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


## La elección de equipos se recorre por grupos: selecciones, cada división
## y los Equipos WE.
func test_team_select_groups() -> void:
	var ts := TeamSelect.new()
	add_child_autofree(ts)
	assert_eq(ts.groups[0]["kind"], "nations")
	assert_eq(ts.groups[-1]["kind"], "we")
	assert_eq(ts.groups.size(), 1 + 19 + 1, "selecciones + 19 divisiones + WE")
	var saved := [GameSettings.home_team_path, GameSettings.away_team_path]
	GameSettings.home_team_path = TeamDB.club_path("arg", "river")
	GameSettings.away_team_path = TeamDB.nation_path("bra")
	ts.open()
	GameSettings.home_team_path = saved[0]
	GameSettings.away_team_path = saved[1]
	assert_eq(ts.groups[ts.group]["division"], "arg1", "abre en el grupo del local")
	ts.show_group(0)
	assert_eq(ts.paths.size(), 59)
	assert_not_null(ts.teams[0].flag)
	ts._on_pick(3)
	assert_eq(ts.side, 1)
	watch_signals(ts)
	ts.show_group(ts.group + 1)
	ts._on_pick(0)
	assert_signal_emitted(ts, "chosen")


func test_competition_uses_the_real_division() -> void:
	var menu: Script = load("res://scripts/ui/main_menu.gd")
	var mine := TeamDB.club_path("eng", "wrexham")
	var div := TeamDB.division_paths("eng", "eng2")
	var league: Array[String] = menu.competition_paths(Competition.Kind.LEAGUE, mine, div)
	assert_eq(league.size(), 24, "toda la Championship")
	var cup: Array[String] = menu.competition_paths(Competition.Kind.CUP, mine, div)
	assert_eq(cup.size(), 8)
	assert_true(cup.has(mine))
	var nat := TeamDB.nation_path("arg")
	var nl: Array[String] = menu.competition_paths(Competition.Kind.LEAGUE, nat, TeamDB.nation_paths())
	assert_eq(nl.size(), 8, "con selecciones, 8")


func test_real_stadium_by_capacity() -> void:
	var boca := TeamDB.load_team(TeamDB.club_path("arg", "boca"))
	var st := StadiumStyles.for_team(boca, -1)
	assert_eq(st["name"], "La Bombonera")
	var mad := StadiumStyles.for_team(TeamDB.load_team(TeamDB.club_path("esp", "realmadrid")), -1)
	assert_true(mad.get("oval", false), "los gigantes: cuenco de cuatro bandejas")
	assert_eq(StadiumStyles.for_team(boca, 0)["name"], StadiumStyles.STYLES[0]["name"], "el elegido en el menú manda")
	assert_eq(StadiumStyles.STYLES[2]["name"], "Gran Coliseo del Plata", "no se pisa el original")


## Mundial 2026: 48 selecciones (42 + 6 del repechaje), 12 grupos de 4,
## 3 fechas, 16avos con 32 y un campeón.
func test_world_cup_2026() -> void:
	var menu: Script = load("res://scripts/ui/main_menu.gd")
	var paths: Array[String] = menu.world_cup_paths(["ita", "pol", "kos", "den", "jam", "sur"])
	assert_eq(paths.size(), 48)
	assert_true(paths.has(TeamDB.nation_path("jam")))
	assert_false(paths.has(TeamDB.nation_path("irq")))
	assert_false(paths.has(TeamDB.nation_path("chn")), "no clasificada")
	var bad: Array[String] = menu.world_cup_paths(["ita"])
	assert_eq(bad.size(), 48, "si no son 6, las 6 de más nivel")
	var me := paths.find(TeamDB.nation_path("arg"))
	var c := Competition.create_world_cup(paths, me, 77, [TeamDB.nation_path("usa")])
	assert_eq(c.groups.size(), 12)
	for g in c.groups:
		assert_eq((g as Array).size(), 4)
	assert_true((c.groups[0] as Array).has(paths.find(TeamDB.nation_path("usa"))), "el anfitrión encabeza el grupo A")
	assert_eq(c.rounds.size(), 3)
	assert_eq((c.rounds[0] as Array).size(), 24)
	assert_eq(c.round_name(), "Fase de grupos · fecha 1 de 3")
	for i in 3:
		c.complete_round([], 100 + i)
	assert_eq(c.rounds.size(), 4)
	assert_eq((c.rounds[3] as Array).size(), 16)
	assert_eq(c.round_name(), "16avos de final")
	var teams_in := {}
	for g in c.rounds[3]:
		teams_in[g["home"]] = true
		teams_in[g["away"]] = true
	assert_eq(teams_in.size(), 32, "32 distintos")
	for i in 10:
		if c.finished():
			break
		c.complete_round([], 200 + i)
	assert_true(c.finished())
	assert_ne(c.champion, -1)
	assert_eq(c.round_name(c.rounds.size() - 1), "Final")
	var saved := Competition.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(saved.groups.size(), 12)
	assert_eq(saved.champion, c.champion)
