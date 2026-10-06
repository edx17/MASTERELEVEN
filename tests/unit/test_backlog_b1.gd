extends GutTest
## Bugs críticos del backlog: lateral con 6 s, entretiempo con inercia y
## pantalla de estadísticas, L1 instantáneo, posesión y córners, giro de la
## pelota en la repetición y highlights.

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


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


func test_throw_in_is_forced_after_six_seconds() -> void:
	var t := m.teams[0]
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.THROW_IN, 0, Vector3(5, 0.11, Pitch.HALF_WIDTH)))
	assert_eq(m.restart_type, MatchRules.Restart.THROW_IN)
	# Nadie la saca (se simula un humano que espera: la IA no saca).
	m._restart_elapsed = MatchController.THROW_IN_LIMIT - 0.1
	assert_almost_eq(m.throw_in_time_left(), 0.1, 0.01)
	var kicks := m.kick_count
	m._restart_elapsed = MatchController.THROW_IN_LIMIT + 0.01
	m._check_throw_in_limit()
	assert_gt(m.kick_count, kicks, "se la da a un compañero")
	assert_eq(m.phase, MatchController.Phase.PLAYING)
	assert_eq(m.last_kick.get("team"), t.index)


## Tiro libre: a los 6 s sin ejecutar sale solo, y con la pelota parada el
## reloj no corre.
func test_free_kick_is_forced_after_six_seconds_and_clock_stops() -> void:
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.FREE_KICK, 0, Vector3(-10, 0.11, 5)))
	assert_eq(m.restart_type, MatchRules.Restart.FREE_KICK)
	var before := m.clock.total_game_seconds()
	_step(10)
	assert_eq(m.clock.total_game_seconds(), before, "el reloj frenado hasta que se patee")
	m._restart_elapsed = MatchController.THROW_IN_LIMIT + 0.01
	m._check_throw_in_limit()
	# Toma carrera y le pega.
	for i in 200:
		if m.phase == MatchController.Phase.PLAYING:
			break
		m._physics_process(dt)
	assert_eq(m.phase, MatchController.Phase.PLAYING, "se ejecutó solo")
	assert_eq(m.last_kick.get("team"), 0)


func test_free_kick_players_already_placed() -> void:
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.FREE_KICK, 0, Vector3(5, 0.11, 0)))
	var spot := m.ball.flat_pos()
	for p in m.teams[1].players:
		if not m.wall_targets.has(p):
			assert_gt(p.flat_pos().distance_to(spot), 9.0, "rivales a 9,15 m: %s" % p.display_name)


func test_halftime_coasts_then_shows_the_stats() -> void:
	m.ball.place(Vector3(0, 0.11, 0))
	m.ball.state.vel = Vector3(8, 0, 0)
	m._end_half()
	assert_eq(m.phase, MatchController.Phase.HALFTIME)
	_step(30)
	assert_gt(m.ball.global_position.x, 1.0, "la pelota sigue rodando")
	for p in m.all_players():
		assert_eq(p.desired_move, Vector3.ZERO, "sin control")
	_step(int(MatchController.WHISTLE_COAST / dt) + 2)
	# B10: primero se van caminando al túnel; después, la pantalla.
	assert_false(m.walk_off.is_empty(), "salen al túnel")
	_step(int(MatchController.WALK_OFF_TIME / dt) + 2)
	assert_true(m.halftime_screen.visible, "la pantalla de estadísticas")
	assert_eq(m.halftime_screen.stat_rows().size(), 10)
	# Espera al usuario (B10): no sigue sola.
	_step(int(MatchController.BREAK_AUTO_CONTINUE / dt) + 2)
	assert_eq(m.clock.half, 1, "espera")
	assert_true(m.halftime_screen.visible)
	m.start_second_half()
	assert_eq(m.clock.half, 2)
	assert_false(m.halftime_screen.visible)
	assert_eq(m.phase, MatchController.Phase.RESTART, "saque del medio del segundo tiempo")


func test_switch_prefers_the_pass_receiver_and_the_goal_side() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	var mm: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(mm)
	mm.set_physics_process(false)
	var h: HumanController = mm.humans[0]
	var t := h.team
	var a: Footballer = t.players[5]
	var b: Footballer = t.players[6]
	h.select(t.players[9])
	mm.ball.place(Vector3(0, 0.11, 0))
	mm.ball.owner_player = null
	mm.ball.intended_receiver = b
	a.teleport(Vector3(1, 0, 0))
	b.teleport(Vector3(20, 0, 0))
	assert_eq(h.switch_target(), b, "el que va a recibir")
	mm.ball.intended_receiver = null
	assert_eq(h.switch_target(), a, "si no, el que llega primero")
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)


func test_possession_and_corners_are_counted() -> void:
	var p: Footballer = m.teams[0].players[6]
	p.teleport(Vector3(0, 0, 0))
	m.ball.give_to(p)
	_step(60)
	# Cuenta para el que la tiene (o el último que la tocó): suman el tiempo.
	assert_gt(m.stats["possession"][0], 0.0)
	assert_almost_eq(m.stats["possession"][0] + m.stats["possession"][1], 1.0, 0.05)
	m.ball.owner_player = null
	m.ball.place(Vector3(m.teams[0].target_goal().x + m.teams[0].attack_dir * 0.6, 0.3, 10.0))
	m.ball.last_touch_team = 1
	m.ball.last_toucher = m.teams[1].players[4]
	_step(2)
	assert_eq(m.stats["corners"][0], 1, "córner para el que atacaba")


func test_replay_keeps_the_ball_spin_and_highlights() -> void:
	m.ball.place(Vector3(0, 0.11, 0))
	m.ball.state.vel = Vector3(10, 0, 0)
	for i in 120:
		m._physics_process(dt)
	var spin := m.ball.spin_pose()
	assert_false(spin.is_equal_approx(Quaternion.IDENTITY), "la pelota giró")
	var clip := m.replay.snapshot(Replay.Kind.CHANCE, 0, "prueba")
	assert_gt((clip["frames"] as Array).size(), 60)
	var last: Dictionary = clip["frames"][-1]
	assert_true(last.has("spin"), "se graba el giro")
	m.ball.replay_pose(Vector3(3, 0.11, 0), Quaternion.IDENTITY)
	m.ball.replay_pose(last["ball"], last["spin"])
	assert_true(m.ball.spin_pose().is_equal_approx(last["spin"]))


func test_offside_gets_a_replay_with_the_line() -> void:
	var t := m.teams[0]
	var p: Footballer = t.players[9]
	for i in 200:
		m._physics_process(dt) # para que haya cuadros grabados
	var line := m.offside_line(t)
	assert_true(is_finite(line))
	m.phase = MatchController.Phase.PLAYING
	m.call_offside(p, line)
	assert_eq(m.replay_request.get("kind"), Replay.Kind.OFFSIDE)
	assert_almost_eq(float(m.replay_request.get("line")), line, 0.001)
	GameSettings.replay_chances = true
	m._phase_timer = 0.0
	# Espera los segundos de después de la jugada (B10) y la muestra.
	for i in int((Replay.POST + 0.5) / dt):
		if m.phase == MatchController.Phase.REPLAY:
			break
		m._physics_process(dt)
	assert_eq(m.phase, MatchController.Phase.REPLAY, "se muestra la repetición")
	assert_almost_eq(m.replay.offside_line, line, 0.001)
	m.replay._wipe.advance(1.0)
	assert_true(m.replay._line_mesh != null and m.replay._line_mesh.visible, "la línea en el césped")
	assert_almost_eq(m.replay._line_mesh.position.x, line, 0.001)
