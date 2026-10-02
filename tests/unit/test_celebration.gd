extends GutTest
## Festejo del gol: el goleador corre al córner, lo acompañan 2 o 3 y los
## demás levantan los brazos.

var m: MatchController
var dt := 1.0 / 60.0


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.show_replays = false
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	for p in m.all_players():
		p.locked = false


func _goal() -> Footballer:
	var t := m.teams[0]
	var shooter: Footballer = t.players[9]
	var goal := t.target_goal()
	shooter.teleport(goal - Vector3(t.attack_dir * 14.0, 0, 3.0), Vector3(t.attack_dir, 0, 0))
	m.teams[1].keeper().teleport(goal - Vector3(t.attack_dir * 10.0, 0, 15.0))
	m.ball.place(goal + Vector3(t.attack_dir * 0.2, 0.5, 0))
	m.ball.state.vel = Vector3(t.attack_dir * 10.0, 0, 0)
	m.ball.last_toucher = shooter
	m.ball.last_touch_team = 0
	for i in 30:
		m._physics_process(dt)
		if m.phase == MatchController.Phase.GOAL:
			break
	return shooter


func test_scorer_runs_to_the_nearest_corner_and_celebrates() -> void:
	var shooter := _goal()
	assert_eq(m.phase, MatchController.Phase.GOAL)
	assert_eq(m.celebration["scorer"], shooter)
	var target: Vector3 = m.celebration["target"]
	var t := m.teams[0]
	assert_eq(signf(target.x), signf(t.target_goal().x), "el córner del arco donde hizo el gol")
	assert_eq(signf(target.z), signf(shooter.global_position.z), "el más cercano")
	assert_lt(absf(target.x), Pitch.HALF_LENGTH - 2.0, "unos metros antes del banderín")
	var mates: Array = m.celebration["mates"]
	assert_between(mates.size(), 2, 3, "lo acompañan 2 o 3")
	var start := shooter.flat_pos().distance_to(target)
	var arrived := false
	for i in int(MatchController.CELEBRATION_MAX / dt):
		m._physics_process(dt)
		if m.celebration.get("arrived", -1.0) >= 0.0 and not arrived:
			arrived = true
			assert_lt(shooter.flat_pos().distance_to(target), 1.5, "festeja en el córner")
			assert_gt(shooter.celebrate_timer, 0.0)
		if m.phase != MatchController.Phase.GOAL:
			break
	assert_true(arrived, "llegó y festejó (estaba a %.0f m)" % start)
	assert_eq(m.phase, MatchController.Phase.RESTART, "después, saque del medio")


func test_mates_follow_and_the_rest_raise_their_arms() -> void:
	_goal()
	var mates: Array = m.celebration["mates"]
	var target: Vector3 = m.celebration["target"]
	var before := []
	for mm in mates:
		before.append((mm[0] as Footballer).flat_pos().distance_to(target))
	for i in int(0.5 / dt):
		m._physics_process(dt)
	var cheering := 0
	for p in m.teams[0].players:
		if p.visual != null and p.visual._event == PlayerVisual.Event.CHEER:
			cheering += 1
	assert_gt(cheering, 0, "los demás festejan con los brazos arriba")
	for i in int(2.0 / dt):
		m._physics_process(dt)
	for k in mates.size():
		var p: Footballer = mates[k][0]
		assert_lt(p.flat_pos().distance_to(target), before[k] - 3.0, "%s va al córner" % p.display_name)
