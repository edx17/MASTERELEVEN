extends GutTest
## Física de la pelota: gravedad, pique, rozamiento, efecto, postes, red y
## resolución de pases (que el pase llegue donde tiene que llegar).

var t: Tuning


func before_each() -> void:
	t = Tuning.new()


func _run(s: BallState, seconds: float) -> void:
	var e := 0.0
	while e < seconds:
		BallPhysics.step(s, BallPhysics.SIM_DT, t)
		e += BallPhysics.SIM_DT


func test_ball_falls_and_rests_on_ground() -> void:
	var s := BallState.new(Vector3(0, 5, 0))
	_run(s, 6.0)
	assert_almost_eq(s.pos.y, t.ball_radius, 0.001)
	assert_almost_eq(s.vel.length(), 0.0, 0.01)


func test_bounce_loses_energy() -> void:
	var s := BallState.new(Vector3(0, 3, 0))
	var peak_after := 0.0
	var bounced := false
	var e := 0.0
	while e < 3.0:
		var ev := BallPhysics.step(s, BallPhysics.SIM_DT, t)
		if ev & BallPhysics.EV_BOUNCE:
			bounced = true
		if bounced:
			peak_after = maxf(peak_after, s.pos.y)
		e += BallPhysics.SIM_DT
	assert_true(bounced, "debe picar")
	assert_gt(peak_after, 0.3, "el pique tiene que tener altura")
	assert_lt(peak_after, 3.0 * 0.5, "cada pique pierde energía")


func test_rolling_ball_stops_by_friction() -> void:
	var s := BallState.new(Vector3(0, t.ball_radius, 0), Vector3(10, 0, 0))
	_run(s, 10.0)
	assert_almost_eq(s.vel.length(), 0.0, 0.01)
	assert_gt(s.pos.x, 10.0)
	assert_lt(s.pos.x, 30.0)


func test_ground_pass_speed_arrives_at_distance() -> void:
	for d in [8.0, 15.0, 30.0]:
		var v0 := BallPhysics.ground_pass_speed(d, 6.0, t)
		var s := BallState.new(Vector3(0, t.ball_radius, 0), Vector3(v0, 0, 0))
		var e := 0.0
		while s.pos.x < d and e < 10.0:
			BallPhysics.step(s, BallPhysics.SIM_DT, t)
			e += BallPhysics.SIM_DT
		assert_almost_eq(s.vel.x, 6.0, 0.35, "llega a %.0f m con la velocidad pedida" % d)


func test_lob_lands_at_requested_distance() -> void:
	for d in [15.0, 30.0, 50.0]:
		var speed := BallPhysics.lob_speed(d, 30.0, t)
		var landing := BallPhysics.lob_landing(speed, 30.0, t)
		assert_almost_eq(landing.x, d, 0.5, "globo a %.0f m" % d)


func test_spin_curves_the_ball() -> void:
	var straight := BallState.new(Vector3(0, 1, 0), Vector3(20, 3, 0))
	var curved := BallState.new(Vector3(0, 1, 0), Vector3(20, 3, 0), Vector3(0, 5, 0))
	_run(straight, 0.8)
	_run(curved, 0.8)
	assert_almost_eq(straight.pos.z, 0.0, 0.001)
	assert_gt(absf(curved.pos.z), 0.3, "con efecto se desvía lateralmente")


func test_post_bounces_ball_back() -> void:
	var s := BallState.new(Vector3(Pitch.HALF_LENGTH - 3.0, 1.0, Pitch.GOAL_HALF_WIDTH), Vector3(20, 0, 0))
	var hit := false
	var e := 0.0
	while e < 0.5:
		if BallPhysics.step(s, BallPhysics.SIM_DT, t) & BallPhysics.EV_POST:
			hit = true
		e += BallPhysics.SIM_DT
	assert_true(hit, "debe pegar en el poste")
	assert_lt(s.vel.x, 0.0, "rebota hacia la cancha")


func test_crossbar_bounces() -> void:
	var s := BallState.new(Vector3(Pitch.HALF_LENGTH - 3.0, Pitch.GOAL_HEIGHT, 0.0), Vector3(20, 0, 0))
	var hit := false
	var e := 0.0
	while e < 0.3:
		if BallPhysics.step(s, BallPhysics.SIM_DT, t) & BallPhysics.EV_POST:
			hit = true
		e += BallPhysics.SIM_DT
	assert_true(hit, "debe pegar en el travesaño")


func test_net_stops_ball_inside_goal() -> void:
	var s := BallState.new(Vector3(Pitch.HALF_LENGTH - 5.0, 1.0, 0.0), Vector3(30, 0, 0))
	_run(s, 3.0)
	assert_gt(s.pos.x, Pitch.HALF_LENGTH, "la pelota queda adentro del arco")
	assert_lt(s.pos.x, Pitch.HALF_LENGTH + Pitch.GOAL_DEPTH, "la red no la deja pasar")


func test_side_netting_from_outside_keeps_ball_out() -> void:
	# Tiro cruzado que pega en la red lateral por afuera.
	var s := BallState.new(Vector3(Pitch.HALF_LENGTH + 1.0, 0.5, Pitch.GOAL_HALF_WIDTH + 3.0), Vector3(0, 0, -15))
	_run(s, 1.0)
	assert_gt(s.pos.z, Pitch.GOAL_HALF_WIDTH - 0.01, "no atraviesa la red lateral")
