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
	&"sprint", &"special", &"rs_left", &"rs_right", &"rs_up", &"rs_down", &"pause",
]

const MAX_SLOTS := 2


static func action_name(slot: int, base: StringName) -> StringName:
	return StringName("p%d_%s" % [slot, base])


static func humans_for_mode(mode: int) -> int:
	match mode:
		0: return 1 # VS_CPU
		1: return 2 # TWO_PLAYERS
		_: return 0 # CPU_VS_CPU


static func setup_for_mode(mode: int) -> void:
	setup(humans_for_mode(mode))


## Crea/recrea las acciones por jugador según los mandos conectados.
static func setup(human_count: int) -> void:
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
