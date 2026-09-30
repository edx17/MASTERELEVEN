extends GutTest
## Prueba de humo: arma un partido CPU vs CPU y lo simula un rato para
## detectar errores de ejecución y comportamientos absurdos.

var _match: MatchController


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.match_minutes = 3
	_match = load("res://scenes/match/match.tscn").instantiate() as MatchController
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
	_simulate(3.0 * 60.0 + 45.0)
	assert_eq(_match.phase, MatchController.Phase.FULLTIME)
	gut.p("Resultado: %d - %d, patadas: %d" % [_match.teams[0].score, _match.teams[1].score, _match.kick_count])
