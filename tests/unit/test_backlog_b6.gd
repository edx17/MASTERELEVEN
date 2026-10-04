extends GutTest
## Gráficos: la red se infla donde pega la pelota y vuelve; la vincha es tela
## mate (sin emisión).

var m: MatchController
var dt := 1.0 / 60.0


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false


func _net(side: int) -> GoalNet:
	for n in get_tree().get_nodes_in_group(&"goal_net"):
		if (n as GoalNet).side == side:
			return n
	return null


func test_both_goals_have_a_reactive_net() -> void:
	assert_not_null(_net(1))
	assert_not_null(_net(-1))
	assert_true(_net(1).material_override is ShaderMaterial)


func test_a_goal_shakes_the_net_and_it_settles() -> void:
	var net := _net(1)
	m.ball.place(Vector3(Pitch.HALF_LENGTH - 1.0, 1.0, 0.5))
	m.ball.state.vel = Vector3(25, 0, 0)
	for i in 30:
		m.ball.tick(dt)
		if m.ball.net_hit_speed > 0.0:
			break
	assert_gt(m.ball.net_hit_speed, 10.0, "pegó en la red con fuerza")
	assert_gt(absf(net.current_bulge()), 0.1, "se infla")
	assert_eq(absf(_net(-1).current_bulge()), 0.0, "la otra no")
	var mat := net.material_override as ShaderMaterial
	var hp: Vector3 = mat.get_shader_parameter("hit_pos")
	assert_almost_eq(hp.x, Pitch.HALF_LENGTH + Pitch.GOAL_DEPTH, 0.4, "en el fondo de la red")
	for i in int(GoalNet.SETTLE_TIME / dt) + 2:
		net._process(dt)
	assert_eq(net.current_bulge(), 0.0, "vuelve a su lugar")


func test_slow_ball_resting_on_the_net_does_not_shake_it() -> void:
	m.ball.net_hit_speed = 1.0
	m._on_net_hit()
	assert_eq(_net(1).current_bulge(), 0.0)
	assert_eq(_net(-1).current_bulge(), 0.0)


func test_headband_is_matte_cloth() -> void:
	var mat := ModelVisual._band_material(Color(1, 1, 1))
	assert_false(mat.emission_enabled)
	assert_lte(mat.albedo_color.v, 0.79, "blanco atenuado, no fosforescente")
	assert_gte(mat.roughness, 0.9)
