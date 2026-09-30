class_name MatchCamera
extends Camera3D
## Cámara de transmisión de TV estilo WE2002: elevada, desde la tribuna lateral,
## sigue la zona de la pelota (no al jugador controlado) con suavizado y algo de
## anticipación. Parámetros en CameraConfig (data/config/camera.tres).

const CONFIG_PATH := "res://data/config/camera.tres"

var config: CameraConfig
var _match: MatchController
var _focus: Vector3 = Vector3.ZERO


func setup(p_match: MatchController) -> void:
	_match = p_match
	config = load(CONFIG_PATH) as CameraConfig
	if config == null:
		config = CameraConfig.new()
	near = 0.5
	far = 500.0
	_focus = target_focus()
	_apply()


func _process(dt: float) -> void:
	if _match == null:
		return
	var k := 1.0 - exp(-config.follow_speed * dt)
	_focus = _focus.lerp(target_focus(), k)
	_apply()


## Punto que la cámara quiere mirar: la pelota, adelantada según su velocidad.
func target_focus() -> Vector3:
	var b := _match.ball.state
	var lead := Vector3(b.vel.x, 0.0, b.vel.z) * config.look_ahead
	var f := Vector3(b.pos.x, 0.0, b.pos.z) + lead
	f.x = clampf(f.x + config.horizontal_offset, -config.focus_limit_x, config.focus_limit_x)
	# A lo ancho se mueve menos: el campo sigue ocupando la pantalla.
	f.z = clampf(f.z * 0.55 + config.vertical_offset, -Pitch.HALF_WIDTH + 10.0, Pitch.HALF_WIDTH - 6.0)
	return f


## Posición de la cámara para un foco dado (pura; se usa también en tests).
static func position_for(focus: Vector3, c: CameraConfig) -> Vector3:
	var base := Vector3(focus.x * c.track_factor, c.camera_height, focus.z + c.camera_distance)
	if absf(c.camera_angle) > 0.01:
		var rel := base - focus
		rel = rel.rotated(Vector3.UP, deg_to_rad(c.camera_angle))
		base = focus + rel
	return base


func _apply() -> void:
	fov = config.base_fov / maxf(config.zoom, 0.1)
	global_position = position_for(_focus, config)
	look_at(_focus, Vector3.UP)
