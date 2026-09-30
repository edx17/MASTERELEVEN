class_name Ball
extends Node3D
## Pelota del partido. Cuando está suelta la mueve BallPhysics; cuando tiene
## dueño se "pega al pie" con toques (conducción estilo WE).

signal kicked(kicker: Footballer)
signal bounced(strength: float)
signal hit_post
signal hit_net

const PHYSICS_SUBSTEPS := 2

var state: BallState = BallState.new()
var owner_player: Footballer = null
var last_touch_team: int = -1
var last_toucher: Footballer = null
## A quién iba dirigido el último pase (para cambio automático y la IA).
var intended_receiver: Footballer = null
## Pelota detenida (pelota parada, festejo, etc.).
var frozen: bool = false

var _tuning: Tuning
var _mesh: MeshInstance3D
var _shadow: MeshInstance3D
var _dribble_phase: float = 0.0


func setup(tuning: Tuning) -> void:
	_tuning = tuning
	_build_visuals()
	place(Vector3(0.0, _tuning.ball_radius, 0.0))


func is_loose() -> bool:
	return owner_player == null


func speed() -> float:
	return state.vel.length()


func flat_pos() -> Vector3:
	return Vector3(state.pos.x, 0.0, state.pos.z)


## Coloca la pelota quieta en un punto.
func place(pos: Vector3) -> void:
	owner_player = null
	intended_receiver = null
	state.pos = Vector3(pos.x, maxf(pos.y, _tuning.ball_radius), pos.z)
	state.vel = Vector3.ZERO
	state.spin = Vector3.ZERO
	_sync_node(0.0)


func give_to(player: Footballer) -> void:
	owner_player = player
	last_touch_team = player.team.index
	last_toucher = player
	if intended_receiver != player:
		intended_receiver = null
	player.clear_pass_target()


## Patea la pelota: pierde dueño y sale con la velocidad y efecto dados.
func kick(velocity: Vector3, spin: Vector3, kicker: Footballer) -> void:
	owner_player = null
	state.vel = velocity
	state.spin = spin
	if kicker != null:
		last_touch_team = kicker.team.index
		last_toucher = kicker
		kicker.touch_block = _tuning.touch_cooldown
		# Sale desde adelante del pie para no quedar "dentro" del pateador.
		var front := kicker.flat_pos() + kicker.facing * 0.45
		if Vector3(state.pos.x - front.x, 0.0, state.pos.z - front.z).length() > 0.9:
			state.pos = Vector3(front.x, state.pos.y, front.z)
	kicked.emit(kicker)


func tick(dt: float) -> void:
	if frozen:
		_sync_node(0.0)
		return
	if owner_player != null:
		_follow_owner(dt)
		return
	var sub := dt / PHYSICS_SUBSTEPS
	for i in PHYSICS_SUBSTEPS:
		var vy_before := state.vel.y
		var ev := BallPhysics.step(state, sub, _tuning)
		if ev & BallPhysics.EV_BOUNCE:
			bounced.emit(absf(vy_before))
		if ev & BallPhysics.EV_POST:
			hit_post.emit()
		if ev & BallPhysics.EV_NET:
			hit_net.emit()
	_sync_node(dt)


## Conducción: la pelota va delante del pie; en sprint se adelanta más y hay
## "toques" (la distancia oscila), y en los giros bruscos queda un poco atrás.
func _follow_owner(dt: float) -> void:
	var p := owner_player
	var sprint := p.is_sprinting()
	var base := _tuning.dribble_distance_sprint if sprint else _tuning.dribble_distance
	var move_speed := Vector3(p.velocity.x, 0.0, p.velocity.z).length()
	_dribble_phase += dt * (4.0 + move_speed * 1.1)
	var touch := 0.0
	if move_speed > 1.0:
		touch = (0.5 + 0.5 * sin(_dribble_phase)) * (0.35 if sprint else 0.12)
	var target := p.flat_pos() + p.facing * (base + touch)
	target.y = _tuning.ball_radius
	var rate := 11.0 if sprint else 18.0
	var new_pos := state.pos.lerp(target, 1.0 - exp(-rate * dt))
	new_pos.y = _tuning.ball_radius
	state.vel = (new_pos - state.pos) / maxf(dt, 0.0001)
	state.pos = new_pos
	state.spin = Vector3.ZERO
	_sync_node(dt)


func _sync_node(dt: float) -> void:
	global_position = state.pos
	# Rotación visual: rueda en la dirección del movimiento.
	var hv := Vector3(state.vel.x, 0.0, state.vel.z)
	var hs := hv.length()
	if hs > 0.01 and dt > 0.0 and _mesh != null:
		var axis := Vector3.UP.cross(hv / hs).normalized()
		_mesh.global_rotate(axis, hs * dt / _tuning.ball_radius)
	if _shadow != null:
		# La sombra ayuda a leer la altura en pases largos y centros.
		_shadow.global_position = Vector3(state.pos.x, 0.02, state.pos.z)
		var h := clampf((state.pos.y - _tuning.ball_radius) / 8.0, 0.0, 1.0)
		var s := lerpf(1.0, 0.55, h)
		_shadow.scale = Vector3(s, 1.0, s)


func _build_visuals() -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = _tuning.ball_radius
	sphere.height = _tuning.ball_radius * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _make_ball_texture()
	mat.roughness = 0.5
	_mesh.material_override = mat
	# La pelota real es chica: se agranda un poco la malla para que se lea en TV.
	_mesh.scale = Vector3.ONE * 1.6
	add_child(_mesh)

	_shadow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = _tuning.ball_radius * 1.6
	disc.bottom_radius = _tuning.ball_radius * 1.6
	disc.height = 0.005
	_shadow.mesh = disc
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0, 0, 0, 0.45)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = smat
	_shadow.top_level = true
	add_child(_shadow)


## Textura procedural (paneles blanco/negro) para que se note el giro.
static func _make_ball_texture() -> ImageTexture:
	var img := Image.create(16, 8, false, Image.FORMAT_RGB8)
	for x in 16:
		for y in 8:
			var dark := (int(x / 4.0) + int(y / 4.0)) % 2 == 0 and (x % 4 != 0)
			img.set_pixel(x, y, Color(0.12, 0.12, 0.12) if dark else Color(0.97, 0.97, 0.97))
	return ImageTexture.create_from_image(img)
