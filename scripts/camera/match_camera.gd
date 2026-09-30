class_name MatchCamera
extends Camera3D
## Cámara lateral de TV estilo WE: alta, desde la tribuna (+Z), sigue a la
## pelota con suavizado y se adelanta un poco en la dirección del juego.

var _match: MatchController
var _focus: Vector3 = Vector3.ZERO


func setup(p_match: MatchController) -> void:
	_match = p_match
	fov = _match.tuning.camera_fov
	near = 0.5
	far = 400.0
	_focus = _target_focus()
	_apply()


func _process(dt: float) -> void:
	if _match == null:
		return
	fov = _match.tuning.camera_fov
	var k := 1.0 - exp(-_match.tuning.camera_smoothing * dt)
	_focus = _focus.lerp(_target_focus(), k)
	_apply()


func _target_focus() -> Vector3:
	var b := _match.ball.state
	var lead := Vector3(b.vel.x, 0.0, b.vel.z) * _match.tuning.camera_lookahead
	var f := Vector3(b.pos.x, 0.0, b.pos.z) + lead
	# Limita el encuadre para no mostrar demasiado afuera de la cancha.
	f.x = clampf(f.x, -Pitch.HALF_LENGTH + 12.0, Pitch.HALF_LENGTH - 12.0)
	f.z = clampf(f.z * 0.6, -Pitch.HALF_WIDTH + 12.0, Pitch.HALF_WIDTH - 8.0)
	return f


func _apply() -> void:
	var t := _match.tuning
	global_position = _focus + Vector3(0.0, t.camera_height, t.camera_distance)
	look_at(_focus, Vector3.UP)
