class_name ControlsConfig
extends RefCounted
## Cambio de botones y teclas (menú Opciones > Controles). Se cambia el Input
## Map del proyecto (las acciones base) y se guarda en user://controls.cfg;
## InputRouter lo vuelve a copiar a las acciones de cada jugador.

## "" = la carpeta del jugador (UserData.controls_path()).
const PATH := ""
## Acciones que se pueden cambiar y su nombre en el menú.
const ACTIONS: Array[StringName] = [&"pass_short", &"shoot", &"pass_long", &"pass_through",
	&"special", &"sprint", &"brake", &"strategy", &"camera_cycle", &"pause"]
const ACTION_NAMES := {
	&"pass_short": "Pase corto / Entrada", &"shoot": "Remate / Presión de un compañero",
	&"pass_long": "Centro / Barrida", &"pass_through": "Pase al hueco / Sale el arquero",
	&"special": "Gambetas / Cambio de jugador", &"sprint": "Correr",
	&"brake": "Frenar / Tiro colocado", &"strategy": "Estrategia", &"camera_cycle": "Cámara",
	&"pause": "Pausa",
}
## Botón del mando -> ícono (ButtonIcons) o nombre.
const JOY_BUTTON_ICONS := {JOY_BUTTON_A: "X", JOY_BUTTON_B: "O", JOY_BUTTON_X: "SQ", JOY_BUTTON_Y: "TRI",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1"}
const JOY_BUTTON_NAMES := {JOY_BUTTON_BACK: "Select", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_DPAD_UP: "Arriba",
	JOY_BUTTON_DPAD_DOWN: "Abajo", JOY_BUTTON_DPAD_LEFT: "Izquierda", JOY_BUTTON_DPAD_RIGHT: "Derecha"}


## Asigna `event` (tecla, botón o gatillo) a `action`. Reemplaza el evento del
## mismo tipo (teclado o mando) que tenía; si otra acción lo usaba, ésta se
## queda con el que soltó (intercambio, así nada queda sin asignar).
static func rebind(action: StringName, event: InputEvent) -> void:
	var is_key := event is InputEventKey
	var old: InputEvent = null
	for ev in InputMap.action_get_events(action):
		if (ev is InputEventKey) == is_key:
			old = ev
			InputMap.action_erase_event(action, ev)
	for other in ACTIONS:
		if other == action:
			continue
		for ev in InputMap.action_get_events(other):
			if _same(ev, event):
				InputMap.action_erase_event(other, ev)
				if old != null:
					InputMap.action_add_event(other, old)
	InputMap.action_add_event(action, _clean(event))
	InputRouter.setup_for_mode(GameSettings.mode)


## Vuelve a los controles de fábrica y borra lo guardado.
static func reset(path: String = PATH) -> void:
	if path == "":
		path = UserData.controls_path()
	InputMap.load_from_project_settings()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	InputRouter.setup_for_mode(GameSettings.mode)


static func save(path: String = PATH) -> void:
	if path == "":
		path = UserData.controls_path()
	var cfg := ConfigFile.new()
	for a in ACTIONS:
		var list: Array = []
		for ev in InputMap.action_get_events(a):
			var d := _to_dict(ev)
			if not d.is_empty():
				list.append(d)
		cfg.set_value("controls", String(a), list)
	cfg.save(path)


## Aplica lo guardado (si hay algo).
static func load_saved(path: String = PATH) -> void:
	if path == "":
		path = UserData.controls_path()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for a in ACTIONS:
		if not cfg.has_section_key("controls", String(a)) or not InputMap.has_action(a):
			continue
		var list: Array = cfg.get_value("controls", String(a))
		var events: Array[InputEvent] = []
		for d in list:
			var ev := _from_dict(d)
			if ev != null:
				events.append(ev)
		if events.is_empty():
			continue
		InputMap.action_erase_events(a)
		for ev in events:
			InputMap.action_add_event(a, ev)


## Tecla asignada a `action` (texto) o "-".
static func key_text(action: StringName) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			return OS.get_keycode_string(code)
	return "-"


## Botón del mando asignado a `action`, como texto con ícono ({X}, {L2}...).
static func pad_text(action: StringName) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			var b := (ev as InputEventJoypadButton).button_index
			if JOY_BUTTON_ICONS.has(b):
				return "{%s}" % JOY_BUTTON_ICONS[b]
			return JOY_BUTTON_NAMES.get(b, "Botón %d" % b)
		if ev is InputEventJoypadMotion:
			var m := ev as InputEventJoypadMotion
			if m.axis == JOY_AXIS_TRIGGER_LEFT:
				return "{L2}"
			if m.axis == JOY_AXIS_TRIGGER_RIGHT:
				return "{R2}"
			return "Eje %d" % m.axis
	return "-"


## Sirve como nueva asignación (se ignoran sticks y teclas sueltas de
## sistema).
static func is_bindable(ev: InputEvent) -> bool:
	if ev is InputEventKey:
		return ev.pressed and not ev.echo
	if ev is InputEventJoypadButton:
		return ev.pressed
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		return m.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] and m.axis_value > 0.6
	return false


static func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return _code(a) == _code(b)
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis
	return false


static func _code(k: InputEventKey) -> int:
	return k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode


## Copia limpia del evento (todos los mandos, sin estado de "apretado").
static func _clean(ev: InputEvent) -> InputEvent:
	return _from_dict(_to_dict(ev))


static func _to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"type": "key", "code": _code(ev)}
	if ev is InputEventJoypadButton:
		return {"type": "joy", "button": ev.button_index}
	if ev is InputEventJoypadMotion:
		return {"type": "axis", "axis": ev.axis, "value": signf(ev.axis_value) if ev.axis_value != 0.0 else 1.0}
	return {}


static func _from_dict(d: Dictionary) -> InputEvent:
	match d.get("type", ""):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(d["code"])
			return k
		"joy":
			var j := InputEventJoypadButton.new()
			j.device = -1
			j.button_index = int(d["button"])
			return j
		"axis":
			var m := InputEventJoypadMotion.new()
			m.device = -1
			m.axis = int(d["axis"])
			m.axis_value = float(d["value"])
			return m
	return null
