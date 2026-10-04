class_name HalftimeScreen
extends CanvasLayer
## Entretiempo y final (como en el WE): estadísticas de los dos equipos con
## barras, un menú (seguir, Dirección del equipo, highlights, salir) y de
## fondo la cámara recorriendo el estadio en tomas lentas.

## Tomas del fondo: [desde, hasta (la cámara se desliza), mira a].
const SHOTS := [
	[Vector3(-40, 32, 80), Vector3(40, 32, 80), Vector3(0, 0, 0)],
	[Vector3(-80, 14, 20), Vector3(-80, 18, -20), Vector3(0, 10, -40)],
	[Vector3(70, 6, 30), Vector3(55, 8, 40), Vector3(0, 8, -45)],
	[Vector3(0, 90, 170), Vector3(30, 80, 160), Vector3(0, 0, 0)],
	[Vector3(30, 3, -20), Vector3(-30, 3, -20), Vector3(0, 8, -60)],
]
const SHOT_TIME := 5.0

var _match: MatchController
var _final := false
var _title: Label
var _score: Label
var _rows: VBoxContainer
var _menu: VBoxContainer
var _continue: Button
var _shot := 0
var _shot_t := 0.0
var _sheet: TeamSheet
var _queue: Array[Dictionary] = []


func setup(m: MatchController) -> void:
	_match = m
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := WEStyle.panel(Vector2(620, 0))
	panel.position = Vector2(60, 70)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_title = WEStyle.label("ENTRETIEMPO", 30, Color(1.0, 0.9, 0.35))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_score = WEStyle.label("", 34)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_score)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	box.add_child(_rows)
	_menu = VBoxContainer.new()
	_menu.position = Vector2(760, 330)
	_menu.add_theme_constant_override("separation", 6)
	root.add_child(_menu)
	_continue = _button("Segundo tiempo", func() -> void: _match.start_second_half())
	_button("Dirección del equipo", _open_sheet)
	_button("Ver highlights", _play_highlights)
	_button("Salir al menú", func() -> void: _match.exit_to_menu())
	_sheet = TeamSheet.new()
	add_child(_sheet)
	_sheet.closed.connect(func() -> void:
		_menu.visible = true
		_focus_default())
	m.replay.finished.connect(_on_clip_done)


func _button(text: String, cb: Callable) -> Button:
	var b := WEStyle.bar(text, cb, 440.0, 22)
	_menu.add_child(b)
	return b


## Muestra la pantalla (entretiempo o final).
func open(final: bool) -> void:
	_final = final
	visible = true
	_menu.visible = true
	_title.text = "FINAL DEL PARTIDO" if final else "ENTRETIEMPO"
	_continue.visible = not final
	_refresh()
	_shot = 0
	_shot_t = 0.0
	_next_shot()
	_focus_default()


func _focus_default() -> void:
	if _continue.visible:
		_continue.grab_focus()
	else:
		(_menu.get_child(1) as Control).grab_focus()


func close() -> void:
	visible = false
	if _sheet.visible:
		_sheet.close()


## Filas: [nombre, valor local, valor visitante] con barras.
func stat_rows() -> Array:
	var st := _match.stats
	var t0 := _match.teams[0]
	var t1 := _match.teams[1]
	var pos: Array = st.get("possession", [0.0, 0.0])
	var total := maxf(float(pos[0]) + float(pos[1]), 0.001)
	var p0 := int(round(float(pos[0]) / total * 100.0)) if float(pos[0]) + float(pos[1]) > 0.0 else 50
	# Al arco: los goles más las atajadas del arquero rival.
	var on0: int = t0.score + int(st["saves"][1])
	var on1: int = t1.score + int(st["saves"][0])
	return [
		["Posesión", "%d %%" % p0, "%d %%" % (100 - p0), p0, 100 - p0],
		["Remates", str(st["shots"][0]), str(st["shots"][1]), st["shots"][0], st["shots"][1]],
		["Remates al arco", str(on0), str(on1), on0, on1],
		["Faltas", str(st["fouls"][0]), str(st["fouls"][1]), st["fouls"][0], st["fouls"][1]],
		["Córners", str(st["corners"][0]), str(st["corners"][1]), st["corners"][0], st["corners"][1]],
		["Amarillas", str(st["yellows"][0]), str(st["yellows"][1]), st["yellows"][0], st["yellows"][1]],
		["Rojas", str(st["reds"][0]), str(st["reds"][1]), st["reds"][0], st["reds"][1]],
		["Fuera de juego", str(st["offsides"][0]), str(st["offsides"][1]), st["offsides"][0], st["offsides"][1]],
	]


func _refresh() -> void:
	var t0 := _match.teams[0]
	var t1 := _match.teams[1]
	_score.text = "%s   %d - %d   %s" % [t0.short_name, t0.score, t1.score, t1.short_name]
	for c in _rows.get_children():
		c.queue_free()
	for r in stat_rows():
		var row := StatRow.new()
		row.caption = r[0]
		row.left_text = r[1]
		row.right_text = r[2]
		row.left = float(r[3])
		row.right = float(r[4])
		row.left_color = t0.color
		row.right_color = t1.color
		row.custom_minimum_size = Vector2(600, 40)
		_rows.add_child(row)


func _process(dt: float) -> void:
	if not visible or _match.replay.playing:
		return
	_shot_t += dt
	if _shot_t >= SHOT_TIME:
		_shot_t = 0.0
		_shot = (_shot + 1) % SHOTS.size()
		_next_shot()


## Toma del fondo: corte al comienzo y desliz lento hacia el final.
func _next_shot() -> void:
	var cam := _match.camera()
	if cam == null:
		return
	var s: Array = SHOTS[_shot]
	cam.set_shot(s[0], s[2], 45.0)
	cam.set_shot(s[1], s[2], 45.0, 0.25)


func _open_sheet() -> void:
	_menu.visible = false
	var t := _match.humans[0].team if not _match.humans.is_empty() else _match.teams[0]
	_sheet.open(_match, t, false)


## Las jugadas repetidas del partido, una atrás de otra.
func _play_highlights() -> void:
	_queue = _match.highlights.duplicate()
	if _queue.is_empty():
		_match.show_toast("Todavía no hubo jugadas para repetir", 1.5)
		return
	_menu.visible = false
	_rows.get_parent().get_parent().visible = false
	_match.replay.play_clip(_queue.pop_front())


func _on_clip_done() -> void:
	if not visible:
		return
	if not _queue.is_empty():
		_match.replay.play_clip(_queue.pop_front())
		return
	_menu.visible = true
	_rows.get_parent().get_parent().visible = true
	_next_shot()
	_focus_default()


## Una estadística: valores a los costados y dos barras enfrentadas.
class StatRow:
	extends Control
	var caption := ""
	var left_text := ""
	var right_text := ""
	var left := 0.0
	var right := 0.0
	var left_color := Color.WHITE
	var right_color := Color.WHITE

	func _draw() -> void:
		var font := get_theme_default_font()
		var w := size.x
		var mid := w * 0.5
		var total := maxf(left + right, 0.0001)
		var bar_w := w * 0.36
		var y := size.y - 10.0
		draw_rect(Rect2(mid - bar_w, y, bar_w, 6), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(mid, y, bar_w, 6), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(mid - bar_w * left / total, y, bar_w * left / total, 6), left_color.lightened(0.15))
		draw_rect(Rect2(mid, y, bar_w * right / total, 6), right_color.lightened(0.15))
		var cw := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_string(font, Vector2(mid - cw * 0.5, 20), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.85, 0.88, 0.95))
		draw_string(font, Vector2(8, 22), left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		var rw := font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, Vector2(w - rw - 8, 22), right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
