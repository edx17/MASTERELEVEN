extends GutTest
## Fase 4: cambios (banco, 3 por partido), arquero expulsado y cansancio
## acumulado.

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


func _bench_of(t: Team, pos: int) -> PlayerData:
	for d in t.bench:
		if d.position == pos:
			return d
	return null


func test_bench_and_substitution_keep_the_slot() -> void:
	var t := m.teams[0]
	assert_eq(t.bench.size(), 5, "cinco suplentes")
	assert_not_null(t.bench_keeper(), "con arquero suplente")
	var out: Footballer = t.players[9]
	var slot := t.slot_of(out)
	var where := out.flat_pos()
	var d := _bench_of(t, PlayerData.Position.FW)
	m.phase = MatchController.Phase.STOPPED
	var p := m.substitute(out, d)
	assert_not_null(p)
	assert_eq(t.slot_of(p), slot, "entra en el puesto del que sale")
	assert_eq(t.players.size(), 11)
	assert_false(t.players.has(out))
	assert_false(out.visible)
	assert_eq(p.number, d.number)
	assert_eq(p.base_spot, out.base_spot)
	assert_almost_eq(p.flat_pos().distance_to(where), 0.0, 0.01)
	assert_false(t.bench.has(d), "ya no está en el banco")
	assert_eq(t.subs_used, 1)
	assert_eq(m.stats["subs"][0], 1)


func test_only_three_substitutions() -> void:
	var t := m.teams[1]
	m.phase = MatchController.Phase.STOPPED
	for i in 3:
		var d: PlayerData = null
		for b in t.bench:
			if b.position != PlayerData.Position.GK:
				d = b
				break
		assert_not_null(m.substitute(t.players[2 + i], d))
	assert_eq(t.subs_left(), 0)
	assert_null(m.substitute(t.players[8], t.bench[0]), "el cuarto no")
	assert_false(m.request_sub(t.players[8], t.bench[0]))


func test_requested_sub_waits_for_a_stoppage() -> void:
	var t := m.teams[0]
	var out: Footballer = t.players[7]
	var d := _bench_of(t, PlayerData.Position.MF)
	assert_true(m.request_sub(out, d))
	assert_true(t.players.has(out), "con la pelota en juego, espera")
	assert_eq(t.subs_left(), 2, "el pedido ya cuenta")
	m._pending = MatchRules.Outcome.new(MatchRules.Restart.THROW_IN, 1, Vector3(0, 0.11, Pitch.HALF_WIDTH))
	m._setup_restart(m._pending)
	assert_false(t.players.has(out), "en la pelota parada, sale")
	assert_eq(t.subs_used, 1)


func test_keeper_can_be_sent_off_and_the_sub_keeper_comes_on() -> void:
	var t := m.teams[1]
	var gk := t.keeper()
	var sub := t.bench_keeper()
	m.phase = MatchController.Phase.PLAYING
	m.send_off(gk)
	assert_true(gk.sent_off)
	var new_gk := t.keeper()
	assert_not_null(new_gk, "nunca queda el arco vacío")
	assert_eq(new_gk.data, sub, "entra el arquero suplente")
	assert_eq(t.slot_of(new_gk), 0, "en el puesto del arquero")
	assert_eq(t.players.size(), 10, "sale un jugador de campo: quedan 10")
	assert_eq(t.subs_used, 1)
	var fw := 0
	for p in t.subbed_off:
		if p.role == Footballer.Role.FW:
			fw += 1
	assert_eq(fw, 1, "sale un delantero")
	assert_lt(new_gk.flat_pos().distance_to(t.own_goal()), 20.0, "va al arco")


func test_keeper_sent_off_without_subs_an_outfield_player_goes_in_goal() -> void:
	var t := m.teams[0]
	t.subs_used = Team.MAX_SUBS
	var gk := t.keeper()
	m.send_off(gk)
	var new_gk := t.keeper()
	assert_not_null(new_gk)
	assert_ne(new_gk.data.position, PlayerData.Position.GK, "es un jugador de campo")
	assert_eq(t.slot_of(new_gk), 0)
	assert_eq(t.players.size(), 10)
	var kit := new_gk.kit_colors()
	assert_eq(kit["shirt"], t.keeper_color, "con la ropa de arquero")
	assert_eq(kit["number"], new_gk.data.number, "y su propio número")
	assert_true(new_gk.data.position == PlayerData.Position.DF, "va un defensor")
	if new_gk.visual is ModelVisual:
		var mv := new_gk.visual as ModelVisual
		assert_eq(mv._body_mat.get_shader_parameter("shirt"), t.keeper_color, "se ve con la camiseta de arquero")
		assert_eq(mv._number_label.text, str(new_gk.number))


func test_keeper_second_yellow_is_a_red_too() -> void:
	var t1 := m.teams[1]
	var gk := t1.keeper()
	gk.yellow_cards = 1
	var vic: Footballer = m.teams[0].players[9]
	vic.teleport(Vector3(0, 0, 0), Vector3(1, 0, 0))
	gk.teleport(Vector3(0, 0, 1.0), Vector3(0, 0, -1))
	for i in 80:
		if gk.sent_off:
			break
		m.phase = MatchController.Phase.PLAYING
		m.call_foul(gk, vic, true) # barrida de costado: amarilla seguido
	assert_true(gk.sent_off, "al arquero también lo echan")
	assert_not_null(t1.keeper())


func test_wear_lowers_the_stamina_cap_and_halftime_restores_part() -> void:
	var p: Footballer = m.teams[0].players[5]
	p.velocity = Vector3(m.tuning.sprint_speed, 0, 0)
	p.desired_move = Vector3(1, 0, 0)
	p.wants_sprint = true
	p.accumulate_wear(60.0)
	var sprint_minute := p.wear
	p.wear = 0.0
	p.wants_sprint = false
	p.velocity = Vector3(5.0, 0, 0)
	for i in 45:
		p.accumulate_wear(60.0)
	assert_gt(p.wear, 8.0, "45 minutos trotando cansan")
	assert_gt(sprint_minute, p.wear / 45.0 * 2.0, "en sprint, mucho más")
	assert_lt(p.stamina, 100.0 - 8.0 + 0.01, "la energía no pasa del tope")
	var before := p.wear
	p.rest_at_halftime()
	assert_almost_eq(p.wear, before * (1.0 - m.tuning.wear_halftime_recovery), 0.01)
	assert_almost_eq(p.stamina, p.stamina_cap(), 0.01)
	p.stamina = 100.0
	p.wear = m.tuning.wear_max
	assert_lt(p.fatigue_speed_factor(), 0.96, "gastado, corre menos")


func test_wear_follows_the_match_clock() -> void:
	m.clock.running = true
	m.phase = MatchController.Phase.PLAYING
	m.set_physics_process(false)
	for i in 120:
		m._physics_process(dt)
	var any := 0.0
	for p in m.all_players():
		any = maxf(any, p.wear)
	assert_gt(any, 0.0)


func test_cpu_subs_a_tired_player_after_minute_55() -> void:
	var t := m.teams[1]
	var tired: Footballer = t.players[8]
	tired.wear = 30.0
	tired.stamina = 30.0
	m._cpu_subs(t)
	assert_eq(t.pending_subs.size(), 0, "antes del 55 no")
	m.clock.half = 2
	m.clock.game_seconds = 15.0 * 60.0
	m._cpu_subs(t)
	assert_eq(t.pending_subs.size(), 1)
	assert_eq(t.pending_subs[0]["out"], tired, "sale el cansado")
	m._make_pending_subs()
	assert_false(t.players.has(tired))
