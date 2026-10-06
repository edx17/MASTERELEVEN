extends GutTest
## Formatos de copa: entrada escalonada, llaves de ida y vuelta, grupos de
## ida y vuelta (Libertadores), playoff con los que llegan de otra copa
## (Sudamericana) y fase liga de 36 (Champions).


func _clubs(countries: Array, n: int) -> Array[String]:
	var out: Array[String] = []
	for c in countries:
		for d in TeamDB.country(String(c))["divisions"]:
			for cl in d["clubs"]:
				out.append(TeamDB.club_path(String(c), String(cl["id"])))
	return out.slice(0, n)


func _play_out(c: Competition, user_result: Array = []) -> int:
	var guard := 0
	while not c.finished() and guard < 60:
		c.complete_round(user_result, 100 + guard)
		guard += 1
	return guard


func test_staged_cup_lets_the_low_divisions_start_earlier() -> void:
	var paths := _clubs(["eng"], 40)
	# 16 entran directo a un cuadro de 32; los otros 24 juegan rondas previas.
	var stage_of := CareerCups.plan_stages(40, 16, 32)
	var c := Competition.create_staged_cup(paths, 39, stage_of, 5, 1, ["1.ª ronda", "2.ª ronda"])
	assert_eq(c.round_name(), "1.ª ronda")
	assert_true(c.alive(0), "los de arriba esperan")
	assert_true(c.user_match().has("home"), "el más débil arranca en la 1.ª ronda")
	var sizes: Array = []
	var guard := 0
	while not c.finished() and guard < 20:
		sizes.append((c.rounds[c.current] as Array).size() * 2)
		c.complete_round([], 7 + guard)
		guard += 1
	assert_gt(c.champion, -1)
	assert_true(sizes.has(32), "hay un cuadro de 32: %s" % [sizes])
	assert_eq(sizes[sizes.size() - 1], 2, "termina en la final")


func test_plan_stages_fits_the_bracket() -> void:
	for spec in [[92, 44, 64], [89, 45, 64], [92, 8, 32], [42, 4, 32], [18, 0, 16], [36, 0, 32], [2, 2, 2]]:
		var st := CareerCups.plan_stages(spec[0], spec[1], spec[2])
		assert_eq(st.size(), spec[0])
		# Simulación de la cuenta: ganadores + los que entran = par, y al
		# cuadro principal llegan exactamente `bracket`.
		var n_stages := 0
		for s in st:
			n_stages = maxi(n_stages, int(s) + 1)
		var alive := 0
		for s in n_stages:
			alive += st.count(s)
			assert_eq(alive % 2, 0, "ronda %d par (%s)" % [s, spec])
			if s < n_stages - 1:
				alive /= 2
		assert_eq(alive, spec[2], "cuadro principal (%s)" % [spec])
		assert_true(st.slice(0, spec[1]).all(func(s: int) -> bool: return s == n_stages - 1), "los directos entran al cuadro")


func test_two_legged_ties_use_the_aggregate() -> void:
	var paths := _clubs(["esp"], 4)
	var c := Competition.create_staged_cup(paths, 0, [0, 0, 0, 0], 3, 2)
	assert_true(c.round_name().ends_with("· ida"))
	c.complete_round([3, 0], 1)
	assert_true(c.round_name().ends_with("· vuelta"))
	var back: Dictionary = c.user_match()
	assert_eq(back["home"] != 0, true, "la vuelta se invierte")
	c.complete_round([1, 0], 2) # pierde 1-0 la vuelta pero pasa 3-1
	assert_eq(Competition.winner(back), 0, "pasa por el global")
	assert_eq((c.rounds[c.current] as Array).size(), 1, "la final")
	assert_false(c.rounds[c.current][0].has("leg"), "a partido único")


func test_aggregate_tie_goes_to_penalties() -> void:
	var paths := _clubs(["esp"], 4)
	var c := Competition.create_staged_cup(paths, 0, [0, 0, 0, 0], 3, 2)
	c.complete_round([2, 1], 1)
	var back: Dictionary = c.user_match()
	c.complete_round([2, 1], 2) # 2-1 y 1-2: 3-3 global
	assert_eq((back["result"] as Array).size(), 4, "penales")
	assert_gt(Competition.winner(back), -1)


func test_libertadores_groups_then_draw() -> void:
	var paths := _clubs(["arg", "bra"], 32)
	var c := Competition.create_groups(paths, 0, 9, true, "draw", 2)
	assert_eq(c.groups.size(), 8)
	assert_eq(c.rounds.size(), 6, "6 fechas de grupos")
	assert_eq(c.round_name(), "Fase de grupos · fecha 1 de 6")
	for r in 6:
		c.complete_round([], 10 + r)
	assert_eq(c.round_name(), "Octavos de final · ida")
	for g in c.rounds[6]:
		assert_ne(c.group_of(g["home"]), c.group_of(g["away"]), "no se repite el grupo")
	_play_out(c)
	assert_gt(c.champion, -1)


func test_sudamericana_playoff_with_libertadores_thirds() -> void:
	var paths := _clubs(["arg", "bra"], 40)
	var sud := Competition.create_groups(paths.slice(0, 32), 0, 4, true, "sud", 2)
	var thirds: Array[String] = []
	thirds.assign(paths.slice(32, 40))
	var idx := sud.add_teams(thirds, paths[35])
	assert_eq(idx.size(), 8)
	assert_eq(sud.user_team, 35, "tu club pasa a esta copa")
	for r in 6:
		sud.complete_round([], 20 + r)
	assert_eq(sud.round_name(), "Playoffs · ida")
	assert_eq((sud.rounds[6] as Array).size(), 8)
	assert_eq(sud.seeds.size(), 8, "los 1.º esperan en octavos")
	sud.complete_round([], 1)
	sud.complete_round([], 2)
	assert_eq(sud.round_name(), "Octavos de final · ida")
	_play_out(sud)
	assert_gt(sud.champion, -1)


func test_swiss_league_phase() -> void:
	var paths := _clubs(["eng", "esp", "ita", "ger"], 36)
	var c := Competition.create_swiss(paths, 0, 21)
	assert_eq(c.rounds.size(), 8, "8 fechas")
	var games := {}
	var home := {}
	for r in c.rounds:
		assert_eq((r as Array).size(), 18)
		var seen := {}
		for g in r:
			assert_false(seen.has(g["home"]) or seen.has(g["away"]), "uno por fecha")
			seen[g["home"]] = true
			seen[g["away"]] = true
			games[g["home"]] = int(games.get(g["home"], 0)) + 1
			games[g["away"]] = int(games.get(g["away"], 0)) + 1
			home[g["home"]] = int(home.get(g["home"], 0)) + 1
	for t in 36:
		assert_eq(games[t], 8)
		assert_eq(home[t], 4, "4 de local")
	assert_eq(c.round_name(), "Fase liga · fecha 1 de 8")
	for r in 8:
		c.complete_round([], 30 + r)
	assert_eq(c.round_name(), "Playoffs · ida")
	assert_eq((c.rounds[8] as Array).size(), 8)
	var table := c.standings(0, 8)
	assert_true(c.seeds.has(table[0]["team"]), "el 1.º espera en octavos")
	var po_teams := []
	for g in c.rounds[8]:
		po_teams.append(g["home"])
		po_teams.append(g["away"])
	assert_true(po_teams.has(table[8]["team"]) and po_teams.has(table[23]["team"]))
	assert_false(po_teams.has(table[24]["team"]), "del 25.º para abajo, afuera")
	c.complete_round([], 1)
	c.complete_round([], 2)
	assert_eq(c.round_name(), "Octavos de final · ida")
	_play_out(c)
	assert_gt(c.champion, -1)


func test_new_formats_survive_save_and_load() -> void:
	var c := Competition.create_swiss(_clubs(["eng", "esp", "ita", "ger"], 36), 3, 2)
	for r in 9:
		c.complete_round([], 50 + r)
	var d := Competition.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(d.ko, "swiss")
	assert_eq(d.group_rounds, 8)
	assert_eq(d.seeds, c.seeds)
	assert_eq(d.round_name(), c.round_name())
	assert_eq(int(d.rounds[9][0]["leg"]), 2)
	assert_eq(d.rounds[9][0]["agg"], c.rounds[9][0]["agg"])
	_play_out(d)
	assert_gt(d.champion, -1)
