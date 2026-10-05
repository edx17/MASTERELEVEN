extends GutTest
## Liga Master (D1): carrera, temporada, goleadores, ascensos y descensos.

var _root := ""


func before_each() -> void:
	_root = ProjectSettings.globalize_path("user://test_master_%d" % randi())
	UserData.root_override = _root
	UserData.ensure_dirs()
	TeamDB.use_option_file(null)


func after_each() -> void:
	TeamDB.use_option_file(null)
	UserData.root_override = ""


func test_start_division_rules() -> void:
	assert_eq(MasterCareer.start_division("arg"), 3, "Argentina: Primera C")
	assert_eq(MasterCareer.start_division("eng"), 3, "Inglaterra: League Two")
	assert_eq(MasterCareer.start_division("esp"), 1, "España: LaLiga 2")
	var ids := MasterCareer.eligible_countries().map(func(c: Dictionary) -> String: return c["id"])
	assert_false(ids.has("bra"), "una sola división")
	assert_true(MasterCareer.we_forced("arg", "boca"))
	assert_false(MasterCareer.we_forced("arg", "colon"))


func test_create_with_big_club_moves_it_down_with_we_squad() -> void:
	var real_boca := TeamDB.load_team(TeamDB.club_path("arg", "boca"))
	var m := MasterCareer.create("arg", "boca", "real", 1234)
	assert_eq(m.squad_mode, "we", "club de primera: Equipo WE obligatorio")
	assert_eq(m.user_league_index(), 3, "arranca en Primera C")
	var sizes := []
	for l in m.leagues:
		sizes.append((l["comp"] as Competition).team_paths.size())
	assert_eq(sizes, [30, 36, 20, 24], "los tamaños no cambian")
	var t := m.user_team()
	assert_eq(t.team_name, "Boca Juniors")
	assert_eq(t.players.size(), 23)
	assert_ne(t.players[0].player_name, real_boca.players[0].player_name, "plantel genérico")
	assert_gt(t.players[0].pid, 0)
	# Fechas reales: 24 equipos, ida y vuelta.
	assert_eq(m.user_league().rounds.size(), 46)
	MasterCareer.deactivate()


func test_real_squad_keeps_players() -> void:
	var real := TeamDB.load_team(TeamDB.club_path("arg", "lugano"))
	var m := MasterCareer.create("arg", "lugano", "real", 77)
	var names := func(t: TeamData) -> Array:
		var out := t.players.map(func(p: PlayerData) -> String: return p.player_name)
		out.sort()
		return out
	assert_eq(names.call(m.user_team()), names.call(real), "mismo plantel")
	MasterCareer.deactivate()


func test_season_scorers_points_promotion_and_save() -> void:
	var m := MasterCareer.create("esp", "zaragoza" if MasterCareer.division_of("esp", "zaragoza") >= 0 else "", "real", 99)
	if m.user_club == "":
		m = MasterCareer.create("esp", String(TeamDB.country("esp")["divisions"][1]["clubs"][0]["id"]), "real", 99)
	var start_points := m.points
	# Partido jugado con autores reales.
	var g := m.user_match()
	assert_false(g.is_empty())
	var comp := m.user_league()
	var me_home: bool = g["home"] == comp.user_team
	var my_t := m.user_team()
	var striker: PlayerData = my_t.players[10]
	m.play_round([2, 0] if me_home else [0, 2], [[0 if me_home else 1, striker.pid], [0 if me_home else 1, striker.pid]], 5)
	assert_eq(int(m.scorers[str(striker.pid)]["goals"]), 2)
	assert_eq(m.points, start_points + 400 + 2 * 50)
	# Guardar y cargar a mitad de temporada.
	m.save()
	var back := MasterCareer.load_saved(m.file)
	assert_eq(back.user_league().current, 1)
	assert_eq(back.points, m.points)
	assert_eq(back.user_team().team_name, m.user_team().team_name)
	# El resto de la temporada simulada.
	back.simulate_to_end(7)
	assert_true(back.season_over)
	var s := back.last_summary()
	var esp1: Dictionary = s["divisions"][0]
	var esp2: Dictionary = s["divisions"][1]
	assert_eq((esp1["down"] as Array).size(), 2)
	assert_eq((esp2["up"] as Array).size(), 2)
	assert_false((esp1["top_scorer"] as Dictionary).is_empty(), "hay goleador")
	var total := 0
	for k in back.scorers:
		total += int(back.scorers[k]["goals"])
	assert_gt(total, 300, "goles de toda la temporada")
	# Temporada siguiente: los que subieron juegan en primera.
	back.start_next_season(3)
	assert_eq(back.season, 2)
	var first: Array = (back.leagues[0]["comp"] as Competition).team_paths
	for id in esp2["up"]:
		assert_true(first.has(TeamDB.club_path("esp", id)), "ascendió %s" % id)
	assert_eq(first.size(), 20)
	MasterCareer.deactivate()


func test_relegation_count_editable() -> void:
	assert_eq(TeamDB.relegation_count("eng", 0), 3)
	assert_eq(TeamDB.relegation_count("arg", 0), 2)
	assert_eq(TeamDB.relegation_count("arg", 3), 0, "la última no desciende")
	var of := OptionFile.new()
	of.set_relegation("arg", "arg1", 4)
	TeamDB.use_option_file(of)
	assert_eq(TeamDB.relegation_count("arg", 0), 4)


func test_list_saves() -> void:
	var m := MasterCareer.create("eng", String(TeamDB.country("eng")["divisions"][3]["clubs"][0]["id"]), "we", 11)
	m.save()
	MasterCareer.deactivate()
	var saves := MasterCareer.list_saves()
	assert_eq(saves.size(), 1)
	assert_string_contains(String(saves[0]["progress"]), "League Two")
	assert_true(MasterCareer.is_career_file(m.file))
