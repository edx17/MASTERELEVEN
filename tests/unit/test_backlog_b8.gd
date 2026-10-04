extends GutTest
## UI: íconos de botones, cambio de controles guardado, ficha ampliada con
## etiquetas que juegan, cancha de formación animada.

const CFG := "user://test_controls.cfg"


func after_each() -> void:
	InputMap.load_from_project_settings()
	InputRouter.setup_for_mode(GameSettings.mode)
	if FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))


func test_button_icons_are_drawn_and_inlined() -> void:
	for id in ButtonIcons.IDS:
		var t := ButtonIcons.texture(id, 24)
		assert_eq(t.get_height(), 24)
	assert_gt(ButtonIcons.texture("L1", 24).get_width(), ButtonIcons.texture("X", 24).get_width(), "gatillo apaisado")
	var combo := ButtonIcons.combo(["L2", "SQ"], 20)
	assert_gt(combo.get_width(), ButtonIcons.texture("L2", 20).get_width() + ButtonIcons.texture("SQ", 20).get_width())
	# Los colores del símbolo están en el centro del ícono.
	var img := (ButtonIcons.texture("O", 64) as ImageTexture).get_image()
	var ring := img.get_pixel(32, 32 - 11)
	assert_gt(ring.r, 0.7, "círculo rojo")
	var rtl := RichTextLabel.new()
	add_child_autofree(rtl)
	ButtonIcons.fill(rtl, "{X} elegir   {O} volver")
	assert_true(rtl.get_parsed_text().contains("elegir"))
	assert_false(rtl.get_parsed_text().contains("{X}"), "el token se reemplaza por el ícono")
	assert_eq(ButtonIcons.plain("{SQ} remate"), "Cuadrado remate")


func test_rebind_swaps_and_persists() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	var shoot_before := ControlsConfig.pad_text(&"shoot")
	var pass_before := ControlsConfig.pad_text(&"pass_short")
	# Remate al botón que tenía el pase corto: se intercambian.
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = true
	ControlsConfig.rebind(&"shoot", ev)
	assert_eq(ControlsConfig.pad_text(&"shoot"), pass_before)
	assert_eq(ControlsConfig.pad_text(&"pass_short"), shoot_before, "el otro se queda con el que soltó")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_U
	key.pressed = true
	ControlsConfig.rebind(&"pass_long", key)
	assert_eq(ControlsConfig.key_text(&"pass_long"), "U")
	# Las acciones por jugador se rearmaron.
	assert_true(InputMap.action_has_event(InputRouter.action_name(0, &"pass_long"), key))
	ControlsConfig.save(CFG)
	InputMap.load_from_project_settings()
	assert_ne(ControlsConfig.key_text(&"pass_long"), "U")
	ControlsConfig.load_saved(CFG)
	assert_eq(ControlsConfig.key_text(&"pass_long"), "U", "se recupera lo guardado")
	assert_eq(ControlsConfig.pad_text(&"shoot"), pass_before)
	ControlsConfig.reset(CFG)
	assert_eq(ControlsConfig.pad_text(&"shoot"), shoot_before)
	assert_false(FileAccess.file_exists(CFG))


func test_controls_page_captures_the_next_button() -> void:
	var page := ControlsPage.new()
	add_child_autofree(page)
	page._start_capture(&"brake")
	assert_true(page.is_capturing())
	var ev := InputEventJoypadMotion.new()
	ev.axis = JOY_AXIS_TRIGGER_LEFT
	ev.axis_value = 1.0
	page._capture_wait = 0.0
	page._input(ev)
	assert_false(page.is_capturing())
	assert_eq(ControlsConfig.pad_text(&"brake"), "{L2}")


func test_extended_stats_and_tags() -> void:
	var t: TeamData = load("res://data/teams/halcones.tres")
	var captains := 0
	for p: PlayerData in t.players:
		for a in ["attack", "jump", "shot_power", "curve"]:
			assert_between(int(p.get(a)), 1, 99, "%s de %s" % [a, p.player_name])
		assert_gt(p.height, 150)
		if p.has_ability("capitan"):
			captains += 1
	assert_eq(captains, 1, "un capitán por plantel")
	assert_eq(PlayerData.ATTRIBUTES.size(), PlayerData.ATTRIBUTE_NAMES.size())
	for n in ["Ataque", "Potencia de salto", "Precisión de cabeza", "Potencia de remate", "Precisión de remate", "Gambeta", "Curva"]:
		assert_has(PlayerData.ATTRIBUTE_NAMES, n)
	for tag in ["gambeteador", "especialista", "penales", "corners", "muro", "ataja_penales", "capitan"]:
		assert_true(PlayerData.ABILITY_NAMES.has(tag))
	# Sin cargar, se derivan solos.
	var d := PlayerData.new()
	d.player_name = "Z. Prueba"
	d.fill_extended(false)
	assert_gt(d.attack, 0)
	assert_eq(d.abilities.size(), 0, "sin etiquetas si no se piden")


func test_tagged_players_take_the_set_pieces() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	var t := m.teams[0]
	assert_not_null(t.captain_data(), "capitán de la ficha")
	var corner_guy: Footballer = t.players[7]
	for p in t.players:
		if p.data != null:
			p.data.abilities = PackedStringArray()
	corner_guy.data.abilities = PackedStringArray(["corners"])
	assert_eq(t.tagged("corners"), corner_guy)
	t.ck_taker = null
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.CORNER, 0,
		Vector3(t.target_goal().x, 0.11, Pitch.HALF_WIDTH)))
	assert_eq(m.restart_taker, corner_guy, "el lanzador de córners")


func test_power_and_curve_change_the_shot() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	var p: Footballer = m.teams[0].players[9]
	m.kicks.randomize_error = false
	var speeds := []
	for sp in [20, 95]:
		p.data.shot_power = sp
		var pos := Vector3(m.teams[0].attack_dir * 25.0, 0, 0)
		p.teleport(pos, Vector3(m.teams[0].attack_dir, 0, 0))
		m.ball.place(pos + Vector3(m.teams[0].attack_dir * 0.5, 0.11, 0))
		m.ball.give_to(p)
		m.kicks.shoot(p, Vector3.ZERO, 0.7)
		speeds.append(m.ball.speed())
	assert_gt(speeds[1], speeds[0] * 1.08, "más potencia de remate, más fuerte")


func test_formation_pitch_slides_to_the_new_shape() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	var sheet := TeamSheet.new()
	add_child_autofree(sheet)
	sheet.open(m, m.teams[0], true)
	var pitch := sheet._pitch
	pitch._process(1.0) # se acomoda
	var p: Footballer = m.teams[0].players[6]
	var before := pitch.shown_of(p)
	sheet._next_formation()
	var target := pitch.spot_of(p)
	if target.distance_to(before) < 0.01:
		p = m.teams[0].players[9]
		before = pitch.shown_of(p)
		target = pitch.spot_of(p)
	pitch._process(0.05)
	var mid := pitch.shown_of(p)
	assert_gt(mid.distance_to(before), 0.0, "empieza a moverse")
	assert_gt(mid.distance_to(target), 0.0, "pero no salta de golpe")
	for i in 60:
		pitch._process(1.0 / 60.0)
	assert_almost_eq(pitch.shown_of(p).distance_to(target), 0.0, 0.01, "llega a su lugar")


func test_name_label_is_smaller() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	var label := GameSettings.player_label
	GameSettings.player_label = 0
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	var h: Footballer = m.teams[0].players[5]
	h.refresh_label()
	assert_lte(h._label.font_size, 64)
	GameSettings.player_label = label
