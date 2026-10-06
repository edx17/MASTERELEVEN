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
var _home: TeamData
var _away: TeamData


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := WEStyle.label("PARTIDO", 30, Color(1.0, 0.9, 0.35))
	title.position = Vector2(70, 40)
	add_child(title)
	var list := VBoxContainer.new()
	list.position = Vector2(70, 86)
	list.add_theme_constant_override("separation", 3)
	add_child(list)
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
	# Jugar y Volver lado a lado, para que todo entre arriba de la caja de ayuda.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	list.add_child(buttons)
	var go := WEStyle.bar("Jugar", func() -> void: play.emit(), 276.0, 22)
	go.focus_entered.connect(func() -> void: _help.text = "Arranca la previa del partido (con la Dirección del equipo).")
	buttons.add_child(go)
	var ret := WEStyle.bar("Volver", func() -> void: back.emit(), 276.0, 22)
	ret.focus_entered.connect(func() -> void: _help.text = "Volver a elegir los equipos.")
	buttons.add_child(ret)
	# Derecha: estadio y uniformes.
	var right := WEStyle.panel(Vector2(500, 0))
	right.position = Vector2(700, 86)
	add_child(right)
	var rbox := VBoxContainer.new()
	right.add_child(rbox)
	_thumb = TextureRect.new()
	_thumb.custom_minimum_size = Vector2(476, 268)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rbox.add_child(_thumb)
	var kits := HBoxContainer.new()
	kits.alignment = BoxContainer.ALIGNMENT_CENTER
	kits.add_theme_constant_override("separation", 60)
	rbox.add_child(kits)
	for i in 2:
		var col := VBoxContainer.new()
		kits.add_child(col)
		var kit := WEStyle.KitIcon.new()
		kit.custom_minimum_size = Vector2(110, 110)
		col.add_child(kit)
		_kits.append(kit)
		var l := WEStyle.label("", 16)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		_kit_labels.append(l)
	_help = WEStyle.help_box(self)


func open() -> void:
	visible = true
	_home = GameSettings.home_team()
	_away = GameSettings.away_team()
	_refresh()
	_rows[0].grab_focus()


func _add(list: VBoxContainer, caption: String, getter: Callable, stepper: Callable, help: String) -> void:
	var row := WEStyle.OptionRow.new(caption, getter, func(d: int) -> void:
		stepper.call(d)
		_refresh(), help)
	row.custom_minimum_size.y = 33
	row.focus_entered.connect(func() -> void: _help.text = help)
	list.add_child(row)
	_rows.append(row)


func _refresh() -> void:
	GameSettings.save_settings()
	for r in _rows:
		r.queue_redraw()
	_thumb.texture = load("res://scripts/ui/main_menu.gd").stadium_thumbnail(GameSettings.stadium_choice)
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
		_kit_labels[i].text = ("LOCAL\n" if i == 0 else "VISITANTE\n") + names[i]


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
