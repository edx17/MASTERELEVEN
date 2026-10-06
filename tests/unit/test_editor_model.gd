extends GutTest
## E2: lógica del Editor (jugadores y planteles) sobre el Option File.

var _root := ""
var m: EditorModel
const BOCA := "db:club:arg:boca"
const RIVER := "db:club:arg:river"


func before_each() -> void:
	_root = ProjectSettings.globalize_path("user://test_editor_%d" % randi())
	UserData.root_override = _root
	UserData.ensure_dirs()
	var of := OptionFile.new()
	of.name = "Editor Test"
	m = EditorModel.new(of)


func after_each() -> void:
	TeamDB.use_option_file(null)
	UserData.root_override = ""


func test_generated_squad_becomes_editable_data() -> void:
	var list := m.players(BOCA)
	assert_eq(list.size(), 23)
	assert_true((list[0] as Dictionary).has("a"))
	assert_eq(String(list[0]["pos"]), "GK")


func test_edit_one_player_and_undo() -> void:
	m.set_player([BOCA, 9], {"n": "Edinson Prueba", "num": 7, "a": {"speed": 91}, "boots": 3})
	var t := TeamDB.load_team(BOCA)
	var p: PlayerData = t.players.filter(func(x: PlayerData) -> bool: return x.player_name == "Edinson Prueba")[0]
	assert_eq(p.speed, 91)
	assert_eq(p.number, 7)
	assert_eq(p.boots, 3)
	assert_true(m.dirty)
	m.undo()
	assert_eq(TeamDB.load_team(BOCA).players.filter(func(x: PlayerData) -> bool: return x.player_name == "Edinson Prueba").size(), 0)


func test_mass_edit_whole_division() -> void:
	var paths := TeamDB.division_paths("arg", "arg1")
	var rows := m.search(paths, "", PlayerData.Position.FW)
	assert_gt(rows.size(), 30)
	var refs := rows.map(func(r: Dictionary) -> Array: return r["ref"])
	var before := int(rows[0]["d"]["a"]["speed"])
	var n := m.mass_edit(refs, "speed", "+", 5)
	assert_eq(n, refs.size())
	assert_eq(int(m.player(refs[0])["a"]["speed"]), mini(before + 5, 99))
	m.mass_edit(refs, "boots", "=", 2)
	assert_eq(int(m.player(refs[3])["boots"]), 2)


func test_add_remove_transfer_and_order() -> void:
	m.remove_player([BOCA, 22])
	assert_eq(m.players(BOCA).size(), 22)
	var ref := m.add_player(BOCA, {"n": "Pibe Nuevo", "pos": "CF"})
	assert_eq(m.players(BOCA).size(), 23)
	for i in EditorModel.MAX_SQUAD - 23:
		m.add_player(RIVER)
	assert_eq(m.players(RIVER).size(), EditorModel.MAX_SQUAD)
	assert_eq(m.add_player(RIVER).size(), 0, "no más de 40")
	var moved := m.transfer(ref, RIVER)
	assert_eq(moved.size(), 0, "River completo: no entra")
	m.remove_player([RIVER, EditorModel.MAX_SQUAD - 1])
	moved = m.transfer(ref, RIVER)
	assert_eq(moved[0], RIVER)
	assert_eq(m.player(moved)["n"], "Pibe Nuevo")
	assert_eq(m.players(BOCA).size(), 22)
	var up := m.move_player(moved, -1)
	assert_eq(up[1], moved[1] - 1)


func test_save_and_reload_from_disk() -> void:
	m.set_team(BOCA, {"name": "Boca (editado)", "stadium": "Bombonera"})
	m.set_player([BOCA, 0], {"n": "Arquero Editado"})
	assert_true(m.save())
	assert_false(m.dirty)
	TeamDB.use_option_file(OptionFile.load_named("Editor Test"))
	var t := TeamDB.load_team(BOCA)
	assert_eq(t.team_name, "Boca (editado)")
	assert_eq(t.players[0].player_name, "Arquero Editado")
	TeamDB.use_option_file(null)
	assert_eq(TeamDB.load_team(BOCA).team_name, "Boca Juniors", "la base intacta")


## E3: convocatoria, selección nueva y borrada.
func test_nations_call_up_new_and_delete() -> void:
	var arg := TeamDB.nation_path("arg")
	m.remove_player([arg, 22])
	var star: Dictionary = m.player([BOCA, 9]).duplicate(true)
	star["n"] = "Convocado de Boca"
	var ref := m.call_up(arg, star)
	assert_eq(m.player(ref)["n"], "Convocado de Boca")
	var nueva := m.new_nation("Groenlandia", "GRL")
	assert_true(TeamDB.exists(nueva))
	assert_eq(TeamDB.load_team(nueva).players.size(), 23)
	m.delete_nation(TeamDB.nation_path("chn"))
	assert_false(TeamDB.exists(TeamDB.nation_path("chn")))
	assert_eq(TeamDB.nations().size(), 59, "59 + 1 nueva - 1 borrada")


## E3: mover un club de división, club nuevo y sacar un club.
func test_leagues_move_new_and_remove_clubs() -> void:
	m.move_club("arg", "arg2", "arg1", "colon")
	assert_true(TeamDB.division_paths("arg", "arg1").has(TeamDB.club_path("arg", "colon")), "ascendido")
	assert_false(TeamDB.division_paths("arg", "arg2").has(TeamDB.club_path("arg", "colon")))
	var path := m.new_club("arg", "arg4", "Club Atlético Mi Barrio", "CMB")
	assert_true(TeamDB.division_paths("arg", "arg4").has(path))
	var t := TeamDB.load_team(path)
	assert_eq(t.team_name, "Club Atlético Mi Barrio")
	assert_eq(t.players.size(), 23)
	m.remove_club("arg", "arg4", "lugano")
	assert_eq(TeamDB.division_paths("arg", "arg4").size(), 24, "24 + 1 nuevo - 1 sacado")
	m.undo()
	assert_eq(TeamDB.division_paths("arg", "arg4").size(), 25)


## E3: copas propias.
func test_custom_cups() -> void:
	var teams := TeamDB.division_paths("eng", "eng1").slice(0, 8)
	var i := m.add_cup("Copa de la Liga", "knockout", teams)
	assert_eq(EditorModel.cup_valid(m.option_file.cups[i]), "")
	m.set_cup(i, {"teams": teams.slice(0, 6)})
	assert_ne(EditorModel.cup_valid(m.option_file.cups[i]), "", "6 no sirve para eliminación")
	m.set_cup(i, {"format": "league"})
	assert_eq(EditorModel.cup_valid(m.option_file.cups[i]), "")
	m.save()
	assert_eq(OptionFile.load_named("Editor Test").cups.size(), 1)
	m.remove_cup(i)
	assert_eq(m.option_file.cups.size(), 0)


## E4: plantilla PNG de la camiseta: se exporta con el diseño, se importa al
## Option File y el equipo la usa en el partido.
func test_kit_template_round_trip() -> void:
	var img := KitTemplate.render(Color.RED, Color.WHITE, Color.BLACK, 1, Color.BLUE, 256)
	assert_eq(img.get_width(), 256)
	# Torso a rayas: hay rojo y azul en la franja del torso.
	var reds := 0
	var blues := 0
	for x in range(0, 128, 2):
		var c := img.get_pixel(x, 64)
		if c.r > 0.8 and c.b < 0.2:
			reds += 1
		elif c.b > 0.8 and c.r < 0.2:
			blues += 1
	assert_gt(reds, 10)
	assert_gt(blues, 10)
	assert_eq(img.get_pixel(32, 160), Color.WHITE, "short")
	DirAccess.make_dir_recursive_absolute(m.option_file.kits_dir())
	var f := m.option_file.kits_dir().path_join("boca_titular.png")
	img.save_png(f)
	m.set_team(BOCA, {"home_tex": "boca_titular.png"})
	var t := TeamDB.load_team(BOCA)
	assert_not_null(t.kit_texture(0))
	assert_null(t.kit_texture(1))
	GameSettings.home_team_path = BOCA
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	var mc: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(mc)
	mc.set_physics_process(false)
	assert_not_null(mc.teams[0].kit_texture, "el partido usa la camiseta pintada")
	GameSettings.home_team_path = GameSettings.DEFAULT_HOME


## Liga Master: cuántos bajan de cada división (se puede deshacer).
func test_relegation_rule() -> void:
	assert_eq(TeamDB.relegation_count("arg", 0), 2)
	m.set_relegation("arg", "arg1", 3)
	assert_eq(TeamDB.relegation_count("arg", 0), 3)
	m.undo()
	assert_eq(TeamDB.relegation_count("arg", 0), 2)


## Escudo propio: un PNG en la carpeta de camisetas del Option File.
func test_imported_crest() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.1, 0.1))
	DirAccess.make_dir_recursive_absolute(m.option_file.kits_dir())
	img.save_png(m.option_file.kits_dir().path_join("boca_escudo.png"))
	assert_null(TeamDB.load_team(BOCA).crest, "sin escudo: el generado")
	m.set_team(BOCA, {"crest": "boca_escudo.png"})
	var t := TeamDB.load_team(BOCA)
	assert_not_null(t.crest)
	assert_eq(t.crest.get_width(), 64)
