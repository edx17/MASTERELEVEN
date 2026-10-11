extends GutTest
## Futsal F2: reglamento FIFA (reloj 2 x 20, lateral con el pie, saque de
## arco con la mano, 4 segundos, pase atrás al arquero, faltas acumuladas y
## doble penal sin barrera).

var m: MatchController
var dt := 1.0 / 60.0
var _saved := {}


func before_each() -> void:
	for k in ["database", "home_team_path", "away_team_path", "match_minutes"]:
		_saved[k] = GameSettings.get(k)
	GameSettings.use_database("futsal_afa")
	GameSettings.match_minutes = 10
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	for p in m.all_players():
		p.locked = false


func after_each() -> void:
	GameSettings.use_database(TeamDB.DEFAULT_DB)
	for k in _saved:
		GameSettings.set(k, _saved[k])


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


func _until_restart() -> void:
	for i in 900:
		if m.phase == MatchController.Phase.RESTART:
			return
		m._physics_process(dt)


func _outfield(t: Team) -> Footballer:
	for p in t.players:
		if not p.is_keeper():
			return p
	return null


func test_five_a_side_and_two_halves_of_twenty() -> void:
	assert_eq(m.teams[0].players.size(), 5)
	assert_eq(m.clock.half_seconds, 20.0 * 60.0, "tiempos de 20'")
	# 10 minutos reales de partido: 5 por tiempo para los 20' (con la pelota en juego).
	assert_almost_eq(m.clock.rate(), 4.0, 0.001)
	m.clock.game_seconds = 20.0 * 60.0
	assert_true(m.clock.is_half_over())
	m.clock.start_second_half()
	assert_eq(m.clock.display(), "20:00", "el segundo tiempo arranca en 20:00")
	assert_almost_eq(m.clock.football_minute(), 45.0, 0.01, "para la CPU es el minuto 45")


func test_clock_stops_with_the_ball_out_of_play() -> void:
	m.phase = MatchController.Phase.STOPPED
	m._phase_timer = INF
	var g0 := m.clock.game_seconds
	_step(30)
	assert_eq(m.clock.game_seconds, g0, "reloj parado")


func test_kick_in_is_taken_with_the_foot() -> void:
	var t0 := m.teams[0]
	var out := MatchRules.Outcome.new(MatchRules.Restart.THROW_IN, 0, Vector3(3.0, m.tuning.ball_radius, Pitch.HALF_WIDTH))
	m._setup_restart(out)
	assert_eq(m.restart_type, MatchRules.Restart.THROW_IN)
	m._update_throw_in_hold()
	assert_false(m.restart_taker.visual != null and m.restart_taker.visual.throw_hold, "no la levanta con las manos")
	var taker := m.restart_taker
	m._restart_elapsed = 2.0
	m.perform_kick(taker, KickActions.Kind.SHORT_PASS, Vector3(0, 0, -1), 0.5)
	assert_eq(m.phase, MatchController.Phase.PLAYING)
	assert_lt(m.ball.state.pos.y, 1.0, "sale del pie, no desde arriba de la cabeza")
	assert_eq(t0.index, 0)


func test_goal_clearance_is_by_hand_from_the_area() -> void:
	var t1 := m.teams[1]
	var side := t1.own_side()
	var o := MatchRules.check(Vector3(side * (Pitch.HALF_LENGTH + 0.5), 0.1, 4.0), m.tuning.ball_radius, 0, m.attack_dirs())
	assert_eq(o.type, MatchRules.Restart.GOAL_KICK)
	assert_true(Pitch.in_penalty_area(o.spot, side), "en el área, cerca del arco")
	m._setup_restart(o)
	assert_true(m.hand_clearance())
	assert_eq(m.restart_taker, t1.keeper())
	assert_true(m.ball.in_hands, "el arquero la tiene en las manos")
	assert_false(m.runup_in_progress(), "sin carrera")
	m._restart_elapsed = 2.0
	m.perform_kick(t1.keeper(), KickActions.Kind.SHOT, Vector3(-side, 0, 0), 0.8)
	assert_eq(m.phase, MatchController.Phase.PLAYING)
	assert_eq(m.stats["shots"][1], 0, "con la mano no es remate")
	assert_false(m.ball.in_hands)


func test_four_seconds_on_a_kick_in_gives_it_to_the_rival() -> void:
	var out := MatchRules.Outcome.new(MatchRules.Restart.THROW_IN, 0, Vector3(3.0, m.tuning.ball_radius, Pitch.HALF_WIDTH))
	m._setup_restart(out)
	m._restart_elapsed = MatchController.restart_limit() + 0.1
	m._check_throw_in_limit()
	assert_eq(m.phase, MatchController.Phase.STOPPED)
	assert_eq(m._pending.type, MatchRules.Restart.THROW_IN)
	assert_eq(m._pending.team, 1, "lateral para el rival")
	assert_eq(MatchController.restart_limit(), 4.0)


func test_four_seconds_on_a_goal_clearance_is_an_indirect_kick() -> void:
	var t1 := m.teams[1]
	var o := MatchRules.Outcome.new(MatchRules.Restart.GOAL_KICK, 1,
		MatchController.clearance_spot(t1.own_side(), 0.0) + Vector3.UP * m.tuning.ball_radius)
	m._setup_restart(o)
	m._restart_elapsed = 4.1
	m._check_throw_in_limit()
	assert_eq(m._pending.type, MatchRules.Restart.FREE_KICK)
	assert_eq(m._pending.team, 0)
	assert_false(Pitch.in_penalty_area(m._pending.spot, t1.own_side()), "en la línea del área")


func test_keeper_four_seconds_with_the_ball_in_his_half() -> void:
	var gk := m.teams[0].keeper()
	gk.teleport(m.teams[0].own_goal() + Vector3(-m.teams[0].own_side() * 3.0, 0, 0), Vector3.RIGHT)
	m.ball.give_to(gk)
	m.hands_time = 0.0
	m._update_keeper_hands(3.9)
	assert_eq(m.phase, MatchController.Phase.PLAYING)
	assert_gt(m.hands_time_left(), 0.0, "el HUD muestra la cuenta también con los pies")
	m._update_keeper_hands(0.2)
	assert_eq(m.phase, MatchController.Phase.STOPPED)
	assert_eq(m._pending.type, MatchRules.Restart.FREE_KICK)
	assert_eq(m._pending.team, 1, "indirecto para el rival")


func test_keeper_cannot_touch_it_again_after_a_teammate() -> void:
	var t0 := m.teams[0]
	var gk := t0.keeper()
	var mate := _outfield(t0)
	var own := t0.own_side()
	gk.teleport(Vector3(own * 15.0, 0, 0), Vector3.RIGHT)
	mate.teleport(Vector3(own * 10.0, 0, 3), Vector3.RIGHT)
	m.ball.place(Vector3(own * 12.0, m.tuning.ball_radius, 0))
	m.ball.give_to(gk)
	m._on_keeper_kick(gk)
	assert_eq(m.keeper_played, gk)
	m.ball.give_to(mate)
	m._check_keeper_second_touch()
	assert_true(m.keeper_locked(gk), "ya la tocó un compañero")
	m.ball.give_to(gk)
	m._check_keeper_second_touch()
	assert_eq(m.phase, MatchController.Phase.STOPPED, "pase atrás: indirecto")
	assert_eq(m._pending.team, 1)


func test_rival_touch_frees_the_keeper() -> void:
	var t0 := m.teams[0]
	var gk := t0.keeper()
	gk.teleport(Vector3(t0.own_side() * 15.0, 0, 0), Vector3.RIGHT)
	m.ball.place(Vector3(t0.own_side() * 12.0, m.tuning.ball_radius, 0))
	m.ball.give_to(gk)
	m._on_keeper_kick(gk)
	m.ball.give_to(_outfield(m.teams[1]))
	m._check_keeper_second_touch()
	assert_null(m.keeper_played, "la tocó un rival: el arquero ya puede")


func test_accumulated_fouls_and_free_kick_without_wall() -> void:
	var t0 := m.teams[0]
	var t1 := m.teams[1]
	var victim := _outfield(t0)
	var offender := _outfield(t1)
	# Falta en campo propio de t0, lejos del arco rival.
	var spot := Vector3(-t0.attack_dir * 5.0, 0, 2.0)
	for i in 5:
		m.phase = MatchController.Phase.PLAYING
		victim.teleport(spot, Vector3.RIGHT)
		offender.teleport(spot - Vector3(0.8, 0, 0), Vector3.RIGHT)
		m.call_foul(offender, victim, false)
		assert_false(m.free_kick_no_wall, "hasta la 5.ª, con barrera")
	assert_eq(m.stats["acc_fouls"][1], 5)
	m.phase = MatchController.Phase.PLAYING
	victim.teleport(spot, Vector3.RIGHT)
	m.call_foul(offender, victim, false)
	assert_eq(m.stats["acc_fouls"][1], 6)
	assert_true(m.free_kick_no_wall, "6.ª: sin barrera")
	assert_almost_eq(m._pending.spot.x, m.second_penalty_spot(t1).x, 0.01, "desde el doble penal")
	assert_eq(m._pending.spot.z, 0.0)
	_until_restart()
	assert_eq(m.restart_type, MatchRules.Restart.FREE_KICK)
	assert_true(m.wall_targets.is_empty(), "sin barrera")
	var ball_x := m.ball.flat_pos().x
	for p in t1.players:
		if p.is_keeper():
			continue
		assert_true((p.flat_pos().x - ball_x) * t1.own_side() <= -1.0, "detrás de la pelota: " + p.display_name)
		assert_gte(p.flat_pos().distance_to(m.ball.flat_pos()), 4.9, "a 5 m")


func test_accumulated_fouls_reset_each_half() -> void:
	m.stats["acc_fouls"] = [4, 6]
	m.phase = MatchController.Phase.HALFTIME
	m.start_second_half()
	assert_eq(m.stats["acc_fouls"], [0, 0])


func test_rounded_penalty_area() -> void:
	var side := 1
	var gx := Pitch.HALF_LENGTH
	assert_true(Pitch.in_penalty_area(Vector3(gx - 5.9, 0, 0), side), "frente al arco, 6 m")
	assert_false(Pitch.in_penalty_area(Vector3(gx - 5.9, 0, 7.0), side), "la esquina del rectángulo queda afuera")
	assert_true(Pitch.in_penalty_area(Vector3(gx - 1.0, 0, 7.0), side), "pegado a la línea de fondo, sí")


func test_football_rules_unchanged() -> void:
	GameSettings.use_database(TeamDB.DEFAULT_DB)
	assert_eq(MatchController.restart_limit(), 6.0)
	assert_eq(MatchController.keeper_limit(), 6.0)
	assert_null(Discipline.rule("foul_limit"))
	assert_false(MatchController.hand_clearance_for(MatchRules.Restart.GOAL_KICK))
	var c := MatchClock.new(10.0)
	assert_eq(c.half_seconds, 45.0 * 60.0)
