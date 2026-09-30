extends GutTest
## Arquero en el partido: achique a pedido del humano y desvíos.

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


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


## Un rival conduce hacia el arco del humano (equipo 0) desde `dist` metros.
func _rival_attacks(dist: float) -> Footballer:
	var t0 := m.teams[0]
	var goal := t0.own_goal()
	# Defensores lejos: que nadie le robe la pelota antes.
	for p in t0.players:
		if not p.is_keeper():
			p.teleport(Vector3(0, 0, 30.0 - p.number), Vector3.ZERO)
			p.locked = true
	var att: Footballer = m.teams[1].players[9]
	var pos := goal + Vector3(-t0.own_side() * dist, 0, 0)
	att.teleport(pos, Vector3(t0.own_side(), 0, 0))
	m.ball.place(pos + Vector3(t0.own_side() * 0.5, 0.11, 0))
	m.ball.give_to(att)
	return att


## Mantiene al atacante quieto con la pelota (medimos sólo al arquero).
func _hold_attacker(att: Footballer, frames: int) -> void:
	var pos := att.flat_pos()
	for i in frames:
		att.teleport(pos, att.facing)
		m.ball.place(pos + att.facing * 0.5 + Vector3(0, 0.11, 0))
		m.ball.give_to(att)
		_step(1)


func test_triangle_held_sends_the_keeper_out() -> void:
	var gk := m.teams[0].keeper()
	var att := _rival_attacks(24.0)
	_hold_attacker(att, 30)
	var before := gk.flat_pos().distance_to(att.flat_pos())
	inp.hold(&"pass_through")
	_hold_attacker(att, 60)
	var after := gk.flat_pos().distance_to(att.flat_pos())
	assert_eq(gk.debug_state, "sale a achicar")
	assert_lt(after, before - 4.0, "el arquero sale al encuentro (%.1f -> %.1f m)" % [before, after])


func test_triangle_works_anywhere_in_own_half() -> void:
	# Reclamo: "no puedo sacar al arquero con Triángulo" con el rival en mi campo.
	var gk := m.teams[0].keeper()
	var att := _rival_attacks(45.0)
	_hold_attacker(att, 20)
	var before := gk.flat_pos().distance_to(att.flat_pos())
	inp.hold(&"pass_through")
	_hold_attacker(att, 60)
	assert_eq(gk.debug_state, "sale a achicar")
	assert_lt(gk.flat_pos().distance_to(att.flat_pos()), before - 4.0)


func test_triangle_does_nothing_with_rival_in_his_half() -> void:
	var gk := m.teams[0].keeper()
	var att := _rival_attacks(70.0)
	inp.hold(&"pass_through")
	_hold_attacker(att, 60)
	assert_ne(gk.debug_state, "sale a achicar")


func test_without_triangle_the_keeper_stays_home() -> void:
	var gk := m.teams[0].keeper()
	var att := _rival_attacks(24.0)
	_hold_attacker(att, 90)
	assert_lt(gk.flat_pos().distance_to(m.teams[0].own_goal()), 6.0, "sin pedido, cerca del arco")


func test_deflection_replans_the_save() -> void:
	# Remate que se desvía en un defensor: el plan viejo (hacia otro punto)
	# no puede dejar al arquero "atado" a no tocarla.
	var t1 := m.teams[1]
	var shooter: Footballer = m.teams[0].players[9]
	var goal := t1.own_goal()
	shooter.teleport(goal + Vector3(-t1.own_side() * 18.0, 0, 0), Vector3(t1.own_side(), 0, 0))
	m.ball.place(shooter.flat_pos() + Vector3(t1.own_side() * 0.5, 0.11, 0))
	m.ball.give_to(shooter)
	m.kicks.randomize_error = false
	m.perform_kick(shooter, KickActions.Kind.SHOT, Vector3(0, 0, 1), 0.6)
	assert_false(m.save_plan.is_empty(), "hay plan de atajada")
	var old_point: Vector3 = m.save_plan["point"]
	# Desvío: un defensor la toca y la manda al otro palo.
	var defender: Footballer = t1.players[3]
	var v := m.ball.state.vel
	m.ball.kick(Vector3(v.x * 0.8, v.y, -v.z - 4.0), Vector3.ZERO, defender)
	if m.save_plan.is_empty():
		pass_test("el desvío no va al arco: sin plan")
		return
	assert_ne(m.save_plan["point"], old_point, "el plan se rehízo para la nueva trayectoria")
