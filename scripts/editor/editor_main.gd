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
	# Los desplegables no se ensanchan hasta su opción más larga (si no, los
	# nombres de las divisiones empujan los paneles fuera de la ventana).
	get_tree().node_added.connect(_on_node_added)
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
	_tabs.add_child(_nations_tab())
	_tabs.add_child(_leagues_tab())
	_tabs.add_child(_cups_tab())
	_tabs.add_child(_kits_tab())
	_tabs.add_child(_import_tab())
	# Barra de estado abajo: Option File, cambios sin guardar y avisos.
	root.add_child(_status)
	_refresh_of_list()
	_fill_group(_p_group)
	_fill_group(_t_group)
	_on_p_group(0)
	_on_t_group(0)
	_refresh_nations()
	_refresh_leagues()
	_refresh_cups()
	if _k_current != "":
		_show_kit(_k_current)
	_fill_group(_k_group)
	_on_k_group(0)
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


func _on_node_added(n: Node) -> void:
	if n is OptionButton and is_ancestor_of(n):
		(n as OptionButton).fit_to_longest_item = false
		(n as OptionButton).clip_text = true
		if (n as OptionButton).custom_minimum_size.x < 120:
			(n as OptionButton).custom_minimum_size.x = 120


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
	_regroup()
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
	_refresh_nations()
	_refresh_leagues()
	_refresh_cups()


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
	var tab := HBoxContainer.new()
	tab.name = "Jugadores"
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.9
	tab.add_child(left)
	# Filtros: si no entran en un renglón, pasan al siguiente.
	var filters := HFlowContainer.new()
	left.add_child(filters)
	_p_group = OptionButton.new()
	_p_group.custom_minimum_size.x = 220
	_p_group.clip_text = true
	_p_group.item_selected.connect(_on_p_group)
	filters.add_child(_p_group)
	_p_team = OptionButton.new()
	_p_team.custom_minimum_size.x = 170
	_p_team.clip_text = true
	_p_team.item_selected.connect(func(_i: int) -> void: _refill_players())
	filters.add_child(_p_team)
	_p_line = OptionButton.new()
	_p_line.custom_minimum_size.x = 170
	for l in LINES:
		_p_line.add_item(l)
	_p_line.item_selected.connect(func(_i: int) -> void: _refill_players())
	filters.add_child(_p_line)
	_p_search = LineEdit.new()
	_p_search.placeholder_text = "Buscar nombre..."
	_p_search.custom_minimum_size.x = 130
	_p_search.text_changed.connect(func(_t: String) -> void: _refill_players())
	filters.add_child(_p_search)
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = COLUMNS.size()
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_MULTI
	# Anchos chicos: la tabla se estira pero deja lugar a la ficha.
	var widths := [90, 34, 140, 46, 70, 40, 50, 90, 46]
	for i in COLUMNS.size():
		_tree.set_column_title(i, COLUMNS[i])
		_tree.set_column_expand(i, i in [0, 2, 7])
		_tree.set_column_custom_minimum_width(i, widths[i])
		_tree.set_column_clip_content(i, true)
	_tree.multi_selected.connect(_on_tree_selected)
	left.add_child(_tree)
	var right := ScrollContainer.new()
	right.custom_minimum_size.x = 400
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
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
	# Vista 3D: el jugador con su aspecto, botines y la camiseta del equipo.
	var prev := KitPreview.new()
	prev.custom_minimum_size = Vector2(220, 300)
	_form_box.add_child(prev)
	var pd := TeamDB.player_from_dict(d, "prev", 0)
	var colors := _kit_colors(ref[0], 0)
	colors.merge(pd.look(), true)
	colors["build"] = int(pd.visual_build())
	colors["body"] = pd.body_params()
	if pd.hair >= 0:
		colors["hair_style"] = pd.hair
	prev.show_player(colors, _kit_tex(ref[0], 0))
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
	dg.clip_text = true
	_fill_group(dg)
	tr.add_child(dg)
	var dt := OptionButton.new()
	dt.custom_minimum_size.x = 120
	dt.clip_text = true
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
	# Que las opciones largas no ensanchen el panel.
	if ctrl is OptionButton:
		(ctrl as OptionButton).clip_text = true
		ctrl.custom_minimum_size.x = maxf(ctrl.custom_minimum_size.x, 140)
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


## Vuelve a leer los grupos (selecciones nuevas, clubes que cambiaron de
## división) sin perder la elección de los filtros.
func _regroup() -> void:
	_groups = TeamSelect.build_groups().filter(func(g: Dictionary) -> bool: return g["kind"] != "we")
	for ob in [_p_group, _t_group, _k_group]:
		if ob == null:
			continue
		var keep: int = ob.selected
		_fill_group(ob)
		ob.select(clampi(keep, 0, _groups.size() - 1))


# --- Selecciones -----------------------------------------------------------------------------

var _n_list: ItemList
var _n_paths: Array[String] = []
var _n_form: VBoxContainer
var _n_current := ""


func _nations_tab() -> Control:
	var tab := HSplitContainer.new()
	tab.name = "Selecciones"
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 260
	tab.add_child(left)
	_n_list = ItemList.new()
	_n_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_n_list.fixed_icon_size = Vector2i(36, 24)
	_n_list.item_selected.connect(func(i: int) -> void: _show_nation(_n_paths[i]))
	left.add_child(_n_list)
	var nr := HBoxContainer.new()
	left.add_child(nr)
	var nname := LineEdit.new()
	nname.placeholder_text = "Nombre"
	nname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nr.add_child(nname)
	var nshort := LineEdit.new()
	nshort.placeholder_text = "Sigla"
	nshort.max_length = 3
	nshort.custom_minimum_size.x = 60
	nr.add_child(nshort)
	left.add_child(_btn("Nueva selección", func() -> void:
		if nname.text.strip_edges() == "":
			_status.text = "Poné el nombre de la selección."
			return
		var path := model.new_nation(nname.text.strip_edges(), nshort.text.strip_edges())
		_regroup()
		_refresh_nations()
		_show_nation(path), "Con un plantel generado que después editás"))
	left.add_child(_btn("Borrar selección", func() -> void:
		if _n_current != "":
			model.delete_nation(_n_current)
			_n_current = ""
			_regroup(), "Deja de aparecer en el juego (se puede deshacer)"))
	_n_form = VBoxContainer.new()
	_n_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(_n_form)
	return tab


func _refresh_nations() -> void:
	if _n_list == null:
		return
	_n_list.clear()
	_n_paths = TeamDB.nation_paths()
	for p in _n_paths:
		var t := TeamDB.load_team(p)
		_n_list.add_item(t.team_name, t.flag)
	if _n_current == "" and not _n_paths.is_empty():
		_n_current = _n_paths[0]
	var i := _n_paths.find(_n_current)
	if i >= 0:
		_n_list.select(i)
		_show_nation(_n_current)


func _show_nation(path: String) -> void:
	_n_current = path
	for c in _n_form.get_children():
		_n_form.remove_child(c)
		c.queue_free()
	var e := model.entry(path)
	if e.is_empty():
		return
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_n_form.add_child(cols)
	var lf := VBoxContainer.new()
	lf.custom_minimum_size.x = 360
	cols.add_child(lf)
	var grid := GridContainer.new()
	grid.columns = 2
	lf.add_child(grid)
	var name := LineEdit.new()
	name.text = String(e.get("name", ""))
	_row(grid, "Nombre", name)
	var short := LineEdit.new()
	short.text = String(e.get("short", ""))
	short.max_length = 3
	_row(grid, "Sigla", short)
	var level := _spin(40, 95, int(e.get("level", 70)))
	_row(grid, "Nivel (planteles generados)", level)
	var form := OptionButton.new()
	var fnames: Array = FormationLibrary.DEFINITIONS.keys()
	for f in fnames:
		form.add_item(f)
	form.select(maxi(fnames.find(String(e.get("formation", "4-4-2"))), 0))
	_row(grid, "Formación", form)
	var home := LineEdit.new()
	home.text = String(e.get("home", ""))
	_row(grid, "Titular", home)
	var away := LineEdit.new()
	away.text = String(e.get("away", ""))
	_row(grid, "Suplente", away)
	var wc := OptionButton.new()
	for o in ["no", "clasificada al Mundial", "repechaje"]:
		wc.add_item(o)
	wc.select(["", "q", "po"].find(String(e.get("wc", ""))))
	_row(grid, "Mundial 2026", wc)
	var flag := LineEdit.new()
	flag.text = JSON.stringify(e.get("flag", {}))
	flag.tooltip_text = "Bandera: {\"t\": \"h\" | \"v\" | \"hw\" | \"vw\" | \"nordic\" | \"cross\" | \"saltire\" | \"disc\" | \"plain\", \"c\": [colores], \"w\": [anchos], \"e\": {\"k\": \"star\", \"c\": \"ffffff\"}} (ver FlagPainter)"
	_row(grid, "Bandera", flag)
	var preview := TextureRect.new()
	preview.texture = FlagPainter.texture(e.get("flag", {}))
	preview.custom_minimum_size = Vector2(96, 64)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lf.add_child(preview)
	lf.add_child(_btn("Aplicar", func() -> void:
		var fl: Variant = JSON.parse_string(flag.text)
		var fields := {"name": name.text.strip_edges(), "short": short.text.strip_edges().to_upper(),
			"level": int(level.value), "formation": fnames[form.selected], "home": home.text.strip_edges(),
			"away": away.text.strip_edges(), "wc": ["", "q", "po"][wc.selected]}
		if fl is Dictionary:
			fields["flag"] = fl
		model.set_team(path, fields)
		_status.text = "Selección actualizada.", ""))
	# Convocatoria.
	var rf := VBoxContainer.new()
	rf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(rf)
	rf.add_child(_lbl("Convocatoria (los 11 primeros son los titulares)"))
	var roster := ItemList.new()
	roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list: Array = e.get("players", [])
	for i in list.size():
		var d: Dictionary = list[i]
		roster.add_item("%s%2d  %-4s %s" % ["★ " if i < 11 else "   ", int(d.get("num", 0)), String(d.get("pos", "")), String(d.get("n", ""))])
	rf.add_child(roster)
	var ra := HBoxContainer.new()
	rf.add_child(ra)
	ra.add_child(_btn("▲", func() -> void:
		var sel := roster.get_selected_items()
		if not sel.is_empty():
			model.move_player([path, sel[0]], -1), ""))
	ra.add_child(_btn("▼", func() -> void:
		var sel := roster.get_selected_items()
		if not sel.is_empty():
			model.move_player([path, sel[0]], 1), ""))
	ra.add_child(_btn("Desconvocar", func() -> void:
		var sel := roster.get_selected_items()
		if not sel.is_empty():
			model.remove_player([path, sel[0]]), ""))
	# Convocar desde un club.
	var cu := HBoxContainer.new()
	rf.add_child(cu)
	cu.add_child(_lbl("Convocar de:"))
	var g := OptionButton.new()
	g.custom_minimum_size.x = 200
	g.clip_text = true
	_fill_group(g)
	cu.add_child(g)
	var tm := OptionButton.new()
	tm.custom_minimum_size.x = 160
	tm.clip_text = true
	cu.add_child(tm)
	var cu2 := HBoxContainer.new()
	rf.add_child(cu2)
	var pl := OptionButton.new()
	pl.custom_minimum_size.x = 260
	cu2.add_child(pl)
	var fill_players := func(_i: int = 0) -> void:
		pl.clear()
		var paths := _group_paths(g.selected)
		if tm.selected < 0 or tm.selected >= paths.size():
			return
		for d in model.players(paths[tm.selected]):
			pl.add_item("%s (%s)" % [d.get("n", ""), d.get("pos", "")])
	var fill_teams := func(_i: int = 0) -> void:
		tm.clear()
		for p in _group_paths(g.selected):
			tm.add_item(String(model.entry(p).get("name", p)))
		fill_players.call()
	g.item_selected.connect(fill_teams)
	tm.item_selected.connect(fill_players)
	g.select(mini(1, _groups.size() - 1))
	fill_teams.call()
	cu2.add_child(_btn("Convocar", func() -> void:
		var paths := _group_paths(g.selected)
		if tm.selected < 0 or pl.selected < 0:
			return
		var d := model.player([paths[tm.selected], pl.selected])
		var r := model.call_up(path, d)
		_status.text = "Convocado." if not r.is_empty() else "La lista ya tiene 23: desconvocá a alguien.", ""))


# --- Ligas ----------------------------------------------------------------------------------

var _l_country: OptionButton
var _l_divs: ItemList
var _l_clubs: ItemList
var _l_move: OptionButton


func _leagues_tab() -> Control:
	var tab := HBoxContainer.new()
	tab.name = "Ligas"
	var c1 := VBoxContainer.new()
	c1.custom_minimum_size.x = 280
	tab.add_child(c1)
	_l_country = OptionButton.new()
	for c in TeamDB.countries():
		_l_country.add_item(String(c["name"]))
	_l_country.item_selected.connect(func(_i: int) -> void: _refresh_leagues())
	c1.add_child(_l_country)
	c1.add_child(_lbl("Divisiones"))
	_l_divs = ItemList.new()
	_l_divs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_l_divs.item_selected.connect(func(_i: int) -> void: _refresh_clubs())
	c1.add_child(_l_divs)
	var c2 := VBoxContainer.new()
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(c2)
	c2.add_child(_lbl("Clubes de la división"))
	_l_clubs = ItemList.new()
	_l_clubs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c2.add_child(_l_clubs)
	var mv := HBoxContainer.new()
	c2.add_child(mv)
	mv.add_child(_lbl("Pasar a:"))
	_l_move = OptionButton.new()
	_l_move.custom_minimum_size.x = 220
	mv.add_child(_l_move)
	mv.add_child(_btn("Pasar de división", _league_move, "Ascenso o descenso a mano"))
	mv.add_child(_btn("Sacar de la liga", func() -> void:
		var ids := _league_sel()
		if not ids.is_empty():
			model.remove_club(ids[0], ids[1], ids[2])
			_regroup(), "Deja de jugar en esta división (sus datos quedan)"))
	mv.add_child(_btn("Editar equipo", func() -> void:
		var ids := _league_sel()
		if ids.is_empty():
			return
		var path := TeamDB.club_path(ids[0], ids[2])
		_tabs.current_tab = 1
		for gi in _groups.size():
			if (_groups[gi]["paths"] as Array).has(path):
				_t_group.select(gi)
				_on_t_group(gi)
		_show_team(path), ""))
	var nc := HBoxContainer.new()
	c2.add_child(nc)
	var cname := LineEdit.new()
	cname.placeholder_text = "Nombre del club nuevo"
	cname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nc.add_child(cname)
	var cshort := LineEdit.new()
	cshort.placeholder_text = "Sigla"
	cshort.max_length = 3
	cshort.custom_minimum_size.x = 60
	nc.add_child(cshort)
	nc.add_child(_btn("Agregar club", func() -> void:
		var ids := _division_sel()
		if ids.is_empty() or cname.text.strip_edges() == "":
			_status.text = "Elegí la división y poné el nombre del club."
			return
		model.new_club(ids[0], ids[1], cname.text.strip_edges(), cshort.text.strip_edges())
		cname.text = ""
		cshort.text = ""
		_regroup(), "Club nuevo en esta división (plantel generado, editable)"))
	return tab


func _country_sel() -> Dictionary:
	var cs := TeamDB.countries()
	return cs[_l_country.selected] if _l_country.selected >= 0 and _l_country.selected < cs.size() else {}


## [país, división] elegidos.
func _division_sel() -> Array:
	var c := _country_sel()
	var sel := _l_divs.get_selected_items()
	if c.is_empty() or sel.is_empty():
		return []
	return [String(c["id"]), String(c["divisions"][sel[0]]["id"])]


## [país, división, club] elegidos.
func _league_sel() -> Array:
	var dv := _division_sel()
	var sel := _l_clubs.get_selected_items()
	if dv.is_empty() or sel.is_empty():
		return []
	var ids := model.division_ids(dv[0], dv[1])
	return [dv[0], dv[1], ids[sel[0]]] if sel[0] < ids.size() else []


func _refresh_leagues() -> void:
	if _l_divs == null:
		return
	var keep := _l_divs.get_selected_items()
	_l_divs.clear()
	_l_move.clear()
	var c := _country_sel()
	for d in c.get("divisions", []):
		_l_divs.add_item("%s (%d)" % [d["name"], (d["clubs"] as Array).size()])
		_l_move.add_item(String(d["name"]))
	if _l_divs.item_count > 0:
		_l_divs.select(keep[0] if not keep.is_empty() and keep[0] < _l_divs.item_count else 0)
	_refresh_clubs()


func _refresh_clubs() -> void:
	_l_clubs.clear()
	var dv := _division_sel()
	if dv.is_empty():
		return
	for p in TeamDB.division_paths(dv[0], dv[1]):
		_l_clubs.add_item(TeamDB.load_team(p).team_name)


func _league_move() -> void:
	var ids := _league_sel()
	var c := _country_sel()
	if ids.is_empty() or _l_move.selected < 0:
		return
	var to := String(c["divisions"][_l_move.selected]["id"])
	model.move_club(ids[0], ids[1], to, ids[2])
	_regroup()
	_status.text = "Club pasado de división."


# --- Copas --------------------------------------------------------------------------------

var _c_list: ItemList
var _c_form: VBoxContainer


func _cups_tab() -> Control:
	var tab := HSplitContainer.new()
	tab.name = "Copas"
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 280
	tab.add_child(left)
	left.add_child(_lbl("Copas propias (se juegan desde COPA en el juego)"))
	_c_list = ItemList.new()
	_c_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_c_list.item_selected.connect(func(i: int) -> void: _show_cup(i))
	left.add_child(_c_list)
	var nc := HBoxContainer.new()
	left.add_child(nc)
	var cname := LineEdit.new()
	cname.placeholder_text = "Nombre de la copa"
	cname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nc.add_child(cname)
	nc.add_child(_btn("Nueva", func() -> void:
		if cname.text.strip_edges() == "":
			return
		var i := model.add_cup(cname.text.strip_edges(), "knockout", [])
		cname.text = ""
		_c_list.select(i)
		_show_cup(i), ""))
	left.add_child(_btn("Borrar copa", func() -> void:
		var sel := _c_list.get_selected_items()
		if not sel.is_empty():
			model.remove_cup(sel[0]), ""))
	_c_form = VBoxContainer.new()
	_c_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(_c_form)
	return tab


func _refresh_cups() -> void:
	if _c_list == null:
		return
	var keep := _c_list.get_selected_items()
	_c_list.clear()
	for c in model.option_file.cups:
		var ok := EditorModel.cup_valid(c) == ""
		_c_list.add_item("%s%s (%d)" % ["" if ok else "⚠ ", c.get("name", ""), (c.get("teams", []) as Array).size()])
	if not keep.is_empty() and keep[0] < _c_list.item_count:
		_c_list.select(keep[0])
		_show_cup(keep[0])
	elif _c_form != null:
		for ch in _c_form.get_children():
			ch.queue_free()


func _show_cup(i: int) -> void:
	for ch in _c_form.get_children():
		_c_form.remove_child(ch)
		ch.queue_free()
	if i < 0 or i >= model.option_file.cups.size():
		return
	var c: Dictionary = model.option_file.cups[i]
	var grid := GridContainer.new()
	grid.columns = 2
	_c_form.add_child(grid)
	var name := LineEdit.new()
	name.text = String(c.get("name", ""))
	name.text_submitted.connect(func(t: String) -> void: model.set_cup(i, {"name": t.strip_edges()}))
	_row(grid, "Nombre (Enter)", name)
	var fmt := OptionButton.new()
	fmt.add_item("Eliminación directa (4, 8, 16 o 32)")
	fmt.add_item("Liga (todos contra todos)")
	fmt.select(0 if String(c.get("format", "knockout")) == "knockout" else 1)
	fmt.item_selected.connect(func(k: int) -> void: model.set_cup(i, {"format": ["knockout", "league"][k]}))
	_row(grid, "Formato", fmt)
	var warn := EditorModel.cup_valid(c)
	var wl := _lbl(warn if warn != "" else "Lista para jugar.")
	wl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4) if warn != "" else Color(0.6, 0.9, 0.6))
	_c_form.add_child(wl)
	var teams: Array = c.get("teams", [])
	var tl := ItemList.new()
	tl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for p in teams:
		var t := TeamDB.load_team(p)
		tl.add_item(t.team_name if t != null else String(p))
	_c_form.add_child(tl)
	_c_form.add_child(_btn("Quitar equipo", func() -> void:
		var sel := tl.get_selected_items()
		if sel.is_empty():
			return
		var nt := teams.duplicate()
		nt.remove_at(sel[0])
		model.set_cup(i, {"teams": nt}), ""))
	var add := HBoxContainer.new()
	_c_form.add_child(add)
	var g := OptionButton.new()
	_fill_group(g)
	add.add_child(g)
	var tm := OptionButton.new()
	tm.custom_minimum_size.x = 200
	add.add_child(tm)
	var fill := func(_k: int = 0) -> void:
		tm.clear()
		for p in _group_paths(g.selected):
			tm.add_item(TeamDB.load_team(p).team_name)
	g.item_selected.connect(fill)
	fill.call()
	add.add_child(_btn("Agregar", func() -> void:
		var paths := _group_paths(g.selected)
		if tm.selected < 0 or tm.selected >= paths.size() or teams.has(paths[tm.selected]):
			return
		var nt := teams.duplicate()
		nt.append(paths[tm.selected])
		model.set_cup(i, {"teams": nt}), ""))
	add.add_child(_btn("Agregar todo el grupo", func() -> void:
		var nt := teams.duplicate()
		for p in _group_paths(g.selected):
			if not nt.has(p):
				nt.append(p)
		model.set_cup(i, {"teams": nt}), ""))


# --- Camisetas -----------------------------------------------------------------------------

const PATTERN_NAMES := ["Lisa", "Rayas / bastones", "Rayas finitas", "Aros", "Mitades", "Banda diagonal",
	"Franja en el pecho", "V en el pecho", "Cuadros"]
var _k_group: OptionButton
var _k_list: ItemList
var _k_paths: Array[String] = []
var _k_form: VBoxContainer
var _k_preview: KitPreview
var _k_current := ""
var _k_kit := 0


func _kits_tab() -> Control:
	var tab := HBoxContainer.new()
	tab.name = "Camisetas"
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 260
	tab.add_child(left)
	_k_group = OptionButton.new()
	_k_group.item_selected.connect(_on_k_group)
	left.add_child(_k_group)
	_k_list = ItemList.new()
	_k_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_k_list.item_selected.connect(func(i: int) -> void: _show_kit(_k_paths[i]))
	left.add_child(_k_list)
	_k_form = VBoxContainer.new()
	_k_form.custom_minimum_size.x = 420
	tab.add_child(_k_form)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(right)
	_k_preview = KitPreview.new()
	_k_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_k_preview)
	var rot := HBoxContainer.new()
	right.add_child(rot)
	var spin := CheckBox.new()
	spin.text = "Girar"
	spin.button_pressed = true
	spin.toggled.connect(func(on: bool) -> void: _k_preview.spin = on)
	rot.add_child(spin)
	rot.add_child(_btn("Frente", func() -> void:
		_k_preview.spin = false
		spin.button_pressed = false
		_k_preview.angle = 0.0, ""))
	rot.add_child(_btn("Espalda", func() -> void:
		_k_preview.spin = false
		spin.button_pressed = false
		_k_preview.angle = PI, ""))
	return tab


func _on_k_group(i: int) -> void:
	if _k_list == null:
		return
	_k_list.clear()
	_k_paths = _group_paths(i)
	for p in _k_paths:
		_k_list.add_item(TeamDB.load_team(p).team_name)
	if not _k_paths.is_empty():
		_k_list.select(0)
		_show_kit(_k_paths[0])


## Colores del uniforme `kit` de un equipo para el modelo (como Footballer).
func _kit_colors(path: String, kit: int) -> Dictionary:
	var t := TeamDB.load_team(path)
	if t == null:
		return {}
	var k := t.kit(kit)
	var pat := t.kit_pattern(kit)
	var socks := t.kit_socks(kit)
	return {"shirt": k[0], "shorts": k[1], "socks": socks if socks.a > 0.0 else k[0], "pattern": pat[0],
		"shirt2": pat[1], "number": 10, "hair_style": HairBuilder.Style.FADE}


func _kit_tex(path: String, kit: int) -> Texture2D:
	var t := TeamDB.load_team(path)
	return t.kit_texture(kit) if t != null else null


func _kit_file_name(path: String, kit: int) -> String:
	return "%s_%s.png" % [path.trim_prefix("db:").replace(":", "_"), ["titular", "suplente"][kit]]


func _show_kit(path: String) -> void:
	_k_current = path
	for c in _k_form.get_children():
		_k_form.remove_child(c)
		c.queue_free()
	var e := model.entry(path)
	if e.is_empty():
		return
	var key: String = ["home", "away"][_k_kit]
	var kit := TeamDB.parse_kit(String(e.get(key, "ffffff/ffffff/ffffff")))
	var which := OptionButton.new()
	which.add_item("Titular")
	which.add_item("Suplente")
	which.select(_k_kit)
	which.item_selected.connect(func(i: int) -> void:
		_k_kit = i
		_show_kit(path))
	_k_form.add_child(which)
	var grid := GridContainer.new()
	grid.columns = 2
	_k_form.add_child(grid)
	var shirt := ColorPickerButton.new()
	shirt.color = kit["shirt"]
	_row(grid, "Camiseta", shirt)
	var shorts := ColorPickerButton.new()
	shorts.color = kit["shorts"]
	_row(grid, "Pantalón", shorts)
	var socks := ColorPickerButton.new()
	socks.color = kit["socks"]
	_row(grid, "Medias", socks)
	var pat := OptionButton.new()
	for n in PATTERN_NAMES:
		pat.add_item(n)
	pat.select(int(kit["pattern"]))
	_row(grid, "Diseño", pat)
	var p2 := ColorPickerButton.new()
	p2.color = kit["pattern_color"]
	_row(grid, "Segundo color", p2)
	var keeper := ColorPickerButton.new()
	keeper.color = Color.html(String(e.get("keeper", "1a1a1a")))
	_row(grid, "Arquero", keeper)
	for cp in [shirt, shorts, socks, p2, keeper]:
		cp.custom_minimum_size = Vector2(120, 30)
	var apply := func() -> void:
		var s := "%s/%s/%s" % [shirt.color.to_html(false), shorts.color.to_html(false), socks.color.to_html(false)]
		if pat.selected > 0:
			s += "|%d|%s" % [pat.selected, p2.color.to_html(false)]
		model.set_team(path, {key: s, "keeper": keeper.color.to_html(false)})
	_k_form.add_child(_btn("Aplicar colores", apply, ""))
	_k_form.add_child(HSeparator.new())
	var tex_name := String(e.get(key + "_tex", ""))
	var info := _lbl(("Plantilla PNG: %s" % tex_name) if tex_name != "" else "Sin plantilla: se usa el diseño de arriba.")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_k_form.add_child(info)
	var how := _lbl("Para pintarla a mano: Exportar plantilla → se abre la carpeta \"plantillas\" con el PNG → pintalo con cualquier programa (Paint, GIMP, Photoshop) sin moverle las piezas → guardalo con el mismo nombre → Importar plantilla.")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	_k_form.add_child(how)
	var fname := _kit_file_name(path, _k_kit)
	var row := HBoxContainer.new()
	_k_form.add_child(row)
	row.add_child(_btn("Exportar plantilla", func() -> void:
		var img := KitTemplate.render(shirt.color, shorts.color, socks.color, pat.selected, p2.color)
		var out := UserData.templates_dir().path_join(fname)
		DirAccess.make_dir_recursive_absolute(UserData.templates_dir())
		img.save_png(out)
		UserData.open_folder(UserData.templates_dir())
		_status.text = "Plantilla exportada: %s" % out, "Guarda el PNG con los colores actuales en la carpeta plantillas"))
	row.add_child(_btn("Importar plantilla", func() -> void:
		var src := UserData.templates_dir().path_join(fname)
		if not FileAccess.file_exists(src):
			_status.text = "No está %s en la carpeta plantillas." % fname
			return
		DirAccess.make_dir_recursive_absolute(model.option_file.kits_dir())
		DirAccess.copy_absolute(src, model.option_file.kits_dir().path_join(fname))
		model.set_team(path, {key + "_tex": fname})
		_status.text = "Plantilla importada (se guarda con el Option File).", "Usa el PNG pintado en el juego"))
	row.add_child(_btn("Quitar plantilla", func() -> void: model.set_team(path, {key + "_tex": ""}), ""))
	_k_form.add_child(_btn("Abrir carpeta de plantillas", func() -> void: UserData.open_folder(UserData.templates_dir()), ""))
	_k_preview.show_player(_kit_colors(path, _k_kit), _kit_tex(path, _k_kit))


# --- Importar -------------------------------------------------------------------------------

func _import_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Importar"
	tab.add_theme_constant_override("separation", 8)
	tab.add_child(_lbl("Copiá tus CSV en la carpeta de importar. Todo va al Option File de arriba (la base no se toca)."))
	var top := HBoxContainer.new()
	tab.add_child(top)
	top.add_child(_btn("Abrir carpeta de importar", func() -> void: UserData.open_folder(UserData.import_dir()), ""))
	# Planteles (CSV de jugadores).
	var pl := HBoxContainer.new()
	tab.add_child(pl)
	pl.add_child(_lbl("Planteles (CSV de jugadores):"))
	pl.add_child(_btn("Importar planteles", _import, "EA FC / SoFIFA, Transfermarkt o planilla propia"))
	_imp_text = _lbl("")
	_imp_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(_imp_text)
	tab.add_child(HSeparator.new())
	# Clubes y divisiones (CSV con nombre, división y estadio).
	var cl := HBoxContainer.new()
	tab.add_child(cl)
	cl.add_child(_lbl("Clubes y divisiones (CSV con nombre, división, estadio):"))
	cl.add_child(_btn("1. Revisar lista de clubes", _clubs_review, "Lee los CSV de clubes y muestra qué va a hacer con cada fila"))
	_ci_filter = OptionButton.new()
	for t in ["Ver todas", "Solo para revisar", "Solo nuevos", "Solo salteadas"]:
		_ci_filter.add_item(t)
	_ci_filter.item_selected.connect(func(_i: int) -> void: _clubs_fill())
	cl.add_child(_ci_filter)
	_ci_stadiums = CheckBox.new()
	_ci_stadiums.text = "Usar los estadios del CSV"
	_ci_stadiums.button_pressed = true
	cl.add_child(_ci_stadiums)
	cl.add_child(_btn("2. Aplicar", _clubs_apply, "Arma las divisiones con estos clubes (se puede deshacer con Ctrl+Z)"))
	_ci_text = _lbl("")
	_ci_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(_ci_text)
	_ci_tree = Tree.new()
	_ci_tree.columns = 5
	_ci_tree.hide_root = true
	_ci_tree.column_titles_visible = true
	_ci_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in 5:
		_ci_tree.set_column_title(i, ["Club en el CSV", "División", "Estadio", "Estado", "Club del juego (clic para cambiar)"][i])
		_ci_tree.set_column_expand(i, true)
	_ci_tree.set_column_expand_ratio(0, 2)
	_ci_tree.set_column_expand_ratio(2, 3)
	_ci_tree.set_column_expand_ratio(4, 3)
	_ci_tree.item_edited.connect(_clubs_edited)
	tab.add_child(_ci_tree)
	return tab


const CI_STATUS := {"match": "OK", "doubt": "REVISAR", "new": "Nuevo", "skip": "Salteada"}

var _ci_plan: Array[Dictionary] = []
var _ci_tree: Tree
var _ci_text: Label
var _ci_filter: OptionButton
var _ci_stadiums: CheckBox


func _clubs_review() -> void:
	var rows := ClubImporter.read_folder(UserData.import_dir())
	if rows.is_empty():
		_ci_plan.clear()
		_clubs_fill()
		_ci_text.text = "No hay CSV de clubes en %s (necesitan las columnas nombre y división)." % UserData.import_dir()
		return
	_ci_plan = ClubImporter.analyze(rows)
	_clubs_fill()


## Opciones del desplegable de una fila: candidatos, club nuevo, no importar.
static func _clubs_options(e: Dictionary) -> Array:
	var out: Array = []
	if e["choice"] == "":
		out.append(["", "— Elegí el club —"])
	for c in e["candidates"]:
		out.append([String(c["id"]), "%s (%s)" % [c["name"], c["division"]]])
	if String(e["division"]) != "":
		out.append([ClubImporter.NEW, "Club nuevo: " + String(e["name"])])
	out.append([ClubImporter.SKIP, "No importar"])
	return out


func _clubs_fill() -> void:
	_ci_tree.clear()
	var root := _ci_tree.create_item()
	var want: String = ["", "doubt", "new", "skip"][maxi(_ci_filter.selected, 0)]
	for i in _ci_plan.size():
		var e := _ci_plan[i]
		if want != "" and e["status"] != want:
			continue
		var it := _ci_tree.create_item(root)
		it.set_metadata(0, i)
		it.set_text(0, e["name"])
		it.set_text(1, e["division_name"])
		it.set_text(2, e["stadium"])
		it.set_text(3, CI_STATUS[e["status"]])
		it.set_tooltip_text(3, e["note"])
		var col: Color = {"match": Color(0.5, 0.9, 0.5), "doubt": Color(1, 0.75, 0.3), "new": Color(0.5, 0.75, 1),
			"skip": Color(0.6, 0.6, 0.6)}[e["status"]]
		it.set_custom_color(3, col)
		var opts := _clubs_options(e)
		var names: Array = []
		var sel := -1
		for k in opts.size():
			names.append(String(opts[k][1]).replace(",", " "))
			if opts[k][0] == e["choice"]:
				sel = k
		it.set_cell_mode(4, TreeItem.CELL_MODE_RANGE)
		it.set_text(4, ",".join(names))
		it.set_editable(4, true)
		it.set_range(4, maxi(sel, 0))
		if e["choice"] == "":
			it.set_custom_color(4, Color(1, 0.75, 0.3))
	var s := ClubImporter.summary(_ci_plan)
	var pending := _ci_plan.filter(func(e: Dictionary) -> bool: return e["status"] == "doubt" and e["choice"] == "").size()
	_ci_text.text = "%d filas: %d encontradas, %d para revisar (%d sin elegir), %d clubes nuevos, %d salteadas. Pasá el mouse por el estado para ver el motivo." % [
		_ci_plan.size(), s["match"], s["doubt"], pending, s["new"], s["skip"]] if not _ci_plan.is_empty() else ""


func _clubs_edited() -> void:
	var it := _ci_tree.get_edited()
	if it == null:
		return
	var e := _ci_plan[int(it.get_metadata(0))]
	var opts := _clubs_options(e)
	var k := int(it.get_range(4))
	if k >= 0 and k < opts.size():
		e["choice"] = opts[k][0]
		_clubs_fill.call_deferred()


func _clubs_apply() -> void:
	if _ci_plan.is_empty():
		_ci_text.text = "Primero apretá \"1. Revisar lista de clubes\"."
		return
	var pending := _ci_plan.filter(func(e: Dictionary) -> bool: return e["choice"] == "")
	var res := model.import_clubs(_ci_plan, _ci_stadiums.button_pressed)
	_regroup()
	_refresh_leagues()
	_ci_text.text = "Listo: %d divisiones armadas con %d clubes (%d nuevos, %d estadios cambiados)%s. Guardá con Ctrl+S; Ctrl+Z lo deshace." % [
		res["divisions"], res["clubs"], res["new"], res["stadiums"],
		(". Quedaron %d filas sin elegir que no se importaron" % pending.size()) if not pending.is_empty() else ""]
	_ci_plan.clear()
	_ci_tree.clear()


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
