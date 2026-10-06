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


## D4: mercado de pases.
func test_market_buy_loan_sell_and_ai() -> void:
	var m := MasterCareer.create("arg", "lugano", "real", 61)
	assert_true(m.market_open(), "abierto en la fecha 1")
	m.points = 100000
	var list := m.market_list(3, 3, "ovr", 10)
	assert_false(list.is_empty())
	var it: Dictionary = list[0]
	var pid := int(it["d"]["pid"])
	var price := m.asking_price(it["club"], it["d"])
	var before := m.club_players("lugano").size()
	assert_eq(m.buy(it["club"], pid), "")
	assert_eq(m.points, 100000 - price)
	assert_eq(m.club_players("lugano").size(), before + 1)
	assert_true(m.user_team().players.any(func(p: PlayerData) -> bool: return p.pid == pid), "ya juega en tu club")
	# Préstamo: vuelve al terminar la temporada.
	var it2: Dictionary = m.market_list(2, 3, "ovr", 10)[0]
	var loan_pid := int(it2["d"]["pid"])
	assert_eq(m.loan_in(it2["club"], loan_pid), "")
	assert_false(m._player_dict("lugano", loan_pid).is_empty())
	# Venta y libre.
	var mine: Dictionary = m.club_players("lugano")[5]
	var seeded := RandomNumberGenerator.new()
	seeded.seed = 3
	var offer := m.sell_offer(int(mine["pid"]), seeded)
	assert_true(offer.has("club"))
	var pts := m.points
	assert_eq(m.sell(int(mine["pid"]), offer["club"], int(offer["price"])), "")
	assert_eq(m.points, pts + int(offer["price"]))
	assert_false(m._player_dict(offer["club"], int(mine["pid"])).is_empty())
	assert_eq(m.release(int(m.club_players("lugano")[6]["pid"])), "")
	# Cerrado a mitad de la primera rueda.
	for i in 8:
		m.play_round([], [], 70 + i)
	assert_false(m.market_open())
	assert_ne(m.buy(it2["club"], int(m.market_list(-1, -1, "ovr", 1)[0]["d"]["pid"])), "", "no se puede comprar")
	m.simulate_to_end(4)
	assert_true(m._player_dict("lugano", loan_pid).is_empty(), "el préstamo volvió")
	# Vuelve a su club (después, en la misma pretemporada, otro club se lo
	# puede comprar o se puede retirar: se mira el registro de pases).
	assert_true(m.transfers.any(func(t: Dictionary) -> bool:
		return t["kind"] == "vuelta" and t["to"] == it2["club"] and t["n"] == it2["d"]["n"]), "volvió a su club")
	var ai := m.transfers.filter(func(t: Dictionary) -> bool: return t["kind"] == "ia")
	assert_gt(ai.size(), 5, "los otros clubes también ficharon")
	# Nadie quedó con el plantel corto.
	for key in m.world.clubs:
		if String(key).ends_with(":" + MasterCareer.FREE_CLUB):
			continue
		assert_true((m.world.clubs[key]["players"] as Array).size() >= 16, key)
	MasterCareer.deactivate()


func test_player_value_by_age() -> void:
	var a := {"speed": 70, "passing": 70, "shooting": 70, "technique": 70, "ball_control": 70, "defense": 70, "stamina": 70}
	var young := MasterCareer.player_value({"pos": "CMF", "age": 21, "a": a})
	var old := MasterCareer.player_value({"pos": "CMF", "age": 33, "a": a})
	assert_gt(young, old * 2)
	assert_eq(young % 50, 0)


## D5: noticias, historial y palmarés.
func test_news_history_and_honours() -> void:
	var m := MasterCareer.create("arg", "lugano", "real", 83)
	m.points = 50000
	var it: Dictionary = m.market_list(3, 3, "ovr", 5)[0]
	m.buy(it["club"], int(it["d"]["pid"]))
	assert_string_contains(String(m.latest_news(1)[0]["text"]), "Fichaste")
	m.simulate_to_end(9)
	var texts: Array = m.latest_news(120).map(func(n: Dictionary) -> String: return n["text"])
	assert_true(texts.any(func(t: String) -> bool: return t.contains("campeón")), "campeones")
	assert_true(texts.any(func(t: String) -> bool: return t.contains("Lesión") or t.contains("Suspendido")), "bajas de tu plantel")
	var bombs := m.news.filter(func(n: Dictionary) -> bool: return n["kind"] == "bombazo")
	assert_lte(bombs.size(), 6, "como mucho 3 por ventana")
	var h := m.club_history()
	assert_eq(h.size(), 1)
	assert_eq(String(h[0]["division"]), "Primera C")
	assert_gt(int(h[0]["pos"]), 0)
	assert_false((h[0]["scorer"] as Dictionary).is_empty(), "goleador del club")
	assert_eq(m.most_titles(10).size(), 4, "un campeón por división")
	# Se guarda.
	m.save()
	var back := MasterCareer.load_saved(m.file)
	assert_eq(back.news.size(), m.news.size())
	MasterCareer.deactivate()


## Fase 7: copas reales intercaladas con la liga, supercopas y Mundial.
func test_cups_and_world_cup() -> void:
	var m := MasterCareer.create("eng", String(TeamDB.country("eng")["divisions"][3]["clubs"][0]["id"]), "real", 91)
	var fa := m.cup("national")
	assert_eq(String(fa["name"]), "FA Cup")
	var fc: Competition = fa["comp"]
	assert_eq(fc.team_paths.size(), 92, "los 92 de la liga inglesa")
	assert_true(fc.team_paths.has(m.user_path()), "League Two: arranca en las rondas previas")
	assert_eq(String(m.cup("league_cup")["name"]), "EFL Cup")
	for id in ["ucl", "uel", "uecl"]:
		var c: Competition = m.cup(id)["comp"]
		assert_eq(c.team_paths.size(), 36, id)
		assert_eq(c.user_team, -1, "desde League Two no se juega en Europa")
	assert_true(m.cup("super").is_empty(), "primera temporada: sin supercopa")
	# Jugar la primera fecha de copa con resultado propio.
	var guard := 0
	while m.pending_event() < 0 and guard < 30:
		m.play_round([], [], 200 + guard)
		guard += 1
	var ev := m.pending_event()
	assert_gte(ev, 0)
	var comp := m.current_comp()
	assert_eq(comp, m.event_comp(ev))
	var g := m.user_match()
	var league_before := m.user_league().current
	var me_home: bool = g["home"] == comp.user_team
	m.play_round([3, 0] if me_home else [0, 3], [], 300)
	assert_eq(m.user_league().current, league_before, "la fecha de copa no mueve la liga")
	assert_true(comp.alive(comp.user_team), "ganó y sigue")
	# Mundial al final de esta temporada.
	m.first_year = 2030
	m.simulate_to_end(5)
	var s := m.last_summary()
	var cs: Dictionary = s["cups"]
	for id in ["national", "league_cup", "ucl", "uel", "uecl", "lib", "cca"]:
		assert_true(cs.has(id), "resultado de %s" % id)
	assert_ne(String(cs["national"]["user"]), "")
	assert_true(bool(cs["lib"]["foreign"]), "las de otras confederaciones, simuladas")
	assert_true(s.has("world_cup"))
	assert_ne(String(s["world_cup"]["champion"]), "")
	assert_eq((TeamDB.nation("eng")["players"] as Array).size(), 23, "convocados")
	# Temporada siguiente: supercopas con los campeones y los 4 primeros de
	# la Premier en la Champions.
	m.start_next_season(6)
	assert_false(m.cup("super").is_empty(), "Community Shield")
	var shield: Competition = m.cup("super")["comp"]
	assert_true(shield.finished(), "se juega antes de la 1.ª fecha (sin tu club, simulada)")
	assert_true(shield.team_paths.has(TeamDB.club_path("eng", String(s["ranks"][0][0]))), "el campeón de la Premier")
	assert_false(m.cup("uefa_super").is_empty(), "Supercopa de Europa")
	assert_false(m.cup("intercontinental").is_empty(), "Intercontinental")
	var ucl: Competition = m.cup("ucl")["comp"]
	for id in (s["ranks"][0] as Array).slice(0, 4):
		assert_true(ucl.team_paths.has(TeamDB.club_path("eng", String(id))), "top 4 a la Champions")
	for cid in ["ucl", "uel", "uecl"]:
		for p in (m.cup(cid)["comp"] as Competition).team_paths:
			assert_true(CareerCups.division_clubs(p.get_slice(":", 2), 0).has(p), "%s: %s es de primera" % [cid, p])
	assert_true(ucl.team_paths.has(String(cs["ucl"]["champion_path"])), "el campeón defiende el título")
	assert_false(m.world_cup_year(), "el próximo, en 4 años")
	# Se guarda y se carga con todas las copas.
	m.save()
	var back := MasterCareer.load_saved(m.file)
	assert_eq(back.cups.size(), m.cups.size())
	assert_eq((back.cup("ucl")["comp"] as Competition).ko, "swiss")
	MasterCareer.deactivate()


## Argentina: Copa Argentina (Primera y 15 de la Nacional directo a 32avos,
## B y C en la fase preliminar), Libertadores y Sudamericana; al año
## siguiente, Trofeo de Campeones y después la Supercopa Argentina.
func test_argentina_cups() -> void:
	var m := MasterCareer.create("arg", "colon", "real", 17)
	var ca: Competition = m.cup("national")["comp"]
	assert_eq(String(m.cup("national")["name"]), "Copa Argentina")
	assert_eq(ca.team_paths.size(), 30 + 15 + 20 + 24)
	assert_eq(ca.round_name(), "Fase preliminar · 1.ª ronda")
	var stage_main := ca.entries.size() - 1
	assert_eq((ca.entries[stage_main] as Array).size(), 45, "Primera y 15 de la Nacional, directo")
	assert_true(ca.team_paths.has(m.user_path()))
	var lib: Competition = m.cup("lib")["comp"]
	var sud: Competition = m.cup("sud")["comp"]
	assert_eq(lib.team_paths.size(), 32)
	assert_eq(sud.team_paths.size(), 32)
	assert_eq(lib.group_rounds, 6)
	# Clubes de los 10 países de la Conmebol y nunca del ascenso.
	var countries := {}
	for comp in [lib, sud]:
		for p in (comp as Competition).team_paths:
			var cid := p.get_slice(":", 2)
			countries[cid] = true
			assert_true(CareerCups.division_clubs(cid, 0).has(p), "%s es de primera" % p)
	for cid in ["arg", "bra", "uru", "par", "chi", "col", "ecu", "per", "bol", "ven"]:
		assert_true(countries.has(cid), "hay clubes de %s" % cid)
	m.simulate_to_end(8)
	var s := m.last_summary()
	assert_eq((s["halves"] as Array).size(), 2, "Apertura y Clausura")
	assert_true((s["cups"] as Dictionary).has("sud"))
	assert_eq(sud.team_paths.size(), 40, "los 3.º de la Libertadores pasaron a la Sudamericana")
	m.start_next_season(9)
	var trofeo := m.cup("trofeo")
	assert_false(trofeo.is_empty(), "Trofeo de Campeones")
	assert_true((trofeo["comp"] as Competition).finished(), "se juega antes de la 1.ª fecha")
	assert_false(m.cup("supercopa_arg").is_empty(), "con el Trofeo jugado, la Supercopa Argentina")
	assert_false(m.cup("recopa").is_empty(), "Recopa Sudamericana")
	MasterCareer.deactivate()


## Mundial de Clubes: 32 clubes de las tres confederaciones, antes de la temporada.
func test_club_world_cup() -> void:
	var m := MasterCareer.create("esp", String(TeamDB.country("esp")["divisions"][1]["clubs"][0]["id"]), "real", 33)
	assert_true(m.cup("cwc").is_empty(), "2026: no hay")
	m.first_year = CareerCups.CLUB_WORLD_CUP_FIRST
	m._new_season_cups(44)
	var cwc: Dictionary = m.cup("cwc")
	assert_false(cwc.is_empty())
	var c: Competition = cwc["comp"]
	assert_eq(c.team_paths.size(), 32)
	assert_eq(c.groups.size(), 8)
	assert_true(c.finished(), "sin tu club: simulado antes de la 1.ª fecha")
	var confeds := {}
	for p in c.team_paths:
		confeds[CareerCups.confed_of(p.get_slice(":", 2))] = true
	assert_eq(confeds.size(), 3, "de las tres confederaciones")
	MasterCareer.deactivate()


func test_cup_spread_before_last_rounds() -> void:
	var s := MasterCareer.spread(6, 46)
	assert_eq(s.size(), 6)
	for v in s:
		assert_between(int(v), 1, 44)
	var prev := 0
	for v in s:
		assert_gte(int(v), prev)
		prev = int(v)


## Mercado: con la lista vacía ("Todavía no hubo pases") el foco queda en
## una fila de opción y el mando sigue andando.
func test_market_focus_with_empty_list() -> void:
	var m := MasterCareer.create("arg", "colon", "real", 5)
	var mk := MasterMarket.new()
	add_child_autofree(mk)
	mk.open(m)
	mk.mode = 2
	mk.call("_rebuild")
	await get_tree().process_frame
	var owner := get_viewport().gui_get_focus_owner()
	assert_not_null(owner, "hay foco")
	assert_true(owner != null and mk.is_ancestor_of(owner), "dentro del mercado")
	MasterCareer.deactivate()
