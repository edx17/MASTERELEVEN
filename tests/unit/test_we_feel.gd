extends GutTest
## Sensación WE2002 (ronda 2): pase atrás al arquero, arquero manejable,
## saque con la mano rodando, pase instantáneo y cortes secos.

var m: MatchController
var inp: ScriptedInput
var dt := 1.0 / 60.0


func before_each() -> void:
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
			o.teleport(Vector3(40, 0, 33), Vector3.ZERO)
			o.locked = true


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


func _back_pass_to_keeper() -> Footballer:
	var t0 := m.teams[0]
	var gk := t0.keeper()
	var goal := t0.own_goal()
	gk.teleport(goal + Vector3(-t0.own_side() * 3.0, 0, 0), Vector3(-t0.own_side(), 0, 0))
	var d: Footballer = t0.players[3]
	d.teleport(goal + Vector3(-t0.own_side() * 18.0, 0, 2.0), Vector3(t0.own_side(), 0, 0))
	m.ball.place(d.flat_pos() + Vector3(t0.own_side() * 0.5, 0.11, 0))
	m.ball.give_to(d)
	m.humans[0].select(d)
	m.perform_kick(d, KickActions.Kind.SHORT_PASS, Vector3(t0.own_side(), 0, 0), 0.4, gk)
	for i in 180:
		_step(1)
		if m.ball.owner_player != null:
			break
	return gk


func test_back_pass_is_played_with_the_feet_and_the_human_controls_the_keeper() -> void:
	var gk := _back_pass_to_keeper()
	assert_eq(m.ball.owner_player, gk, "el arquero recibe el pase atrás")
	assert_false(m.ball.in_hands, "no la agarra con la mano")
	_step(2)
	assert_eq(m.humans[0].controlled, gk, "el humano maneja al arquero")
	# Conduce con los pies como un jugador más.
	inp.move = Vector3(0, 0, 1)
	_step(40)
	assert_eq(m.ball.owner_player, gk, "sigue con la pelota al moverse")
	assert_lt(m.ball.state.pos.y, 0.4, "la pelota va por el piso")


func test_keeper_throw_rolls_along_the_ground() -> void:
	var t0 := m.teams[0]
	var gk := t0.keeper()
	var goal := t0.own_goal()
	gk.teleport(goal + Vector3(-t0.own_side() * 4.0, 0, 0), Vector3(-t0.own_side(), 0, 0))
	m.ball.place(gk.flat_pos() + Vector3(0, 1.0, 0))
	m.ball.give_to(gk, false, true)
	_step(2)
	assert_eq(m.humans[0].controlled, gk, "con la pelota en las manos lo maneja el humano")
	var mate: Footballer = t0.players[2]
	mate.teleport(goal + Vector3(-t0.own_side() * 16.0, 0, 8.0), Vector3.ZERO)
	var r := m.perform_kick(gk, KickActions.Kind.SHORT_PASS, mate.flat_pos() - gk.flat_pos(), 0.4, mate)
	assert_eq(r, mate)
	assert_lt(m.ball.state.pos.y, 0.3, "saque con la mano: sale rodando")
	assert_lt(absf(m.ball.state.vel.y), 1.0, "no la tira para arriba")


func test_keeper_with_ball_in_hands_stays_in_the_box() -> void:
	var t0 := m.teams[0]
	var gk := t0.keeper()
	var goal := t0.own_goal()
	gk.teleport(goal + Vector3(-t0.own_side() * 14.0, 0, 0), Vector3.ZERO)
	m.ball.place(gk.flat_pos() + Vector3(0, 1.0, 0))
	m.ball.give_to(gk, false, true)
	# Stick hacia afuera del área (hacia el medio de la cancha).
	inp.move = Vector3(-t0.own_side(), 0, 0)
	_step(90)
	assert_true(Pitch.in_penalty_area(gk.flat_pos(), t0.own_side()), "no sale del área con la pelota en la mano")
	assert_eq(m.ball.owner_player, gk)


func test_carrier_passes_instantly() -> void:
	# "Tardan en salir": quien conduce patea en el mismo tick, aunque la
	# pelota esté en el toque adelantado.
	var p: Footballer = m.teams[0].players[6]
	p.teleport(Vector3(0, 0, 0), Vector3.RIGHT)
	m.ball.place(Vector3(1.2, 0.11, 0))
	m.ball.give_to(p)
	assert_true(m.can_kick(p), "puede patear con la pelota a 1,2 m")


func test_sharp_cut_reverses_quickly() -> void:
	# Corriendo a toda velocidad, darse vuelta 180° es un corte seco.
	var p: Footballer = m.teams[0].players[6]
	p.teleport(Vector3(-20, 0, 0), Vector3.RIGHT)
	m.ball.place(Vector3(-19.4, 0.11, 0))
	m.ball.give_to(p)
	m.humans[0].select(p)
	inp.move = Vector3(1, 0, 0)
	inp.hold(&"sprint")
	_step(90)
	inp.move = Vector3(-1, 0, 0)
	var frames := 0
	while p.velocity.x > -3.0 and frames < 120:
		_step(1)
		frames += 1
	gut.p("de sprint a 3 m/s para atrás: %.2f s" % (frames * dt))
	assert_lt(frames * dt, 0.75)


func test_circle_slides_when_defending() -> void:
	# Controles pedidos: Círculo (B) = barrida; Cuadrado ya no barre.
	var att: Footballer = m.teams[1].players[9]
	att.locked = false
	att.teleport(Vector3(0, 0, 0), Vector3.LEFT)
	m.ball.place(Vector3(-0.5, 0.11, 0))
	m.ball.give_to(att)
	var d: Footballer = m.teams[0].players[3]
	d.teleport(Vector3(-4, 0, 0), Vector3.RIGHT)
	m.humans[0].select(d)
	inp.hold(&"shoot")
	_step(2)
	assert_ne(d.state, Footballer.State.SLIDING, "Cuadrado no barre")
	inp.release(&"shoot")
	_step(2)
	inp.hold(&"pass_long")
	_step(2)
	assert_eq(d.state, Footballer.State.SLIDING, "Círculo barre")


func test_through_pass_goes_behind_the_last_line() -> void:
	# Triángulo: la pelota cae detrás de la última línea rival, no en los pies.
	var t0 := m.teams[0]
	var passer: Footballer = t0.players[6]
	var runner: Footballer = t0.players[9]
	passer.teleport(Vector3(0, 0, 0), Vector3.RIGHT)
	runner.teleport(Vector3(14, 0, 2), Vector3.RIGHT)
	var defs := [m.teams[1].players[2], m.teams[1].players[3]]
	for i in defs.size():
		defs[i].teleport(Vector3(18, 0, -4 + i * 8), Vector3.LEFT)
	m.ball.place(Vector3(0.5, 0.11, 0))
	m.ball.give_to(passer)
	m.perform_kick(passer, KickActions.Kind.THROUGH_PASS, Vector3(1, 0, 0), 0.2, runner)
	var target: Vector3 = runner.pass_target
	assert_gt(target.x, 18.0 + 3.5, "el pase al hueco cae detrás de la línea (x=%.1f)" % target.x)


func test_radar_fades_when_ball_is_behind_it() -> void:
	var hud: MatchHud
	for c in m.get_children():
		if c is MatchHud:
			hud = c
	var radar = hud._radar
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		pass_test("sin cámara en modo headless")
		return
	# Pelota justo detrás del radar en pantalla (banda cercana).
	var center: Vector2 = radar.get_global_rect().get_center()
	var from := cam.project_ray_origin(center)
	var dir := cam.project_ray_normal(center)
	var t := -from.y / dir.y
	m.ball.place(from + dir * t + Vector3(0, 0.11, 0))
	assert_true(radar._hides_play(), "detecta la pelota detrás del radar")
