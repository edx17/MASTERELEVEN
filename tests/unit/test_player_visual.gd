extends GutTest
## Capa de presentación: anima según la simulación y nunca la modifica.

func _visual() -> PlayerVisual:
	var v := PlayerVisual.new()
	add_child_autofree(v)
	v.setup({"shirt": Color.RED, "shorts": Color.BLACK}, 7)
	return v


func test_running_swings_the_legs() -> void:
	var v := _visual()
	var angles: Array[float] = []
	for i in 30:
		v.update(1.0 / 60.0, 7.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
		angles.append(v._leg[0].rotation.x)
	assert_gt(angles.max() - angles.min(), 0.5, "las piernas se mueven al correr")


func test_standing_still_keeps_legs_straight() -> void:
	var v := _visual()
	for i in 30:
		v.update(1.0 / 60.0, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
	assert_almost_eq(v._leg[0].rotation.x, 0.0, 0.01)


func test_kick_swings_the_kicking_leg_forward() -> void:
	var v := _visual()
	v.play(PlayerVisual.Event.KICK)
	var min_angle := 0.0
	for i in 20:
		v.update(1.0 / 60.0, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
		min_angle = minf(min_angle, v._leg[1].rotation.x)
	assert_lt(min_angle, -0.8, "la pierna sale hacia adelante")


func test_match_plays_kick_animation_without_touching_physics() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	var p: Footballer = m.teams[0].players[6]
	p.locked = false
	p.teleport(Vector3(0, 0, 0), Vector3.RIGHT)
	m.ball.place(Vector3(0.5, 0.11, 0))
	m.ball.give_to(p)
	var pos_before := p.global_position
	m.perform_kick(p, KickActions.Kind.SHOT, Vector3.RIGHT, 0.6)
	assert_eq(p.visual._event, PlayerVisual.Event.KICK)
	assert_eq(p.global_position, pos_before, "la animación no mueve al jugador")
