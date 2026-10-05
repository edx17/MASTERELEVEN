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
