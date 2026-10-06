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

const GOLD := WEStyle.ACCENT
const BLUE := WEStyle.TEXT_DIM
const RED := WEStyle.DANGER
const GREEN := WEStyle.ACCENT_GREEN
## Columnas de la lista: ancho (px de 1080; 0 = se estira) y alineación.
const COLS := [28, 48, 72, 0, 64, 72, 64, 64, 96]
const ALIGN := "CRLLRRRRL"
const HINTS := [[&"ui_accept", "Marcar / cambiar"], [&"ui_navigate", "Formación"], [&"ui_cancel", "Volver"]]

var career: MasterCareer
var _frame: WEStyle.ScreenFrame
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
	_frame = WEStyle.ScreenFrame.new("Plantel", HINTS)
	add_child(_frame)


func open(c: MasterCareer) -> void:
	career = c
	_marked = -1
	visible = true
	_rebuild()
	WEStyle.fade_in(_frame)


func _clear(n: Node) -> void:
	for ch in n.get_children():
		n.remove_child(ch)
		ch.queue_free()


## Arma el cuerpo con dos columnas: la lista (expande) y la ficha (tarjeta).
func _columns() -> VBoxContainer:
	_clear(_frame.body)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", int(WEStyle.px(40)))
	_frame.body.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", int(WEStyle.px(8)))
	row.add_child(left)
	var card := WEStyle.make_card()
	card.custom_minimum_size.x = WEStyle.px(620)
	row.add_child(card)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", int(WEStyle.px(6)))
	card.add_child(_detail)
	return left


func _scroll(left: VBoxContainer) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	left.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	return list


func _section(text: String) -> Label:
	var l := WEStyle.make_caption_label(text)
	l.custom_minimum_size.y = WEStyle.px(WEStyle.HEADER_ROW_H)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


func _rebuild() -> void:
	_rows.clear()
	var t := career.user_team()
	_players = t.players
	_frame.crumb.text = "LIGA MASTER  /  PLANTEL"
	_frame.title.text = "PLANTEL Y FORMACIÓN"
	_frame.title_info.text = "%s · %s" % [t.team_name, career.formation_name()]
	_frame.footer.set_hints(HINTS)
	var left := _columns()
	var forms := MasterCareer.FORMATIONS
	var frow := WEStyle.OptionRow.new("Formación", func() -> String: return career.formation_name(),
		func(dir: int) -> void:
			var i := forms.find(career.formation_name())
			career.set_formation(forms[wrapi(i + dir, 0, forms.size())])
			career.save()
			_marked = -1
			_rebuild.call_deferred(), "", WEStyle.px(1000))
	frow.use_modern_style()
	left.add_child(frow)
	left.add_child(_header(["", "N°", "Puesto", "Nombre", "Edad", "Media", "Evol.", "Goles", "Estado"]))
	_list = _scroll(left)
	_list.add_child(_section("Titulares"))
	for i in _players.size():
		_list.add_child(_row(i))
		if i == 10:
			_list.add_child(_section("Suplentes"))
		if i == 22 and _players.size() > 23:
			_list.add_child(_section("Fuera de la lista (al partido van 23)"))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", int(WEStyle.px(16)))
	left.add_child(btns)
	for spec in [["Mejor once", func() -> void:
			career.auto_lineup()
			career.save()
			_marked = -1
			_rebuild.call_deferred()], ["Inferiores", _open_youth], ["Volver", _close]]:
		var b := WEStyle.make_action_button(spec[0], spec[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns.add_child(b)
	var focus_i := 0
	for i in _players.size():
		if _players[i].pid == _focus_pid:
			focus_i = i
	if not _rows.is_empty():
		_rows[focus_i].grab_focus()
		_show_detail(focus_i)


## Fila de celdas con las columnas de COLS.
func _cells(texts: Array, color: Color, _fs: int = 0, header: bool = false) -> HBoxContainer:
	return WEStyle.make_cells(texts, COLS, ALIGN, header, color)


## Encabezado de la tabla, con el mismo margen que las filas.
func _header(texts: Array) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(WEStyle.px(12)))
	m.add_theme_constant_override("margin_right", int(WEStyle.px(12)))
	m.custom_minimum_size.y = WEStyle.px(WEStyle.HEADER_ROW_H)
	m.add_child(_cells(texts, BLUE, 0, true))
	return m


func _row(i: int) -> Button:
	var p := _players[i]
	var d := career.user_player_dict(p.pid)
	var status := ""
	if int(d.get("inj", 0)) > 0:
		status = "LES %d" % int(d["inj"])
	elif int(d.get("susp", 0)) > 0:
		status = "SUS %d" % int(d["susp"])
	var mark := "▶" if i == _marked else ("●" if i < 11 else "")
	var c := RED if status != "" else (GOLD if i == _marked else WEStyle.TEXT_MAIN)
	var ev := career.overall_delta(p.pid)
	var cells := _cells([mark, str(p.number), p.role_code, p.player_name, str(p.get_age()),
		str(roundi(TeamDB.overall(p))), ("%+d" % ev) if ev != 0 else "", str(career.goals_of(p.pid)), status], c)
	(cells.get_child(0) as Label).add_theme_color_override("font_color", GOLD if i == _marked else GREEN)
	if ev != 0:
		(cells.get_child(6) as Label).add_theme_color_override("font_color", GREEN if ev > 0 else RED)
	var b := WEStyle.make_row_button(cells, i == _marked)
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
	_detail.add_child(WEStyle.make_caption_label("%s · N° %d" % [p.role_code, p.number], GOLD))
	_detail.add_child(WEStyle.make_title_label(p.player_name.to_upper(), WEStyle.TITLE_M))
	_detail.add_child(WEStyle.make_body_label("%d años · %d cm · %s · media %d" % [p.get_age(), p.height_cm(),
		["diestro", "zurdo", "ambidiestro"][clampi(p.foot, 0, 2)], roundi(TeamDB.overall(p))], WEStyle.BODY_M, WEStyle.TEXT_DIM))
	var st := "Titular" if i < 11 else "Suplente"
	if int(d.get("inj", 0)) > 0:
		st = "Lesionado: %d fecha%s" % [int(d["inj"]), "" if int(d["inj"]) == 1 else "s"]
	elif int(d.get("susp", 0)) > 0:
		st = "Suspendido: %d fecha%s" % [int(d["susp"]), "" if int(d["susp"]) == 1 else "s"]
	_detail.add_child(WEStyle.make_body_label("%s · Goles: %d · Amarillas: %d" % [st, career.goals_of(p.pid), int(d.get("yc", 0))],
		WEStyle.BODY_M, RED if st.begins_with("Les") or st.begins_with("Sus") else WEStyle.TEXT_MAIN))
	_detail.add_child(WEStyle.make_separator())
	_detail.add_child(WEStyle.make_caption_label("Atributos · cambio en la temporada"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", int(WEStyle.px(16)))
	grid.add_theme_constant_override("v_separation", 0)
	_detail.add_child(grid)
	for k in PlayerData.ATTRIBUTES.size():
		var attr: String = PlayerData.ATTRIBUTES[k]
		var v := int(p.get(attr))
		var delta := career.attr_delta(p.pid, attr, v)
		var name := WEStyle.make_body_label(PlayerData.ATTRIBUTE_NAMES[k], WEStyle.BODY_M, WEStyle.TEXT_DIM)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name)
		var val := WEStyle.make_body_label(str(v), WEStyle.BODY_M, TeamSheet.attribute_color(v))
		val.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.custom_minimum_size.x = WEStyle.px(40)
		grid.add_child(val)
		var dl := WEStyle.make_body_label(("%+d" % delta) if delta != 0 else "", WEStyle.BODY_M, GREEN if delta > 0 else RED)
		dl.custom_minimum_size.x = WEStyle.px(40)
		grid.add_child(dl)
	# Media de cada temporada (se anota en el cambio de año).
	var hist: Array = d.get("hist", [])
	if not hist.is_empty():
		var parts: Array = hist.slice(maxi(0, hist.size() - 5)).map(func(h: Array) -> String: return "%s: %d" % [h[0], int(h[1])])
		_detail.add_child(_note("Media por temporada: " + "  ·  ".join(parts)))
	_detail.add_child(_note("Aceptar sobre un jugador y después sobre otro: se cambian (queda guardado para los próximos partidos). Rojo: lesionado o suspendido; si es titular, juega el mejor libre de su puesto."))


## Nota en Barlow Italic (texto secundario con salto de línea).
func _note(text: String) -> Label:
	var l := WEStyle.make_body_label(text, WEStyle.BODY_S, WEStyle.TEXT_DIM, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = WEStyle.px(560)
	return l


# --- Inferiores ----------------------------------------------------------------------

## Las inferiores (Sub-20) de tu club: los que van a subir cuando falte gente
## en el plantel o al cumplir 21.
func _open_youth() -> void:
	_rows.clear()
	var youth: Array = career.user_youth().duplicate()
	youth.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return MasterCareer.dict_overall(a) > MasterCareer.dict_overall(b))
	_frame.crumb.text = "LIGA MASTER  /  PLANTEL  /  INFERIORES"
	_frame.title.text = "INFERIORES (SUB-20)"
	_frame.title_info.text = "%d jugadores" % youth.size()
	_frame.footer.set_hints([[&"ui_navigate", "Navegar"], [&"ui_cancel", "Volver"]])
	var left := _columns()
	left.add_child(_header(["", "", "Puesto", "Nombre", "Edad", "Media", "", "", ""]))
	var list := _scroll(left)
	var first: Button = null
	for d in youth:
		var cells := _cells(["", "", String(d.get("pos", "")), String(d.get("n", "")), str(int(d.get("age", 18))),
			str(MasterCareer.dict_overall(d)), "", "", ""], WEStyle.TEXT_MAIN)
		var b := WEStyle.make_row_button(cells)
		b.focus_entered.connect(_youth_detail.bind(d))
		list.add_child(b)
		if first == null:
			first = b
	if youth.is_empty():
		left.add_child(WEStyle.make_body_label("Tu club no tiene inferiores cargadas.", WEStyle.BODY_L, WEStyle.TEXT_DIM))
	var back := WEStyle.make_action_button("Volver al plantel", func() -> void: _rebuild.call_deferred())
	left.add_child(back)
	(first if first != null else back).grab_focus()


func _youth_detail(d: Dictionary) -> void:
	_clear(_detail)
	_detail.add_child(WEStyle.make_caption_label(String(d.get("pos", "")), GOLD))
	_detail.add_child(WEStyle.make_title_label(String(d.get("n", "")).to_upper(), WEStyle.TITLE_M))
	_detail.add_child(WEStyle.make_body_label("%d años · media %d" % [int(d.get("age", 18)), MasterCareer.dict_overall(d)],
		WEStyle.BODY_M, WEStyle.TEXT_DIM))
	_detail.add_child(WEStyle.make_separator())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(WEStyle.px(16)))
	_detail.add_child(grid)
	var a: Dictionary = d.get("a", {})
	for k in a:
		var ai := PlayerData.ATTRIBUTES.find(String(k))
		var name := WEStyle.make_body_label(String(PlayerData.ATTRIBUTE_NAMES[ai]) if ai >= 0 else String(k).capitalize(),
			WEStyle.BODY_M, WEStyle.TEXT_DIM)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name)
		var val := WEStyle.make_body_label(str(int(a[k])), WEStyle.BODY_M, TeamSheet.attribute_color(int(a[k])))
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)
	_detail.add_child(_note("Suben solos cuando al plantel le falta gente de su puesto (primero los mejores) o al cumplir 21 años."))


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
