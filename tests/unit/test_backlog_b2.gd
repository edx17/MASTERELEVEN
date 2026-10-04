extends GutTest
## Pelota y jugador: la conducción es por toques (el pie la empuja y se ve el
## gesto; entre toques rueda sola), la pelota se dibuja pegada al botín en el
## toque y las gambetas la mueven de verdad.

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
	for t in m.teams:
		for p in t.players:
			p.locked = false
			p.teleport(Vector3(-40 + t.index * 80, 0, -25 + t.players.find(p) * 4))


func _carrier() -> Footballer:
	var p: Footballer = m.teams[0].players[9]
	p.teleport(Vector3(0, 0, 0), Vector3.RIGHT)
	m.ball.place(Vector3(0.4, 0.11, 0))
	m.ball.give_to(p)
	return p


func _run(p: Footballer, frames: int, dir: Vector3 = Vector3.RIGHT) -> Array:
	var seen: Array = []
	var cb := func(ev: int, side: float) -> void: seen.append([ev, side])
	p.visual.played.connect(cb)
	for i in frames:
		p.desired_move = dir
		p.wants_sprint = false
		p.tick(dt, true)
		m.ball.tick(dt)
	p.visual.played.disconnect(cb)
	return seen


func test_dribble_is_made_of_touches_with_both_feet() -> void:
	var p := _carrier()
	var seen := _run(p, 150)
	var touches := seen.filter(func(e: Array) -> bool: return e[0] == PlayerVisual.Event.TOUCH)
	assert_gt(touches.size(), 3, "toques mientras corre")
	var feet := {}
	for e in touches:
		feet[signf(e[1])] = true
	assert_eq(feet.size(), 2, "alterna los dos pies")
	assert_eq(m.ball.owner_player, p, "y no la pierde")


func test_ball_rolls_between_touches() -> void:
	# Entre toques la pelota se adelanta y el jugador la alcanza: la distancia
	# pie-pelota cambia (no queda fija pegada).
	var p := _carrier()
	var dists: Array[float] = []
	for i in 120:
		p.desired_move = Vector3.RIGHT
		p.tick(dt, true)
		m.ball.tick(dt)
		dists.append(m.ball.flat_pos().distance_to(Dribble.foot_point(p.global_position, p.facing)))
	assert_gt(dists.max() - dists.min(), 0.12, "la pelota se aleja y vuelve")


func test_roulette_moves_the_ball_to_the_side() -> void:
	var p := _carrier()
	_run(p, 30)
	m.perform_skill(p, Footballer.Skill.ROULETTE)
	var right := p.facing.cross(Vector3.UP).normalized()
	var max_side := 0.0
	for i in int(MatchController.ROULETTE_TIME / dt):
		p.desired_move = Vector3.RIGHT
		p.tick(dt, true)
		m.ball.tick(dt)
		max_side = maxf(max_side, (m.ball.flat_pos() - p.flat_pos()).dot(right))
	assert_gt(max_side, 0.25, "la pelota hace el arco al costado")


func test_feint_drags_the_ball_toward_the_cut() -> void:
	var p := _carrier()
	_run(p, 30)
	var stick := Vector3(0, 0, 1)
	m.perform_feint(p, stick)
	assert_gt(m.ball.state.vel.dot(stick), 2.0, "la suela la arrastra hacia el enganche")
	assert_lt(m.ball.global_position.distance_to(m.ball.state.pos + m.ball.visual_offset), 0.01)
