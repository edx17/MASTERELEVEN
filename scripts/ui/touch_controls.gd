extends CanvasLayer
## Controles táctiles (Android / pantallas táctiles): un mando virtual en
## pantalla. A la izquierda el stick; a la derecha ✕ ○ □ △, L1 / R1, L2 / R2 y
## START / SELECT. Mandan los mismos eventos que un mando de verdad
## (InputEventJoypadButton / InputEventJoypadMotion del dispositivo 0), así
## que el juego, los menús y las indicaciones funcionan sin cambios.
## Sólo aparece con pantalla táctil (o con `-- --touch` para probarlo).
##   - En el partido está siempre; mientras no se lo usa se ve tenue
##     (IDLE_ALPHA) y al tocarlo se marca.
##   - En los menús se toca la pantalla directamente; si hace falta el mando
##     (una pantalla sin botones, L1/R1, START), aparece deslizando el dedo
##     por la pantalla o tocando el botón del mando de la esquina, y se va
##     solo después de MENU_IDLE segundos sin usarlo.

const DEVICE := 0
## Botones: [id del ícono, botón del mando, centro en px de 1080 desde la
## esquina inferior derecha, radio].
const BUTTONS := [
	["X", JOY_BUTTON_A, Vector2(250, 150), 74.0],
	["O", JOY_BUTTON_B, Vector2(110, 270), 74.0],
	["SQ", JOY_BUTTON_X, Vector2(390, 270), 74.0],
	["TRI", JOY_BUTTON_Y, Vector2(250, 390), 74.0],
	["R1", JOY_BUTTON_RIGHT_SHOULDER, Vector2(110, 515), 56.0],
	["L1", JOY_BUTTON_LEFT_SHOULDER, Vector2(390, 515), 56.0],
]
## Gatillos (ejes): [id, eje, centro desde la esquina inferior derecha, radio].
const TRIGGERS := [
	["R2", JOY_AXIS_TRIGGER_RIGHT, Vector2(110, 640), 50.0],
	["L2", JOY_AXIS_TRIGGER_LEFT, Vector2(390, 640), 50.0],
]
## START / SELECT arriba al centro: [texto, botón, desplazamiento x desde el centro].
const MENU_BUTTONS := [["START", JOY_BUTTON_START, 360.0], ["SELECT", JOY_BUTTON_BACK, -360.0]]
## Todo el mando va por arriba de las fichas de jugador del HUD (px de 1080).
const LIFT := 130.0
## Stick: centro desde la esquina inferior izquierda y radio (px de 1080).
const STICK_CENTER := Vector2(260, 260)
const STICK_RADIUS := 170.0
## Opacidad del mando sin tocarlo / tocándolo, y cuánto tarda en apagarse
## después de soltarlo (segundos).
const IDLE_ALPHA := 0.3
const ACTIVE_ALPHA := 1.0
const FADE_DELAY := 1.2
## En los menús: cuánto hay que deslizar el dedo para que aparezca el mando
## (px de 1080) y cuánto tarda en irse sin usarlo (segundos).
const SWIPE := 90.0
const MENU_IDLE := 5.0
## Botón del mando en los menús: centro desde la esquina inferior izquierda y radio.
const TOGGLE_CENTER := Vector2(64, 124)
const TOGGLE_RADIUS := 40.0

var enabled := false
var _pad: Pad
var _toggle: Toggle
## El mando se mostró en un menú (por deslizar o por el botón).
var menu_pad := false
## Dedos en los menús: índice -> dónde empezó (para detectar el deslizamiento).
var _swipes := {}


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
		or OS.get_cmdline_user_args().has("--touch")
	if enabled:
		build()


## Arma el mando y el botón de la esquina.
func build() -> void:
	_pad = Pad.new()
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.modulate.a = IDLE_ALPHA
	add_child(_pad)
	_toggle = Toggle.new()
	_toggle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toggle.pressed.connect(show_menu_pad)
	add_child(_toggle)


func _process(dt: float) -> void:
	if _pad == null:
		return
	var playing := in_match()
	if playing:
		menu_pad = false
	elif menu_pad and _pad.idle_time() > MENU_IDLE:
		menu_pad = false
	var show := playing or menu_pad
	if _pad.visible != show:
		_pad.visible = show
		if not show:
			_pad.release_all()
	if show:
		_pad.fade(dt)
	_toggle.visible = not show


## Muestra el mando en un menú (hasta que no se lo use por un rato).
func show_menu_pad() -> void:
	menu_pad = true
	_pad.visible = true
	_pad.wake()


## En los menús, deslizar el dedo por la pantalla hace aparecer el mando.
func _input(event: InputEvent) -> void:
	if _pad == null or in_match() or menu_pad:
		_swipes.clear()
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_swipes[t.index] = t.position
		else:
			_swipes.erase(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _swipes.has(d.index) and d.position.distance_to(_swipes[d.index]) > WEStyle.px(SWIPE):
			_swipes.clear()
			show_menu_pad()


## Botón chico con un mando en la esquina (en los menús): lo muestra.
class Toggle:
	extends Control
	signal pressed

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func center() -> Vector2:
		return Vector2(WEStyle.px(TOGGLE_CENTER.x), size.y - WEStyle.px(TOGGLE_CENTER.y))

	## Sólo el círculo del botón ataja los toques (el resto va al menú).
	func _has_point(p: Vector2) -> bool:
		return p.distance_to(center()) <= WEStyle.px(TOGGLE_RADIUS) * 1.3

	func _gui_input(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			accept_event()
			pressed.emit()

	func _draw() -> void:
		var c := center()
		var r := WEStyle.px(TOGGLE_RADIUS)
		draw_circle(c, r, Color(WEStyle.BG_NIGHT, 0.55))
		draw_arc(c, r, 0, TAU, 40, Color(WEStyle.TEXT_MAIN, 0.45), 2.0)
		# Un mando dibujado: cuerpo, cruceta y dos botones.
		var w := r * 1.1
		var body := Rect2(c - Vector2(w * 0.5, w * 0.28), Vector2(w, w * 0.56))
		draw_rect(body, Color(WEStyle.TEXT_MAIN, 0.8), false, 2.0)
		var dp := c + Vector2(-w * 0.24, 0)
		draw_line(dp - Vector2(w * 0.1, 0), dp + Vector2(w * 0.1, 0), Color(WEStyle.TEXT_MAIN, 0.8), 2.0)
		draw_line(dp - Vector2(0, w * 0.1), dp + Vector2(0, w * 0.1), Color(WEStyle.TEXT_MAIN, 0.8), 2.0)
		draw_circle(c + Vector2(w * 0.2, -w * 0.06), w * 0.05, Color(WEStyle.ACCENT, 0.9))
		draw_circle(c + Vector2(w * 0.3, w * 0.06), w * 0.05, Color(WEStyle.ACCENT, 0.9))


## ¿Se está jugando? (en la escena del partido y sin pausa: en la pausa y los
## menús se toca la pantalla).
func in_match() -> bool:
	return get_tree().get_first_node_in_group(&"match") != null and not get_tree().paused


## El mando dibujado y los dedos: cada dedo que toca un control queda atado a
## él hasta que se levanta (multitáctil).
class Pad:
	extends Control
	## índice del dedo -> {kind: "stick" | "button" | "trigger", i}
	var _fingers := {}
	var _stick := Vector2.ZERO
	var _held := {}
	## Segundos desde que se soltó el último dedo.
	var _idle := 99.0

	func _init() -> void:
		# Ataja los clics que genera el toque sobre el mando (que no lleguen al
		# menú de abajo); en el resto de la pantalla no hace nada (_has_point).
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _has_point(p: Vector2) -> bool:
		return not _hit(p).is_empty()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			accept_event()

	## Segundos sin dedos sobre el mando.
	func idle_time() -> float:
		return 0.0 if not _fingers.is_empty() else _idle

	## Recién mostrado: marcado y contando desde cero.
	func wake() -> void:
		_idle = 0.0
		modulate.a = ACTIVE_ALPHA

	## Opacidad: plena mientras hay un dedo (y un rato después), tenue si no.
	func fade(dt: float) -> void:
		_idle = 0.0 if not _fingers.is_empty() else _idle + dt
		var target := ACTIVE_ALPHA if _idle < FADE_DELAY else IDLE_ALPHA
		modulate.a = move_toward(modulate.a, target, dt * (8.0 if target > modulate.a else 2.0))

	## Suelta todo lo que estaba apretado (al salir del partido o pausar).
	func release_all() -> void:
		for idx in _fingers.keys():
			_press(_fingers[idx], false, Vector2.ZERO)
		_fingers.clear()
		_idle = 99.0
		modulate.a = IDLE_ALPHA

	func _px(v: float) -> float:
		return WEStyle.px(v)

	func stick_center() -> Vector2:
		return Vector2(_px(STICK_CENTER.x), size.y - _px(STICK_CENTER.y + LIFT))

	func button_center(c: Vector2) -> Vector2:
		return Vector2(size.x - _px(c.x), size.y - _px(c.y + LIFT))

	func menu_center(dx: float) -> Vector2:
		return Vector2(size.x * 0.5 + _px(dx), _px(70))

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree():
			return
		if event is InputEventScreenTouch:
			var t := event as InputEventScreenTouch
			if t.pressed:
				var hit := _hit(t.position)
				if not hit.is_empty():
					_fingers[t.index] = hit
					modulate.a = ACTIVE_ALPHA
					_idle = 0.0
					_press(hit, true, t.position)
					get_viewport().set_input_as_handled()
			elif _fingers.has(t.index):
				_press(_fingers[t.index], false, t.position)
				_fingers.erase(t.index)
				_idle = 0.0
				get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag:
			var d := event as InputEventScreenDrag
			if _fingers.has(d.index):
				if String(_fingers[d.index]["kind"]) == "stick":
					_move_stick(d.position)
				get_viewport().set_input_as_handled()

	## Qué control hay bajo el dedo ({} = ninguno: el toque sigue al menú).
	func _hit(p: Vector2) -> Dictionary:
		if p.distance_to(stick_center()) <= _px(STICK_RADIUS) * 1.3:
			return {"kind": "stick", "i": 0}
		for i in BUTTONS.size():
			if p.distance_to(button_center(BUTTONS[i][2])) <= _px(BUTTONS[i][3]):
				return {"kind": "button", "i": i}
		for i in TRIGGERS.size():
			if p.distance_to(button_center(TRIGGERS[i][2])) <= _px(TRIGGERS[i][3]):
				return {"kind": "trigger", "i": i}
		for i in MENU_BUTTONS.size():
			if Rect2(menu_center(MENU_BUTTONS[i][2]) - Vector2(_px(80), _px(30)), Vector2(_px(160), _px(60))).has_point(p):
				return {"kind": "menu", "i": i}
		return {}

	func _press(hit: Dictionary, down: bool, pos: Vector2) -> void:
		var i: int = hit["i"]
		match String(hit["kind"]):
			"stick":
				if down:
					_move_stick(pos)
				else:
					_stick = Vector2.ZERO
					_send_axes()
			"button":
				_send_button(BUTTONS[i][1], down)
				_held["b%d" % i] = down
			"menu":
				_send_button(MENU_BUTTONS[i][1], down)
				_held["m%d" % i] = down
			"trigger":
				var m := InputEventJoypadMotion.new()
				m.device = DEVICE
				m.axis = TRIGGERS[i][1]
				m.axis_value = 1.0 if down else 0.0
				Input.parse_input_event(m)
				_held["t%d" % i] = down
		queue_redraw()

	func _move_stick(pos: Vector2) -> void:
		var v := (pos - stick_center()) / _px(STICK_RADIUS)
		_stick = v.limit_length(1.0)
		_send_axes()
		queue_redraw()

	func _send_axes() -> void:
		for a in [[JOY_AXIS_LEFT_X, _stick.x], [JOY_AXIS_LEFT_Y, _stick.y]]:
			var m := InputEventJoypadMotion.new()
			m.device = DEVICE
			m.axis = a[0]
			m.axis_value = a[1]
			Input.parse_input_event(m)

	func _send_button(index: int, down: bool) -> void:
		var b := InputEventJoypadButton.new()
		b.device = DEVICE
		b.button_index = index
		b.pressed = down
		b.pressure = 1.0 if down else 0.0
		Input.parse_input_event(b)

	func _draw() -> void:
		var base := Color(WEStyle.BG_NIGHT, 0.45)
		var rim := Color(WEStyle.TEXT_MAIN, 0.35)
		# Stick: base y perilla.
		var c := stick_center()
		var r := _px(STICK_RADIUS)
		draw_circle(c, r, base)
		draw_arc(c, r, 0, TAU, 48, rim, 2.0)
		draw_circle(c + _stick * r * 0.6, r * 0.38, Color(WEStyle.ACCENT, 0.55 if _stick != Vector2.ZERO else 0.3))
		for i in BUTTONS.size():
			_draw_button(button_center(BUTTONS[i][2]), _px(BUTTONS[i][3]), String(BUTTONS[i][0]), bool(_held.get("b%d" % i, false)))
		for i in TRIGGERS.size():
			_draw_button(button_center(TRIGGERS[i][2]), _px(TRIGGERS[i][3]), String(TRIGGERS[i][0]), bool(_held.get("t%d" % i, false)))
		var font := WEStyle.font(WEStyle.Typeface.SEMIBOLD)
		var fs := WEStyle.font_px(WEStyle.BODY_S)
		for i in MENU_BUTTONS.size():
			var rect := Rect2(menu_center(MENU_BUTTONS[i][2]) - Vector2(_px(70), _px(22)), Vector2(_px(140), _px(44)))
			var on: bool = _held.get("m%d" % i, false)
			draw_rect(rect, Color(WEStyle.ACCENT, 0.5) if on else base)
			draw_rect(rect, rim, false, 1.5)
			draw_string(font, Vector2(rect.position.x, rect.get_center().y + fs * 0.35), String(MENU_BUTTONS[i][0]),
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, WEStyle.TEXT_MAIN)

	func _draw_button(c: Vector2, r: float, id: String, on: bool) -> void:
		draw_circle(c, r, Color(WEStyle.ACCENT, 0.5) if on else Color(WEStyle.BG_NIGHT, 0.45))
		draw_arc(c, r, 0, TAU, 40, Color(WEStyle.TEXT_MAIN, 0.35), 2.0)
		var tex := ButtonIcons.texture(id, int(r * 1.1))
		var sz := tex.get_size()
		draw_texture(tex, c - sz * 0.5, Color(1, 1, 1, 0.85))
