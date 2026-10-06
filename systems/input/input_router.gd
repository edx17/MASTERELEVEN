class_name InputRouter
extends RefCounted
## Traduce el Input Map del proyecto (fuente única de verdad, editable desde
## Proyecto > Configuración > Mapa de entrada o desde el futuro menú de opciones)
## a acciones por jugador humano: "p0_pass_short", "p1_shoot", etc.
##
## Reglas de asignación:
## - 1 humano: recibe teclado + todos los mandos.
## - 2 humanos: con 2+ mandos, P1 = teclado + mando 0 y P2 = mando 1.
##   Con 1 mando, P1 = teclado y P2 = mando 0.
## Nunca se hardcodean teclas ni botones: se copian los eventos del Input Map.

const BASE_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"pass_short", &"shoot", &"pass_long", &"pass_through",
	&"sprint", &"special", &"brake", &"strategy", &"rs_left", &"rs_right", &"rs_up", &"rs_down", &"pause",
	&"mentality_down", &"mentality_up",
]

const MAX_SLOTS := 2


static func action_name(slot: int, base: StringName) -> StringName:
	return StringName("p%d_%s" % [slot, base])


static func humans_for_mode(mode: int) -> int:
	match mode:
		0: return 1 # VS_CPU
		1: return 2 # TWO_PLAYERS
		_: return 0 # CPU_VS_CPU


## Pestañas de las pantallas (L1/R1 o Q/E). No están en project.godot: se
## agregan acá, también después de volver a los controles de fábrica.
const TAB_ACTIONS := {&"ui_tab_prev": [KEY_Q, JOY_BUTTON_LEFT_SHOULDER], &"ui_tab_next": [KEY_E, JOY_BUTTON_RIGHT_SHOULDER]}


static func ensure_tab_actions() -> void:
	for action in TAB_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var k := InputEventKey.new()
		k.physical_keycode = TAB_ACTIONS[action][0]
		InputMap.action_add_event(action, k)
		var b := InputEventJoypadButton.new()
		b.button_index = TAB_ACTIONS[action][1]
		InputMap.action_add_event(action, b)


static func setup_for_mode(mode: int) -> void:
	setup(humans_for_mode(mode))


## Crea/recrea las acciones por jugador según los mandos conectados.
static func setup(human_count: int) -> void:
	ensure_tab_actions()
	var pads: Array[int] = Input.get_connected_joypads()
	for slot in MAX_SLOTS:
		var use_keyboard := false
		var devices: Array[int] = [] # -1 en la lista = cualquier mando
		if human_count == 1 and slot == 0:
			use_keyboard = true
			devices = [-1]
		elif human_count == 2:
			if slot == 0:
				use_keyboard = true
				if pads.size() >= 2:
					devices = [pads[0]]
			else:
				if pads.size() >= 2:
					devices = [pads[1]]
				elif pads.size() == 1:
					devices = [pads[0]]
		for base in BASE_ACTIONS:
			_rebuild_action(slot, base, use_keyboard, devices)
	# Las asignaciones pueden haber cambiado (ControlsConfig): las indicaciones se rearman.
	notify_bindings_changed()


static func _rebuild_action(slot: int, base: StringName, use_keyboard: bool, devices: Array[int]) -> void:
	var name := action_name(slot, base)
	var deadzone := 0.5
	if InputMap.has_action(base):
		deadzone = InputMap.action_get_deadzone(base)
	if InputMap.has_action(name):
		InputMap.erase_action(name)
	InputMap.add_action(name, deadzone)
	if not InputMap.has_action(base):
		return
	for ev in InputMap.action_get_events(base):
		if ev is InputEventKey or ev is InputEventMouseButton:
			if use_keyboard:
				InputMap.action_add_event(name, ev.duplicate())
		elif ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			for device in devices:
				var copy: InputEvent = ev.duplicate()
				copy.device = device
				InputMap.action_add_event(name, copy)


## True si hay al menos un mando para el segundo jugador.
static func can_play_two_players() -> bool:
	return Input.get_connected_joypads().size() >= 1


# --- Fuente activa (teclado o mando) para las indicaciones de control ---------
# Gana el último dispositivo usado a propósito: una tecla o un botón apretados,
# o un stick más allá de la zona muerta configurada (la de move_*). El ruido de
# los sticks no cuenta y hay un margen corto para que no parpadee. La fuente se
# guarda en las opciones (GameSettings.input_source) sólo como valor inicial
# para la próxima vez: la real siempre manda.

enum Source { KEYBOARD, GAMEPAD }

## Tiempo mínimo entre dos cambios de fuente (s).
const SOURCE_SWITCH_GAP := 0.25

## Señales de la entrada (InputRouter es estático: las señales viven acá).
##   source_changed(source): cambió la fuente activa.
##   bindings_changed(): se reasignó una tecla o un botón.
class Events:
	extends RefCounted
	signal source_changed(source: int)
	signal bindings_changed()

static var source: int = Source.KEYBOARD
static var _events := Events.new()
static var _last_switch := -10.0


static func events() -> Events:
	return _events


## Fuente inicial: la guardada (si hay) o, si no, mando si hay uno conectado.
static func start(saved: int = -1) -> void:
	if saved == Source.KEYBOARD or saved == Source.GAMEPAD:
		source = saved
	else:
		source = Source.GAMEPAD if not Input.get_connected_joypads().is_empty() else Source.KEYBOARD


static func is_gamepad() -> bool:
	return source == Source.GAMEPAD


## Zona muerta de los sticks: la configurada para mover al jugador.
static func stick_deadzone() -> float:
	return InputMap.action_get_deadzone(&"move_left") if InputMap.has_action(&"move_left") else 0.5


## La fuente que indica un evento, o -1 si no cuenta (ruido del stick,
## movimiento del mouse, teclas soltadas o repetidas).
static func source_of(event: InputEvent) -> int:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		return Source.KEYBOARD
	if event is InputEventMouseButton and event.is_pressed():
		return Source.KEYBOARD
	if event is InputEventJoypadButton and event.is_pressed():
		return Source.GAMEPAD
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > stick_deadzone():
		return Source.GAMEPAD
	return -1


## Mira un evento de entrada y cambia la fuente si corresponde.
static func observe(event: InputEvent) -> void:
	var s := source_of(event)
	if s >= 0:
		set_source(s)


## Cambia la fuente (con el margen anti-parpadeo, salvo `force`), la guarda
## como preferencia y avisa.
static func set_source(s: int, force: bool = false) -> void:
	if s == source:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not force and now - _last_switch < SOURCE_SWITCH_GAP:
		return
	_last_switch = now
	source = s
	GameSettings.input_source = s
	if GameSettings.persist:
		GameSettings.save_settings()
	_events.source_changed.emit(s)


## Avisar que cambió una asignación (las indicaciones se rearman).
static func notify_bindings_changed() -> void:
	_events.bindings_changed.emit()
