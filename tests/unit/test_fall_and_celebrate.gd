extends GutTest
## Derribos por barrida, festejo y arquero de costado (simulación).

var m: MatchController


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	for p in m.all_players():
		p.locked = false


func test_tripped_player_cannot_play_until_he_gets_up() -> void:
	var p: Footballer = m.teams[0].players[6]
	p.teleport(Vector3.ZERO, Vector3.RIGHT)
	p.trip(1.0)
	assert_false(p.can_touch_ball(), "en el piso no la toca")
	p.desired_move = Vector3.RIGHT
	for i in 30:
		p.tick(1.0 / 60.0, false)
	assert_lt(p.flat_pos().length(), 0.3, "no corre en el piso")
	for i in 40:
		p.tick(1.0 / 60.0, false)
	assert_eq(p.state, Footballer.State.NORMAL)
	assert_false(p.tripped)


func test_winning_slide_can_trip_the_carrier() -> void:
	m.tuning.slide_trip_chance = 1.0
	var carrier: Footballer = m.teams[0].players[6]
	var slider: Footballer = m.teams[1].players[6]
	carrier.teleport(Vector3.ZERO, Vector3.RIGHT)
	m.ball.place(Vector3(0.4, 0.11, 0))
	m.ball.give_to(carrier)
	slider.teleport(Vector3(1.2, 0, 0), Vector3.LEFT)
	slider.start_slide(Vector3.LEFT)
	m._try_steal(1.0 / 60.0)
	m.tuning.slide_trip_chance = 0.5
	assert_true(carrier.tripped, "la barrida que roba lo derriba")


func test_scorer_celebrates_standing_still() -> void:
	var p: Footballer = m.teams[0].players[9]
	p.teleport(Vector3.ZERO, Vector3.RIGHT)
	p.celebrate(1.0)
	p.desired_move = Vector3.RIGHT
	for i in 30:
		p.tick(1.0 / 60.0, false)
	assert_lt(p.flat_pos().length(), 0.1)


func test_keeper_faces_the_ball_while_moving_sideways() -> void:
	var gk: Footballer = m.teams[0].keeper()
	gk.teleport(Vector3(-50, 0, 0), Vector3.RIGHT)
	for i in 30:
		gk.desired_move = Vector3(0, 0, 0.5)
		gk.face_point = Vector3(0, 0, 0)
		gk.tick(1.0 / 60.0, false)
	assert_gt(gk.facing.dot(Vector3.RIGHT), 0.95, "sigue mirando la pelota")
	assert_gt(gk.velocity.z, 1.5, "y se desplaza de costado")


func test_catch_gesture_depends_on_height() -> void:
	assert_eq(MatchController.catch_event(2.0), PlayerVisual.Event.CATCH_HIGH)
	assert_eq(MatchController.catch_event(1.1), PlayerVisual.Event.CATCH)
	assert_eq(MatchController.catch_event(0.2), PlayerVisual.Event.CATCH_LOW)
