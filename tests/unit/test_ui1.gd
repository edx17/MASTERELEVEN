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
