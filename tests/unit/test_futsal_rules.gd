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


# --- Árbitros ---------------------------------------------------------------

func test_two_referees_on_the_touchlines_and_a_fourth_by_the_benches() -> void:
	assert_not_null(m.referee2)
	assert_eq(m.referee.line_side, -1)
	assert_eq(m.referee2.line_side, 1)
	m.ball.place(Vector3(4.0, m.tuning.ball_radius, 2.0))
	for i in 240:
		m.referee.tick(dt, m.ball.global_position, true)
		m.referee2.tick(dt, m.ball.global_position, true)
	for r in [m.referee, m.referee2]:
		assert_gt(absf(r.global_position.z), Pitch.HALF_WIDTH, "por afuera de la banda")
	# En diagonal: uno hacia cada arco respecto de la pelota.
	assert_gt(m.referee.global_position.x, 4.0)
	assert_lt(m.referee2.global_position.x, 4.0)
	assert_true(m.fourth_official.bench_walker)
	for i in 600:
		m.fourth_official.tick(dt, m.ball.global_position, false)
		assert_between(m.fourth_official.global_position.z, Pitch.HALF_WIDTH + 0.5, Pitch.HALF_WIDTH + 2.5, "entre la banda y los bancos")


func test_kick_in_referee_points_and_counts() -> void:
	var out := MatchRules.Outcome.new(MatchRules.Restart.THROW_IN, 0, Vector3(3.0, m.tuning.ball_radius, Pitch.HALF_WIDTH))
	m._setup_restart(out)
	var r := m.referee2
	assert_eq(r.line_side, 1, "el de esa banda")
	var events: Array = r._steps.map(func(st: Dictionary) -> int: return int(st["event"]))
	assert_eq(events, [PlayerVisual.Event.REF_POINT, PlayerVisual.Event.REF_COUNT])
	assert_false(m._officials_ready(), "primero señala")
	for i in 400:
		m._physics_process(dt)
		if m._officials_ready():
			break
	assert_true(m._officials_ready())
	assert_lt(m._restart_elapsed, 0.5, "los 4 s arrancan después de la seña")


func test_wall_at_five_meters_and_referee_paces_it() -> void:
	assert_eq(Pitch.RESTART_DISTANCE, 5.0)
	var t0 := m.teams[0]
	var spot := t0.target_goal() - Vector3(t0.attack_dir * 9.0, 0, -2.0)
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.FREE_KICK, 0, spot + Vector3.UP * m.tuning.ball_radius))
	assert_between(m.wall_targets.size(), 1, 2, "barrera de 2 como mucho")
	for p: Footballer in m.wall_targets:
		assert_almost_eq(p.flat_pos().distance_to(Vector3(spot.x, 0, spot.z)), 5.0, 0.8, "a 5 m")
	var r := m.nearest_line_ref(spot)
	var events: Array = r._steps.map(func(st: Dictionary) -> int: return int(st["event"]))
	assert_true(events.has(PlayerVisual.Event.REF_WALL), "marca la barrera")
	assert_true(r._steps.any(func(st: Dictionary) -> bool: return st["walk"]), "caminando")


func test_foul_referee_enters_and_signals_the_table() -> void:
	var victim := _outfield(m.teams[0])
	var offender := _outfield(m.teams[1])
	var spot := Vector3(-m.teams[0].attack_dir * 5.0, 0, 2.0)
	victim.teleport(spot, Vector3.RIGHT)
	offender.teleport(spot - Vector3(0.8, 0, 0), Vector3.RIGHT)
	var r := m.nearest_line_ref(spot)
	seed(3)
	m.call_foul(offender, victim, false)
	var events: Array = r._steps.map(func(st: Dictionary) -> int: return int(st["event"]))
	if m.card_scene.is_empty():
		assert_eq(events, [PlayerVisual.Event.REF_POINT, PlayerVisual.Event.REF_TABLE])
	var entry: Vector3 = r._steps[0]["to"]
	assert_lt(absf(entry.z), Pitch.HALF_WIDTH, "entra a la cancha")


func test_arm_toward() -> void:
	# El modelo mira hacia +Z con la derecha hacia -X; mirando hacia -Z, la
	# derecha queda hacia +X.
	assert_eq(Referee.arm_toward(Vector3(-1, 0, 0), Vector3(0, 0, 1)), 1.0)
	assert_eq(Referee.arm_toward(Vector3(1, 0, 0), Vector3(0, 0, -1)), 1.0)
	assert_eq(Referee.arm_toward(Vector3(-1, 0, 0), Vector3(0, 0, -1)), -1.0)


# --- F3: cambios volantes e IA a escala ---------------------------------------

func test_flying_sub_goes_to_the_zone_and_returns_to_the_bench() -> void:
	var t := m.teams[0]
	assert_eq(t.subs_left(), 99, "sin límite de cambios")
	var out := _outfield(t)
	var in_data: PlayerData = t.next_quartet()[0]
	out.stamina = 30.0
	assert_true(m.request_flying_sub(out, in_data))
	assert_true(m.is_heading_off(out))
	var zone := m.flying_zone(t)
	assert_gt(zone.z, Pitch.HALF_WIDTH, "del lado de los bancos")
	assert_lt(zone.x * t.attack_dir, 0.0, "en su campo")
	m.ball.place(Vector3(-t.attack_dir * 3.0, m.tuning.ball_radius, -6.0))
	for i in 60 * 9:
		m._physics_process(dt)
		if not m.is_heading_off(out):
			break
	assert_false(t.players.has(out), "salió")
	assert_true(t.bench.has(out.base_data), "vuelve al banco: puede volver a entrar")
	assert_false(t.bench.has(in_data))
	assert_eq(m.sub_scenes.size(), 0, "sin parar el juego")
	var e: Dictionary = t.bench_energy[out.base_data]
	assert_almost_eq(float(e["stamina"]), 30.0, 15.0)
	t.rest_bench(5.0)
	assert_gt(t.bench_stamina(out.base_data), float(e["stamina"]) - 0.01, "descansa en el banco")


## El que salió en un cambio volante no vuelve a aparecer en la cancha después
## de una repetición (la repetición lo muestra y antes quedaba parado ahí).
func test_flying_sub_ghost_hidden_after_replay() -> void:
	var t := m.teams[0]
	var out := _outfield(t)
	var in_data: PlayerData = t.next_quartet()[0]
	m.phase = MatchController.Phase.STOPPED
	assert_true(m.request_sub(out, in_data))
	assert_false(t.players.has(out), "salió")
	assert_false(out.visible)
	out.visible = true # la repetición lo vuelve a mostrar
	m._on_replay_finished()
	assert_false(out.visible, "no queda un sexto jugador en la cancha")
	var on := 0
	for c in m.get_children():
		if c is Footballer and (c as Footballer).visible and (c as Footballer).team == t:
			on += 1
	assert_eq(on, 5, "5 en la cancha")


## Dirección del equipo en futsal: 5 titulares y 9 suplentes (los demás
## del plantel no entran a la lista); la minicancha es del piso elegido.
func test_team_sheet_five_starters_and_floor_colors() -> void:
	var t := m.teams[0]
	var sh := TeamSheet.new()
	add_child_autofree(sh)
	sh.open(m, t, true)
	var caps: Array = []
	var rows := 0
	for c in sh._list.get_children():
		if c is Label:
			caps.append([(c as Label).text, rows])
		else:
			rows += 1
	assert_eq(caps, [["TITULARES", 0], ["SUPLENTES", 5]])
	assert_eq(rows, 5 + Discipline.bench_size())
	var saved := GameSettings.court_surface
	GameSettings.court_surface = 1
	assert_eq(WEStyle.pitch_stripes()[1], Discipline.surface(1)[1], "pista azul")
	GameSettings.court_surface = saved


func test_quick_flying_sub_takes_off_the_most_tired() -> void:
	var t := m.teams[1]
	var tired := _outfield(t)
	for p in t.players:
		p.stamina = 90.0
	tired.stamina = 20.0
	assert_true(m.quick_flying_sub(t))
	assert_eq(m.flying[0]["out"], tired)


func test_quartet_rotation() -> void:
	var t := m.teams[0]
	t.rotation_minutes = 5.0
	t.last_rotation = 0.0
	m.clock.game_seconds = 5.0 * 60.0 + 1.0
	m._flying_auto(dt)
	var outs := m.flying.filter(func(f: Dictionary) -> bool: return f["out"].team == t)
	assert_eq(outs.size(), 4, "sale el cuarteto entero (de a dos)")


func test_ai_distances_scale_with_the_court() -> void:
	assert_lt(TeamAI.shoot_distance(), Pitch.HALF_LENGTH, "no remata desde su campo")
	assert_almost_eq(Pitch.g(3.66), Pitch.GOAL_HALF_WIDTH, 0.001, "puntería al arco de 3 m")
	assert_lt(m.tuning.short_pass_max_distance, 35.0, "pases más cortos")
	Discipline.use(Discipline.FOOTBALL)
	assert_eq(Pitch.s(10.0), 10.0)
	assert_eq(Pitch.h(10.0), 10.0)
	assert_eq(TeamAI.shoot_distance(), TeamAI.SHOOT_DISTANCE, "el fútbol no cambia")
	Discipline.use(Discipline.FUTSAL)


# --- F4: arquero jugador --------------------------------------------------------

func _attack_with(t: Team) -> Footballer:
	var carrier := _outfield(t)
	var spot := Vector3(t.attack_dir * 6.0, 0.0, -3.0)
	carrier.teleport(spot, Vector3(t.attack_dir, 0, 0))
	m.ball.place(spot + Vector3(t.attack_dir * 0.4, m.tuning.ball_radius, 0))
	m.ball.give_to(carrier)
	return carrier


func _run_until(cond: Callable, max_steps: int = 60 * 12) -> void:
	for i in max_steps:
		if cond.call():
			return
		m._drive_flying_subs(dt)
		m._drive_keeper_player()
		for p in m.all_players():
			# Avanza al que va a la zona de cambio (sin la simulación completa).
			if m.is_heading_off(p):
				var to := m.flying_zone(p.team) - p.flat_pos()
				p.teleport(p.flat_pos() + to.limit_length(0.3), p.facing)


func test_keeper_player_cycle() -> void:
	var t := m.teams[0]
	var gk := t.keeper()
	m.toggle_keeper_player(t)
	assert_true(t.keeper_player)
	_attack_with(t)
	m._drive_keeper_player()
	assert_eq(m.keeper_player_state(t), MatchController.KeeperPlayer.GOING_OUT)
	assert_true(m.is_heading_off(gk), "el arquero va a la zona de cambio")
	_run_until(func() -> bool: return m.keeper_player_state(t) == MatchController.KeeperPlayer.IN)
	assert_null(t.keeper(), "arco vacío: 5 contra 4")
	var fp: Footballer = m._kp[0]["player"]
	assert_true(fp.keeper_shirt, "con camiseta de arquero")
	assert_false(fp.is_keeper(), "juega de campo (sin manos)")
	assert_eq(fp.kit_colors()["shirt"], t.keeper_color)
	assert_eq(t.players.filter(func(p: Footballer) -> bool: return not p.is_keeper()).size(), 5)
	# Pierde la pelota: sale el arquero jugador y vuelve el arquero.
	m.ball.give_to(_outfield(m.teams[1]))
	m._drive_keeper_player()
	assert_eq(m.keeper_player_state(t), MatchController.KeeperPlayer.GOING_BACK)
	_run_until(func() -> bool: return m.keeper_player_state(t) == MatchController.KeeperPlayer.OFF)
	assert_not_null(t.keeper(), "volvió el arquero")
	assert_eq(t.keeper().base_data, gk.base_data)


func test_keeper_back_at_kickoff_and_rival_restart() -> void:
	var t := m.teams[1]
	m.toggle_keeper_player(t)
	_attack_with(t)
	m._drive_keeper_player()
	_run_until(func() -> bool: return m.keeper_player_state(t) == MatchController.KeeperPlayer.IN)
	assert_null(t.keeper())
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.THROW_IN, 0, Vector3(2.0, m.tuning.ball_radius, Pitch.HALF_WIDTH)))
	assert_not_null(t.keeper(), "saca el rival: vuelve el arquero")
	assert_eq(m.keeper_player_state(t), MatchController.KeeperPlayer.OFF)
	assert_lt(t.keeper().flat_pos().distance_to(t.own_goal()), 2.5, "en su arco")


func test_cpu_uses_keeper_player_when_losing_late() -> void:
	var t := m.teams[1]
	t.score = 1
	m.teams[0].score = 2
	m.clock.game_seconds = m.clock.half_seconds * 0.8
	m.clock.half = 2
	m._flying_cpu_t = 5.0
	m._flying_auto(dt)
	assert_true(t.keeper_player, "pierde por 1 al final")
	assert_false(m.teams[0].keeper_player)
