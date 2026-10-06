class_name HomeScreen
extends Control
## Menú principal, diseño 01 "Central de partido" (rediseño estadio de noche).
##
## Encabezado con el nombre del juego; abajo, un HBoxContainer con el menú
## lateral (420 px de 1080p, ítems de 72 px en Bebas 32) y la zona de
## contenido: tarjeta del próximo partido (escudos de 160 px, VS en Bebas
## 64), el botón principal (Continuar) y los otros modos; a la derecha, tu
## club. Pie con las indicaciones de control según el dispositivo.
##
## Navegación: arriba/abajo recorre el menú (circular, MenuNav); derecha entra
## al contenido y desde su borde izquierdo, izquierda vuelve al último ítem
## del menú. Todos los estilos salen de WEStyle.
##
## Las acciones las pone el menú principal: {friendly, master, cup, editor,
## options, quit, continue, new_master, league, world, youth, training}.

## Ítems del menú lateral: [clave de la acción, texto].
const MENU := [["friendly", "Partido amistoso"], ["master", "Liga Master"], ["cup", "Copa"],
	["editor", "Editar"], ["options", "Opciones"], ["quit", "Salir"]]
## Otros modos (abajo del contenido): [acción, título, detalle].
const OTHER_MODES := [["league", "Liga", "Todos contra todos"], ["world", "Mundial", "48 selecciones"],
	["youth", "Sub-20", "Inferiores y juveniles"], ["training", "Entrenamiento", "Club House"]]

var actions: Dictionary = {}
var continue_button: Button
var menu_items: Array[Button] = []
var mode_cards: Array[Button] = []
var _last_item: Button
var _has_saves := false


func _init(p_actions: Dictionary = {}) -> void:
	actions = p_actions
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


## Datos del próximo partido. Ilustrativos por ahora (un clásico de la base);
## en una etapa siguiente salen de la Liga Master guardada.
static func featured_match() -> Dictionary:
	return {"home": TeamDB.club_path("arg", "boca"), "away": TeamDB.club_path("arg", "river"),
		"competition": "Liga Profesional", "round": "Fecha 1", "venue": "Local"}


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = WEStyle.BG_NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 0)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", int(WEStyle.px(WEStyle.MARGIN_X)))
	margin.add_theme_constant_override("margin_right", int(WEStyle.px(WEStyle.MARGIN_X)))
	margin.add_theme_constant_override("margin_top", int(WEStyle.px(WEStyle.MARGIN_Y)))
	margin.add_theme_constant_override("margin_bottom", int(WEStyle.px(24)))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(WEStyle.px(24)))
	margin.add_child(col)
	col.add_child(_header())
	col.add_child(WEStyle.make_separator())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(WEStyle.px(40)))
	col.add_child(body)
	body.add_child(_side_menu())
	body.add_child(_content())
	body.add_child(_club_column())
	outer.add_child(WEStyle.HintFooter.new("01  /  Central de partido",
		[[&"ui_accept", "Aceptar"], [&"ui_navigate", "Navegar"]]))


func _header() -> Control:
	var h := HBoxContainer.new()
	h.add_child(WEStyle.make_title_label("MASTER ELEVEN", WEStyle.TITLE_L))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(gap)
	var crumb := WEStyle.make_body_label("MENÚ PRINCIPAL", WEStyle.BODY_L, WEStyle.TEXT_DIM)
	crumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(crumb)
	return h


func _side_menu() -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = WEStyle.px(WEStyle.SIDE_MENU_W)
	v.add_theme_constant_override("separation", 0)
	v.add_child(WEStyle.make_caption_label("Central de juego", WEStyle.ACCENT))
	var sp := Control.new()
	sp.custom_minimum_size.y = WEStyle.px(16)
	v.add_child(sp)
	for it in MENU:
		var b := Button.new()
		b.text = String(it[1])
		b.custom_minimum_size = Vector2(WEStyle.px(WEStyle.SIDE_MENU_W), WEStyle.px(WEStyle.SIDE_ITEM_H))
		b.focus_mode = Control.FOCUS_ALL
		WEStyle.style_menu_item(b)
		b.pressed.connect(_run.bind(String(it[0])))
		b.focus_entered.connect(func() -> void: _last_item = b)
		v.add_child(b)
		menu_items.append(b)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	v.add_child(WEStyle.make_body_label("Fútbol de los de antes", WEStyle.BODY_M, WEStyle.TEXT_DIM, true))
	_last_item = menu_items[0]
	return v


func _content() -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", int(WEStyle.px(12)))
	var m := featured_match()
	var home := TeamDB.load_team(String(m["home"]))
	var away := TeamDB.load_team(String(m["away"]))
	v.add_child(WEStyle.make_caption_label("Tu próximo partido"))
	v.add_child(WEStyle.make_title_label(home.team_name.to_upper() if home != null else "", WEStyle.TITLE_XL))
	v.add_child(WEStyle.make_body_label("%s  /  %s  /  %s" % [m["competition"], m["round"], m["venue"]],
		WEStyle.BODY_L, WEStyle.TEXT_DIM))
	# Tarjeta del partido: escudos de 160 px y VS en Bebas 64.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", WEStyle.make_panel_style())
	v.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", int(WEStyle.px(16)))
	card.add_child(cv)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(WEStyle.px(48)))
	cv.add_child(row)
	row.add_child(_team_block(home))
	var vs := WEStyle.make_title_label("VS", WEStyle.TITLE_XL, WEStyle.TEXT_DIM)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vs)
	row.add_child(_team_block(away))
	cv.add_child(WEStyle.make_separator())
	var st := HBoxContainer.new()
	st.add_child(WEStyle.make_caption_label("Estadio"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.add_child(gap)
	st.add_child(WEStyle.make_body_label(home.stadium if home != null else "", WEStyle.BODY_L))
	cv.add_child(st)
	# Botón principal.
	continue_button = Button.new()
	continue_button.text = "Continuar  ›"
	continue_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	continue_button.custom_minimum_size.y = WEStyle.px(WEStyle.SIDE_ITEM_H) * 0.82
	continue_button.focus_mode = Control.FOCUS_ALL
	WEStyle.style_primary_button(continue_button, WEStyle.TITLE_M)
	continue_button.pressed.connect(func() -> void: _run("continue" if _has_saves else "new_master"))
	continue_button.gui_input.connect(_back_to_menu)
	v.add_child(continue_button)
	# Otros modos.
	var sp := Control.new()
	sp.custom_minimum_size.y = WEStyle.px(8)
	v.add_child(sp)
	v.add_child(WEStyle.make_caption_label("Otros modos"))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", int(WEStyle.px(16)))
	v.add_child(modes)
	for i in OTHER_MODES.size():
		var it: Array = OTHER_MODES[i]
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = WEStyle.px(88)
		b.focus_mode = Control.FOCUS_ALL
		WEStyle.style_button(b)
		var lv := VBoxContainer.new()
		lv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lv.offset_left = WEStyle.px(WEStyle.BUTTON_PADDING_X)
		lv.offset_top = WEStyle.px(12)
		lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lv.add_theme_constant_override("separation", 0)
		var t := WEStyle.make_title_label(String(it[1]).to_upper(), WEStyle.TITLE_M)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lv.add_child(t)
		var d := WEStyle.make_body_label(String(it[2]), WEStyle.BODY_M, WEStyle.TEXT_DIM)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lv.add_child(d)
		b.add_child(lv)
		b.pressed.connect(_run.bind(String(it[0])))
		if i == 0:
			b.gui_input.connect(_back_to_menu)
		modes.add_child(b)
		mode_cards.append(b)
	return v


func _team_block(t: TeamData) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(WEStyle.px(12)))
	var crest := WEStyle.Crest.new()
	crest.team = t
	crest.label_font = WEStyle.font(WEStyle.Typeface.TITLE)
	crest.custom_minimum_size = Vector2.ONE * WEStyle.px(160)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(crest)
	var n := WEStyle.make_body_label(t.team_name if t != null else "", WEStyle.BODY_L)
	n.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	return v


## Columna derecha: tu club (por ahora el del partido ilustrativo).
func _club_column() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(WEStyle.px(40)))
	var line := ColorRect.new()
	line.color = WEStyle.LINE
	line.custom_minimum_size.x = WEStyle.BORDER
	h.add_child(line)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = WEStyle.px(340)
	v.add_theme_constant_override("separation", int(WEStyle.px(10)))
	h.add_child(v)
	var m := featured_match()
	var t := TeamDB.load_team(String(m["home"]))
	v.add_child(WEStyle.make_caption_label("Tu club", WEStyle.ACCENT))
	v.add_child(WEStyle.make_title_label(t.team_name.to_upper() if t != null else "", WEStyle.TITLE_L))
	v.add_child(WEStyle.make_body_label("Temporada 2026", WEStyle.BODY_L, WEStyle.TEXT_DIM))
	v.add_child(WEStyle.make_separator())
	for pair in [["Competición", String(m["competition"])], ["Estadio", t.stadium if t != null else ""],
			["Capacidad", WEStyle.thousands(t.capacity) if t != null and t.capacity > 0 else "—"]]:
		v.add_child(WEStyle.make_caption_label(String(pair[0])))
		v.add_child(WEStyle.make_title_label(String(pair[1]).to_upper(), WEStyle.TITLE_M))
	return h


## Al abrir: si hay partidas guardadas, "Continuar"; si no, empezar una Liga Master.
func refresh(has_saves: bool) -> void:
	_has_saves = has_saves
	continue_button.text = "Continuar  ›" if has_saves else "Empezar Liga Master  ›"


func _ready() -> void:
	# Derecha desde el menú entra al contenido.
	for b in menu_items:
		b.focus_neighbor_right = b.get_path_to(continue_button)
	WEStyle.fade_in(self)


## Desde el borde izquierdo del contenido, izquierda vuelve al menú.
func _back_to_menu(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left") and _last_item != null:
		_last_item.grab_focus()
		get_viewport().set_input_as_handled()


func _run(key: String) -> void:
	var cb: Callable = actions.get(key, Callable())
	if cb.is_valid():
		cb.call()
