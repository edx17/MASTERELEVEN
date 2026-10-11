extends GutTest
## Futsal F6: Liga Virtual de futsal (carrera), estadios y pantalla de carga.

var _saved := {}
var _root := ""


func before_all() -> void:
	for k in ["database", "home_team_path", "away_team_path", "gym_style"]:
		_saved[k] = GameSettings.get(k)
	GameSettings.use_database("futsal_afa")


func after_all() -> void:
	TeamDB.use_option_file(null)
	GameSettings.use_database(String(_saved["database"]) if String(_saved["database"]) != "" else TeamDB.DEFAULT_DB)
	for k in _saved:
		GameSettings.set(k, _saved[k])


func before_each() -> void:
	_root = ProjectSettings.globalize_path("user://test_futsal_career_%d" % randi())
	UserData.root_override = _root
	UserData.ensure_dirs()
	TeamDB.use_option_file(null)


func after_each() -> void:
	MasterCareer.deactivate()
	TeamDB.use_option_file(null)
	UserData.root_override = ""


func _club(div: String, i: int = 0) -> String:
	return TeamDB.division_paths("arg", div)[i].get_slice(":", 3)


func test_start_in_primera_d() -> void:
	var d2 := _club("futD2", 3)
	assert_eq(MasterCareer.start_division_name("arg", d2), "Primera D")
	assert_eq(MasterCareer.start_division("arg", _club("futD1", 2)), 3, "un club de la Zona 1 se queda en su zona")
	var m := MasterCareer.create("arg", d2, "real", 11)
	assert_true(m.futsal())
	assert_eq(m.leagues.size(), 4, "A, B, C y la D con sus dos zonas")
	assert_eq(m.user_league_index(), 3)
	var d: Competition = m.user_league()
	assert_eq(d.ko, "futsal")
	assert_eq(d.groups.size(), 2)
	assert_eq(m.division_name(3), "Primera D")
	var sizes := m.leagues.map(func(l: Dictionary) -> int: return (l["comp"] as Competition).team_paths.size())
	assert_eq(sizes, [18, 18, 18, 38])
	for i in 3:
		assert_eq((m.leagues[i]["comp"] as Competition).user_team, -1, "sólo tu liga tiene al usuario")
	assert_eq(m.user_team().players.size(), 14, "plantel de futsal")


func test_big_club_drops_to_d_and_sizes_hold() -> void:
	var a0 := _club("futA", 0)
	var m := MasterCareer.create("arg", a0, "real", 5)
	assert_eq(m.squad_mode, "we", "club de la A: Equipo WE")
	assert_eq(m.user_league_index(), 3)
	var sizes := m.leagues.map(func(l: Dictionary) -> int: return (l["comp"] as Competition).team_paths.size())
	assert_eq(sizes, [18, 18, 18, 38])


func test_futsal_cups_only() -> void:
	var m := MasterCareer.create("arg", _club("futD1", 4), "real", 21)
	var ids := m.cups.map(func(e: Dictionary) -> String: return String(e["id"]))
	assert_eq(ids, ["fut_super", "fut_copa"], "Supercopa y Copa Argentina; sin internacionales ni Sub-20")
	var copa: Competition = m.cups[1]["comp"]
	assert_eq(copa.ko, "copa_arg")
	assert_eq(copa.team_paths.size(), 92)
	assert_gte(copa.user_team, 0)
	assert_false(m.world_cup_year())


func test_full_season_promotions_and_next_season() -> void:
	var me := _club("futD2", 6)
	var m := MasterCareer.create("arg", me, "real", 31)
	var before: Array = []
	for l in m.leagues:
		before.append((l["comp"] as Competition).team_paths.duplicate())
	m.simulate_to_end(77)
	assert_true(m.season_over)
	var s: Dictionary = m.history.back()
	var divs: Array = s["divisions"]
	assert_eq(divs.size(), 4)
	assert_eq((divs[1]["up"] as Array).size(), 2, "de la B suben el campeón y el del playoff")
	assert_eq((divs[0]["down"] as Array).size(), 2)
	assert_eq((divs[2]["down"] as Array).size(), 3, "de la C descienden 3")
	assert_eq((divs[3]["up"] as Array).size(), 3, "de la D, los dos campeones de zona y el del playoff")
	assert_true(s.has("futsal_super"))
	assert_eq((s["futsal_super"] as Array).size(), 5)
	assert_false(s.has("world_cup"))
	# Cada copa terminó.
	for e in m.cups:
		assert_gte((e["comp"] as Competition).champion, 0, String(e["name"]))
	# Temporada 2: los que subieron juegan arriba; las zonas siguen parejas.
	m.start_next_season()
	var sizes := m.leagues.map(func(l: Dictionary) -> int: return (l["comp"] as Competition).team_paths.size())
	assert_eq(sizes, [18, 18, 18, 38])
	var d: Competition = m.leagues[3]["comp"]
	assert_eq((d.groups[0] as Array).size(), 19)
	assert_eq((d.groups[1] as Array).size(), 19)
	var b_paths: Array = (m.leagues[1]["comp"] as Competition).team_paths
	for id in divs[1]["down"]:
		assert_true((m.leagues[2]["comp"] as Competition).team_paths.has(TeamDB.club_path("arg", id)), "bajó a la C")
	for id in divs[2]["up"]:
		assert_true(b_paths.has(TeamDB.club_path("arg", id)), "subió a la B")
	var sc: Dictionary = m.cup("fut_super")
	assert_false(sc.is_empty(), "Supercopa con los campeones")
	var sup: Competition = sc["comp"]
	assert_eq(sup.team_paths[0], TeamDB.club_path("arg", String(divs[0]["champion"])), "el campeón de la A (playoff)")


func test_save_and_load_futsal_career() -> void:
	var m := MasterCareer.create("arg", _club("futC", 2), "real", 8)
	for i in 3:
		m.play_round([], [], 100 + i)
	m.save()
	var back := MasterCareer.load_saved(m.file)
	assert_not_null(back)
	assert_eq((back.leagues[3]["comp"] as Competition).ko, "futsal")
	assert_eq((back.leagues[3]["comp"] as Competition).groups.size(), 2)
	assert_eq(back.cups.size(), 2)


func test_squad_rules_follow_discipline() -> void:
	assert_eq(MasterCareer.squad_target(), 14)
	assert_eq(MasterCareer.min_squad(), MasterCareer.FUTSAL_MIN_SQUAD)
	assert_eq(MasterCareer.formations(), Discipline.formations())


func test_gym_styles_build() -> void:
	var home := TeamDB.load_team(TeamDB.division_paths("arg", "futA")[0])
	for st in GymBuilder.NAMES.size():
		var g := GymBuilder.build(home, st)
		assert_not_null(g.get_node_or_null("Roof"), GymBuilder.NAMES[st])
		assert_eq(int(g.get_meta("style")), st)
		var crowds := g.find_children("Crowd", "MultiMeshInstance3D", true, false)
		assert_false(crowds.is_empty(), "con público: " + GymBuilder.NAMES[st])
		if st == GymBuilder.Style.PABELLON:
			assert_false(g.find_children("Seats", "MultiMeshInstance3D", true, false).is_empty(), "butacas")
		assert_false(g.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n is GymBuilder.Scoreboard).is_empty(),
			"marcador")
		GymBuilder.set_camera_height(g, 40.0)
		assert_false((g.get_node("Roof") as Node3D).visible)
		g.free()


func test_seat_lettering_mask() -> void:
	var mask := GymBuilder._text_mask("BOCA", 14)
	assert_eq(mask.size(), 16, "4 letras de 3 columnas y un espacio")
	var lit := range(80).filter(func(k: int) -> bool: return GymBuilder._mask_at(mask, k, 80, 2))
	assert_gt(lit.size(), 0, "la fila de arriba de las letras tiene butacas marcadas")
	assert_eq(lit.size() % 2, 0, "cada píxel ocupa dos butacas")
	assert_false(GymBuilder._mask_at(mask, 0, 80, 2), "fuera de la palabra")
	assert_false(GymBuilder._mask_at(mask, 40, 80, 0), "arriba de las letras")
	assert_true(GymBuilder._text_mask("BOCA", 5).is_empty(), "tribuna baja: sin letras")


func test_loading_tips() -> void:
	var tips := 0
	for i in 30:
		var t := String(LoadingScreen.pick_tip())
		assert_ne(t, "")
		tips += 1
	assert_eq(tips, 30)
	assert_true(LoadingScreen.TIPS_FUTSAL.any(func(t: String) -> bool: return t.contains("4 segundos")))
	assert_false(LoadingScreen.is_busy())
