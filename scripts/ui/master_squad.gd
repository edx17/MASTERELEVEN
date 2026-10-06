class_name MasterSquad
extends Control
## Plantel y Dirección del equipo de la Liga Master (fuera del partido):
## a la izquierda la formación y los 23 (los 11 titulares arriba, en el orden
## de los puestos); a la derecha la ficha del jugador elegido con sus
## atributos y cuánto cambiaron desde que empezó la temporada.
##   - X (o clic) sobre un jugador y después sobre otro: se intercambian
##     (titular con suplente = entra el suplente). Queda guardado para los
##     partidos que vienen.
##   - Formación ◀ ▶: cambia el esquema (los titulares se eligen solos).
##   - "Mejor once": vuelve a la alineación automática.
## Los lesionados y suspendidos aparecen en rojo; si están en el once,
## entra el mejor libre de su puesto hasta que vuelvan.

signal closed

const GOLD := Color(1.0, 0.9, 0.35)
const BLUE := Color(0.6, 0.8, 1.0)
const RED := Color(1.0, 0.55, 0.5)
const GREEN := Color(0.55, 1.0, 0.6)

var career: MasterCareer
var _list: VBoxContainer
var _detail: VBoxContainer
var _info: Label
var _marked := -1
var _players: Array[PlayerData] = []
var _rows: Array[Button] = []
var _focus_pid := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func open(c: MasterCareer) -> void:
	career = c
	_marked = -1
	visible = true
	_rebuild()


func _clear(n: Node) -> void:
	for ch in n.get_children():
		n.remove_child(ch)
		ch.queue_free()


func _rebuild() -> void:
	_clear(self)
	_rows.clear()
	var lp := WEStyle.panel(Vector2(700, 620))
	lp.position = Vector2(40, 30)
	add_child(lp)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	lp.add_child(left)
	var t := career.user_team()
	_players = t.players
	left.add_child(WEStyle.label("PLANTEL Y DIRECCIÓN  ·  %s" % t.team_name, 22, GOLD))
	var forms := MasterCareer.FORMATIONS
	var frow := WEStyle.OptionRow.new("Formación", func() -> String: return career.formation_name(),
		func(dir: int) -> void:
			var i := forms.find(career.formation_name())
			career.set_formation(forms[wrapi(i + dir, 0, forms.size())])
			career.save()
			_marked = -1
			_rebuild.call_deferred(), "", 676.0)
	left.add_child(frow)
	left.add_child(_cells(["", "N°", "Puesto", "Nombre", "Edad", "Media", "Evol.", "Goles", "Estado"], BLUE, 14))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(676, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	scroll.add_child(_list)
	for i in _players.size():
		_list.add_child(_row(i))
		if i == 10:
			_list.add_child(WEStyle.label("  Suplentes", 14, BLUE))
		if i == 22 and _players.size() > 23:
			_list.add_child(WEStyle.label("  Fuera de la lista (al partido van 23)", 14, BLUE))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	left.add_child(btns)
	btns.add_child(WEStyle.bar("Mejor once", func() -> void:
		career.auto_lineup()
		career.save()
		_marked = -1
		_rebuild.call_deferred(), 216.0, 20))
	btns.add_child(WEStyle.bar("Inferiores", _open_youth, 216.0, 20))
	btns.add_child(WEStyle.bar("Volver", _close, 216.0, 20))
	# Derecha: la ficha.
	var rp := WEStyle.panel(Vector2(480, 620))
	rp.position = Vector2(760, 30)
	add_child(rp)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 2)
	rp.add_child(_detail)
	_info = WEStyle.label("", 15, Color(0.8, 0.85, 0.95))
	var focus_i := 0
	for i in _players.size():
		if _players[i].pid == _focus_pid:
			focus_i = i
	if not _rows.is_empty():
		_rows[focus_i].grab_focus()
		_show_detail(focus_i)


## Ancho de cada columna de la lista.
const COLS := [22, 40, 62, 240, 50, 56, 50, 50, 80]


## Fila de celdas de ancho fijo (para que las columnas queden alineadas).
func _cells(texts: Array, color: Color, fs: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 4)
	for k in texts.size():
		var l := WEStyle.label(String(texts[k]), fs, color)
		l.custom_minimum_size = Vector2(COLS[k], 0)
		l.clip_text = true
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
	return h


func _row(i: int) -> Button:
	var p := _players[i]
	var d := career.user_player_dict(p.pid)
	var b := Button.new()
	b.custom_minimum_size = Vector2(660, 28)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 16)
	var status := ""
	if int(d.get("inj", 0)) > 0:
		status = "  LES %d" % int(d["inj"])
	elif int(d.get("susp", 0)) > 0:
		status = "  SUS %d" % int(d["susp"])
	var mark := "▶" if i == _marked else ("●" if i < 11 else "")
	WEStyle.style_bar(b)
	var c := RED if status != "" else (GOLD if i == _marked else Color.WHITE)
	var ev := career.overall_delta(p.pid)
	var cells := _cells([mark, str(p.number), p.role_code, p.player_name, str(p.get_age()),
		str(roundi(TeamDB.overall(p))), ("%+d" % ev) if ev != 0 else "", str(career.goals_of(p.pid)), status.strip_edges()], c, 16)
	if ev != 0:
		(cells.get_child(6) as Label).add_theme_color_override("font_color", GREEN if ev > 0 else RED)
	cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cells.offset_left = 14
	b.add_child(cells)
	b.focus_entered.connect(func() -> void: _show_detail(i))
	b.pressed.connect(_on_row.bind(i))
	_rows.append(b)
	return b


## Primer toque marca; el segundo intercambia.
func _on_row(i: int) -> void:
	if _marked < 0:
		_marked = i
		_focus_pid = _players[i].pid
		_rebuild.call_deferred()
		return
	if _marked != i:
		career.swap_players(_players[_marked].pid, _players[i].pid)
		career.save()
	_focus_pid = _players[i].pid
	_marked = -1
	_rebuild.call_deferred()


func _show_detail(i: int) -> void:
	_clear(_detail)
	if i < 0 or i >= _players.size():
		return
	var p := _players[i]
	_focus_pid = p.pid
	var d := career.user_player_dict(p.pid)
	_detail.add_child(WEStyle.label(p.player_name, 22, GOLD))
	_detail.add_child(WEStyle.label("%s · %d años · %d cm · %s · media %d" % [p.role_code, p.get_age(), p.height_cm(),
		["diestro", "zurdo", "ambidiestro"][clampi(p.foot, 0, 2)], roundi(TeamDB.overall(p))], 15))
	var st := "Titular" if i < 11 else "Suplente"
	if int(d.get("inj", 0)) > 0:
		st = "Lesionado: %d fecha%s" % [int(d["inj"]), "" if int(d["inj"]) == 1 else "s"]
	elif int(d.get("susp", 0)) > 0:
		st = "Suspendido: %d fecha%s" % [int(d["susp"]), "" if int(d["susp"]) == 1 else "s"]
	_detail.add_child(WEStyle.label("%s · Goles: %d · Amarillas: %d" % [st, career.goals_of(p.pid), int(d.get("yc", 0))], 15,
		RED if st.begins_with("Les") or st.begins_with("Sus") else Color.WHITE))
	_detail.add_child(WEStyle.label("Atributos (cambio en la temporada)", 15, BLUE))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 0)
	_detail.add_child(grid)
	for k in PlayerData.ATTRIBUTES.size():
		var attr: String = PlayerData.ATTRIBUTES[k]
		var v := int(p.get(attr))
		var delta := career.attr_delta(p.pid, attr, v)
		var name := WEStyle.label(PlayerData.ATTRIBUTE_NAMES[k], 15)
		name.custom_minimum_size = Vector2(230, 0)
		grid.add_child(name)
		grid.add_child(WEStyle.label(str(v), 15, TeamSheet.attribute_color(v)))
		grid.add_child(WEStyle.label(("%+d" % delta) if delta != 0 else "", 15, GREEN if delta > 0 else RED))
	# Media de cada temporada (se anota en el cambio de año).
	var hist: Array = d.get("hist", [])
	if not hist.is_empty():
		var parts: Array = hist.slice(maxi(0, hist.size() - 5)).map(func(h: Array) -> String: return "%s: %d" % [h[0], int(h[1])])
		var hl := WEStyle.label("Media por temporada: " + "  ·  ".join(parts), 14, BLUE)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.custom_minimum_size = Vector2(450, 0)
		_detail.add_child(hl)
	var help := WEStyle.label("X sobre un jugador y después sobre otro: se cambian (queda guardado para los próximos partidos). Rojo: lesionado o suspendido; si es titular, juega el mejor libre de su puesto.", 14, Color(0.7, 0.75, 0.85))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(450, 0)
	_detail.add_child(help)


# --- Inferiores ----------------------------------------------------------------------

## Las inferiores (Sub-20) de tu club: los que van a subir cuando falte gente
## en el plantel o al cumplir 21.
func _open_youth() -> void:
	_clear(self)
	var lp := WEStyle.panel(Vector2(700, 620))
	lp.position = Vector2(40, 30)
	add_child(lp)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	lp.add_child(left)
	var youth: Array = career.user_youth().duplicate()
	youth.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return MasterCareer.dict_overall(a) > MasterCareer.dict_overall(b))
	left.add_child(WEStyle.label("INFERIORES (SUB-20)  ·  %d jugadores" % youth.size(), 22, GOLD))
	left.add_child(_cells(["", "", "Puesto", "Nombre", "Edad", "Media", "", "", ""], BLUE, 14))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(676, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	left.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 1)
	scroll.add_child(list)
	var rp := WEStyle.panel(Vector2(480, 620))
	rp.position = Vector2(760, 30)
	add_child(rp)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 2)
	rp.add_child(_detail)
	var first: Button = null
	for d in youth:
		var b := Button.new()
		b.custom_minimum_size = Vector2(660, 28)
		WEStyle.style_bar(b)
		var cells := _cells(["", "", String(d.get("pos", "")), String(d.get("n", "")), str(int(d.get("age", 18))),
			str(MasterCareer.dict_overall(d)), "", "", ""], Color.WHITE, 16)
		cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cells.offset_left = 14
		b.add_child(cells)
		b.focus_entered.connect(_youth_detail.bind(d))
		list.add_child(b)
		if first == null:
			first = b
	if youth.is_empty():
		left.add_child(WEStyle.label("Tu club no tiene inferiores cargadas.", 16))
	var back := WEStyle.bar("Volver al plantel", func() -> void: _rebuild.call_deferred(), 676.0, 20)
	left.add_child(back)
	(first if first != null else back).grab_focus()


func _youth_detail(d: Dictionary) -> void:
	_clear(_detail)
	_detail.add_child(WEStyle.label(String(d.get("n", "")), 22, GOLD))
	_detail.add_child(WEStyle.label("%s · %d años · media %d" % [d.get("pos", ""), int(d.get("age", 18)),
		MasterCareer.dict_overall(d)], 15))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	_detail.add_child(grid)
	var a: Dictionary = d.get("a", {})
	for k in a:
		var ai := PlayerData.ATTRIBUTES.find(String(k))
		grid.add_child(WEStyle.label(String(PlayerData.ATTRIBUTE_NAMES[ai]) if ai >= 0 else String(k).capitalize(), 15))
		grid.add_child(WEStyle.label(str(int(a[k])), 15, TeamSheet.attribute_color(int(a[k]))))
	var help := WEStyle.label("Suben solos cuando al plantel le falta gente de su puesto (primero los mejores) o al cumplir 21 años.", 14, Color(0.7, 0.75, 0.85))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(450, 0)
	_detail.add_child(help)


func _close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		if _marked >= 0:
			_marked = -1
			_rebuild.call_deferred()
		else:
			_close()
		get_viewport().set_input_as_handled()
