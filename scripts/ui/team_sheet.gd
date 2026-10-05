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
enum Mode { SUBSTITUTE, CAPTAIN, FK, CK, PK }

## Puesto en la formación (TacticalRole.Kind), con las siglas del WE.
const ROLE_CODES := ["GK", "CB", "SB", "DH", "CH", "OH", "SH", "WG", "CF"]
const POS_CODES := ["GK", "DF", "MF", "FW"]
const POS_COLORS := [Color(0.8, 0.72, 0.15), Color(0.2, 0.45, 0.8), Color(0.25, 0.62, 0.32), Color(0.78, 0.22, 0.2)]
## Flechas de condición: rojo arriba, naranja, amarillo, azul, gris abajo.
const CONDITION_COLORS := [Color(0.95, 0.15, 0.12), Color(1.0, 0.55, 0.1), Color(0.98, 0.85, 0.15),
	Color(0.25, 0.55, 0.95), Color(0.55, 0.55, 0.58)]

const BG := Color(0.04, 0.09, 0.16, 0.95)
const ROW := Color(0.1, 0.26, 0.46)
const ROW_BENCH := Color(0.08, 0.17, 0.3)
const ROW_FOCUS := Color(0.5, 0.68, 0.9)
const ROW_MARK := Color(0.85, 0.62, 0.12)

var match_ref: MatchController
var team: Team
var prematch := false
var column: int = Column.POSITION
var mode: int = Mode.SUBSTITUTE
## Entrada marcada para el intercambio (ver _entries) o vacía.
var _marked := {}
var _focus_index := 0
var _entries: Array[Dictionary] = []

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
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	# Izquierda: el plantel. Derecha: la cancha grande con la formación
	# (los jugadores se acomodan solos al cambiarla), y abajo el menú y la
	# ficha del jugador marcado.
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.custom_minimum_size = Vector2(1240, 690)
	root.position = -root.custom_minimum_size * 0.5
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	var left := _panel(root, Vector2(470, 690))
	var lbox := VBoxContainer.new()
	lbox.add_theme_constant_override("separation", 4)
	left.add_child(lbox)
	_title = _label(lbox, "", 20, Color(1.0, 0.85, 0.3))
	var head := HBoxContainer.new()
	lbox.add_child(head)
	_label(head, "Jugador", 15, Color(0.7, 0.8, 0.95)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col_label = _label(head, "", 15, Color(0.7, 0.8, 0.95))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	lbox.add_child(_list)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(756, 690)
	right.add_theme_constant_override("separation", 10)
	root.add_child(right)
	var pp := _panel(right, Vector2(756, 0))
	_pitch = MiniPitch.new()
	_pitch.custom_minimum_size = Vector2(730, 236)
	pp.add_child(_pitch)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(bottom)
	var mp := _panel(bottom, Vector2(318, 0))
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 4)
	mp.add_child(_menu)
	var dp := _panel(bottom, Vector2(428, 0))
	dp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 3)
	dp.add_child(_detail)
	_status = _label(right, "", 15, Color(0.85, 0.9, 1.0))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = false
	var sm := ButtonIcons.Mirror.new(15, false, Color(0.85, 0.9, 1.0))
	sm.source = _status
	sm.custom_minimum_size = Vector2(756, 40)
	right.add_child(sm)


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
		if i == 11:
			var sep := ColorRect.new()
			sep.color = Color(1, 1, 1, 0.25)
			sep.custom_minimum_size = Vector2(0, 2)
			_list.add_child(sep)
		_rows.append(_row(i, e, pending.get(e["d"], "")))
	_col_label.text = "%s" % COLUMN_NAMES[column]
	_title.text = "%s  ·  %s" % [team.team_name, team.formation.formation_name if team.formation else ""]
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
	var b := Button.new()
	b.custom_minimum_size = Vector2(444, 22)
	b.focus_mode = Control.FOCUS_ALL
	var bg := ROW if e["kind"] == "pitch" else ROW_BENCH
	if not _marked.is_empty() and _marked["d"] == e["d"]:
		bg = ROW_MARK
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = ROW_FOCUS if st in ["focus", "hover"] else bg
		sb.content_margin_left = 8
		b.add_theme_stylebox_override(st, sb)
	_list.add_child(b)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 8
	hb.offset_right = -4
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	var d: PlayerData = e["d"]
	var name_color := Color.WHITE
	match e["kind"]:
		"bench": name_color = Color(0.78, 0.86, 1.0)
		"red": name_color = Color(1.0, 0.35, 0.3)
		"out": name_color = Color(0.5, 0.52, 0.56)
	var tag := ""
	if team.captain_data() == d:
		tag += "  (C)"
	if pending != "":
		tag += "  [%s]" % pending
	if e["p"] != null and (e["p"] as Footballer).injury > 0:
		tag += "  [lesionado]" if (e["p"] as Footballer).injury == Footballer.Injury.SERIOUS else "  [golpe]"
	var nl := _label(hb, d.player_name + tag, 15, name_color)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var num := _label(hb, str(d.number), 15, Color.WHITE)
	num.custom_minimum_size = Vector2(30, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(_column_cell(e))
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
			bar.custom_minimum_size = Vector2(84, 16)
			if p != null:
				bar.stamina = p.stamina / 100.0
				bar.cap = p.stamina_cap() / 100.0
			return bar
		Column.CONDITION:
			var arrow := ConditionArrow.new()
			arrow.custom_minimum_size = Vector2(84, 16)
			arrow.condition = team.condition_of(d)
			return arrow
	var cell := Label.new()
	cell.custom_minimum_size = Vector2(84, 16)
	cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_theme_font_size_override("font_size", 14)
	var code: String = POS_CODES[d.position]
	var pos := int(d.position)
	if e["kind"] == "pitch" and p != null:
		code = ROLE_CODES[clampi(p.tactical_role, 0, ROLE_CODES.size() - 1)]
		pos = TacticalRole.to_position(p.tactical_role)
		if p.is_keeper():
			code = "GK"
			pos = PlayerData.Position.GK
	cell.text = code
	var sb := StyleBoxFlat.new()
	sb.bg_color = POS_COLORS[pos]
	cell.add_theme_stylebox_override("normal", sb)
	return cell


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
		Mode.FK, Mode.CK, Mode.PK:
			if on_pitch:
				match mode:
					Mode.FK: team.fk_taker = e["d"]
					Mode.CK: team.ck_taker = e["d"]
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
	_menu_button("Tiros libres: %s" % _taker_name(team.fk_taker), _choose.bind(Mode.FK))
	_menu_button("Córners: %s" % _taker_name(team.ck_taker), _choose.bind(Mode.CK))
	_menu_button("Penales: %s" % _taker_name(team.pk_taker), _choose.bind(Mode.PK))
	_menu_button("Capitán: %s" % _taker_name(team.captain, team.captain_data()), _choose.bind(Mode.CAPTAIN))
	_menu_button("Formación: %s" % (team.formation.formation_name if team.formation else "-"), _next_formation)
	for i in team.strategy_slots.size():
		var on := "  (activa)" if team.strategy == team.strategy_slots[i] else ""
		var sb := _menu_button("%s%s" % [Strategy.NAMES[team.strategy_slots[i]], on], cycle_strategy_slot.bind(i))
		sb.icon = ButtonIcons.combo(["L2", Strategy.BUTTON_ICONS[i]], 20)


func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(294, 25)
	b.add_theme_font_size_override("font_size", 15)
	b.clip_text = true
	for st in ["normal", "hover", "focus", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.3, 0.5, 0.75, 0.9) if st in ["focus", "hover"] else Color(0, 0, 0, 0)
		sb.content_margin_left = 12
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.pressed.connect(cb)
	_menu.add_child(b)
	return b


func _taker_name(d: PlayerData, auto: PlayerData = null) -> String:
	if d != null:
		return d.player_name
	return "auto (%s)" % auto.player_name if auto != null else "automático"


func _mode_name(m: int) -> String:
	match m:
		Mode.FK: return "Tiros libres"
		Mode.CK: return "Córners"
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


func _hint() -> String:
	match mode:
		Mode.CAPTAIN, Mode.FK, Mode.CK, Mode.PK:
			return "%s: elegí un jugador de la cancha.   {O} / Esc: volver" % _mode_name(mode)
	if not _marked.is_empty():
		return "%s marcado: elegí con quién cambiarlo.   {O} / Esc: desmarcar" % _marked["d"].player_name
	var extra := "cambio libre" if prematch else "entra en la próxima pelota parada"
	return "{X} en dos jugadores: se intercambian (%s).   {L1} / {R1} columna" % extra


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
	_label(_detail, "%d  %s" % [base.number, base.player_name], 21, Color.WHITE)
	var info := "%s  ·  %s  ·  %d cm  ·  Condición: %s" % [POS_CODES[base.position],
		"Zurdo" if base.foot == PlayerData.Foot.LEFT else "Diestro", base.height_cm(),
		PlayerData.CONDITION_NAMES[cond]]
	if p != null and e["kind"] == "pitch":
		info += "  ·  Energía %d%%" % roundi(p.stamina_cap())
	var il := _label(_detail, info, 13, Color(0.75, 0.85, 1.0))
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var roles := []
	if team.captain_data() == base:
		roles.append("Capitán")
	if team.fk_taker == base:
		roles.append("Tiros libres")
	if team.ck_taker == base:
		roles.append("Córners")
	if team.pk_taker == base:
		roles.append("Penales")
	if p != null and p.injury > 0:
		roles.append("Lesionado" if p.injury == Footballer.Injury.SERIOUS else "Golpeado (juega rengo)")
	if e["kind"] == "red":
		roles.append("Expulsado")
	if e["kind"] == "out":
		roles.append("Ya salió")
	if not roles.is_empty():
		_label(_detail, " · ".join(roles), 13, Color(1.0, 0.8, 0.3))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 0)
	_detail.add_child(grid)
	for k in PlayerData.ATTRIBUTES.size():
		var v := int(d.get(PlayerData.ATTRIBUTES[k]))
		if v <= 0:
			continue
		var nl := _label(grid, PlayerData.ATTRIBUTE_NAMES[k], 13, Color(0.85, 0.88, 0.95))
		nl.custom_minimum_size = Vector2(150, 0)
		# Potencia de remate: también el nivel del WE (6 a 9).
		var txt := str(v)
		if PlayerData.ATTRIBUTES[k] == "shot_power" and d is PlayerData:
			txt = "%d (%d)" % [v, (d as PlayerData).shot_level()]
		var vl := _label(grid, txt, 13, attribute_color(v))
		vl.custom_minimum_size = Vector2(30, 0)
	# Etiquetas (las estrellitas del WE), en una sola línea.
	var tags := PackedStringArray()
	for id in base.abilities:
		tags.append(String(PlayerData.ABILITY_NAMES.get(id, id)))
	if not tags.is_empty():
		var tl := _label(_detail, "★ " + "  ★ ".join(tags), 13, Color(1.0, 0.85, 0.35))
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Colores de los puntajes como en el WE: los altos resaltan.
static func attribute_color(v: int) -> Color:
	if v >= 80:
		return Color(1.0, 0.45, 0.15)
	if v >= 70:
		return Color(1.0, 0.82, 0.25)
	return Color.WHITE


# --- Helpers ---------------------------------------------------------------------

func _panel(parent: Control, min_size: Vector2) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = min_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = Color(0.3, 0.55, 0.85, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)
	return pc


func _label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
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
		for p in team.players:
			var want := spot_of(p)
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
		# Las posiciones base van de su arco a la mitad: se estiran a la cancha.
		var max_x := 0.3
		for q in team.players:
			max_x = maxf(max_x, q.base_spot.x)
		return Vector2(0.06 + 0.84 * clampf(p.base_spot.x / max_x, 0.0, 1.0), 0.5 - p.base_spot.y * 0.5)

	## Lugar dibujado ahora (para los tests: se anima hacia spot_of).
	func shown_of(p: Footballer) -> Vector2:
		return _shown.get(p, spot_of(p))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.16, 0.42, 0.2))
		for i in 10:
			if i % 2 == 0:
				draw_rect(Rect2(r.size.x * i / 10.0, 0, r.size.x / 10.0, r.size.y), Color(0.19, 0.47, 0.23))
		var line := Color(1, 1, 1, 0.75)
		PitchMarkings.draw_2d(self, r.grow(-10), line, 1.5)
		if team == null:
			return
		var font := get_theme_default_font()
		for p in team.players:
			var n := shown_of(p)
			var pos := Vector2(r.size.x * n.x, 16.0 + (r.size.y - 40.0) * n.y)
			var c := team.keeper_color if p.is_keeper() else team.color
			if p == marked:
				draw_circle(pos, 17.0, Color(1.0, 0.75, 0.1))
			elif p == focused:
				draw_circle(pos, 17.0, Color.WHITE)
			draw_circle(pos, 13.0, c)
			draw_arc(pos, 13.0, 0, TAU, 24, Color(0, 0, 0, 0.6), 1.5)
			var ink := Color.BLACK if c.get_luminance() > 0.35 else Color.WHITE
			draw_string(font, pos + Vector2(-13, 5), str(p.number), HORIZONTAL_ALIGNMENT_CENTER, 26, 14, ink)
			var code: String = "GK" if p.is_keeper() else ROLE_CODES[clampi(p.tactical_role, 0, ROLE_CODES.size() - 1)]
			var pos_i := PlayerData.Position.GK if p.is_keeper() else TacticalRole.to_position(p.tactical_role)
			draw_rect(Rect2(pos + Vector2(-42, -7), Vector2(25, 14)), POS_COLORS[pos_i])
			draw_string(font, pos + Vector2(-42, 4), code, HORIZONTAL_ALIGNMENT_CENTER, 25, 11, Color.WHITE)
			var surname := p.display_name.get_slice(" ", p.display_name.get_slice_count(" ") - 1)
			draw_string(font, pos + Vector2(-45, 26), surname, HORIZONTAL_ALIGNMENT_CENTER, 90, 12, Color.WHITE)


## Barra de energía: lo actual, y en oscuro lo que se perdió por el desgaste.
class EnergyBar:
	extends Control
	var stamina := 1.0
	var cap := 1.0

	func _draw() -> void:
		var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		draw_rect(r, Color(0.15, 0.15, 0.18))
		draw_rect(Rect2(r.position, Vector2(r.size.x * cap, r.size.y)), Color(0.35, 0.3, 0.12))
		var c := Color(0.35, 0.85, 0.35).lerp(Color(0.95, 0.3, 0.2), clampf(1.0 - stamina, 0.0, 1.0) * 1.4)
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
