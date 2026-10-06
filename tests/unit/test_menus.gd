extends GutTest
## Menús estilo WE: principal, elección de equipos, configuración del
## partido, uniformes y datos de los equipos.

var _saved := {}


func before_each() -> void:
	for k in ["home_team_path", "away_team_path", "home_kit", "away_kit", "time_choice", "match_minutes"]:
		_saved[k] = GameSettings.get(k)


func after_each() -> void:
	for k in _saved:
		GameSettings.set(k, _saved[k])


func test_there_are_eight_fictional_teams_with_two_kits() -> void:
	var paths := GameSettings.team_paths()
	assert_eq(paths.size(), 8)
	for p in paths:
		var t := load(p) as TeamData
		assert_eq(t.players.size(), 23, t.team_name)
		assert_ne(t.kit(0)[0], t.kit(1)[0], "dos camisetas distintas: " + t.team_name)
		for r in t.ratings():
			assert_between(r, 0.0, 1.0)


func test_main_menu_pages_and_back() -> void:
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	# Al abrir el juego, primero el título (Press START).
	if menu.call("_current") == "title":
		menu.call("leave_title")
	assert_eq(menu.call("_current"), "home")
	menu.call("show_page", "modes")
	assert_eq(menu.call("_current"), "modes")
	menu.call("show_page", "options")
	menu.call("go_back")
	assert_eq(menu.call("_current"), "modes")
	menu.call("go_back")
	assert_eq(menu.call("_current"), "home")


func test_team_select_picks_home_then_away() -> void:
	var ts := TeamSelect.new()
	add_child_autofree(ts)
	ts.open()
	watch_signals(ts)
	ts._on_pick(2)
	assert_eq(ts.side, 1, "después del local, el visitante")
	ts._on_pick(5)
	assert_signal_emitted_with_parameters(ts, "chosen", [ts.paths[2], ts.paths[5]])


func test_match_setup_rows_change_settings() -> void:
	var ms := MatchSetup.new()
	add_child_autofree(ms)
	ms.open()
	GameSettings.time_choice = -1
	ms._cycle(1, "time_choice", MatchConditions.TIME_NAMES.size())
	assert_eq(GameSettings.time_choice, 0)
	ms._cycle(-1, "time_choice", MatchConditions.TIME_NAMES.size())
	ms._cycle(-1, "time_choice", MatchConditions.TIME_NAMES.size())
	assert_eq(GameSettings.time_choice, MatchConditions.TIME_NAMES.size() - 1, "da la vuelta")
	var before := GameSettings.match_minutes
	ms._step_duration(1)
	assert_ne(GameSettings.match_minutes, before)


func test_chosen_kits_are_used_and_clashes_avoided() -> void:
	GameSettings.home_team_path = "res://data/teams/aurora.tres"
	GameSettings.away_team_path = "res://data/teams/halcones.tres"
	GameSettings.home_kit = 1
	GameSettings.away_kit = 0
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	var aurora := load(GameSettings.home_team_path) as TeamData
	assert_eq(m.teams[0].color, aurora.kit(1)[0], "el local con el alternativo")
	# Mismo equipo de los dos lados: el visitante no puede usar la misma camiseta.
	assert_true(GameSettings.kits_clash(Color.RED, Color(0.95, 0.05, 0.05)))
	assert_false(GameSettings.kits_clash(Color.RED, Color.WHITE))


func test_mirror_match_uses_the_other_kit() -> void:
	GameSettings.home_team_path = "res://data/teams/pampa.tres"
	GameSettings.away_team_path = "res://data/teams/pampa.tres"
	GameSettings.home_kit = 0
	GameSettings.away_kit = 0
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	assert_false(GameSettings.kits_clash(m.teams[0].color, m.teams[1].color))


## Un valor largo no pisa el nombre de la opción: se recorta y corre.
func test_option_row_long_value_scrolls_inside_its_space() -> void:
	var row := WEStyle.OptionRow.new("Sobre los jugadores", func() -> String: return "nombre del controlado y algo más largo",
		func(_d: int) -> void: pass, "", 480.0)
	add_child_autofree(row)
	await get_tree().process_frame
	var font := row.get_theme_default_font()
	var cap_end := font.get_string_size("Sobre los jugadores", HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 18.0
	var clip: Control = row.get("_clip")
	assert_gt(clip.position.x, cap_end, "el valor empieza después del nombre")
	assert_true(clip.clip_contents)
	assert_gt(float(row.get("_overflow")), 0.0, "no entra: corre")
	row.set("_t", 3.0)
	row._process(0.0)
	assert_lt((row.get("_val") as Label).position.x, 0.0, "se movió")
