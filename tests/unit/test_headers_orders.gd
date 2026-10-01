extends GutTest
## Cabezazos, orden guardada (estilo WE), pelota en las manos del arquero y
## pelota que sale del pie.

var m: MatchController
var inp: ScriptedInput
var dt := 1.0 / 60.0


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	inp = ScriptedInput.new()
	m.humans[0].input = inp
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	m.ball.owner_player = null
	for p in m.all_players():
		p.locked = false
		p.teleport(p.flat_pos() + Vector3(0, 0, 60), Vector3.RIGHT) # fuera del juego


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


## Pelota que llega por el aire a `at` a 2 m de altura, viniendo de `from_dir`.
func _cross_to(at: Vector3, from_dir: Vector3) -> void:
	m.ball.place(at - from_dir * 3.0 + Vector3(0, 2.0, 0))
	m.ball.state.vel = from_dir * 14.0 + Vector3(0, 1.0, 0)
	m.ball.intended_receiver = null


func test_cpu_striker_heads_at_goal() -> void:
	var t1 := m.teams[1]
	var striker: Footballer = t1.players[9]
	var goal := t1.target_goal()
	var spot := goal - Vector3(t1.attack_dir * 8.0, 0, 0)
	striker.teleport(spot, Vector3(t1.attack_dir, 0, 0))
	_cross_to(spot, Vector3(0, 0, 1))
	var kicks := m.kick_count
	_step(20)
	assert_gt(m.kick_count, kicks, "cabecea")
	assert_eq(m.last_kick.get("kind"), KickActions.Kind.SHOT, "remate de cabeza")
	assert_eq(m.last_kick.get("player"), striker)


func test_cpu_defender_clears_with_the_head() -> void:
	var t1 := m.teams[1]
	var df: Footballer = t1.players[2]
	var spot := t1.own_goal() + Vector3(t1.attack_dir * 12.0, 0, 3.0)
	df.teleport(spot, Vector3(-t1.attack_dir, 0, 0))
	_cross_to(spot, Vector3(-t1.attack_dir, 0, 0))
	_step(20)
	assert_eq(m.last_kick.get("player"), df, "la despeja")
	assert_eq(m.last_kick.get("kind"), KickActions.Kind.LONG_PASS, "despeje largo")
	assert_gt(m.ball.state.vel.x * t1.attack_dir, 0.0, "lejos de su arco")


func test_human_order_waits_for_the_ball_and_heads_it() -> void:
	var p: Footballer = m.teams[0].players[9]
	var spot := Vector3(20, 0, 0)
	p.teleport(spot, Vector3.RIGHT)
	m.humans[0].select(p)
	# Pide el tiro mucho antes de que llegue la pelota.
	m.ball.place(Vector3(-40, 0.11, -25)) # lejos de todos
	inp.hold(&"shoot")
	_step(10)
	inp.release(&"shoot")
	_step(90) # 1,5 s esperando: la orden sigue
	assert_true(m.humans[0].has_order(), "la orden espera la pelota")
	# (Con el stick suelto fue a buscar la pelota; lo ubicamos para el centro.)
	p.teleport(spot, Vector3.RIGHT)
	_cross_to(spot, Vector3(0, 0, 1))
	var kicks := m.kick_count
	_step(20)
	assert_gt(m.kick_count, kicks)
	assert_eq(m.last_kick.get("player"), p, "le llegó y cabeceó")
	assert_eq(m.last_kick.get("kind"), KickActions.Kind.SHOT)
	assert_false(m.humans[0].has_order())


func test_order_is_cancelled_by_button_or_by_an_interception() -> void:
	var p: Footballer = m.teams[0].players[6]
	p.teleport(Vector3(0, 0, 0), Vector3.RIGHT)
	m.humans[0].select(p)
	m.ball.place(Vector3(-20, 0.11, 25))
	inp.hold(&"pass_short")
	_step(5)
	inp.release(&"pass_short")
	_step(5)
	assert_true(m.humans[0].has_order())
	inp.hold(&"cancel")
	_step(2)
	inp.release(&"cancel")
	assert_false(m.humans[0].has_order(), "R2 / E cancela")
	inp.hold(&"pass_short")
	_step(5)
	inp.release(&"pass_short")
	_step(5)
	assert_true(m.humans[0].has_order())
	var rival: Footballer = m.teams[1].players[6]
	rival.teleport(Vector3(-20, 0, 25), Vector3.RIGHT)
	m.ball.give_to(rival)
	_step(2)
	assert_false(m.humans[0].has_order(), "el rival la anticipó")


func test_ball_in_hands_follows_the_keeper_to_the_ground() -> void:
	var gk := m.teams[0].keeper()
	gk.teleport(m.teams[0].own_goal() + Vector3(m.teams[0].attack_dir * 2.0, 0, 0), Vector3(m.teams[0].attack_dir, 0, 0))
	m.ball.give_to(gk, false, true)
	m.ball.tick(dt)
	var standing := m.ball.state.pos.y
	if not gk.visual is ModelVisual or MixamoLibrary.library(ModelVisual._body_scene) == null:
		assert_between(standing, 0.6, 1.5, "a la altura de las manos")
		return
	var mv := gk.visual as ModelVisual
	mv._anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	mv.play(PlayerVisual.Event.BLOCK) # se tira al piso con la pelota
	for i in 60:
		mv.update(dt, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
		mv._anim.advance(dt)
		m.ball.tick(dt)
	assert_lt(m.ball.state.pos.y, standing - 0.3, "la pelota baja con las manos (no queda flotando)")
	var hands := mv.hold_point()
	assert_lt(m.ball.state.pos.distance_to(hands), 0.05)


func test_kicked_ball_is_drawn_leaving_from_the_foot() -> void:
	var p: Footballer = m.teams[0].players[6]
	p.teleport(Vector3.ZERO, Vector3.RIGHT)
	m.ball.place(Vector3(0.8, 0.11, 0.3))
	m.ball.give_to(p)
	m.perform_kick(p, KickActions.Kind.SHOT, Vector3.RIGHT, 0.6)
	var foot := p.visual.contact_point(PlayerVisual.Event.KICK)
	var drawn := m.ball.state.pos + m.ball.visual_offset
	assert_lt(drawn.distance_to(foot), 0.05, "se dibuja en el pie al salir")
	for i in 20:
		m.ball.tick(dt)
	assert_lt(m.ball.visual_offset.length(), 0.05, "y enseguida vuelve a su posición real")
