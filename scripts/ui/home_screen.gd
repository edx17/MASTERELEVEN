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
## options, quit, continue, new_master, league, world, youth, training} y
## resume(archivo) para retomar una partida.
##
## La tarjeta del próximo partido y "Tu club" salen de la partida más
## reciente (la primera de Continuar); "Continuar" la retoma directo y, si
## hay más, "Otras partidas" abre la lista. Sin partidas, lo dice y el botón
## principal empieza una Liga Master.

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
var others_button: Button
var _last_item: Button
## Partida destacada (ver featured_match) o {}.
var featured: Dictionary = {}
var _match_box: VBoxContainer
var _club_box: VBoxContainer


func _init(p_actions: Dictionary = {}) -> void:
	actions = p_actions
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


## El próximo partido de la partida más reciente (la que retoma "Continuar"):
## {file, mode, user, home, away, venue, competition, round, season, status,
## saves}. {} si no hay partidas guardadas.
static func featured_match() -> Dictionary:
	var saves := Competition.list_saves()
	saves.append_array(MasterCareer.list_saves())
	if saves.is_empty():
		return {}
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["updated"]) > String(b["updated"]))
	var info := match_info(String(saves[0]["file"]))
	if not info.is_empty():
		info["saves"] = saves.size()
	return info


## Datos de una partida guardada (Liga Master o Liga / Copa / Mundial), con
## los equipos de su Option File.
static func match_info(file: String) -> Dictionary:
	var prev := TeamDB.option_file
	var out := {"file": file}
	if MasterCareer.is_career_file(file):
		var m := MasterCareer.load_saved(file)
		if m == null:
			return {}
		m.activate()
		out["mode"] = "Liga Master"
		out["user"] = m.user_team()
		out["season"] = "Temporada %s" % m.year_label()
		out["competition"] = m.current_comp_name()
		out["round"] = m.round_text()
		var g := m.user_match()
		if not g.is_empty():
			var comp := m.current_comp()
			out["home"] = comp.team(g["home"])
			out["away"] = comp.team(g["away"])
			out["venue"] = "Local" if comp.team_paths[g["home"]] == m.user_path() else "Visitante"
		else:
			out["status"] = "Temporada terminada" if m.season_over else "Tu equipo no juega esta fecha"
	else:
		var c := Competition.load_saved(file)
		if c == null:
			return {}
		var cur := prev.name if prev != null else ""
		if c.option_file != cur:
			TeamDB.use_option_file(OptionFile.load_named(c.option_file) if c.option_file != "" else null)
		out["mode"] = "Mundial" if c.kind == Competition.Kind.WORLD_CUP else String(Competition.KIND_NAMES[c.kind])
		out["user"] = c.team(c.user_team)
		out["competition"] = c.title if c.title != "" else c.default_title()
		out["round"] = c.progress_text()
		out["season"] = String(out["mode"])
		var g := c.user_match()
		if not g.is_empty():
			out["home"] = c.team(g["home"])
			out["away"] = c.team(g["away"])
			out["venue"] = "Local" if g["home"] == c.user_team else "Visitante"
		else:
			out["status"] = "Terminada" if c.finished() else "Tu equipo quedó eliminado"
	TeamDB.use_option_file(prev)
	return out


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
	# Próximo partido (se arma en refresh con la partida más reciente).
	_match_box = VBoxContainer.new()
	_match_box.add_theme_constant_override("separation", int(WEStyle.px(12)))
	v.add_child(_match_box)
	# Botón principal.
	continue_button = Button.new()
	continue_button.text = "Continuar  ›"
	continue_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	continue_button.custom_minimum_size.y = WEStyle.px(WEStyle.SIDE_ITEM_H) * 0.82
	continue_button.focus_mode = Control.FOCUS_ALL
	WEStyle.style_primary_button(continue_button, WEStyle.TITLE_M)
	continue_button.pressed.connect(_on_continue)
	continue_button.gui_input.connect(_back_to_menu)
	v.add_child(continue_button)
	others_button = Button.new()
	others_button.text = "Otras partidas  ›"
	others_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	others_button.custom_minimum_size.y = WEStyle.px(48)
	others_button.focus_mode = Control.FOCUS_ALL
	WEStyle.style_button(others_button, WEStyle.BODY_L)
	others_button.pressed.connect(_run.bind("continue"))
	others_button.gui_input.connect(_back_to_menu)
	others_button.visible = false
	v.add_child(others_button)
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


## Columna derecha: tu club (el de la partida más reciente); se llena en refresh.
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
	_club_box = v
	return h


## Al abrir el menú: la partida más reciente arma la tarjeta y "Tu club";
## sin partidas, "Empezar Liga Master".
func refresh(_has_saves: bool = true) -> void:
	featured = featured_match()
	_fill_match()
	_fill_club()
	continue_button.text = "Continuar  ›" if not featured.is_empty() else "Empezar Liga Master  ›"
	others_button.visible = int(featured.get("saves", 0)) > 1


func _on_continue() -> void:
	if featured.is_empty():
		_run("new_master")
		return
	var cb: Callable = actions.get("resume", Callable())
	if cb.is_valid():
		cb.call(String(featured["file"]))
	else:
		_run("continue")


func _fill_match() -> void:
	WEStyle.clear_children(_match_box)
	_match_box.add_child(WEStyle.make_caption_label("Tu próximo partido"))
	if featured.is_empty():
		_match_box.add_child(WEStyle.make_title_label("SIN PARTIDAS GUARDADAS", WEStyle.TITLE_XL))
		var l := WEStyle.make_body_label("Empezá una Liga Master, o una liga, copa o Mundial desde Otros modos.",
			WEStyle.BODY_L, WEStyle.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_match_box.add_child(l)
		return
	var user: TeamData = featured.get("user")
	var home: TeamData = featured.get("home")
	var away: TeamData = featured.get("away")
	_match_box.add_child(WEStyle.make_title_label(user.team_name.to_upper() if user != null else "", WEStyle.TITLE_XL))
	var parts := [String(featured.get("competition", "")), String(featured.get("round", ""))]
	if featured.has("venue"):
		parts.append(String(featured["venue"]))
	var info := WEStyle.make_body_label("  /  ".join(parts), WEStyle.BODY_L, WEStyle.TEXT_DIM)
	info.clip_text = true
	_match_box.add_child(info)
	# Tarjeta del partido: escudos de 160 px y VS en Bebas 64.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", WEStyle.make_panel_style())
	_match_box.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", int(WEStyle.px(16)))
	card.add_child(cv)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(WEStyle.px(48)))
	cv.add_child(row)
	if home != null and away != null:
		row.add_child(_team_block(home))
		var vs := WEStyle.make_title_label("VS", WEStyle.TITLE_XL, WEStyle.TEXT_DIM)
		vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(vs)
		row.add_child(_team_block(away))
	else:
		# Sin partido en la fecha: tu escudo y el estado de la partida.
		row.add_child(_team_block(user))
		var st := WEStyle.make_title_label(String(featured.get("status", "")).to_upper(), WEStyle.TITLE_M, WEStyle.TEXT_DIM)
		st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(st)
	cv.add_child(WEStyle.make_separator())
	var st_row := HBoxContainer.new()
	st_row.add_child(WEStyle.make_caption_label("Estadio"))
	st_row.add_child(WEStyle.make_gap())
	var venue_team := home if home != null else user
	st_row.add_child(WEStyle.make_body_label(venue_team.stadium if venue_team != null and venue_team.stadium != "" else "—", WEStyle.BODY_L))
	cv.add_child(st_row)


func _fill_club() -> void:
	WEStyle.clear_children(_club_box)
	_club_box.add_child(WEStyle.make_caption_label("Tu club", WEStyle.ACCENT))
	if featured.is_empty():
		var l := WEStyle.make_body_label("Todavía no hay una partida en curso.", WEStyle.BODY_L, WEStyle.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_club_box.add_child(l)
		return
	var t: TeamData = featured.get("user")
	_club_box.add_child(WEStyle.make_title_label(t.team_name.to_upper() if t != null else "", WEStyle.TITLE_L))
	_club_box.add_child(WEStyle.make_body_label(String(featured.get("season", "")), WEStyle.BODY_L, WEStyle.TEXT_DIM))
	_club_box.add_child(WEStyle.make_separator())
	for pair in [["Modo", String(featured.get("mode", ""))], ["Competición", String(featured.get("competition", ""))],
			["Estadio", t.stadium if t != null and t.stadium != "" else "—"],
			["Capacidad", WEStyle.thousands(t.capacity) if t != null and t.capacity > 0 else "—"]]:
		_club_box.add_child(WEStyle.make_caption_label(String(pair[0])))
		var text := String(pair[1])
		var val: Label
		if text.length() > 18:
			# Nombres largos (estadios): texto común, en dos líneas si hace falta.
			val = WEStyle.make_body_label(text, WEStyle.BODY_L)
			val.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
			val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			val.custom_minimum_size.x = WEStyle.px(340)
		else:
			val = WEStyle.make_title_label(text.to_upper(), WEStyle.TITLE_M)
		_club_box.add_child(val)


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
