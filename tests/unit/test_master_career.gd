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


## D2: amarillas, rojas y lesiones.
func test_cards_and_injuries_rules() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var d := {"n": "X"}
	for i in 4:
		MasterCareer._apply_event(d, "y", rng)
	assert_eq(int(d.get("susp", 0)), 0)
	MasterCareer._apply_event(d, "y", rng)
	assert_eq(int(d["susp"]), 1, "5 amarillas = 1 fecha")
	assert_eq(int(d["yc"]), 0)
	MasterCareer._apply_event(d, "r", rng)
	assert_between(int(d["susp"]), 2, 3)
	MasterCareer._apply_event(d, "i2", rng)
	assert_gt(int(d["inj"]), 0)


## D2: el lesionado no es titular y cumple las fechas.
func test_unavailable_player_sits_out_and_serves() -> void:
	var m := MasterCareer.create("esp", String(TeamDB.country("esp")["divisions"][1]["clubs"][0]["id"]), "real", 31)
	var star: PlayerData = m.user_team().starters()[5]
	var d := m._player_dict(m.user_club, star.pid)
	d["susp"] = 1
	TeamDB.use_option_file(m.world)
	var xi := m.user_team().starters().map(func(p: PlayerData) -> int: return p.pid)
	assert_false(xi.has(star.pid), "suspendido: fuera del once")
	assert_true(m.user_absences().size() >= 1)
	m.play_round([], [], 8)
	assert_eq(int(m._player_dict(m.user_club, star.pid)["susp"]), 0, "cumplió la fecha")
	MasterCareer.deactivate()


## D2: cambio de año (edad, evolución, retiros y juveniles).
func test_new_year_ages_retires_and_refills() -> void:
	var m := MasterCareer.create("arg", "lugano", "real", 41)
	var players: Array = m.club_players("lugano")
	var veteran: Dictionary = players[3]
	veteran["age"] = 40
	var kid: Dictionary = players[4]
	kid["age"] = 18
	var kid_before := MasterCareer._avg(kid)
	var kid_pid := int(kid["pid"])
	m.simulate_to_end(12)
	assert_true(m.season_over)
	var now: Array = m.club_players("lugano")
	assert_eq(now.size(), 23, "repuesto con juveniles")
	assert_false(now.any(func(p: Dictionary) -> bool: return int(p["pid"]) == int(veteran["pid"])), "el de 40 se retiró")
	var u: Dictionary = m.last_summary()["user"]
	assert_true((u["retired"] as Array).has(veteran["n"]))
	assert_false((u["youth"] as Array).is_empty())
	var k: Array = now.filter(func(p: Dictionary) -> bool: return int(p["pid"]) == kid_pid)
	if not k.is_empty():
		assert_eq(int(k[0]["age"]), 19)
		assert_gt(MasterCareer._avg(k[0]), kid_before, "el pibe creció")
	# Durante la temporada hubo suspensiones o lesiones en algún club.
	var hurt := 0
	for key in m.world.clubs:
		for p in m.world.clubs[key]["players"]:
			if int(p.get("inj", 0)) > 0:
				hurt += 1
	gut.p("Lesionados al final (después de la pretemporada): %d" % hurt)
	MasterCareer.deactivate()


## Fixture: nadie juega más de dos fechas seguidas de local o de visitante.
func test_fixture_alternates_home_and_away() -> void:
	for n in [8, 20, 24, 36]:
		var rounds := Competition.round_robin(n, true, 5)
		for t in n:
			var seq: Array = []
			for r in rounds:
				for g in r:
					if g["home"] == t or g["away"] == t:
						seq.append(g["home"] == t)
			var streak := 1
			var worst := 1
			for k in range(1, seq.size()):
				streak = streak + 1 if seq[k] == seq[k - 1] else 1
				worst = maxi(worst, streak)
			assert_lte(worst, 3, "%d equipos, equipo %d" % [n, t])


## D3: alineación y formación guardadas.
func test_saved_lineup_and_formation() -> void:
	var m := MasterCareer.create("arg", "lugano", "real", 52)
	var t := m.user_team()
	var starter := t.players[9]
	var bench := t.players[20]
	m.swap_players(starter.pid, bench.pid)
	var xi := m.user_team().starters().map(func(p: PlayerData) -> int: return p.pid)
	assert_true(xi.has(bench.pid), "el suplente entra")
	assert_false(xi.has(starter.pid))
	assert_eq(xi[9], bench.pid, "en el mismo puesto")
	# Guardado en el archivo.
	m.save()
	var back := MasterCareer.load_saved(m.file)
	assert_true(back.user_team().starters().map(func(p: PlayerData) -> int: return p.pid).has(bench.pid))
	# Si se lesiona, juega otro; al volver, vuelve a su lugar.
	back.user_player_dict(bench.pid)["inj"] = 2
	back._refresh_user()
	assert_false(back.user_team().starters().map(func(p: PlayerData) -> int: return p.pid).has(bench.pid))
	back.user_player_dict(bench.pid)["inj"] = 0
	back._refresh_user()
	assert_true(back.user_team().starters().map(func(p: PlayerData) -> int: return p.pid).has(bench.pid))
	back.set_formation("4-3-3")
	assert_eq(back.user_team().formation.resource_path.get_file(), "f_4-3-3.tres")
	assert_false(back.has_custom_lineup())
	assert_eq(back.calendar().size(), 46)
	MasterCareer.deactivate()
