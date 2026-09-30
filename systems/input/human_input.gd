class_name HumanInput
extends InputSource
## Input de un humano (teclado y/o mando) usando las acciones por jugador que
## genera InputRouter a partir del Input Map ("p0_pass_short", ...).

var slot: int = 0


func _init(p_slot: int = 0) -> void:
	slot = p_slot


func _a(base: StringName) -> StringName:
	return InputRouter.action_name(slot, base)


func move_vector() -> Vector3:
	var v := Input.get_vector(_a(&"move_left"), _a(&"move_right"), _a(&"move_up"), _a(&"move_down"))
	return Vector3(v.x, 0.0, v.y)


func pressed(action: StringName) -> bool:
	return Input.is_action_pressed(_a(action))


func just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(_a(action))


func just_released(action: StringName) -> bool:
	return Input.is_action_just_released(_a(action))
