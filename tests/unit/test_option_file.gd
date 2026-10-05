extends GutTest
## E1: carpeta del jugador, Option File (cambios sobre la base) e importación
## de planteles desde el juego.

var _root := ""


func before_each() -> void:
	_root = ProjectSettings.globalize_path("user://test_userdata_%d" % randi())
	UserData.root_override = _root
	UserData.ensure_dirs()


func after_each() -> void:
	TeamDB.use_option_file(null)
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


func test_user_folders_exist() -> void:
	for sub in UserData.SUBDIRS:
		assert_true(DirAccess.dir_exists_absolute(UserData.path(sub)), sub)
	assert_true(FileAccess.file_exists(UserData.import_dir().path_join("LEEME.txt")))


func test_option_file_overrides_without_touching_the_base() -> void:
	var of := OptionFile.new()
	of.name = "Prueba"
	var boca: Dictionary = TeamDB.club("arg", "boca")[0].duplicate(true)
	boca["name"] = "Boca Editado"
	of.set_club("arg", boca)
	var nueva := {"id": "xxx", "name": "Club Nuevo", "short": "NUE", "home": "00ff00/ffffff/00ff00", "away": "ffffff/ffffff/ffffff"}
	of.set_club("arg", nueva)
	var ids: Array = []
	for cl in TeamDB.club("arg", "boca")[1]["clubs"]:
		ids.append(cl["id"])
	ids.erase("riestra")
	ids.append("xxx")
	of.set_division("arg", "arg1", ids)
	of.deleted_nations.append("chn")
	assert_true(of.save())
	var loaded := OptionFile.load_named("Prueba")
	assert_not_null(loaded)
	TeamDB.use_option_file(loaded)
	assert_eq(TeamDB.load_team(TeamDB.club_path("arg", "boca")).team_name, "Boca Editado")
	var lpf := TeamDB.division_paths("arg", "arg1")
	assert_true(lpf.has(TeamDB.club_path("arg", "xxx")), "club nuevo en la LPF")
	assert_false(lpf.has(TeamDB.club_path("arg", "riestra")), "sacado de la LPF")
	assert_eq(TeamDB.nations().size(), 58, "una selección borrada")
	TeamDB.use_option_file(null)
	assert_eq(TeamDB.load_team(TeamDB.club_path("arg", "boca")).team_name, "Boca Juniors", "la base intacta")
	assert_eq(TeamDB.nations().size(), 59)


func test_list_export_and_import() -> void:
	var of := OptionFile.new()
	of.name = "Temporada"
	of.set_nation({"id": "arg", "name": "Argentina 2026", "short": "ARG"})
	of.save()
	assert_eq(OptionFile.list().size(), 1)
	var out := _root.path_join("exportado.meof")
	assert_true(of.export_to(out))
	var name := OptionFile.import_from(out)
	assert_eq(name, "Temporada (2)", "no pisa el que ya está")
	assert_eq(OptionFile.list().size(), 2)
	OptionFile.delete_named("Temporada (2)")
	assert_eq(OptionFile.list().size(), 1)


func test_import_folder_goes_to_the_option_file() -> void:
	var f := FileAccess.open(UserData.import_dir().path_join("planteles.csv"), FileAccess.WRITE)
	f.store_string("short_name,club_name,nationality_name,player_positions,overall\n" +
		"J. Real,Boca Juniors,Argentina,GK,80\nK. Real,Boca Juniors,Argentina,CB,79\n")
	f.close()
	var of := OptionFile.new()
	of.name = "Importado"
	var imp := SquadImporter.new()
	var res := imp.import_folder(UserData.import_dir(), of)
	assert_eq(res["files"], 1)
	assert_eq(res["clubs"], 1)
	assert_true(of.clubs.has("arg:boca"))
	assert_eq(TeamDB.load_team(TeamDB.club_path("arg", "boca")).players[0].player_name.begins_with("J. Real"), false,
		"la base no cambia")
	TeamDB.use_option_file(OptionFile.load_named("Importado"))
	var boca := TeamDB.load_team(TeamDB.club_path("arg", "boca"))
	assert_eq(boca.players[0].player_name, "J. Real", "el arquero importado, titular")


## Cada Liga / Copa / Mundial en su archivo; CONTINUAR las lista con dónde va.
func test_saves_are_separate_and_listed() -> void:
	var paths := TeamDB.division_paths("eng", "eng1")
	var liga := Competition.create_league(paths, 0, false, 3)
	liga.save()
	var copa := Competition.create_cup(GameSettings.team_paths(), 2, 4)
	copa.option_file = "Algo"
	copa.save()
	assert_true(liga.file.begins_with(UserData.saves_dir("ligas")))
	assert_true(copa.file.begins_with(UserData.saves_dir("copas")))
	assert_ne(liga.file, copa.file)
	liga.complete_round([1, 0], 9)
	liga.save()
	var saves := Competition.list_saves()
	assert_eq(saves.size(), 2)
	var titles := saves.map(func(s: Dictionary) -> String: return s["title"])
	assert_true(titles.any(func(t: String) -> bool: return t.begins_with("Liga · ")), str(titles))
	var lsave: Dictionary = saves.filter(func(s: Dictionary) -> bool: return s["kind"] == Competition.Kind.LEAGUE)[0]
	assert_eq(lsave["progress"], "Fecha 2 de 19")
	var back := Competition.load_saved(liga.file)
	assert_eq(back.current, 1)
	back.delete_file()
	assert_eq(Competition.list_saves().size(), 1)


## El juego guarda la configuración en la carpeta del jugador.
func test_settings_go_to_the_user_folder() -> void:
	var was := GameSettings.persist
	GameSettings.persist = true
	GameSettings.save_settings()
	GameSettings.persist = was
	assert_true(FileAccess.file_exists(UserData.config_path()))


## E3: las copas propias del Option File se juegan desde COPA.
func test_custom_cup_is_playable() -> void:
	var of := OptionFile.new()
	of.name = "Copas"
	var teams := TeamDB.division_paths("eng", "eng1").slice(0, 4)
	of.cups = [{"id": "c1", "name": "Copa Chica", "format": "knockout", "teams": teams},
		{"id": "c2", "name": "Rota", "format": "knockout", "teams": teams.slice(0, 3)}]
	TeamDB.use_option_file(of)
	var menu: Script = load("res://scripts/ui/main_menu.gd")
	var cups: Array = menu.playable_cups()
	assert_eq(cups.size(), 1, "la de 3 equipos no se puede jugar")
	assert_eq(cups[0]["name"], "Copa Chica")
	var c := Competition.create_cup(teams as Array[String], 0, 3)
	assert_eq(c.round_name(), "Semifinales")
