class_name MasterHub
extends Control
## Pantalla de la Liga Master: a la izquierda la tabla (o los goleadores) de
## cualquier división del país, con la zona de ascenso en verde y la de
## descenso en rojo; a la derecha la temporada, los puntos WE, el próximo
## partido (Jugar / Simular) y los resultados de la última fecha. Al terminar
## la temporada, el resumen: campeones, goleadores, ascensos y descensos.

signal play_match(home_path: String, away_path: String, human_side: int)
signal back

const GOLD := Color(1.0, 0.9, 0.35)
const BLUE := Color(0.6, 0.8, 1.0)
const UP := Color(0.55, 1.0, 0.6)
const DOWN := Color(1.0, 0.55, 0.5)

var career: MasterCareer
## División que se muestra a la izquierda y si se ven los goleadores.
var view_division := 0
var view_scorers := false
var _left: VBoxContainer
var _right: VBoxContainer
var _abandon_armed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lp := WEStyle.panel(Vector2(660, 620))
	lp.position = Vector2(40, 30)
	add_child(lp)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 4)
	lp.add_child(_left)
	var rp := WEStyle.panel(Vector2(520, 620))
	rp.position = Vector2(720, 30)
	add_child(rp)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 7)
	rp.add_child(_right)


func open(c: MasterCareer) -> void:
	career = c
	career.activate()
	view_division = career.user_league_index()
	view_scorers = false
	_abandon_armed = false
	visible = true
	_rebuild()


func _clear(box: Control) -> void:
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()


func _rebuild() -> void:
	_clear(_left)
	_clear(_right)
	_left.add_child(WEStyle.label("LIGA MASTER  ·  TEMPORADA %s" % career.year_label(), 24, GOLD))
	var divs := career.leagues.size()
	_left.add_child(WEStyle.OptionRow.new("División",
		func() -> String: return career.division_name(view_division),
		func(dir: int) -> void:
			view_division = wrapi(view_division + dir, 0, divs)
			_rebuild_left(), "Izquierda / derecha: ver otra división.", 636.0))
	_left.add_child(WEStyle.OptionRow.new("Ver",
		func() -> String: return "Goleadores" if view_scorers else "Tabla",
		func(_dir: int) -> void:
			view_scorers = not view_scorers
			_rebuild_left(), "Tabla de posiciones o goleadores.", 636.0))
	var body := VBoxContainer.new()
	body.name = "Body"
	_left.add_child(body)
	_rebuild_left()
	if career.season_over:
		_season_summary()
	else:
		_next_match()


func _rebuild_left() -> void:
	var body := _left.get_node_or_null("Body")
	if body == null:
		return
	_clear(body)
	# Las filas de opción muestran el valor nuevo.
	for ch in _left.get_children():
		if ch is WEStyle.OptionRow:
			(ch as WEStyle.OptionRow).refresh()
	if view_scorers:
		_scorers(body)
	else:
		_table(body)


func _name(club_id: String) -> String:
	return TeamDB.load_team(TeamDB.club_path(career.country, club_id)).team_name


## Tabla de la división elegida: ascenso en verde, descenso en rojo, el
## club del jugador en dorado.
func _table(body: Control) -> void:
	var comp: Competition = career.leagues[view_division]["comp"]
	var up := TeamDB.relegation_count(career.country, view_division - 1) if view_division > 0 else 0
	var down := TeamDB.relegation_count(career.country, view_division)
	var n := comp.team_paths.size()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(636, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 0)
	scroll.add_child(grid)
	for h in ["", "Equipo", "PJ", "G", "E", "P", "GF", "GC", "DG", "Pts"]:
		grid.add_child(WEStyle.label(h, 14, BLUE))
	var pos := 1
	var my_row: Control = null
	for row in comp.standings():
		var me: bool = comp.team_paths[row["team"]] == career.user_path()
		var c := GOLD if me else (UP if pos <= up else (DOWN if pos > n - down else Color.WHITE))
		grid.add_child(WEStyle.label(str(pos), 15, c))
		var name := WEStyle.label(comp.team(row["team"]).team_name, 15, c)
		name.custom_minimum_size = Vector2(250, 0)
		name.clip_text = true
		grid.add_child(name)
		if me:
			my_row = name
		for k in ["pj", "g", "e", "p", "gf", "gc", "dg", "pts"]:
			grid.add_child(WEStyle.label(str(row[k]), 15, c))
		pos += 1
	var legend := []
	if up > 0:
		legend.append("Verde: suben %d" % up)
	if down > 0:
		legend.append("Rojo: bajan %d" % down)
	if not legend.is_empty():
		body.add_child(WEStyle.label("   ".join(legend), 14, Color(0.75, 0.8, 0.9)))
	if my_row != null:
		_scroll_to.call_deferred(scroll, my_row)


## Que se vea la fila del club del jugador (cuando la tabla ya tiene tamaño).
func _scroll_to(scroll: ScrollContainer, row: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(row):
		scroll.ensure_control_visible(row)


func _scorers(body: Control) -> void:
	var list := career.top_scorers(view_division, 20)
	if list.is_empty():
		body.add_child(WEStyle.label("Todavía no hubo goles.", 18))
		return
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 1)
	body.add_child(grid)
	for h in ["", "Jugador", "Club", "Goles"]:
		grid.add_child(WEStyle.label(h, 14, BLUE))
	var pos := 1
	for row in list:
		var mine: bool = String(row["club"]) == career.user_club
		var c := GOLD if mine else Color.WHITE
		grid.add_child(WEStyle.label(str(pos), 15, c))
		var pn := WEStyle.label(String(row["n"]), 15, c)
		pn.custom_minimum_size = Vector2(220, 0)
		pn.clip_text = true
		grid.add_child(pn)
		var cn := WEStyle.label(_name(String(row["club"])), 15, c)
		cn.custom_minimum_size = Vector2(240, 0)
		cn.clip_text = true
		grid.add_child(cn)
		grid.add_child(WEStyle.label(str(row["goals"]), 15, c))
		pos += 1


func result_text(comp: Competition, g: Dictionary) -> String:
	var r: Array = g["result"]
	if r.size() >= 2:
		return "%s  %d - %d  %s" % [comp.team(g["home"]).team_name, r[0], r[1], comp.team(g["away"]).team_name]
	return "%s  vs  %s" % [comp.team(g["home"]).team_name, comp.team(g["away"]).team_name]


func _next_match() -> void:
	var comp := career.user_league()
	_right.add_child(WEStyle.label(career.user_team().team_name, 24, GOLD))
	_right.add_child(WEStyle.label("%s  ·  %s" % [career.division_name(career.user_league_index()), career.round_text()], 18))
	_right.add_child(WEStyle.label("Puntos WE: %d" % career.points, 18, BLUE))
	# Bajas: lesionados y suspendidos (no entran en el once).
	var abs := career.user_absences()
	if not abs.is_empty():
		var txt := "Bajas: " + ", ".join(abs.slice(0, 3).map(func(a: Dictionary) -> String: return "%s (%s)" % [a["n"], a["why"]]))
		if abs.size() > 3:
			txt += " y %d más" % (abs.size() - 3)
		_right.add_child(_wrap(txt, DOWN))
	var g := career.user_match()
	var first: Button = null
	if g.is_empty():
		_right.add_child(WEStyle.label("Tu liga terminó: faltan fechas de otras divisiones.", 17))
		first = WEStyle.bar("Simular hasta el final", func() -> void:
			career.simulate_to_end()
			career.save()
			_rebuild(), 480.0, 22)
		_right.add_child(first)
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 20)
		_right.add_child(row)
		for side in ["home", "away"]:
			var crest := WEStyle.Crest.new()
			crest.team = comp.team(g[side])
			crest.custom_minimum_size = Vector2(96, 112)
			row.add_child(crest)
			if side == "home":
				row.add_child(WEStyle.label("vs", 26))
		var vs := WEStyle.label(result_text(comp, g), 18)
		vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_right.add_child(vs)
		first = WEStyle.bar("Jugar el partido", func() -> void:
			var side := 0 if g["home"] == comp.user_team else 1
			play_match.emit(comp.team_paths[g["home"]], comp.team_paths[g["away"]], side), 480.0, 22)
		_right.add_child(first)
		_right.add_child(WEStyle.bar("Simular el partido", func() -> void:
			career.play_round()
			career.save()
			_rebuild(), 480.0, 22))
	_right.add_child(WEStyle.bar("Guardar y salir", func() -> void:
		career.save()
		back.emit(), 480.0, 22))
	var ab := WEStyle.bar("Abandonar la carrera", Callable(), 480.0, 22)
	ab.pressed.connect(func() -> void:
		if _abandon_armed:
			career.delete_file()
			back.emit()
		else:
			_abandon_armed = true
			ab.text = "¿Seguro? Se borra la carrera (X otra vez)")
	_right.add_child(ab)
	if comp.current > 0:
		_right.add_child(WEStyle.label("Última fecha:", 17, BLUE))
		var last: Array = comp.rounds[comp.current - 1]
		var mine := last.filter(func(pg: Dictionary) -> bool: return pg["home"] == comp.user_team or pg["away"] == comp.user_team)
		var rest := last.filter(func(pg: Dictionary) -> bool: return not mine.has(pg))
		for pg in (mine + rest).slice(0, 4):
			var l := WEStyle.label(result_text(comp, pg), 15, GOLD if mine.has(pg) else Color.WHITE)
			l.clip_text = true
			l.custom_minimum_size = Vector2(480, 0)
			_right.add_child(l)
	if first != null:
		first.grab_focus()


## Fin de temporada: cómo le fue al jugador, campeones y goleadores de cada
## división, ascensos y descensos.
func _season_summary() -> void:
	var s := career.last_summary()
	var u: Dictionary = s.get("user", {})
	_right.add_child(WEStyle.label("FIN DE LA TEMPORADA %s" % s.get("year", ""), 24, GOLD))
	var went := String(u.get("went", "stay"))
	var verdict := "Terminaste %d.º en %s." % [int(u.get("pos", 0)), u.get("division_name", "")]
	if int(u.get("pos", 0)) == 1:
		verdict = "¡CAMPEÓN de %s!" % u.get("division_name", "")
	_right.add_child(WEStyle.label(verdict, 20, UP if int(u.get("pos", 0)) == 1 else Color.WHITE))
	if went == "up":
		_right.add_child(WEStyle.label("¡ASCENDISTE!", 22, UP))
	elif went == "down":
		_right.add_child(WEStyle.label("Descendiste.", 20, DOWN))
	_right.add_child(WEStyle.label("Puntos WE: %d" % career.points, 18, BLUE))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(490, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	scroll.add_child(box)
	# Tu plantel en el cambio de año: retiros, juveniles y los que más crecieron.
	box.add_child(WEStyle.label("Tu plantel", 17, BLUE))
	if not (u.get("retired", []) as Array).is_empty():
		box.add_child(_wrap("  Se retiraron: " + ", ".join(u["retired"]), DOWN))
	if not (u.get("youth", []) as Array).is_empty():
		box.add_child(_wrap("  Juveniles: " + ", ".join(u["youth"]), UP))
	if not (u.get("risers", []) as Array).is_empty():
		box.add_child(_wrap("  Crecieron: " + ", ".join((u["risers"] as Array).map(func(r: Array) -> String:
			return "%s (+%d)" % [r[0], int(r[1])])), Color.WHITE))
	if (u.get("retired", []) as Array).is_empty() and (u.get("youth", []) as Array).is_empty():
		box.add_child(WEStyle.label("  Sin retiros.", 15))
	for d in s.get("divisions", []):
		box.add_child(WEStyle.label(String(d["name"]), 17, BLUE))
		box.add_child(WEStyle.label("  Campeón: %s" % _name(String(d["champion"])), 15, GOLD))
		var ts: Dictionary = d.get("top_scorer", {})
		if not ts.is_empty():
			box.add_child(WEStyle.label("  Goleador: %s (%s) %d goles" % [ts["n"], _name(String(ts["club"])), int(ts["goals"])], 15))
		if not (d["up"] as Array).is_empty():
			box.add_child(_wrap("  Suben: " + ", ".join((d["up"] as Array).map(_name)), UP))
		if not (d["down"] as Array).is_empty():
			box.add_child(_wrap("  Bajan: " + ", ".join((d["down"] as Array).map(_name)), DOWN))
	var next := WEStyle.bar("Empezar la temporada %d" % (career.first_year + career.season), func() -> void:
		career.start_next_season()
		career.save()
		view_division = career.user_league_index()
		_rebuild(), 480.0, 22)
	_right.add_child(next)
	_right.add_child(WEStyle.bar("Guardar y salir", func() -> void:
		career.save()
		back.emit(), 480.0, 22))
	next.grab_focus()


func _wrap(text: String, color: Color) -> Label:
	var l := WEStyle.label(text, 15, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(470, 0)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		career.save()
		back.emit()
		get_viewport().set_input_as_handled()
