class_name PauseMenu
extends CanvasLayer
## Pausa (Esc / Start). También resuelve la salida al menú al final del partido.

var _panel: Control
var _help: Label
var _title: Label
var _resume: Button
var _subs_btn: Button
var _camera_row: WEStyle.OptionRow
## Dirección del equipo (cambios, pateadores, capitán, formación).
var _sheet: TeamSheet
## Lista del partido y, en el entrenamiento, el menú de práctica (se arma al
## abrir la pausa por primera vez).
var _box: VBoxContainer
var _train_box: VBoxContainer
var _train_rows: Array[WEStyle.OptionRow] = []
var _train_first: Control
## Submenúes de la pausa (Pantalla, Sonido, Opciones de juego) y el botón
## que abre cada uno (para volver al mismo lugar).
var _subs: Dictionary = {}
var _sub_opener: Dictionary = {}
var _sub_rows: Array[WEStyle.OptionRow] = []
## Mando que pausó (1, 2...; 0 = no se sabe).
var pad := 0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Al estilo del WE: cartel "PAUSA — MANDO 1" arriba a la izquierda, barras
	# violetas a la izquierda (el partido se sigue viendo) y la ayuda abajo.
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var head := ColorRect.new()
	head.color = Color(0.02, 0.02, 0.06, 0.85)
	head.position = Vector2(0, 74)
	head.size = Vector2(520, 50)
	_panel.add_child(head)
	_title = WEStyle.label("PAUSA", 30, Color(0.85, 0.9, 1.0))
	_title.position = Vector2(24, 78)
	_panel.add_child(_title)
	var box := VBoxContainer.new()
	box.position = Vector2(0, 136)
	box.add_theme_constant_override("separation", 5)
	_panel.add_child(box)
	_box = box
	_help = WEStyle.help_box(_panel)
	_resume = _button(box, "Continuar", _toggle, "Volver al partido.")
	_subs_btn = _button(box, "", _open_subs, "Cambios, posiciones, pateadores, capitán, formación y estrategias.")
	_camera_row = _option(box, "Cámara", func() -> String:
			var cam := _camera()
			return cam.config.display_name if cam != null else "-",
		func(d: int) -> void:
			var cam := _camera()
			if cam != null:
				cam.set_preset(cam.preset_index + d, false),
		"Ancha, Normal, Lejana, Vertical... (también con SELECT en el partido).")
	_camera_row.custom_minimum_size.y = 42
	_sub_button(box, "Pantalla", "display", "Radar, marcador y lo que se ve arriba de los jugadores.", [
		["Radar", func() -> String: return "sí" if GameSettings.show_radar else "no",
			func(_d: int) -> void: GameSettings.show_radar = not GameSettings.show_radar,
			"El mapa chico de la cancha, abajo al centro."],
		["Marcador y reloj", func() -> String: return "sí" if GameSettings.show_score else "no",
			func(_d: int) -> void: GameSettings.show_score = not GameSettings.show_score,
			"El resultado y el tiempo, arriba."],
		["Sobre los jugadores", func() -> String: return GameSettings.PLAYER_LABEL_NAMES[GameSettings.player_label],
			func(d: int) -> void:
				GameSettings.player_label = posmod(GameSettings.player_label + d, GameSettings.PLAYER_LABEL_NAMES.size())
				_refresh_labels(),
			"Nombre del que manejás, números, nombres de todos o nada."],
	])
	_sub_button(box, "Sonido", "sound", "Volumen de los efectos y del público.", [
		["Volumen de efectos", func() -> String: return str(GameSettings.sfx_volume),
			func(d: int) -> void: GameSettings.sfx_volume = clampi(GameSettings.sfx_volume + d, 0, 10),
			"Silbato del árbitro, patadas, piques, palo y red."],
		["Volumen del público", func() -> String: return str(GameSettings.crowd_volume),
			func(d: int) -> void: GameSettings.crowd_volume = clampi(GameSettings.crowd_volume + d, 0, 10),
			"El murmullo de la tribuna, los cánticos, los silbidos y los \"uhh\"."],
	])
	_sub_button(box, "Opciones de juego", "game", "Formación, dificultad, movimiento, velocidad y arquero.", [
		["Formación", func() -> String:
				var t := _my_team()
				return t.formation.formation_name if t != null and t.formation != null else "-",
			_step_formation, "Cambiar la formación de tu equipo."],
		["Dificultad CPU", func() -> String: return Difficulty.NAMES[GameSettings.difficulty],
			func(d: int) -> void:
				GameSettings.difficulty = posmod(GameSettings.difficulty + d, Difficulty.NAMES.size())
				var m := get_parent() as MatchController
				if m != null:
					m.apply_difficulty(GameSettings.difficulty),
			"Qué tan bien juega la computadora."],
		["Movimiento", func() -> String:
				var dirs := GameSettings.stick_directions
				return ("%d direcciones" % dirs) if dirs > 0 else "libre",
			func(d: int) -> void:
				var o := GameSettings.STICK_OPTIONS
				GameSettings.stick_directions = o[posmod(o.find(GameSettings.stick_directions) + d, o.size())],
			"8 o 16 rumbos como en el WE, o libre."],
		["Velocidad del juego", func() -> String: return "%+d" % GameSettings.game_speed,
			func(d: int) -> void:
				GameSettings.game_speed = clampi(GameSettings.game_speed + d, -2, 2)
				Engine.time_scale = GameSettings.game_time_scale(),
			"Más lento o más rápido (el reloj del partido no cambia)."],
		["Arquero a los 6 s", func() -> String: return GameSettings.KEEPER_AUTO_NAMES[GameSettings.keeper_auto_action],
			func(_d: int) -> void: GameSettings.keeper_auto_action = 1 - GameSettings.keeper_auto_action,
			"Qué hace tu arquero si no la soltaste a tiempo."],
	])
	_button(box, "Salir del partido", _exit, "Volver al menú principal.")
	_panel.visible = false

	_sheet = TeamSheet.new()
	add_child(_sheet)
	_sheet.closed.connect(_close_subs)


func _button(parent: Control, text: String, cb: Callable, help: String = "") -> Button:
	var b := WEStyle.bar(text, cb, 470.0, 21)
	b.custom_minimum_size.y = 42
	b.focus_entered.connect(func() -> void: _help.text = help)
	parent.add_child(b)
	return b


func _option(parent: Control, caption: String, getter: Callable, stepper: Callable, help: String) -> WEStyle.OptionRow:
	var row := WEStyle.OptionRow.new(caption, getter, func(d: int) -> void:
		stepper.call(d)
		GameSettings.save_settings(), help, 470.0)
	row.custom_minimum_size.y = 38
	row.focus_entered.connect(func() -> void: _help.text = help)
	parent.add_child(row)
	_sub_rows.append(row)
	return row


## Botón de la pausa que abre un submenú con sus opciones (◀ ▶ las cambian;
## "Volver" o atrás regresan a la lista).
func _sub_button(parent: Control, text: String, key: String, help: String, rows: Array) -> void:
	var b := _button(parent, text + "  ▶", _open_sub.bind(key), help)
	var sub := VBoxContainer.new()
	sub.position = Vector2(0, 136)
	sub.add_theme_constant_override("separation", 5)
	sub.visible = false
	_panel.add_child(sub)
	for r in rows:
		_option(sub, r[0], r[1], r[2], r[3])
	_button(sub, "Volver", _close_sub, "Volver a la pausa.")
	_subs[key] = sub
	_sub_opener[key] = b


func _open_sub(key: String) -> void:
	_box.visible = false
	for k in _subs:
		_subs[k].visible = k == key
	_title.text = "%s — %s" % [_title_text(), (_sub_opener[key] as Button).text.trim_suffix("  ▶").to_upper()]
	for r in _sub_rows:
		r.refresh()
	(_subs[key] as Control).get_child(0).grab_focus()


func _close_sub() -> void:
	var opener: Button = null
	for k in _subs:
		if _subs[k].visible:
			opener = _sub_opener[k]
		_subs[k].visible = false
	_box.visible = true
	_refresh()
	if opener != null:
		opener.grab_focus()


func open_sub_key() -> String:
	for k in _subs:
		if _subs[k].visible:
			return k
	return ""


func _camera() -> MatchCamera:
	var m := get_parent() as MatchController
	return m.camera() if m != null else null


func _my_team() -> Team:
	var m := get_parent() as MatchController
	return m.teams[_my_team_index()] if m != null else null


func _refresh_labels() -> void:
	var m := get_parent() as MatchController
	if m != null:
		for p in m.all_players():
			p.refresh_label()


## Qué mando apretó Start: el título dice "PAUSA — MANDO N" (como el WE).
func _pressed_pad() -> int:
	var m := get_parent() as MatchController
	if m == null:
		return 0
	for h in m.humans:
		if Input.is_action_just_pressed(InputRouter.action_name(h.slot, &"pause")):
			return h.slot + 1
	return 1 if not m.humans.is_empty() else 0


func _title_text() -> String:
	return "PAUSA — MANDO %d" % pad if pad > 0 else "PAUSA"


func _process(_dt: float) -> void:
	var m := get_parent() as MatchController
	# Con la pantalla del entretiempo / final, el menú es el de ella.
	if m != null and m.halftime_screen != null and m.halftime_screen.visible:
		return
	if m != null and m.phase == MatchController.Phase.FULLTIME and not _panel.visible:
		if Input.is_action_just_pressed(&"ui_accept") or Input.is_action_just_pressed(&"pause"):
			_exit()
		return
	# Durante la presentación, Start la saltea (no pausa).
	if m != null and m.phase == MatchController.Phase.INTRO:
		return
	# Con la Dirección del equipo abierta, ella maneja el "atrás".
	if _sheet.visible:
		return
	# En un submenú, atrás (o Start) vuelve a la lista de la pausa.
	if open_sub_key() != "":
		if Input.is_action_just_pressed(&"ui_cancel") or Input.is_action_just_pressed(&"pause"):
			_close_sub()
		return
	if Input.is_action_just_pressed(&"pause"):
		if not get_tree().paused:
			pad = _pressed_pad()
		_toggle()


func _toggle() -> void:
	if _sheet.visible:
		_sheet.close()
		return
	if open_sub_key() != "":
		_close_sub()
	var paused := not get_tree().paused
	get_tree().paused = paused
	_panel.visible = paused
	if paused:
		_title.text = _title_text()
		var m := get_parent() as MatchController
		if m != null and m.training != null:
			_open_training(m.training)
			return
		_refresh()
		_resume.grab_focus()


## Equipo del jugador 1 (el que cambia de formación desde la pausa); si pausó
## el mando 2, el suyo.
func _my_team_index() -> int:
	var m := get_parent() as MatchController
	if m != null and not m.humans.is_empty():
		for h in m.humans:
			if h.slot + 1 == pad:
				return h.team.index
		return m.humans[0].team.index
	return 0


func _refresh() -> void:
	GameSettings.save_settings()
	_title.text = _title_text()
	var m := get_parent() as MatchController
	if m == null:
		return
	var t := m.teams[_my_team_index()]
	_subs_btn.text = "Dirección del equipo (%d cambios)" % t.subs_left()
	for r in _sub_rows:
		r.refresh()


# --- Dirección del equipo --------------------------------------------------------

func _open_subs() -> void:
	var m := get_parent() as MatchController
	if m == null:
		return
	_panel.visible = false
	_sheet.open(m, m.teams[_my_team_index()], false)


func _close_subs() -> void:
	_panel.visible = true
	_refresh()
	_subs_btn.grab_focus()


func _step_formation(d: int) -> void:
	var m := get_parent() as MatchController
	if m == null:
		return
	var all := FormationLibrary.load_all()
	var t := m.teams[_my_team_index()]
	var idx := 0
	for i in all.size():
		if t.formation != null and all[i].formation_name == t.formation.formation_name:
			idx = i
	m.set_formation(t.index, all[posmod(idx + d, all.size())])


func _exit() -> void:
	var m := get_parent() as MatchController
	if m != null:
		m.exit_to_menu()
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")



# --- Menú de práctica (entrenamiento) -----------------------------------------------

func _open_training(t: TrainingSession) -> void:
	if _train_box == null:
		_build_training(t)
	_box.visible = false
	_train_box.visible = true
	_refresh_training()
	_train_first.grab_focus()


## Práctica, jugadores de cada lado, pelota parada (dónde, barrera, quién
## patea), reinicio, táctica, cámara y salida.
func _build_training(t: TrainingSession) -> void:
	_train_box = VBoxContainer.new()
	_train_box.position = Vector2(0, 132)
	_train_box.add_theme_constant_override("separation", 3)
	_panel.add_child(_train_box)
	_train_first = _row(t, "Práctica", func() -> String: return TrainingSession.KIND_NAMES[t.kind],
		func(d: int) -> void: t.start(posmod(t.kind + d, TrainingSession.KIND_NAMES.size())),
		"Libre, tiros libres, córners, penales o un desafío con récord.")
	_row(t, "Atacantes", func() -> String: return str(t.attackers),
		func(d: int) -> void:
			t.attackers = clampi(t.attackers + d, 1, 10)
			t.start(),
		"Jugadores de campo de tu equipo (práctica libre y pelota parada).")
	_row(t, "Defensores", func() -> String: return str(t.defenders),
		func(d: int) -> void:
			t.defenders = clampi(t.defenders + d, 0, 10)
			t.start(),
		"Jugadores de campo del rival.")
	_row(t, "Arquero rival", func() -> String: return "sí" if t.rival_keeper else "no",
		func(_d: int) -> void:
			t.rival_keeper = not t.rival_keeper
			t.start(),
		"Con o sin arquero en el arco rival (práctica libre).")
	_row(t, "Distancia del tiro libre", func() -> String: return "%d m" % int(round(t.fk_distance)),
		func(d: int) -> void:
			t.fk_distance = clampf(t.fk_distance + d, 16.0, 36.0)
			t.reset_play(),
		"Desde dónde se patea el tiro libre.")
	_row(t, "Ángulo del tiro libre", func() -> String: return "%+d°" % int(t.fk_angle),
		func(d: int) -> void:
			t.fk_angle = clampf(t.fk_angle + d * 5.0, -50.0, 50.0)
			t.reset_play(),
		"0° = de frente al arco; negativo, del lado izquierdo.")
	_row(t, "Barrera", func() -> String: return "sí" if t.wall else "no",
		func(_d: int) -> void:
			t.wall = not t.wall
			t.reset_play(),
		"Tiro libre con o sin barrera.")
	_row(t, "Córner desde", func() -> String: return "la derecha" if t.corner_side > 0 else "la izquierda",
		func(_d: int) -> void:
			t.corner_side = -t.corner_side
			t.reset_play(),
		"De qué lado se patean los córners.")
	_row(t, "Pateador", func() -> String:
			var p := t.taker()
			return p.display_name if p != null else "-",
		func(d: int) -> void:
			var n := t.outfield(t.my_team()).size()
			t.taker_index = posmod(t.taker_index + d, maxi(n, 1))
			t.reset_play(),
		"Quién patea los tiros libres, córners y penales.")
	_train_box.add_child(_bar("Reiniciar la jugada", func() -> void:
		t.reset_play()
		_toggle(), "Vuelve a armar la jugada desde el principio (también con SELECT)."))
	_train_box.add_child(_bar("Dirección del equipo", _open_subs, "Formación, estrategias y posiciones de tu equipo."))
	_train_box.add_child(_bar("Cambiar de cámara", func() -> void:
		var m := get_parent() as MatchController
		if m != null and m.camera() != null:
			m.camera().set_preset(m.camera().preset_index + 1), "Recorre las cámaras (en la práctica SELECT reinicia)."))
	_train_box.add_child(_bar("Salir del entrenamiento", _exit, "Volver al menú principal."))
	_sheet.closed.connect(func() -> void:
		if _train_box != null and _train_box.visible:
			_train_first.grab_focus())


func _row(t: TrainingSession, caption: String, getter: Callable, stepper: Callable, help: String) -> WEStyle.OptionRow:
	var row := WEStyle.OptionRow.new(caption, getter, func(d: int) -> void:
		stepper.call(d)
		_refresh_training(), help, 470.0)
	row.custom_minimum_size.y = 33
	row.add_theme_font_size_override("font_size", 19)
	row.focus_entered.connect(func() -> void: _help.text = help)
	_train_box.add_child(row)
	_train_rows.append(row)
	return row


func _bar(text: String, cb: Callable, help: String) -> Button:
	var b := WEStyle.bar(text, cb, 470.0, 19)
	b.custom_minimum_size.y = 33
	b.focus_entered.connect(func() -> void: _help.text = help)
	return b


func _refresh_training() -> void:
	for r in _train_rows:
		r.refresh()
