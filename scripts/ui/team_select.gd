class_name TeamSelect
extends Control
## Elección de equipos, como en el WE: abajo la grilla de escudos; arriba el
## local y el visitante con sus uniformes, y las barras de ataque, defensa,
## fuerza, velocidad y técnica. Primero se elige el local y después el
## visitante. Cuadrado (o Z) elige uno al azar; Círculo / Esc vuelve.

signal chosen(home_path: String, away_path: String)
signal cancelled

var paths: Array[String] = []
var teams: Array[TeamData] = []
## 0 = eligiendo el local, 1 = el visitante.
var side := 0
var picks: Array[int] = [0, 1]

var _grid: GridContainer
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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paths = GameSettings.team_paths()
	for p in paths:
		teams.append(load(p) as TeamData)
	picks = [maxi(paths.find(GameSettings.home_team_path), 0), maxi(paths.find(GameSettings.away_team_path), 0)]
	_title = WEStyle.label("ELEGÍ LOS EQUIPOS", 30, Color(1.0, 0.9, 0.35))
	_title.position = Vector2(70, 40)
	add_child(_title)
	# Arriba: local | barras | visitante.
	var top := HBoxContainer.new()
	top.position = Vector2(70, 90)
	top.add_theme_constant_override("separation", 20)
	add_child(top)
	for i in 2:
		var pc := WEStyle.panel(Vector2(330, 250))
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		pc.add_child(box)
		var sl := WEStyle.label("LOCAL" if i == 0 else "VISITANTE", 20, Color(0.6, 0.8, 1.0))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sl)
		_side_labels.append(sl)
		var nl := WEStyle.label("", 24)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(nl)
		_names.append(nl)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 18)
		box.add_child(row)
		var crest := WEStyle.Crest.new()
		crest.custom_minimum_size = Vector2(90, 110)
		row.add_child(crest)
		_crests.append(crest)
		var kit := WEStyle.KitIcon.new()
		kit.custom_minimum_size = Vector2(110, 130)
		row.add_child(kit)
		_kits.append(kit)
		top.add_child(pc)
		_side_panels.append(pc)
		if i == 0:
			var mid := WEStyle.panel(Vector2(400, 250))
			_bars = WEStyle.RatingBars.new()
			_bars.custom_minimum_size = Vector2(376, 226)
			mid.add_child(_bars)
			top.add_child(mid)
	# Grilla de escudos.
	_grid = GridContainer.new()
	_grid.columns = 8
	_grid.position = Vector2(110, 380)
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 10)
	add_child(_grid)
	for i in teams.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(118, 104)
		for st in ["normal", "hover", "focus", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.1, 0.12, 0.3, 0.85)
			sb.border_color = Color(0.3, 1.0, 0.4) if st in ["focus", "hover"] else Color(0.25, 0.3, 0.6)
			sb.set_border_width_all(3)
			b.add_theme_stylebox_override(st, sb)
		var crest := WEStyle.Crest.new()
		crest.team = teams[i]
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
	_help = WEStyle.help_box(self)


func open() -> void:
	side = 0
	visible = true
	_title.text = "ELEGÍ TU EQUIPO" if single else "ELEGÍ LOS EQUIPOS"
	_side_panels[1].visible = not single
	_bars.get_parent().visible = not single
	_refresh()
	(_grid.get_child(picks[0]) as Control).grab_focus()


func _on_focus(i: int) -> void:
	picks[side] = i
	_refresh()


func _on_pick(i: int) -> void:
	picks[side] = i
	if single:
		chosen.emit(paths[i], "")
		return
	if side == 0:
		side = 1
		_refresh()
		(_grid.get_child(picks[1]) as Control).grab_focus()
		return
	chosen.emit(paths[picks[0]], paths[picks[1]])


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
			_refresh()
			(_grid.get_child(picks[0]) as Control).grab_focus()
		else:
			cancelled.emit()
		get_viewport().set_input_as_handled()
	elif (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X) \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Z):
		random_pick()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for i in 2:
		var t := teams[picks[i]]
		_names[i].text = t.team_name
		_crests[i].team = t
		_crests[i].queue_redraw()
		var kit := t.kit(0)
		_kits[i].shirt = kit[0]
		_kits[i].shorts = kit[1]
		_kits[i].queue_redraw()
		_side_labels[i].add_theme_color_override("font_color", Color(1.0, 0.9, 0.35) if side == i else Color(0.6, 0.8, 1.0))
	_bars.home = teams[picks[0]].ratings()
	_bars.away = teams[picks[1]].ratings()
	_bars.queue_redraw()
	_help.text = ("Elegí tu equipo." if single else ("Elegí el equipo LOCAL." if side == 0 else "Elegí el equipo VISITANTE.")) + \
		"   {X} elegir   {SQ} (Z) al azar   {O} (Esc) volver"
