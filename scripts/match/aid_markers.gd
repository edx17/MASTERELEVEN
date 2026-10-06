class_name AidMarkers
extends Node3D
## Ayudas visuales del partido (Opciones > Ayudas): la línea del offside del
## equipo del primer humano mientras ataca y el lugar donde va a picar la
## pelota cuando va por el aire.

var match: MatchController
var _line: MeshInstance3D
var _landing: MeshInstance3D


func _ready() -> void:
	_line = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.02, Pitch.HALF_WIDTH * 2.0)
	_line.mesh = box
	_line.material_override = _mat(Color(1.0, 0.9, 0.2, 0.6))
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.visible = false
	add_child(_line)
	_landing = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.45
	ring.outer_radius = 0.6
	_landing.mesh = ring
	_landing.scale = Vector3(1.0, 0.05, 1.0)
	_landing.material_override = _mat(Color(1.0, 1.0, 1.0, 0.7))
	_landing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_landing.visible = false
	add_child(_landing)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	return m


func _process(_dt: float) -> void:
	if match == null:
		return
	var playing := match.phase == MatchController.Phase.PLAYING
	# Línea del offside: sólo cuando el equipo del humano tiene la pelota.
	var show_line := false
	if playing and GameSettings.show_offside_line and GameSettings.offside and not match.humans.is_empty():
		var team := match.humans[0].team
		var owner: Footballer = match.ball.owner_player
		if team != null and owner != null and owner.team == team:
			show_line = true
			_line.position = Vector3(match.offside_line(team), 0.03, 0.0)
	_line.visible = show_line
	# Caída de la pelota: si va alta.
	var show_land := false
	if playing and GameSettings.show_ball_landing and match.ball.owner_player == null:
		var spot := landing_spot(match.ball.global_position, match.ball.state.vel, GameSettings.tuning.gravity)
		if spot != Vector3.INF:
			show_land = true
			_landing.position = Vector3(spot.x, 0.04, spot.z)
	_landing.visible = show_land


## Dónde pica una pelota en `pos` con velocidad `vel` (tiro parabólico, sin
## rozamiento del aire); INF si no va por el aire.
static func landing_spot(pos: Vector3, vel: Vector3, g: float) -> Vector3:
	if pos.y < 1.2 or g <= 0.0:
		return Vector3.INF
	# y(t) = pos.y + vel.y t - g t² / 2 = 0.11
	var a := -0.5 * g
	var b := vel.y
	var c := pos.y - 0.11
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return Vector3.INF
	var t := (-b - sqrt(disc)) / (2.0 * a)
	if t <= 0.0:
		return Vector3.INF
	return Vector3(pos.x + vel.x * t, 0.0, pos.z + vel.z * t)
