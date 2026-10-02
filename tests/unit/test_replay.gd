extends GutTest
## Repetición del gol: graba la jugada, la vuelve a mostrar con la ficha del
## goleador y después se saca del medio.

var m: MatchController
var dt := 1.0 / 60.0


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.show_replays = true
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	for p in m.all_players():
		p.locked = false


func after_each() -> void:
	GameSettings.show_replays = false


func _score_goal() -> Footballer:
	var t := m.teams[0]
	var shooter: Footballer = t.players[9]
	var goal := t.target_goal()
	# Corre hacia el arco unos segundos (eso se graba).
	for i in 120:
		m.replay.record()
	shooter.teleport(goal - Vector3(t.attack_dir * 6.0, 0, 0), Vector3(t.attack_dir, 0, 0))
	var gk := m.teams[1].keeper()
	gk.teleport(goal - Vector3(t.attack_dir * 10.0, 0, 15.0))
	m.ball.place(goal + Vector3(t.attack_dir * 0.2, 0.5, 0))
	m.ball.state.vel = Vector3(t.attack_dir * 10.0, 0, 0)
	m.ball.last_toucher = shooter
	m.ball.last_touch_team = 0
	for i in 30:
		m._physics_process(dt)
		if m.phase == MatchController.Phase.GOAL:
			break
	return shooter


func test_goal_is_followed_by_a_replay_and_a_kickoff() -> void:
	var shooter := _score_goal()
	assert_eq(m.phase, MatchController.Phase.GOAL)
	assert_eq(m.goal_scorer, shooter)
	for i in int((MatchController.GOAL_DELAY + 0.2) / dt):
		m._physics_process(dt)
		if m.phase == MatchController.Phase.REPLAY:
			break
	assert_eq(m.phase, MatchController.Phase.REPLAY, "después del festejo, la repetición")
	assert_true(m.replay.playing)
	var saw_card := false
	for i in 1200:
		m._physics_process(dt)
		if m.replay._card.visible:
			saw_card = true
		if m.phase != MatchController.Phase.REPLAY:
			break
	assert_true(saw_card, "se ve la ficha del goleador")
	assert_eq(m.phase, MatchController.Phase.RESTART, "y se saca del medio")
	assert_eq(m.restart_type, MatchRules.Restart.KICKOFF)


func test_scorer_line_has_position_number_height_and_age() -> void:
	var p: Footballer = m.teams[0].players[9]
	var line := Replay.scorer_line(p, false)
	assert_string_contains(line, str(p.number))
	assert_string_contains(line, p.display_name)
	assert_string_contains(line, "cm")
	assert_string_contains(line, "años")
	assert_between(p.base_data.get_age(), 18, 34)
	assert_string_contains(Replay.scorer_line(p, true), "en contra")


func test_no_replay_when_disabled() -> void:
	GameSettings.show_replays = false
	_score_goal()
	for i in int((MatchController.GOAL_DELAY + 0.2) / dt):
		m._physics_process(dt)
	assert_ne(m.phase, MatchController.Phase.REPLAY)
