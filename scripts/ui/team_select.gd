class_name TeamSelect
extends Control
## Elección de equipos, como en el WE: arriba el local y el visitante con sus
## uniformes y las barras de ataque, defensa, fuerza, velocidad y técnica;
## abajo la grilla de escudos (o banderas) del grupo elegido. Los grupos son
## las Selecciones, cada división de cada país y los Equipos WE (ficticios);
## L1 / R1 (Q / E) pasan de grupo. Primero se elige el local y después el
## visitante. Cuadrado (o Z) elige uno al azar; Círculo / Esc vuelve.

signal chosen(home_path: String, away_path: String)
signal cancelled

## Grupos: [{name, sub, paths}].
var groups: Array[Dictionary] = []
var group := 0
## Equipos del grupo que se ve.
var paths: Array[String] = []
var teams: Array[TeamData] = []
## 0 = eligiendo el local, 1 = el visitante.
var side := 0
## Rutas elegidas (local, visitante).
var picked: Array[String] = ["", ""]

var _grid: GridContainer
var _scroll: ScrollContainer
var _group_label: Label
var _group_sub: Label
var _names: Array[Label] = []
var _crests: Array[WEStyle.Crest] = []
var _kits: Array[WEStyle.KitIcon] = []
var _bars: WEStyle.RatingBars
var _help: Label
var _side_labels: Array[Label] = []
var _side_panels: Array[Control] = []
var _title: Label
## Elegir un solo equipo (el tuyo, para la Liga o la Copa).
var single := false
## Sólo estos equipos, en un único grupo (p. ej. las 48 del Mundial).
var only_paths: Array[String] = []
var _all_groups: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_all_groups = build_groups()
	groups = _all_groups
	picked = [GameSettings.home_team_path, GameSettings.away_team_path]
	_title = WEStyle.label("ELEGÍ LOS EQUIPOS", 30, Color(1.0, 0.9, 0.35))
	_title.position = Vector2(70, 30)
	add_child(_title)
	# Arriba: local | barras | visitante.
	var top := HBoxContainer.new()
	top.position = Vector2(70, 76)
	top.add_theme_constant_override("separation", 20)
	add_child(top)
	for i in 2:
		var pc := WEStyle.panel(Vector2(330, 206))
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		pc.add_child(box)
		var sl := WEStyle.label("LOCAL" if i == 0 else "VISITANTE", 18, Color(0.6, 0.8, 1.0))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sl)
		_side_labels.append(sl)
		var nl := WEStyle.label("", 22)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.clip_text = true
		nl.custom_minimum_size.x = 300
		box.add_child(nl)
		_names.append(nl)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 18)
		box.add_child(row)
		var crest := WEStyle.Crest.new()
		crest.custom_minimum_size = Vector2(90, 100)
		row.add_child(crest)
		_crests.append(crest)
		var kit := WEStyle.KitIcon.new()
		kit.custom_minimum_size = Vector2(100, 116)
		row.add_child(kit)
		_kits.append(kit)
		top.add_child(pc)
		_side_panels.append(pc)
		if i == 0:
			var mid := WEStyle.panel(Vector2(400, 206))
			_bars = WEStyle.RatingBars.new()
			_bars.custom_minimum_size = Vector2(376, 186)
			mid.add_child(_bars)
			top.add_child(mid)
	# Pestaña del grupo: "◀ ARGENTINA · Liga Profesional ▶".
	_group_label = WEStyle.label("", 24, Color(1.0, 0.9, 0.35))
	_group_label.position = Vector2(70, 296)
	_group_label.size = Vector2(1140, 32)
	_group_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_group_label)
	_group_sub = WEStyle.label("", 15, Color(0.7, 0.8, 0.95))
	_group_sub.position = Vector2(70, 326)
	_group_sub.size = Vector2(1140, 20)
	_group_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_group_sub)
	# Grilla de escudos con desplazamiento.
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(70, 352)
	_scroll.size = Vector2(1140, 262)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 10
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll.add_child(_grid)
	_help = WEStyle.help_box(self)
	(_help.get_parent() as Control).offset_top = -86
	# Leyenda fija de los botones (arriba a la derecha, como en el WE).
	var legend := ButtonIcons.IconLabel.new(20, false, Color(0.92, 0.95, 1.0))
	legend.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	legend.position = Vector2(-560, 22)
	legend.size = Vector2(540, 30)
	add_child(legend)
	legend.show_text(LEGEND)


## Leyenda de botones de la elección de equipos.
const LEGEND := "{L1}{R1} Grupo    {SQ} Al azar    {X} Aceptar    {O} Volver"


## Selecciones, cada división de cada país y los Equipos WE.
static func build_groups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"name": "SELECCIONES", "sub": "%d selecciones" % TeamDB.nations().size(), "paths": TeamDB.nation_paths(),
		"kind": "nations"})
	for c in TeamDB.countries():
		for d in c["divisions"]:
			var ps := TeamDB.division_paths(c["id"], d["id"])
			out.append({"name": "%s · %s" % [String(c["name"]).to_upper(), d["name"]],
				"sub": "%d equipos · temporada %s" % [ps.size(), d.get("season", "")], "paths": ps,
				"kind": "division", "country": c["id"], "division": d["id"]})
	out.append({"name": "EQUIPOS WE", "sub": "Equipos ficticios de Master Eleven", "paths": GameSettings.team_paths(),
		"kind": "we"})
	return out


## Grupo que contiene la ruta (o -1).
func group_of(path: String) -> int:
	for i in groups.size():
		if (groups[i]["paths"] as Array).has(path):
			return i
	return -1


## Equipos del grupo de esa ruta (la división de un club, para la Liga).
func group_paths_of(path: String) -> Array[String]:
	var g := group_of(path)
	var out: Array[String] = []
	if g >= 0:
		out.assign(groups[g]["paths"])
	return out


func open() -> void:
	side = 0
	visible = true
	_title.text = "ELEGÍ TU EQUIPO" if single else "ELEGÍ LOS EQUIPOS"
	_side_panels[1].visible = not single
	_bars.get_parent().visible = not single
	picked = [GameSettings.home_team_path, GameSettings.away_team_path]
	if only_paths.is_empty():
		groups = _all_groups
	else:
		var mundial := only_paths.size() == 48 and only_paths.all(func(p: String) -> bool: return p.begins_with("db:nat:"))
		groups = [{"name": "MUNDIAL 2026" if mundial else "ELEGÍ TU EQUIPO", "sub": "%d equipos" % only_paths.size(),
			"paths": only_paths, "kind": "nations" if mundial else "custom"}]
		if not only_paths.has(picked[0]):
			picked[0] = only_paths[0]
	for i in 2:
		if not TeamDB.exists(picked[i]):
			picked[i] = GameSettings.DEFAULT_HOME if i == 0 else GameSettings.DEFAULT_AWAY
	var g := group_of(picked[0])
	show_group(g if g >= 0 else groups.size() - 1)


## Muestra un grupo en la grilla (y pone el foco en el elegido si está).
func show_group(g: int) -> void:
	group = posmod(g, groups.size())
	paths.assign(groups[group]["paths"])
	teams.clear()
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	for i in paths.size():
		var t := TeamDB.load_team(paths[i])
		teams.append(t)
		var b := Button.new()
		b.custom_minimum_size = Vector2(104, 82)
		b.tooltip_text = t.team_name
		for st in ["normal", "hover", "focus", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.1, 0.12, 0.3, 0.85)
			sb.border_color = Color(0.3, 1.0, 0.4) if st in ["focus", "hover"] else Color(0.25, 0.3, 0.6)
			sb.set_border_width_all(3)
			b.add_theme_stylebox_override(st, sb)
		var crest := WEStyle.Crest.new()
		crest.team = t
		crest.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		crest.offset_left = 14
		crest.offset_right = -14
		crest.offset_top = 6
		crest.offset_bottom = -6
		crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(crest)
		b.focus_entered.connect(_on_focus.bind(i))
		b.pressed.connect(_on_pick.bind(i))
		_grid.add_child(b)
	var gname: String = groups[group]["name"]
	_group_label.text = "◀  %s  ▶" % gname
	_group_sub.text = "%s   ·   grupo %d de %d" % [groups[group]["sub"], group + 1, groups.size()]
	_refresh()
	var focus := maxi(paths.find(picked[side]), 0)
	if is_inside_tree() and _grid.get_child_count() > 0:
		(_grid.get_child(focus) as Control).grab_focus()


func _on_focus(i: int) -> void:
	picked[side] = paths[i]
	_refresh()


func _on_pick(i: int) -> void:
	picked[side] = paths[i]
	if single:
		chosen.emit(paths[i], "")
		return
	if side == 0:
		side = 1
		_refresh()
		var j := paths.find(picked[1])
		(_grid.get_child(j if j >= 0 else i) as Control).grab_focus()
		return
	chosen.emit(picked[0], picked[1])


func random_pick() -> void:
	var i := randi() % teams.size()
	(_grid.get_child(i) as Control).grab_focus()
	_on_focus(i)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		if side == 1:
			side = 0
			var g := group_of(picked[0])
			if g >= 0 and g != group:
				show_group(g)
			else:
				_refresh()
				(_grid.get_child(maxi(paths.find(picked[0]), 0)) as Control).grab_focus()
		else:
			cancelled.emit()
		get_viewport().set_input_as_handled()
	elif (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X) \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Z):
		random_pick()
		get_viewport().set_input_as_handled()
	elif _group_step(event) != 0:
		show_group(group + _group_step(event))
		get_viewport().set_input_as_handled()


## L1 / R1 (o Q / E): grupo anterior / siguiente.
static func _group_step(event: InputEvent) -> int:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			return -1
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			return 1
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q or event.physical_keycode == KEY_PAGEUP:
			return -1
		if event.physical_keycode == KEY_E or event.physical_keycode == KEY_PAGEDOWN:
			return 1
	return 0


func _refresh() -> void:
	var datas: Array[TeamData] = []
	for i in 2:
		var t := TeamDB.load_team(picked[i])
		datas.append(t)
		if t == null:
			continue
		_names[i].text = t.team_name
		_crests[i].team = t
		_crests[i].queue_redraw()
		_kits[i].set_kit(t, 0)
		_side_labels[i].add_theme_color_override("font_color", Color(1.0, 0.9, 0.35) if side == i else Color(0.6, 0.8, 1.0))
	if datas[0] != null and datas[1] != null:
		_bars.home = datas[0].ratings()
		_bars.away = datas[1].ratings()
		_bars.queue_redraw()
	var focus_t := datas[side]
	var extra := ""
	if focus_t != null and focus_t.stadium != "":
		extra = "   ·   %s" % focus_t.stadium
	_help.text = ("Elegí tu equipo." if single else ("Elegí el equipo LOCAL." if side == 0 else "Elegí el equipo VISITANTE.")) + \
		extra + "   (Teclado: Enter elegir, Q/E grupo, Z al azar, Esc volver.)"
