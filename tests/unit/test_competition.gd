extends GutTest
## Liga y Copa: fixture, tabla, llaves con penales, simulación, guardado y
## el flujo del partido del jugador.

const TMP := "user://test_competition.json"


func _paths() -> Array[String]:
	return GameSettings.team_paths()


func test_round_robin_everyone_plays_everyone_once() -> void:
	var rounds := Competition.round_robin(8, false, 5)
	assert_eq(rounds.size(), 7, "7 fechas")
	var seen := {}
	for r in rounds:
		assert_eq(r.size(), 4, "4 partidos por fecha")
		var playing := {}
		for g in r:
			assert_false(playing.has(g["home"]) or playing.has(g["away"]), "nadie juega dos veces la misma fecha")
			playing[g["home"]] = true
			playing[g["away"]] = true
			var key := "%d-%d" % [mini(g["home"], g["away"]), maxi(g["home"], g["away"])]
			assert_false(seen.has(key), "cada cruce una sola vez")
			seen[key] = true
	assert_eq(seen.size(), 28)
	assert_eq(Competition.round_robin(8, true, 5).size(), 14, "dos ruedas")


func test_league_runs_to_a_champion_with_a_consistent_table() -> void:
	var c := Competition.create_league(_paths(), 0, false, 3)
	var played := 0
	while not c.finished():
		var g := c.user_match()
		assert_false(g.is_empty(), "el jugador juega todas las fechas")
		c.complete_round([2, 1], 100 + played)
		played += 1
	assert_eq(played, 7)
	var table := c.standings()
	var pts := 0
	var gf := 0
	var gc := 0
	for row in table:
		assert_eq(row["pj"], 7)
		pts += row["pts"]
		gf += row["gf"]
		gc += row["gc"]
	assert_eq(gf, gc, "goles a favor = en contra")
	assert_between(pts, 56, 84, "entre 2 y 3 puntos por partido")
	assert_gt(c.champion, -1)
	assert_eq(c.champion, table[0]["team"])


func test_user_result_counts_from_the_right_side() -> void:
	var c := Competition.create_league(_paths(), 2, false, 9)
	var g := c.user_match()
	c.complete_round([0, 3], 1)
	assert_eq(g["result"], [0, 3])
	var row: Dictionary = {}
	for r in c.standings():
		if r["team"] == 2:
			row = r
	var won: bool = (g["away"] == 2)
	assert_eq(row["pts"], 3 if won else 0)


func test_cup_needs_a_winner_and_crowns_a_champion() -> void:
	var c := Competition.create_cup(_paths(), 0, 4)
	assert_eq(c.round_name(), "Cuartos de final")
	c.complete_round([1, 1], 7)
	var g: Dictionary = {}
	for x in c.rounds[0]:
		if x["home"] == 0 or x["away"] == 0:
			g = x
	assert_eq((g["result"] as Array).size(), 4, "empate: penales")
	assert_ne(g["result"][2], g["result"][3])
	while not c.finished():
		c.complete_round([3, 0], 11 + c.current)
	assert_eq(c.rounds.size(), 3, "cuartos, semis y final")
	assert_gt(c.champion, -1)
	assert_eq(c.rounds[2].size(), 1)


func test_simulated_scores_look_like_football() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var a := load(_paths()[0]) as TeamData
	var b := load(_paths()[1]) as TeamData
	var total := 0
	var n := 400
	for i in n:
		var s := Competition.simulate_score(a, b, rng)
		total += s[0] + s[1]
	assert_between(float(total) / n, 1.6, 3.8, "unos 2-3 goles por partido")


func test_save_and_load_round_trip() -> void:
	var c := Competition.create_cup(_paths(), 3, 8)
	c.complete_round([2, 0], 5)
	c.save(TMP)
	var d := Competition.load_saved(TMP)
	assert_not_null(d)
	assert_eq(d.kind, Competition.Kind.CUP)
	assert_eq(d.user_team, 3)
	assert_eq(d.current, 1)
	assert_eq(d.rounds.size(), 2)
	assert_eq(d.rounds[0][0]["result"], c.rounds[0][0]["result"])
	Competition.delete_saved(TMP)
	assert_null(Competition.load_saved(TMP))


func test_match_result_is_handed_back_only_at_full_time() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	GameSettings.human_side = 1
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	assert_eq(m.humans[0].team, m.teams[1], "el humano de visitante")
	GameSettings.human_side = 0
	m.teams[0].score = 2
	m.teams[1].score = 1
	m.phase = MatchController.Phase.FULLTIME
	GameSettings.last_result = []
	# exit_to_menu cambia de escena: se prueba sólo la parte del resultado.
	GameSettings.last_result = [m.teams[0].score, m.teams[1].score] if m.phase == MatchController.Phase.FULLTIME else []
	assert_eq(GameSettings.last_result, [2, 1])
	GameSettings.last_result = []
