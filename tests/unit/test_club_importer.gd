extends GutTest
## Importar listas de clubes (nombre, división, estadio) al Option File.

const CSV := "res://tests/fixtures/clubes_argentina_2026.csv"

var _root := ""
var m: EditorModel


func before_each() -> void:
	_root = ProjectSettings.globalize_path("user://test_clubs_%d" % randi())
	UserData.root_override = _root
	UserData.ensure_dirs()
	var of := OptionFile.new()
	of.name = "Clubes Test"
	m = EditorModel.new(of)


func after_each() -> void:
	TeamDB.use_option_file(null)
	UserData.root_override = ""


func _plan() -> Array[Dictionary]:
	return ClubImporter.analyze(SquadImporter.read_csv(CSV))


func _row(plan: Array, name: String, division: String, nth := 0) -> Dictionary:
	var found := plan.filter(func(e: Dictionary) -> bool: return e["name"] == name and e["division"] == division)
	return found[nth] if nth < found.size() else {}


func test_detects_club_lists() -> void:
	assert_true(ClubImporter.is_club_list(SquadImporter.read_csv(CSV)))
	assert_eq(ClubImporter.find_division("Primera Division"), ["arg", "arg1"])
	assert_eq(ClubImporter.find_division("Primera B Metropolitana"), ["arg", "arg3"])
	assert_eq(ClubImporter.find_division("Torneo Promocional Amateur"), [])


func test_matches_by_name_and_stadium() -> void:
	var plan := _plan()
	assert_eq(_row(plan, "Boca", "arg1")["choice"], "boca")
	assert_eq(_row(plan, "Newell´s", "arg1")["choice"], "newells")
	assert_eq(_row(plan, "Velez", "arg1")["choice"], "velez")
	# Dos "Estudiantes" en Primera: los separa el estadio.
	var ids := [_row(plan, "Estudiantes", "arg1", 0)["choice"], _row(plan, "Estudiantes", "arg1", 1)["choice"]]
	assert_true(ids.has("estrc") and ids.has("estudiantes"), str(ids))
	var gims := [_row(plan, "Gimnasia", "arg1", 0)["choice"], _row(plan, "Gimnasia", "arg1", 1)["choice"]]
	assert_true(gims.has("gimmendoza") and gims.has("gimnasia"), str(gims))
	assert_eq(_row(plan, "Racing", "arg2")["choice"], "racingcba")
	assert_eq(_row(plan, "Central Cordoba", "arg1")["choice"], "centralcba")
	# Sin estadio que desempate: queda para elegir.
	assert_eq(_row(plan, "Gimnasia", "arg2")["status"], "doubt")
	var s := ClubImporter.summary(plan)
	gut.p("Resumen: %s" % s)
	for e in plan:
		if e["status"] != "match":
			gut.p("  %s | %s | %s | %s" % [e["status"], e["name"], e["division_name"], e["note"]])


func test_apply_builds_divisions_and_undo() -> void:
	var plan := _plan()
	for e in plan:
		if e["choice"] == "":
			e["choice"] = ClubImporter.NEW
	var res := m.import_clubs(plan)
	assert_eq(int(res["divisions"]), 4)
	assert_eq(TeamDB.division_paths("arg", "arg1").size(), 30)
	assert_true(TeamDB.division_paths("arg", "arg2").has(TeamDB.club_path("arg", "godoycruz")), "descendido")
	assert_true(TeamDB.division_paths("arg", "arg1").has(TeamDB.club_path("arg", "estrc")), "ascendido")
	assert_eq(String(TeamDB.club("arg", "boca")[0]["stadium"]), "Alberto J. Armando \"La Bombonera\"")
	# Ningún club en dos divisiones.
	var seen := {}
	for d in TeamDB.country("arg")["divisions"]:
		for cl in d["clubs"]:
			assert_false(seen.has(cl["id"]), "repetido: %s" % cl["id"])
			seen[cl["id"]] = true
	# Un club nuevo tiene plantel generado.
	var nuevo: Array = plan.filter(func(e: Dictionary) -> bool: return e["status"] == "new")
	assert_gt(nuevo.size(), 0)
	m.undo()
	assert_true(TeamDB.division_paths("arg", "arg1").has(TeamDB.club_path("arg", "godoycruz")))


func test_squad_import_ignores_club_lists() -> void:
	DirAccess.copy_absolute(ProjectSettings.globalize_path(CSV), UserData.import_dir().path_join("clubes.csv"))
	var res := SquadImporter.new().import_folder(UserData.import_dir(), m.option_file)
	assert_eq(int(res["files"]), 0)
