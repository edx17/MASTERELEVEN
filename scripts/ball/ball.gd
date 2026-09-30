class_name Ball
extends Node3D
## Pelota del partido. Siempre la mueve BallPhysics (es independiente): tener
## "dueño" sólo significa quién la está conduciendo. El conductor le da toques
## (ver Dribble) y la pierde si se le escapa demasiado lejos. Excepción: el
## arquero dentro de su área la lleva en las manos.

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
var _touch_timer: float = 0.0


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


## `player` pasa a conducir la pelota. Con `receive` se aplica el primer
## control: la pelota se frena al ritmo del jugador según su ball_control y la
## velocidad con la que llegaba (un mal control la deja picando lejos).
func give_to(player: Footballer, receive: bool = false) -> void:
	owner_player = player
	last_touch_team = player.team.index
	last_toucher = player
	if intended_receiver != player:
		intended_receiver = null
	player.clear_pass_target()
	_touch_timer = 0.0
	if receive:
		var pv := Vector3(player.velocity.x, 0.0, player.velocity.z)
		var rel := state.vel - pv
		var control := PlayerData.unit(player.data.ball_control) if player.data else 0.6
		# Cuanto más rápida viene y peor el control, más rebota.
		var keep := clampf(0.35 - control * 0.3 + rel.length() * 0.008, 0.02, 0.45)
		state.vel = pv + rel * keep
		state.vel.y = minf(state.vel.y, 0.0) * 0.3
		state.spin = Vector3.ZERO


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
		if Vector3(state.pos.x - front.x, 0.0, state.pos.z - front.z).length() > 1.4:
			state.pos = Vector3(front.x, state.pos.y, front.z)
	kicked.emit(kicker)


func tick(dt: float) -> void:
	if frozen:
		_sync_node(0.0)
		return
	if owner_player != null:
		if _in_keeper_hands():
			_hold_in_hands(dt)
			return
		_dribble(dt)
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


func _in_keeper_hands() -> bool:
	var p := owner_player
	return p.is_keeper() and Pitch.in_penalty_area(p.flat_pos(), p.team.own_side())


func _hold_in_hands(dt: float) -> void:
	var p := owner_player
	state.pos = p.flat_pos() + p.facing * 0.35 + Vector3.UP * 1.0
	state.vel = Vector3(p.velocity.x, 0.0, p.velocity.z)
	state.spin = Vector3.ZERO
	_sync_node(dt)


## Toques de conducción. La pelota sigue rodando con su física; acá sólo se
## decide cuándo el conductor la vuelve a tocar y con qué velocidad.
func _dribble(dt: float) -> void:
	var p := owner_player
	_touch_timer = maxf(0.0, _touch_timer - dt)
	var foot := Dribble.foot_point(p.global_position, p.facing)
	var to_ball := Vector3(state.pos.x - foot.x, 0.0, state.pos.z - foot.z)
	var dist := to_ball.length()
	# Se le escapó: la pelota queda libre.
	if dist > _tuning.dribble_lose_distance or state.pos.y > _tuning.control_height:
		owner_player = null
		return
	var body_dist := Vector3(state.pos.x - p.global_position.x, 0.0, state.pos.z - p.global_position.z).length()
	# Se puede tocar con el pie de adelante, pegada al cuerpo o, si se pide un
	# giro, estirando la pierna.
	var reach := Dribble.reach_for(p.intent_dir, state.vel)
	if (dist > reach and body_dist > reach) or _touch_timer > 0.0:
		return
	var pv := Vector3(p.velocity.x, 0.0, p.velocity.z)
	var speed := pv.length()
	if speed < Dribble.SHIELD_SPEED:
		# Quieto o casi: la pisa y la acomoda en el pie.
		var pull := (foot - Vector3(state.pos.x, 0.0, state.pos.z)) * 5.0
		state.vel = Vector3(pull.x, 0.0, pull.z).limit_length(2.0) + pv
		return
	var dir := p.intent_dir if p.intent_dir.length_squared() > 0.04 else pv
	dir = Vector3(dir.x, 0.0, dir.z).normalized()
	# Sólo se toca si el jugador la está alcanzando (si la pelota ya va más
	# rápido en esa dirección, se la deja rodar: evita que se "acelere sola").
	if state.vel.dot(dir) > pv.dot(dir) + 0.3:
		return
	# 0 = trote (o menos), 1 = sprint a fondo.
	var jog := _tuning.run_speed * _tuning.dribble_speed_factor
	var sprint := _tuning.sprint_speed * _tuning.dribble_speed_factor
	var frac := clampf(inverse_lerp(jog, sprint, speed), 0.0, 1.0)
	var control := PlayerData.centered(p.data.ball_control) if p.data else 0.0
	var d := Dribble.touch_distance(frac, control, p.dribble_pressure, _tuning)
	var along := pv.dot(dir)
	state.vel = Dribble.touch_velocity(maxf(along, 0.0), dir, d, _tuning)
	state.vel.y = 0.0
	state.spin = Vector3.ZERO
	_touch_timer = Dribble.TOUCH_COOLDOWN
	p.touches += 1


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
