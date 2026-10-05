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
## Qué se ve a la izquierda: 0 tabla, 1 goleadores, 2 calendario,
## 3 noticias, 4 historial y palmarés.
var view_mode := 0
const VIEW_NAMES := ["Tabla", "Goleadores", "Calendario", "Copas", "Noticias", "Historial"]
var _squad: MasterSquad
var _market: MasterMarket
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
	view_mode = 0
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
		func() -> String: return VIEW_NAMES[view_mode],
		func(dir: int) -> void:
			view_mode = wrapi(view_mode + dir, 0, VIEW_NAMES.size())
			_rebuild_left(), "Tabla, goleadores, calendario, noticias o historial.", 636.0))
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


func _scroll_box(body: Control, h: float = 480.0) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(636, h)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	WEStyle.pad_scroll(scroll)
	body.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	scroll.add_child(box)
	return box


## Copas de la temporada: la nacional (tu camino y la última ronda) y la
## continental (grupos o llaves).
func _cups(body: Control) -> void:
	var box := _scroll_box(body)
	var specs := [[career.national_cup, career.national_cup_name()], [career.continental, career.cont_name]]
	for spec in specs:
		var comp: Competition = spec[0]
		if comp == null:
			continue
		box.add_child(WEStyle.label(String(spec[1]), 18, GOLD))
		var me := comp.user_team
		var status := ""
		if comp.finished():
			status = "Campeón: %s" % comp.team(comp.champion).team_name
		else:
			status = comp.round_name()
		if me >= 0:
			var reach := MasterCareer.cup_reach(comp, me)
			status += "  ·  Tu equipo: %s" % (("sigue en carrera" if comp.alive(me) else "eliminado en " + reach) if reach != "Campeón" else "¡campeón!")
		else:
			status += "  ·  Tu equipo no la juega"
		var st := WEStyle.label(status, 15)
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		st.custom_minimum_size = Vector2(610, 0)
		box.add_child(st)
		if comp.kind == Competition.Kind.WORLD_CUP and comp.current < Competition.WC_GROUP_ROUNDS:
			for gi in comp.groups.size():
				var line := "Grupo %s: " % Competition.WC_GROUP_LETTERS[gi]
				var parts: Array = []
				for row in comp.group_table(gi):
					parts.append("%s %d" % [comp.team(row["team"]).team_name, int(row["pts"])])
				var gl := WEStyle.label(line + ", ".join(parts), 14, GOLD if comp.group_of(me) == gi and me >= 0 else Color.WHITE)
				gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				gl.custom_minimum_size = Vector2(610, 0)
				box.add_child(gl)
		elif comp.current > 0:
			var r := mini(comp.current, comp.rounds.size()) - 1
			box.add_child(WEStyle.label(comp.round_name(r), 15, BLUE))
			var games: Array = comp.rounds[r]
			var mine := games.filter(func(gm: Dictionary) -> bool: return gm["home"] == me or gm["away"] == me)
			var rest := games.filter(func(gm: Dictionary) -> bool: return not mine.has(gm))
			for gm in (mine + rest).slice(0, 8):
				var res: Array = gm["result"]
				var txt := result_text(comp, gm)
				if res.size() >= 4:
					txt += "  (pen. %d-%d)" % [res[2], res[3]]
				box.add_child(WEStyle.label(txt, 14, GOLD if mine.has(gm) else Color.WHITE))
	if career.national_cup == null:
		box.add_child(WEStyle.label("Las copas empiezan la temporada que viene.", 16))
	var wc_y := career.first_year + career.season - 1
	var next_wc := MasterCareer.WORLD_CUP_FIRST
	while next_wc < wc_y:
		next_wc += 4
	box.add_child(WEStyle.label("Mundial: al terminar la temporada %d (con convocados de la carrera)." % next_wc, 15, BLUE))


## Noticias de la carrera, las más nuevas arriba.
func _news(body: Control) -> void:
	var box := _scroll_box(body)
	var colors := {"lesion": DOWN, "susp": Color(1.0, 0.75, 0.4), "pase": BLUE, "bombazo": GOLD, "temporada": UP}
	var list := career.latest_news(60)
	if list.is_empty():
		box.add_child(WEStyle.label("Todavía no hay noticias.", 17))
	for n in list:
		var l := WEStyle.label("T%d · F%d   %s" % [int(n["season"]), int(n["round"]), n["text"]], 15,
			colors.get(n["kind"], Color.WHITE))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(610, 0)
		box.add_child(l)
	body.add_child(WEStyle.label("T: temporada · F: fecha · Stick derecho o RePág / AvPág: mover", 14, Color(0.75, 0.8, 0.9)))


## Historial de tus temporadas y palmarés.
func _history(body: Control) -> void:
	var box := _scroll_box(body)
	var hon := career.club_honours()
	box.add_child(WEStyle.label("Palmarés de %s" % career.user_team().team_name, 18, GOLD))
	var titles: Array = hon["titles"]
	var t := WEStyle.label("Títulos: %s" % (", ".join(titles) if not titles.is_empty() else "ninguno todavía"), 15, Color.WHITE)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(610, 0)
	box.add_child(t)
	box.add_child(WEStyle.label("Ascensos: %d · Descensos: %d" % [hon["promotions"], hon["relegations"]], 15))
	box.add_child(WEStyle.label("Temporadas", 17, BLUE))
	var rows := career.club_history()
	if rows.is_empty():
		box.add_child(WEStyle.label("Todavía no terminó ninguna temporada.", 15))
	else:
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 0)
		box.add_child(grid)
		for h in ["Año", "División", "Pos", "", "Copa", "Goleador"]:
			grid.add_child(WEStyle.label(h, 14, BLUE))
		for r in rows:
			var went: String = {"up": "Ascenso", "down": "Descenso"}.get(r["went"], "")
			var c: Color = GOLD if r["champion"] else (UP if r["went"] == "up" else (DOWN if r["went"] == "down" else Color.WHITE))
			grid.add_child(WEStyle.label(str(r["year"]), 15, c))
			var dn := WEStyle.label(String(r["division"]), 15, c)
			dn.custom_minimum_size = Vector2(150, 0)
			dn.clip_text = true
			grid.add_child(dn)
			grid.add_child(WEStyle.label("%d.º" % r["pos"], 15, c))
			grid.add_child(WEStyle.label("Campeón" if r["champion"] else went, 15, c))
			grid.add_child(WEStyle.label(String(r["cup"]), 15, GOLD if r["cup"] == "Campeón" else c))
			var sc: Dictionary = r["scorer"]
			grid.add_child(WEStyle.label("%s (%d)" % [sc["n"], int(sc["goals"])] if not sc.is_empty() else "", 15, c))
	var rec := career.goal_record()
	if not rec.is_empty():
		box.add_child(WEStyle.label("Récord de goles en una temporada: %s (%s), %d en %s" % [rec["n"], _name(String(rec["club"])),
			int(rec["goals"]), rec["year"]], 15, BLUE))
	for s in career.history:
		var cups: Dictionary = s.get("cups", {})
		var parts: Array = []
		for k in ["national", "continental"]:
			if cups.has(k):
				parts.append("%s: %s" % [cups[k]["name"], cups[k]["champion"]])
		if s.has("world_cup"):
			var wc: Dictionary = s["world_cup"]
			parts.append("Mundial: %s (%s: %s)" % [wc["champion"], wc["nation"], wc["reach"]])
		if not parts.is_empty():
			var l := WEStyle.label("%s · %s" % [s.get("year", ""), " · ".join(parts)], 14)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(610, 0)
			box.add_child(l)
	var most := career.most_titles(8)
	if not most.is_empty():
		box.add_child(WEStyle.label("Más campeones de la carrera", 17, BLUE))
		for m in most:
			var mine: bool = m[0] == career.user_club
			box.add_child(WEStyle.label("  %s: %d" % [_name(String(m[0])), int(m[1])], 15, GOLD if mine else Color.WHITE))


## Tus partidos de la temporada: fecha, local o visitante, rival y resultado.
func _calendar(body: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(636, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	WEStyle.pad_scroll(scroll)
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 0)
	scroll.add_child(grid)
	for h in ["Fecha", "", "Rival", "Resultado"]:
		grid.add_child(WEStyle.label(h, 14, BLUE))
	var now_row: Control = null
	for m in career.calendar():
		var res: Array = m["result"]
		var c := Color.WHITE
		if res.size() == 2:
			c = UP if res[0] > res[1] else (DOWN if res[0] < res[1] else Color(0.85, 0.85, 0.85))
		if m["current"]:
			c = GOLD
		grid.add_child(WEStyle.label(str(m["round"]), 15, c))
		grid.add_child(WEStyle.label("L" if m["home"] else "V", 15, c))
		var rival := WEStyle.label(String(m["rival"]), 15, c)
		rival.custom_minimum_size = Vector2(330, 0)
		rival.clip_text = true
		grid.add_child(rival)
		grid.add_child(WEStyle.label("%d - %d" % [res[0], res[1]] if res.size() == 2 else ("próxima" if m["current"] else ""), 15, c))
		if m["current"]:
			now_row = rival
	body.add_child(WEStyle.label("L: local · V: visitante · Verde ganado, rojo perdido · Stick derecho o RePág / AvPág: mover", 14,
		Color(0.75, 0.8, 0.9)))
	if now_row != null:
		_scroll_to.call_deferred(scroll, now_row)


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
	scroll.custom_minimum_size = Vector2(636, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	WEStyle.pad_scroll(scroll)
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
	legend.append("Stick derecho o RePág / AvPág: mover la tabla")
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
	var comp := career.current_comp()
	var cup_day := career.pending_event() != ""
	_right.add_child(WEStyle.label(career.user_team().team_name, 24, GOLD))
	var where := WEStyle.label("%s  ·  %s" % [career.current_comp_name(), career.round_text()], 18, GOLD if cup_day else Color.WHITE)
	where.clip_text = true
	where.custom_minimum_size = Vector2(480, 0)
	_right.add_child(where)
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
	if g.is_empty() and cup_day:
		_right.add_child(WEStyle.label("Fecha de copa: tu equipo no la juega.", 17))
		first = WEStyle.bar("Simular la fecha de copa", func() -> void:
			career.play_round()
			career.save()
			_rebuild(), 480.0, 22)
		_right.add_child(first)
	elif g.is_empty():
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
			crest.custom_minimum_size = Vector2(80, 92)
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
	_right.add_child(WEStyle.bar("Plantel y Dirección", _open_squad, 480.0, 22))
	_right.add_child(WEStyle.bar("Mercado de pases%s" % ("" if career.market_open() else " (cerrado)"), _open_market, 480.0, 22))
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
	var league := career.user_league()
	if league.current > 0:
		_right.add_child(WEStyle.label("Última fecha:", 17, BLUE))
		var last: Array = league.rounds[league.current - 1]
		var mine := last.filter(func(pg: Dictionary) -> bool: return pg["home"] == league.user_team or pg["away"] == league.user_team)
		var rest := last.filter(func(pg: Dictionary) -> bool: return not mine.has(pg))
		for pg in (mine + rest).slice(0, 2):
			var l := WEStyle.label(result_text(league, pg), 15, GOLD if mine.has(pg) else Color.WHITE)
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
	scroll.custom_minimum_size = Vector2(490, 250)
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
	# Copas y Mundial.
	var cups: Dictionary = s.get("cups", {})
	for k in ["national", "continental"]:
		if cups.has(k):
			var cp: Dictionary = cups[k]
			box.add_child(WEStyle.label(String(cp["name"]), 17, BLUE))
			box.add_child(_wrap("  Campeón: %s%s" % [cp["champion"], ("  ·  Tu equipo: %s" % cp["user"]) if String(cp["user"]) != "" else ""], GOLD))
	if s.has("world_cup"):
		var wc: Dictionary = s["world_cup"]
		box.add_child(WEStyle.label("Mundial %s" % wc["year"], 17, BLUE))
		box.add_child(_wrap("  Campeón: %s  ·  %s: %s" % [wc["champion"], wc["nation"], wc["reach"]], GOLD))
		if not (wc["called"] as Array).is_empty():
			box.add_child(_wrap("  Convocados de tu club: " + ", ".join(wc["called"]), UP))
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
	_right.add_child(WEStyle.bar("Mercado de pases (pretemporada)", _open_market, 480.0, 22))
	_right.add_child(WEStyle.bar("Guardar y salir", func() -> void:
		career.save()
		back.emit(), 480.0, 22))
	next.grab_focus()


func _wrap(text: String, color: Color) -> Label:
	var l := WEStyle.label(text, 15, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(470, 0)
	return l


## Plantel y Dirección del equipo (pantalla aparte, encima del hub).
func _open_squad() -> void:
	if _squad == null:
		_squad = MasterSquad.new()
		add_child(_squad)
		_squad.closed.connect(_overlay_closed)
	_left.get_parent().visible = false
	_right.get_parent().visible = false
	_squad.open(career)


## Mercado de pases (pantalla aparte).
func _open_market() -> void:
	if _market == null:
		_market = MasterMarket.new()
		add_child(_market)
		_market.closed.connect(_overlay_closed)
	_left.get_parent().visible = false
	_right.get_parent().visible = false
	_market.open(career)


func _overlay_closed() -> void:
	_left.get_parent().visible = true
	_right.get_parent().visible = true
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or (_squad != null and _squad.visible) or (_market != null and _market.visible):
		return
	if event.is_action_pressed(&"ui_cancel"):
		career.save()
		back.emit()
		get_viewport().set_input_as_handled()
