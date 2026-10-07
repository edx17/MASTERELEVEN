extends CanvasLayer
## Controles táctiles (Android / pantallas táctiles): un mando virtual en
## pantalla. A la izquierda el stick; a la derecha ✕ ○ □ △, L1 / R1, L2 / R2 y
## START / SELECT. Mandan los mismos eventos que un mando de verdad
## (InputEventJoypadButton / InputEventJoypadMotion del dispositivo 0), así
## que el juego, los menús y las indicaciones funcionan sin cambios.
## Sólo aparece con pantalla táctil (o con `-- --touch` para probarlo).

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

var enabled := false
var _pad: Pad


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
		or OS.get_cmdline_user_args().has("--touch")
	if not enabled:
		return
	_pad = Pad.new()
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pad)


## El mando dibujado y los dedos: cada dedo que toca un control queda atado a
## él hasta que se levanta (multitáctil).
class Pad:
	extends Control
	## índice del dedo -> {kind: "stick" | "button" | "trigger", i}
	var _fingers := {}
	var _stick := Vector2.ZERO
	var _held := {}

	func _px(v: float) -> float:
		return WEStyle.px(v)

	func stick_center() -> Vector2:
		return Vector2(_px(STICK_CENTER.x), size.y - _px(STICK_CENTER.y + LIFT))

	func button_center(c: Vector2) -> Vector2:
		return Vector2(size.x - _px(c.x), size.y - _px(c.y + LIFT))

	func menu_center(dx: float) -> Vector2:
		return Vector2(size.x * 0.5 + _px(dx), _px(70))

	func _input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var t := event as InputEventScreenTouch
			if t.pressed:
				var hit := _hit(t.position)
				if not hit.is_empty():
					_fingers[t.index] = hit
					_press(hit, true, t.position)
					get_viewport().set_input_as_handled()
			elif _fingers.has(t.index):
				_press(_fingers[t.index], false, t.position)
				_fingers.erase(t.index)
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
