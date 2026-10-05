extends GutTest
## Paso C: base de datos real (selecciones y clubes en data/db).


func test_nations_build_with_flag_and_23_players() -> void:
	var ns := TeamDB.nations()
	assert_eq(ns.size(), 59)
	var wc := ns.filter(func(n: Dictionary) -> bool: return n["wc"] == "q")
	assert_eq(wc.size(), 42, "clasificados seguros al Mundial 2026")
	for n in ns:
		var t := TeamDB.load_team(TeamDB.nation_path(n["id"]))
		assert_not_null(t, n["id"])
		assert_eq(t.players.size(), 23, n["id"])
		assert_not_null(t.flag, n["id"])
		assert_eq(t.short_name.length(), 3, n["id"])
		assert_eq(t.players[0].position, PlayerData.Position.GK, n["id"] + ": arquero titular")


func test_all_clubs_load_and_divisions_are_complete() -> void:
	var expected := {"eng": [20, 24, 24, 24], "esp": [20, 22], "ita": [20, 20], "ger": [18, 18], "por": [18],
		"ned": [18], "mex": [18], "bra": [20], "arg": [30, 36, 20, 20, 12]}
	assert_eq(TeamDB.countries().size(), expected.size())
	var total := 0
	for c in TeamDB.countries():
		var sizes := []
		for d in c["divisions"]:
			sizes.append(d["clubs"].size())
			for cl in d["clubs"]:
				assert_true(TeamDB.exists(TeamDB.club_path(c["id"], cl["id"])))
				total += 1
		assert_eq(sizes, expected[c["id"]], c["id"])
	assert_gt(total, 400)
	var boca := TeamDB.load_team(TeamDB.club_path("arg", "boca"))
	assert_eq(boca.team_name, "Boca Juniors")
	assert_eq(boca.pattern, 6, "franja en el pecho")
	assert_eq(boca.stadium, "La Bombonera")
	assert_eq(boca.players.size(), 23)


func test_generated_rosters_are_stable_and_follow_level() -> void:
	var path := TeamDB.club_path("eng", "liverpool")
	var a := TeamDB.load_team(path)
	var first := a.players[5].player_name
	TeamDB.reload()
	var b := TeamDB.load_team(path)
	assert_eq(b.players[5].player_name, first, "mismo plantel cada vez")
	var top := 0.0
	for p in b.starters():
		top += TeamDB.overall(p)
	var low := 0.0
	for p in TeamDB.load_team(TeamDB.club_path("eng", "barrow")).starters():
		low += TeamDB.overall(p)
	assert_gt(top, low + 50.0, "la Premier juega mejor que la League Two")


func test_kit_parsing() -> void:
	var k := TeamDB.parse_kit("0a2a6e/0a2a6e/0a2a6e|band|f5c400")
	assert_eq(k["pattern"], 6)
	assert_eq(k["pattern_color"], Color.html("f5c400"))
	var plain := TeamDB.parse_kit("ffffff/101820")
	assert_eq(plain["socks"], Color.WHITE)
	assert_eq(plain["pattern"], 0)


func test_imported_players_fill_the_formation() -> void:
	var e := {"name": "Prueba", "short": "PRU", "home": "ffffff/ffffff/ffffff", "away": "101820/101820/101820",
		"formation": "4-4-2", "players": [
			{"n": "Delantero Uno", "pos": "CF", "ft": "L", "h": 185, "a": {"shooting": 90}},
			{"n": "Arquero Uno", "pos": "GK", "h": 192},
			{"n": "Central Uno", "pos": "CB"}]}
	var t := TeamDB.build_club(e, "arg", {"id": "arg1", "level": 1})
	assert_eq(t.players[0].player_name, "Arquero Uno", "el arquero primero")
	assert_eq(t.players[0].height, 192)
	var cf: PlayerData = t.players.filter(func(p: PlayerData) -> bool: return p.player_name == "Delantero Uno")[0]
	assert_eq(cf.shooting, 90)
	assert_eq(cf.foot, PlayerData.Foot.LEFT)


func test_match_starts_with_database_teams() -> void:
	var saved := [GameSettings.home_team_path, GameSettings.away_team_path]
	GameSettings.home_team_path = TeamDB.nation_path("arg")
	GameSettings.away_team_path = TeamDB.club_path("bra", "flamengo")
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	assert_eq(m.teams[0].team_name, "Argentina")
	assert_eq(m.teams[1].team_name, "Flamengo")
	assert_eq(m.teams[0].players.size(), 11)
	GameSettings.home_team_path = saved[0]
	GameSettings.away_team_path = saved[1]
