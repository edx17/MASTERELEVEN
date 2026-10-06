class_name MasterMarket
extends Control
## Mercado de pases de la Liga Master (puntos WE).
##   - Comprar: jugadores de cualquier club (de tu país o de las ligas de
##     los otros países) y libres, con filtros por puesto, liga y club, y
##     orden por media, edad o precio. Comprar al precio
##     que piden, ofertar 80 % (a veces aceptan) o pedirlo a préstamo hasta
##     fin de temporada.
##   - Vender: tus jugadores; un club ofrece puntos (aceptar o no) o se lo
##     deja libre.
##   - Pases: los de esta temporada en todo el país.
## Abre en las primeras 4 fechas, 4 alrededor de la mitad y al terminar la
## temporada.

signal closed

const GOLD := WEStyle.ACCENT
const BLUE := WEStyle.TEXT_DIM
const RED := WEStyle.DANGER
const GREEN := WEStyle.ACCENT_GREEN
const MODES := ["Comprar", "Vender", "Pases de la temporada"]
const LINES := ["Todos", "Arqueros", "Defensores", "Volantes", "Delanteros"]
const SORTS := ["ovr", "age", "value"]
const SORT_NAMES := ["Media", "Edad", "Precio"]
## Columnas de la lista: ancho (px de 1080; 0 = se estira) y alineación.
const COLS := [0, 320, 64, 64, 72, 110]
const ALIGN := "LLRCRR"
const HINTS := [[&"ui_accept", "Elegir"], [&"ui_navigate", "Filtros"], [&"ui_cancel", "Volver"]]

var career: MasterCareer
var _frame: WEStyle.ScreenFrame
var mode := 0
var line := 0
var division := -1
## Filtro de liga (índice en career.market_scopes()) y de club ("" = todos).
var scope := 0
var club_filter := ""
var _scopes: Array = []
var sort := 0
var _rows_box: VBoxContainer
var _detail: VBoxContainer
var _items: Array = []
var _focus := 0
var _msg := ""
var _offer: Dictionary = {}
var _rng := RandomNumberGenerator.new()
## Fila de opción que se acaba de cambiar (queda con el foco al rearmar) y
## la primera fila de opción (foco si la lista quedó vacía).
var _keep_caption := ""
var _first_opt: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_rng.randomize()
	_frame = WEStyle.ScreenFrame.new("Mercado de pases", HINTS)
	add_child(_frame)
	_frame.crumb.text = "LIGA MASTER  /  MERCADO"
	_frame.title.text = "MERCADO DE PASES"


func open(c: MasterCareer) -> void:
	career = c
	visible = true
	_msg = ""
	_offer = {}
	_focus = 0
	_rebuild()
	WEStyle.fade_in(_frame)


func _clear(n: Node) -> void:
	for ch in n.get_children():
		n.remove_child(ch)
		ch.queue_free()


func _rebuild() -> void:
	_clear(_frame.body)
	_first_opt = null
	_frame.title_info.text = "%s puntos WE" % WEStyle.thousands(career.points)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", int(WEStyle.px(40)))
	_frame.body.add_child(row)
	var left := VBoxContainer.new()
	left.name = "Left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", int(WEStyle.px(8)))
	row.add_child(left)
	left.add_child(WEStyle.make_caption_label(career.market_text(), GREEN if career.market_open() else RED))
	# Filtros en dos columnas (así la lista tiene más alto).
	var opts := GridContainer.new()
	opts.name = "Opts"
	opts.columns = 2
	opts.add_theme_constant_override("h_separation", int(WEStyle.px(16)))
	opts.add_theme_constant_override("v_separation", int(WEStyle.px(4)))
	left.add_child(opts)
	opts.add_child(_opt("Ver", func() -> String: return MODES[mode], func(d: int) -> void:
		mode = wrapi(mode + d, 0, MODES.size())
		_focus = 0
		_offer = {}))
	if mode == 0:
		if _scopes.is_empty():
			_scopes = career.market_scopes()
		opts.add_child(_opt("Puesto", func() -> String: return LINES[line], func(d: int) -> void:
			line = wrapi(line + d, 0, LINES.size())
			_focus = 0))
		opts.add_child(_opt("Liga", func() -> String: return String(_scopes[scope]["label"]), func(d: int) -> void:
			scope = wrapi(scope + d, 0, _scopes.size())
			club_filter = ""
			_focus = 0))
		opts.add_child(_opt("Club", func() -> String: return _club_filter_name(), func(d: int) -> void:
			var opts2 := _club_options()
			var i := opts2.map(func(o: Array) -> String: return o[0]).find(club_filter)
			club_filter = String(opts2[wrapi(i + d, 0, opts2.size())][0])
			_focus = 0))
		opts.add_child(_opt("Orden", func() -> String: return SORT_NAMES[sort], func(d: int) -> void:
			sort = wrapi(sort + d, 0, SORTS.size())
			_focus = 0))
	var head := MarginContainer.new()
	head.add_theme_constant_override("margin_left", int(WEStyle.px(12)))
	head.add_theme_constant_override("margin_right", int(WEStyle.px(12)))
	head.custom_minimum_size.y = WEStyle.px(WEStyle.HEADER_ROW_H)
	left.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	left.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 0)
	scroll.add_child(_rows_box)
	var back := WEStyle.make_action_button("Volver", _close)
	back.name = "Back"
	left.add_child(back)
	var card := WEStyle.make_card()
	card.custom_minimum_size.x = WEStyle.px(640)
	row.add_child(card)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", int(WEStyle.px(8)))
	card.add_child(_detail)
	match mode:
		0:
			_buy_list(head)
		1:
			_sell_list(head)
		_:
			_transfers_list(head)
	# El foco: en la fila que se acaba de cambiar (así se puede seguir
	# cambiándola) o, si la lista quedó vacía, en la primera fila de opción
	# (si no, el mando no tiene dónde moverse).
	var keep := opts.get_node_or_null("Opt" + _keep_caption) if _keep_caption != "" else null
	_keep_caption = ""
	if keep != null:
		(keep as Control).grab_focus()
	elif _rows_box.get_children().filter(func(c: Node) -> bool: return c is Button).is_empty():
		_first_opt.grab_focus()


func _opt(caption: String, getter: Callable, step: Callable) -> WEStyle.OptionRow:
	var row := WEStyle.OptionRow.new(caption, getter, func(d: int) -> void:
		step.call(d)
		_keep_caption = caption
		_rebuild.call_deferred(), "", WEStyle.px(440))
	row.use_modern_style()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.name = "Opt" + caption
	if _first_opt == null:
		_first_opt = row
	return row


func _cells(texts: Array, color: Color, _fs: int = 0, header: bool = false) -> HBoxContainer:
	return WEStyle.make_cells(texts, COLS, ALIGN, header, color)


func _row(texts: Array, color: Color, i: int, on_focus: Callable) -> Button:
	var b := WEStyle.make_row_button(_cells(texts, color))
	b.focus_entered.connect(func() -> void:
		if _focus != i:
			_offer = {}
			_msg = ""
		_focus = i
		on_focus.call(i))
	_rows_box.add_child(b)
	return b


func _club_name(club: String) -> String:
	if club == "" or club == MasterCareer.FREE_CLUB:
		return "(libre)"
	return career._club_name(club)


## Opciones del filtro de club: [club, nombre]; "" = todos, libres aparte.
func _club_options() -> Array:
	var out: Array = [["", "Todos"]]
	if int(_scopes[scope]["division"]) < 0 and String(_scopes[scope]["country"]) == "":
		out.append([MasterCareer.FREE_CLUB, "Libres"])
	out.append_array(career.scope_clubs(_scopes[scope]))
	return out


func _club_filter_name() -> String:
	for o in _club_options():
		if o[0] == club_filter:
			return String(o[1])
	return "Todos"


# --- Comprar ------------------------------------------------------------------------------

func _buy_list(head: Control) -> void:
	var sc: Dictionary = _scopes[scope]
	_items = career.market_list(line - 1, int(sc["division"]), SORTS[sort], 80, String(sc["country"]), club_filter)
	head.add_child(_cells(["Jugador", "Club", "Edad", "Pos", "Media", "Precio"], BLUE, 0, true))
	var first: Button = null
	for i in _items.size():
		var it: Dictionary = _items[i]
		var d: Dictionary = it["d"]
		var b := _row([d["n"], _club_name(it["club"]), str(int(d.get("age", 0))), String(d.get("pos", "")),
			str(MasterCareer.dict_overall(d)), WEStyle.thousands(career.asking_price(it["club"], d))], WEStyle.TEXT_MAIN, i, _show_buy)
		if i == mini(_focus, _items.size() - 1):
			first = b
	if first != null:
		first.grab_focus()
	else:
		_detail.add_child(_note("No hay jugadores con esos filtros.", BLUE))


func _player_card(d: Dictionary, club: String) -> void:
	_detail.add_child(WEStyle.make_caption_label("%s · %s" % [d.get("pos", ""), _club_name(club)], GOLD))
	_detail.add_child(WEStyle.make_title_label(String(d["n"]).to_upper(), WEStyle.TITLE_M))
	_detail.add_child(WEStyle.make_body_label("%d años · media %d" % [int(d.get("age", 0)), MasterCareer.dict_overall(d)],
		WEStyle.BODY_M, WEStyle.TEXT_DIM))
	_detail.add_child(WEStyle.make_separator())
	var a: Dictionary = d.get("a", {})
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", int(WEStyle.px(16)))
	grid.add_theme_constant_override("v_separation", 0)
	_detail.add_child(grid)
	for k in PlayerData.ATTRIBUTES.size():
		var attr: String = PlayerData.ATTRIBUTES[k]
		if not a.has(attr):
			continue
		var nm := WEStyle.make_body_label(PlayerData.ATTRIBUTE_NAMES[k], WEStyle.BODY_M, WEStyle.TEXT_DIM)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		grid.add_child(nm)
		var v := WEStyle.make_body_label(str(int(a[attr])), WEStyle.BODY_M, TeamSheet.attribute_color(int(a[attr])))
		v.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.custom_minimum_size.x = WEStyle.px(36)
		grid.add_child(v)
	_detail.add_child(WEStyle.make_separator())


## Botón de acción de la ficha (el primero, principal).
func _action(text: String, cb: Callable) -> Button:
	var primary := _detail.get_children().filter(func(c: Node) -> bool: return c is Button).is_empty()
	return WEStyle.make_action_button(text, cb, primary)


func _show_buy(i: int) -> void:
	_clear(_detail)
	if i >= _items.size():
		return
	var it: Dictionary = _items[i]
	var d: Dictionary = it["d"]
	var club: String = it["club"]
	_player_card(d, club)
	var price := career.asking_price(club, d)
	var why := career.cannot_buy(club, price)
	if why != "" and _msg == "":
		_detail.add_child(_note(why, RED))
	var pid := int(d["pid"])
	if club == MasterCareer.FREE_CLUB:
		# Libre: sólo la prima de fichaje.
		_detail.add_child(_action("Fichar (libre): %s puntos" % WEStyle.thousands(price), func() -> void:
			_after(career.buy(club, pid), "¡Fichado! %s ya es tuyo." % d["n"])))
		if _msg != "":
			_detail.add_child(_note(_msg, GREEN if _msg.begins_with("¡") else RED))
		return
	_detail.add_child(_action("Comprar: %s puntos" % WEStyle.thousands(price), func() -> void:
		_after(career.buy(club, pid), "¡Fichado! %s ya es tuyo." % d["n"])))
	_detail.add_child(_action("Ofertar 80 %%: %s puntos" % WEStyle.thousands(int(price * MasterCareer.LOWBALL_SHARE)), func() -> void:
		var r := career.lowball(club, pid, _rng)
		if r == "aceptada":
			_after("", "¡Aceptaron! %s ya es tuyo." % d["n"])
		elif r == "rechazada":
			_msg = "Rechazaron la oferta."
			_rebuild.call_deferred()
		else:
			_after(r, "")))
	_detail.add_child(_action("Préstamo hasta fin de temporada: %s" % WEStyle.thousands(career.loan_price(d)), func() -> void:
		_after(career.loan_in(club, pid), "%s llega a préstamo." % d["n"])))
	if _msg != "":
		_detail.add_child(_note(_msg, GREEN if _msg.begins_with("¡") else RED))


func _note(text: String, color: Color) -> Label:
	var l := WEStyle.make_body_label(text, WEStyle.BODY_M, color, color == BLUE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = WEStyle.px(580)
	return l


## Después de una operación: guarda y muestra el resultado.
func _after(err: String, ok_text: String) -> void:
	_msg = err if err != "" else ok_text
	if err == "":
		career.save()
	_rebuild.call_deferred()


# --- Vender -------------------------------------------------------------------------------

func _sell_list(head: Control) -> void:
	_items = career.club_players(career.user_club).duplicate()
	_items.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return MasterCareer.dict_overall(x) > MasterCareer.dict_overall(y))
	head.add_child(_cells(["Jugador", "", "Edad", "Pos", "Media", "Valor"], BLUE, 0, true))
	var first: Button = null
	for i in _items.size():
		var d: Dictionary = _items[i]
		var note := "a préstamo" if d.has("loan_from") else ""
		var b := _row([d["n"], note, str(int(d.get("age", 0))), String(d.get("pos", "")), str(MasterCareer.dict_overall(d)),
			WEStyle.thousands(MasterCareer.player_value(d))], BLUE if note != "" else WEStyle.TEXT_MAIN, i, _show_sell)
		if i == mini(_focus, _items.size() - 1):
			first = b
	if first != null:
		first.grab_focus()


func _show_sell(i: int) -> void:
	_clear(_detail)
	if i >= _items.size():
		return
	var d: Dictionary = _items[i]
	var pid := int(d["pid"])
	_player_card(d, career.user_club)
	if d.has("loan_from"):
		_detail.add_child(_note("Está a préstamo: vuelve a %s al terminar la temporada." % _club_name(String(d["loan_from"])), BLUE))
		_detail.add_child(_action("Devolverlo ahora", func() -> void:
			_after(career.release(pid), "Volvió a su club.")))
	else:
		if _offer.is_empty() or int(_offer.get("pid", -1)) != pid:
			_detail.add_child(_action("Buscar comprador", func() -> void:
				if not career.market_open():
					_msg = "El mercado está cerrado."
				else:
					_offer = career.sell_offer(pid, _rng)
					_offer["pid"] = pid
					_msg = "" if _offer.has("club") else "Nadie lo quiere por ahora."
				_rebuild.call_deferred()))
		else:
			_detail.add_child(_note("%s ofrece %s puntos." % [_club_name(_offer["club"]), WEStyle.thousands(int(_offer["price"]))], GOLD))
			var off := _offer
			_detail.add_child(_action("Aceptar", func() -> void:
				_offer = {}
				_after(career.sell(pid, off["club"], int(off["price"])), "Vendido a %s." % _club_name(off["club"]))))
			_detail.add_child(_action("Rechazar", func() -> void:
				_offer = {}
				_msg = ""
				_rebuild.call_deferred()))
		_detail.add_child(_action("Dejarlo libre", func() -> void:
			_after(career.release(pid), "%s quedó libre." % d["n"])))
	if _msg != "":
		_detail.add_child(_note(_msg, GREEN if not _msg.begins_with("No") and not _msg.begins_with("El") else RED))


# --- Pases de la temporada -------------------------------------------------------------------

func _transfers_list(head: Control) -> void:
	_items = career.season_transfers()
	head.add_child(_cells(["Jugador", "De → a", "", "", "", "Puntos"], BLUE, 0, true))
	(head.get_child(0).get_child(1) as Label).custom_minimum_size.x = WEStyle.px(520)
	var kinds := {"compra": "compra", "préstamo": "préstamo", "venta": "venta", "libre": "libre", "ia": "", "vuelta": "vuelve"}
	var first: Button = null
	for i in _items.size():
		var t: Dictionary = _items[i]
		var mine: bool = t["from"] == career.user_club or t["to"] == career.user_club
		var b := _row([t["n"], "%s → %s" % [_club_name(t["from"]), _club_name(t["to"])], "", "", String(kinds.get(t["kind"], "")),
			WEStyle.thousands(int(t["price"])) if int(t["price"]) > 0 else ""], GOLD if mine else WEStyle.TEXT_MAIN, i, func(_i: int) -> void: pass)
		(b.get_child(0).get_child(1) as Label).custom_minimum_size.x = WEStyle.px(520)
		if first == null:
			first = b
	if first != null:
		first.grab_focus()
	_clear(_detail)
	_detail.add_child(WEStyle.make_caption_label("Pases de la temporada", GOLD))
	_detail.add_child(_note("Los pases de esta temporada en todo el país. En dorado, los de tu club. Los otros clubes se refuerzan en la pretemporada y a mitad de temporada.", BLUE))
	if _items.is_empty():
		_detail.add_child(_note("Todavía no hubo pases.", WEStyle.TEXT_MAIN))


func _close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
