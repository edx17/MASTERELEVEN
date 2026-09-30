extends GutTest
## IA de equipo: estados, acompañamiento del ataque y pelotas paradas.

var m: MatchController
var dt := 1.0 / 60.0


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate() as MatchController
	add_child_autofree(m)
	m.set_physics_process(false)


func _play_with_ball_at(owner: Footballer, pos: Vector3) -> void:
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	for p in m.all_players():
		p.locked = false
	owner.teleport(pos - Vector3(owner.team.attack_dir * 0.5, 0, 0), Vector3(owner.team.attack_dir, 0, 0))
	m.ball.place(pos)
	m.ball.give_to(owner)


func _run(seconds: float) -> void:
	for i in int(seconds / dt):
		m._physics_process(dt)


func _avg_x(team: Team, exclude: Footballer) -> float:
	var s := 0.0
	var n := 0
	for p in team.players:
		if p != exclude and not p.is_keeper():
			s += team.progress_of(p.flat_pos())
			n += 1
	return s / n


func test_states_follow_possession_and_zone() -> void:
	var t0 := m.teams[0]
	var carrier: Footballer = t0.players[2]
	_play_with_ball_at(carrier, t0.to_world(Vector2(0.15, 0.0)) + Vector3(0, 0.11, 0))
	_run(0.3)
	assert_eq(m.ais[0].state, TeamShape.State.BUILD_UP, "pelota en campo propio: salida")
	assert_true(m.ais[1].state in [TeamShape.State.DEFENDING, TeamShape.State.PRESSING], "el rival defiende o presiona")
	var fwd: Footballer = t0.players[9]
	_play_with_ball_at(fwd, t0.to_world(Vector2(0.72, 0.1)) + Vector3(0, 0.11, 0))
	m.ais[0]._possession_since = -100.0 # posesión asentada (no contraataque)
	_run(0.3)
	assert_eq(m.ais[0].state, TeamShape.State.ATTACKING, "pelota en campo rival: ataque")


func test_team_follows_the_carrier_forward() -> void:
	# El reclamo: "cuando avanza un jugador con la pelota el resto se queda".
	var t0 := m.teams[0]
	var carrier: Footballer = t0.players[6]
	_play_with_ball_at(carrier, t0.to_world(Vector2(0.35, 0.0)) + Vector3(0, 0.11, 0))
	# Rivales lejos para que nadie corte.
	for o in m.teams[1].players:
		o.teleport(Vector3(o.team.attack_dir * -40.0, 0, 30.0), Vector3.ZERO)
	_run(1.0)
	var before := _avg_x(t0, carrier)
	# El portador avanza 30 m (se lo lleva conduciendo con el resto en marcha).
	for i in 30:
		carrier.teleport(carrier.flat_pos() + Vector3(t0.attack_dir * 1.0, 0, 0), Vector3(t0.attack_dir, 0, 0))
		m.ball.place(carrier.flat_pos() + Vector3(t0.attack_dir * 0.5, 0.11, 0))
		m.ball.give_to(carrier)
		_run(0.1)
	_run(1.5)
	var after := _avg_x(t0, carrier)
	assert_gt(after - before, 0.12, "el equipo avanza como bloque (%.2f -> %.2f)" % [before, after])


func test_corner_loads_the_box() -> void:
	var t0 := m.teams[0]
	var spot := Vector3(t0.attack_dir * (Pitch.HALF_LENGTH - 0.4), 0.11, Pitch.HALF_WIDTH - 0.4)
	var taker: Footballer = t0.players[5]
	var att := SetPieceShape.targets(t0, MatchRules.Restart.CORNER, 0, spot, taker)
	var dfn := SetPieceShape.targets(m.teams[1], MatchRules.Restart.CORNER, 0, spot, null)
	var in_box := 0
	for p in att:
		if Pitch.in_penalty_area(att[p], t0.attack_dir):
			in_box += 1
	assert_gte(in_box, 5, "al menos cinco atacantes en el área")
	var def_box := 0
	for p in dfn:
		if Pitch.in_penalty_area(dfn[p], m.teams[1].own_side()):
			def_box += 1
	assert_gte(def_box, 7, "defensa cargada en el área")


func test_opponent_presses_high_on_goal_kick() -> void:
	var t0 := m.teams[0]
	var t1 := m.teams[1]
	# Saque de arco del equipo 1 (en su área): el equipo 0 adelanta el bloque.
	var spot := Vector3(t1.own_side() * (Pitch.HALF_LENGTH - 5.5), 0.11, 4.0)
	var press := SetPieceShape.targets(t0, MatchRules.Restart.GOAL_KICK, 1, spot, null)
	var forwards_high := 0
	for p in press:
		if TacticalRole.is_forward(p.tactical_role) and t0.progress_of(press[p]) > 0.72:
			forwards_high += 1
	assert_gte(forwards_high, 2, "delanteros en la puerta del área rival")
	# Y el que saca abre la salida: centrales separados.
	var build := SetPieceShape.targets(t1, MatchRules.Restart.GOAL_KICK, 1, spot, t1.keeper())
	var cbs: Array[float] = []
	for p in build:
		if p.tactical_role == TacticalRole.Kind.CB:
			cbs.append(t1.lateral_of(build[p]))
	assert_gt(cbs.max() - cbs.min(), 0.6, "centrales abiertos en la salida")


func test_throw_in_offers_short_options() -> void:
	var t0 := m.teams[0]
	var spot := Vector3(0.0, 0.11, Pitch.HALF_WIDTH)
	var taker: Footballer = t0.players[4]
	var tg := SetPieceShape.targets(t0, MatchRules.Restart.THROW_IN, 0, spot, taker)
	var near := 0
	for p in tg:
		if Vector3(tg[p]).distance_to(spot) < 13.0:
			near += 1
	assert_gte(near, 2, "dos opciones cortas para el lateral")


func test_formation_change_in_match() -> void:
	var f := FormationLibrary.build("3-5-2")
	m.set_formation(0, f)
	assert_eq(m.teams[0].formation.formation_name, "3-5-2")
	assert_eq(m.teams[0].players[2].tactical_role, TacticalRole.Kind.CB)
