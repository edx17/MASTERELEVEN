extends GutTest
## Sub-20: equipos juveniles de clubes y selecciones, y los torneos (Torneo
## de Proyección, Libertadores Sub-20, UEFA Youth League, Mundial Sub-20).


func after_each() -> void:
	TeamDB.use_option_file(null)


func _avg(t: TeamData) -> float:
	var total := 0.0
	for v in t.ratings():
		total += v
	return total


func test_generated_u20_is_young_and_weaker() -> void:
	var senior := TeamDB.load_team(TeamDB.club_path("arg", "river"))
	var u20 := TeamDB.load_team(TeamDB.u20_path(TeamDB.club_path("arg", "river")))
	assert_not_null(u20)
	assert_eq(u20.team_name, senior.team_name + " Sub-20")
	assert_true(TeamDB.exists(TeamDB.u20_path(TeamDB.club_path("arg", "river"))))
	assert_true(u20.players.all(func(p: PlayerData) -> bool: return p.age >= 17 and p.age <= 19))
	assert_lt(_avg(u20), _avg(senior), "más flojo que primera")
	assert_eq(u20.color, senior.color, "misma camiseta")
	var nat := TeamDB.load_team(TeamDB.u20_path(TeamDB.nation_path("arg")))
	assert_eq(nat.team_name, "Argentina Sub-20")


func test_imported_youth_is_used() -> void:
	var of := OptionFile.new()
	var entry: Dictionary = (TeamDB.club("arg", "river")[0] as Dictionary).duplicate(true)
	var youth: Array = []
	for i in 18:
		youth.append({"n": "Pibe %d" % i, "pos": ["GK", "CB", "CMF", "CF"][i % 4], "age": 18, "ovr": 60, "nat": "Argentina"})
	entry["youth"] = youth
	of.set_club("arg", entry)
	TeamDB.use_option_file(of)
	var u20 := TeamDB.load_team(TeamDB.u20_path(TeamDB.club_path("arg", "river")))
	assert_eq(u20.players.size(), 18)
	assert_true(u20.players.all(func(p: PlayerData) -> bool: return p.player_name.begins_with("Pibe")))
	# La Sub-20 de Argentina toma a los juveniles argentinos de los clubes.
	var nat := TeamDB.load_team(TeamDB.u20_path(TeamDB.nation_path("arg")))
	assert_true(nat.players.any(func(p: PlayerData) -> bool: return p.player_name.begins_with("Pibe")))


func test_youth_tournaments_play_to_the_end() -> void:
	var cache := {}
	var sizes := {"proyeccion": TeamDB.country("arg")["divisions"][0]["clubs"].size(), "lib_u20": 16, "uyl": 36, "wc_u20": 24}
	for id in sizes:
		var teams := CareerCups.youth_teams(id, cache)
		assert_eq(teams.size(), sizes[id], id)
		assert_true(teams.all(func(p: String) -> bool: return TeamDB.is_u20(p)), id)
		var c := CareerCups.youth_comp(id, teams, 0, 5)
		var guard := 0
		while not c.finished() and guard < 80:
			c.complete_round([], 100 + guard)
			guard += 1
		assert_true(c.finished(), id)
		if id != "proyeccion":
			assert_gt(c.champion, -1, id)


func test_world_cup_u20_round_of_16_with_best_thirds() -> void:
	var teams := CareerCups.youth_teams("wc_u20", {})
	var c := CareerCups.youth_comp("wc_u20", teams, 0, 9)
	assert_eq(c.groups.size(), 6)
	for r in 3:
		c.complete_round([], r + 1)
	assert_eq(c.round_name(), "Octavos de final")
	var seen := {}
	for g in c.rounds[3]:
		seen[g["home"]] = true
		seen[g["away"]] = true
	assert_eq(seen.size(), 16)
	for gi in 6:
		var t := c.group_table(gi)
		assert_true(seen.has(t[0]["team"]) and seen.has(t[1]["team"]), "pasan 1.º y 2.º")
		assert_false(seen.has(t[3]["team"]), "el 4.º queda afuera")


func test_liga_master_has_youth_cups() -> void:
	var m := MasterCareer.create("arg", "boca", "real", 4321)
	var ids: Array = m.cups.map(func(e: Dictionary) -> String: return e["id"])
	assert_true(ids.has("proyeccion"), str(ids))
	assert_true(ids.has("lib_u20"), str(ids))
	var proy: Dictionary = m.cups[ids.find("proyeccion")]
	assert_eq(proy["type"], "youth")
	assert_eq(int(proy["mine"]), -1, "Boca arranca en la Primera C: el Proyección es de la Liga Profesional")
	assert_eq((proy["comp"] as Competition).user_team, -1, "se simula")
	# Como si tu club estuviera en primera: las noticias siguen a tu Sub-20.
	proy["mine"] = 0
	var lib: Dictionary = m.cups[ids.find("lib_u20")]
	lib["mine"] = 0
	m.simulate_to_end(7)
	assert_true(m.news.any(func(n: Dictionary) -> bool: return String(n.get("text", "")).contains("tu Sub-20")),
		"noticias de tu Sub-20")


func test_free_agents_in_the_liga_master_market() -> void:
	var of := OptionFile.new()
	of.free_agents = [{"n": "Suelto Uno", "pos": "CF", "age": 27, "ovr": 74}, {"n": "Suelto Dos", "pos": "CB", "age": 30, "ovr": 70}]
	TeamDB.use_option_file(of)
	var m := MasterCareer.create("arg", "boca", "real", 55)
	assert_eq(m.free_agents().size(), 2)
	var list := m.market_list(-1, -1, "ovr", 100000)
	var free := list.filter(func(it: Dictionary) -> bool: return it["club"] == MasterCareer.FREE_CLUB)
	assert_eq(free.size(), 2, "los libres aparecen en el mercado")
	var d: Dictionary = free[0]["d"]
	var price := m.asking_price(MasterCareer.FREE_CLUB, d)
	assert_lt(price, m.player_value(d), "sólo la prima")
	m.points = 1000000
	if not m.market_open():
		return
	assert_eq(m.buy(MasterCareer.FREE_CLUB, int(d["pid"])), "")
	assert_eq(m.free_agents().size(), 1)
	assert_true(m.club_players(m.user_club).has(d))
	# Liberar lo devuelve a la lista de libres.
	assert_eq(m.release(int(d["pid"])), "")
	assert_eq(m.free_agents().size(), 2)
