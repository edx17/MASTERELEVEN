extends CanvasLayer
## Pantalla de carga entre el menú y el partido (y al volver): tapa la
## pantalla mientras se carga la escena nueva (en otro hilo) y mientras arma
## el estadio, con un consejo de los controles. El sonido se apaga mientras
## tanto (antes quedaba la pantalla quieta con el ruido de la cancha) y
## vuelve con la escena nueva.
##
## Uso: LoadingScreen.goto("res://scenes/match/match.tscn")

## Tiempo mínimo en pantalla (s), para que se alcance a leer el consejo.
const MIN_TIME := 1.6
## Fundidos de entrada y de salida (s).
const FADE_IN := 0.18
const FADE_OUT := 0.35
## Volumen del bus Master mientras carga (dB).
const MUTED_DB := -60.0
const MATCH_SCENE := "res://scenes/match/match.tscn"

## Consejos para los dos deportes. {X} {O} {SQ} {TRI} {L1} {R1} {L2} {R2} son
## los íconos de los botones (ButtonIcons.fill).
const TIPS_COMMON := [
	"{X} pase corto, {O} pase largo y {TRI} pase al hueco: cuanto más lo mantenés, más fuerte sale.",
	"{SQ} remata. Dos veces {SQ}: remate rasante. {L1} + {SQ}: globo por arriba del arquero.",
	"{R2} mientras cargás el remate: sale colocado, más preciso y con menos fuerza.",
	"{L1} + {R1} + {SQ}: remate potente. Carga más lento, pero sale como un misil.",
	"{L1} + {O}: centro alto. Dos veces {O}: centro raso al primer palo.",
	"{L1} + {X}: pared. El compañero te la devuelve al espacio.",
	"Sin la pelota, {X} mantenido presiona al que la tiene y, al llegar, intenta la entrada.",
	"Sin la pelota, {O} es la barrida: de atrás o de costado es tarjeta casi segura.",
	"Sin la pelota, {SQ} mantenido manda a un compañero a presionar; {TRI} mantenido hace salir al arquero.",
	"{L1} sin la pelota cambia de jugador. Con la pelota, mantenido, conducís pegado al pie.",
	"{R1} es el pique. Cansa: mirá la barra de energía antes de apurar.",
	"{L2} + {X} / {SQ} / {O} / {TRI}: prende o apaga las estrategias del equipo.",
	"{L2} + cruceta izquierda o derecha: mentalidad más defensiva u ofensiva.",
	"{SQ} + {X} o {O} + {X}: amague. Girá el stick derecho para la marsellesa.",
	"En la pelota parada, el stick derecho le da comba al tiro libre.",
	"Start pausa el partido: cambios, Dirección del equipo, cámara y sonido.",
]
const TIPS_FOOTBALL := [
	"{L1} tres veces seguidas: bicicleta. Ideal para un centro que viene alto.",
	"Cuidado con el offside: el pase al hueco {TRI} tiene que salir antes del pique del delantero.",
	"En los penales, la dirección del stick elige el palo y la barra la altura.",
	"Los cambios del rival los avisa el cuarto árbitro con el cartel.",
]
const TIPS_FUTSAL := [
	"{L2} + cruceta arriba: cambio volante. Sale el más cansado y entra el suplente con más energía.",
	"{L2} + cruceta abajo: arquero jugador. En cada ataque entra uno de campo y quedan 5 contra 4.",
	"Tenés 4 segundos para sacar: el árbitro los cuenta con el brazo. Si no, la pelota es del rival.",
	"El arquero tiene 4 segundos con la pelota en su campo, y no la puede volver a tocar si se la devuelven.",
	"El lateral es con el pie, desde la línea. El saque de arco, con la mano.",
	"Desde la 6.ª falta acumulada, tiro libre sin barrera desde el doble penal (10 m).",
	"En la Dirección del equipo armás el segundo cuarteto y la rotación (cada 3', 5' o 7').",
	"La cancha es chica: un pase corto {X} bien jugado vale más que un pelotazo.",
]

var _root: Control
var _title: Label
var _sub: Label
var _tip: ButtonIcons.IconLabel
## Escudos del local y del visitante (sólo yendo al partido).
var _crests: Array[WEStyle.Crest] = []
var _bar: Bar
var _busy := false
var _music_db := 0.0
var _tips: Array = []
var _tip_time := 0.0


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()


func is_busy() -> bool:
	return _busy


## Va a la escena `path` con la pantalla de carga. `title` y `subtitle` son
## lo que se lee arriba (si van vacíos, se arman con los equipos del partido).
func goto(path: String, title := "", subtitle := "") -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	var to_match := path == MATCH_SCENE
	for i in 2:
		var tp := GameSettings.home_team_path if i == 0 else GameSettings.away_team_path
		var team: TeamData = TeamDB.load_team(tp) if to_match and tp != "" and TeamDB.exists(tp) else null
		_crests[i].team = team
		_crests[i].visible = team != null and not (i == 1 and GameSettings.training)
		_crests[i].queue_redraw()
	if title == "":
		title = _match_title() if to_match else "MENÚ PRINCIPAL"
	if subtitle == "":
		subtitle = _match_subtitle() if to_match else ""
	_show(title, subtitle)
	var t0 := Time.get_ticks_msec()
	await _fade(true)
	# La escena se carga en otro hilo; la barra avanza mientras tanto.
	var packed: PackedScene = null
	if ResourceLoader.load_threaded_request(path) == OK:
		var progress := []
		while true:
			var st := ResourceLoader.load_threaded_get_status(path, progress)
			if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_bar.value = 0.7 * float(progress[0]) if progress.size() > 0 else _bar.value
				await get_tree().process_frame
				continue
			if st == ResourceLoader.THREAD_LOAD_LOADED:
				packed = ResourceLoader.load_threaded_get(path) as PackedScene
			break
	if packed == null:
		packed = load(path) as PackedScene
	_bar.value = 0.75
	# Un cuadro con la barra dibujada antes de que la escena nueva bloquee al
	# armar el estadio.
	await get_tree().process_frame
	var old := get_tree().current_scene
	get_tree().change_scene_to_packed(packed)
	while get_tree().current_scene == old or get_tree().current_scene == null:
		await get_tree().process_frame
	_bar.value = 0.95
	# Primeros cuadros de la escena nueva (compila sombras, arma el público).
	for i in 3:
		await get_tree().process_frame
	while (Time.get_ticks_msec() - t0) / 1000.0 < MIN_TIME:
		await get_tree().process_frame
	_bar.value = 1.0
	await _fade(false)
	_root.hide()
	_busy = false


## Elige el consejo según el deporte (los de fútbol o futsal y los comunes).
func pick_tip() -> String:
	if _tips.is_empty():
		_tips = TIPS_COMMON.duplicate()
		_tips.append_array(TIPS_FUTSAL if Discipline.is_futsal() else TIPS_FOOTBALL)
		_tips.shuffle()
	return _tips.pop_back()


func _match_title() -> String:
	var h := _team_name(GameSettings.home_team_path)
	var a := _team_name(GameSettings.away_team_path)
	if GameSettings.training:
		return "ENTRENAMIENTO  ·  " + h
	return "%s   vs   %s" % [h, a]


func _match_subtitle() -> String:
	if GameSettings.training:
		return "Club House"
	if Discipline.is_futsal():
		return "Futsal  ·  2 x 20'  ·  " + _venue(GameSettings.home_team_path)
	return "Fútbol  ·  " + _venue(GameSettings.home_team_path)


func _team_name(path: String) -> String:
	if path == "" or not TeamDB.exists(path):
		return "—"
	var t := TeamDB.load_team(path)
	return t.team_name.to_upper() if t != null else "—"


func _venue(path: String) -> String:
	if path == "" or not TeamDB.exists(path):
		return ""
	var t := TeamDB.load_team(path)
	if t == null:
		return ""
	return t.stadium if t.stadium != "" else "Cancha de " + t.team_name


func _show(title: String, subtitle: String) -> void:
	_tips.clear()
	_title.text = title
	_sub.text = subtitle
	_sub.visible = subtitle != ""
	_tip.show_text(pick_tip())
	_tip_time = 0.0
	_bar.value = 0.0
	_root.modulate.a = 0.0
	_root.show()


func _process(dt: float) -> void:
	if not _root.visible:
		return
	_bar.phase += dt
	_bar.queue_redraw()
	# Carga larga: el consejo cambia cada 5 s.
	_tip_time += dt
	if _tip_time > 5.0:
		_tip_time = 0.0
		_tip.show_text(pick_tip())


## Fundido de la pantalla y del sonido. Entra: tapa y baja el volumen.
## Sale: destapa y lo vuelve a donde estaba.
func _fade(entering: bool) -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	if entering:
		_music_db = AudioServer.get_bus_volume_db(bus)
	var tw := create_tween().set_parallel()
	tw.tween_property(_root, "modulate:a", 1.0 if entering else 0.0, FADE_IN if entering else FADE_OUT)
	var from := AudioServer.get_bus_volume_db(bus)
	var to := MUTED_DB if entering else _music_db
	tw.tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(bus, v), from, to, FADE_IN if entering else FADE_OUT)
	await tw.finished


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = WEStyle.BG_NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	# Franja de cancha abajo, como el piso de un vestuario.
	var stripe := ColorRect.new()
	stripe.color = WEStyle.BG_PANEL
	stripe.anchor_top = 0.62
	stripe.anchor_right = 1.0
	stripe.anchor_bottom = 1.0
	_root.add_child(stripe)
	var line := ColorRect.new()
	line.color = WEStyle.ACCENT
	line.anchor_top = 0.62
	line.anchor_right = 1.0
	line.anchor_bottom = 0.62
	line.offset_bottom = WEStyle.px(3)
	_root.add_child(line)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = WEStyle.px(WEStyle.MARGIN_X * 2)
	box.offset_right = -WEStyle.px(WEStyle.MARGIN_X * 2)
	box.offset_top = WEStyle.px(160)
	box.offset_bottom = -WEStyle.px(90)
	box.add_theme_constant_override("separation", int(WEStyle.px(14)))
	_root.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(WEStyle.px(28)))
	box.add_child(head)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", int(WEStyle.px(6)))
	for i in 2:
		var c := WEStyle.Crest.new()
		c.custom_minimum_size = Vector2(WEStyle.px(132), WEStyle.px(150))
		c.label_font = WEStyle.font(WEStyle.Typeface.TITLE)
		_crests.append(c)
	head.add_child(_crests[0])
	head.add_child(names)
	head.add_child(_crests[1])
	names.add_child(WEStyle.make_caption_label("CARGANDO", WEStyle.ACCENT))
	_title = WEStyle.make_title_label("", WEStyle.TITLE_XL)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(_title)
	_sub = WEStyle.make_body_label("", WEStyle.BODY_L, WEStyle.TEXT_DIM)
	names.add_child(_sub)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(WEStyle.make_caption_label("CONSEJO", WEStyle.ACCENT))
	_tip = ButtonIcons.IconLabel.new(WEStyle.font_px(WEStyle.TITLE_M), false, WEStyle.TEXT_MAIN)
	_tip.custom_minimum_size.y = WEStyle.px(110)
	box.add_child(_tip)
	_bar = Bar.new()
	_bar.custom_minimum_size.y = WEStyle.px(10)
	box.add_child(_bar)


## Barra de progreso con un brillo que corre (se ve viva aunque la carga
## esté quieta).
class Bar:
	extends Control
	var value := 0.0
	var phase := 0.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, WEStyle.LINE)
		var w := size.x * clampf(value, 0.0, 1.0)
		draw_rect(Rect2(0, 0, w, size.y), WEStyle.ACCENT)
		var gx := fposmod(phase * 0.6, 1.3) - 0.15
		var gw := size.x * 0.12
		draw_rect(Rect2(size.x * gx - gw * 0.5, 0, gw, size.y), Color(1, 1, 1, 0.25))
