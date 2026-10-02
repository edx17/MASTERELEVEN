extends GutTest
## Repetición del gol: graba la jugada, la vuelve a mostrar con la ficha del
## goleador y después se saca del medio.

var m: MatchController
var dt := 1.0 / 60.0


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.show_replays = true
	GameSettings.replay_chances = true
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
	GameSettings.replay_chances = false


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
	for i in int((MatchController.CELEBRATION_MAX + 0.5) / dt):
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
	for i in int((MatchController.CELEBRATION_MAX + 0.5) / dt):
		m._physics_process(dt)
	assert_ne(m.phase, MatchController.Phase.REPLAY)


func _run_until(target: int, seconds: float) -> bool:
	for i in int(seconds / dt):
		m._physics_process(dt)
		if m.phase == target:
			return true
	return false


func test_near_miss_is_replayed_before_the_goal_kick() -> void:
	var t := m.teams[0]
	var shooter: Footballer = t.players[9]
	for i in 120:
		m.replay.record()
	var goal := t.target_goal()
	shooter.teleport(goal - Vector3(t.attack_dir * 16.0, 0, 0), Vector3(t.attack_dir, 0, 0))
	m.teams[1].keeper().teleport(goal - Vector3(t.attack_dir * 10.0, 0, 15.0))
	m.last_kick = {"kind": KickActions.Kind.SHOT, "team": 0, "pos": shooter.flat_pos(), "keeper": false, "player": shooter}
	# Afuera, pegado al palo.
	m.ball.place(goal + Vector3(t.attack_dir * 0.3, 0.5, 4.6))
	m.ball.state.vel = Vector3(t.attack_dir * 10.0, 0, 0)
	m.ball.last_toucher = shooter
	m.ball.last_touch_team = 0
	assert_true(_run_until(MatchController.Phase.STOPPED, 1.0), "se va afuera")
	assert_false(m.replay_request.is_empty(), "pide la repetición")
	assert_true(_run_until(MatchController.Phase.REPLAY, 3.0), "repetición de la jugada")
	assert_string_contains(m.replay._caption, shooter.display_name)
	assert_true(_run_until(MatchController.Phase.RESTART, 20.0))
	assert_eq(m.restart_type, MatchRules.Restart.GOAL_KICK, "y después el saque de arco")


func test_foul_with_card_is_replayed() -> void:
	for i in 120:
		m.replay.record()
	var vic: Footballer = m.teams[0].players[9]
	var off: Footballer = m.teams[1].players[3]
	vic.teleport(Vector3(10, 0, 0), Vector3(1, 0, 0))
	off.teleport(Vector3(9, 0, 0), Vector3(1, 0, 0))
	off.yellow_cards = 0
	var asked := false
	for i in 40:
		m.phase = MatchController.Phase.PLAYING
		m.replay_request = {}
		m.call_foul(off, vic, true)
		if not m.replay_request.is_empty():
			asked = true
			break
	assert_true(asked, "una falta con tarjeta o cerca del área se repite")


func test_hud_shows_only_the_score_during_the_replay() -> void:
	_score_goal()
	assert_true(_run_until(MatchController.Phase.REPLAY, MatchController.CELEBRATION_MAX + 0.5))
	var hud: MatchHud = null
	for c in m.get_children():
		if c is MatchHud:
			hud = c
	assert_not_null(hud)
	hud._process(dt)
	var shown := 0
	for c in hud.get_children():
		if c is CanvasItem and (c as CanvasItem).visible:
			shown += 1
	assert_eq(shown, 1, "sólo el marcador")
	assert_true(hud._top.visible)
