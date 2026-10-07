extends GutTest
## Paso UI-1: pantallas y marcas a la WE2002.

var m: MatchController
var dt := 1.0 / 60.0


func _start(mode: int = GameSettings.Mode.CPU_VS_CPU) -> void:
	GameSettings.set_mode(mode)
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


## UI1-a: en el tiro libre con la cámara atrás aparece el cartel con los
## metros al arco ("23M"), y se va cuando sale la pelota.
func test_free_kick_shows_distance_sign() -> void:
	_start()
	var t := m.teams[0]
	var spot := t.target_goal() - Vector3(t.attack_dir * 23.0, 0.0, 0.0)
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.FREE_KICK, t.index, Vector3(spot.x, 0.11, spot.z)))
	assert_true(m.free_kick_camera_active())
	_step(1)
	assert_eq(m.distance_sign_text(), "23M")
	var before := m.kick_count
	for i in int(8.0 / dt):
		_step(1)
		if m.kick_count != before:
			break
	_step(2)
	assert_eq(m.distance_sign_text(), "", "se va al patear")


func test_goal_distance_rounds_to_meters() -> void:
	assert_eq(MatchController.goal_distance_m(Vector3(10, 0, 3), Vector3(30, 0, 3)), 20)
	assert_eq(MatchController.goal_distance_m(Vector3(0, 0, 0), Vector3(3, 0, 4)), 5)


## UI1-a: el número del mando (1, 2) al lado de la flecha.
func test_arrow_shows_controller_number() -> void:
	_start(GameSettings.Mode.VS_CPU)
	var p: Footballer = m.teams[0].players[5]
	p.set_human_slot(1)
	assert_true(p._slot_label.visible)
	assert_eq(p._slot_label.text, "2")
	p.set_human_slot(-1)
	assert_false(p._slot_label.visible)


func _pause_menu() -> PauseMenu:
	for c in m.get_children():
		if c is PauseMenu:
			return c
	return null


## UI1-b: la pausa dice qué mando la pidió y tiene Cámara, Pantalla y Sonido;
## los submenúes vuelven a la lista.
func test_pause_title_camera_and_submenus() -> void:
	_start(GameSettings.Mode.VS_CPU)
	var pm := _pause_menu()
	assert_not_null(pm)
	pm.pad = 2
	pm._refresh()
	assert_eq(pm._title.text, "PAUSA — MANDO 2")
	var cam := m.camera()
	var before := cam.preset_index
	pm._camera_row.change(1)
	assert_eq(cam.preset_index, posmod(before + 1, cam.presets.size()), "cambia la cámara")
	cam.set_preset(before, false)
	for key in ["display", "sound", "game"]:
		pm._open_sub(key)
		assert_eq(pm.open_sub_key(), key)
		assert_false(pm._box.visible)
		pm._close_sub()
		assert_eq(pm.open_sub_key(), "")
		assert_true(pm._box.visible)


## UI1-b: Pantalla apaga el radar y el marcador del HUD.
func test_display_switches_hide_radar_and_score() -> void:
	_start()
	var radar0 := GameSettings.show_radar
	var score0 := GameSettings.show_score
	GameSettings.show_radar = false
	GameSettings.show_score = false
	m._hud._process(0.0)
	assert_false(m._hud._radar.visible)
	assert_false(m._hud._top.visible)
	GameSettings.show_radar = true
	GameSettings.show_score = true
	m._hud._process(0.0)
	assert_true(m._hud._radar.visible)
	assert_true(m._hud._top.visible)
	GameSettings.show_radar = radar0
	GameSettings.show_score = score0


## UI1-c: el resultado cuenta los goles de cada tiempo, los tiros libres y
## los penales; el final se titula "RESULTADO".
func test_result_counts_halves_free_kicks_and_penalties() -> void:
	_start()
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.FREE_KICK, 1, Vector3(10, 0.11, 5)))
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.PENALTY, 0, m.penalty_spot(m.teams[1])))
	assert_eq(m.stats["free_kicks"], [0, 1])
	assert_eq(m.stats["penalties"], [1, 0])
	m.stats["goals_1st"] = [1, 0]
	m.stats["goals_2nd"] = [0, 2]
	m.halftime_screen.open(true)
	assert_eq(m.halftime_screen._title.text, "RESULTADO")
	assert_eq(m.halftime_screen.halves_text(), "1T  1 - 0      2T  0 - 2")
	var names := []
	for r in m.halftime_screen.stat_rows():
		names.append(r[0])
	assert_has(names, "Tiros libres")
	assert_has(names, "Penales")
	assert_has(names, "Fuera de juego")
	m.halftime_screen.close()


## UI1-d: siglas de puesto del WE2002 con el lado.
func test_we_position_codes() -> void:
	assert_eq(TacticalRole.we_code(TacticalRole.Kind.FB, -0.68), "RB")
	assert_eq(TacticalRole.we_code(TacticalRole.Kind.FB, 0.68), "LB")
	assert_eq(TacticalRole.we_code(TacticalRole.Kind.WM, 0.7), "LMF")
	assert_eq(TacticalRole.we_code(TacticalRole.Kind.DM, 0.0), "DMF")
	assert_eq(TacticalRole.we_code(TacticalRole.Kind.ST, 0.1), "CF")
	_start()
	var codes := []
	for p in m.teams[0].players:
		if not p.is_keeper():
			codes.append(TeamSheet.role_code(p))
	assert_has(codes, "CB")
	assert_true(codes.has("LB") or codes.has("LMF") or codes.has("WG"), str(codes))


## UI1-d: tiro libre corto / largo y córner izquierdo / derecho.
func test_separate_set_piece_takers() -> void:
	_start()
	var t := m.teams[0]
	var a: PlayerData = t.players[9].base_data
	var b: PlayerData = t.players[10].base_data
	t.fk_taker = a
	t.fk_long_taker = b
	var g := t.target_goal()
	assert_eq(MatchController.free_kick_taker_data(t, g - Vector3(t.attack_dir * 20.0, 0, 0)), a, "corto")
	assert_eq(MatchController.free_kick_taker_data(t, g - Vector3(t.attack_dir * 30.0, 0, 0)), b, "largo")
	t.ck_taker = a
	t.ck_right_taker = b
	var left := Vector3(g.x, 0, -Pitch.HALF_WIDTH * t.attack_dir)
	var right := Vector3(g.x, 0, Pitch.HALF_WIDTH * t.attack_dir)
	assert_true(MatchController.corner_from_left(t, left))
	assert_eq(MatchController.corner_taker_data(t, left), a)
	assert_eq(MatchController.corner_taker_data(t, right), b)
	t.ck_right_taker = null
	assert_eq(MatchController.corner_taker_data(t, right), a, "sin el de la derecha, el de la izquierda")
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.CORNER, 0, Vector3(right.x, 0.11, right.z)))
	assert_eq(m.restart_taker.base_data, a)


## UI1-d: Copiar estrategia guarda formación, botones y pateadores y los
## vuelve a poner.
func test_copy_strategy_saves_and_loads() -> void:
	TeamSheet.plans_path = "user://test_plans.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TeamSheet.plans_path))
	_start()
	var t := m.teams[0]
	var sheet := TeamSheet.new()
	add_child_autofree(sheet)
	sheet.open(m, t, true)
	var a: PlayerData = t.players[9].base_data
	t.fk_long_taker = a
	t.strategy_slots[0] = t.strategy_slots[3]
	var slots := t.strategy_slots.duplicate()
	sheet.save_plan()
	t.fk_long_taker = null
	t.strategy_slots[0] = Strategy.DEFAULT_SLOTS[0]
	sheet.load_plan()
	assert_eq(t.fk_long_taker, a)
	assert_eq(t.strategy_slots, slots)
	sheet.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TeamSheet.plans_path))
	TeamSheet.plans_path = ""


## UI1-e: cuándo queda decidida la tanda.
func test_shootout_decided() -> void:
	assert_eq(PenaltyShootout.decided([true, true, true], [false, false, false]), 0, "3-0 con 2 por patear")
	assert_eq(PenaltyShootout.decided([true, true, true], [false, false]), -1, "todavía puede")
	assert_eq(PenaltyShootout.decided([true, true, true, true, true], [true, true, true, true, true]), -1)
	assert_eq(PenaltyShootout.decided([true, true, true, true, true, false], [true, true, true, true, true, true]), 1, "muerte súbita")
	assert_eq(PenaltyShootout.decided([true, true, true, true, true, true], [true, true, true, true, true]), -1, "falta el otro")


## UI1-e: tanda CPU vs CPU completa: alterna, los demás esperan en el medio
## y termina con un ganador.
func test_shootout_plays_to_a_winner() -> void:
	GameSettings.shootout = true
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	GameSettings.shootout = false
	var so := m.training as PenaltyShootout
	assert_not_null(so)
	assert_eq(m.restart_type, MatchRules.Restart.PENALTY)
	var waiting := 0
	for p in m.all_players():
		if p != m.restart_taker and not p.is_keeper() and p.flat_pos().length() < 9.0:
			waiting += 1
	assert_gt(waiting, 15, "en el círculo central")
	var first_shooter := so.shooter
	for i in int(240.0 / dt):
		_step(1)
		if so.finished:
			break
	assert_true(so.finished, "terminó")
	assert_ne(so.winner, -1)
	assert_ne(so.goals_of(0), so.goals_of(1))
	assert_true(absi(so.kicks[0].size() - so.kicks[1].size()) <= 1)
	assert_eq(first_shooter, 0)


## UI1-f: presentación con el cartel de equipos, "EN VIVO", la bandera
## gigante en la formación y la foto del equipo con flash.
func test_presentation_banner_live_flag_and_photo() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	GameSettings.play_intro = true
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	var intro := m.intro
	intro._enter(MatchIntro.Step.WARMUP)
	assert_true(intro._banner.visible, "cartel de los equipos")
	assert_true(intro._live.visible, "EN VIVO")
	assert_string_contains(intro.live_text(), String(StadiumStyles.current["name"]))
	intro._enter(MatchIntro.Step.LINEUP)
	assert_false(intro._banner.visible)
	assert_not_null(intro.flag_mesh)
	assert_true(intro.flag_mesh.visible, "bandera gigante")
	intro._enter(MatchIntro.Step.PHOTO)
	assert_eq(intro.photo_team, m.humans[0].team)
	var zs := {}
	for p in intro.photo_team.players:
		zs[snappedf(p.flat_pos().z, 0.1)] = true
	assert_eq(zs.size(), 2, "dos filas")
	var flashed := false
	for i in int(3.0 / dt):
		m._physics_process(dt)
		if intro._flash.color.a > 0.5:
			flashed = true
	assert_true(flashed, "flash de la foto")
	intro._enter(MatchIntro.Step.DONE)
	assert_null(intro.flag_mesh)
	assert_eq(m.phase, MatchController.Phase.RESTART)


## ETAPA 6: marcador centrado con el rótulo de la competición, reloj "1T" y
## el resultado se enciende al haber un gol.
func test_hud_scorebug_label_clock_and_goal_flash() -> void:
	GameSettings.match_label = "Liga Virtual · Fecha 3"
	_start()
	var hud: MatchHud = null
	for c in m.find_children("*", "", true, false):
		if c is MatchHud:
			hud = c
	assert_not_null(hud)
	var labels := hud._top.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_true(labels.has("LIGA VIRTUAL · FECHA 3"), "rótulo de la competición")
	hud._process(dt)
	assert_string_starts_with(hud._clock.text, "1T")
	assert_eq(hud._score.text, "0 - 0")
	m.teams[0].score += 1
	hud._process(dt)
	assert_eq(hud._score.text, "1 - 0")
	assert_gt(hud._score_box.modulate.r, 1.0, "el resultado se enciende con el gol")
	GameSettings.match_label = ""
