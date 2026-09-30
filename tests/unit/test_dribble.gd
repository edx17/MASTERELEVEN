extends GutTest
## Conducción con pelota independiente (toques).

var t: Tuning


func before_each() -> void:
	t = Tuning.new()


func test_faster_means_longer_touches() -> void:
	assert_gt(Dribble.touch_distance(1.0, 0.0, 0.0, t), Dribble.touch_distance(0.3, 0.0, 0.0, t))


func test_better_control_means_shorter_touches() -> void:
	assert_lt(Dribble.touch_distance(1.0, 0.8, 0.0, t), Dribble.touch_distance(1.0, -0.8, 0.0, t))


func test_pressure_shortens_touches() -> void:
	assert_lt(Dribble.touch_distance(1.0, 0.0, 1.0, t), Dribble.touch_distance(1.0, 0.0, 0.0, t))


func test_touch_puts_ball_about_distance_ahead() -> void:
	# Jugador a 7 m/s; la pelota sale con la velocidad del toque y rueda.
	var speed := 7.0
	var d := 1.2
	var v := Dribble.touch_velocity(speed, Vector3.RIGHT, d, t)
	var ball := BallState.new(Vector3(0, t.ball_radius, 0), v)
	var player_x := 0.0
	var max_gap := 0.0
	var e := 0.0
	while e < 1.5:
		BallPhysics.step(ball, BallPhysics.SIM_DT, t)
		player_x += speed * BallPhysics.SIM_DT
		max_gap = maxf(max_gap, ball.pos.x - player_x)
		e += BallPhysics.SIM_DT
	assert_almost_eq(max_gap, d, 0.25, "la pelota se adelanta lo pedido")


func test_exposed_when_far_from_foot() -> void:
	assert_false(Dribble.is_exposed(Vector3(0.4, 0.1, 0), Vector3.ZERO, Vector3.RIGHT))
	assert_true(Dribble.is_exposed(Vector3(1.5, 0.1, 0), Vector3.ZERO, Vector3.RIGHT))
