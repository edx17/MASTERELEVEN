extends GutTest
## Futsal (F0 + F1): disciplina, cancha de 40 x 20 con arcos de 3 x 2, base
## AFA con sus divisiones, formaciones de 5, gimnasio y menú.

var _saved := {}


func before_each() -> void:
	for k in ["database", "home_team_path", "away_team_path", "court_surface", "offside"]:
		_saved[k] = GameSettings.get(k)


func after_each() -> void:
	TeamDB.use_db(TeamDB.DEFAULT_DB)
	for k in _saved:
		GameSettings.set(k, _saved[k])
	assert_false(Discipline.is_futsal(), "vuelve al fútbol")


func test_court_measures_follow_the_discipline() -> void:
	Discipline.use(Discipline.FUTSAL)
	assert_eq(Pitch.HALF_LENGTH, 20.0, "40 m de largo")
	assert_eq(Pitch.HALF_WIDTH, 10.0, "20 m de ancho")
	assert_eq(Pitch.GOAL_HALF_WIDTH * 2.0, 3.0, "arco de 3 m")
	assert_eq(Pitch.GOAL_HEIGHT, 2.0, "y 2 de alto")
	assert_eq(Pitch.PENALTY_SPOT_DISTANCE, 6.0)
	assert_eq(Pitch.SECOND_PENALTY_DISTANCE, 10.0, "doble penal a 10 m")
	assert_almost_eq(Pitch.SCALE, 20.0 / 52.5, 0.001)
	assert_eq(Discipline.players(), 5)
	assert_false(Discipline.offside(), "sin offside")
	Discipline.use(Discipline.FOOTBALL)
	assert_eq(Pitch.HALF_LENGTH, 52.5)
	assert_eq(Pitch.HALF_WIDTH, 34.0)
	assert_eq(Pitch.SCALE, 1.0)


func test_five_a_side_formations() -> void:
	Discipline.use(Discipline.FUTSAL)
	var defs := FormationLibrary.definitions()
	for f in ["1-2-1", "2-2", "1-3", "3-1", "4-0"]:
		assert_true(defs.has(f), f)
		var fd := FormationLibrary.build(f)
		assert_eq(fd.slots.size(), 5, f + ": arquero y 4")
		assert_true(fd.is_valid(), f)
	assert_eq(FormationLibrary.build("4-4-2").slots.size(), 5, "una de 11 cae en la de 5 por defecto")


func test_ball_bounces_lower_on_the_court() -> void:
	var foot := Tuning.new()
	var fut := Tuning.new()
	Discipline.use(Discipline.FUTSAL)
	Discipline.apply_to(fut)
	assert_lt(fut.ground_restitution, foot.ground_restitution, "pelota de bote bajo")
	assert_lt(fut.bounce_friction, foot.bounce_friction + 0.0001)


func test_afa_database_divisions_and_rosters() -> void:
	assert_true(TeamDB.available_dbs().has("futsal_afa"))
	assert_eq(TeamDB.dbs_of(Discipline.FUTSAL), ["futsal_afa"])
	TeamDB.use_db("futsal_afa")
	assert_true(Discipline.is_futsal(), "la base define la disciplina")
	var arg := TeamDB.country("arg")
	var ids: Array = (arg["divisions"] as Array).map(func(d: Dictionary) -> String: return String(d["id"]))
	assert_eq(ids, ["futA", "futB", "futC", "futD1", "futD2"], "A, B, C y D en dos zonas")
	var pids := {}
	var clubs := 0
	for d in arg["divisions"]:
		for cl in d["clubs"]:
			clubs += 1
			assert_eq((cl["players"] as Array).size(), 14, String(cl["name"]))
			for p in cl["players"]:
				assert_false(pids.has(int(p["pid"])), "pid único")
				pids[int(p["pid"])] = true
	assert_eq(clubs, 92)
	var paths := TeamDB.division_paths("arg", "futA")
	var t := TeamDB.load_team(paths[0])
	assert_eq(t.starters().size(), 5, "5 titulares")
	assert_eq(t.players.size(), 14)
	assert_eq(t.players.filter(func(p: PlayerData) -> bool: return p.position == PlayerData.Position.GK).size(), 2, "dos arqueros")


func test_boca_wears_its_football_colors() -> void:
	TeamDB.use_db("futsal_afa")
	for p in TeamDB.division_paths("arg", "futA"):
		var t := TeamDB.load_team(p)
		if t.team_name == "Boca":
			assert_almost_eq(t.color.b, Color("#0a2a6e").b, 0.02, "azul y oro, no un color de la paleta")
			return
	fail_test("Boca no está en la Primera A")


func test_futsal_only_plays_with_futsal_clubs() -> void:
	GameSettings.home_team_path = GameSettings.DEFAULT_HOME
	GameSettings.use_database("futsal_afa")
	assert_true(GameSettings.home_team_path.begins_with("db:"), "los Equipos WE son de 11: se cambia por un club")
	assert_false(GameSettings.team_ok(GameSettings.DEFAULT_AWAY))
	assert_ne(GameSettings.home_team_path, GameSettings.away_team_path)
	GameSettings.offside = true
	assert_false(GameSettings.offside_on(), "en futsal no hay offside")
	GameSettings.use_database(TeamDB.DEFAULT_DB)
	assert_true(GameSettings.offside_on())


func test_court_and_markings_are_built() -> void:
	Discipline.use(Discipline.FUTSAL)
	GameSettings.court_surface = 1
	var pitch := PitchBuilder.build()
	add_child_autofree(pitch)
	assert_null(PitchBuilder.grass_material, "sin pasto")
	var hl := Pitch.HALF_LENGTH
	var lines := PitchMarkings._futsal_lines(hl, Pitch.HALF_WIDTH)
	assert_gt(lines.size(), 4, "perímetro, mitad, áreas y zonas de cambio")
	for seg in lines:
		for pt in seg:
			assert_true(absf(pt.x) <= hl + 0.01 and absf(pt.y) <= Pitch.HALF_WIDTH + 0.5, "las líneas quedan en la cancha (las de cambio, 40 cm afuera)")


func test_gym_has_a_roof_hidden_for_high_cameras() -> void:
	Discipline.use(Discipline.FUTSAL)
	var gym := GymBuilder.build(null)
	add_child_autofree(gym)
	var roof := gym.get_node("Roof") as Node3D
	GymBuilder.set_camera_height(gym, 6.0)
	assert_true(roof.visible, "desde adentro se ve el techo")
	GymBuilder.set_camera_height(gym, 20.0)
	assert_false(roof.visible, "la cámara Amplia y el dron miran desde arriba")


func test_camera_presets_scale_to_the_court() -> void:
	Discipline.use(Discipline.FUTSAL)
	var c := load("res://data/config/cameras/amplia.tres") as CameraConfig
	var s := MatchCamera.scaled(c)
	assert_lt(s.camera_height, c.camera_height)
	assert_lt(s.camera_distance, c.camera_distance)
	assert_eq(s.focus_limit_x, Pitch.HALF_LENGTH - 4.0)


func test_menu_asks_football_or_futsal_after_the_title() -> void:
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	menu.call("leave_title")
	assert_eq(menu.call("_current"), "discipline")
	var col: VBoxContainer = menu.get("_disc_col")
	var ds: Array = col.get_children().filter(func(b: Node) -> bool: return b.has_meta("discipline")) \
		.map(func(b: Node) -> String: return String(b.get_meta("discipline")))
	assert_eq(ds, ["football", "futsal"])
	# Futsal tiene una sola base: va directo al menú.
	menu.call("_choose_discipline", Discipline.FUTSAL)
	assert_eq(menu.call("_current"), "home")
	assert_eq(TeamDB.db_id, "futsal_afa")
	var home: HomeScreen = menu.get("_home")
	for i in HomeScreen.MENU.size():
		if HomeScreen.MENU[i][0] == "master":
			assert_true(home.menu_items[i].visible, "Liga Virtual de futsal (F6)")
	for i in HomeScreen.OTHER_MODES.size():
		if HomeScreen.OTHER_MODES[i][0] == "league":
			assert_true(home.mode_cards[i].visible, "Liga sí")
		if HomeScreen.OTHER_MODES[i][0] == "world":
			assert_false(home.mode_cards[i].visible, "Mundial no")
	menu.call("_choose_database", TeamDB.DEFAULT_DB)
	for b in home.menu_items:
		assert_true(b.visible, "en fútbol, todo")


func test_match_setup_shows_the_floor_in_futsal() -> void:
	TeamDB.use_db("futsal_afa")
	GameSettings.fix_team_paths()
	var ms := MatchSetup.new()
	add_child_autofree(ms)
	ms.open()
	var visible: Array = ms._rows.filter(func(r: Control) -> bool: return r.visible).map(func(r: WEStyle.OptionRow) -> String: return r.caption)
	assert_true(visible.has("Piso"))
	assert_false(visible.has("Césped"))
	assert_false(visible.has("Offside"))
	GameSettings.court_surface = 0
	ms._futsal_rows[0].step.call(1)
	assert_eq(GameSettings.court_surface, 1, "parquet -> pista azul")
