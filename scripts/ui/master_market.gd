class_name MasterMarket
extends Control
## Mercado de pases de la Liga Master (puntos WE).
##   - Comprar: jugadores de los otros clubes del país, con filtros por
##     puesto y división y orden por media, edad o precio. Comprar al precio
##     que piden, ofertar 80 % (a veces aceptan) o pedirlo a préstamo hasta
##     fin de temporada.
##   - Vender: tus jugadores; un club ofrece puntos (aceptar o no) o se lo
##     deja libre.
##   - Pases: los de esta temporada en todo el país.
## Abre en las primeras 4 fechas, 4 alrededor de la mitad y al terminar la
## temporada.

signal closed

const GOLD := Color(1.0, 0.9, 0.35)
const BLUE := Color(0.6, 0.8, 1.0)
const RED := Color(1.0, 0.55, 0.5)
const GREEN := Color(0.55, 1.0, 0.6)
const MODES := ["Comprar", "Vender", "Pases de la temporada"]
const LINES := ["Todos", "Arqueros", "Defensores", "Volantes", "Delanteros"]
const SORTS := ["ovr", "age", "value"]
const SORT_NAMES := ["Media", "Edad", "Precio"]
const COLS := [210, 190, 46, 52, 54, 80]

var career: MasterCareer
var mode := 0
var line := 0
var division := -1
var sort := 0
var _rows_box: VBoxContainer
var _detail: VBoxContainer
var _items: Array = []
var _focus := 0
var _msg := ""
var _offer: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_rng.randomize()


func open(c: MasterCareer) -> void:
	career = c
	visible = true
	_msg = ""
	_offer = {}
	_focus = 0
	_rebuild()


func _clear(n: Node) -> void:
	for ch in n.get_children():
		n.remove_child(ch)
		ch.queue_free()


func _rebuild() -> void:
	_clear(self)
	var lp := WEStyle.panel(Vector2(720, 620))
	lp.position = Vector2(30, 30)
	add_child(lp)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	lp.add_child(left)
	left.add_child(WEStyle.label("MERCADO DE PASES  ·  %d puntos WE" % career.points, 20, GOLD))
	left.add_child(WEStyle.label(career.market_text(), 16, GREEN if career.market_open() else RED))
	left.add_child(_opt("Ver", func() -> String: return MODES[mode], func(d: int) -> void:
		mode = wrapi(mode + d, 0, MODES.size())
		_focus = 0
		_offer = {}))
	if mode == 0:
		var divs := career.leagues.size()
		left.add_child(_opt("Puesto", func() -> String: return LINES[line], func(d: int) -> void:
			line = wrapi(line + d, 0, LINES.size())
			_focus = 0))
		left.add_child(_opt("División", func() -> String: return "Todas" if division < 0 else career.division_name(division),
			func(d: int) -> void:
				division = wrapi(division + 1 + d, 0, divs + 1) - 1
				_focus = 0))
		left.add_child(_opt("Orden", func() -> String: return SORT_NAMES[sort], func(d: int) -> void:
			sort = wrapi(sort + d, 0, SORTS.size())
			_focus = 0))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(696, 356 if mode == 0 else 446)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	left.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 1)
	scroll.add_child(_rows_box)
	left.add_child(WEStyle.bar("Volver", _close, 696.0, 20))
	var rp := WEStyle.panel(Vector2(470, 620))
	rp.position = Vector2(770, 30)
	add_child(rp)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	rp.add_child(_detail)
	match mode:
		0:
			_buy_list()
		1:
			_sell_list()
		_:
			_transfers_list()


func _opt(caption: String, getter: Callable, step: Callable) -> WEStyle.OptionRow:
	return WEStyle.OptionRow.new(caption, getter, func(d: int) -> void:
		step.call(d)
		_rebuild.call_deferred(), "", 696.0)


func _cells(texts: Array, color: Color, fs: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 6)
	for k in texts.size():
		var l := WEStyle.label(String(texts[k]), fs, color)
		l.custom_minimum_size = Vector2(COLS[k], 0)
		l.clip_text = true
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
	return h


func _row(texts: Array, color: Color, i: int, on_focus: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(680, 27)
	WEStyle.style_bar(b)
	var cells := _cells(texts, color, 15)
	cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cells.offset_left = 14
	b.add_child(cells)
	b.focus_entered.connect(func() -> void:
		if _focus != i:
			_offer = {}
			_msg = ""
		_focus = i
		on_focus.call(i))
	_rows_box.add_child(b)
	return b


func _club_name(club: String) -> String:
	if club == "":
		return "(libre)"
	return TeamDB.load_team(TeamDB.club_path(career.country, club)).team_name


# --- Comprar ------------------------------------------------------------------------------

func _buy_list() -> void:
	_items = career.market_list(line - 1, division, SORTS[sort], 80)
	_rows_box.add_child(_cells(["Jugador", "Club", "Edad", "Pos", "Media", "Precio"], BLUE, 14))
	var first: Button = null
	for i in _items.size():
		var it: Dictionary = _items[i]
		var d: Dictionary = it["d"]
		var b := _row([d["n"], _club_name(it["club"]), str(int(d.get("age", 0))), String(d.get("pos", "")),
			str(MasterCareer.dict_overall(d)), str(career.asking_price(it["club"], d))], Color.WHITE, i, _show_buy)
		if i == mini(_focus, _items.size() - 1):
			first = b
	if first != null:
		first.grab_focus()
	else:
		_detail.add_child(WEStyle.label("No hay jugadores con esos filtros.", 17))


func _player_card(d: Dictionary, club: String) -> void:
	_detail.add_child(WEStyle.label(String(d["n"]), 22, GOLD))
	_detail.add_child(WEStyle.label("%s · %d años · media %d · %s" % [d.get("pos", ""), int(d.get("age", 0)),
		MasterCareer.dict_overall(d), _club_name(club)], 15))
	var a: Dictionary = d.get("a", {})
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 0)
	_detail.add_child(grid)
	for k in PlayerData.ATTRIBUTES.size():
		var attr: String = PlayerData.ATTRIBUTES[k]
		if not a.has(attr):
			continue
		var nm := WEStyle.label(PlayerData.ATTRIBUTE_NAMES[k], 13)
		nm.custom_minimum_size = Vector2(150, 0)
		grid.add_child(nm)
		grid.add_child(WEStyle.label(str(int(a[attr])), 13, TeamSheet.attribute_color(int(a[attr]))))


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
	_detail.add_child(WEStyle.bar("Comprar: %d puntos" % price, func() -> void:
		_after(career.buy(club, pid), "¡Fichado! %s ya es tuyo." % d["n"]), 440.0, 19))
	_detail.add_child(WEStyle.bar("Ofertar 80 %%: %d puntos" % int(price * MasterCareer.LOWBALL_SHARE), func() -> void:
		var r := career.lowball(club, pid, _rng)
		if r == "aceptada":
			_after("", "¡Aceptaron! %s ya es tuyo." % d["n"])
		elif r == "rechazada":
			_msg = "Rechazaron la oferta."
			_rebuild.call_deferred()
		else:
			_after(r, ""), 440.0, 19))
	_detail.add_child(WEStyle.bar("Préstamo hasta fin de temporada: %d" % career.loan_price(d), func() -> void:
		_after(career.loan_in(club, pid), "%s llega a préstamo." % d["n"]), 440.0, 19))
	if _msg != "":
		_detail.add_child(_note(_msg, GREEN if _msg.begins_with("¡") else RED))


func _note(text: String, color: Color) -> Label:
	var l := WEStyle.label(text, 16, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	return l


## Después de una operación: guarda y muestra el resultado.
func _after(err: String, ok_text: String) -> void:
	_msg = err if err != "" else ok_text
	if err == "":
		career.save()
	_rebuild.call_deferred()


# --- Vender -------------------------------------------------------------------------------

func _sell_list() -> void:
	_items = career.club_players(career.user_club).duplicate()
	_items.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return MasterCareer.dict_overall(x) > MasterCareer.dict_overall(y))
	_rows_box.add_child(_cells(["Jugador", "", "Edad", "Pos", "Media", "Valor"], BLUE, 14))
	var first: Button = null
	for i in _items.size():
		var d: Dictionary = _items[i]
		var note := "a préstamo" if d.has("loan_from") else ""
		var b := _row([d["n"], note, str(int(d.get("age", 0))), String(d.get("pos", "")), str(MasterCareer.dict_overall(d)),
			str(MasterCareer.player_value(d))], BLUE if note != "" else Color.WHITE, i, _show_sell)
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
		_detail.add_child(WEStyle.bar("Devolverlo ahora", func() -> void:
			_after(career.release(pid), "Volvió a su club."), 440.0, 19))
	else:
		if _offer.is_empty() or int(_offer.get("pid", -1)) != pid:
			_detail.add_child(WEStyle.bar("Buscar comprador", func() -> void:
				if not career.market_open():
					_msg = "El mercado está cerrado."
				else:
					_offer = career.sell_offer(pid, _rng)
					_offer["pid"] = pid
					_msg = "" if _offer.has("club") else "Nadie lo quiere por ahora."
				_rebuild.call_deferred(), 440.0, 19))
		else:
			_detail.add_child(_note("%s ofrece %d puntos." % [_club_name(_offer["club"]), int(_offer["price"])], GOLD))
			var off := _offer
			_detail.add_child(WEStyle.bar("Aceptar", func() -> void:
				_offer = {}
				_after(career.sell(pid, off["club"], int(off["price"])), "Vendido a %s." % _club_name(off["club"])), 440.0, 19))
			_detail.add_child(WEStyle.bar("Rechazar", func() -> void:
				_offer = {}
				_msg = ""
				_rebuild.call_deferred(), 440.0, 19))
		_detail.add_child(WEStyle.bar("Dejarlo libre", func() -> void:
			_after(career.release(pid), "%s quedó libre." % d["n"]), 440.0, 19))
	if _msg != "":
		_detail.add_child(_note(_msg, GREEN if not _msg.begins_with("No") and not _msg.begins_with("El") else RED))


# --- Pases de la temporada -------------------------------------------------------------------

func _transfers_list() -> void:
	_items = career.season_transfers()
	_rows_box.add_child(_cells(["Jugador", "De", "", "", "", "Puntos"], BLUE, 14))
	var kinds := {"compra": "compra", "préstamo": "préstamo", "venta": "venta", "libre": "libre", "ia": "", "vuelta": "vuelve"}
	var first: Button = null
	for i in _items.size():
		var t: Dictionary = _items[i]
		var mine: bool = t["from"] == career.user_club or t["to"] == career.user_club
		var b := _row([t["n"], "%s → %s" % [_club_name(t["from"]), _club_name(t["to"])], "", "", String(kinds.get(t["kind"], "")),
			str(t["price"]) if int(t["price"]) > 0 else ""], GOLD if mine else Color.WHITE, i, func(_i: int) -> void: pass)
		(b.get_child(0).get_child(1) as Label).custom_minimum_size.x = 300
		if first == null:
			first = b
	if first != null:
		first.grab_focus()
	_clear(_detail)
	_detail.add_child(_note("Los pases de esta temporada en todo el país. En dorado, los de tu club. Los otros clubes se refuerzan en la pretemporada y a mitad de temporada.", Color(0.8, 0.85, 0.95)))
	if _items.is_empty():
		_detail.add_child(WEStyle.label("Todavía no hubo pases.", 17))


func _close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
