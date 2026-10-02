extends GutTest
## Botones y combinaciones del WE: globo, remate rasante, centros alto y raso,
## pared, super cancel, cambio con L1, amague, bicicleta, marsellesa,
## conducción cerrada, presión pedida y pelota aérea.

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
	m.kicks.randomize_error = false
	for p in m.all_players():
		p.locked = false


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


func _carrier(pos: Vector3 = Vector3(20, 0, 0)) -> Footballer:
	var p: Footballer = m.teams[0].players[9]
	p.teleport(pos, Vector3(m.teams[0].attack_dir, 0, 0))
	m.ball.place(pos + Vector3(m.teams[0].attack_dir * 0.5, 0.11, 0))
	m.ball.give_to(p)
	m.humans[0].select(p)
	return p


## Aprieta y suelta `actions` (a la vez) durante `frames` cuadros.
func _press(actions: Array, frames: int = 6) -> void:
	for a in actions:
		inp.hold(a)
	_step(frames)
	for a in actions:
		inp.release(a)
	_step(1)


## Espera la patada (contando desde `k`, el contador antes de apretar).
func _wait_kick(k: int, max_frames: int = 40) -> bool:
	for i in max_frames:
		if m.kick_count != k:
			return true
		_step(1)
	return m.kick_count != k


func test_l1_square_is_a_chip() -> void:
	_carrier()
	var k := m.kick_count
	inp.hold(&"special")
	_press([&"shoot"], 10)
	inp.release(&"special")
	_wait_kick(k)
	var v := m.ball.state.vel
	assert_gt(v.y / Vector2(v.x, v.z).length(), 0.6, "sale bombeado (globo)")


func test_double_square_is_a_low_shot() -> void:
	_carrier()
	var k := m.kick_count
	_press([&"shoot"], 10)
	_press([&"shoot"], 2)
	_wait_kick(k)
	assert_lt(m.ball.state.vel.y, 1.5, "rasante")
	var normal := m.ball.state.vel
	assert_gt(Vector2(normal.x, normal.z).length(), 15.0, "fuerte")


func test_single_square_waits_the_double_tap_window_then_shoots() -> void:
	_carrier()
	var k := m.kick_count
	_press([&"shoot"], 10)
	assert_eq(m.kick_count, k, "espera un posible segundo toque")
	_step(int(HumanController.DOUBLE_TAP / dt) + 2)
	assert_gt(m.kick_count, k, "remate normal")


func test_cross_variants() -> void:
	var t := m.teams[0]
	var spot := Vector3(t.attack_dir * 38.0, 0, 26.0)
	var p := _carrier(spot)
	var mate: Footballer = t.players[8]
	mate.teleport(Vector3(t.attack_dir * 44.0, 0, 0), Vector3.RIGHT)
	var k := m.kick_count
	inp.hold(&"special")
	_press([&"pass_long"], 10)
	inp.release(&"special")
	_wait_kick(k)
	var high := m.ball.state.vel.y
	# Un toque: centro normal (alto, al segundo palo).
	_carrier(spot)
	k = m.kick_count
	_press([&"pass_long"], 10)
	_wait_kick(k)
	var single := m.ball.state.vel.y
	# Doble toque: a media altura (más tenso, más bajo que el normal).
	_carrier(spot)
	k = m.kick_count
	_press([&"pass_long"], 10)
	_press([&"pass_long"], 2)
	_wait_kick(k)
	var mid := m.ball.state.vel.y
	# Triple toque: rasante al primer palo.
	_carrier(spot)
	k = m.kick_count
	_press([&"pass_long"], 10)
	_press([&"pass_long"], 2)
	_press([&"pass_long"], 2)
	_wait_kick(k)
	var low := m.ball.state.vel.y
	assert_gt(high, 8.0, "L1 + Círculo: centro alto")
	assert_gt(single, mid + 0.5, "doble Círculo: más bajo que el de un toque")
	assert_gt(mid, 1.0, "doble Círculo: va por el aire, a media altura")
	assert_lt(absf(low), 1.0, "triple Círculo: centro rasante por el piso")
	assert_true(p != null)


func test_one_two_returns_the_ball_to_the_passer() -> void:
	var t := m.teams[0]
	var p := _carrier(Vector3(0, 0, 0))
	var mate: Footballer = t.players[8]
	mate.teleport(Vector3(t.attack_dir * 8.0, 0, -4.0), Vector3.RIGHT)
	for o in m.teams[1].players:
		o.teleport(o.flat_pos() + Vector3(0, 0, 60), Vector3.RIGHT)
	inp.move = Vector3(t.attack_dir, 0, -0.5).normalized()
	inp.hold(&"special")
	_press([&"pass_short"], 4)
	inp.release(&"special")
	inp.move = Vector3.ZERO
	assert_eq(m.humans[0].controlled, p, "el control queda en el que la tocó")
	var returned := false
	for i in 240:
		_step(1)
		if m.ball.intended_receiver == p and m.last_kick.get("player") == mate:
			returned = true
			break
	assert_true(returned, "el compañero la devuelve de primera")
	assert_gt(p.flat_pos().x * t.attack_dir, 1.0, "y el que la tocó picó al espacio")


func test_super_cancel_and_l1_switch() -> void:
	var p: Footballer = m.teams[0].players[6]
	for o in m.all_players():
		o.teleport(o.flat_pos() + Vector3(0, 0, 60), Vector3.RIGHT)
	p.teleport(Vector3(0, 0, 0), Vector3.RIGHT)
	m.humans[0].select(p)
	m.ball.place(Vector3(-12, 0.11, 0)) # p es el más cercano
	m.ball.owner_player = null
	_press([&"pass_short"], 4)
	_step(2)
	assert_true(m.humans[0].has_order())
	_press([&"special", &"sprint"], 2)
	assert_false(m.humans[0].has_order(), "L1 + R1 = super cancel")
	assert_eq(m.humans[0].controlled, p, "el super cancel no cambia de jugador")
	_press([&"special"], 2)
	assert_ne(m.humans[0].controlled, p, "L1 sin la pelota cambia de jugador")


func test_l1_with_the_ball_keeps_it_closer_and_does_not_switch() -> void:
	var p := _carrier()
	inp.move = Vector3(1, 0, 0)
	inp.hold(&"special")
	_step(60)
	assert_eq(m.humans[0].controlled, p)
	assert_true(p.close_control)
	var speed := Vector3(p.velocity.x, 0, p.velocity.z).length()
	assert_lt(speed, m.tuning.run_speed * m.tuning.dribble_speed_factor * 0.85, "conducción cerrada, más lenta")
	inp.release(&"special")


func test_feint_cuts_and_fools_the_defender() -> void:
	var p := _carrier(Vector3(0, 0, 0))
	var df: Footballer = m.teams[1].players[3]
	df.teleport(p.flat_pos() + Vector3(m.teams[0].attack_dir * 2.5, 0, 0.3), Vector3.LEFT)
	var facing_before := p.facing
	var k := m.kick_count
	inp.hold(&"shoot")
	_step(5)
	_press([&"pass_short"], 2)
	inp.release(&"shoot")
	_step(1)
	assert_eq(m.kick_count, k, "no patea")
	assert_lt(p.facing.dot(facing_before), 0.3, "engancha")
	assert_gt(df.reaction_timer, 0.0, "el defensor se lo come")
	assert_eq(m.ball.owner_player, p)


func test_triple_l1_is_a_stepover_and_then_a_burst() -> void:
	var p := _carrier()
	for i in 3:
		_press([&"special"], 2)
	assert_eq(p.skill, Footballer.Skill.STEPOVER, "bicicleta")
	_step(int(MatchController.STEPOVER_TIME / dt) + 2)
	assert_eq(p.skill, Footballer.Skill.BURST, "y sale en velocidad")


func test_right_stick_full_turn_is_a_roulette() -> void:
	var p := _carrier()
	for i in 24:
		var a := TAU * i / 20.0
		inp.right = Vector3(cos(a), 0, sin(a))
		_step(1)
		if p.skill == Footballer.Skill.ROULETTE:
			break
	inp.right = Vector3.ZERO
	assert_eq(p.skill, Footballer.Skill.ROULETTE, "marsellesa")
	var df: Footballer = m.teams[1].players[3]
	df.teleport(p.flat_pos() + p.facing * 1.0, -p.facing)
	var protected := m.tackle_chance(df, p)
	p.skill = Footballer.Skill.NONE
	assert_lt(protected, m.tackle_chance(df, p) * 0.5, "girando cuesta más sacársela")


func test_square_held_defending_sends_a_teammate_to_press() -> void:
	var rival: Footballer = m.teams[1].players[9]
	rival.teleport(Vector3(0, 0, 0), Vector3.LEFT)
	m.ball.place(Vector3(-0.5, 0.11, 0))
	m.ball.give_to(rival)
	inp.hold(&"shoot")
	var helpers := 0
	for i in 30: # (pasado el tiempo de reacción)
		_step(1)
		helpers = 0
		for p in m.teams[0].players:
			if p.debug_state == "presiona (pedido)":
				helpers += 1
		if helpers > 0:
			break
	inp.release(&"shoot")
	assert_eq(helpers, 1, "un compañero sale a presionar")


func test_aerial_buttons() -> void:
	var t := m.teams[0]
	var p: Footballer = t.players[6]
	p.teleport(t.own_goal() + Vector3(t.attack_dir * 20.0, 0, 0), Vector3.RIGHT)
	m.ball.owner_player = null
	m.ball.place(p.flat_pos() + Vector3(0, 2.0, 0))
	assert_eq(HumanController.aerial_kind(KickActions.Kind.SHOT, p, m.ball), KickActions.Kind.CLEAR, "Cuadrado en campo propio: despeje de cabeza")
	assert_eq(HumanController.aerial_kind(KickActions.Kind.LONG_PASS, p, m.ball), KickActions.Kind.CLEAR, "Círculo: despeje")
	assert_eq(HumanController.aerial_kind(KickActions.Kind.SHORT_PASS, p, m.ball), KickActions.Kind.SHORT_PASS, "X: pase de cabeza")
	p.teleport(t.target_goal() - Vector3(t.attack_dir * 12.0, 0, 0), Vector3.RIGHT)
	m.ball.place(p.flat_pos() + Vector3(0, 2.0, 0))
	assert_eq(HumanController.aerial_kind(KickActions.Kind.SHOT, p, m.ball), KickActions.Kind.SHOT, "Cuadrado en campo rival: remate de cabeza")


func test_menus_accept_with_x() -> void:
	var found := false
	for e in InputMap.action_get_events(&"ui_accept"):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			found = true
	assert_true(found, "X (abajo) acepta en los menús")


func test_r2_while_charging_gives_a_placed_shot() -> void:
	var t := m.teams[0]
	var spot := Vector3(t.attack_dir * 36.0, 0, 3.0)
	_carrier(spot)
	m.kicks.randomize_error = false
	var k := m.kick_count
	_press([&"shoot"], 12)
	_wait_kick(k)
	var normal := Vector2(m.ball.state.vel.x, m.ball.state.vel.z).length()
	_carrier(spot)
	k = m.kick_count
	inp.hold(&"shoot")
	_step(6)
	inp.hold(&"brake")
	_step(6)
	inp.release(&"shoot")
	inp.release(&"brake")
	_step(1)
	_wait_kick(k)
	var placed := Vector2(m.ball.state.vel.x, m.ball.state.vel.z).length()
	assert_lt(placed, normal * 0.9, "colocado: menos potencia")
	assert_gt(absf(m.ball.state.vel.z), 0.5, "busca un palo")


func test_r2_while_dribbling_stops_dead() -> void:
	var p := _carrier()
	p.velocity = p.facing * 7.0
	inp.hold(&"brake")
	_step(1)
	inp.release(&"brake")
	assert_lt(Vector3(p.velocity.x, 0, p.velocity.z).length(), 2.0, "frena en seco")
	assert_eq(m.ball.owner_player, p, "con la pelota pisada")


func test_tall_player_wins_the_header_duel() -> void:
	var t0 := m.teams[0]
	var t1 := m.teams[1]
	var tall: Footballer = t0.players[9]
	var small: Footballer = t1.players[3]
	tall.data = tall.data.duplicate()
	small.data = small.data.duplicate()
	tall.data.build = PlayerData.Build.TALL
	small.data.build = PlayerData.Build.SHORT
	assert_gt(tall.data.body_height(), small.data.body_height())
	assert_gt(small.data.agility(), tall.data.agility(), "el bajo gira más cerrado")
	# Pelota alta entre los dos: el alto llega, el bajo no.
	var mid := Vector3(0, 0, 0)
	tall.teleport(mid + Vector3(0.5, 0, 0), Vector3.LEFT)
	small.teleport(mid - Vector3(0.5, 0, 0), Vector3.RIGHT)
	m.ball.place(Vector3(0, m.tuning.header_max_height * 1.04, 0))
	assert_true(m.in_header_reach(tall), "el alto la alcanza")
	assert_false(m.in_header_reach(small), "el bajo no llega")
