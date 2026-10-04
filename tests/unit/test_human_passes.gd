extends GutTest
## Pases del humano: atrás, horizontal, largo (con control aéreo) y de primera.
## Rivales lejos: se mide la mecánica del pase, no la presión.

var m: MatchController
var inp: ScriptedInput
var dt := 1.0 / 60.0


func _setup() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate() as MatchController
	add_child_autofree(m)
	m.set_physics_process(false)
	inp = ScriptedInput.new()
	m.humans[0].input = inp
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	for p in m.all_players():
		p.locked = false
	for o in m.teams[1].players:
		if not o.is_keeper():
			o.teleport(Vector3(45, 0, 33), Vector3.ZERO)
			o.locked = true


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


func _give(p: Footballer, pos: Vector3) -> void:
	p.teleport(pos, Vector3.RIGHT)
	m.ball.place(pos + Vector3(0.5, 0.11, 0))
	m.ball.give_to(p)
	m.humans[0].select(p)


## Pasa con el stick `stick` (pantalla) cargando `frames`; devuelve
## [receptor elegido, quién terminó con la pelota].
func _do_pass(action: StringName, stick: Vector3, frames: int) -> Array:
	inp.move = stick
	_step(4)
	inp.hold(action)
	_step(frames)
	inp.release(action)
	var kicks := m.kick_count
	var waited := 0
	while m.kick_count == kicks and waited < 60:
		_step(1)
		waited += 1
	var intended: Footballer = m.ball.intended_receiver
	inp.move = Vector3.ZERO
	for i in 360:
		_step(1)
		if m.ball.owner_player != null:
			break
	return [intended, m.ball.owner_player]


## Proporción de pases que terminan en un compañero. Con `exact`, sólo cuenta
## si la recibe el receptor elegido.
func _success_rate(action: StringName, stick: Vector3, frames: int, exact: bool = true) -> float:
	var ok := 0
	var n := 12
	for i in n:
		_setup()
		_step(60)
		var carrier: Footballer = m.teams[0].players[6]
		_give(carrier, Vector3(-6.0 + i * 0.4, 0, 3.0 - i * 0.5))
		_step(20)
		var r := _do_pass(action, stick, frames)
		var got: Footballer = r[1]
		if r[0] != null and (got == r[0] or (not exact and got != null and got.team == carrier.team and got != carrier)):
			ok += 1
		m.queue_free()
	return float(ok) / n


func test_back_pass_arrives() -> void:
	# El equipo 0 ataca a +X; con la cámara TV, "izquierda" en pantalla es atrás.
	# (Si otro compañero se cruza en la línea y la toma, el pase igual salió bien.)
	var rate := _success_rate(&"pass_short", Vector3(-1, 0, 0), 10, false)
	gut.p("pase atrás: %.0f %%" % (rate * 100.0))
	assert_gte(rate, 0.9)


func test_square_pass_arrives() -> void:
	var up := _success_rate(&"pass_short", Vector3(0, 0, -1), 10)
	var down := _success_rate(&"pass_short", Vector3(0, 0, 1), 10)
	gut.p("pase horizontal: %.0f %% / %.0f %%" % [up * 100.0, down * 100.0])
	assert_gte(up, 0.9)
	assert_gte(down, 0.9)


func test_long_pass_is_controlled_in_the_air() -> void:
	# Semilla fija: con 24 pases el porcentaje varía con el azar (67-92 %).
	seed(20261004)
	var rate := _success_rate(&"pass_long", Vector3(1, 0, 0.3), 24)
	gut.p("pase largo controlado: %.0f %%" % (rate * 100.0))
	assert_gte(rate, 0.75)


func test_chest_control_keeps_the_ball() -> void:
	_setup()
	var r: Footballer = m.teams[0].players[9]
	r.teleport(Vector3(10, 0, 0), Vector3.LEFT)
	m.ball.place(Vector3(11.0, 1.6, 0))
	m.ball.state.vel = Vector3(-6.0, -1.0, 0)
	m.ball.intended_receiver = r
	_step(2)
	assert_eq(m.ball.owner_player, r, "la baja con el pecho")
	_step(40)
	assert_eq(m.ball.owner_player, r, "y la sigue teniendo al caer al pie")
	assert_lt(m.ball.state.pos.y, 0.5)


func test_one_touch_pass_goes_where_the_stick_points() -> void:
	# Reclamo: "si hago un pase de primera, sale a cualquier lugar".
	# A pasa a B; mientras la pelota viaja, con el stick hacia C se aprieta pase.
	var hits := 0
	var n := 8
	for i in n:
		_setup()
		_step(30)
		var a: Footballer = m.teams[0].players[5]
		var b: Footballer = m.teams[0].players[6]
		var c: Footballer = m.teams[0].players[9]
		for p in m.teams[0].players:
			if p != a and p != b and p != c and not p.is_keeper():
				p.teleport(Vector3(-40, 0, -30 + p.number), Vector3.ZERO)
				p.locked = true
		a.teleport(Vector3(-10, 0, 0), Vector3.RIGHT)
		b.teleport(Vector3(4, 0, 0), Vector3.LEFT)
		c.teleport(Vector3(6, 0, -14 - i * 0.5), Vector3.LEFT)
		b.locked = false
		m.ball.place(a.flat_pos() + Vector3(0.5, 0.11, 0))
		m.ball.give_to(a)
		m.humans[0].select(a)
		# Pase a B.
		m.perform_kick(a, KickActions.Kind.SHORT_PASS, Vector3.RIGHT, 0.5, b)
		m.humans[0].select(b)
		# Con la pelota en camino: stick hacia arriba (C) y pase.
		_step(10)
		inp.move = Vector3(0, 0, -1)
		inp.hold(&"pass_short")
		_step(8)
		inp.release(&"pass_short")
		var kicks := m.kick_count
		for f in 120:
			_step(1)
			if m.kick_count != kicks:
				break
		if m.ball.intended_receiver == c:
			hits += 1
		m.queue_free()
	gut.p("pase de primera al del stick: %d/%d" % [hits, n])
	assert_gte(hits, n - 1)
