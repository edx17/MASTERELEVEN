class_name HalftimeScreen
extends CanvasLayer
## Entretiempo y final (como en el WE): estadísticas de los dos equipos con
## barras, un menú (seguir, Dirección del equipo, highlights, salir) y de
## fondo la cámara recorriendo el estadio en tomas lentas. En el final, en
## lugar de la Dirección del equipo, los puntajes de cada jugador.

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
## Goles de cada tiempo, debajo del resultado ("1T 1-0   2T 0-1").
var _halves: Label
var _rows: VBoxContainer
var _menu: VBoxContainer
var _continue: Button
var _sheet_btn: Button
var _ratings_btn: Button
var _showing_ratings := false
var _shot := 0
var _shot_t := 0.0
var _sheet: TeamSheet
var _footer: WEStyle.HintFooter
var _caption: Label
var _names: Array[Label] = []
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
	# Velo sobre el partido (el HUD queda atrás) para que se lea todo.
	var veil := ColorRect.new()
	veil.color = Color(WEStyle.BG_NIGHT, 0.55)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	# Izquierda: el resultado y las estadísticas (o los puntajes) en una
	# tarjeta; derecha: el menú. De fondo, la cámara recorre el estadio.
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = WEStyle.px(WEStyle.MARGIN_X)
	panel.offset_top = WEStyle.px(WEStyle.MARGIN_Y)
	panel.offset_right = WEStyle.px(WEStyle.MARGIN_X + 1000)
	panel.offset_bottom = -WEStyle.px(WEStyle.FOOTER_H + 32)
	var sb := WEStyle.make_panel_style()
	sb.bg_color = WEStyle.BG_NIGHT
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(WEStyle.px(10)))
	panel.add_child(box)
	_caption = WEStyle.make_caption_label("Partido", WEStyle.ACCENT)
	box.add_child(_caption)
	_title = WEStyle.make_title_label("ENTRETIEMPO", WEStyle.TITLE_L)
	box.add_child(_title)
	# Resultado: local | goles | visitante.
	var score := HBoxContainer.new()
	score.add_theme_constant_override("separation", int(WEStyle.px(24)))
	box.add_child(score)
	for i in 2:
		var n := WEStyle.make_title_label("", WEStyle.TITLE_M)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 0 else HORIZONTAL_ALIGNMENT_LEFT
		n.clip_text = true
		_names.append(n)
		score.add_child(n)
		if i == 0:
			_score = WEStyle.make_title_label("", WEStyle.TITLE_XL, WEStyle.ACCENT)
			_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			score.add_child(_score)
	_halves = WEStyle.make_caption_label("")
	_halves.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_halves)
	box.add_child(WEStyle.make_separator())
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 0)
	box.add_child(_rows)
	var mp := WEStyle.make_card()
	var msb := WEStyle.make_panel_style()
	msb.bg_color = WEStyle.BG_NIGHT
	mp.add_theme_stylebox_override("panel", msb)
	mp.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	mp.offset_left = -WEStyle.px(WEStyle.MARGIN_X + 560)
	mp.offset_right = -WEStyle.px(WEStyle.MARGIN_X)
	mp.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(mp)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", int(WEStyle.px(8)))
	mp.add_child(_menu)
	_continue = _button("Segundo tiempo", func() -> void: _match.start_second_half())
	_sheet_btn = _button("Dirección del equipo", _open_sheet)
	_ratings_btn = _button("Puntajes de los jugadores", _toggle_ratings)
	_button("Ver highlights", _play_highlights)
	_button("Salir al menú", func() -> void: _match.exit_to_menu())
	_footer = WEStyle.HintFooter.new("Entretiempo", [[&"ui_navigate", "Navegar"], [&"ui_accept", "Aceptar"]])
	_footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_footer.offset_top = -WEStyle.px(WEStyle.FOOTER_H)
	root.add_child(_footer)
	_sheet = TeamSheet.new()
	add_child(_sheet)
	_sheet.closed.connect(func() -> void:
		_menu.visible = true
		_menu_card().visible = true
		_focus_default())
	m.replay.finished.connect(_on_clip_done)


## El menú es el padre del padre de _menu (la tarjeta): se oculta entero.
func _menu_card() -> Control:
	return _menu.get_parent() as Control


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "%s  ›" % text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(WEStyle.px(500), WEStyle.px(56))
	if _menu.get_child_count() == 0:
		WEStyle.style_primary_button(b, WEStyle.BODY_L)
	else:
		WEStyle.style_button(b, WEStyle.BODY_L)
	b.pressed.connect(cb)
	_menu.add_child(b)
	return b


## Muestra la pantalla (entretiempo o final).
func open(final: bool) -> void:
	_final = final
	visible = true
	_menu.visible = true
	_title.text = "RESULTADO" if final else "ENTRETIEMPO"
	_caption.text = ("Final del partido" if final else "Fin del primer tiempo").to_upper()
	_footer.screen = "Resultado" if final else "Entretiempo"
	_footer.rebuild()
	_continue.visible = not final
	_sheet_btn.visible = not final
	_ratings_btn.visible = final
	_showing_ratings = false
	_ratings_btn.text = "Puntajes de los jugadores  ›"
	_refresh()
	_shot = 0
	_shot_t = 0.0
	_next_shot()
	_focus_default()
	_arm_menu()


## Los botones no responden el primer segundo y medio: si se venía apretando
## X (por ejemplo, para saltear una repetición) no se saltea la pantalla.
const INPUT_GRACE := 1.5


func _arm_menu() -> void:
	for b in _menu.get_children():
		(b as Button).disabled = true
	get_tree().create_timer(INPUT_GRACE, true, false, true).timeout.connect(func() -> void:
		for b in _menu.get_children():
			(b as Button).disabled = false)


func _focus_default() -> void:
	if _continue.visible:
		_continue.grab_focus()
	else:
		_ratings_btn.grab_focus()


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
		["Tiros libres", str(st["free_kicks"][0]), str(st["free_kicks"][1]), st["free_kicks"][0], st["free_kicks"][1]],
		["Penales", str(st["penalties"][0]), str(st["penalties"][1]), st["penalties"][0], st["penalties"][1]],
	]


## "1T 1-0   2T 0-1" (en el entretiempo, sólo el primero).
func halves_text() -> String:
	var g1: Array = _match.stats["goals_1st"]
	var g2: Array = _match.stats["goals_2nd"]
	var txt := "1T  %d - %d" % [g1[0], g1[1]]
	if _final:
		txt += "      2T  %d - %d" % [g2[0], g2[1]]
	return txt


func _toggle_ratings() -> void:
	_showing_ratings = not _showing_ratings
	_ratings_btn.text = ("Estadísticas del partido" if _showing_ratings else "Puntajes de los jugadores") + "  ›"
	_refresh()


func _refresh() -> void:
	var t0 := _match.teams[0]
	var t1 := _match.teams[1]
	_score.text = "%d - %d" % [t0.score, t1.score]
	_names[0].text = t0.team_name.to_upper()
	_names[1].text = t1.team_name.to_upper()
	_halves.text = halves_text()
	for c in _rows.get_children():
		c.queue_free()
	if _showing_ratings:
		_fill_ratings()
		return
	for r in stat_rows():
		var row := StatRow.new()
		row.caption = r[0]
		row.left_text = r[1]
		row.right_text = r[2]
		row.left = float(r[3])
		row.right = float(r[4])
		row.left_color = t0.color
		row.right_color = t1.color
		row.custom_minimum_size = Vector2(0, WEStyle.px(50))
		_rows.add_child(row)


## Filas de puntajes de un equipo: [puesto, número, nombre, puntaje, goles,
## asistencias, figura]. Primero los que terminaron en la cancha, después los
## que salieron o fueron expulsados (los que no jugaron no aparecen).
func rating_rows(t: Team) -> Array:
	var r := _match.ratings
	var mvp := r.man_of_the_match()
	var out: Array = []
	var seen := {}
	var order: Array = []
	for p in t.players:
		order.append(p)
	for p in r.players():
		if p.team == t and not order.has(p):
			order.append(p)
	for p in order:
		if seen.has(p):
			continue
		seen[p] = true
		var s := r.of(p)
		var code: String = "GK" if p.is_keeper() else TeamSheet.role_code(p)
		out.append([code, p.number, p.display_name, r.rating(p), s["goals"], s["assists"], p == mvp])
	return out


func _fill_ratings() -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", int(WEStyle.px(32)))
	_rows.add_child(cols)
	for t in _match.teams:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		cols.add_child(col)
		col.add_child(WEStyle.make_title_label(t.team_name.to_upper(), WEStyle.TITLE_M, t.color.lightened(0.35)))
		col.add_child(WEStyle.make_cells(["Pos.", "N°", "Jugador", "Nota"], [52, 40, 0, 60], "LRLR", true))
		for row in rating_rows(t):
			var extra := ""
			if row[4] > 0:
				extra += "  G%s" % ("x%d" % row[4] if row[4] > 1 else "")
			if row[5] > 0:
				extra += "  A%s" % ("x%d" % row[5] if row[5] > 1 else "")
			var val: float = row[3]
			var txt := "—" if val < 0.0 else ("%.1f" % val)
			var line := WEStyle.make_cells([row[0], str(row[1]), String(row[2]) + extra, txt], [52, 40, 0, 60], "LRLR", false,
				WEStyle.ACCENT if row[6] else WEStyle.TEXT_MAIN, WEStyle.BODY_M)
			line.custom_minimum_size.y = WEStyle.px(30)
			(line.get_child(0) as Label).add_theme_color_override("font_color", WEStyle.TEXT_DIM)
			var c := WEStyle.TEXT_DIM
			if val >= 7.5:
				c = WEStyle.ACCENT_GREEN
			elif val >= 6.0:
				c = WEStyle.TEXT_MAIN
			elif val >= 0.0:
				c = WEStyle.DANGER
			var rl := line.get_child(3) as Label
			rl.add_theme_color_override("font_color", c)
			rl.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
			col.add_child(line)
	var mvp := _match.ratings.man_of_the_match()
	if mvp != null:
		var l := WEStyle.make_caption_label("Figura del partido: %s (%s)" % [mvp.display_name, mvp.team.short_name], WEStyle.ACCENT)
		l.custom_minimum_size.y = WEStyle.px(WEStyle.HEADER_ROW_H)
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_rows.add_child(l)


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
	_menu_card().visible = false
	var t := _match.humans[0].team if not _match.humans.is_empty() else _match.teams[0]
	_sheet.open(_match, t, false)


## Las jugadas repetidas del partido, una atrás de otra.
func _play_highlights() -> void:
	_queue = _match.highlights.duplicate()
	if _queue.is_empty():
		_match.show_toast("Todavía no hubo jugadas para repetir", 1.5)
		return
	_menu_card().visible = false
	_footer.visible = false
	_rows.get_parent().get_parent().visible = false
	_match.replay.play_clip(_queue.pop_front())


func _on_clip_done() -> void:
	if not visible:
		return
	if not _queue.is_empty():
		_match.replay.play_clip(_queue.pop_front())
		return
	_menu.visible = true
	_menu_card().visible = true
	_footer.visible = true
	_rows.get_parent().get_parent().visible = true
	# La repetición mostró a los jugadores: la cancha vuelve a quedar vacía.
	_match.hide_players_for_break()
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
		var title := WEStyle.font(WEStyle.Typeface.TITLE)
		var semi := WEStyle.font(WEStyle.Typeface.SEMIBOLD)
		var w := size.x
		var mid := w * 0.5
		var total := maxf(left + right, 0.0001)
		var bar_w := w * 0.34
		var bh := WEStyle.px(6)
		var y := size.y - bh - WEStyle.px(8)
		draw_rect(Rect2(mid - bar_w - 1, y, bar_w, bh), WEStyle.LINE)
		draw_rect(Rect2(mid + 1, y, bar_w, bh), WEStyle.LINE)
		draw_rect(Rect2(mid - 1 - bar_w * left / total, y, bar_w * left / total, bh), left_color.lightened(0.15))
		draw_rect(Rect2(mid + 1, y, bar_w * right / total, bh), right_color.lightened(0.15))
		var cap := WEStyle.font_px(WEStyle.BODY_S)
		var cap_text := caption.to_upper()
		var cw := semi.get_string_size(cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, cap).x
		draw_string(semi, Vector2(mid - cw * 0.5, y - WEStyle.px(10)), cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, cap, WEStyle.TEXT_DIM)
		var fs := WEStyle.font_px(WEStyle.TITLE_M)
		var base := y + bh
		draw_string(title, Vector2(0, base), left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WEStyle.TEXT_MAIN)
		var rw := title.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(title, Vector2(w - rw, base), right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WEStyle.TEXT_MAIN)
