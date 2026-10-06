class_name MasterHub
extends Control
## Liga Master, diseño 03 "Mesa táctica" (rediseño estadio de noche).
##
## Encabezado y pie como el menú principal; abajo, tres columnas:
##   - Izquierda: el próximo partido (Jugar / Simular) y las bajas; al terminar
##     la temporada, el resultado y "Empezar la temporada".
##   - Centro: la sección elegida con L1/R1 (Q/E): tabla de posiciones (filas
##     de 44 px, números a la derecha, ascenso en verde y descenso en rojo),
##     goleadores, calendario, copas, noticias o historial.
##   - Derecha: dirección del club (formación), plantel, mercado, guardar.
## Todos los estilos salen de WEStyle.

signal play_match(home_path: String, away_path: String, human_side: int)
signal back

const GOLD := WEStyle.ACCENT
const BLUE := WEStyle.TEXT_DIM
const UP := WEStyle.ACCENT_GREEN
const DOWN := WEStyle.DANGER

var career: MasterCareer
## División que se ve en la tabla y los goleadores.
var view_division := 0
## Sección del centro: 0 tabla, 1 goleadores, 2 calendario, 3 copas,
## 4 noticias, 5 historial.
var view_mode := 0
## Copa que se ve en "Copas" (índice en career.cups; -1 = la que toca).
var view_cup := -1
const VIEW_NAMES := ["Tabla", "Goleadores", "Calendario", "Copas", "Noticias", "Historial"]
var _squad: MasterSquad
var _market: MasterMarket
var _frame: WEStyle.MesaFrame
var _left: VBoxContainer
var _center: VBoxContainer
var _right: VBoxContainer
var _abandon_armed := false
## Botón principal de la columna izquierda (Jugar / Simular / Empezar la
## temporada): adonde vuelve el foco desde el centro.
var _primary_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame = WEStyle.MesaFrame.new("03  /  Mesa táctica",
		[[&"ui_accept", "Aceptar"], [&"ui_cancel", "Volver"], [&"ui_tabs", "Sección"]])
	add_child(_frame)
	_left = _frame.left
	_center = _frame.center
	_right = _frame.right


## Ancho útil de la columna central (para listas y tablas).
func _cw() -> float:
	return maxf(_center.size.x, WEStyle.px(760))


## Texto con los tokens: los tamaños viejos (base 720) pasan a los del rediseño.
func _lbl(text: String, size: int, color: Color = WEStyle.TEXT_MAIN) -> Label:
	if color == Color.WHITE:
		color = WEStyle.TEXT_MAIN
	if size >= 20:
		return WEStyle.make_title_label(text, WEStyle.TITLE_M, color)
	var token := WEStyle.BODY_L if size >= 17 else (WEStyle.BODY_M if size >= 15 else WEStyle.BODY_S)
	return WEStyle.make_body_label(text, token, color)


func open(c: MasterCareer) -> void:
	career = c
	career.activate()
	view_division = career.user_league_index()
	view_mode = 0
	view_cup = -1
	_abandon_armed = false
	visible = true
	_rebuild()
	WEStyle.fade_in(_frame)


func _clear(box: Control) -> void:
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()


func _rebuild() -> void:
	_clear(_left)
	_clear(_center)
	_clear(_right)
	var team := career.user_team()
	_frame.crumb.text = "LIGA MASTER  /  %s" % career.year_label()
	_frame.title.text = "LIGA MASTER · TEMPORADA %s" % career.year_label()
	_frame.title_info.text = "%s · %s puntos WE" % [team.team_name, WEStyle.thousands(career.points)]
	_build_center()
	_club_column()
	if career.season_over:
		_season_summary()
	else:
		_next_match()
	_link_center_focus.call_deferred()


# --- Centro: la sección elegida ------------------------------------------------------

func _build_center() -> void:
	var head := HBoxContainer.new()
	var name: String = String(VIEW_NAMES[view_mode]) if not (career.season_over and view_mode == 0) else "Resumen"
	if view_mode in [0, 1] and not (career.season_over and view_mode == 0):
		name = career.division_name(view_division)
	head.add_child(WEStyle.make_title_label(String(name).to_upper(), WEStyle.TITLE_M))
	head.add_child(WEStyle.make_gap())
	var meta := WEStyle.make_body_label("%s · %s" % [career.year_label(), career.round_text()], WEStyle.BODY_L, WEStyle.TEXT_DIM)
	meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(meta)
	_center.add_child(head)
	var names := VIEW_NAMES.duplicate()
	if career.season_over:
		names[0] = "Resumen"
	_center.add_child(WEStyle.SectionTabs.new(names, view_mode))
	if view_mode in [0, 1] and not (career.season_over and view_mode == 0):
		var divs := career.leagues.size()
		var div_row := WEStyle.OptionRow.new("División",
			func() -> String: return career.division_name(view_division),
			func(dir: int) -> void:
				view_division = wrapi(view_division + dir, 0, divs)
				_rebuild_center.call_deferred(), "", WEStyle.px(760))
		div_row.use_modern_style()
		div_row.name = "DivRow"
		_center.add_child(div_row)
	if view_mode == 3:
		var cup_row := WEStyle.OptionRow.new("Copa",
			func() -> String: return String(career.cups[view_cup]["name"]) if view_cup >= 0 and view_cup < career.cups.size() else "—",
			func(dir: int) -> void:
				if not career.cups.is_empty():
					view_cup = wrapi(view_cup + dir, 0, career.cups.size())
				_rebuild_center.call_deferred(), "", WEStyle.px(760))
		cup_row.use_modern_style()
		cup_row.name = "CupRow"
		_center.add_child(cup_row)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(WEStyle.px(4)))
	_center.add_child(body)
	if career.season_over and view_mode == 0:
		_summary_list(body)
		return
	match view_mode:
		1:
			_scorers(body)
		2:
			_calendar(body)
		3:
			_cups(body)
		4:
			_news(body)
		5:
			_history(body)
		_:
			_table(body)
			_season_progress()


## Rearma sólo el centro (al cambiar de sección o de división), con el foco
## donde estaba si se puede.
func _rebuild_center() -> void:
	var keep := ""
	var f := get_viewport().gui_get_focus_owner()
	if f != null and _center.is_ancestor_of(f):
		keep = String(f.name)
	_clear(_center)
	_build_center()
	_link_center_focus.call_deferred()
	if keep != "":
		var again := _center.get_node_or_null(keep)
		if again is Control:
			(again as Control).grab_focus()
		else:
			_focus_primary()


## Cambio de sección (L1 / R1): el foco vuelve al botón principal (así Jugar
## y Simular quedan siempre a un toque).
func _set_view(i: int) -> void:
	view_mode = wrapi(i, 0, VIEW_NAMES.size())
	_rebuild_center()
	_focus_primary()


func _focus_primary() -> void:
	if _primary_btn != null and is_instance_valid(_primary_btn) and _primary_btn.is_inside_tree():
		_primary_btn.grab_focus()


## Desde lo que toma el foco en el centro se vuelve a la izquierda: en las
## filas de opción (izquierda/derecha cambian el valor) con arriba; en el resto
## con izquierda.
func _link_center_focus() -> void:
	if _primary_btn == null or not is_instance_valid(_primary_btn) or not _primary_btn.is_inside_tree():
		return
	for c in _center.find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl.focus_mode != Control.FOCUS_ALL:
			continue
		var path := ctl.get_path_to(_primary_btn)
		if ctl is WEStyle.OptionRow:
			ctl.focus_neighbor_top = path
		else:
			ctl.focus_neighbor_left = path


## Abajo de la tabla: la fecha de la temporada en grande y el calendario.
func _season_progress() -> void:
	var league := career.user_league()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(WEStyle.px(16)))
	var v := VBoxContainer.new()
	v.add_child(WEStyle.make_caption_label("Temporada"))
	var nums := HBoxContainer.new()
	nums.add_theme_constant_override("separation", int(WEStyle.px(12)))
	nums.add_child(WEStyle.make_title_label("%02d" % mini(league.current + 1, league.rounds.size()), WEStyle.TITLE_XL, WEStyle.ACCENT))
	var of := WEStyle.make_body_label("/ %d fechas" % league.rounds.size(), WEStyle.BODY_L, WEStyle.TEXT_DIM)
	of.size_flags_vertical = Control.SIZE_SHRINK_END
	nums.add_child(of)
	v.add_child(nums)
	row.add_child(v)
	row.add_child(WEStyle.make_gap())
	var cal := Button.new()
	cal.name = "CalendarLink"
	cal.text = "Ver calendario  ›"
	cal.size_flags_vertical = Control.SIZE_SHRINK_END
	WEStyle.style_button(cal)
	cal.pressed.connect(_set_view.bind(2))
	row.add_child(cal)
	_center.add_child(row)


## Tabla de la división elegida: filas de 44 px, números a la derecha; la
## zona de ascenso con una marca verde y la de descenso roja; tu club resaltado.
func _table(body: Control) -> void:
	var comp: Competition = career.leagues[view_division]["comp"]
	var up := TeamDB.relegation_count(career.country, view_division - 1) if view_division > 0 else 0
	var down := TeamDB.relegation_count(career.country, view_division)
	var n := comp.team_paths.size()
	var cols := ["Pos.", "Equipo", "PJ", "G", "E", "P", "DG", "Pts"]
	body.add_child(WEStyle.make_table_row(cols, true, false, Color(0, 0, 0, 0)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, WEStyle.px(WEStyle.ROW_H) * 9)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	WEStyle.pad_scroll(scroll)
	body.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 0)
	scroll.add_child(rows)
	var pos := 1
	var my_row: Control = null
	for row in comp.standings():
		var me: bool = comp.team_paths[row["team"]] == career.user_path()
		var zone := UP if pos <= up else (DOWN if pos > n - down else Color(0, 0, 0, 0))
		var dg := int(row["dg"])
		var r := WEStyle.make_table_row(["%02d" % pos, comp.team(row["team"]).team_name, str(row["pj"]), str(row["g"]), str(row["e"]),
			str(row["p"]), ("%+d" % dg) if dg != 0 else "0", str(row["pts"])], false, me, zone)
		rows.add_child(r)
		if me:
			my_row = r
		pos += 1
	var legend := []
	if up > 0:
		legend.append("Verde: suben %d" % up)
	if down > 0:
		legend.append("Rojo: bajan %d" % down)
	body.add_child(WEStyle.make_body_label("   ".join(legend), WEStyle.BODY_S, WEStyle.TEXT_DIM))
	if my_row != null:
		_scroll_to.call_deferred(scroll, my_row)


# --- Izquierda: el próximo partido ----------------------------------------------------

func _next_match() -> void:
	var comp := career.current_comp()
	var cup_day := career.pending_event() >= 0
	var team := career.user_team()
	_left.add_child(WEStyle.make_caption_label("%s · %s" % [career.current_comp_name(), career.round_text()],
		WEStyle.ACCENT))
	_left.add_child(WEStyle.make_title_label(team.team_name.to_upper(), WEStyle.TITLE_L))
	var g := career.user_match()
	var first: Button = null
	if g.is_empty():
		var note := "Fecha de copa: tu equipo no la juega." if cup_day else "Tu liga terminó: faltan fechas de otras divisiones."
		var l := WEStyle.make_body_label(note, WEStyle.BODY_L, WEStyle.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_left.add_child(l)
		first = _primary("Simular la fecha de copa" if cup_day else "Simular hasta el final", func() -> void:
			if cup_day:
				career.play_round()
			else:
				career.simulate_to_end()
			career.save()
			_rebuild())
		_left.add_child(first)
	else:
		var mine_home: bool = g["home"] == comp.user_team
		var rival := comp.team(g["away"] if mine_home else g["home"])
		_left.add_child(WEStyle.make_body_label("vs %s" % rival.team_name, WEStyle.BODY_L, WEStyle.TEXT_DIM))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(WEStyle.px(24)))
		for side in ["home", "away"]:
			var crest := WEStyle.Crest.new()
			crest.team = comp.team(g[side])
			crest.label_font = WEStyle.font(WEStyle.Typeface.TITLE)
			crest.custom_minimum_size = Vector2(WEStyle.px(110), WEStyle.px(120))
			row.add_child(crest)
			if side == "home":
				var vs := WEStyle.make_title_label("VS", WEStyle.TITLE_L, WEStyle.TEXT_DIM)
				vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(vs)
		_left.add_child(row)
		var home_team := comp.team(g["home"])
		_left.add_child(WEStyle.make_caption_label("%s · %s" % ["Local" if mine_home else "Visitante",
			home_team.stadium if home_team.stadium != "" else home_team.team_name]))
		first = _primary("Jugar el partido", func() -> void:
			var side := 0 if g["home"] == comp.user_team else 1
			play_match.emit(comp.team_paths[g["home"]], comp.team_paths[g["away"]], side))
		first.name = "Play"
		_left.add_child(first)
		var sim := _secondary("Simular partido", func() -> void:
			career.play_round()
			career.save()
			_rebuild())
		sim.name = "Simulate"
		_left.add_child(sim)
	# Bajas: lesionados y suspendidos (no entran en el once).
	var abs := career.user_absences()
	if not abs.is_empty():
		var txt := "Bajas: " + ", ".join(abs.slice(0, 3).map(func(a: Dictionary) -> String: return "%s (%s)" % [a["n"], a["why"]]))
		if abs.size() > 3:
			txt += " y %d más" % (abs.size() - 3)
		_left.add_child(_wrap(txt, WEStyle.DANGER))
	var league := career.user_league()
	if league.current > 0:
		_left.add_child(WEStyle.make_caption_label("Última fecha"))
		var last: Array = league.rounds[league.current - 1]
		var mine := last.filter(func(pg: Dictionary) -> bool: return pg["home"] == league.user_team or pg["away"] == league.user_team)
		var rest := last.filter(func(pg: Dictionary) -> bool: return not mine.has(pg))
		for pg in (mine + rest).slice(0, 2):
			var l := WEStyle.make_body_label(result_text(league, pg), WEStyle.BODY_M,
				WEStyle.ACCENT if mine.has(pg) else WEStyle.TEXT_DIM)
			l.clip_text = true
			_left.add_child(l)
	if first != null:
		_primary_btn = first
		first.grab_focus()


func _primary(text: String, cb: Callable) -> Button:
	return WEStyle.make_action_button(text, cb, true)


func _secondary(text: String, cb: Callable) -> Button:
	return WEStyle.make_action_button(text, cb)


# --- Derecha: dirección del club -------------------------------------------------------

func _club_column() -> void:
	_right.add_child(WEStyle.make_title_label("DIRECCIÓN DEL CLUB", WEStyle.TITLE_M))
	var board := WEStyle.FormationBoard.new()
	board.formation = career.formation_name()
	board.custom_minimum_size = Vector2(WEStyle.px(380), WEStyle.px(200))
	_right.add_child(board)
	_right.add_child(_link("Plantel y formación", "Ver equipo · %s" % career.formation_name(), _open_squad, "Squad"))
	_right.add_child(_link("Mercado de pases", "Gestionar plantel" if career.market_open() else "Cerrado ahora",
		_open_market, "Market"))
	_right.add_child(WEStyle.make_separator())
	var save := _secondary("Guardar y salir", func() -> void:
		career.save()
		back.emit())
	save.name = "SaveExit"
	_right.add_child(save)
	var ab := _secondary("Abandonar la carrera", Callable())
	ab.name = "Abandon"
	ab.add_theme_color_override("font_color", WEStyle.DANGER)
	ab.pressed.connect(func() -> void:
		if _abandon_armed:
			career.delete_file()
			back.emit()
		else:
			_abandon_armed = true
			ab.text = "¿Seguro? Se borra la carrera  ›")
	_right.add_child(ab)


## Acceso de la columna derecha: título en Bebas y una línea de detalle.
func _link(title: String, detail: String, cb: Callable, node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size.y = WEStyle.px(84)
	b.focus_mode = Control.FOCUS_ALL
	WEStyle.style_button(b)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = WEStyle.px(WEStyle.BUTTON_PADDING_X)
	v.offset_top = WEStyle.px(10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	var t := WEStyle.make_title_label(title.to_upper(), WEStyle.TITLE_M)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var d := WEStyle.make_body_label("%s  ›" % detail, WEStyle.BODY_L, WEStyle.TEXT_DIM)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	b.add_child(v)
	b.pressed.connect(cb)
	return b


# --- Fin de temporada --------------------------------------------------------------------

## Izquierda: cómo le fue a tu club y "Empezar la temporada"; el detalle
## (plantel, premios, copas, divisiones) va en el centro ("Resumen").
func _season_summary() -> void:
	var s := career.last_summary()
	var u: Dictionary = s.get("user", {})
	_left.add_child(WEStyle.make_caption_label("Fin de la temporada %s" % s.get("year", ""), WEStyle.ACCENT))
	var champion := int(u.get("pos", 0)) == 1
	var verdict := "¡Campeón!" if champion else "%d.º puesto" % int(u.get("pos", 0))
	_left.add_child(WEStyle.make_title_label(verdict.to_upper(), WEStyle.TITLE_L, UP if champion else WEStyle.TEXT_MAIN))
	_left.add_child(WEStyle.make_body_label(String(u.get("division_name", "")), WEStyle.BODY_L, WEStyle.TEXT_DIM))
	var went := String(u.get("went", "stay"))
	if went == "up":
		_left.add_child(WEStyle.make_title_label("¡ASCENDISTE!", WEStyle.TITLE_M, UP))
	elif went == "down":
		_left.add_child(WEStyle.make_title_label("DESCENDISTE", WEStyle.TITLE_M, DOWN))
	var next := _primary("Empezar la temporada %d" % (career.first_year + career.season), func() -> void:
		career.start_next_season()
		career.save()
		view_division = career.user_league_index()
		view_mode = 0
		_rebuild())
	next.name = "NextSeason"
	_left.add_child(next)
	_left.add_child(_secondary("Mercado de pases (pretemporada)", _open_market))
	_primary_btn = next
	next.grab_focus()


## Centro, "Resumen": tu plantel, premios, copas y lo de cada división.
func _summary_list(body: Control) -> void:
	var s := career.last_summary()
	var u: Dictionary = s.get("user", {})
	var box := _scroll_box(body)
	box.add_child(_lbl("Tu plantel", 17, BLUE))
	if not (u.get("retired", []) as Array).is_empty():
		box.add_child(_wrap("  Se retiraron: " + ", ".join(u["retired"]), DOWN))
	if not (u.get("youth", []) as Array).is_empty():
		box.add_child(_wrap("  Juveniles: " + ", ".join(u["youth"]), UP))
	if not (u.get("risers", []) as Array).is_empty():
		box.add_child(_wrap("  Crecieron: " + ", ".join((u["risers"] as Array).map(func(r: Array) -> String:
			return "%s (+%d)" % [r[0], int(r[1])])), WEStyle.TEXT_MAIN))
	if (u.get("retired", []) as Array).is_empty() and (u.get("youth", []) as Array).is_empty():
		box.add_child(_lbl("  Sin retiros.", 15))
	var awards: Array = s.get("awards", [])
	if not awards.is_empty():
		box.add_child(_lbl("Premios", 17, BLUE))
		for a in awards:
			var mine: bool = String(a.get("club_id", "")) == career.user_club
			box.add_child(_wrap("  %s: %s (%s)%s" % [a["award"], a["n"], a["club"],
				(", " + String(a["detail"])) if String(a["detail"]) != "" else ""], GOLD if mine else WEStyle.TEXT_MAIN))
	var cups: Dictionary = s.get("cups", {})
	for k in cups:
		var cp: Dictionary = cups[k]
		box.add_child(_lbl(String(cp["name"]), 17, BLUE))
		box.add_child(_wrap("  Campeón: %s%s" % [cp["champion"], ("  ·  Tu equipo: %s" % cp["user"]) if String(cp["user"]) != "" else ""], GOLD))
	if s.has("world_cup"):
		var wc: Dictionary = s["world_cup"]
		box.add_child(_lbl("Mundial %s" % wc["year"], 17, BLUE))
		box.add_child(_wrap("  Campeón: %s  ·  %s: %s" % [wc["champion"], wc["nation"], wc["reach"]], GOLD))
		if not (wc["called"] as Array).is_empty():
			box.add_child(_wrap("  Convocados de tu club: " + ", ".join(wc["called"]), UP))
	for d in s.get("divisions", []):
		box.add_child(_lbl(String(d["name"]), 17, BLUE))
		box.add_child(_lbl("  Campeón: %s" % _name(String(d["champion"])), 15, GOLD))
		var ts: Dictionary = d.get("top_scorer", {})
		if not ts.is_empty():
			box.add_child(_lbl("  Goleador: %s (%s) %d goles" % [ts["n"], _name(String(ts["club"])), int(ts["goals"])], 15))
		if not (d["up"] as Array).is_empty():
			box.add_child(_wrap("  Suben: " + ", ".join((d["up"] as Array).map(_name)), UP))
		if not (d["down"] as Array).is_empty():
			box.add_child(_wrap("  Bajan: " + ", ".join((d["down"] as Array).map(_name)), DOWN))


func _wrap(text: String, color: Color) -> Label:
	var l := WEStyle.make_body_label(text, WEStyle.BODY_M, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WEStyle.px(420), 0)
	return l


func _scroll_box(body: Control, h: float = WEStyle.px(560)) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(_cw(), h)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	WEStyle.pad_scroll(scroll)
	body.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	scroll.add_child(box)
	return box


## Copas de la temporada: la elegida con su estado, tus partidos y la fase
## que se está jugando (grupos, fase liga o la llave).
func _cups(body: Control) -> void:
	if career.cups.is_empty():
		body.add_child(_lbl("Esta temporada no hay copas.", 16))
		return
	if view_cup < 0 or view_cup >= career.cups.size():
		view_cup = career.pending_event()
		if view_cup < 0:
			view_cup = 0
			for i in career.cups.size():
				if (career.cups[i]["comp"] as Competition).user_team >= 0:
					view_cup = i
					break
		var row := _center.get_node_or_null("CupRow") as WEStyle.OptionRow
		if row != null:
			row.refresh()
	var box := _scroll_box(body, WEStyle.px(500))
	var e: Dictionary = career.cups[view_cup]
	var comp: Competition = e["comp"]
	var me := comp.user_team
	var status := ""
	if comp.finished():
		status = "Campeón: %s" % comp.team(comp.champion).team_name
	else:
		status = comp.round_name()
	if me >= 0:
		var reach := MasterCareer.cup_reach(comp, me)
		if reach == "Campeón":
			status += "  ·  ¡Tu equipo es campeón!"
		elif comp.alive(me):
			status += "  ·  Tu equipo sigue en carrera"
		else:
			status += "  ·  Tu equipo quedó afuera (%s)" % reach
	else:
		status += "  ·  Tu equipo no la juega"
	box.add_child(_wrap(status, Color.WHITE))
	# Tus partidos.
	if me >= 0:
		var mine: Array = []
		for ri in comp.rounds.size():
			for g in comp.rounds[ri]:
				if g["home"] == me or g["away"] == me:
					mine.append([ri, g])
		if not mine.is_empty():
			box.add_child(_lbl("Tus partidos", 15, BLUE))
			for it in mine:
				box.add_child(_lbl("  %s: %s" % [comp.round_name(it[0]), cup_game_text(comp, it[1])], 14, GOLD))
	# La fase que se está jugando (o la última).
	if comp.in_first_phase() and comp.ko == "swiss":
		box.add_child(_lbl("Fase liga  ·  1.º a 8.º a octavos, 9.º a 24.º al playoff", 15, BLUE))
		var pos := 1
		for row in comp.standings(0, comp.group_rounds):
			var c := UP if pos <= 8 else (Color.WHITE if pos <= 24 else WEStyle.TEXT_DIM)
			if row["team"] == me:
				c = GOLD
			box.add_child(_lbl("  %2d. %s   %d pts  (%d PJ, %+d)" % [pos, comp.team(row["team"]).team_name,
				int(row["pts"]), int(row["pj"]), int(row["dg"])], 14, c))
			pos += 1
	elif comp.in_first_phase():
		for gi in comp.groups.size():
			var parts: Array = []
			for row in comp.group_table(gi):
				parts.append("%s %d" % [comp.team(row["team"]).team_name, int(row["pts"])])
			box.add_child(_wrap("Grupo %s: %s" % [Competition.WC_GROUP_LETTERS[gi], ", ".join(parts)],
				GOLD if me >= 0 and comp.group_of(me) == gi else Color.WHITE))
	else:
		var r := mini(comp.current, comp.rounds.size() - 1)
		if r >= 0:
			box.add_child(_lbl(comp.round_name(r), 15, BLUE))
			for g in comp.rounds[r]:
				var mine_g: bool = g["home"] == me or g["away"] == me
				box.add_child(_lbl("  " + cup_game_text(comp, g), 14, GOLD if mine_g else Color.WHITE))
	var wc_y := career.first_year + career.season - 1
	var next_wc := MasterCareer.WORLD_CUP_FIRST
	while next_wc < wc_y:
		next_wc += 4
	var next_cwc := CareerCups.CLUB_WORLD_CUP_FIRST
	while next_cwc < wc_y:
		next_cwc += 4
	box.add_child(_lbl("Mundial de Clubes: antes de la temporada %d. Mundial: al terminar la de %d." % [next_cwc, next_wc], 14, BLUE))


## "Boca  2 - 1  River  (global 3-3, pen. 4-2)".
func cup_game_text(comp: Competition, g: Dictionary) -> String:
	var txt := result_text(comp, g)
	var res: Array = g["result"]
	var extra: Array = []
	if g.has("agg") and res.size() >= 2:
		extra.append("global %d-%d" % [int(res[0]) + int(g["agg"][0]), int(res[1]) + int(g["agg"][1])])
	if res.size() >= 4:
		extra.append("pen. %d-%d" % [res[2], res[3]])
	if not extra.is_empty():
		txt += "  (%s)" % ", ".join(extra)
	return txt


## Noticias de la carrera, las más nuevas arriba.
func _news(body: Control) -> void:
	var box := _scroll_box(body)
	var colors := {"lesion": DOWN, "susp": WEStyle.ACCENT, "pase": BLUE, "bombazo": GOLD, "temporada": UP}
	var list := career.latest_news(60)
	if list.is_empty():
		box.add_child(_lbl("Todavía no hay noticias.", 17))
	for n in list:
		var l := _lbl("T%d · F%d   %s" % [int(n["season"]), int(n["round"]), n["text"]], 15,
			colors.get(n["kind"], Color.WHITE))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(_cw() - 16, 0)
		box.add_child(l)
	body.add_child(_lbl("T: temporada · F: fecha · Stick derecho o RePág / AvPág: mover", 14, WEStyle.TEXT_DIM))


## Historial de tus temporadas y palmarés.
func _history(body: Control) -> void:
	var box := _scroll_box(body)
	var hon := career.club_honours()
	box.add_child(_lbl("Palmarés de %s" % career.user_team().team_name, 18, GOLD))
	var titles: Array = hon["titles"]
	var t := _lbl("Títulos: %s" % (", ".join(titles) if not titles.is_empty() else "ninguno todavía"), 15, Color.WHITE)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(_cw() - 16, 0)
	box.add_child(t)
	box.add_child(_lbl("Ascensos: %d · Descensos: %d" % [hon["promotions"], hon["relegations"]], 15))
	box.add_child(_lbl("Temporadas", 17, BLUE))
	var rows := career.club_history()
	if rows.is_empty():
		box.add_child(_lbl("Todavía no terminó ninguna temporada.", 15))
	else:
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 0)
		box.add_child(grid)
		for h in ["Año", "División", "Pos", "", "Copas", "Goleador"]:
			grid.add_child(_lbl(h, 14, BLUE))
		for r in rows:
			var went: String = {"up": "Ascenso", "down": "Descenso"}.get(r["went"], "")
			var c: Color = GOLD if r["champion"] else (UP if r["went"] == "up" else (DOWN if r["went"] == "down" else Color.WHITE))
			grid.add_child(_lbl(str(r["year"]), 15, c))
			var dn := _lbl(String(r["division"]), 15, c)
			dn.custom_minimum_size = Vector2(_cw() * 0.28, 0)
			dn.clip_text = true
			grid.add_child(dn)
			grid.add_child(_lbl("%d.º" % r["pos"], 15, c))
			grid.add_child(_lbl("Campeón" if r["champion"] else went, 15, c))
			var won: int = (r["cups"] as Array).filter(func(x: Array) -> bool: return x[1] == "Campeón").size()
			var cup_txt := ("%d título%s" % [won, "" if won == 1 else "s"]) if won > 0 else String(r["cup"])
			grid.add_child(_lbl(cup_txt, 15, GOLD if won > 0 else c))
			var sc: Dictionary = r["scorer"]
			grid.add_child(_lbl("%s (%d)" % [sc["n"], int(sc["goals"])] if not sc.is_empty() else "", 15, c))
	var rec := career.goal_record()
	if not rec.is_empty():
		box.add_child(_lbl("Récord de goles en una temporada: %s (%s), %d en %s" % [rec["n"], _name(String(rec["club"])),
			int(rec["goals"]), rec["year"]], 15, BLUE))
	for s in career.history:
		var cups: Dictionary = s.get("cups", {})
		var parts: Array = []
		for k in cups:
			parts.append("%s: %s" % [cups[k]["name"], cups[k]["champion"]])
		if s.has("world_cup"):
			var wc: Dictionary = s["world_cup"]
			parts.append("Mundial: %s (%s: %s)" % [wc["champion"], wc["nation"], wc["reach"]])
		for a in s.get("awards", []):
			if a["award"] == "Balón de Oro":
				parts.append("Balón de Oro: %s (%s)" % [a["n"], a["club"]])
		if not parts.is_empty():
			var l := _lbl("%s · %s" % [s.get("year", ""), " · ".join(parts)], 14)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(_cw() - 16, 0)
			box.add_child(l)
	var most := career.most_titles(8)
	if not most.is_empty():
		box.add_child(_lbl("Más campeones de la carrera", 17, BLUE))
		for m in most:
			var mine: bool = m[0] == career.user_club
			box.add_child(_lbl("  %s: %d" % [_name(String(m[0])), int(m[1])], 15, GOLD if mine else Color.WHITE))


## Tus partidos de la temporada: fecha, local o visitante, rival y resultado.
func _calendar(body: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(_cw(), WEStyle.px(560))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	WEStyle.pad_scroll(scroll)
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 0)
	scroll.add_child(grid)
	for h in ["Fecha", "", "Rival", "Resultado"]:
		grid.add_child(_lbl(h, 14, BLUE))
	var now_row: Control = null
	for m in career.calendar():
		var res: Array = m["result"]
		var c := Color.WHITE
		if res.size() == 2:
			c = UP if res[0] > res[1] else (DOWN if res[0] < res[1] else WEStyle.TEXT_DIM)
		if m["current"]:
			c = GOLD
		grid.add_child(_lbl(str(m["round"]), 15, c))
		grid.add_child(_lbl("L" if m["home"] else "V", 15, c))
		var rival := _lbl(String(m["rival"]), 15, c)
		rival.custom_minimum_size = Vector2(_cw() * 0.5, 0)
		rival.clip_text = true
		grid.add_child(rival)
		grid.add_child(_lbl("%d - %d" % [res[0], res[1]] if res.size() == 2 else ("próxima" if m["current"] else ""), 15, c))
		if m["current"]:
			now_row = rival
	body.add_child(_lbl("L: local · V: visitante · Verde ganado, rojo perdido · Stick derecho o RePág / AvPág: mover", 14,
		WEStyle.TEXT_DIM))
	if now_row != null:
		_scroll_to.call_deferred(scroll, now_row)


func _name(club_id: String) -> String:
	return TeamDB.load_team(TeamDB.club_path(career.country, club_id)).team_name


## Que se vea la fila del club del jugador (cuando la tabla ya tiene tamaño).
func _scroll_to(scroll: ScrollContainer, row: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(row):
		scroll.ensure_control_visible(row)


func _scorers(body: Control) -> void:
	var list := career.top_scorers(view_division, 20)
	if list.is_empty():
		body.add_child(_lbl("Todavía no hubo goles.", 18))
		return
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 1)
	body.add_child(grid)
	for h in ["", "Jugador", "Club", "Goles"]:
		grid.add_child(_lbl(h, 14, BLUE))
	var pos := 1
	for row in list:
		var mine: bool = String(row["club"]) == career.user_club
		var c := GOLD if mine else Color.WHITE
		grid.add_child(_lbl(str(pos), 15, c))
		var pn := _lbl(String(row["n"]), 15, c)
		pn.custom_minimum_size = Vector2(_cw() * 0.36, 0)
		pn.clip_text = true
		grid.add_child(pn)
		var cn := _lbl(_name(String(row["club"])), 15, c)
		cn.custom_minimum_size = Vector2(_cw() * 0.36, 0)
		cn.clip_text = true
		grid.add_child(cn)
		grid.add_child(_lbl(str(row["goals"]), 15, c))
		pos += 1


func result_text(comp: Competition, g: Dictionary) -> String:
	var r: Array = g["result"]
	if r.size() >= 2:
		return "%s  %d - %d  %s" % [comp.team(g["home"]).team_name, r[0], r[1], comp.team(g["away"]).team_name]
	return "%s  vs  %s" % [comp.team(g["home"]).team_name, comp.team(g["away"]).team_name]

# --- Plantel y mercado (pantallas aparte) -----------------------------------------------

## Plantel y Dirección del equipo (pantalla aparte, encima del hub).
func _open_squad() -> void:
	if _squad == null:
		_squad = MasterSquad.new()
		add_child(_squad)
		_squad.closed.connect(_overlay_closed)
	_frame.visible = false
	_squad.open(career)


## Mercado de pases (pantalla aparte).
func _open_market() -> void:
	if _market == null:
		_market = MasterMarket.new()
		add_child(_market)
		_market.closed.connect(_overlay_closed)
	_frame.visible = false
	_market.open(career)


func _overlay_closed() -> void:
	_frame.visible = true
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or (_squad != null and _squad.visible) or (_market != null and _market.visible):
		return
	if event.is_action_pressed(&"ui_tab_prev"):
		_set_view(view_mode - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_tab_next"):
		_set_view(view_mode + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		career.save()
		back.emit()
		get_viewport().set_input_as_handled()
