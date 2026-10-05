extends Control
## Editor de Master Eleven (E2): Jugadores, Equipos e Importar. Se abre como
## programa aparte ("MasterEleven Editor.exe") o desde el menú del juego
## (EDITOR). Todo se guarda en el Option File elegido arriba; la base del
## juego no se toca.
##
## Pensado para mouse y teclado: Ctrl+S guarda, Ctrl+Z deshace; en la tabla
## de jugadores se eligen varios con Ctrl / Shift para la edición masiva.

const GAME_SCENE := "res://scenes/ui/main_menu.tscn"
const LINES := ["Todos los puestos", "Arqueros", "Defensores", "Volantes", "Delanteros"]
const CODES := ["GK", "CB", "LB", "RB", "DMF", "CMF", "LMF", "RMF", "AMF", "WG", "CF"]
const FEET := ["Diestro", "Zurdo", "Ambidiestro"]
const FEET_CODES := ["R", "L", "B"]
const COLUMNS := ["Equipo", "N°", "Nombre", "Puesto", "Pie", "Edad", "Altura", "Nacionalidad", "Media"]
## Campos del aspecto: [clave en los datos, nombre, opciones (índice = valor)].
const LOOK_FIELDS := [
	["build", "Físico", ["normal", "corpulento", "delgado", "alto", "bajo", "robusto", "musculoso"]],
	["skin", "Piel", ["A clara", "B trigueña", "C oscura", "D muy oscura"]],
	["hair", "Peinado", []],
	["hc", "Color de pelo", []],
	["fh", "Barba / bigote", []],
	["boots", "Botines", []],
]

var model: EditorModel

var _of_select: OptionButton
var _status: Label
var _undo_btn: Button
var _tabs: TabContainer
var _groups: Array[Dictionary] = []

# Jugadores
var _p_group: OptionButton
var _p_team: OptionButton
var _p_line: OptionButton
var _p_search: LineEdit
var _tree: Tree
var _rows: Array = []
var _form_box: VBoxContainer
var _sel_label: Label

# Equipos
var _t_group: OptionButton
var _t_list: ItemList
var _t_paths: Array[String] = []
var _t_form: VBoxContainer
var _t_roster: ItemList
var _t_current := ""

# Importar
var _imp_text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	var th := Theme.new()
	th.default_font_size = 15
	theme = th
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_groups = TeamSelect.build_groups().filter(func(g: Dictionary) -> bool: return g["kind"] != "we")
	var of := _load_active()
	model = EditorModel.new(of)
	model.changed.connect(_on_changed)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10
	root.offset_right = -10
	root.offset_top = 8
	root.offset_bottom = -8
	add_child(root)
	root.add_child(_top_bar())
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	_tabs.add_child(_players_tab())
	_tabs.add_child(_teams_tab())
	_tabs.add_child(_import_tab())
	# Barra de estado abajo: Option File, cambios sin guardar y avisos.
	root.add_child(_status)
	_refresh_of_list()
	_fill_group(_p_group)
	_fill_group(_t_group)
	_on_p_group(0)
	_on_t_group(0)
	_update_status()


func _load_active() -> OptionFile:
	var of: OptionFile = null
	if GameSettings.active_optionfile != "":
		of = OptionFile.load_named(GameSettings.active_optionfile)
	if of == null:
		of = OptionFile.new()
		of.name = "Mi Option File"
		var existing := OptionFile.load_named(of.name)
		if existing != null:
			of = existing
	return of


# --- Barra de arriba ----------------------------------------------------------------

func _top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "MASTER ELEVEN · EDITOR"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	bar.add_child(title)
	bar.add_child(_spacer(20))
	bar.add_child(_lbl("Option File:"))
	_of_select = OptionButton.new()
	_of_select.custom_minimum_size.x = 240
	_of_select.item_selected.connect(_on_of_selected)
	bar.add_child(_of_select)
	bar.add_child(_btn("Nuevo", _new_option_file, "Crear un Option File vacío"))
	var save := _btn("Guardar (Ctrl+S)", _save, "Guarda los cambios en el Option File")
	bar.add_child(save)
	_undo_btn = _btn("Deshacer (Ctrl+Z)", func() -> void: model.undo(), "Vuelve atrás el último cambio")
	bar.add_child(_undo_btn)
	bar.add_child(_btn("Usar en el juego", _activate_in_game, "El juego usa este Option File"))
	bar.add_child(_btn("Abrir carpeta", func() -> void: UserData.open_folder(UserData.optionfiles_dir()), "Carpeta de Option Files"))
	if GameSettings.editor_from_game:
		bar.add_child(_btn("Volver al juego", _back_to_game, ""))
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	return bar


func _refresh_of_list() -> void:
	_of_select.clear()
	var names: Array = []
	for o in OptionFile.list():
		names.append(o["name"])
	if not names.has(model.option_file.name):
		names.push_front(model.option_file.name)
	for n in names:
		_of_select.add_item(n)
	_of_select.select(names.find(model.option_file.name))


func _on_of_selected(i: int) -> void:
	var name := _of_select.get_item_text(i)
	if name == model.option_file.name:
		return
	if model.dirty:
		model.save()
	var of := OptionFile.load_named(name)
	if of == null:
		return
	_switch_model(of)


func _switch_model(of: OptionFile) -> void:
	model = EditorModel.new(of)
	model.changed.connect(_on_changed)
	_refresh_of_list()
	_on_p_group(_p_group.selected)
	_on_t_group(_t_group.selected)
	_update_status()


func _new_option_file() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Nuevo Option File"
	var le := LineEdit.new()
	le.placeholder_text = "Nombre (p. ej. Temporada 2026)"
	le.custom_minimum_size.x = 320
	dlg.add_child(le)
	dlg.confirmed.connect(func() -> void:
		var n := le.text.strip_edges()
		if n == "":
			return
		if model.dirty:
			model.save()
		var of := OptionFile.new()
		of.name = n
		of.save()
		_switch_model(of)
		dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()
	le.grab_focus()


func _save() -> void:
	if model.save():
		_status.text = "Guardado en \"%s\"." % model.option_file.name
		_refresh_of_list()
	else:
		_status.text = "No se pudo guardar."


func _activate_in_game() -> void:
	model.save()
	GameSettings.active_optionfile = model.option_file.name
	GameSettings.save_settings()
	_status.text = "El juego va a usar \"%s\"." % model.option_file.name


func _back_to_game() -> void:
	if model.dirty:
		model.save()
	GameSettings.apply_option_file()
	get_tree().change_scene_to_file(GAME_SCENE)


func _update_status() -> void:
	_undo_btn.disabled = not model.can_undo()
	var star := " *" if model.dirty else ""
	if _status.text == "" or _status.text.begins_with("Option File"):
		_status.text = "Option File: %s%s" % [model.option_file.name, star]


func _on_changed() -> void:
	_status.text = ""
	_update_status()
	_refill_players()
	if _t_current != "":
		_show_team(_t_current)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.ctrl_pressed:
		if event.keycode == KEY_S:
			_save()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z:
			model.undo()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Al cerrar la ventana no se pierde nada.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and model != null and model.dirty:
		model.save()


# --- Ayudas de interfaz ------------------------------------------------------------

static func _lbl(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


static func _btn(t: String, cb: Callable, tip: String) -> Button:
	var b := Button.new()
	b.text = t
	b.tooltip_text = tip
	b.pressed.connect(cb)
	return b


static func _spacer(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = w
	return c


func _fill_group(ob: OptionButton) -> void:
	ob.clear()
	for g in _groups:
		ob.add_item(String(g["name"]))


func _group_paths(i: int) -> Array[String]:
	var out: Array[String] = []
	if i >= 0 and i < _groups.size():
		out.assign(_groups[i]["paths"])
	return out


# --- Jugadores ------------------------------------------------------------------------

func _players_tab() -> Control:
	var tab := HSplitContainer.new()
	tab.name = "Jugadores"
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.7
	tab.add_child(left)
	var filters := HBoxContainer.new()
	left.add_child(filters)
	_p_group = OptionButton.new()
	_p_group.custom_minimum_size.x = 260
	_p_group.item_selected.connect(_on_p_group)
	filters.add_child(_p_group)
	_p_team = OptionButton.new()
	_p_team.custom_minimum_size.x = 200
	_p_team.item_selected.connect(func(_i: int) -> void: _refill_players())
	filters.add_child(_p_team)
	_p_line = OptionButton.new()
	for l in LINES:
		_p_line.add_item(l)
	_p_line.item_selected.connect(func(_i: int) -> void: _refill_players())
	filters.add_child(_p_line)
	_p_search = LineEdit.new()
	_p_search.placeholder_text = "Buscar nombre..."
	_p_search.custom_minimum_size.x = 160
	_p_search.text_changed.connect(func(_t: String) -> void: _refill_players())
	filters.add_child(_p_search)
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = COLUMNS.size()
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_MULTI
	for i in COLUMNS.size():
		_tree.set_column_title(i, COLUMNS[i])
		_tree.set_column_expand(i, i in [0, 2, 7])
	_tree.set_column_custom_minimum_width(2, 180)
	_tree.set_column_custom_minimum_width(4, 90)
	_tree.set_column_custom_minimum_width(1, 40)
	_tree.multi_selected.connect(_on_tree_selected)
	left.add_child(_tree)
	var right := ScrollContainer.new()
	right.custom_minimum_size.x = 380
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(right)
	_form_box = VBoxContainer.new()
	_form_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_form_box)
	_sel_label = _lbl("Elegí un jugador (o varios con Ctrl / Shift para editarlos juntos).")
	_sel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form_box.add_child(_sel_label)
	return tab


func _on_p_group(i: int) -> void:
	_p_team.clear()
	_p_team.add_item("Todos los equipos")
	for p in _group_paths(i):
		var e := model.entry(p)
		_p_team.add_item(String(e.get("name", p)))
	_p_team.select(0)
	_refill_players()


func _player_paths() -> Array[String]:
	var all := _group_paths(_p_group.selected)
	if _p_team.selected <= 0:
		return all
	var out: Array[String] = [all[_p_team.selected - 1]]
	return out


func _refill_players() -> void:
	if _tree == null:
		return
	var keep := _selected_refs()
	_tree.clear()
	var root := _tree.create_item()
	_rows = model.search(_player_paths(), _p_search.text, _p_line.selected - 1)
	for r in _rows:
		var d: Dictionary = r["d"]
		var it := _tree.create_item(root)
		var vals := [r["team"], str(d.get("num", "")), String(d.get("n", "")), String(d.get("pos", "")),
			FEET[maxi(FEET_CODES.find(String(d.get("ft", "R"))), 0)], str(d.get("age", "")), str(d.get("h", "")),
			String(d.get("nat", "")), str(EditorModel.overall(d))]
		for c in vals.size():
			it.set_text(c, vals[c])
		it.set_metadata(0, r["ref"])
		if keep.has(r["ref"]):
			it.select(0)
	_on_selection()


var _selecting := false


## Al tocar una celda se marca toda la fila.
func _on_tree_selected(item: TreeItem, column: int, selected: bool) -> void:
	if _selecting:
		return
	_selecting = true
	for c in COLUMNS.size():
		if c == column:
			continue
		if selected:
			item.select(c)
		else:
			item.deselect(c)
	_selecting = false
	_on_selection.call_deferred()


func _selected_refs() -> Array:
	var out: Array = []
	if _tree == null or _tree.get_root() == null:
		return out
	var it := _tree.get_next_selected(null)
	while it != null:
		out.append(it.get_metadata(0))
		it = _tree.get_next_selected(it)
	return out


func _on_selection() -> void:
	for c in _form_box.get_children():
		if c != _sel_label:
			_form_box.remove_child(c)
			c.queue_free()
	var refs := _selected_refs()
	if refs.is_empty():
		_sel_label.text = "%d jugadores. Elegí uno (o varios con Ctrl / Shift para editarlos juntos)." % _rows.size()
		return
	if refs.size() == 1:
		_sel_label.text = ""
		_player_form(refs[0])
	else:
		_sel_label.text = "%d jugadores elegidos: edición masiva." % refs.size()
		_mass_form(refs)


## Ficha de un jugador: datos, aspecto y atributos; "Aplicar" guarda en
## memoria (Ctrl+S al Option File).
func _player_form(ref: Array) -> void:
	var d := model.player(ref)
	var grid := GridContainer.new()
	grid.columns = 2
	_form_box.add_child(grid)
	var name := LineEdit.new()
	name.text = String(d.get("n", ""))
	_row(grid, "Nombre", name)
	var num := _spin(1, 99, int(d.get("num", 1)))
	_row(grid, "Dorsal", num)
	var pos := OptionButton.new()
	for c in CODES:
		pos.add_item(c)
	pos.select(maxi(CODES.find(String(d.get("pos", "CMF"))), 0))
	_row(grid, "Puesto", pos)
	var alt := LineEdit.new()
	alt.text = String(d.get("alt", ""))
	alt.placeholder_text = "otros puestos: CF,WG"
	_row(grid, "Otros puestos", alt)
	var foot := OptionButton.new()
	for f in FEET:
		foot.add_item(f)
	foot.select(maxi(FEET_CODES.find(String(d.get("ft", "R"))), 0))
	_row(grid, "Pie", foot)
	var h := _spin(155, 205, int(d.get("h", 178)))
	_row(grid, "Estatura (cm)", h)
	var age := _spin(15, 45, int(d.get("age", 24)))
	_row(grid, "Edad", age)
	var nat := LineEdit.new()
	nat.text = String(d.get("nat", ""))
	_row(grid, "Nacionalidad", nat)
	var looks := {}
	for lf in LOOK_FIELDS:
		var ob := OptionButton.new()
		ob.add_item("automático")
		for o in _look_options(lf[0], lf[2]):
			ob.add_item(o)
		ob.select(int(d.get(lf[0], -1)) + 1)
		_row(grid, lf[1], ob)
		looks[lf[0]] = ob
	_form_box.add_child(HSeparator.new())
	_form_box.add_child(_lbl("Atributos (1-99)"))
	var ag := GridContainer.new()
	ag.columns = 2
	_form_box.add_child(ag)
	var a: Dictionary = d.get("a", {})
	var attrs := {}
	for k in PlayerData.ATTRIBUTES.size():
		var key: String = PlayerData.ATTRIBUTES[k]
		ag.add_child(_lbl(PlayerData.ATTRIBUTE_NAMES[k]))
		var sp := _spin(1, 99, int(a.get(key, 50)))
		ag.add_child(sp)
		attrs[key] = sp
	var actions := HBoxContainer.new()
	_form_box.add_child(actions)
	actions.add_child(_btn("Aplicar cambios", func() -> void:
		var fields := {"n": name.text.strip_edges(), "num": int(num.value), "pos": CODES[pos.selected],
			"ft": FEET_CODES[foot.selected], "h": int(h.value), "age": int(age.value), "nat": nat.text.strip_edges(),
			"alt": alt.text.strip_edges().to_upper() if alt.text.strip_edges() != "" else null}
		for lk in looks:
			var v: int = (looks[lk] as OptionButton).selected - 1
			fields[lk] = v if v >= 0 else null
		var av := {}
		for key in attrs:
			av[key] = int((attrs[key] as SpinBox).value)
		fields["a"] = av
		model.set_player(ref, fields), ""))
	actions.add_child(_btn("Quitar del plantel", func() -> void: model.remove_player(ref), "Baja: lo saca del plantel"))
	# Pase a otro equipo.
	var tr := HBoxContainer.new()
	_form_box.add_child(tr)
	tr.add_child(_lbl("Pasar a:"))
	var dg := OptionButton.new()
	dg.custom_minimum_size.x = 150
	_fill_group(dg)
	tr.add_child(dg)
	var dt := OptionButton.new()
	dt.custom_minimum_size.x = 150
	tr.add_child(dt)
	var fill_dt := func(gi: int) -> void:
		dt.clear()
		for p in _group_paths(gi):
			dt.add_item(String(model.entry(p).get("name", p)))
	dg.item_selected.connect(fill_dt)
	dg.select(maxi(_p_group.selected, 0))
	fill_dt.call(dg.selected)
	tr.add_child(_btn("Pasar", func() -> void:
		var dest := _group_paths(dg.selected)
		if dt.selected < 0 or dt.selected >= dest.size():
			return
		var res := model.transfer(ref, dest[dt.selected])
		_status.text = "Pase hecho." if not res.is_empty() else "No se pudo: el plantel de destino está completo (23).", ""))


## Opciones del aspecto que dependen de otras tablas del juego.
static func _look_options(key: String, fixed: Array) -> Array:
	match key:
		"hair":
			return HairBuilder.NAMES
		"hc":
			return PlayerData.HAIR_COLOR_NAMES
		"fh":
			return PlayerData.FACIAL_HAIR_NAMES
		"boots":
			return PlayerData.BOOT_NAMES
	return fixed


## Edición masiva: un atributo (+, -, =) o un campo del aspecto para todos
## los elegidos.
func _mass_form(refs: Array) -> void:
	var fields: Array = []
	for k in PlayerData.ATTRIBUTES.size():
		fields.append([PlayerData.ATTRIBUTES[k], PlayerData.ATTRIBUTE_NAMES[k], []])
	for lf in LOOK_FIELDS:
		fields.append([lf[0], lf[1], _look_options(lf[0], lf[2])])
	fields.append(["nat", "Nacionalidad", []])
	var grid := GridContainer.new()
	grid.columns = 2
	_form_box.add_child(grid)
	var field := OptionButton.new()
	for f in fields:
		field.add_item(f[1])
	_row(grid, "Qué cambiar", field)
	var op := OptionButton.new()
	for o in ["sumar", "restar", "poner en"]:
		op.add_item(o)
	_row(grid, "Cómo", op)
	var val := _spin(1, 99, 5)
	_row(grid, "Valor", val)
	var choice := OptionButton.new()
	_row(grid, "Opción", choice)
	var text := LineEdit.new()
	_row(grid, "Texto", text)
	var update := func(i: int) -> void:
		var f: Array = fields[i]
		var is_attr: bool = f[0] in PlayerData.ATTRIBUTES
		op.get_parent().get_child(op.get_index() - 1).visible = is_attr
		op.visible = is_attr
		val.visible = is_attr
		val.get_parent().get_child(val.get_index() - 1).visible = is_attr
		var opts: Array = f[2]
		choice.visible = not opts.is_empty()
		choice.get_parent().get_child(choice.get_index() - 1).visible = choice.visible
		choice.clear()
		choice.add_item("automático")
		for o in opts:
			choice.add_item(o)
		text.visible = f[0] == "nat"
		text.get_parent().get_child(text.get_index() - 1).visible = text.visible
	field.item_selected.connect(update)
	update.call(0)
	_form_box.add_child(_btn("Aplicar a los %d elegidos" % refs.size(), func() -> void:
		var f: Array = fields[field.selected]
		var n := 0
		if f[0] in PlayerData.ATTRIBUTES:
			n = model.mass_edit(refs, f[0], ["+", "-", "="][op.selected], int(val.value))
		elif f[0] == "nat":
			n = model.mass_edit(refs, "nat", "=", text.text.strip_edges())
		else:
			n = model.mass_edit(refs, f[0], "=", choice.selected - 1 if choice.selected > 0 else -1)
		_status.text = "%d jugadores cambiados." % n, ""))


func _row(grid: GridContainer, caption: String, ctrl: Control) -> void:
	grid.add_child(_lbl(caption))
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(ctrl)


static func _spin(lo: int, hi: int, v: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = v
	return s


# --- Equipos ------------------------------------------------------------------------------

func _teams_tab() -> Control:
	var tab := HSplitContainer.new()
	tab.name = "Equipos"
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 300
	tab.add_child(left)
	_t_group = OptionButton.new()
	_t_group.item_selected.connect(_on_t_group)
	left.add_child(_t_group)
	_t_list = ItemList.new()
	_t_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_t_list.item_selected.connect(func(i: int) -> void: _show_team(_t_paths[i]))
	left.add_child(_t_list)
	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(right)
	_t_form = VBoxContainer.new()
	_t_form.custom_minimum_size.x = 360
	right.add_child(_t_form)
	var roster_box := VBoxContainer.new()
	roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(roster_box)
	roster_box.add_child(_lbl("Plantel (los 11 primeros son los titulares)"))
	_t_roster = ItemList.new()
	_t_roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_box.add_child(_t_roster)
	var acts := HBoxContainer.new()
	roster_box.add_child(acts)
	acts.add_child(_btn("▲ Subir", func() -> void: _roster_move(-1), "Lo pone antes (titular / suplente)"))
	acts.add_child(_btn("▼ Bajar", func() -> void: _roster_move(1), ""))
	acts.add_child(_btn("Nuevo jugador", func() -> void:
		var r := model.add_player(_t_current)
		_status.text = "Jugador agregado." if not r.is_empty() else "El plantel ya tiene 23.", "Alta"))
	acts.add_child(_btn("Quitar", func() -> void:
		var sel := _t_roster.get_selected_items()
		if not sel.is_empty():
			model.remove_player([_t_current, sel[0]]), "Baja"))
	acts.add_child(_btn("Editar en Jugadores", _edit_in_players, "Abre el plantel en la pestaña Jugadores"))
	return tab


func _on_t_group(i: int) -> void:
	_t_list.clear()
	_t_paths = _group_paths(i)
	for p in _t_paths:
		_t_list.add_item(String(model.entry(p).get("name", p)))
	if not _t_paths.is_empty():
		_t_list.select(0)
		_show_team(_t_paths[0])


func _show_team(path: String) -> void:
	_t_current = path
	for c in _t_form.get_children():
		_t_form.remove_child(c)
		c.queue_free()
	var e := model.entry(path)
	var grid := GridContainer.new()
	grid.columns = 2
	_t_form.add_child(grid)
	var name := LineEdit.new()
	name.text = String(e.get("name", ""))
	_row(grid, "Nombre", name)
	var short := LineEdit.new()
	short.text = String(e.get("short", ""))
	short.max_length = 3
	_row(grid, "Sigla (3)", short)
	var stadium := LineEdit.new()
	stadium.text = String(e.get("stadium", ""))
	_row(grid, "Estadio", stadium)
	var cap := _spin(0, 200000, int(e.get("cap", 0)))
	cap.step = 500
	_row(grid, "Capacidad", cap)
	var form := OptionButton.new()
	var fnames: Array = FormationLibrary.DEFINITIONS.keys()
	for f in fnames:
		form.add_item(f)
	form.select(maxi(fnames.find(String(e.get("formation", "4-4-2"))), 0))
	_row(grid, "Formación", form)
	var home := LineEdit.new()
	home.text = String(e.get("home", ""))
	home.tooltip_text = "camiseta/pantalón/medias|diseño|color (hex). Diseños: stripes, pinstripes, hoops, halves, sash, band, v, checks"
	_row(grid, "Titular", home)
	var away := LineEdit.new()
	away.text = String(e.get("away", ""))
	away.tooltip_text = home.tooltip_text
	_row(grid, "Suplente", away)
	_t_form.add_child(_btn("Aplicar datos del equipo", func() -> void:
		model.set_team(path, {"name": name.text.strip_edges(), "short": short.text.strip_edges().to_upper(),
			"stadium": stadium.text.strip_edges(), "cap": int(cap.value), "formation": fnames[form.selected],
			"home": home.text.strip_edges(), "away": away.text.strip_edges()})
		_status.text = "Equipo actualizado.", ""))
	var kit_note := _lbl("Las camisetas con vista 3D y plantillas llegan en la etapa E4.")
	kit_note.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	kit_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_t_form.add_child(kit_note)
	_t_roster.clear()
	var list: Array = e.get("players", [])
	for i in list.size():
		var d: Dictionary = list[i]
		_t_roster.add_item("%s%2d  %-4s %s" % ["★ " if i < 11 else "   ", int(d.get("num", 0)), String(d.get("pos", "")), String(d.get("n", ""))])


func _roster_move(delta: int) -> void:
	var sel := _t_roster.get_selected_items()
	if sel.is_empty():
		return
	var ref := model.move_player([_t_current, sel[0]], delta)
	_t_roster.select(ref[1])


func _edit_in_players() -> void:
	_tabs.current_tab = 0
	_p_group.select(_t_group.selected)
	_on_p_group(_t_group.selected)
	var i := _group_paths(_t_group.selected).find(_t_current)
	_p_team.select(i + 1)
	_refill_players()


# --- Importar -------------------------------------------------------------------------------

func _import_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Importar"
	tab.add_theme_constant_override("separation", 10)
	var info := _lbl("1. Abrí la carpeta de importar y copiá ahí tus CSV (EA FC / SoFIFA, Transfermarkt o tu planilla).\n" +
		"2. Apretá Importar: los planteles van al Option File de arriba (la base no se toca).\n" +
		"3. Revisá el resumen: los clubes que no se encontraron hay que corregirlos en el CSV o en la pestaña Equipos.")
	tab.add_child(info)
	var row := HBoxContainer.new()
	tab.add_child(row)
	row.add_child(_btn("Abrir carpeta de importar", func() -> void: UserData.open_folder(UserData.import_dir()), ""))
	row.add_child(_btn("Importar", _import, ""))
	_imp_text = _lbl("")
	_imp_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(_imp_text)
	return tab


func _import() -> void:
	var imp := SquadImporter.new()
	var res := imp.import_folder(UserData.import_dir(), model.option_file)
	if int(res["files"]) == 0:
		_imp_text.text = "No hay archivos CSV en %s" % UserData.import_dir()
		return
	var lines := ["%d archivo(s), %d filas: %d jugadores en %d clubes, %d selecciones." % [res["files"], res["rows"],
		res["players"], res["clubs"], res["nations"]], "Guardado en \"%s\"." % model.option_file.name]
	lines.append_array(imp.report)
	_imp_text.text = "\n".join(lines)
	_switch_model(model.option_file)
