class_name PlayerInput
extends RefCounted
## Lectura de controles de un jugador humano (slot 0 o 1) usando las acciones
## generadas por InputRouter.

var slot: int = 0


func _init(p_slot: int = 0) -> void:
	slot = p_slot


func _a(base: StringName) -> StringName:
	return InputRouter.action_name(slot, base)


## Dirección de movimiento en el plano de la cancha (x = derecha, z = abajo en pantalla).
func move_vector() -> Vector3:
	var v := Input.get_vector(_a(&"move_left"), _a(&"move_right"), _a(&"move_up"), _a(&"move_down"))
	return Vector3(v.x, 0.0, v.y)


func pressed(base: StringName) -> bool:
	return Input.is_action_pressed(_a(base))


func just_pressed(base: StringName) -> bool:
	return Input.is_action_just_pressed(_a(base))


func just_released(base: StringName) -> bool:
	return Input.is_action_just_released(_a(base))
