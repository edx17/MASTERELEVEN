class_name InputSource
extends RefCounted
## Fuente de órdenes para un jugador controlado. El controlador del jugador sólo
## habla con esta interfaz, nunca con el singleton Input: así se puede enchufar
## HumanInput (teclado/mando), ScriptedInput (tests), AIInput o, en el futuro,
## NetworkInput sin tocar la lógica de juego.
##
## Acciones: &"pass_short", &"shoot", &"pass_long", &"pass_through", &"sprint",
## &"special" (L1: cambio de jugador sin la pelota; gambeta y combinaciones
## con la pelota), &"pause".


## Acciones silenciadas (no se leen como apretadas): las usa L2 + botón para
## elegir una estrategia sin que el botón también patee.
var muted: Array[StringName] = []


## Se llama una vez por tick antes de leer (para fuentes que llevan estado).
func poll() -> void:
	pass


## Dirección de movimiento en el plano de la cancha (x = derecha, z = abajo en pantalla).
func move_vector() -> Vector3:
	return Vector3.ZERO


## Stick derecho (mismo sistema que move_vector): giros para la marsellesa.
func right_vector() -> Vector3:
	return Vector3.ZERO


func pressed(_action: StringName) -> bool:
	return false


func just_pressed(_action: StringName) -> bool:
	return false


func just_released(_action: StringName) -> bool:
	return false
