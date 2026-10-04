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
			MatchIntro.Step.PRESENT_HOME, MatchIntro.Step.PRESENT_AWAY, MatchIntro.Step.FORMATION]:
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


func test_warmup_has_rondos_and_keepers_saving() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.play_intro = true
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	var intro := m.intro
	assert_eq(intro._rondos.size(), 4, "dos rondos 4 contra 1 por equipo")
	assert_eq(intro._keeper_drills.size(), 2)
	for r in intro._rondos:
		assert_eq((r["ring"] as Array).size(), 4)
	var dives := [0]
	var gk := m.teams[0].keeper()
	gk.visual.played.connect(func(_e: int, _s: float) -> void: dives[0] += 1)
	var passes := [0]
	for r in intro._rondos:
		for p in r["ring"]:
			(p as Footballer).visual.played.connect(func(e: int, _s: float) -> void:
				if e == PlayerVisual.Event.PASS:
					passes[0] += 1)
	for i in 60 * 6:
		m._physics_process(1.0 / 60.0)
	assert_gt(passes[0], 6, "la pelota circula en los rondos")
	assert_gt(dives[0], 0, "el arquero ataja")
	var home: Vector3 = intro._keeper_drills[0]["home"]
	assert_lt(Pitch.goal_center(m.teams[0].own_side()).distance_to(gk.flat_pos()), 4.0, "el arquero en su arco")
	assert_true(home.is_finite())
	# Al salir por el túnel desaparecen las pelotas de utilería.
	intro._enter(MatchIntro.Step.TUNNEL)
	assert_eq(intro._rondos.size(), 0)


func test_presentation_dollies_along_each_team_and_announces_everyone() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.play_intro = true
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	var intro := m.intro
	var named: Array = []
	intro.player_announced.connect(func(p: Footballer) -> void: named.append(p))
	intro._enter(MatchIntro.Step.TUNNEL)
	# Las filas ya formadas (cada equipo en su lado, sin cruzarse).
	for p in intro._targets:
		p.teleport(intro._targets[p], Vector3.BACK)
	intro._enter(MatchIntro.Step.PRESENT_HOME)
	var xs: Array[float] = []
	while intro.step == MatchIntro.Step.PRESENT_HOME:
		m._physics_process(1.0 / 60.0)
		xs.append(m._camera.shot_pos.x)
		assert_lt(m._camera.shot_pos.z, MatchIntro.ROW_Z + MatchIntro.DOLLY_DIST + 1.5, "de frente y cerca")
	assert_eq(named.size(), 11, "los once del local, uno por uno")
	for p in named:
		assert_eq((p as Footballer).team.index, 0)
		assert_lt((p as Footballer).flat_pos().x, 0.0, "el local en su mitad de la fila")
	assert_gt(absf(xs[0] - xs[-1]), 8.0, "la cámara recorre la fila")
	while intro.step == MatchIntro.Step.PRESENT_AWAY:
		m._physics_process(1.0 / 60.0)
	assert_eq(named.size(), 22)
	for i in range(11, 22):
		assert_gt((named[i] as Footballer).flat_pos().x, 0.0, "el visitante en su lado: nadie pasa por delante")
