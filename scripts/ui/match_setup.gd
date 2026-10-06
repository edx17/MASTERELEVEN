class_name MatchSetup
extends Control
## Configuración del partido (el "Match Mode" del WE): horario, clima, viento,
## césped, duración, nivel de la CPU, offside, estadio y el uniforme de cada
## equipo. A la derecha, la miniatura del estadio; abajo los uniformes y una
## ayuda de la opción elegida.

signal play
signal back

var _rows: Array[WEStyle.OptionRow] = []
var _thumb: TextureRect
var _kits: Array[WEStyle.KitIcon] = []
var _kit_labels: Array[Label] = []
var _help: Label
var _stadium: Label
var _frame: WEStyle.ScreenFrame
var _home: TeamData
var _away: TeamData


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame = WEStyle.ScreenFrame.new("Configuración del partido",
		[[&"ui_navigate", "Cambiar"], [&"ui_accept", "Aceptar"], [&"ui_cancel", "Volver"]])
	add_child(_frame)
	_frame.crumb.text = "PARTIDO  /  CONFIGURACIÓN"
	_frame.title.text = "CONFIGURACIÓN DEL PARTIDO"
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", int(WEStyle.px(40)))
	_frame.body.add_child(row)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", int(WEStyle.px(2)))
	row.add_child(list)
	_add(list, "Horario", func() -> String: return _choice(GameSettings.time_choice, MatchConditions.TIME_NAMES),
		_cycle.bind("time_choice", MatchConditions.TIME_NAMES.size()), "Tarde, atardecer o noche (con las luces del estadio).")
	_add(list, "Clima", func() -> String: return _choice(GameSettings.weather_choice, MatchConditions.WEATHER_NAMES),
		_cycle.bind("weather_choice", MatchConditions.WEATHER_NAMES.size()), "Con lluvia la pelota pica menos y corre más; con nieve se frena.")
	_add(list, "Viento", func() -> String: return _choice(GameSettings.wind_choice, GameSettings.WIND_NAMES),
		_cycle.bind("wind_choice", GameSettings.WIND_NAMES.size()), "El viento desvía la pelota en el aire.")
	_add(list, "Césped", func() -> String: return "según el clima" if GameSettings.pitch_choice < 0 else GameSettings.PITCH_NAMES[GameSettings.pitch_choice],
		_cycle.bind("pitch_choice", GameSettings.PITCH_NAMES.size()), "Mojado: la pelota corre más y los jugadores pueden resbalar.")
	_add(list, "Estado", func() -> String: return GameSettings.PITCH_WEAR_NAMES[GameSettings.pitch_wear],
		_cycle.bind("pitch_wear", GameSettings.PITCH_WEAR_NAMES.size()), "Gastado: césped con calvas y tierra (textura de cancha de barrio).")
	_add(list, "Duración", func() -> String: return "%d min" % GameSettings.match_minutes, _step_duration,
		"Minutos reales que dura el partido (los 90 del reloj pasan en ese tiempo).")
	_add(list, "Nivel CPU", func() -> String: return Difficulty.NAMES[GameSettings.difficulty], _step_difficulty,
		"Qué tan bien juega la computadora.")
	_add(list, "Offside", func() -> String: return "sí" if GameSettings.offside else "no",
		func(_d: int) -> void: GameSettings.offside = not GameSettings.offside, "Cobrar o no la posición adelantada.")
	_add(list, "Estadio", func() -> String:
			if GameSettings.stadium_choice < 0 and _home != null and _home.stadium != "":
				return "del local (%s)" % _home.stadium
			return _choice(GameSettings.stadium_choice, StadiumStyles.names()),
		_cycle.bind("stadium_choice", StadiumStyles.STYLES.size()),
		"Dónde se juega. \"Al azar\" con un club real de local: su estadio (nombre real, forma según la capacidad).")
	_add(list, "Uniforme local", func() -> String: return "titular" if GameSettings.home_kit == 0 else "alternativo",
		func(_d: int) -> void: GameSettings.home_kit = 1 - GameSettings.home_kit, "Camiseta del local.")
	_add(list, "Uniforme visitante", func() -> String: return "titular" if GameSettings.away_kit == 0 else "alternativo",
		func(_d: int) -> void: GameSettings.away_kit = 1 - GameSettings.away_kit,
		"Camiseta del visitante (si se confunde con la del local, usa la otra).")
	_add(list, "Jugadores", func() -> String:
			if GameSettings.player_style == GameSettings.PlayerStyle.RETRO and not RetroBody.available():
				return "retro (falta el modelo)"
			return GameSettings.PLAYER_STYLE_NAMES[clampi(GameSettings.player_style, 0, GameSettings.PLAYER_STYLE_NAMES.size() - 1)],
		func(d: int) -> void: GameSettings.player_style = posmod(GameSettings.player_style + d, GameSettings.PLAYER_STYLE_NAMES.size()),
		"Modelo de los jugadores. Clásicos: pocos polígonos, como el WE de PS1. Retro (beta): el modelo base estilo PS1. Detallados: el modelo con músculos. Bloques: cuadrados, con rodillas y codos que se doblan.")
	# Jugar y Volver lado a lado, abajo de las opciones.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", int(WEStyle.px(16)))
	list.add_child(_spacer())
	list.add_child(buttons)
	var go := WEStyle.make_action_button("Jugar el partido", func() -> void: play.emit(), true)
	go.name = "Play"
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.focus_entered.connect(func() -> void: _help.text = "Arranca la previa del partido (con la Dirección del equipo).")
	buttons.add_child(go)
	var ret := WEStyle.make_action_button("Volver", func() -> void: back.emit())
	ret.name = "Back"
	ret.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ret.focus_entered.connect(func() -> void: _help.text = "Volver a elegir los equipos.")
	buttons.add_child(ret)
	# Derecha: estadio, uniformes y la ayuda de la opción elegida.
	var right := PanelContainer.new()
	var sb := WEStyle.make_panel_style()
	var pad := WEStyle.px(WEStyle.CARD_PADDING)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	right.add_theme_stylebox_override("panel", sb)
	right.custom_minimum_size.x = WEStyle.px(700)
	row.add_child(right)
	var rbox := VBoxContainer.new()
	rbox.add_theme_constant_override("separation", int(WEStyle.px(12)))
	right.add_child(rbox)
	rbox.add_child(WEStyle.make_caption_label("Estadio"))
	_stadium = WEStyle.make_title_label("", WEStyle.TITLE_M)
	_stadium.clip_text = true
	rbox.add_child(_stadium)
	_thumb = TextureRect.new()
	_thumb.custom_minimum_size = Vector2(0, WEStyle.px(340))
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_thumb.clip_contents = true
	rbox.add_child(_thumb)
	var kits := HBoxContainer.new()
	kits.add_theme_constant_override("separation", int(WEStyle.px(24)))
	rbox.add_child(kits)
	for i in 2:
		var kh := HBoxContainer.new()
		kh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kh.add_theme_constant_override("separation", int(WEStyle.px(12)))
		kits.add_child(kh)
		var kit := WEStyle.KitIcon.new()
		kit.custom_minimum_size = Vector2(WEStyle.px(96), WEStyle.px(104))
		kh.add_child(kit)
		_kits.append(kit)
		var kv := VBoxContainer.new()
		kv.alignment = BoxContainer.ALIGNMENT_CENTER
		kv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kv.add_child(WEStyle.make_caption_label("Local" if i == 0 else "Visitante"))
		var l := WEStyle.make_body_label("", WEStyle.BODY_L)
		l.clip_text = true
		kv.add_child(l)
		kh.add_child(kv)
		_kit_labels.append(l)
	rbox.add_child(WEStyle.make_separator())
	_help = WEStyle.make_body_label("", WEStyle.BODY_M, WEStyle.TEXT_DIM, true)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size.x = WEStyle.px(600)
	rbox.add_child(_help)


func _spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = WEStyle.px(12)
	return c


func open() -> void:
	visible = true
	_home = GameSettings.home_team()
	_away = GameSettings.away_team()
	_frame.title_info.text = "%s  vs  %s" % [_home.team_name, _away.team_name] if _home != null and _away != null else ""
	_refresh()
	_rows[0].grab_focus()
	WEStyle.fade_in(_frame)


func _add(list: VBoxContainer, caption: String, getter: Callable, stepper: Callable, help: String) -> void:
	var row := WEStyle.OptionRow.new(caption, getter, func(d: int) -> void:
		stepper.call(d)
		_refresh(), help, WEStyle.px(900))
	row.use_modern_style()
	row.focus_entered.connect(func() -> void: _help.text = help)
	list.add_child(row)
	_rows.append(row)


func _refresh() -> void:
	GameSettings.save_settings()
	for r in _rows:
		r.queue_redraw()
	_thumb.texture = load("res://scripts/ui/main_menu.gd").stadium_thumbnail(GameSettings.stadium_choice)
	_stadium.text = String(_rows[8].get_value.call()).to_upper() if _rows.size() > 8 else ""
	if _home == null:
		return
	var hk := _home.kit(GameSettings.home_kit)
	var ak_i := GameSettings.away_kit
	if GameSettings.kits_clash(_away.kit(ak_i)[0], hk[0]):
		ak_i = 1 - ak_i
	var names := [_home.team_name, _away.team_name]
	_kits[0].set_kit(_home, GameSettings.home_kit)
	_kits[1].set_kit(_away, ak_i)
	for i in 2:
		_kit_labels[i].text = "%s · %s" % [names[i], "titular" if (GameSettings.home_kit if i == 0 else ak_i) == 0 else "alternativo"]


static func _choice(i: int, names: Array) -> String:
	return "al azar" if i < 0 else String(names[i])


## Recorre -1 (al azar), 0 .. count-1 hacia los dos lados.
func _cycle(dir: int, setting: String, count: int) -> void:
	var v: int = GameSettings.get(setting) + dir
	if v >= count:
		v = -1
	elif v < -1:
		v = count - 1
	GameSettings.set(setting, v)


func _step_duration(dir: int) -> void:
	var opts := GameSettings.DURATION_OPTIONS.duplicate()
	opts.sort()
	var idx := opts.find(GameSettings.match_minutes)
	GameSettings.match_minutes = opts[posmod(idx + dir, opts.size())]


func _step_difficulty(dir: int) -> void:
	GameSettings.difficulty = posmod(GameSettings.difficulty + dir, Difficulty.NAMES.size())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		back.emit()
		get_viewport().set_input_as_handled()
