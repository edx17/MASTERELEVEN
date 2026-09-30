class_name MatchCamera
extends Camera3D
## Cámara del partido estilo WE2002: sigue la zona de la pelota (no al jugador
## controlado) con suavizado y anticipación. Tiene varios modos (TV, Amplia,
## Cercana, Vertical, Dron) definidos como recursos en data/config/cameras/ y
## se cambian con la acción "camera_cycle" (C / Select-Back).
## También traduce la dirección del stick (pantalla) a la cancha, para que
## "arriba" sea siempre hacia arriba en pantalla, cualquiera sea el modo.

signal mode_changed(display_name: String)

const PRESETS: Array[String] = [
	"res://data/config/cameras/tv.tres",
	"res://data/config/cameras/amplia.tres",
	"res://data/config/cameras/cercana.tres",
	"res://data/config/cameras/vertical.tres",
	"res://data/config/cameras/dron.tres",
]

var config: CameraConfig
var presets: Array[CameraConfig] = []
var preset_index: int = 0
var _match: MatchController
var _focus: Vector3 = Vector3.ZERO


func setup(p_match: MatchController) -> void:
	_match = p_match
	for path in PRESETS:
		var c := load(path) as CameraConfig
		if c != null:
			presets.append(c)
	if presets.is_empty():
		presets.append(CameraConfig.new())
	near = 0.5
	far = 500.0
	set_preset(GameSettings.camera_preset, false)
	_focus = target_focus()
	_apply()


func set_preset(index: int, announce: bool = true) -> void:
	preset_index = posmod(index, presets.size())
	config = presets[preset_index]
	GameSettings.camera_preset = preset_index
	_update_occlusion()
	if announce:
		mode_changed.emit(config.display_name)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"camera_cycle"):
		set_preset(preset_index + 1)


func _process(dt: float) -> void:
	if _match == null:
		return
	var k := 1.0 - exp(-config.follow_speed * dt)
	_focus = _focus.lerp(target_focus(), k)
	_apply()


## Dirección del equipo del humano (o del local): la cámara vertical mira hacia allá.
func _attack_dir() -> int:
	if not _match.humans.is_empty():
		return _match.humans[0].team.attack_dir
	return _match.teams[0].attack_dir


## Punto que la cámara quiere mirar: la pelota, adelantada según su velocidad.
func target_focus() -> Vector3:
	var b := _match.ball.state
	var lead := Vector3(b.vel.x, 0.0, b.vel.z) * config.look_ahead
	var f := Vector3(b.pos.x, 0.0, b.pos.z) + lead
	match config.mode:
		CameraConfig.Mode.LATERAL:
			f.x = clampf(f.x + config.horizontal_offset, -config.focus_limit_x, config.focus_limit_x)
			# A lo ancho sigue a la pelota lo suficiente para ver la banda cercana.
			f.z = clampf(f.z * config.track_z + config.vertical_offset, -Pitch.HALF_WIDTH + 8.0, Pitch.HALF_WIDTH + 2.0)
		CameraConfig.Mode.VERTICAL:
			var dir := _attack_dir()
			f.x = clampf(f.x + dir * config.horizontal_offset, -Pitch.HALF_LENGTH + 6.0, Pitch.HALF_LENGTH - 6.0)
			f.z = clampf(f.z * config.track_z, -Pitch.HALF_WIDTH + 6.0, Pitch.HALF_WIDTH - 6.0)
		CameraConfig.Mode.TOPDOWN:
			# Cuanto más alta, menos se mueve (a gran altura ya ve toda la cancha).
			var k := clampf(1.0 - (config.camera_height - 45.0) / 60.0, 0.0, 1.0)
			f.x = clampf(f.x, -Pitch.HALF_LENGTH + 10.0, Pitch.HALF_LENGTH - 10.0) * k
			f.z = clampf(f.z, -Pitch.HALF_WIDTH + 8.0, Pitch.HALF_WIDTH - 8.0) * k
	return f


## Posición de la cámara lateral para un foco dado (pura; se usa en tests).
static func position_for(focus: Vector3, c: CameraConfig) -> Vector3:
	var base := Vector3(focus.x * c.track_factor, c.camera_height, focus.z + c.camera_distance)
	if absf(c.camera_angle) > 0.01:
		var rel := base - focus
		rel = rel.rotated(Vector3.UP, deg_to_rad(c.camera_angle))
		base = focus + rel
	return base


func _apply() -> void:
	fov = config.base_fov / maxf(config.zoom, 0.1)
	match config.mode:
		CameraConfig.Mode.LATERAL:
			global_position = position_for(_focus, config)
			look_at(_focus, Vector3.UP)
		CameraConfig.Mode.VERTICAL:
			var dir := _attack_dir()
			global_position = _focus + Vector3(-dir * config.camera_distance, config.camera_height, 0.0)
			look_at(_focus, Vector3.UP)
		CameraConfig.Mode.TOPDOWN:
			global_position = _focus + Vector3(0.0, config.camera_height, 0.01)
			# "Arriba" en pantalla = -Z, como en la vista de TV.
			look_at(_focus, Vector3.FORWARD)


## Convierte la dirección del stick (x = derecha, z = abajo en pantalla) a la
## cancha según la orientación actual de la cámara.
func screen_to_world(v: Vector3) -> Vector3:
	var right := global_basis.x
	right.y = 0.0
	var down := -global_basis.y
	down.y = 0.0
	if right.length_squared() < 0.0001 or down.length_squared() < 0.0001:
		return v
	return right.normalized() * v.x + down.normalized() * v.z


## La tribuna que queda entre la cámara y la cancha sólo proyecta sombra.
func _update_occlusion() -> void:
	var stadium := _match.stadium
	if stadium == null:
		return
	var hide := ""
	match config.mode:
		CameraConfig.Mode.LATERAL:
			hide = "StandSouth"
		CameraConfig.Mode.VERTICAL:
			hide = "StandWest" if _attack_dir() > 0 else "StandEast"
	StadiumBuilder.set_camera_side(stadium, hide)
