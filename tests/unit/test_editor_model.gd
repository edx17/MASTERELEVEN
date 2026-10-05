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
	assert_eq(m.add_player(BOCA).size(), 0, "no más de 23")
	var moved := m.transfer(ref, RIVER)
	assert_eq(moved.size(), 0, "River completo: no entra")
	m.remove_player([RIVER, 22])
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
