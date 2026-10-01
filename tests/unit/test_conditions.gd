extends GutTest
## Horario, clima, viento y césped: efectos en el juego y en la presentación.

var _saved := []


func before_each() -> void:
	_saved = [GameSettings.time_choice, GameSettings.weather_choice, GameSettings.wind_choice, GameSettings.pitch_choice]


func after_each() -> void:
	GameSettings.time_choice = _saved[0]
	GameSettings.weather_choice = _saved[1]
	GameSettings.wind_choice = _saved[2]
	GameSettings.pitch_choice = _saved[3]


func _tuning_for(c: MatchConditions) -> Tuning:
	var t: Tuning = GameSettings.tuning.duplicate()
	c.apply_to(t)
	return t


## Distancia que recorre un pase rasante a 15 m/s.
func _roll_distance(t: Tuning) -> float:
	var s := BallState.new()
	s.pos = Vector3(0, t.ball_radius, 0)
	s.vel = Vector3(15, 0, 0)
	for i in 600:
		BallPhysics.step(s, 1.0 / 60.0, t)
	return s.pos.x


func test_defaults_are_a_dry_clear_afternoon() -> void:
	var c := GameSettings.make_conditions()
	assert_eq(c.time_of_day, MatchConditions.TimeOfDay.AFTERNOON)
	assert_eq(c.weather, MatchConditions.Weather.CLEAR)
	assert_eq(c.wind_speed, 0.0)
	assert_eq(c.wetness, 0.0)


func test_wet_pitch_makes_the_ball_run_and_snow_stops_it() -> void:
	var dry := _roll_distance(_tuning_for(MatchConditions.create(1, 0, 0.0, 0.0, 0.0)))
	var wet := _roll_distance(_tuning_for(MatchConditions.create(1, 2, 0.0, 0.0, 0.85)))
	var snow := _roll_distance(_tuning_for(MatchConditions.create(1, 3, 0.0, 0.0, 0.3)))
	gut.p("pase rasante: seco %.1f m, mojado %.1f m, nieve %.1f m" % [dry, wet, snow])
	assert_gt(wet, dry * 1.2, "con lluvia corre más")
	assert_lt(snow, dry * 0.8, "con nieve frena")


func test_wind_drifts_the_ball_in_the_air_only() -> void:
	var calm := _tuning_for(MatchConditions.create(1, 0, 0.0, 0.0, 0.0))
	var windy := _tuning_for(MatchConditions.create(1, 0, 9.0, 90.0, 0.0)) # sopla hacia +Z
	for t: Tuning in [calm, windy]:
		var s := BallState.new()
		s.pos = Vector3(0, t.ball_radius, 0)
		s.vel = Vector3(16, 14, 0) # pelotazo
		for i in 120:
			BallPhysics.step(s, 1.0 / 60.0, t)
		if t == calm:
			assert_almost_eq(s.pos.z, 0.0, 0.01)
		else:
			gut.p("desvío del pelotazo con viento de 9 m/s: %.1f m" % s.pos.z)
			assert_gt(s.pos.z, 1.0, "el viento lo lleva")
	# Rodando por el piso, el viento no la mueve de costado.
	var g := BallState.new()
	g.pos = Vector3(0, windy.ball_radius, 0)
	g.vel = Vector3(10, 0, 0)
	for i in 60:
		BallPhysics.step(g, 1.0 / 60.0, windy)
	assert_almost_eq(g.pos.z, 0.0, 0.01)


func test_wet_slides_go_further_and_trip_more() -> void:
	var dry := _tuning_for(MatchConditions.create(1, 0, 0.0, 0.0, 0.0))
	var wet := _tuning_for(MatchConditions.create(1, 2, 0.0, 0.0, 1.0))
	assert_gt(wet.slide_duration, dry.slide_duration)
	assert_gt(wet.slide_trip_chance, dry.slide_trip_chance)


func test_menu_choices_map_to_conditions() -> void:
	GameSettings.time_choice = MatchConditions.TimeOfDay.NIGHT
	GameSettings.weather_choice = MatchConditions.Weather.RAIN
	GameSettings.wind_choice = 2
	GameSettings.pitch_choice = -1
	var c := GameSettings.make_conditions()
	assert_eq(c.time_of_day, MatchConditions.TimeOfDay.NIGHT)
	assert_eq(c.weather, MatchConditions.Weather.RAIN)
	assert_eq(c.wind_speed, 9.0)
	assert_gt(c.wetness, 0.6, "la lluvia moja el césped")
	assert_string_contains(c.describe(), "Noche")


func test_every_combination_builds() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	for time in 4:
		for weather in 4:
			GameSettings.time_choice = time
			GameSettings.weather_choice = weather
			GameSettings.wind_choice = 1
			var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
			add_child(m)
			m.set_physics_process(false)
			var a := m.atmosphere
			assert_not_null(a.environment)
			var night := time == MatchConditions.TimeOfDay.NIGHT
			if night:
				assert_eq(a.floodlights.size(), 4, "torres de luz de noche")
			assert_eq(a.precipitation != null, weather >= MatchConditions.Weather.RAIN)
			assert_almost_eq(m.tuning.wind.length(), 4.0, 0.01, "el viento llega a la física")
			m.free()


func test_match_tuning_is_a_copy() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.pitch_choice = 2
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	assert_ne(m.tuning, GameSettings.tuning)
	assert_lt(m.tuning.rolling_decel, GameSettings.tuning.rolling_decel, "mojado en el partido")
	assert_almost_eq(GameSettings.tuning.wind.length(), 0.0, 0.001, "el ajuste base no cambia")
