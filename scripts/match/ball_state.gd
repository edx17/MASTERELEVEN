class_name BallState
extends RefCounted
## Estado físico puro de la pelota (sin nodos), para poder simularla y testearla aislada.

var pos: Vector3 = Vector3.ZERO
## Velocidad lineal (m/s).
var vel: Vector3 = Vector3.ZERO
## Efecto (vector de rotación simplificado). Eje Y = efecto lateral (comba).
var spin: Vector3 = Vector3.ZERO


func _init(p_pos: Vector3 = Vector3.ZERO, p_vel: Vector3 = Vector3.ZERO, p_spin: Vector3 = Vector3.ZERO) -> void:
	pos = p_pos
	vel = p_vel
	spin = p_spin


func copy() -> BallState:
	return BallState.new(pos, vel, spin)
