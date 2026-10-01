extends GutTest
## Configuración guardada entre sesiones y miniaturas de los estadios.

const PATH := "user://test_settings.cfg"
var _backup := {}


func before_each() -> void:
	for key in GameSettings.SAVED:
		_backup[key] = GameSettings.get(key)


func after_each() -> void:
	for key in _backup:
		GameSettings.set(key, _backup[key])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_settings_round_trip() -> void:
	GameSettings.stadium_choice = 2
	GameSettings.weather_choice = MatchConditions.Weather.RAIN
	GameSettings.game_speed = -1
	GameSettings.match_minutes = 10
	GameSettings.save_settings(PATH)
	GameSettings.stadium_choice = 0
	GameSettings.weather_choice = MatchConditions.Weather.CLEAR
	GameSettings.game_speed = 0
	GameSettings.match_minutes = 5
	GameSettings.load_settings(PATH)
	assert_eq(GameSettings.stadium_choice, 2)
	assert_eq(GameSettings.weather_choice, MatchConditions.Weather.RAIN)
	assert_eq(GameSettings.game_speed, -1)
	assert_eq(GameSettings.match_minutes, 10)


func test_bad_values_are_ignored_or_clamped() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("options", "stadium_choice", 99)
	cfg.set_value("options", "match_minutes", 42)
	cfg.set_value("options", "difficulty", "difícil")
	cfg.save(PATH)
	var diff := GameSettings.difficulty
	GameSettings.load_settings(PATH)
	assert_eq(GameSettings.stadium_choice, StadiumStyles.STYLES.size() - 1)
	assert_true(GameSettings.match_minutes in GameSettings.DURATION_OPTIONS)
	assert_eq(GameSettings.difficulty, diff, "un tipo equivocado no se carga")


func test_tests_do_not_touch_the_player_settings() -> void:
	assert_false(GameSettings.persist)


func test_every_stadium_has_a_thumbnail() -> void:
	for i in StadiumStyles.STYLES.size():
		assert_true(ResourceLoader.exists("res://assets/ui/stadiums/%d.png" % i), "miniatura %d" % i)
	assert_not_null(load("res://scripts/ui/main_menu.gd").stadium_thumbnail(-1), "aleatorio")
