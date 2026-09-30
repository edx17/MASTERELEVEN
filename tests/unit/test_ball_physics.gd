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
	var curved := BallState.new(Vector3(0, 1, 0), Vector3(20, 3, 0), Vector3(0, 50, 0))
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



# --- Validación contra datos reales (informe técnico / FIFA) ------------------

func test_kpi_fifa_bounce_on_hard_surface() -> void:
	# Prueba de rebote FIFA: cae de 2 m sobre superficie dura (e≈0,8) y
	# rebota 1,2-1,4 m.
	var hard := Tuning.new()
	hard.ground_restitution = 0.8
	var s := BallState.new(Vector3(0, 2.0 + hard.ball_radius, 0))
	var peak := 0.0
	var bounced := false
	var e := 0.0
	while e < 2.0:
		if BallPhysics.step(s, BallPhysics.SIM_DT, hard) & BallPhysics.EV_BOUNCE:
			if bounced:
				break
			bounced = true
		if bounced:
			peak = maxf(peak, s.pos.y - hard.ball_radius)
		e += BallPhysics.SIM_DT
	assert_between(peak, 1.15, 1.4, "rebote FIFA")


func test_kpi_drag_crisis_makes_hard_shots_fly() -> void:
	# Cd baja a alta velocidad: el arrastre relativo (k) es menor.
	assert_lt(BallPhysics.drag_k(25.0, t), BallPhysics.drag_k(5.0, t) * 0.6)
	# Valor físico: ½·1,2·0,22·π·0,11²/0,43 ≈ 0,0117.
	assert_almost_eq(BallPhysics.drag_k(25.0, t), 0.0117, 0.001)


func test_kpi_free_kick_curls_a_few_meters() -> void:
	# Tiro libre a 25 m/s con ~10 vueltas/s de efecto: se desvía 2-5 m en 25 m.
	var s := BallState.new(Vector3(0, 0.5, 0), Vector3(25, 3, 0), Vector3(0, 60, 0))
	while s.pos.x < 25.0:
		BallPhysics.step(s, BallPhysics.SIM_DT, t)
	assert_between(absf(s.pos.z), 2.0, 5.0)


func test_kpi_strong_shot_speed_is_realistic() -> void:
	# Tiros fuertes reales: ~90-115 km/h.
	assert_between(t.shot_speed_max * 3.6, 90.0, 115.0)


func test_kpi_long_ball_distance() -> void:
	# Un pelotazo a 28 m/s y 35° cae entre 45 y 65 m (arrastre incluido).
	var d := BallPhysics.lob_landing(28.0, 35.0, t).x
	assert_between(d, 45.0, 65.0)
