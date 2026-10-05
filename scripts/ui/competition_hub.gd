class_name CompetitionHub
extends Control
## Pantalla de la Liga / Copa: a la izquierda la tabla (liga) o las llaves
## (copa); a la derecha el próximo partido del jugador con "Jugar el
## partido", "Simular" y "Abandonar", y los resultados de la última fecha.

signal play_match(home_path: String, away_path: String, human_side: int)
signal back

var comp: Competition
var _left: VBoxContainer
var _right: VBoxContainer
var _abandon_armed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lp := WEStyle.panel(Vector2(640, 600))
	lp.position = Vector2(60, 40)
	add_child(lp)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 3)
	lp.add_child(_left)
	var rp := WEStyle.panel(Vector2(500, 600))
	rp.position = Vector2(720, 40)
	add_child(rp)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 8)
	rp.add_child(_right)


func open(c: Competition) -> void:
	comp = c
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
	var title := "%s MASTER ELEVEN" % Competition.KIND_NAMES[comp.kind].to_upper()
	_left.add_child(WEStyle.label(title, 26, Color(1.0, 0.9, 0.35)))
	if comp.kind == Competition.Kind.LEAGUE:
		_table()
	else:
		_bracket()
	_next_match()


func _short(i: int) -> String:
	return comp.team(i).team_name


## Tabla de posiciones (el equipo del jugador resaltado).
func _table() -> void:
	# Ligas reales de 20 o más: letra más chica y la tabla se desplaza.
	var big := comp.team_paths.size() > 10
	var fs := 15 if big else 18
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 540)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 0 if big else 3)
	scroll.add_child(grid)
	for h in ["", "Equipo", "PJ", "G", "E", "P", "GF", "GC", "DG", "Pts"]:
		grid.add_child(WEStyle.label(h, fs - 1, Color(0.6, 0.8, 1.0)))
	var pos := 1
	var my_row: Control = null
	for row in comp.standings():
		var me: bool = row["team"] == comp.user_team
		var c := Color(1.0, 0.9, 0.35) if me else Color.WHITE
		grid.add_child(WEStyle.label(str(pos), fs, c))
		var name := WEStyle.label(_short(row["team"]), fs, c)
		name.custom_minimum_size = Vector2(250, 0)
		name.clip_text = true
		grid.add_child(name)
		if me:
			my_row = name
		for k in ["pj", "g", "e", "p", "gf", "gc", "dg", "pts"]:
			grid.add_child(WEStyle.label(str(row[k]), fs, c))
		pos += 1
	# Que se vea la fila del jugador.
	if my_row != null and big:
		scroll.ready.connect(func() -> void: scroll.ensure_control_visible(my_row), CONNECT_ONE_SHOT)


## Llaves de la copa, ronda por ronda.
func _bracket() -> void:
	for i in comp.rounds.size():
		_left.add_child(WEStyle.label(comp.round_name(i), 20, Color(0.6, 0.8, 1.0)))
		for g in comp.rounds[i]:
			_left.add_child(WEStyle.label("   " + result_text(g), 18,
				Color(1.0, 0.9, 0.35) if g["home"] == comp.user_team or g["away"] == comp.user_team else Color.WHITE))


func result_text(g: Dictionary) -> String:
	var r: Array = g["result"]
	var s := "%s  vs  %s" % [_short(g["home"]), _short(g["away"])]
	if r.size() >= 2:
		s = "%s  %d - %d  %s" % [_short(g["home"]), r[0], r[1], _short(g["away"])]
		if r.size() >= 4:
			s += "  (penales %d-%d)" % [r[2], r[3]]
	return s


func _next_match() -> void:
	if comp.finished():
		var champ := comp.champion if comp.champion >= 0 else int(comp.standings()[0]["team"])
		_right.add_child(WEStyle.label("¡CAMPEÓN!", 32, Color(1.0, 0.9, 0.35)))
		var crest := WEStyle.Crest.new()
		crest.team = comp.team(champ)
		crest.custom_minimum_size = Vector2(150, 180)
		_right.add_child(crest)
		_right.add_child(WEStyle.label(comp.team(champ).team_name, 26))
		if champ == comp.user_team:
			_right.add_child(WEStyle.label("¡Ganaste la %s!" % Competition.KIND_NAMES[comp.kind].to_lower(), 20, Color(0.6, 1.0, 0.6)))
		_right.add_child(WEStyle.bar("Terminar", func() -> void:
			Competition.delete_saved()
			back.emit(), 460.0, 22))
		(_right.get_child(_right.get_child_count() - 1) as Control).grab_focus()
		return
	_right.add_child(WEStyle.label(comp.round_name(), 24, Color(1.0, 0.9, 0.35)))
	var g := comp.user_match()
	var first: Button = null
	if g.is_empty():
		_right.add_child(WEStyle.label("Tu equipo quedó eliminado.", 20))
		first = WEStyle.bar("Simular la fecha", func() -> void:
			comp.complete_round()
			comp.save()
			_rebuild(), 460.0, 22)
		_right.add_child(first)
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 20)
		_right.add_child(row)
		for side in ["home", "away"]:
			var crest := WEStyle.Crest.new()
			crest.team = comp.team(g[side])
			crest.custom_minimum_size = Vector2(110, 130)
			row.add_child(crest)
			if side == "home":
				row.add_child(WEStyle.label("vs", 28))
		_right.add_child(WEStyle.label("%s  -  %s" % [_short(g["home"]), _short(g["away"])], 20))
		first = WEStyle.bar("Jugar el partido", func() -> void:
			var side := 0 if g["home"] == comp.user_team else 1
			play_match.emit(comp.team_paths[g["home"]], comp.team_paths[g["away"]], side), 460.0, 22)
		_right.add_child(first)
		_right.add_child(WEStyle.bar("Simular el partido", func() -> void:
			comp.complete_round()
			comp.save()
			_rebuild(), 460.0, 22))
	var ab := WEStyle.bar("Abandonar", Callable(), 460.0, 22)
	ab.pressed.connect(func() -> void:
		if _abandon_armed:
			Competition.delete_saved()
			back.emit()
		else:
			_abandon_armed = true
			ab.text = "¿Seguro? Se pierde todo (X otra vez)")
	_right.add_child(ab)
	_right.add_child(WEStyle.bar("Volver", func() -> void: back.emit(), 460.0, 22))
	if comp.current > 0:
		_right.add_child(WEStyle.label("Última fecha:", 18, Color(0.6, 0.8, 1.0)))
		for pg in comp.rounds[comp.current - 1]:
			_right.add_child(WEStyle.label(result_text(pg), 16))
	if first != null:
		first.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		back.emit()
		get_viewport().set_input_as_handled()
