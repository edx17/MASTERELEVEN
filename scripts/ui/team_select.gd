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

var _frame: WEStyle.ScreenFrame
var _grid: GridContainer
var _scroll: ScrollContainer
var _group_label: Label
var _group_sub: Label
var _names: Array[Label] = []
var _crests: Array[WEStyle.Crest] = []
var _kits: Array[WEStyle.KitIcon] = []
var _bars: WEStyle.RatingBars
var _side_labels: Array[Label] = []
var _side_panels: Array[Control] = []
## Elegir un solo equipo (el tuyo, para la Liga o la Copa).
var single := false
## Sólo estos equipos, en un único grupo (p. ej. las 48 del Mundial).
var only_paths: Array[String] = []
## Sólo las divisiones de este país (Liga Virtual); "" = todas.
var only_country := ""
var _all_groups: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_all_groups = build_groups()
	groups = _all_groups
	picked = [GameSettings.home_team_path, GameSettings.away_team_path]
	_frame = WEStyle.ScreenFrame.new("Elección de equipos", HINTS)
	add_child(_frame)
	_frame.crumb.text = "PARTIDO  /  EQUIPOS"
	# Arriba: local | comparación | visitante.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(WEStyle.px(24)))
	_frame.body.add_child(top)
	for i in 2:
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", int(WEStyle.px(8)))
		pc.add_child(box)
		var sl := WEStyle.make_caption_label("Local" if i == 0 else "Visitante")
		box.add_child(sl)
		_side_labels.append(sl)
		var nl := WEStyle.make_title_label("", WEStyle.TITLE_M)
		nl.clip_text = true
		nl.custom_minimum_size.x = WEStyle.px(360)
		box.add_child(nl)
		_names.append(nl)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(WEStyle.px(24)))
		box.add_child(row)
		var crest := WEStyle.Crest.new()
		crest.label_font = WEStyle.font(WEStyle.Typeface.TITLE)
		crest.custom_minimum_size = Vector2(WEStyle.px(130), WEStyle.px(144))
		row.add_child(crest)
		_crests.append(crest)
		var kit := WEStyle.KitIcon.new()
		kit.custom_minimum_size = Vector2(WEStyle.px(140), WEStyle.px(160))
		row.add_child(kit)
		_kits.append(kit)
		top.add_child(pc)
		_side_panels.append(pc)
		if i == 0:
			var mid := PanelContainer.new()
			mid.add_theme_stylebox_override("panel", _card_style(false))
			mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var mv := VBoxContainer.new()
			mv.add_child(WEStyle.make_caption_label("Comparación"))
			_bars = WEStyle.RatingBars.new()
			_bars.modern = true
			_bars.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_bars.custom_minimum_size = Vector2(WEStyle.px(480), WEStyle.px(220))
			mv.add_child(_bars)
			mid.add_child(mv)
			top.add_child(mid)
	# El grupo que se ve: "EQUIPOS WE" a la izquierda, el detalle a la derecha.
	var gbar := HBoxContainer.new()
	gbar.add_theme_constant_override("separation", int(WEStyle.px(16)))
	_group_label = WEStyle.make_title_label("", WEStyle.TITLE_M, WEStyle.ACCENT)
	gbar.add_child(_group_label)
	gbar.add_child(WEStyle.make_gap())
	_group_sub = WEStyle.make_body_label("", WEStyle.BODY_L, WEStyle.TEXT_DIM)
	_group_sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gbar.add_child(_group_sub)
	_frame.body.add_child(gbar)
	# Grilla de escudos con desplazamiento.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_frame.body.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 10
	_grid.add_theme_constant_override("h_separation", int(WEStyle.px(16)))
	_grid.add_theme_constant_override("v_separation", int(WEStyle.px(16)))
	_scroll.add_child(_grid)


## Indicaciones del pie (rearmadas al cambiar de teclado a mando).
const HINTS := [[&"ui_accept", "Elegir"], [&"ui_cancel", "Volver"], [&"ui_tabs", "Grupo"], [&"ui_random", "Al azar"]]


## Tarjeta del local o el visitante: con borde dorado la que se está eligiendo.
func _card_style(active: bool) -> StyleBoxFlat:
	var sb := WEStyle.make_panel_style()
	var pad := WEStyle.px(WEStyle.CARD_PADDING)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	if active:
		sb.border_color = WEStyle.ACCENT
		sb.set_border_width_all(WEStyle.FOCUS_BORDER)
	return sb


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
	out.append({"name": "EQUIPOS WE", "sub": "Equipos ficticios de Virtual Eleven", "paths": GameSettings.team_paths(),
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
	_frame.title.text = "ELEGÍ TU EQUIPO" if single else "ELEGÍ LOS EQUIPOS"
	_side_panels[1].visible = not single
	_bars.get_parent().visible = not single
	picked = [GameSettings.home_team_path, GameSettings.away_team_path]
	if only_country != "":
		groups = build_groups().filter(func(gr: Dictionary) -> bool:
			return gr["kind"] == "division" and gr["country"] == only_country)
		if group_of(picked[0]) < 0:
			picked[0] = (groups[groups.size() - 1]["paths"] as Array)[0]
	elif only_paths.is_empty():
		groups = _all_groups
	else:
		var mundial := only_paths.size() == 48 and only_paths.all(func(p: String) -> bool: return p.begins_with("db:nat:"))
		groups = [{"name": "MUNDIAL" if mundial else "ELEGÍ TU EQUIPO", "sub": "%d equipos" % only_paths.size(),
			"paths": only_paths, "kind": "nations" if mundial else "custom"}]
		if not only_paths.has(picked[0]):
			picked[0] = only_paths[0]
	for i in 2:
		if not TeamDB.exists(picked[i]):
			picked[i] = GameSettings.DEFAULT_HOME if i == 0 else GameSettings.DEFAULT_AWAY
	var g := group_of(picked[0])
	show_group(g if g >= 0 else groups.size() - 1)
	WEStyle.fade_in(_frame)


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
		b.custom_minimum_size = Vector2(WEStyle.px(150), WEStyle.px(124))
		b.tooltip_text = t.team_name
		WEStyle.style_button(b)
		var crest := WEStyle.Crest.new()
		crest.team = t
		crest.label_font = WEStyle.font(WEStyle.Typeface.TITLE)
		crest.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		crest.offset_left = WEStyle.px(24)
		crest.offset_right = -WEStyle.px(24)
		crest.offset_top = WEStyle.px(12)
		crest.offset_bottom = -WEStyle.px(12)
		crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(crest)
		b.focus_entered.connect(_on_focus.bind(i))
		b.pressed.connect(_on_pick.bind(i))
		_grid.add_child(b)
	var gname: String = groups[group]["name"]
	_group_label.text = gname
	_group_sub.text = "%s  ·  grupo %d de %d" % [groups[group]["sub"], group + 1, groups.size()]
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
		_side_labels[i].add_theme_color_override("font_color", WEStyle.ACCENT if side == i else WEStyle.TEXT_DIM)
		_side_panels[i].add_theme_stylebox_override("panel", _card_style(side == i and not single))
	if datas[0] != null and datas[1] != null:
		_bars.home = datas[0].ratings()
		_bars.away = datas[1].ratings()
		_bars.queue_redraw()
	var focus_t := datas[side]
	var extra := ""
	if focus_t != null and focus_t.stadium != "":
		extra = "  ·  %s" % focus_t.stadium
	_frame.title_info.text = ("Elegí tu equipo" if single else ("Elegí el LOCAL" if side == 0 else "Elegí el VISITANTE")) + extra
