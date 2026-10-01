extends GutTest
## Faltas (tiro libre, penal, barrera, amarilla), arquero (6 s, soltarla),
## saque de arco y velocidad del juego.

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
	for p in m.all_players():
		p.locked = false


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


func test_slide_from_behind_is_usually_a_foul() -> void:
	var carrier: Footballer = m.teams[0].players[9]
	var slider: Footballer = m.teams[1].players[3]
	carrier.teleport(Vector3(0, 0, 0), Vector3.RIGHT)
	slider.teleport(Vector3(-1.0, 0, 0), Vector3.RIGHT) # atrás del que conduce
	assert_gt(m.foul_chance(slider, carrier, true), 0.6)
	slider.teleport(Vector3(1.0, 0, 0), Vector3.LEFT) # de frente
	assert_lt(m.foul_chance(slider, carrier, true), 0.15)


func test_foul_gives_a_free_kick_with_a_wall() -> void:
	var t0 := m.teams[0]
	var victim: Footballer = t0.players[9]
	var offender: Footballer = m.teams[1].players[3]
	var spot := t0.target_goal() - Vector3(t0.attack_dir * 22.0, 0, -3.0)
	victim.teleport(spot, Vector3(t0.attack_dir, 0, 0))
	offender.teleport(spot - Vector3(t0.attack_dir, 0, 0), Vector3(t0.attack_dir, 0, 0))
	m.call_foul(offender, victim, true)
	assert_eq(m.phase, MatchController.Phase.STOPPED)
	assert_eq(m._pending.type, MatchRules.Restart.FREE_KICK)
	assert_eq(m._pending.team, 0)
	_step(int(MatchController.FOUL_DELAY / dt) + 2)
	assert_eq(m.phase, MatchController.Phase.RESTART)
	assert_eq(m.restart_type, MatchRules.Restart.FREE_KICK)
	assert_between(m.wall_targets.size(), 3, 4, "barrera a 22 m")
	for p: Footballer in m.wall_targets:
		assert_almost_eq(p.flat_pos().distance_to(m.ball.flat_pos()), Pitch.CENTER_CIRCLE_RADIUS, 0.3)


func test_foul_in_the_box_is_a_penalty() -> void:
	var t0 := m.teams[0]
	var victim: Footballer = t0.players[9]
	var offender: Footballer = m.teams[1].players[3]
	var spot := t0.target_goal() - Vector3(t0.attack_dir * 8.0, 0, 0)
	victim.teleport(spot, Vector3(t0.attack_dir, 0, 0))
	offender.teleport(spot - Vector3(t0.attack_dir, 0, 0), Vector3(t0.attack_dir, 0, 0))
	m.call_foul(offender, victim, true)
	assert_eq(m._pending.type, MatchRules.Restart.PENALTY)
	assert_almost_eq(absf(m._pending.spot.x), Pitch.HALF_LENGTH - Pitch.PENALTY_SPOT_DISTANCE, 0.01)
	_step(int(MatchController.FOUL_DELAY / dt) + 2)
	assert_eq(m.restart_type, MatchRules.Restart.PENALTY)
	var kicks := m.kick_count
	_step(120)
	assert_gt(m.kick_count, kicks, "la CPU patea el penal")
	assert_eq(m.last_kick.get("kind"), KickActions.Kind.SHOT)


func test_keeper_six_seconds_and_drop() -> void:
	var gk := m.teams[0].keeper()
	gk.teleport(m.teams[0].own_goal() + Vector3(m.teams[0].attack_dir * 5.0, 0, 0), Vector3(m.teams[0].attack_dir, 0, 0))
	m.ball.give_to(gk, false, true)
	# La CPU la juega rápido; acá se mide la regla directamente.
	m.hands_time = 5.9
	GameSettings.keeper_auto_action = 1
	m._update_keeper_hands(0.2)
	GameSettings.keeper_auto_action = 0
	assert_false(m.ball.in_hands, "a los 6 s la suelta")
	assert_eq(m.keeper_released, gk)
	assert_false(m.keeper_can_use_hands(gk), "no la puede volver a agarrar")
	m.ball.last_toucher = m.teams[1].players[9]
	m._update_keeper_hands(dt)
	assert_true(m.keeper_can_use_hands(gk), "después de que la toca otro, sí")


func test_keeper_auto_kick_after_six_seconds() -> void:
	var gk := m.teams[0].keeper()
	gk.teleport(m.teams[0].own_goal() + Vector3(m.teams[0].attack_dir * 5.0, 0, 0), Vector3(m.teams[0].attack_dir, 0, 0))
	m.ball.give_to(gk, false, true)
	m.hands_time = 5.95
	var k := m.kick_count
	m._update_keeper_hands(0.1)
	assert_gt(m.kick_count, k, "a los 6 s la patea")


func test_goal_kick_is_taken_from_the_goal_area_edge_with_the_feet() -> void:
	var t1 := m.teams[1]
	var spot := Vector3(t1.own_side() * (Pitch.HALF_LENGTH - Pitch.GOAL_AREA_DEPTH), 0.11, 4.0)
	m._pending = MatchRules.Outcome.new(MatchRules.Restart.GOAL_KICK, 1, spot)
	m._setup_restart(m._pending)
	assert_eq(m.restart_taker, t1.keeper())
	assert_false(m.ball.in_hands, "con el pie")
	assert_almost_eq(absf(m.ball.state.pos.x), Pitch.HALF_LENGTH - Pitch.GOAL_AREA_DEPTH, 0.01)


func test_goal_kick_keeper_takes_a_run_up_before_kicking() -> void:
	var t1 := m.teams[1]
	var spot := Vector3(t1.own_side() * (Pitch.HALF_LENGTH - Pitch.GOAL_AREA_DEPTH), 0.11, 4.0)
	m._pending = MatchRules.Outcome.new(MatchRules.Restart.GOAL_KICK, 1, spot)
	m._setup_restart(m._pending)
	var gk := t1.keeper()
	var far := 0.0
	var kicked_at := -1
	for i in 600:
		_step(1)
		far = maxf(far, gk.flat_pos().distance_to(Vector3(spot.x, 0.0, spot.z)))
		if m.phase == MatchController.Phase.PLAYING:
			kicked_at = i
			break
		assert_almost_eq(m.ball.flat_pos().distance_to(Vector3(spot.x, 0.0, spot.z)), 0.0, 0.05, "la pelota queda en la línea")
	assert_gt(far, MatchController.GOAL_KICK_RUNUP - 0.6, "retrocede para tomar carrera")
	assert_gt(kicked_at, 60, "no patea al instante")
	assert_lt(gk.flat_pos().distance_to(Vector3(spot.x, 0.0, spot.z)), 1.0, "patea desde la pelota")


func test_rivals_back_off_when_the_keeper_holds_the_ball() -> void:
	var t0 := m.teams[0]
	var t1 := m.teams[1]
	var gk := t1.keeper()
	gk.teleport(t1.own_goal() + Vector3(t1.attack_dir * 6.0, 0.0, 0.0), Vector3(t1.attack_dir, 0.0, 0.0))
	# Los atacantes, encima del arquero.
	for p in t0.players:
		if not p.is_keeper():
			p.teleport(gk.flat_pos() + Vector3(t1.attack_dir * 3.0, 0.0, randf_range(-6.0, 6.0)), Vector3.ZERO)
	m.ball.give_to(gk, false, true)
	m.tuning.keeper_hold_time = 99.0 # que no la reponga durante la prueba
	for i in 540:
		_step(1)
		m.hands_time = 0.0
	assert_true(m.ball.in_hands)
	var gap_line := absf(Pitch.HALF_LENGTH - TeamAI.KEEPER_HOLD_GAP)
	var near := 0
	for p in t0.players:
		if not p.is_keeper() and not p.is_human() and absf(p.flat_pos().x) > gap_line + 2.0:
			near += 1
	assert_eq(near, 0, "nadie se queda encima del arquero")


func test_game_speed_slows_the_game_but_not_the_clock() -> void:
	assert_lt(GameSettings.game_time_scale(), 1.0, "por defecto, algo más lento")
	assert_almost_eq(Engine.time_scale, GameSettings.game_time_scale(), 0.001)
	# Godot entrega dt ya escalado: 1 s real a escala 0,84 son 60 pasos de 0,84/60.
	m.clock.running = true
	var g0 := m.clock.game_seconds
	for i in 60:
		m._physics_process(dt * Engine.time_scale)
	var real_rate := m.clock._scale
	assert_almost_eq(m.clock.game_seconds - g0, real_rate, real_rate * 0.05, "el reloj avanza 1 s real de partido")


func test_passer_slows_down_while_passing() -> void:
	var p: Footballer = m.teams[0].players[6]
	p.teleport(Vector3(-10, 0, 0), Vector3(1, 0, 0))
	p.velocity = Vector3(7.0, 0, 0)
	m.ball.place(p.flat_pos() + Vector3(0.5, 0.11, 0))
	m.ball.give_to(p)
	var before := Vector3(p.velocity.x, 0, p.velocity.z).length()
	var mate: Footballer = m.teams[0].players[7]
	assert_not_null(m.perform_kick(p, KickActions.Kind.SHORT_PASS, mate.flat_pos() - p.flat_pos(), 0.5, mate))
	for i in 12:
		p.desired_move = Vector3(1, 0, 0)
		p.wants_sprint = true
		p.tick(dt, false)
	var after := Vector3(p.velocity.x, 0, p.velocity.z).length()
	assert_gt(p.kick_brake, 0.0)
	assert_lt(after, before * 0.6, "frena mientras pasa (%.1f -> %.1f m/s)" % [before, after])
