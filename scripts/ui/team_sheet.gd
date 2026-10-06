class_name TeamSheet
extends Control
## Dirección del equipo, al estilo de la pantalla del WE: a la izquierda la
## minicancha con la formación y la lista de los 23 (11 titulares y el banco);
## a la derecha el menú y la ficha del jugador elegido.
##   - L1 / R1 (o Q / E): la columna de la lista pasa por Puesto, Energía y
##     Condición (flechas).
##   - Sustituir (o X sobre la lista): se marca uno y después otro y se
##     intercambian. Dos titulares cambian de puesto; titular y suplente:
##     antes del partido, cambio libre de la alineación; durante el partido,
##     es un cambio (hasta 3).
##   - Tiros libres / Córners / Penales / Capitán: se elige al jugador.
##   - Formación: pasa a la siguiente.
## Se usa en la previa (con "Jugar partido") y en la pausa.

signal closed
signal play_pressed

enum Column { POSITION, ENERGY, CONDITION }
const COLUMN_NAMES := ["Puesto", "Energía", "Condición"]
enum Mode { SUBSTITUTE, CAPTAIN, FK, CK, PK, FK_LONG, CK_RIGHT }
const POS_CODES := ["GK", "DF", "MF", "FW"]
const POS_COLORS := [Color(0.8, 0.72, 0.15), Color(0.2, 0.45, 0.8), Color(0.25, 0.62, 0.32), Color(0.78, 0.22, 0.2)]
## Flechas de condición: rojo arriba, naranja, amarillo, azul, gris abajo.
const CONDITION_COLORS := [Color(0.95, 0.15, 0.12), Color(1.0, 0.55, 0.1), Color(0.98, 0.85, 0.15),
	Color(0.25, 0.55, 0.95), Color(0.55, 0.55, 0.58)]


var match_ref: MatchController
var team: Team
var prematch := false
var column: int = Column.POSITION
var mode: int = Mode.SUBSTITUTE
## Entrada marcada para el intercambio (ver _entries) o vacía.
var _marked := {}
var _focus_index := 0
var _entries: Array[Dictionary] = []

var _frame: WEStyle.ScreenFrame
var _pitch: MiniPitch
var _list: VBoxContainer
var _menu: VBoxContainer
var _detail: VBoxContainer
var _title: Label
var _col_label: Label
var _status: Label
var _rows: Array[Button] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func _ready() -> void:
	_frame = WEStyle.ScreenFrame.new("Dirección del equipo", [])
	add_child(_frame)
	_frame.title.text = "DIRECCIÓN DEL EQUIPO"
	# Izquierda: el plantel. Derecha: la cancha con la formación (los
	# jugadores se acomodan solos al cambiarla), y abajo el menú y la ficha
	# del jugador marcado.
	var root := HBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", int(WEStyle.px(32)))
	_frame.body.add_child(root)
	var lbox := VBoxContainer.new()
	lbox.custom_minimum_size.x = WEStyle.px(620)
	lbox.add_theme_constant_override("separation", 0)
	root.add_child(lbox)
	_title = WEStyle.make_caption_label("", WEStyle.ACCENT)
	# El equipo y la formación van a la derecha del título (title_info).
	_title.visible = false
	lbox.add_child(_title)
	var head := HBoxContainer.new()
	head.custom_minimum_size.y = WEStyle.px(WEStyle.HEADER_ROW_H)
	head.add_theme_constant_override("separation", int(WEStyle.px(12)))
	var hj := WEStyle.make_caption_label("Jugador")
	hj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_pad(hj))
	_col_label = WEStyle.make_caption_label("")
	_col_label.custom_minimum_size.x = WEStyle.px(124)
	_col_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_col_label)
	lbox.add_child(head)
	var ls := ScrollContainer.new()
	ls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ls.follow_focus = true
	lbox.add_child(ls)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	ls.add_child(_list)
	# Derecha: arriba la ficha del jugador (ancha, los atributos en cuatro
	# columnas); abajo el menú y la cancha con su proporción real.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", int(WEStyle.px(16)))
	root.add_child(right)
	var dp := WEStyle.make_card()
	dp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(dp)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", int(WEStyle.px(4)))
	dp.add_child(_detail)
	_status = WEStyle.make_body_label("", WEStyle.BODY_M, WEStyle.ACCENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", int(WEStyle.px(16)))
	right.add_child(bottom)
	var mp := WEStyle.make_card()
	mp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(mp)
	# El menú es largo (tiradores, estrategias...): se desplaza con el foco
	# para que no se corte abajo.
	var ms := ScrollContainer.new()
	ms.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ms.follow_focus = true
	ms.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mp.add_child(ms)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", int(WEStyle.px(2)))
	_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ms.add_child(_menu)
	var pp := WEStyle.make_card()
	bottom.add_child(pp)
	_pitch = MiniPitch.new()
	_pitch.custom_minimum_size = Vector2(WEStyle.px(PITCH_H * 105.0 / 68.0), WEStyle.px(PITCH_H))
	pp.add_child(_pitch)


## Alto de la cancha (px de 1080); el ancho sale de la proporción 105 x 68.
const PITCH_H := 300.0


func _pad(c: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(WEStyle.px(12)))
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(c)
	return m


## Abre la pantalla para el equipo `t` (previa = cambios libres y "Jugar").
func open(m: MatchController, t: Team, is_prematch: bool) -> void:
	match_ref = m
	team = t
	prematch = is_prematch
	mode = Mode.SUBSTITUTE
	_marked = {}
	_focus_index = 0
	visible = true
	_rebuild()
	_menu.get_child(0).grab_focus()


func close() -> void:
	visible = false
	_marked = {}
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var step := 0
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			step = -1
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			step = 1
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
			step = -1
		elif event.physical_keycode == KEY_E:
			step = 1
	if step != 0:
		cycle_column(step)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		back()
		get_viewport().set_input_as_handled()


## L1 / R1: Puesto -> Energía -> Condición.
func cycle_column(step: int) -> void:
	column = posmod(column + step, Column.size())
	_rebuild()


## Atrás: desmarca, sale del modo de elección o cierra.
func back() -> void:
	if not _marked.is_empty():
		_marked = {}
		_rebuild()
	elif mode != Mode.SUBSTITUTE:
		mode = Mode.SUBSTITUTE
		_rebuild()
		_menu.get_child(0).grab_focus()
	else:
		close()


# --- Lista ----------------------------------------------------------------------

## Filas: titulares en el orden de la formación (los expulsados quedan en su
## puesto, en rojo), después el banco y al final los que ya salieron.
func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in team.roster.size():
		var p := team.roster[i]
		var kind := "pitch" if team.players.has(p) else "red"
		out.append({"kind": kind, "p": p, "d": p.base_data, "slot": i})
	for d in team.bench:
		out.append({"kind": "bench", "p": null, "d": d, "slot": -1})
	for p in team.subbed_off:
		out.append({"kind": "out", "p": p, "d": p.base_data, "slot": -1})
	return out


func _rebuild() -> void:
	if team == null:
		return
	# El foco vive en filas y botones que se rearman: se recuerda dónde estaba
	# para devolverlo (si no, al cambiar de columna con L1 / R1 el cursor se
	# perdía y no se podía seguir).
	var owner: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var was_row := owner != null and _rows.has(owner)
	var menu_idx := _menu.get_children().find(owner) if owner != null and _menu != null else -1
	_entries = entries()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	var pending := {}
	for s in team.pending_subs:
		pending[s["out"].base_data] = "sale"
		pending[s["in"]] = "entra"
	for i in _entries.size():
		var e := _entries[i]
		if i == 0 or i == 11:
			var cap := WEStyle.make_caption_label("Titulares" if i == 0 else "Suplentes")
			cap.custom_minimum_size.y = WEStyle.px(WEStyle.HEADER_ROW_H)
			cap.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			_list.add_child(cap)
		_rows.append(_row(i, e, pending.get(e["d"], "")))
	_col_label.text = String(COLUMN_NAMES[column]).to_upper()
	_title.text = "%s  ·  %s" % [team.team_name, team.formation.formation_name if team.formation else ""]
	_frame.crumb.text = "PARTIDO  /  PREVIA" if prematch else "PARTIDO  /  PAUSA"
	_frame.title_info.text = _title.text
	var choosing := mode != Mode.SUBSTITUTE or not _marked.is_empty()
	_frame.footer.set_hints([[&"ui_accept", "Elegir / cambiar"], [&"ui_tabs", "Columna"],
		[&"ui_cancel", "Desmarcar" if choosing else "Volver"]])
	_build_menu()
	_pitch.team = team
	_pitch.focused = _entry_player(_focus_index)
	_pitch.marked = _marked.get("p") if not _marked.is_empty() else null
	_pitch.queue_redraw()
	_show_detail(_focus_index)
	_status.text = _hint()
	if _rows.is_empty():
		return
	if was_row or mode != Mode.SUBSTITUTE or not _marked.is_empty():
		_rows[clampi(_focus_index, 0, _rows.size() - 1)].grab_focus()
	elif menu_idx >= 0 and menu_idx < _menu.get_child_count():
		(_menu.get_child(menu_idx) as Control).grab_focus()
	elif visible and is_inside_tree() and get_viewport().gui_get_focus_owner() == null:
		_rows[0].grab_focus()


func _row(i: int, e: Dictionary, pending: String) -> Button:
	var d: PlayerData = e["d"]
	var name_color := WEStyle.TEXT_MAIN
	match e["kind"]:
		"bench": name_color = WEStyle.TEXT_DIM
		"red": name_color = WEStyle.DANGER
		"out": name_color = Color(WEStyle.TEXT_DIM, 0.6)
	var tag := ""
	if team.captain_data() == d:
		tag += "  (C)"
	if pending != "":
		tag += "  [%s]" % pending
	if e["p"] != null and (e["p"] as Footballer).injury > 0:
		tag += "  [lesionado]" if (e["p"] as Footballer).injury == Footballer.Injury.SERIOUS else "  [golpe]"
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(WEStyle.px(12)))
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var num := WEStyle.make_body_label(str(d.number), WEStyle.BODY_L, WEStyle.TEXT_DIM)
	num.custom_minimum_size.x = WEStyle.px(36)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(num)
	var nl := WEStyle.make_body_label(d.player_name + tag, WEStyle.BODY_L, name_color)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.clip_text = true
	hb.add_child(nl)
	var cell := _column_cell(e)
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(cell)
	var marked: bool = not _marked.is_empty() and _marked["d"] == d
	var b := WEStyle.make_row_button(hb, marked)
	b.custom_minimum_size.y = WEStyle.px(WEStyle.ROW_H)
	_list.add_child(b)
	b.pressed.connect(_on_row.bind(i))
	b.focus_entered.connect(_on_row_focus.bind(i))
	return b


## Celda de la columna elegida (puesto, energía o flecha de condición).
func _column_cell(e: Dictionary) -> Control:
	var d: PlayerData = e["d"]
	var p: Footballer = e["p"]
	match column:
		Column.ENERGY:
			var bar := EnergyBar.new()
			bar.custom_minimum_size = Vector2(WEStyle.px(124), WEStyle.px(22))
			if p != null:
				bar.stamina = p.stamina / 100.0
				bar.cap = p.stamina_cap() / 100.0
			return bar
		Column.CONDITION:
			var arrow := ConditionArrow.new()
			arrow.custom_minimum_size = Vector2(WEStyle.px(124), WEStyle.px(22))
			arrow.condition = team.condition_of(d)
			return arrow
	var cell := WEStyle.make_body_label("", WEStyle.BODY_S, WEStyle.TEXT_MAIN)
	cell.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
	cell.custom_minimum_size = Vector2(WEStyle.px(124), WEStyle.px(26))
	cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var code: String = d.role_code if d.role_code != "" else POS_CODES[d.position]
	var pos := int(d.position)
	if e["kind"] == "pitch" and p != null:
		code = role_code(p)
		pos = TacticalRole.to_position(p.tactical_role)
		if p.is_keeper():
			code = "GK"
			pos = PlayerData.Position.GK
	cell.text = code
	var sb := StyleBoxFlat.new()
	sb.bg_color = POS_COLORS[pos]
	sb.set_corner_radius_all(int(WEStyle.px(WEStyle.RADIUS_BUTTON)))
	cell.add_theme_stylebox_override("normal", sb)
	return cell


## Sigla del puesto en la formación, con el lado (LB/RB, LMF/RMF).
static func role_code(p: Footballer) -> String:
	return TacticalRole.we_code(p.tactical_role, p.base_spot.y)


func _entry_player(i: int) -> Footballer:
	if i < 0 or i >= _entries.size():
		return null
	return _entries[i]["p"]


func _on_row_focus(i: int) -> void:
	_focus_index = i
	_pitch.focused = _entry_player(i)
	_pitch.queue_redraw()
	_show_detail(i)


func _on_row(i: int) -> void:
	_focus_index = i
	press_entry(_entries[i])


## Elegir una fila según el modo (también lo usan los tests).
func press_entry(e: Dictionary) -> void:
	var on_pitch: bool = e["kind"] == "pitch"
	match mode:
		Mode.CAPTAIN:
			if on_pitch:
				team.captain = e["d"]
				_done_choosing("Capitán: %s" % e["d"].player_name)
			return
		Mode.FK, Mode.CK, Mode.PK, Mode.FK_LONG, Mode.CK_RIGHT:
			if on_pitch:
				match mode:
					Mode.FK: team.fk_taker = e["d"]
					Mode.FK_LONG: team.fk_long_taker = e["d"]
					Mode.CK: team.ck_taker = e["d"]
					Mode.CK_RIGHT: team.ck_right_taker = e["d"]
					Mode.PK: team.pk_taker = e["d"]
				_done_choosing("%s: %s" % [_mode_name(mode), e["d"].player_name])
			return
	if e["kind"] in ["red", "out"]:
		return
	if _marked.is_empty():
		_marked = e
		_rebuild()
		return
	var a := _marked
	_marked = {}
	_swap(a, e)
	_rebuild()


func _done_choosing(text: String) -> void:
	mode = Mode.SUBSTITUTE
	_rebuild()
	_status.text = text
	_menu.get_child(0).grab_focus()


## Intercambio entre dos filas (ver la cabecera del archivo).
func _swap(a: Dictionary, b: Dictionary) -> void:
	if a["d"] == b["d"]:
		return
	if a["kind"] == "bench" and b["kind"] == "bench":
		var ia := team.bench.find(a["d"])
		var ib := team.bench.find(b["d"])
		team.bench[ia] = b["d"]
		team.bench[ib] = a["d"]
		return
	if a["kind"] == "pitch" and b["kind"] == "pitch":
		match_ref.swap_slots(a["p"], b["p"])
		return
	var starter: Dictionary = a if a["kind"] == "pitch" else b
	var sub: Dictionary = b if starter == a else a
	if prematch:
		match_ref.swap_lineup(starter["p"], sub["d"])
	elif team.subs_left() <= 0:
		match_ref.show_toast("No quedan cambios")
	else:
		match_ref.request_sub(starter["p"], sub["d"])


# --- Menú -----------------------------------------------------------------------

func _build_menu() -> void:
	for c in _menu.get_children():
		_menu.remove_child(c)
		c.queue_free()
	if prematch:
		_menu_button("Jugar partido", func() -> void:
			close()
			play_pressed.emit())
	_menu_button("Salir", close)
	var subs := "Sustituir" if prematch else "Sustituir  (%d restantes)" % team.subs_left()
	_menu_button(subs, _start_substitute)
	_menu_button("TL corto: %s" % _taker_name(team.fk_taker), _choose.bind(Mode.FK))
	_menu_button("TL largo: %s" % _taker_name(team.fk_long_taker, team.fk_taker), _choose.bind(Mode.FK_LONG))
	_menu_button("Córner izq.: %s" % _taker_name(team.ck_taker), _choose.bind(Mode.CK))
	_menu_button("Córner der.: %s" % _taker_name(team.ck_right_taker, team.ck_taker), _choose.bind(Mode.CK_RIGHT))
	_menu_button("Penales: %s" % _taker_name(team.pk_taker), _choose.bind(Mode.PK))
	_menu_button("Capitán: %s" % _taker_name(team.captain, team.captain_data()), _choose.bind(Mode.CAPTAIN))
	_menu_button("Formación: %s" % (team.formation.formation_name if team.formation else "-"), _next_formation)
	_menu_button("Copiar estrategia: guardar", save_plan)
	_menu_button("Copiar estrategia: cargar", load_plan)
	for i in team.strategy_slots.size():
		var on := "  (activa)" if team.strategy == team.strategy_slots[i] else ""
		var sb := _menu_button("%s%s" % [Strategy.NAMES[team.strategy_slots[i]], on], cycle_strategy_slot.bind(i))
		sb.icon = ButtonIcons.combo(["L2", Strategy.BUTTON_ICONS[i]], int(WEStyle.px(WEStyle.HINT_SIZE) * 0.8))


func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = WEStyle.px(40)
	b.clip_text = true
	for st in ["normal", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.content_margin_left = WEStyle.px(WEStyle.BUTTON_PADDING_X) * 0.6
		b.add_theme_stylebox_override(st, sb)
	for st in ["hover", "focus"]:
		var fs := WEStyle.make_focus_style()
		fs.content_margin_left = WEStyle.px(WEStyle.BUTTON_PADDING_X) * 0.6
		b.add_theme_stylebox_override(st, fs)
	b.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
	b.add_theme_font_size_override("font_size", WEStyle.font_px(WEStyle.BODY_M))
	b.add_theme_color_override("font_color", WEStyle.TEXT_MAIN)
	for k in ["font_focus_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, WEStyle.ACCENT)
	b.pressed.connect(cb)
	_menu.add_child(b)
	return b


func _taker_name(d: PlayerData, auto: PlayerData = null) -> String:
	if d != null:
		return d.player_name
	return "auto (%s)" % auto.player_name if auto != null else "automático"


func _mode_name(m: int) -> String:
	match m:
		Mode.FK: return "Tiros libres cortos"
		Mode.FK_LONG: return "Tiros libres largos"
		Mode.CK: return "Córners desde la izquierda"
		Mode.CK_RIGHT: return "Córners desde la derecha"
		Mode.PK: return "Penales"
		Mode.CAPTAIN: return "Capitán"
	return "Sustituir"


func _start_substitute() -> void:
	mode = Mode.SUBSTITUTE
	_marked = {}
	_focus_index = 0
	_rebuild()
	if not _rows.is_empty():
		_rows[0].grab_focus()


func _choose(m: int) -> void:
	mode = m
	_marked = {}
	_rebuild()
	if not _rows.is_empty():
		_rows[clampi(_focus_index, 0, 10)].grab_focus()


## Cambia la estrategia asignada a un botón (sin repetir y sin "ninguna").
func cycle_strategy_slot(i: int) -> void:
	var kind: int = team.strategy_slots[i]
	for n in Strategy.NAMES.size():
		kind = kind % (Strategy.NAMES.size() - 1) + 1
		if not team.strategy_slots.has(kind):
			break
	if team.strategy == team.strategy_slots[i]:
		team.strategy = kind
	team.strategy_slots[i] = kind
	var idx := _menu.get_children().find(get_viewport().gui_get_focus_owner()) if is_inside_tree() else -1
	_rebuild()
	if idx >= 0 and idx < _menu.get_child_count():
		(_menu.get_child(idx) as Control).grab_focus()


func _next_formation() -> void:
	var all := FormationLibrary.load_all()
	var idx := 0
	for i in all.size():
		if team.formation != null and all[i].formation_name == team.formation.formation_name:
			idx = i
	var focus_idx := _menu.get_children().find(get_viewport().gui_get_focus_owner()) if is_inside_tree() else -1
	match_ref.set_formation(team.index, all[(idx + 1) % all.size()])
	_rebuild()
	# El foco queda en "Formación" para seguir pasando (antes iba al último
	# botón, que desde que están las estrategias ya no es éste).
	if focus_idx >= 0 and focus_idx < _menu.get_child_count():
		(_menu.get_child(focus_idx) as Control).grab_focus()


# --- Copiar estrategia ------------------------------------------------------------

## Planes guardados por equipo (formación, estrategias de los 4 botones,
## pateadores y capitán): se copian al próximo partido del mismo equipo.
## "" = la carpeta del jugador (UserData.plans_path()).
static var plans_path := ""


static func _plans_file() -> String:
	return plans_path if plans_path != "" else UserData.plans_path()

const PLAN_TAKERS := ["fk_taker", "fk_long_taker", "ck_taker", "ck_right_taker", "pk_taker", "captain"]


func save_plan() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_plans_file())
	var key := team.team_name
	cfg.set_value(key, "formation", team.formation.formation_name if team.formation else "")
	cfg.set_value(key, "strategy_slots", team.strategy_slots.duplicate())
	for f in PLAN_TAKERS:
		var d: PlayerData = team.get(f)
		cfg.set_value(key, f, d.player_name if d != null else "")
	cfg.save(_plans_file())
	_status.text = "Estrategia guardada: se puede copiar en otro partido de %s." % team.short_name


func load_plan() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_plans_file()) != OK or not cfg.has_section(team.team_name):
		_status.text = "No hay una estrategia guardada de %s." % team.short_name
		return
	var key := team.team_name
	var fname: String = cfg.get_value(key, "formation", "")
	for f in FormationLibrary.load_all():
		if f.formation_name == fname and (team.formation == null or team.formation.formation_name != fname):
			match_ref.set_formation(team.index, f)
	var slots: Array = cfg.get_value(key, "strategy_slots", [])
	if slots.size() == team.strategy_slots.size():
		for i in slots.size():
			team.strategy_slots[i] = int(slots[i])
	var squad: Array[PlayerData] = []
	for p in team.players:
		if p.base_data != null:
			squad.append(p.base_data)
	squad.append_array(team.bench)
	for f in PLAN_TAKERS:
		var who: String = cfg.get_value(key, f, "")
		var found: PlayerData = null
		for d in squad:
			if d.player_name == who:
				found = d
		team.set(f, found)
	_rebuild()
	_status.text = "Estrategia copiada."


## Qué se está haciendo (los botones están en el pie).
func _hint() -> String:
	match mode:
		Mode.CAPTAIN, Mode.FK, Mode.CK, Mode.PK, Mode.FK_LONG, Mode.CK_RIGHT:
			return "%s: elegí un jugador de la cancha." % _mode_name(mode)
	if not _marked.is_empty():
		return "%s marcado: elegí con quién cambiarlo." % _marked["d"].player_name
	var extra := "cambio libre" if prematch else "entra en la próxima pelota parada"
	return "Elegí dos jugadores y se intercambian (%s)." % extra


# --- Ficha ----------------------------------------------------------------------

func _show_detail(i: int) -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	if i < 0 or i >= _entries.size():
		return
	var e := _entries[i]
	var base: PlayerData = e["d"]
	var p: Footballer = e["p"]
	var cond := team.condition_of(base)
	var d: PlayerData = p.data if p != null and p.data != null else base.with_condition(cond)
	_detail.add_child(WEStyle.make_title_label("%d  %s" % [base.number, base.player_name.to_upper()], WEStyle.TITLE_M))
	var code: String = base.role_code if base.role_code != "" else POS_CODES[base.position]
	if p != null and e["kind"] == "pitch":
		code = "GK" if p.is_keeper() else role_code(p)
	var info := "%s  ·  %s  ·  %d cm  ·  Físico %s (%s)  ·  Condición: %s" % [code,
		base.foot_name(), base.height_cm(), base.physique_letter(),
		PlayerData.BUILD_NAMES.get(base.visual_build(), ""), PlayerData.CONDITION_NAMES[cond]]
	if p != null and e["kind"] == "pitch":
		info += "  ·  Energía %d%%" % roundi(p.stamina_cap())
	var il := _label(_detail, info, WEStyle.BODY_S, WEStyle.TEXT_DIM)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var roles := []
	if team.captain_data() == base:
		roles.append("Capitán")
	if team.fk_taker == base:
		roles.append("TL corto")
	if team.fk_long_taker == base:
		roles.append("TL largo")
	if team.ck_taker == base:
		roles.append("Córner izq.")
	if team.ck_right_taker == base:
		roles.append("Córner der.")
	if team.pk_taker == base:
		roles.append("Penales")
	if p != null and p.injury > 0:
		roles.append("Lesionado" if p.injury == Footballer.Injury.SERIOUS else "Golpeado (juega rengo)")
	if e["kind"] == "red":
		roles.append("Expulsado")
	if e["kind"] == "out":
		roles.append("Ya salió")
	if not roles.is_empty():
		_detail.add_child(WEStyle.make_caption_label(" · ".join(roles), WEStyle.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", int(WEStyle.px(40)))
	grid.add_theme_constant_override("v_separation", 0)
	_detail.add_child(WEStyle.make_separator())
	_detail.add_child(grid)
	for k in PlayerData.ATTRIBUTES.size():
		var v := int(d.get(PlayerData.ATTRIBUTES[k]))
		if v <= 0:
			continue
		var nl := _label(grid, PlayerData.ATTRIBUTE_NAMES[k], WEStyle.BODY_M, WEStyle.TEXT_DIM)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Potencia de remate: también el nivel del WE (6 a 9).
		var txt := str(v)
		if PlayerData.ATTRIBUTES[k] == "shot_power" and d is PlayerData:
			txt = "%d (%d)" % [v, (d as PlayerData).shot_level()]
		var vl := _label(grid, txt, WEStyle.BODY_M, attribute_color(v))
		vl.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vl.custom_minimum_size.x = WEStyle.px(56)
	# Etiquetas (las estrellitas del WE), en una sola línea.
	var tags := PackedStringArray()
	for id in base.abilities:
		tags.append(String(PlayerData.ABILITY_NAMES.get(id, id)))
	if not tags.is_empty():
		var tl := _label(_detail, "★ " + "  ★ ".join(tags), WEStyle.BODY_S, WEStyle.ACCENT)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Colores de los puntajes como en el WE: los altos resaltan.
static func attribute_color(v: int) -> Color:
	if v >= 80:
		return Color(1.0, 0.45, 0.15)
	if v >= 70:
		return Color(1.0, 0.82, 0.25)
	return Color.WHITE


# --- Helpers ---------------------------------------------------------------------

## Texto con los tokens (font_size: BODY_L / BODY_M / BODY_S).
func _label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var l := WEStyle.make_body_label(text, font_size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Cancha con la formación (el equipo ataca hacia la derecha). Cada jugador
## es una ficha con su número, puesto y apellido; al cambiar la formación o
## hacer un cambio, las fichas se deslizan a su lugar nuevo.
class MiniPitch:
	extends Control
	var team: Team
	var focused: Footballer
	var marked: Footballer
	## Posición dibujada de cada ficha (0..1 en la cancha), que sigue a la real.
	var _shown := {}

	func _process(dt: float) -> void:
		if team == null:
			return
		var moving := false
		var sp := spots()
		for p in team.players:
			var want: Vector2 = sp.get(p, Vector2(0.5, 0.5))
			var cur: Vector2 = _shown.get(p, want)
			var nxt := cur.lerp(want, 1.0 - exp(-10.0 * dt))
			if nxt.distance_to(want) < 0.001:
				nxt = want
			else:
				moving = true
			_shown[p] = nxt
		if moving:
			queue_redraw()

	## Lugar de la ficha de `p` en la cancha (x 0..1 de arco propio a rival,
	## y 0..1 de arriba abajo).
	func spot_of(p: Footballer) -> Vector2:
		return spots().get(p, Vector2(0.5, 0.5))

	## Lugar de cada ficha: el arquero en su arco y las líneas repartidas por
	## toda la cancha (defensa cerca del área propia, delanteros cerca de la
	## rival). Las fichas que quedarían encimadas se separan a lo alto.
	func spots() -> Dictionary:
		var out := {}
		var min_x := INF
		var max_x := -INF
		for q in team.players:
			if not q.is_keeper():
				min_x = minf(min_x, q.base_spot.x)
				max_x = maxf(max_x, q.base_spot.x)
		var span := max_x - min_x
		for q in team.players:
			var x := 0.07
			if not q.is_keeper():
				x = 0.55 if span < 0.01 else lerpf(0.27, 0.86, (q.base_spot.x - min_x) / span)
			out[q] = Vector2(x, clampf(0.5 - q.base_spot.y * 0.5, 0.06, 0.94))
		# Separación mínima entre fichas (en la cancha de 0..1): ~90 px de ancho
		# y ~44 px de alto en la cancha de la pantalla.
		var gap := Vector2(0.12, 0.2)
		var list: Array = out.keys()
		for it in 12:
			var moved := false
			for a in list.size():
				for b in range(a + 1, list.size()):
					var pa: Vector2 = out[list[a]]
					var pb: Vector2 = out[list[b]]
					if absf(pa.x - pb.x) < gap.x and absf(pa.y - pb.y) < gap.y:
						var push := (gap.y - absf(pa.y - pb.y)) * 0.5 + 0.001
						var up := -1.0 if pa.y < pb.y or (pa.y == pb.y and a < b) else 1.0
						out[list[a]] = Vector2(pa.x, clampf(pa.y + up * push, 0.06, 0.94))
						out[list[b]] = Vector2(pb.x, clampf(pb.y - up * push, 0.06, 0.94))
						moved = true
			if not moved:
				break
		return out

	## Lugar dibujado ahora (para los tests: se anima hacia spot_of).
	func shown_of(p: Footballer) -> Vector2:
		return _shown.get(p, spot_of(p))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		for i in 10:
			draw_rect(Rect2(r.size.x * i / 10.0, 0, r.size.x / 10.0 + 1.0, r.size.y),
				WEStyle.PITCH_DARK if i % 2 == 0 else WEStyle.PITCH_LIGHT)
		PitchMarkings.draw_2d(self, r.grow(-WEStyle.px(12)), Color(WEStyle.TEXT_MAIN, 0.55), 1.0)
		if team == null:
			return
		var body := WEStyle.font(WEStyle.Typeface.BODY)
		var semi := WEStyle.font(WEStyle.Typeface.SEMIBOLD)
		var rad := WEStyle.px(19)
		var fs := WEStyle.font_px(WEStyle.BODY_M)
		var small := WEStyle.font_px(WEStyle.BODY_S) - 1
		for p in team.players:
			var n := shown_of(p)
			var pos := Vector2(r.size.x * n.x, rad + 4.0 + (r.size.y - rad * 2.0 - WEStyle.px(32)) * n.y)
			var c := team.keeper_color if p.is_keeper() else team.color
			if p == marked:
				draw_circle(pos, rad + 4.0, WEStyle.ACCENT)
			elif p == focused:
				draw_circle(pos, rad + 4.0, WEStyle.TEXT_MAIN)
			draw_circle(pos, rad, c)
			draw_arc(pos, rad, 0, TAU, 24, Color(WEStyle.BG_NIGHT, 0.7), 1.5)
			var ink := WEStyle.BG_NIGHT if c.get_luminance() > 0.35 else WEStyle.TEXT_MAIN
			draw_string(semi, pos + Vector2(-rad, fs * 0.35), str(p.number), HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, fs, ink)
			var code: String = "GK" if p.is_keeper() else TeamSheet.role_code(p)
			var pos_i := PlayerData.Position.GK if p.is_keeper() else TacticalRole.to_position(p.tactical_role)
			var tag := Rect2(pos + Vector2(-rad - WEStyle.px(46), -WEStyle.px(10)), Vector2(WEStyle.px(40), WEStyle.px(20)))
			if tag.position.x < 2.0:
				# Pegado al borde (el arquero): la etiqueta va arriba de la ficha.
				tag.position = Vector2(pos.x - tag.size.x * 0.5, pos.y - rad - tag.size.y - 2.0)
			draw_rect(tag, POS_COLORS[pos_i])
			draw_string(semi, Vector2(tag.position.x, tag.end.y - WEStyle.px(5)), code, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, small, WEStyle.TEXT_MAIN)
			var surname := p.display_name.get_slice(" ", p.display_name.get_slice_count(" ") - 1)
			draw_string(body, pos + Vector2(-WEStyle.px(70), rad + fs), surname, HORIZONTAL_ALIGNMENT_CENTER, WEStyle.px(140), small + 1, WEStyle.TEXT_MAIN)


## Barra de energía: lo actual, y en oscuro lo que se perdió por el desgaste.
class EnergyBar:
	extends Control
	var stamina := 1.0
	var cap := 1.0

	func _draw() -> void:
		var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		draw_rect(r, WEStyle.LINE)
		draw_rect(Rect2(r.position, Vector2(r.size.x * cap, r.size.y)), Color(WEStyle.ACCENT, 0.3))
		var c := WEStyle.ACCENT_GREEN.lerp(WEStyle.DANGER, clampf(1.0 - stamina, 0.0, 1.0) * 1.4)
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(stamina, 0.0, 1.0), r.size.y)), c)


## Flecha de condición del WE: hacia arriba (excelente) ... hacia abajo (mala).
class ConditionArrow:
	extends Control
	var condition: int = PlayerData.Condition.NORMAL

	func _draw() -> void:
		var c: Color = TeamSheet.CONDITION_COLORS[clampi(condition, 0, 4)]
		# Ángulo: arriba, arriba-derecha, derecha, abajo-derecha, abajo.
		var ang := lerpf(-PI * 0.5, PI * 0.5, condition / 4.0)
		var center := size * 0.5
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x)
		var l := minf(size.y, 18.0) * 0.5
		var tip := center + dir * l
		var tail := center - dir * l
		draw_line(tail, center, c, 4.0)
		draw_colored_polygon(PackedVector2Array([tip, center + side * l * 0.75, center - side * l * 0.75]), c)
