extends GutTest
## Prueba de humo: arma un partido CPU vs CPU y lo simula un rato para
## detectar errores de ejecución y comportamientos absurdos.

var _match: MatchController


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.match_minutes = 3
	_match = load("res://scenes/match/match.tscn").instantiate() as MatchController
	_match.break_auto_continue = true
	add_child_autofree(_match)
	# El partido se avanza a mano, tick por tick.
	_match.set_physics_process(false)


func after_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	GameSettings.match_minutes = 5


func _simulate(seconds: float) -> void:
	var dt := 1.0 / 60.0
	for i in int(seconds / dt):
		_match._physics_process(dt)


func test_match_builds_22_players() -> void:
	assert_eq(_match.all_players().size(), 22)
	assert_eq(_match.phase, MatchController.Phase.RESTART, "arranca con saque del medio")


func test_kickoff_is_taken_and_ball_moves() -> void:
	_simulate(3.0)
	assert_ne(_match.phase, MatchController.Phase.RESTART, "la IA tiene que sacar del medio")
	assert_gt(_match.kick_count, 0)


func test_cpu_match_runs_without_players_leaving_the_area() -> void:
	_simulate(40.0)
	for p in _match.all_players():
		assert_lt(absf(p.global_position.x), Pitch.HALF_LENGTH + 6.0, "%s dentro de la zona de juego" % p.name)
		assert_lt(absf(p.global_position.z), Pitch.HALF_WIDTH + 6.0, "%s dentro de la zona de juego" % p.name)
	assert_gt(_match.kick_count, 3, "tiene que haber pases/tiros")
	assert_gt(_match.clock.total_game_seconds(), 0.0)


func test_full_match_reaches_final_whistle() -> void:
	# El reloj se frena con la pelota parada (faltas, laterales, saques):
	# el partido dura más que sus minutos en tiempo real. Se simula hasta el
	# final con un tope generoso.
	var waited := 0.0
	while _match.phase != MatchController.Phase.FULLTIME and waited < 3.0 * 60.0 * 2.0:
		_simulate(15.0)
		waited += 15.0
	assert_eq(_match.phase, MatchController.Phase.FULLTIME)
	gut.p("Resultado: %d - %d, patadas: %d" % [_match.teams[0].score, _match.teams[1].score, _match.kick_count])
	# Cansancio acumulado y cambios de la CPU.
	var worst := 0.0
	var total := 0.0
	for p in _match.all_players():
		worst = maxf(worst, p.wear)
		total += p.wear
	gut.p("Desgaste: promedio %.1f, máximo %.1f; cambios %d - %d" % [total / _match.all_players().size(), worst,
			_match.stats["subs"][0], _match.stats["subs"][1]])
	gut.p("Choques: %d, lesiones: %d, faltas: %d" % [_match.stats["contacts"][0] + _match.stats["contacts"][1],
			_match.stats["injuries"][0] + _match.stats["injuries"][1], _match.stats["fouls"][0] + _match.stats["fouls"][1]])
	for t in _match.teams:
		assert_eq(t.players.size() + t.sent_off.size(), 11, "los cambios no cambian la cantidad")
		assert_lte(t.subs_used, Team.MAX_SUBS)


func test_debug_overlay_runs() -> void:
	var dbg: DebugOverlay = null
	for c in _match.get_children():
		if c is DebugOverlay:
			dbg = c
	assert_not_null(dbg)
	dbg._set_enabled(true)
	for i in 30:
		_match._physics_process(1.0 / 60.0)
		dbg._process(1.0 / 60.0)
	assert_string_contains(dbg._label.text, "posesión")
