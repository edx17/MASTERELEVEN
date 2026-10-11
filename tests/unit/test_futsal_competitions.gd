extends GutTest
## Futsal F5: Liga con playoff (A, B, C, D en zonas), Supercopa y torneos
## amistosos.

var _saved := {}


func before_all() -> void:
	for k in ["database", "home_team_path", "away_team_path"]:
		_saved[k] = GameSettings.get(k)
	GameSettings.use_database("futsal_afa")


## Vuelve todo como estaba (la base de futsal cambia local y visitante).
func after_all() -> void:
	GameSettings.use_database(String(_saved["database"]) if String(_saved["database"]) != "" else TeamDB.DEFAULT_DB)
	for k in _saved:
		GameSettings.set(k, _saved[k])


func _play_league(c: Competition) -> void:
	var s := 1
	while c.current < c.group_rounds:
		c.complete_round([], s)
		s += 1


func _finish(c: Competition) -> void:
	var s := 100
	while not c.finished():
		c.complete_round([], s)
		s += 1


func test_primera_a_league_and_playoff() -> void:
	var zones := FutsalLeague.division_zones("futA")
	var c := FutsalLeague.create("futA", zones, zones[0][0], 7)
	assert_eq(c.team_paths.size(), 18)
	assert_eq(c.group_rounds, 34, "ida y vuelta")
	_play_league(c)
	assert_eq(c.champion, -1, "en la A no hay campeón de la fase regular")
	var table := c.group_table(0)
	var qf: Array = c.rounds[c.group_rounds]
	assert_eq(qf.size(), 4, "cuartos de final")
	var first := int(table[0]["team"])
	var eighth := int(table[7]["team"])
	var g0: Dictionary = qf[0]
	assert_eq([g0["home"], g0["away"]], [eighth, first], "1.º contra 8.º; la ida en cancha del peor ubicado")
	assert_eq(int(g0["leg"]), 1)
	assert_eq(int(g0["adv"]), first, "empate en el global: pasa el mejor ubicado")
	assert_true(c.notes.any(func(n: String) -> bool: return n.begins_with("Descienden")), "los 2 últimos descienden")
	_finish(c)
	assert_gte(c.champion, 0)
	assert_true(String(c.notes[0]).begins_with("Campeón"), "el ganador del playoff es el campeón")


func test_quarterfinal_tie_goes_to_the_better_placed_and_semis_to_penalties() -> void:
	var g := {"home": 5, "away": 1, "result": [1, 1], "leg": 2, "agg": [2, 2], "adv": 1}
	assert_eq(Competition.winner(g), 1, "cuartos: mejor ubicado")
	var semi := {"home": 5, "away": 1, "result": [1, 1, 3, 4], "leg": 2, "agg": [2, 2]}
	assert_eq(Competition.winner(semi), 1, "semis: penales")
	var zones := FutsalLeague.division_zones("futA")
	var c := FutsalLeague.create("futA", zones, zones[0][0], 3)
	_play_league(c)
	# Ida y vuelta de cuartos: la vuelta conserva la ventaja.
	c.complete_round([], 500)
	var back: Array = c.rounds[c.current]
	assert_eq(int(back[0]["leg"]), 2)
	assert_true(back[0].has("adv"))
	c.complete_round([], 501)
	var semis: Array = c.rounds[c.current]
	assert_eq(semis.size(), 2)
	assert_false(semis[0].has("adv"), "desde semifinales, penales")
	assert_string_contains(c.round_name(c.current), "semifinales")


func test_primera_b_champion_promotes_and_playoff_two_to_nine() -> void:
	var zones := FutsalLeague.division_zones("futB")
	var c := FutsalLeague.create("futB", zones, zones[0][3], 11)
	_play_league(c)
	var table := c.group_table(0)
	var in_po := {}
	for g in c.rounds[c.group_rounds]:
		in_po[int(g["home"])] = true
		in_po[int(g["away"])] = true
	assert_false(in_po.has(int(table[0]["team"])), "el campeón no juega el playoff")
	for k in range(1, 9):
		assert_true(in_po.has(int(table[k]["team"])), "del 2.º al 9.º")
	assert_string_contains(String(c.notes[0]), "asciende")
	_finish(c)
	assert_string_contains(String(c.notes[0]), "Ganador del playoff")


func test_primera_d_two_zones_and_crossed_playoff() -> void:
	var zones := FutsalLeague.division_zones("futD1")
	assert_eq(zones.size(), 2)
	var c := FutsalLeague.create("futD", zones, zones[1][0], 5)
	assert_eq(c.groups.size(), 2)
	for games in c.rounds:
		for g in games:
			assert_eq(c.group_of(g["home"]), c.group_of(g["away"]), "cada zona juega entre sí")
	_play_league(c)
	var z1 := c.group_table(0)
	var z2 := c.group_table(1)
	var qf: Array = c.rounds[c.group_rounds]
	var pairs: Array = qf.map(func(g: Dictionary) -> Array: return [g["home"], g["away"]])
	var has := func(x: int, y: int) -> bool:
		return pairs.has([x, y]) or pairs.has([y, x])
	assert_true(has.call(int(z1[1]["team"]), int(z2[4]["team"])), "2.º Z1 - 5.º Z2")
	assert_true(has.call(int(z1[2]["team"]), int(z2[3]["team"])), "3.º Z1 - 4.º Z2")
	assert_true(has.call(int(z1[4]["team"]), int(z2[1]["team"])), "5.º Z1 - 2.º Z2")
	assert_eq(c.notes.filter(func(n: String) -> bool: return n.begins_with("Campeón de la Zona")).size(), 2, "asciende el campeón de cada zona")
	_finish(c)
	assert_gte(c.champion, 0, "el ganador del playoff es el 3.er ascenso")


func test_supercup_format() -> void:
	var paths := FutsalLeague.supercup_paths()
	assert_eq(paths.size(), 5)
	var c := FutsalLeague.create_supercup(paths, 0)
	var r0: Array = c.rounds[0]
	assert_eq(r0.size(), 1, "antes, los campeones de la D")
	assert_eq([r0[0]["home"], r0[0]["away"]], [3, 4])
	c.complete_round([], 9)
	var semis: Array = c.rounds[1]
	var d_winner := Competition.winner(r0[0])
	assert_eq([semis[0]["home"], semis[0]["away"]], [0, d_winner], "A contra el de la D")
	assert_eq([semis[1]["home"], semis[1]["away"]], [1, 2], "B contra C")
	_finish(c)
	assert_gte(c.champion, 0)
	assert_eq(c.rounds.size(), 3, "repechaje, semis y final")


func test_saved_futsal_league_keeps_playoff_state() -> void:
	var zones := FutsalLeague.division_zones("futC")
	var c := FutsalLeague.create("futC", zones, zones[0][0], 4)
	_play_league(c)
	var d := c.to_dict()
	var back := Competition.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_eq(back.ko, "futsal")
	assert_eq(back.fmt, "futC")
	assert_eq(back.notes, c.notes)
	assert_true((back.rounds[back.group_rounds][0] as Dictionary).has("adv"))
	assert_eq(FutsalLeague.FORMATS["futC"]["down"], 3, "en la C descienden 3")


func test_copa_argentina_staged_entry() -> void:
	var a0: String = TeamDB.division_paths("arg", "futA")[0]
	var c := FutsalLeague.create_copa_argentina(a0, 13)
	assert_eq(c.team_paths.size(), 92, "todos los clubes")
	var d_ids: Array = c.entries[0]
	var first: Array = c.rounds[0]
	for g in first:
		assert_true(d_ids.has(g["home"]) and d_ids.has(g["away"]), "Fase 1: sólo los de la D")
	assert_string_contains(c.round_name(0), "Fase 1")
	assert_true(c.alive(c.user_team), "el de la A espera")
	c.complete_round([], 1)
	var second: Array = c.rounds[1]
	var c_ids: Array = c.entries[1]
	var c_in := 0
	for g in second:
		for side in ["home", "away"]:
			assert_false((c.entries[2] as Array).has(g[side]), "la A y la B todavía no")
			if c_ids.has(g[side]):
				c_in += 1
	assert_gt(c_in, 0, "Fase 2: entran los de la C")
	c.complete_round([], 2)
	assert_string_contains(c.round_name(2), "32avos")
	# Después de 32avos, la ronda siguiente es de 32 (16avos).
	c.complete_round([], 3)
	assert_eq((c.rounds[3] as Array).size(), 16, "16avos")
	var s := 10
	while not c.finished():
		c.complete_round([], s)
		s += 1
	assert_gte(c.champion, 0)
	assert_eq((c.rounds.back() as Array).size(), 1, "final")
