extends GutTest
## Backlog B10 (tu prueba de la última versión): centros en el entrenamiento,
## gol que entra en la red, foco de la Dirección del equipo, árbitro en el
## saque del medio, entretiempo que espera y final con puntajes.

var m: MatchController
var dt := 1.0 / 60.0


func after_each() -> void:
	GameSettings.training = false


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


func _start_training() -> void:
	GameSettings.training = true
	GameSettings.training_kind = TrainingSession.Kind.FREE
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	GameSettings.human_side = 0
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)


## En el entrenamiento sin defensores, al tirar un centro los compañeros iban
## a la línea de su propio arco (la "línea del offside" daba 0).
func test_training_cross_runs_go_to_the_rival_box() -> void:
	_start_training()
	var t := m.training
	t.attackers = 4
	t.defenders = 0
	t.start()
	var team := m.teams[0]
	var ai: TeamAI = m.ais[0]
	var winger: Footballer = t._striker()
	var pos := team.target_goal() - Vector3(team.attack_dir * 14.0, 0, -26.0)
	winger.teleport(pos)
	m.ball.place(pos + Vector3(0, 0.11, 0))
	m.ball.give_to(winger)
	ai._assign_roles(m.ball)
	var runs := 0
	for p in ai.roles:
		if ai.roles[p] == "al área":
			runs += 1
			var target: Vector3 = ai._box_runs[p]
			assert_gt(team.progress_of(target), 0.8, "al área rival, no al propio arco")
	assert_gt(runs, 0, "alguien va al área")


func _start_match() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false


## Dirección del equipo: al cambiar la formación el foco se iba al último
## botón (una estrategia) y había que volver a "Formación".
func test_formation_button_keeps_the_focus() -> void:
	_start_match()
	var sh := TeamSheet.new()
	add_child_autofree(sh)
	sh.open(m, m.teams[0], false)
	var btn: Button = null
	for c in sh._menu.get_children():
		if (c as Button).text.begins_with("Formación"):
			btn = c
	assert_not_null(btn)
	btn.grab_focus()
	var before := m.teams[0].formation.formation_name
	sh._next_formation()
	var owner := sh.get_viewport().gui_get_focus_owner() as Button
	assert_not_null(owner)
	assert_true(owner.text.begins_with("Formación"), "el foco sigue en Formación")
	assert_ne(m.teams[0].formation.formation_name, before)
	sh._next_formation()
	owner = sh.get_viewport().gui_get_focus_owner() as Button
	assert_true(owner.text.begins_with("Formación"), "se puede seguir pasando")


## Saque del medio: el árbitro no tapa la pelota; está a un costado del
## círculo central, en el campo del equipo que saca.
func test_referee_beside_the_center_circle_on_kickoff() -> void:
	_start_match()
	for kicking in [0, 1]:
		m._setup_kickoff(kicking)
		var r := m.referee.global_position
		var kt := m.teams[kicking]
		assert_gt(Vector2(r.x, r.z).length(), Pitch.CENTER_CIRCLE_RADIUS, "fuera del círculo")
		assert_lt(kt.attack_dir * r.x, 0.0, "en el campo del que saca")
		assert_lt(r.z, 0.0, "del lado de enfrente de la cámara")
		m._physics_process(dt)
		var r2 := m.referee.global_position
		assert_almost_eq(r2.distance_to(r), 0.0, 0.2, "se queda ahí hasta el saque")


## Pase que llega, gol con asistencia y puntajes: el goleador y el asistidor
## suben; el arquero que recibió el gol baja; los que casi no jugaron, "—".
func test_ratings_goal_assist_and_keeper() -> void:
	_start_match()
	var r := m.ratings
	var t0 := m.teams[0]
	var t1 := m.teams[1]
	var passer: Footballer = t0.players[8]
	var scorer: Footballer = t0.players[9]
	var keeper := t1.keeper()
	# Minutos jugados para todos.
	r.tick(dt, 30.0, m.teams, null)
	r.on_pass(passer)
	r.tick(dt, 0.0, m.teams, scorer)
	assert_eq(r.of(passer)["passes_ok"], 1, "el pase llegó")
	r.on_shot(scorer)
	r.on_goal(scorer, 0, m.teams)
	assert_eq(r.of(scorer)["goals"], 1)
	assert_eq(r.of(passer)["assists"], 1)
	assert_eq(r.of(keeper)["conceded"], 1)
	assert_gt(r.rating(scorer), 7.0, "el goleador")
	assert_gt(r.rating(passer), 6.5, "el que asistió")
	assert_lt(r.rating(keeper), 6.0, "el arquero que recibió el gol")
	assert_eq(r.man_of_the_match(), scorer, "figura del partido")
	# Un pase cortado cuenta como intercepción del rival.
	var defender: Footballer = t1.players[3]
	r.on_pass(passer)
	r.tick(dt, 0.0, m.teams, defender)
	assert_eq(r.of(defender)["interceptions"], 1)
	# Un suplente que no jugó casi nada no tiene puntaje.
	var fresh := PlayerRatings.new()
	fresh.tick(dt, 3.0, m.teams, null)
	assert_eq(fresh.rating(scorer), -1.0)


## El partido avisa los hechos: un pase de la CPU que llega se cuenta.
func test_match_feeds_the_ratings() -> void:
	_start_match()
	var p: Footballer = m.teams[0].players[6]
	m.ball.place(p.flat_pos() + Vector3(m.teams[0].attack_dir * 0.4, 0.11, 0))
	m.ball.give_to(p)
	m.perform_kick(p, KickActions.Kind.SHORT_PASS, Vector3(m.teams[0].attack_dir, 0, 0), 0.4)
	assert_eq(m.ratings.of(p)["passes"], 1)
	_step(240)
	assert_gt(m.ratings.of(p)["minutes"], 0.0, "suma minutos")


## Final: en lugar de la Dirección del equipo, los puntajes; el entretiempo
## espera (no arranca solo el segundo tiempo) y los botones no responden el
## primer segundo y medio.
func test_final_shows_ratings_and_halftime_waits() -> void:
	_start_match()
	var hs := m.halftime_screen
	m.phase = MatchController.Phase.HALFTIME
	m._show_break()
	assert_true(hs.visible)
	assert_true(hs._sheet_btn.visible, "en el entretiempo, Dirección del equipo")
	assert_false(hs._ratings_btn.visible)
	assert_true(hs._continue.disabled, "no se saltea apretando de más")
	assert_eq(m._phase_timer, INF, "espera al usuario")
	for i in 600:
		m._physics_process(dt)
	assert_eq(m.phase, MatchController.Phase.HALFTIME, "sigue en el entretiempo")
	hs.close()
	m.phase = MatchController.Phase.FULLTIME
	m._show_break()
	assert_false(hs._sheet_btn.visible, "en el final no hay Dirección del equipo")
	assert_true(hs._ratings_btn.visible)
	hs._toggle_ratings()
	assert_eq(hs.rating_rows(m.teams[0]).size(), m.teams[0].players.size())
