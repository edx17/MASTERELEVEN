extends GutTest
## Importar planteles con revisión: emparejar clubes del CSV (abreviaturas del
## ascenso, alias recordados), crear clubes, ligas y países que faltan,
## Sub-20, libres y selecciones nuevas del catálogo.

const HEADER := "short_name,club_name,nationality_name,player_positions,overall,league_name,seleccion"

var of: OptionFile


func before_each() -> void:
	of = OptionFile.new()
	of.name = "Revisión"
	TeamDB.use_option_file(of)


func after_each() -> void:
	TeamDB.use_option_file(null)


## Filas de un club: n jugadores (2 arqueros, el resto repartido).
func _club_rows(club: String, league: String, n: int, nat := "Argentina", prefix := "", marked := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pos := ["GK", "GK", "CB", "CB", "RB", "LB", "CM", "CDM", "CAM", "RM", "LM", "ST", "ST", "CB", "CM", "RW"]
	for i in n:
		out.append({"short_name": "%s%s %d" % [prefix, club.substr(0, 4), i], "club_name": club, "nationality_name": nat,
			"player_positions": pos[i % pos.size()], "overall": str(70 - i % 10), "league_name": league, "seleccion": marked})
	return out


func _entry(plan: Array, name: String) -> Dictionary:
	for e in plan:
		if e["name"] == name:
			return e
	return {}


func _club_named(cid: String, name: String) -> String:
	for d in TeamDB.country(cid)["divisions"]:
		for cl in d["clubs"]:
			if cl["name"] == name:
				return String(cl["id"])
	return ""


func test_ascenso_names_and_abbreviations_match() -> void:
	var rows: Array[Dictionary] = []
	for c in ["Talleres (R.E)", "Mitre (Santiago)", "J.J. Urquiza", "San Martín (Tucumán)", "Brown (Adrogué)", "Lugano"]:
		rows.append_array(_club_rows(c, "Primera B", 3))
	var plan := SquadImporter.plan_rows(rows, of)
	var want := {"Talleres (R.E)": "Talleres de Remedios de Escalada", "Mitre (Santiago)": "Mitre (Santiago del Estero)",
		"J.J. Urquiza": "J. J. Urquiza", "San Martín (Tucumán)": "San Martín de Tucumán",
		"Brown (Adrogué)": "Brown de Adrogué", "Lugano": "Club Lugano"}
	for k in want:
		var e := _entry(plan, k)
		assert_eq(e["status"], "match", k)
		assert_eq(e["choice"], _club_named("arg", want[k]), k)
		assert_eq(e["division"], "arg3", "Primera B es la B Metropolitana")


func test_csv_division_is_rebuilt_with_moves_and_new_clubs() -> void:
	var rows: Array[Dictionary] = []
	rows.append_array(_club_rows("Godoy Cruz", "Primera B Nacional", 34))
	rows.append_array(_club_rows("Gimnasia (Jujuy)", "Primera B Nacional", 20))
	var plan := SquadImporter.plan_rows(rows, of)
	assert_eq(_entry(plan, "Gimnasia (Jujuy)")["status"], "new")
	var imp := SquadImporter.new()
	var res := imp.apply_plan(plan, rows, of)
	assert_eq(res["new_clubs"], 1)
	var nac: Array = TeamDB.country("arg")["divisions"][1]["clubs"]
	assert_eq(nac.size(), 2, "la división queda como en el CSV")
	var godoy := _club_named("arg", "Godoy Cruz")
	assert_eq(TeamDB.club("arg", godoy)[1]["id"], "arg2", "Godoy Cruz bajó")
	assert_eq(TeamDB.load_team(TeamDB.club_path("arg", godoy)).players.size(), 34, "plantel de 34 (hasta 40)")
	assert_eq(String(of.club_alias.get("gimnasia (jujuy)", "")).get_slice(":", 0), "arg")


func test_alias_is_remembered() -> void:
	var rows := _club_rows("Estudiantes", "Primera B Nacional", 5)
	var plan := SquadImporter.plan_rows(rows, of)
	var e := _entry(plan, "Estudiantes")
	assert_eq(e["status"], "doubt", "hay varios Estudiantes")
	var rc := _club_named("arg", "Estudiantes de Río Cuarto")
	SquadImporter.plan_pick(e, "arg", rc)
	SquadImporter.new().apply_plan(plan, rows, of)
	var again := _entry(SquadImporter.plan_rows(rows, of), "Estudiantes")
	assert_eq(again["status"], "match", "la segunda vez ya sabe cuál es")
	assert_eq(again["choice"], rc)


func test_unknown_league_creates_country_and_division() -> void:
	var rows := _club_rows("Paris Saint-Germain", "Ligue 1", 25, "Francia")
	var plan := SquadImporter.plan_rows(rows, of)
	var e := _entry(plan, "Paris Saint-Germain")
	assert_eq(e["status"], "new")
	var res := SquadImporter.new().apply_plan(plan, rows, of)
	assert_eq(res["clubs"], 1)
	var fra := TeamDB.country("fra")
	assert_false(fra.is_empty(), "se creó Francia")
	assert_eq(fra["divisions"][0]["name"], "Ligue 1")
	var t := TeamDB.load_team(TeamDB.club_path("fra", fra["divisions"][0]["clubs"][0]["id"]))
	assert_eq(t.players.size(), 25)
	# Sobrevive al guardar y cargar el Option File.
	var back := OptionFile.from_dict(JSON.parse_string(JSON.stringify(of.to_dict())))
	TeamDB.use_option_file(back)
	assert_eq(TeamDB.country("fra")["divisions"][0]["clubs"].size(), 1)


func test_youth_free_agents_and_national_lists() -> void:
	var rows: Array[Dictionary] = []
	rows.append_array(_club_rows("River Plate", "Copa LPF Proyección", 18, "Argentina", "Pibe "))
	rows.append_array(_club_rows("Libre", "Primera B", 4, "Argentina", "Suelto "))
	rows.append_array(_club_rows("Club Inexistente FC", "Copa del Mundo", 18, "Gales", "Galés ", "Gales"))
	var plan := SquadImporter.plan_rows(rows, of)
	assert_eq(_entry(plan, "River Plate")["kind"], "youth")
	assert_eq(_entry(plan, "Libre")["choice"], SquadImporter.FREE)
	assert_eq(_entry(plan, "Club Inexistente FC")["choice"], SquadImporter.FREE, "sin liga no se inventa el club: queda libre")
	var res := SquadImporter.new().apply_plan(plan, rows, of)
	assert_eq(res["youth"], 1)
	var river := TeamDB.club("arg", "river")
	assert_eq((river[0]["youth"] as Array).size(), 18, "la Sub-20 de River")
	assert_false((river[0].get("players", []) as Array).any(func(p: Dictionary) -> bool: return String(p["n"]).begins_with("Pibe")),
		"los pibes no van a Primera")
	assert_eq(of.free_agents.size(), 4 + 18, "los 4 libres y los 18 galeses sin club")
	var wal := TeamDB.nation("wal")
	assert_false(wal.is_empty(), "Gales se crea del catálogo")
	assert_eq((wal["players"] as Array).size(), 18)
	assert_eq(String(wal["home"]).get_slice("/", 0), "c8102e")


func test_catalog_flags_and_names() -> void:
	assert_gt(NationCatalog.entries().size(), 100)
	for n in NationCatalog.entries():
		var img := FlagPainter.image(n["flag"])
		assert_not_null(img, n["id"])
		assert_true(TeamDB.parse_kit(String(n["home"])).has("shirt"), n["id"])
	assert_eq(SquadImporter.nation_id_of("República Checa"), "cze")
	assert_eq(SquadImporter.nation_id_of("Bosnia-Herzegovina"), "bih")
	assert_eq(SquadImporter.nation_id_of("Congo"), "cgo")
	assert_eq(SquadImporter.nation_id_of("RD del Congo"), "cod")
	assert_eq(SquadImporter.nation_id_of("Inglaterra"), "eng")
