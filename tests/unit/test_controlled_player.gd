extends GutTest
## Integración: un humano (ScriptedInput) conduce, gira y pasa.

var m: MatchController
var input: ScriptedInput
var dt := 1.0 / 60.0


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate() as MatchController
	add_child_autofree(m)
	m.set_physics_process(false)
	input = ScriptedInput.new()
	m.humans[0].input = input
	# Juego en marcha, sin rivales cerca: sólo importa la conducción.
	m.restart_taker = null
	m.ball.frozen = false
	m.phase = MatchController.Phase.PLAYING
	for p in m.all_players():
		p.locked = false
		p.teleport(Vector3(-45.0 + p.number * 2.0, 0.0, 30.0 if p.team.index == 0 else -30.0))
	# Los rivales quietos (sin IA) para no interferir.
	m.ais[1].team.players.map(func(p: Footballer) -> void: p.set_physics_process(false))


func _carrier() -> Footballer:
	var p: Footballer = m.teams[0].players[6]
	p.teleport(Vector3(-20, 0, 0), Vector3.RIGHT)
	m.ball.place(Vector3(-19.6, 0.11, 0))
	m.ball.give_to(p)
	m.humans[0].select(p)
	return p


func _run(seconds: float) -> Dictionary:
	var info := {"max_gap": 0.0, "lost": false}
	for i in int(seconds / dt):
		# Los rivales no se mueven (se los deja lejos).
		for o in m.teams[1].players:
			o.desired_move = Vector3.ZERO
		m._physics_process(dt)
		var c := m.humans[0].controlled
		if m.ball.owner_player != c:
			info["lost"] = true
		info["max_gap"] = maxf(info["max_gap"], m.ball.flat_pos().distance_to(c.flat_pos()))
	return info


func test_sprint_dribble_keeps_ball_with_touches() -> void:
	var p := _carrier()
	input.move = Vector3.RIGHT
	input.hold(&"sprint")
	var info := _run(3.0)
	assert_false(info["lost"], "no pierde la pelota corriendo derecho")
	assert_gt(p.touches, 3, "conduce con toques")
	assert_gt(info["max_gap"], 0.7, "la pelota no va pegada al pie")
	assert_lt(info["max_gap"], 1.8, "pero tampoco se le escapa")
	assert_gt(p.global_position.x, -20.0 + 15.0, "avanzó en sprint")


func test_can_turn_with_the_ball() -> void:
	var p := _carrier()
	input.move = Vector3.RIGHT
	_run(1.0)
	input.move = Vector3(0, 0, -1)
	_run(1.5)
	assert_eq(m.ball.owner_player, p, "gira y la sigue conduciendo")
	assert_lt(m.ball.state.pos.z, -3.0, "la pelota fue hacia arriba con él")


func test_short_pass_reaches_teammate() -> void:
	var p := _carrier()
	var mate: Footballer = m.teams[0].players[9]
	mate.teleport(Vector3(-5, 0, 0), Vector3.LEFT)
	input.move = Vector3.ZERO
	_run(0.3)
	input.move = Vector3.RIGHT
	input.hold(&"pass_short")
	_run(0.15)
	input.release(&"pass_short")
	input.move = Vector3.ZERO
	var got := false
	for i in 240:
		m._physics_process(dt)
		if m.ball.owner_player == mate:
			got = true
			break
	assert_true(got, "el compañero recibe el pase")
	assert_eq(m.humans[0].controlled, mate, "cambio automático al receptor")


func _two_mates() -> Array[Footballer]:
	var up: Footballer = m.teams[0].players[5]
	var right: Footballer = m.teams[0].players[9]
	up.teleport(Vector3(-20, 0, -12), Vector3.DOWN)
	right.teleport(Vector3(-6, 0, 0), Vector3.LEFT)
	var out: Array[Footballer] = [up, right]
	return out


func _carrier_at_origin() -> Footballer:
	var p: Footballer = m.teams[0].players[6]
	p.teleport(Vector3(-20, 0, 0), Vector3.RIGHT)
	m.ball.place(Vector3(-19.6, 0.11, 0))
	m.ball.give_to(p)
	m.humans[0].select(p)
	return p


func _pass_and_get_receiver() -> Footballer:
	input.hold(&"pass_short")
	_run(0.15)
	input.release(&"pass_short")
	_run(dt)
	return m.ball.intended_receiver


func test_pass_uses_aim_even_after_releasing_stick() -> void:
	var mates := _two_mates()
	_carrier_at_origin()
	_run(0.2)
	# Apunta hacia arriba (al compañero de arriba) y suelta el stick justo antes.
	input.move = Vector3(0, 0, -1)
	_run(0.1)
	input.move = Vector3.ZERO
	assert_eq(_pass_and_get_receiver(), mates[0], "el pase va a quien se apuntó")


func test_charging_marks_the_receiver() -> void:
	var mates := _two_mates()
	_carrier_at_origin()
	_run(0.2)
	input.move = Vector3(0, 0, -1)
	input.hold(&"pass_short")
	_run(0.1)
	assert_eq(m.humans[0].preview_receiver, mates[0], "mientras carga, se marca al receptor")
	input.release(&"pass_short")
	_run(dt)
	assert_null(m.humans[0].preview_receiver, "al patear se quita la marca")


func test_short_pass_always_finds_a_teammate() -> void:
	var behind: Footballer = m.teams[0].players[3]
	behind.teleport(Vector3(-30, 0, 2), Vector3.RIGHT)
	_carrier_at_origin()
	_run(0.2)
	# Apunta hacia adelante, donde no hay nadie: igual busca a un compañero.
	input.move = Vector3.RIGHT
	assert_not_null(_pass_and_get_receiver(), "no suelta la pelota al vacío")


func test_receiver_comes_to_the_ball_even_with_stick_held() -> void:
	# Pase hacia la derecha manteniendo el stick a la derecha todo el tiempo:
	# el receptor no debe escaparse hacia la derecha, debe venir a recibir.
	var mates := _two_mates()
	var receiver := mates[1]
	_carrier_at_origin()
	_run(0.2)
	input.move = Vector3.RIGHT
	input.hold(&"pass_short")
	_run(0.15)
	input.release(&"pass_short")
	var start_x := receiver.global_position.x
	var got := false
	for i in 240:
		m._physics_process(dt)
		if m.ball.owner_player == receiver:
			got = true
			break
	assert_true(got, "recibe con el stick apretado")
	assert_lt(receiver.global_position.x, start_x + 1.0, "no se escapó en la dirección del stick")


func test_moving_stick_elsewhere_returns_control() -> void:
	var mates := _two_mates()
	_carrier_at_origin()
	_run(0.2)
	input.move = Vector3.RIGHT
	input.hold(&"pass_short")
	_run(0.15)
	input.release(&"pass_short")
	_run(0.05)
	# Nueva orden: hacia abajo (90° de la dirección del pase).
	input.move = Vector3(0, 0, 1)
	_run(0.3)
	assert_gt(mates[1].velocity.z, 1.0, "el jugador toma el control del receptor")


func test_pass_marker_hidden_by_default() -> void:
	var mates := _two_mates()
	_carrier_at_origin()
	_run(0.2)
	input.move = Vector3(0, 0, -1)
	input.hold(&"pass_short")
	_run(0.1)
	assert_eq(m.humans[0].preview_receiver, mates[0], "el receptor se elige igual")
	assert_true(mates[0]._pass_marker == null or not mates[0]._pass_marker.visible, "pero el aro no se ve")
	input.release(&"pass_short")
