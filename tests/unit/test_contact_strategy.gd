extends GutTest
## Fase 4 (3): cuerpo a cuerpo, lesiones, habilidades especiales y
## estrategias.

var m: MatchController
var dt := 1.0 / 60.0


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	for p in m.all_players():
		p.locked = false


## Copia de los datos del jugador con otros atributos (sólo para este partido).
func _with(p: Footballer, values: Dictionary) -> void:
	var d := p.data.duplicate() as PlayerData
	for k in values:
		d.set(k, values[k])
	p.data = d


func test_strong_defender_wins_the_shoulder_charge() -> void:
	var df: Footballer = m.teams[1].players[2]
	var fw: Footballer = m.teams[0].players[9]
	_with(df, {"strength": 92, "balance": 85, "build": PlayerData.Build.MUSCULAR})
	_with(fw, {"strength": 35, "balance": 40, "build": PlayerData.Build.SLIM})
	assert_gt(m.contact_loss_chance(df, fw), 0.65, "el flaquito pierde casi siempre")
	assert_lt(m.contact_loss_chance(fw, df), 0.2, "al revés, casi nunca")


func test_losing_the_contact_staggers_and_frees_the_ball() -> void:
	var df: Footballer = m.teams[1].players[2]
	var fw: Footballer = m.teams[0].players[9]
	fw.teleport(Vector3(0, 0, 0), Vector3.RIGHT)
	m.ball.place(Vector3(0.4, 0.11, 0))
	m.ball.give_to(fw)
	m.resolve_contact(df, fw, true)
	assert_eq(fw.state, Footballer.State.RECOVERING, "trastabilla")
	assert_null(m.ball.owner_player, "la pelota queda suelta")
	assert_gt(df.contact_cooldown, 0.0)
	m.resolve_contact(df, fw, false)
	assert_eq(fw.state, Footballer.State.RECOVERING)


func test_running_side_by_side_produces_contacts() -> void:
	var df: Footballer = m.teams[1].players[2]
	var fw: Footballer = m.teams[0].players[9]
	var contacts := 0
	for i in 400:
		fw.state = Footballer.State.NORMAL
		df.state = Footballer.State.NORMAL
		fw.contact_cooldown = 0.0
		df.contact_cooldown = 0.0
		fw.teleport(Vector3(0, 0, 0), Vector3.RIGHT)
		df.teleport(Vector3(0, 0, 0.7), Vector3.RIGHT)
		fw.velocity = Vector3(6, 0, 0)
		df.velocity = Vector3(6, 0, 0)
		m.ball.place(Vector3(0.4, 0.11, 0))
		m.ball.give_to(fw)
		m._body_contact(dt)
		if fw.contact_cooldown > 0.0:
			contacts += 1
	assert_gt(contacts, 3, "corriendo a la par chocan de vez en cuando")
	assert_lt(contacts, 40, "pero no a cada rato")


func test_heavier_player_pushes_the_lighter_one() -> void:
	var a: Footballer = m.teams[0].players[5]
	var b: Footballer = m.teams[1].players[5]
	_with(a, {"strength": 95, "build": PlayerData.Build.HEAVY})
	_with(b, {"strength": 25, "build": PlayerData.Build.SLIM})
	for p in m.all_players():
		if p != a and p != b:
			p.teleport(Vector3(-40 + p.number, 0, -30 if p.team.index == 0 else 30))
	a.teleport(Vector3(0, 0, 0))
	b.teleport(Vector3(0.4, 0, 0))
	m._separate_players()
	assert_gt(b.global_position.x - 0.4, absf(a.global_position.x) * 1.5, "el liviano se corre más")


func test_serious_injury_slows_down_and_cpu_subs_him() -> void:
	var t := m.teams[1]
	var p: Footballer = t.players[6]
	var before := p.fatigue_speed_factor()
	m.injure(p, Footballer.Injury.SERIOUS)
	assert_lt(p.fatigue_speed_factor(), before * 0.8, "rengo")
	assert_eq(t.pending_subs.size(), 1, "la CPU pide el cambio")
	assert_eq(t.pending_subs[0]["out"], p)
	assert_eq(m.stats["injuries"][1], 1)


func test_abilities_help() -> void:
	var df: Footballer = m.teams[1].players[2]
	var fw: Footballer = m.teams[0].players[9]
	_with(fw, {"abilities": PackedStringArray()})
	_with(df, {"abilities": PackedStringArray()})
	var plain := m.tackle_chance(df, fw)
	_with(fw, {"abilities": PackedStringArray(["gambeteador"])})
	assert_lt(m.tackle_chance(df, fw), plain, "al gambeteador cuesta sacársela")
	_with(fw, {"abilities": PackedStringArray()})
	_with(df, {"abilities": PackedStringArray(["marcador"])})
	assert_gt(m.tackle_chance(df, fw), plain, "el marcador entra mejor")
	# Pasador: menos error en el pase.
	var mf: Footballer = m.teams[0].players[6]
	_with(mf, {"abilities": PackedStringArray()})
	m.kicks._pass_direction(mf, Vector3(20, 0, 0), Vector3.ZERO, 0.5)
	var err := m.kicks.last_error
	_with(mf, {"abilities": PackedStringArray(["pasador"])})
	m.kicks._pass_direction(mf, Vector3(20, 0, 0), Vector3.ZERO, 0.5)
	assert_lt(m.kicks.last_error, err)


func test_generated_squads_have_abilities() -> void:
	var count := 0
	for t in m.teams:
		for d in t.data.players:
			count += d.abilities.size()
	assert_gt(count, 8)


func test_strategies_change_the_shape() -> void:
	var f := m.teams[0].formation
	var ball := Vector2(0.5, 0.0)
	var none := TeamShape.compute(f, TeamShape.State.DEFENDING, ball, Strategy.Kind.NONE)
	var trap := TeamShape.compute(f, TeamShape.State.DEFENDING, ball, Strategy.Kind.OFFSIDE_TRAP)
	var attack := TeamShape.compute(f, TeamShape.State.ATTACKING, ball, Strategy.Kind.ALL_ATTACK)
	var normal_attack := TeamShape.compute(f, TeamShape.State.ATTACKING, ball, Strategy.Kind.NONE)
	var back := TeamShape.compute(f, TeamShape.State.DEFENDING, ball, Strategy.Kind.ALL_DEFENSE)
	for i in f.slots.size():
		if TacticalRole.is_defender(f.tactical_role(i)):
			assert_gt(trap[i].x, none[i].x, "trampa: la línea sube")
	assert_gt(attack[9].x, normal_attack[9].x - 0.001, "todos al ataque")
	assert_lt(back[6].x, none[6].x, "todos atrás")


func test_l2_plus_button_toggles_a_strategy_without_kicking() -> void:
	var t := m.teams[0]
	var inp := ScriptedInput.new()
	m.humans[0].input = inp
	var p: Footballer = t.players[6]
	p.teleport(Vector3(-20, 0, 0), Vector3.RIGHT)
	m.ball.place(Vector3(-19.6, 0.11, 0))
	m.ball.give_to(p)
	m.humans[0].select(p)
	var kicks := m.kick_count
	inp.hold(&"strategy")
	m.humans[0].tick(dt)
	inp.hold(&"pass_short")
	m.humans[0].tick(dt)
	assert_eq(t.strategy, t.strategy_slots[0], "L2 + X: la estrategia del botón X")
	inp.release(&"strategy")
	for i in 20:
		m.humans[0].tick(dt)
	inp.release(&"pass_short")
	for i in 5:
		m.humans[0].tick(dt)
	assert_eq(m.kick_count, kicks, "el botón no pateó")
	inp.hold(&"strategy")
	m.humans[0].tick(dt)
	inp.hold(&"pass_short")
	m.humans[0].tick(dt)
	assert_eq(t.strategy, Strategy.Kind.NONE, "otra vez: se apaga")


func test_pressing_strategy_presses_all_over() -> void:
	var t := m.teams[1]
	var ai: TeamAI = m.ais[1]
	t.strategy = Strategy.Kind.PRESSING
	ai._possession_team = 0
	ai._possession_since = ai._time - 20.0
	var carrier: Footballer = m.teams[0].players[6]
	carrier.teleport(t.to_world(Vector2(0.6, 0.0)))
	m.ball.place(carrier.flat_pos() + Vector3(0, 0.11, 0))
	m.ball.give_to(carrier)
	ai._update_state(m.ball)
	assert_eq(ai.state, TeamShape.State.PRESSING)


func test_cpu_goes_all_out_when_losing_late() -> void:
	var t := m.teams[1]
	m.teams[0].score = 1
	m.clock.half = 2
	m.clock.game_seconds = 30.0 * 60.0
	m._cpu_strategy(t)
	assert_eq(t.strategy, Strategy.Kind.ALL_ATTACK)
	m.teams[0].score = 0
	t.score = 1
	m.clock.game_seconds = 38.0 * 60.0
	m._cpu_strategy(t)
	assert_eq(t.strategy, Strategy.Kind.ALL_DEFENSE)


func test_sheet_assigns_strategies_to_buttons() -> void:
	var t := m.teams[0]
	var sh := TeamSheet.new()
	add_child_autofree(sh)
	sh.open(m, t, false)
	var before := t.strategy_slots.duplicate()
	sh.cycle_strategy_slot(0)
	assert_ne(t.strategy_slots[0], before[0])
	var seen := {}
	for k in t.strategy_slots:
		assert_false(seen.has(k), "sin repetir")
		seen[k] = true
		assert_ne(k, Strategy.Kind.NONE)
