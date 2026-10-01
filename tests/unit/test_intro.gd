extends GutTest
## Presentación previa al partido: recorre todas las etapas y termina en el
## saque del medio. Sin el pedido del menú, el partido arranca directo.


func after_each() -> void:
	GameSettings.play_intro = false


func test_without_menu_request_the_match_starts_directly() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	assert_eq(m.phase, MatchController.Phase.RESTART)
	assert_null(m.intro)


func test_intro_runs_all_steps_and_ends_in_the_kickoff() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.play_intro = true
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	assert_eq(m.phase, MatchController.Phase.INTRO)
	assert_false(GameSettings.play_intro, "se consume")
	var intro := m.intro
	for step in [MatchIntro.Step.WARMUP, MatchIntro.Step.TUNNEL, MatchIntro.Step.LINEUP,
			MatchIntro.Step.HANDSHAKE, MatchIntro.Step.FORMATION]:
		intro._enter(step)
		for i in 90:
			m._physics_process(1.0 / 60.0)
		assert_true(m._camera.cinematic, "toma cinematográfica en la etapa %d" % step)
	# Fila protocolar: el local quedó alineado frente a la tribuna.
	var ball_before := m.ball.flat_pos()
	intro._enter(MatchIntro.Step.DONE)
	assert_eq(m.phase, MatchController.Phase.RESTART, "termina en el saque del medio")
	assert_false(m._camera.cinematic)
	assert_almost_eq(ball_before.length(), 0.0, 0.5, "la pelota no se movió")


func test_intro_finishes_by_itself() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.play_intro = true
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.intro._enter(MatchIntro.Step.WARMUP)
	var total := 0.0
	for d in MatchIntro.DURATION.values():
		total += d
	for i in int((total + 2.0) * 60.0):
		m._physics_process(1.0 / 60.0)
		if m.phase != MatchController.Phase.INTRO:
			break
	assert_eq(m.phase, MatchController.Phase.RESTART)


func test_no_marks_over_players_during_the_presentation() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	GameSettings.play_intro = true
	var label := GameSettings.player_label
	GameSettings.player_label = 1 # números
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	for p in m.all_players():
		assert_false(p._label.visible, "sin número en la presentación")
		assert_false(p._arrow.visible)
	m.intro._enter(MatchIntro.Step.DONE)
	assert_true(m.all_players()[3]._label.visible, "en el partido, sí")
	GameSettings.player_label = label
