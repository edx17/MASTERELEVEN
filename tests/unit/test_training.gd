extends GutTest
## Entrenamiento (Club House): cancha sin tribunas, sin reloj, la jugada se
## rearma sola, pelota parada configurable y desafíos con puntaje.

var m: MatchController
var dt := 1.0 / 60.0


func _start(kind: int) -> void:
	GameSettings.training = true
	GameSettings.training_kind = kind
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	GameSettings.human_side = 0
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)


func after_each() -> void:
	GameSettings.training = false


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


func test_club_house_without_stands_clock_or_referee() -> void:
	_start(TrainingSession.Kind.FREE)
	assert_not_null(m.training)
	assert_not_null(m.stadium.find_child("ClubHouse", false, false), "el edificio del club")
	assert_null(m.stadium.find_child("StandNorth*", false, false), "sin tribunas")
	assert_false(m.referee.visible, "sin árbitro")
	_step(120)
	assert_eq(m.clock.total_game_seconds(), 0.0, "el reloj no corre")


func test_free_practice_squads_and_reset() -> void:
	_start(TrainingSession.Kind.FREE)
	var t := m.training
	assert_eq(t.outfield(m.teams[0]).size(), 4)
	assert_null(m.teams[0].keeper(), "tu arquero no hace falta")
	assert_eq(t.outfield(m.teams[1]).size(), 3)
	assert_not_null(m.teams[1].keeper())
	assert_eq(m.ball.owner_player, t._striker(), "el delantero arranca con la pelota")
	t.attackers = 2
	t.defenders = 5
	t.rival_keeper = false
	t.start()
	assert_eq(t.outfield(m.teams[0]).size(), 2)
	assert_eq(t.outfield(m.teams[1]).size(), 5)
	assert_null(m.teams[1].keeper())
	for p in m.teams[1].roster:
		assert_eq(p.visible, m.teams[1].players.has(p), "los que no juegan, ocultos")
	# Se juega un rato y se reinicia.
	_step(90)
	t.reset_play()
	assert_eq(m.ball.owner_player, t._striker())
	assert_eq(m.phase, MatchController.Phase.PLAYING)


func test_goal_counts_and_the_play_is_rebuilt() -> void:
	_start(TrainingSession.Kind.FREE)
	var t := m.training
	var goal := m.teams[0].target_goal()
	m.ball.owner_player = null
	m.ball.place(goal + Vector3(m.teams[0].attack_dir * 0.6, 0.5, 0))
	m.ball.last_touch_team = 0
	_step(2)
	assert_eq(t.goals, 1)
	assert_eq(t.message, "¡GOL!")
	assert_eq(m.phase, MatchController.Phase.STOPPED, "sin festejo ni saque del medio")
	_step(int(TrainingSession.RESET_DELAY / dt) + 3)
	assert_eq(m.phase, MatchController.Phase.PLAYING, "se rearma sola")
	assert_eq(m.ball.owner_player, t._striker())
	assert_eq(m.teams[0].score, 0, "no hay marcador")


func test_free_kick_spot_wall_and_taker() -> void:
	_start(TrainingSession.Kind.FREE_KICK)
	var t := m.training
	t.defenders = 5
	t.fk_distance = 25.0
	t.fk_angle = -20.0
	t.start()
	assert_eq(m.phase, MatchController.Phase.RESTART)
	assert_eq(m.restart_type, MatchRules.Restart.FREE_KICK)
	assert_almost_eq(m.ball.flat_pos().distance_to(m.teams[0].target_goal()), 25.0, 0.6)
	assert_gt(m.wall_targets.size(), 0, "con barrera")
	t.wall = false
	t.reset_play()
	assert_eq(m.wall_targets.size(), 0, "sin barrera")
	t.taker_index = 1
	t.reset_play()
	assert_eq(m.restart_taker, t.taker(), "el pateador elegido")


func test_corner_and_penalty_spots() -> void:
	_start(TrainingSession.Kind.CORNER)
	assert_eq(m.restart_type, MatchRules.Restart.CORNER)
	assert_gt(absf(m.ball.flat_pos().z), Pitch.HALF_WIDTH - 1.0)
	m.training.start(TrainingSession.Kind.PENALTY)
	assert_eq(m.restart_type, MatchRules.Restart.PENALTY)
	assert_almost_eq(m.ball.flat_pos().distance_to(m.teams[0].target_goal()), Pitch.PENALTY_SPOT_DISTANCE, 0.2)


func test_set_piece_save_ends_the_attempt() -> void:
	_start(TrainingSession.Kind.PENALTY)
	var t := m.training
	m.restart_taker = null
	m._set_phase(MatchController.Phase.PLAYING)
	t._prev_phase = MatchController.Phase.RESTART
	m.ball.give_to(m.teams[1].keeper(), false, true)
	t.tick(dt)
	t.tick(dt)
	assert_eq(t.attempts, 1)
	assert_eq(t.message, "¡ATAJÓ!")


func test_slalom_time_and_missed_gates() -> void:
	_start(TrainingSession.Kind.SLALOM)
	var t := m.training
	assert_eq(t.outfield(m.teams[0]).size(), 1)
	assert_eq(m.teams[1].players.size(), 0, "solo")
	assert_eq(t._gates.size(), TrainingSession.SLALOM_GATES)
	var p := t._striker()
	var dir := float(m.teams[0].attack_dir)
	# Pasa por todas las banderas menos una, y llega.
	for i in t._gates.size():
		var g: Array = t._gates[i]
		var z: float = float(g[1]) if i != 2 else -float(g[1])
		p.teleport(Vector3(float(g[0]) + dir * 0.2, 0, z), Vector3(dir, 0, 0))
		m.ball.give_to(p)
		t.tick(0.5)
	p.teleport(Vector3(t._start_x + dir * TrainingSession.SLALOM_SPACING * (TrainingSession.SLALOM_GATES + 1.2), 0, 0), Vector3(dir, 0, 0))
	m.ball.give_to(p)
	t.tick(0.5)
	assert_true(t.finished)
	assert_almost_eq(t._penalty, TrainingSession.SLALOM_MISS_PENALTY, 0.01, "una bandera salteada")
	assert_true(t.best.has(TrainingSession.KIND_NAMES[TrainingSession.Kind.SLALOM]), "queda el récord")


func test_passing_scores_on_the_marked_teammate() -> void:
	_start(TrainingSession.Kind.PASSING)
	var t := m.training
	assert_eq(t._station_players.size(), 5)
	var target := t._target
	assert_ne(target, t._holder)
	m.ball.give_to(target)
	t.tick(dt)
	assert_eq(t.score, 1)
	assert_true(t.running, "arranca el reloj")
	assert_ne(t._target, target, "otro compañero marcado")


func test_rondo_ends_when_the_markers_win_it() -> void:
	_start(TrainingSession.Kind.RONDO)
	var t := m.training
	assert_eq(t.outfield(m.teams[1]).size(), 2, "dos marcas")
	m.ball.give_to(t._station_players[2])
	t.tick(dt)
	m.ball.give_to(t._station_players[3])
	t.tick(dt)
	assert_eq(t._passes, 2)
	m.ball.give_to(t.outfield(m.teams[1])[0])
	t.tick(dt)
	assert_true(t.finished)
	assert_eq(t.message.ends_with("2 pases seguidos"), true)


func test_targets_score_the_corners() -> void:
	_start(TrainingSession.Kind.TARGETS)
	var t := m.training
	assert_eq(t._rings.size(), 4)
	var goal := m.teams[0].target_goal()
	var corner := Vector3(goal.x, Pitch.GOAL_HEIGHT - 0.6, Pitch.GOAL_HALF_WIDTH - 0.6)
	assert_eq(t.target_points(corner), 3, "al ángulo")
	assert_eq(t.target_points(Vector3(goal.x, 1.0, 0.0)), 1, "al medio")


func test_every_practice_runs_without_errors() -> void:
	_start(TrainingSession.Kind.FREE)
	for k in TrainingSession.KIND_NAMES.size():
		m.training.start(k)
		_step(150)
		m.training.reset_play()
		_step(30)
	assert_true(true, "todas las prácticas se juegan un rato")


func test_club_house_sound_is_drums_without_crowd() -> void:
	var w := MatchAudio.sound("drums")
	assert_gt(w.data.size(), 1000, "loop de percusión generado")
	assert_eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	_start(TrainingSession.Kind.FREE)
	assert_true(m.audio._training, "sin hinchada en el Club House")
