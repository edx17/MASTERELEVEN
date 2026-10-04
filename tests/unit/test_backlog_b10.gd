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


func _start_match(mode: int = GameSettings.Mode.CPU_VS_CPU) -> void:
	GameSettings.set_mode(mode)
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


func _goal_shot() -> void:
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	for p in m.all_players():
		p.locked = false
	var t := m.teams[0]
	m.teams[1].keeper().teleport(t.target_goal() + Vector3(0, 0, 30))
	var shooter: Footballer = t.players[9]
	var gx := t.target_goal().x
	var pos := Vector3(gx - t.attack_dir * 14.0, 0, 2.0)
	shooter.teleport(pos)
	m.ball.place(pos + Vector3(t.attack_dir * 0.4, 0.11, 0))
	m.ball.give_to(shooter)
	m.kicks.randomize_error = false
	m.perform_kick(shooter, KickActions.Kind.SHOT, Vector3(t.attack_dir, 0, 0), 0.25)


## La repetición del gol sigue 3 s después de que entra (la pelota en la red,
## no frenada sobre la línea) y después viene el festejo desde otro ángulo.
func test_goal_replay_shows_the_net_and_then_the_celebration() -> void:
	_start_match()
	GameSettings.show_replays = true
	_goal_shot()
	for i in 240:
		if m.phase == MatchController.Phase.GOAL:
			break
		m._physics_process(dt)
	assert_eq(m.phase, MatchController.Phase.GOAL, "gol")
	var goal_x := m.teams[0].target_goal().x
	for i in int(12.0 / dt):
		if m.phase == MatchController.Phase.REPLAY:
			break
		m._physics_process(dt)
	assert_eq(m.phase, MatchController.Phase.REPLAY)
	var clip: Dictionary = m.highlights[-1]
	var frames: Array = clip["frames"]
	var ev: int = clip["event"]
	assert_gte(frames.size() - 1 - ev, int(Replay.POST * Replay.RATE) - 1, "3 s después del gol")
	assert_lte(ev, int(Replay.PRE_MAX * Replay.RATE), "a lo sumo 6 s antes")
	var last_ball: Vector3 = frames[-1]["ball"]
	assert_gt(absf(last_ball.x), absf(goal_x) + 0.4, "la pelota adentro del arco, no sobre la línea")
	assert_false(m._celebration_clip.is_empty(), "el festejo queda para después")
	# Termina la del gol: viene el festejo, siguiendo al goleador.
	m.replay._wipe.advance(1.0)
	m.replay.stop()
	m.replay._wipe.advance(1.0)
	assert_eq(m.phase, MatchController.Phase.REPLAY, "sigue la repetición")
	assert_eq(m.replay.kind, Replay.Kind.CELEBRATION)
	assert_true(m._celebration_clip.is_empty())


## Mientras se festeja, la cámara sigue al goleador de cerca.
func test_camera_follows_the_scorer() -> void:
	_start_match()
	_goal_shot()
	for i in 240:
		if m.phase == MatchController.Phase.GOAL:
			break
		m._physics_process(dt)
	for i in 90:
		m._physics_process(dt)
	var cam := m.camera()
	cam._process(1.0)
	var scorer: Footballer = m.celebration["scorer"]
	assert_true(cam.cinematic)
	assert_lt(cam.shot_pos.distance_to(scorer.global_position), 12.0, "plano medio")


## Sin tirones: entre dos cuadros la pelota queda en el medio.
func test_replay_interpolates_between_frames() -> void:
	_start_match()
	m.ball.place(Vector3(0, 0.11, 0))
	m.ball.state.vel = Vector3(12, 0, 0)
	for i in 120:
		m._physics_process(dt)
	var r := m.replay
	r.kind = Replay.Kind.CHANCE
	var a: Vector3 = r._frames[10]["ball"]
	var b: Vector3 = r._frames[11]["ball"]
	r._apply_frame(10.5, 0.0, true)
	assert_almost_eq(m.ball.global_position.x, (a.x + b.x) * 0.5, 0.01)


## Offside: la toma es lateral y lejana, en el momento del pase.
func test_offside_replay_is_a_wide_side_shot() -> void:
	_start_match()
	var t := m.teams[0]
	for i in 120:
		m._physics_process(dt)
	var passer: Footballer = t.players[6]
	var off: Footballer = t.players[9]
	m.replay.mark_kick()
	for i in 30:
		m._physics_process(dt)
	m.phase = MatchController.Phase.PLAYING
	m.call_offside(off, m.offside_line(t), passer)
	GameSettings.replay_chances = true
	m._phase_timer = 0.0
	for i in int((Replay.POST + 0.5) / dt):
		if m.phase == MatchController.Phase.REPLAY:
			break
		m._physics_process(dt)
	assert_eq(m.phase, MatchController.Phase.REPLAY)
	assert_eq(m.replay.kind, Replay.Kind.OFFSIDE)
	assert_gt(m.replay._freeze_left, 0.0, "se congela en el pase")
	m.replay._wipe.advance(1.0)
	m.replay.tick(dt)
	var cam := m.camera()
	assert_gt(cam.shot_pos.z, 30.0, "desde la banda, lejos")


## L2 + cruceta: mentalidad defensiva / equilibrada / ofensiva.
func test_mentality_with_l2_and_dpad() -> void:
	_start_match(GameSettings.Mode.VS_CPU)
	var inp := ScriptedInput.new()
	m.humans[0].input = inp
	var t := m.humans[0].team
	assert_eq(t.mentality, 0)
	inp.hold(&"strategy")
	inp.hold(&"mentality_up")
	m.humans[0].tick(dt)
	assert_eq(t.mentality, 1, "ofensiva")
	inp.release(&"mentality_up")
	m.humans[0].tick(dt)
	inp.hold(&"mentality_down")
	m.humans[0].tick(dt)
	inp.release(&"mentality_down")
	m.humans[0].tick(dt)
	inp.hold(&"mentality_down")
	m.humans[0].tick(dt)
	assert_eq(t.mentality, -1, "defensiva")
	# Sin L2 la cruceta no cambia la mentalidad.
	inp.release(&"strategy")
	inp.release(&"mentality_down")
	m.humans[0].tick(dt)
	inp.hold(&"mentality_up")
	m.humans[0].tick(dt)
	assert_eq(t.mentality, -1)


## Con mentalidad ofensiva el bloque sube con la pelota (laterales y
## volantes más que nadie); con la defensiva se queda.
func test_mentality_moves_the_block() -> void:
	var f := FormationLibrary.build("4-4-2")
	var ball := Vector2(0.6, 0.0)
	var base := TeamShape.compute(f, TeamShape.State.ATTACKING, ball)
	var off := TeamShape.compute(f, TeamShape.State.ATTACKING, ball, 0, 1)
	var dfn := TeamShape.compute(f, TeamShape.State.ATTACKING, ball, 0, -1)
	var sum := [0.0, 0.0, 0.0]
	for i in range(1, base.size()):
		sum[0] += base[i].x
		sum[1] += off[i].x
		sum[2] += dfn[i].x
	assert_gt(sum[1], sum[0], "ofensiva: más arriba")
	assert_lt(sum[2], sum[0], "defensiva: más atrás")


## En el área con el arco libre la CPU remata casi siempre, y no la devuelve
## a un compañero peor ubicado.
func test_cpu_shoots_in_the_box() -> void:
	_start_match()
	var ai: TeamAI = m.ais[0]
	var t := m.teams[0]
	var p: Footballer = t.players[9]
	var goal := t.target_goal()
	assert_gte(ai.shot_chance(p, 12.0, true, true), 0.75, "en el área, libre")
	assert_gte(ai.shot_chance(p, 12.0, true, false), 0.45, "en el área, tapado")
	assert_lt(ai.shot_chance(p, 25.0, false, true), 0.3, "de lejos, menos")
	var mate: Footballer = t.players[7]
	p.teleport(goal - Vector3(t.attack_dir * 11.0, 0, 2.0))
	mate.teleport(goal - Vector3(t.attack_dir * 16.0, 0, 14.0))
	assert_false(ai._better_finisher(mate, p, goal), "el de atrás no define mejor")
	mate.teleport(goal - Vector3(t.attack_dir * 5.0, 0, -1.0))
	for o in m.teams[1].players:
		o.teleport(Vector3(-t.attack_dir * 30.0, 0, o.global_position.z))
	assert_true(ai._better_finisher(mate, p, goal), "el que está solo frente al arco, sí")


## Entretiempo: se van caminando al túnel (uno va a hablar con el árbitro) y
## en la pantalla la cancha queda vacía; en el segundo tiempo vuelven.
func test_halftime_walk_off_and_empty_pitch() -> void:
	_start_match()
	m._end_half()
	_step(int(MatchController.WHISTLE_COAST / dt) + 2)
	assert_false(m.walk_off.is_empty())
	var to_ref := 0
	var to_tunnel: Array = []
	for p in m.walk_off:
		if p is Footballer:
			if m.walk_off[p][0] == "ref":
				to_ref += 1
			elif m.walk_off[p][0] == "tunnel":
				to_tunnel.append(p)
	assert_eq(to_ref, 1, "uno va al árbitro")
	assert_gt(to_tunnel.size(), 10)
	var p0: Footballer = to_tunnel[0]
	var d0 := p0.flat_pos().distance_to(Vector3(0, 0, StadiumBuilder.tunnel_z))
	_step(120)
	var d1 := p0.flat_pos().distance_to(Vector3(0, 0, StadiumBuilder.tunnel_z))
	assert_lt(d1, d0, "camina hacia el túnel")
	assert_lt(p0.velocity.length(), m.tuning.run_speed * 0.6, "caminando, no corriendo")
	_step(int(MatchController.WALK_OFF_TIME / dt))
	assert_true(m.halftime_screen.visible)
	for p in m.all_players():
		assert_false(p.visible, "cancha vacía")
	m.start_second_half()
	for p in m.teams[0].players:
		assert_true(p.visible, "vuelven para el segundo tiempo")


## Final: los que ganaron festejan o aplauden; los que perdieron se tiran al
## piso, se agarran la cabeza o protestan. Después, la tribuna se vacía.
func test_fulltime_reactions_and_crowd_leaves() -> void:
	_start_match()
	m.teams[0].score = 2
	m.clock.half = 2
	m._end_half()
	assert_eq(m.phase, MatchController.Phase.FULLTIME)
	_step(int(MatchController.WHISTLE_COAST / dt) + 2)
	var winners := {}
	var losers := {}
	for p in m.walk_off:
		if not (p is Footballer):
			continue
		var w: Array = m.walk_off[p]
		var key := "%s:%s" % [w[0], w[2]]
		if p.team == m.teams[0]:
			winners[key] = true
		else:
			losers[key] = true
	assert_true(winners.has("stay:%d" % PlayerVisual.Event.CHEER), "festejan")
	assert_true(winners.has("stay:%d" % PlayerVisual.Event.APPLAUD), "aplauden")
	assert_true(losers.has("down:-1"), "al piso")
	assert_true(losers.has("ref:%d" % PlayerVisual.Event.PROTEST), "le protestan al árbitro")
	assert_true(losers.has("stay:%d" % PlayerVisual.Event.HEAD_HOLD) or losers.has("stay:%d" % PlayerVisual.Event.HANDS_HIPS))
	_step(int(MatchController.FULLTIME_REACTIONS / dt) + 2)
	assert_true(m.halftime_screen.visible)
	_step(600)
	var empty: float = StadiumBuilder.crowd_material.get_shader_parameter("empty")
	assert_gt(empty, 0.05, "la gente se va yendo")
