extends GutTest
## Nieve (pelota naranja, surcos que se tapan), marcas de barridas y nombre
## sobre el jugador controlado.

var _saved := []


func before_each() -> void:
	_saved = [GameSettings.weather_choice, GameSettings.player_label]


func after_each() -> void:
	GameSettings.weather_choice = _saved[0]
	GameSettings.player_label = _saved[1]


func _match() -> MatchController:
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	return m


func test_snow_uses_an_orange_ball_and_grooves_fill_up() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.weather_choice = MatchConditions.Weather.SNOW
	var m := _match()
	var mat := m.ball._mesh.material_override as StandardMaterial3D
	assert_gt(mat.albedo_color.r, mat.albedo_color.b + 0.5, "pelota naranja")
	m.atmosphere._process(0.016)
	var start: float = PitchBuilder.grass_material.get_shader_parameter("snow")
	m.clock.game_seconds = MatchClock.HALF_GAME_SECONDS * 0.9
	m.atmosphere._process(0.016)
	var g: float = PitchBuilder.grass_material.get_shader_parameter("groove_clear")
	var end_first: float = PitchBuilder.grass_material.get_shader_parameter("snow")
	assert_lt(g, 0.3, "al final del tiempo los surcos se taparon")
	assert_gt(end_first, start + 0.2, "la nieve se va acumulando")
	m.clock.start_second_half()
	m.atmosphere._process(0.016)
	assert_almost_eq(float(PitchBuilder.grass_material.get_shader_parameter("groove_clear")), 1.0, 0.01, "en el entretiempo se limpian las líneas")
	assert_gte(float(PitchBuilder.grass_material.get_shader_parameter("snow")), end_first, "pero la nieve acumulada sigue")
	m.clock.game_seconds = MatchClock.HALF_GAME_SECONDS
	m.atmosphere._process(0.016)
	assert_almost_eq(float(PitchBuilder.grass_material.get_shader_parameter("snow")), Atmosphere.SNOW_END, 0.01, "al final, casi todo blanco")


func test_wet_slide_leaves_a_mark() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.weather_choice = MatchConditions.Weather.RAIN
	var m := _match()
	var p: Footballer = m.teams[0].players[5]
	p.locked = false
	m.phase = MatchController.Phase.PLAYING
	p.start_slide(Vector3.RIGHT)
	assert_eq(m.atmosphere._marks.size(), 0, "todavía no tocó el piso: sin marca")
	var lengths := []
	for i in 30:
		m._physics_process(1.0 / 60.0)
		m.atmosphere._process(1.0 / 60.0)
		if not m.atmosphere._marks.is_empty():
			lengths.append((m.atmosphere._marks[0] as Decal).size.z)
	assert_eq(m.atmosphere._marks.size(), 1, "marca de barro")
	assert_gt(lengths[-1], lengths[0] + 0.5, "la marca se alarga mientras se desliza")


func test_name_over_the_controlled_player() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	GameSettings.player_label = 0
	var m := _match()
	m._physics_process(1.0 / 60.0)
	var controlled := m.humans[0].controlled
	assert_true(controlled._label.visible)
	assert_eq(controlled._label.text, controlled.display_name)
	var other: Footballer = m.teams[1].players[5]
	assert_false(other._label.visible, "los demás sin marca")
	GameSettings.player_label = 1
	other.refresh_label()
	assert_eq(other._label.text, str(other.number))
