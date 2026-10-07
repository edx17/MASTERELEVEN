extends GutTest
## Base Temporada 2026: ids únicos, el mismo jugador en su club y en su
## selección (también en la Liga Virtual) y partidas atadas a su base.

var _root := ""


func before_each() -> void:
	_root = ProjectSettings.globalize_path("user://test_db2026_%d" % randi())
	UserData.root_override = _root
	UserData.ensure_dirs()
	TeamDB.use_db("t2026")


func after_each() -> void:
	TeamDB.use_db(TeamDB.DEFAULT_DB)
	_rm(_root)
	UserData.root_override = ""


func _rm(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	for sub in d.get_directories():
		_rm(dir.path_join(sub))
	DirAccess.remove_absolute(dir)


## Un convocado de la selección que juega en un club de la base: [pid, "pais:club"].
func _shared_player(nat: String) -> Array:
	var clubs := {}
	for c in TeamDB.countries():
		for d in c["divisions"]:
			for cl in d["clubs"]:
				for p in cl.get("players", []):
					clubs[int(p["pid"])] = "%s:%s" % [c["id"], cl["id"]]
	for pid in TeamDB.nation(nat)["squad"]:
		if clubs.has(int(pid)):
			return [int(pid), clubs[int(pid)]]
	return []


func test_both_databases_are_available() -> void:
	assert_eq(TeamDB.available_dbs(), ["ficticia", "t2026"])
	assert_eq(TeamDB.db_name("t2026"), "Temporada 2026")


func test_ids_are_unique_and_references_resolve() -> void:
	var problems := load("res://tools/build_db.gd").validate(TeamDB.base_countries(), TeamDB.base_nations(),
		TeamDB.external_players(), []) as Array
	assert_eq(problems, [], "sin ids repetidos ni convocados sueltos")
	assert_gt(TeamDB.base_nations().size(), 100)
	assert_gt(TeamDB.max_pid(), 20000)


func test_same_player_in_club_and_national_team() -> void:
	var hit := _shared_player("arg")
	assert_false(hit.is_empty(), "Argentina tiene convocados de clubes de la base")
	var parts := String(hit[1]).split(":")
	var club := TeamDB.load_team(TeamDB.club_path(parts[0], parts[1]))
	var nat := TeamDB.load_team(TeamDB.nation_path("arg"))
	var in_club: Array = club.players.filter(func(p: PlayerData) -> bool: return p.pid == hit[0])
	var in_nat: Array = nat.players.filter(func(p: PlayerData) -> bool: return p.pid == hit[0])
	assert_eq(in_club.size(), 1)
	assert_eq(in_nat.size(), 1, "el mismo id en la selección")
	assert_eq((in_club[0] as PlayerData).player_name, (in_nat[0] as PlayerData).player_name)
	assert_eq((in_club[0] as PlayerData).shooting, (in_nat[0] as PlayerData).shooting, "mismos atributos")


func test_changes_to_the_club_player_show_in_the_national_team() -> void:
	var hit := _shared_player("arg")
	var parts := String(hit[1]).split(":")
	var entry: Dictionary = (TeamDB.club(parts[0], parts[1])[0] as Dictionary).duplicate(true)
	for d in entry["players"]:
		if int(d["pid"]) == hit[0]:
			d["inj"] = 3
	# Como en la Liga Virtual: el mundo de la carrera cambia al jugador.
	var of := OptionFile.new()
	of.set_club(parts[0], entry)
	TeamDB.use_option_file(of)
	var nat := TeamDB.load_team(TeamDB.nation_path("arg"))
	var p: PlayerData = nat.players.filter(func(x: PlayerData) -> bool: return x.pid == hit[0])[0]
	assert_true(p.unavailable, "lesionado en el club = lesionado en la selección")


func test_career_keeps_database_ids() -> void:
	var c := TeamDB.country("arg")
	var bottom: Dictionary = (c["divisions"] as Array).back()
	var club_id := String(bottom["clubs"][0]["id"])
	var base_pids: Array = (bottom["clubs"][0]["players"] as Array).map(func(d: Dictionary) -> int: return int(d["pid"]))
	var m := MasterCareer.create("arg", club_id, "real", 7)
	assert_eq(m.db, "t2026")
	var world_pids: Array = (m.world.clubs["arg:" + club_id]["players"] as Array).map(func(d: Dictionary) -> int: return int(d["pid"]))
	world_pids.sort()
	base_pids.sort()
	assert_eq(world_pids, base_pids, "los jugadores siguen con su id de la base")
	assert_gt(m.next_pid, TeamDB.max_pid() - 1, "los nuevos (juveniles) no pisan ids de la base")
	MasterCareer.deactivate()


func test_saves_only_load_with_their_database() -> void:
	var c := Competition.create_league(TeamDB.division_paths("arg", "arg1"), 0, false, 3)
	c.save()
	assert_eq(Competition.list_saves().size(), 1)
	assert_not_null(Competition.load_saved(c.file))
	TeamDB.use_db("ficticia")
	assert_eq(Competition.list_saves().size(), 0, "con la Ficticia no aparece")
	assert_null(Competition.load_saved(c.file), "ni se carga")
	TeamDB.use_db("t2026")
	assert_eq(Competition.load_saved(c.file).db, "t2026")


func test_option_files_belong_to_their_database() -> void:
	var of := OptionFile.new()
	of.name = "Mio 2026"
	of.save()
	assert_eq(OptionFile.list().size(), 1)
	TeamDB.use_db("ficticia")
	assert_eq(OptionFile.list().size(), 0)
	assert_null(OptionFile.load_named("Mio 2026"))


func test_old_saves_are_from_the_fictional_database() -> void:
	assert_eq(TeamDB.db_of({"format": "VirtualEleven Partida"}), "ficticia")
	assert_eq(TeamDB.db_of({"db": "t2026"}), "t2026")
