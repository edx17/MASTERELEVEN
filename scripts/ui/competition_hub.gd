class_name CompetitionHub
extends Control
## Liga / Copa / Mundial con el diseño 03 "Mesa táctica" (el mismo armazón que
## la Liga Virtual, WEStyle.MesaFrame):
##   - Izquierda: el próximo partido (Jugar / Simular) y la última fecha; al
##     terminar, el campeón.
##   - Centro, por secciones (L1/R1 o Q/E): en la liga, la tabla (filas de
##     44 px, números a la derecha) y el fixture; en las copas, las llaves y el
##     fixture; en el Mundial, además, los grupos.
##   - Derecha: tu equipo (campaña y racha), Volver y Abandonar.
## Todos los estilos salen de WEStyle.

signal play_match(home_path: String, away_path: String, human_side: int)
signal back

var comp: Competition
## Sección del centro (índice en views()).
var view := 0
var _frame: WEStyle.MesaFrame
var _abandon_armed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame = WEStyle.MesaFrame.new("03  /  Mesa táctica",
		[[&"ui_accept", "Aceptar"], [&"ui_cancel", "Volver"], [&"ui_tabs", "Sección"]])
	add_child(_frame)


func open(c: Competition) -> void:
	comp = c
	_abandon_armed = false
	visible = true
	view = default_view()
	_rebuild()
	WEStyle.fade_in(_frame)


## Secciones del centro según el tipo de competición.
func views() -> Array:
	match comp.kind:
		Competition.Kind.LEAGUE:
			return ["Tabla", "Fixture"]
		Competition.Kind.WORLD_CUP:
			return ["Grupos", "Llaves", "Fixture"]
	return ["Llaves", "Fixture"]


## La sección con la que se abre: en el Mundial, las llaves una vez
## terminados los grupos.
func default_view() -> int:
	if comp.kind == Competition.Kind.WORLD_CUP and comp.current >= comp.group_rounds:
		return 1
	return 0


func kind_title() -> String:
	return "MUNDIAL" if comp.kind == Competition.Kind.WORLD_CUP else "%s VIRTUAL ELEVEN" % String(Competition.KIND_NAMES[comp.kind]).to_upper()


func _rebuild() -> void:
	_frame.clear_columns()
	_frame.crumb.text = "%s  /  %s" % [kind_title(), comp.progress_text().to_upper()]
	_frame.title.text = kind_title()
	_frame.title_info.text = comp.team(comp.user_team).team_name
	_build_center()
	_team_column()
	_next_match()


func _name(i: int) -> String:
	return comp.team(i).team_name


func result_text(g: Dictionary) -> String:
	var r: Array = g["result"]
	var s := "%s  vs  %s" % [_name(g["home"]), _name(g["away"])]
	if r.size() >= 2:
		s = "%s  %d - %d  %s" % [_name(g["home"]), r[0], r[1], _name(g["away"])]
		if r.size() >= 4:
			s += "  (penales %d-%d)" % [r[2], r[3]]
	return s


# --- Centro: la sección elegida ------------------------------------------------------

func _build_center() -> void:
	var c := _frame.center
	var names := views()
	var head := HBoxContainer.new()
	var heading := {"Tabla": "Tabla de posiciones", "Grupos": "Fase de grupos", "Llaves": "Llaves", "Fixture": "Fixture"}
	head.add_child(WEStyle.make_title_label(String(heading[names[view]]).to_upper(), WEStyle.TITLE_M))
	head.add_child(WEStyle.make_gap())
	var meta := WEStyle.make_body_label("Terminada" if comp.finished() else comp.round_name(), WEStyle.BODY_L, WEStyle.TEXT_DIM)
	meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(meta)
	c.add_child(head)
	c.add_child(WEStyle.SectionTabs.new(names, view))
	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(WEStyle.px(4)))
	c.add_child(body)
	match String(names[view]):
		"Tabla":
			_table(body)
		"Grupos":
			_groups(body)
		"Llaves":
			_bracket(body)
		_:
			_fixture(body)


func _set_view(i: int) -> void:
	view = wrapi(i, 0, views().size())
	WEStyle.clear_children(_frame.center)
	_build_center()


func _scroll_box(body: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = WEStyle.px(WEStyle.ROW_H) * 8
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	WEStyle.pad_scroll(scroll)
	body.add_child(scroll)
	return scroll


func _rows(scroll: ScrollContainer) -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 0)
	scroll.add_child(rows)
	return rows


func _scroll_to(scroll: ScrollContainer, row: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(row):
		scroll.ensure_control_visible(row)


## Tabla de la liga: filas de 44 px y los números a la derecha; el puntero
## con una marca verde y tu equipo resaltado.
func _table(body: Control) -> void:
	body.add_child(WEStyle.make_table_row(["Pos.", "Equipo", "PJ", "G", "E", "P", "GF", "GC", "DG", "Pts"], true))
	var scroll := _scroll_box(body)
	var rows := _rows(scroll)
	var pos := 1
	var my_row: Control = null
	for row in comp.standings():
		var me: bool = row["team"] == comp.user_team
		var dg := int(row["dg"])
		var r := WEStyle.make_table_row(["%02d" % pos, _name(row["team"]), str(row["pj"]), str(row["g"]), str(row["e"]),
			str(row["p"]), str(row["gf"]), str(row["gc"]), ("%+d" % dg) if dg != 0 else "0", str(row["pts"])], false, me,
			WEStyle.ACCENT_GREEN if pos == 1 else Color(0, 0, 0, 0))
		rows.add_child(r)
		if me:
			my_row = r
		pos += 1
	if my_row != null:
		_scroll_to.call_deferred(scroll, my_row)


## Mundial: los grupos, el tuyo primero; los que pasan con la marca verde.
func _groups(body: Control) -> void:
	var scroll := _scroll_box(body)
	var rows := _rows(scroll)
	var mine := comp.group_of(comp.user_team)
	var order: Array = [mine] if mine >= 0 else []
	for gi in comp.groups.size():
		if gi != mine:
			order.append(gi)
	var thirds := comp.groups.size() == 12
	for gi in order:
		var cap := WEStyle.make_caption_label("Grupo %s" % Competition.WC_GROUP_LETTERS[gi],
			WEStyle.ACCENT if gi == mine else WEStyle.TEXT_DIM)
		cap.custom_minimum_size.y = WEStyle.px(WEStyle.HEADER_ROW_H)
		cap.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		rows.add_child(cap)
		rows.add_child(WEStyle.make_table_row(["Pos.", "Selección", "PJ", "DG", "GF", "Pts"], true))
		var pos := 1
		for row in comp.group_table(gi):
			var zone := WEStyle.ACCENT_GREEN if pos <= 2 else (Color(WEStyle.ACCENT_GREEN, 0.4) if thirds and pos == 3 else Color(0, 0, 0, 0))
			var dg := int(row["dg"])
			rows.add_child(WEStyle.make_table_row(["%02d" % pos, _name(row["team"]), str(row["pj"]),
				("%+d" % dg) if dg != 0 else "0", str(row["gf"]), str(row["pts"])], false, row["team"] == comp.user_team, zone))
			pos += 1
	body.add_child(WEStyle.make_body_label("Verde: pasan los dos primeros%s" % (" y los 8 mejores terceros" if thirds else ""),
		WEStyle.BODY_S, WEStyle.TEXT_DIM))


## Columnas de la llave: [{name, games, round}] desde la primera ronda de
## eliminación hasta la final; las rondas que faltan, con cruces vacíos ({}).
## La ida y vuelta se muestra en una columna (la vuelta, con el global).
func bracket_columns() -> Array:
	var from := comp.group_rounds if comp.kind == Competition.Kind.WORLD_CUP else 0
	var cols := []
	var i := from
	while i < comp.rounds.size():
		var games: Array = comp.rounds[i]
		var name := comp.round_name(i)
		if not games.is_empty() and int((games[0] as Dictionary).get("leg", 0)) == 1 and i + 1 < comp.rounds.size():
			i += 1
			games = comp.rounds[i]
		cols.append({"name": name.trim_suffix(" · ida").trim_suffix(" · vuelta"), "games": games, "round": i})
		i += 1
	var n := 0
	if not cols.is_empty():
		n = (cols.back()["games"] as Array).size()
	elif comp.kind == Competition.Kind.WORLD_CUP:
		# Todavía en grupos: los 16avos (o la ronda que corresponda) por definir.
		n = 16 if comp.groups.size() == 12 else comp.groups.size()
		cols.append(_empty_column(n))
	while n > 1 and comp.champion < 0:
		n = (n + 1) / 2
		cols.append(_empty_column(n))
	return cols


func _empty_column(n: int) -> Dictionary:
	var games := []
	for k in n:
		games.append({})
	return {"name": String(Competition.CUP_ROUND_NAMES.get(n * 2, "Ronda")), "games": games, "round": -1}


func _bracket(body: Control) -> void:
	var scroll := _scroll_box(body)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var b := Bracket.new()
	b.hub = self
	b.columns = bracket_columns()
	scroll.add_child(b)
	_scroll_bracket.call_deferred(scroll, b)


## Que se vea la ronda que se juega y el cruce de tu equipo.
func _scroll_bracket(scroll: ScrollContainer, b: Bracket) -> void:
	await get_tree().process_frame
	if not is_instance_valid(scroll):
		return
	b.avail = scroll.size.x
	await get_tree().process_frame
	if not is_instance_valid(scroll):
		return
	var spot := b.focus_point()
	scroll.scroll_horizontal = int(maxf(spot.x - WEStyle.px(40), 0.0))
	scroll.scroll_vertical = int(maxf(spot.y - scroll.size.y * 0.5, 0.0))


## Todas las fechas con sus resultados; se abre en la que se juega.
func _fixture(body: Control) -> void:
	var scroll := _scroll_box(body)
	var rows := _rows(scroll)
	var target: Control = null
	for i in comp.rounds.size():
		var cap := WEStyle.make_caption_label(comp.round_name(i), WEStyle.ACCENT if i == comp.current else WEStyle.TEXT_DIM)
		cap.custom_minimum_size.y = WEStyle.px(WEStyle.HEADER_ROW_H)
		cap.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		rows.add_child(cap)
		if i == mini(comp.current, comp.rounds.size() - 1):
			target = cap
		for g in comp.rounds[i]:
			rows.add_child(_fixture_row(g))
	if target != null:
		_scroll_to.call_deferred(scroll, target)


## Un partido del fixture: local a la derecha, el resultado al medio y el
## visitante a la izquierda (tu equipo en dorado).
func _fixture_row(g: Dictionary) -> Control:
	var me: bool = g["home"] == comp.user_team or g["away"] == comp.user_team
	var pc := WEStyle.make_table_row([], false, me)
	var h := pc.get_child(0) as HBoxContainer
	var color := WEStyle.ACCENT if me else WEStyle.TEXT_MAIN
	var home := WEStyle.make_body_label(_name(g["home"]), WEStyle.BODY_L, color)
	home.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.clip_text = true
	h.add_child(home)
	var r: Array = g["result"]
	var score := "%d - %d" % [r[0], r[1]] if r.size() >= 2 else "vs"
	if r.size() >= 4:
		score += "  (%d-%d)" % [r[2], r[3]]
	var mid := WEStyle.make_body_label(score, WEStyle.BODY_L, color if r.size() >= 2 else WEStyle.TEXT_DIM)
	mid.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.custom_minimum_size.x = WEStyle.px(140)
	h.add_child(mid)
	var away := WEStyle.make_body_label(_name(g["away"]), WEStyle.BODY_L, color)
	away.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	away.clip_text = true
	h.add_child(away)
	for l in [home, mid, away]:
		(l as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return pc


# --- Izquierda: el próximo partido ----------------------------------------------------

func _next_match() -> void:
	var left := _frame.left
	if comp.finished():
		_champion()
		return
	left.add_child(WEStyle.make_caption_label(comp.round_name(), WEStyle.ACCENT))
	left.add_child(WEStyle.make_title_label(_name(comp.user_team).to_upper(), WEStyle.TITLE_L))
	var g := comp.user_match()
	var first: Button
	if g.is_empty():
		left.add_child(_wrap("Tu equipo quedó eliminado.", WEStyle.TEXT_DIM))
		first = WEStyle.make_action_button("Simular la fecha", _simulate, true)
		first.name = "Simulate"
		left.add_child(first)
	else:
		var mine_home: bool = g["home"] == comp.user_team
		left.add_child(WEStyle.make_body_label("vs %s" % _name(g["away"] if mine_home else g["home"]), WEStyle.BODY_L, WEStyle.TEXT_DIM))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(WEStyle.px(24)))
		for side in ["home", "away"]:
			row.add_child(_crest(g[side], WEStyle.px(110)))
			if side == "home":
				var vs := WEStyle.make_title_label("VS", WEStyle.TITLE_L, WEStyle.TEXT_DIM)
				vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(vs)
		left.add_child(row)
		var home_team := comp.team(g["home"])
		left.add_child(WEStyle.make_caption_label("%s · %s" % ["Local" if mine_home else "Visitante",
			home_team.stadium if home_team.stadium != "" else home_team.team_name]))
		first = WEStyle.make_action_button("Jugar el partido", func() -> void:
			play_match.emit(comp.team_paths[g["home"]], comp.team_paths[g["away"]], 0 if mine_home else 1), true)
		first.name = "Play"
		left.add_child(first)
		var sim := WEStyle.make_action_button("Simular partido", _simulate)
		sim.name = "Simulate"
		left.add_child(sim)
	_last_round()
	first.grab_focus()


func _simulate() -> void:
	comp.complete_round()
	comp.save()
	_rebuild()


## Resultados de la última fecha: los de tu equipo (o tu grupo) primero.
func _last_round() -> void:
	if comp.current <= 0:
		return
	var left := _frame.left
	left.add_child(WEStyle.make_caption_label("Última fecha"))
	var last: Array = comp.rounds[comp.current - 1]
	var mine := comp.group_of(comp.user_team) if comp.kind == Competition.Kind.WORLD_CUP else -1
	var first_games := last.filter(func(pg: Dictionary) -> bool:
		return pg["home"] == comp.user_team or pg["away"] == comp.user_team \
			or (mine >= 0 and comp.group_of(pg["home"]) == mine))
	var rest := last.filter(func(pg: Dictionary) -> bool: return not first_games.has(pg))
	for pg in (first_games + rest).slice(0, 3):
		var me: bool = pg["home"] == comp.user_team or pg["away"] == comp.user_team
		var l := WEStyle.make_body_label(result_text(pg), WEStyle.BODY_M, WEStyle.ACCENT if me else WEStyle.TEXT_DIM)
		l.clip_text = true
		left.add_child(l)


func _champion() -> void:
	var left := _frame.left
	var champ := comp.champion if comp.champion >= 0 else int(comp.standings()[0]["team"])
	left.add_child(WEStyle.make_caption_label("Campeón", WEStyle.ACCENT))
	left.add_child(WEStyle.make_title_label(_name(champ).to_upper(), WEStyle.TITLE_L))
	left.add_child(_crest(champ, WEStyle.px(160)))
	if champ == comp.user_team:
		var won: String = "el Mundial" if comp.kind == Competition.Kind.WORLD_CUP else "la " + String(Competition.KIND_NAMES[comp.kind]).to_lower()
		left.add_child(WEStyle.make_title_label("¡Ganaste %s!" % won, WEStyle.TITLE_M, WEStyle.ACCENT_GREEN))
	var done := WEStyle.make_action_button("Terminar", func() -> void:
		comp.delete_file()
		back.emit(), true)
	done.name = "Finish"
	left.add_child(done)
	done.grab_focus()


func _crest(i: int, h: float) -> Control:
	var crest := WEStyle.Crest.new()
	crest.team = comp.team(i)
	crest.label_font = WEStyle.font(WEStyle.Typeface.TITLE)
	crest.custom_minimum_size = Vector2(h, h * 1.1)
	return crest


func _wrap(text: String, color: Color) -> Label:
	var l := WEStyle.make_body_label(text, WEStyle.BODY_L, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# --- Derecha: tu equipo -----------------------------------------------------------------

## Campaña de tu equipo en lo jugado: {pj, g, e, p, gf, gc, form} (form: las
## últimas 5, "G", "E" o "P"; los penales cuentan como empate).
func user_campaign() -> Dictionary:
	var out := {"pj": 0, "g": 0, "e": 0, "p": 0, "gf": 0, "gc": 0, "form": []}
	for i in mini(comp.current, comp.rounds.size()):
		for g in comp.rounds[i]:
			var r: Array = g["result"]
			if r.size() < 2 or (g["home"] != comp.user_team and g["away"] != comp.user_team):
				continue
			var home: bool = g["home"] == comp.user_team
			var gf: int = r[0] if home else r[1]
			var gc: int = r[1] if home else r[0]
			out["pj"] += 1
			out["gf"] += gf
			out["gc"] += gc
			var k := "g" if gf > gc else ("p" if gf < gc else "e")
			out[k] += 1
			(out["form"] as Array).append(k.to_upper())
	out["form"] = (out["form"] as Array).slice(-5)
	return out


## Dónde está tu equipo: "3º de 20", "Grupo C · 2º", "En carrera"...
func user_status() -> String:
	match comp.kind:
		Competition.Kind.LEAGUE:
			var table := comp.standings()
			for k in table.size():
				if table[k]["team"] == comp.user_team:
					return "%dº de %d" % [k + 1, table.size()]
		Competition.Kind.WORLD_CUP:
			if comp.current < comp.group_rounds:
				var gi := comp.group_of(comp.user_team)
				var t := comp.group_table(gi)
				for k in t.size():
					if t[k]["team"] == comp.user_team:
						return "Grupo %s · %dº" % [Competition.WC_GROUP_LETTERS[gi], k + 1]
	if comp.champion == comp.user_team:
		return "Campeón"
	return "En carrera" if comp.alive(comp.user_team) else "Eliminado"


func _team_column() -> void:
	var right := _frame.right
	right.add_child(WEStyle.make_title_label("TU EQUIPO", WEStyle.TITLE_M))
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", int(WEStyle.px(16)))
	who.add_child(_crest(comp.user_team, WEStyle.px(72)))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var nm := WEStyle.make_body_label(_name(comp.user_team), WEStyle.BODY_L)
	nm.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
	v.add_child(nm)
	v.add_child(WEStyle.make_caption_label(user_status(), WEStyle.ACCENT))
	who.add_child(v)
	right.add_child(who)
	var c := user_campaign()
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", int(WEStyle.px(12)))
	for st in [["Partidos", str(c["pj"])], ["G · E · P", "%d·%d·%d" % [c["g"], c["e"], c["p"]]], ["Goles", "%d:%d" % [c["gf"], c["gc"]]]]:
		var card := PanelContainer.new()
		var sb := WEStyle.make_panel_style()
		sb.content_margin_left = WEStyle.px(16)
		sb.content_margin_right = WEStyle.px(16)
		sb.content_margin_top = WEStyle.px(10)
		sb.content_margin_bottom = WEStyle.px(10)
		card.add_theme_stylebox_override("panel", sb)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := VBoxContainer.new()
		cv.add_child(WEStyle.make_caption_label(st[0]))
		cv.add_child(WEStyle.make_title_label(st[1], WEStyle.TITLE_M))
		card.add_child(cv)
		stats.add_child(card)
	right.add_child(stats)
	if not (c["form"] as Array).is_empty():
		right.add_child(WEStyle.make_caption_label("Racha"))
		var form := HBoxContainer.new()
		form.add_theme_constant_override("separation", int(WEStyle.px(8)))
		var tint := {"G": WEStyle.ACCENT_GREEN, "E": WEStyle.TEXT_DIM, "P": WEStyle.DANGER}
		for k in c["form"]:
			var chip := PanelContainer.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = tint[k]
			sb.set_corner_radius_all(int(WEStyle.px(WEStyle.RADIUS_BUTTON)))
			chip.add_theme_stylebox_override("panel", sb)
			chip.custom_minimum_size = Vector2(WEStyle.px(40), WEStyle.px(40))
			var l := WEStyle.make_body_label(String(k), WEStyle.BODY_M, WEStyle.BG_NIGHT)
			l.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			chip.add_child(l)
			form.add_child(chip)
		right.add_child(form)
	if comp.finished():
		return
	right.add_child(WEStyle.make_separator())
	var bk := WEStyle.make_action_button("Volver", func() -> void: back.emit())
	bk.name = "Back"
	right.add_child(bk)
	var ab := WEStyle.make_action_button("Abandonar", Callable())
	ab.name = "Abandon"
	ab.add_theme_color_override("font_color", WEStyle.DANGER)
	ab.pressed.connect(func() -> void:
		if _abandon_armed:
			comp.delete_file()
			back.emit()
		else:
			_abandon_armed = true
			ab.text = "¿Seguro? Se pierde todo  ›")
	right.add_child(ab)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or comp == null:
		return
	if event.is_action_pressed(&"ui_tab_prev"):
		_set_view(view - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_tab_next"):
		_set_view(view + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		back.emit()
		get_viewport().set_input_as_handled()


## Llave de la copa dibujada: una columna por ronda, cada cruce en una tarjeta
## de dos filas (ganador en blanco, eliminado apagado, tu equipo en dorado)
## y líneas finas hacia el cruce siguiente.
class Bracket:
	extends Control
	var hub: CompetitionHub
	var columns: Array = []:
		set(v):
			columns = v
			_measure()
	## Ancho visible: si entran todas las rondas, las tarjetas se achican
	## (hasta un mínimo) para no tener que desplazarse de costado.
	var avail := 0.0:
		set(v):
			avail = v
			_measure()

	func card_w() -> float:
		if avail <= 0.0 or columns.is_empty():
			return WEStyle.px(280)
		return clampf((avail - gap_x() * (columns.size() - 1)) / columns.size(), WEStyle.px(200), WEStyle.px(280))

	func card_h() -> float:
		return WEStyle.px(WEStyle.ROW_H) * 2.0

	func gap_x() -> float:
		return WEStyle.px(56)

	func slot() -> float:
		return card_h() + WEStyle.px(20)

	func head() -> float:
		return WEStyle.px(WEStyle.HEADER_ROW_H) + WEStyle.px(8)

	func _measure() -> void:
		var n := 0
		if not columns.is_empty():
			n = (columns[0]["games"] as Array).size()
		custom_minimum_size = Vector2(columns.size() * (card_w() + gap_x()) - gap_x(), head() + n * slot())
		queue_redraw()

	## Rectángulo del cruce j de la columna c (cada ronda, a mitad de sus dos
	## cruces de origen).
	func card_rect(c: int, j: int) -> Rect2:
		var s := slot() * pow(2.0, c)
		var cy := head() + s * (j + 0.5)
		return Rect2(c * (card_w() + gap_x()), cy - card_h() * 0.5, card_w(), card_h())

	## Dónde mirar al abrir: el cruce de tu equipo en la ronda que se juega (o
	## la primera columna sin jugar).
	func focus_point() -> Vector2:
		for c in columns.size():
			var games: Array = columns[c]["games"]
			if int(columns[c]["round"]) < hub.comp.current and int(columns[c]["round"]) >= 0:
				continue
			for j in games.size():
				var g: Dictionary = games[j]
				if not g.is_empty() and (g["home"] == hub.comp.user_team or g["away"] == hub.comp.user_team):
					return card_rect(c, j).get_center()
			return card_rect(c, 0).position
		return Vector2.ZERO

	func _draw() -> void:
		var body := WEStyle.font(WEStyle.Typeface.BODY)
		var semi := WEStyle.font(WEStyle.Typeface.SEMIBOLD)
		var fs := WEStyle.font_px(WEStyle.BODY_M)
		var cap := WEStyle.font_px(WEStyle.BODY_S)
		var pad := WEStyle.px(12)
		for c in columns.size():
			var col: Dictionary = columns[c]
			var live: bool = int(col["round"]) == hub.comp.current
			var x := c * (card_w() + gap_x())
			draw_string(semi, Vector2(x, WEStyle.px(WEStyle.HEADER_ROW_H) * 0.7), String(col["name"]).to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, card_w(), cap, WEStyle.ACCENT if live else WEStyle.TEXT_DIM)
			var games: Array = col["games"]
			for j in games.size():
				var r := card_rect(c, j)
				var g: Dictionary = games[j]
				var mine: bool = not g.is_empty() and (g["home"] == hub.comp.user_team or g["away"] == hub.comp.user_team)
				var sb := WEStyle.make_panel_style()
				if mine:
					sb.border_color = WEStyle.ACCENT
				draw_style_box(sb, r)
				draw_line(Vector2(r.position.x + 1, r.get_center().y), Vector2(r.end.x - 1, r.get_center().y), WEStyle.LINE, 1.0)
				# Línea hacia el cruce siguiente.
				if c + 1 < columns.size():
					var to := card_rect(c + 1, j / 2)
					var a := Vector2(r.end.x, r.get_center().y)
					var mx := r.end.x + gap_x() * 0.5
					var b := Vector2(to.position.x, to.get_center().y)
					draw_polyline(PackedVector2Array([a, Vector2(mx, a.y), Vector2(mx, b.y), b]), WEStyle.LINE, 1.0)
				var lines := _lines(g)
				for k in 2:
					var y := r.position.y + card_h() * (0.25 + 0.5 * k)
					var ln: Dictionary = lines[k]
					var f: Font = semi if ln["bold"] else body
					var base := y + fs * 0.35
					var score_w := f.get_string_size(ln["score"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
					draw_string(f, Vector2(r.end.x - pad - score_w, base), ln["score"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ln["color"])
					var room := card_w() - pad * 3.0 - score_w
					draw_string(f, Vector2(r.position.x + pad, base), _fit(f, ln["name"], fs, room), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ln["color"])

	## Las dos filas de un cruce: {name, score, color, bold}.
	func _lines(g: Dictionary) -> Array:
		if g.is_empty():
			var tbd := {"name": "Por definir", "score": "", "color": WEStyle.TEXT_DIM, "bold": false}
			return [tbd, tbd]
		var r: Array = g["result"]
		var agg: Array = g.get("agg", [0, 0])
		var win := Competition.winner(g)
		var out := []
		for k in 2:
			var t: int = g["home"] if k == 0 else g["away"]
			var score := ""
			if r.size() >= 2:
				score = str(int(r[k]) + int(agg[k]))
				if r.size() >= 4:
					score += " (%d)" % r[2 + k]
			var color := WEStyle.TEXT_MAIN
			if t == hub.comp.user_team:
				color = WEStyle.ACCENT
			elif win >= 0 and win != t:
				color = WEStyle.TEXT_DIM
			out.append({"name": hub.comp.team(t).team_name, "score": score, "color": color, "bold": win == t})
		return out

	func _fit(f: Font, text: String, fs: int, room: float) -> String:
		if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= room:
			return text
		var t := text
		while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
			t = t.left(t.length() - 1)
		return t + "…"
