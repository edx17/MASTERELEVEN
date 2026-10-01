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
## Segundos desde la última patada.
var kick_age: float = 0.0
## El arquero la tiene en las manos (si la recibió con los pies, por un pase
## atrás de un compañero, la juega como un jugador más).
var in_hands: bool = false
## Sólo presentación: desfase con el que se dibuja la pelota respecto de su
## posición simulada. Al patear se dibuja saliendo del pie y se acomoda en
## unas centésimas (VISUAL_SETTLE).
var visual_offset: Vector3 = Vector3.ZERO
const VISUAL_SETTLE := 0.08

var _tuning: Tuning
var _mesh: MeshInstance3D
var _shadow: MeshInstance3D
## Fase 0..1 del ciclo de toque de la conducción.
var _touch_phase: float = 0.0
## Segundos que quedan para que una pelota bajada con el pecho/muslo caiga al
## pie (mientras tanto no se pierde por estar alta).
var _settle: float = 0.0


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
func give_to(player: Footballer, receive: bool = false, hands: bool = false) -> void:
	visual_offset = Vector3.ZERO
	owner_player = player
	in_hands = hands and player.is_keeper()
	last_touch_team = player.team.index
	last_toucher = player
	if intended_receiver != player:
		intended_receiver = null
	player.clear_pass_target()
	_touch_phase = 0.0
	if receive:
		var pv := Vector3(player.velocity.x, 0.0, player.velocity.z)
		var rel := state.vel - pv
		var control := PlayerData.unit(player.data.ball_control) if player.data else 0.6
		# Primer control seguro: se amortigua casi toda la velocidad relativa.
		# Sólo un pase muy fuerte a alguien de poco control se escapa un poco.
		var keep := clampf(0.1 - control * 0.08 + maxf(rel.length() - 18.0, 0.0) * 0.012, 0.0, 0.25)
		state.vel = pv + rel * keep
		state.vel.y = minf(state.vel.y, 0.0) * 0.3
		state.spin = Vector3.ZERO
		# Control con el pecho/muslo: la pelota cae mansa al pie.
		_settle = 0.6 if state.pos.y > _tuning.control_height else 0.0


## Patea la pelota: pierde dueño y sale con la velocidad y efecto dados.
func kick(velocity: Vector3, spin: Vector3, kicker: Footballer) -> void:
	owner_player = null
	in_hands = false
	state.vel = velocity
	state.spin = spin
	kick_age = 0.0
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
	kick_age += dt
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
	return in_hands and p.is_keeper() and Pitch.in_penalty_area(p.flat_pos(), p.team.own_side())


func _hold_in_hands(dt: float) -> void:
	var p := owner_player
	# Entre las manos del modelo: acompaña la atajada, la estirada y la caída.
	state.pos = p.visual.hold_point() if p.visual != null else p.flat_pos() + p.facing * 0.35 + Vector3.UP * 1.0
	state.pos.y = maxf(state.pos.y, _tuning.ball_radius)
	state.vel = Vector3(p.velocity.x, 0.0, p.velocity.z)
	state.spin = Vector3.ZERO
	_sync_node(dt)


## Conducción guiada (ver Dribble): un resorte lleva la pelota hacia un punto
## delante del pie que "late" con los toques. La física sigue actuando (rueda,
## pica), así que en los giros la pelota queda un instante atrás y la sigue.
func _dribble(dt: float) -> void:
	var p := owner_player
	var foot := Dribble.foot_point(p.global_position, p.facing)
	var dist := Vector3(state.pos.x - foot.x, 0.0, state.pos.z - foot.z).length()
	# Sólo se pierde si algo la sacó lejos (un rebote, un golpe).
	_settle = maxf(0.0, _settle - dt)
	var max_h := _tuning.chest_control_height + 0.2 if _settle > 0.0 else _tuning.control_height
	if dist > _tuning.dribble_lose_distance or state.pos.y > max_h:
		owner_player = null
		_settle = 0.0
		return
	var pv := Vector3(p.velocity.x, 0.0, p.velocity.z)
	var speed := pv.length()
	var jog := _tuning.run_speed * _tuning.dribble_speed_factor
	var sprint := _tuning.sprint_speed * _tuning.dribble_speed_factor
	var frac := clampf(inverse_lerp(jog, sprint, speed), 0.0, 1.0)
	var control_c := PlayerData.centered(p.data.ball_control) if p.data else 0.0
	var control_u := PlayerData.unit(p.data.ball_control) if p.data else 0.6
	var target: Vector3
	var shielding := speed < Dribble.SHIELD_SPEED * 2.0 and p.dribble_pressure > 0.6
	if speed < Dribble.SHIELD_SPEED and not shielding:
		# Quieto: la pisa en el pie.
		target = foot
		_touch_phase = 0.0
	else:
		var period := Dribble.touch_period(frac)
		var before := _touch_phase
		_touch_phase = fmod(_touch_phase + dt / period, 1.0)
		if _touch_phase < before:
			p.touches += 1
		var d := Dribble.touch_distance(frac, control_c, p.dribble_pressure, _tuning)
		# Conducción cerrada (L1) y gambetas: la pelota pegada al pie.
		if p.close_control or p.skill in [Footballer.Skill.ROULETTE, Footballer.Skill.STEPOVER]:
			d *= 0.55
		target = Dribble.dribble_target(p.global_position, p.facing, Dribble.pulse(_touch_phase, d),
			p.shield_from, shielding)
	var to_target := target - Vector3(state.pos.x, 0.0, state.pos.z)
	var desired := pv + to_target * Dribble.spring_rate(control_u)
	var hv := Vector3(state.vel.x, 0.0, state.vel.z).move_toward(desired, _tuning.dribble_steer_accel * dt)
	state.vel.x = hv.x
	state.vel.z = hv.z
	state.spin = Vector3.ZERO


func _sync_node(dt: float) -> void:
	if dt > 0.0:
		visual_offset *= exp(-dt / VISUAL_SETTLE)
	global_position = state.pos + visual_offset
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
	disc.top_radius = _tuning.ball_radius * 2.0
	disc.bottom_radius = _tuning.ball_radius * 2.0
	disc.height = 0.005
	_shadow.mesh = disc
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0, 0, 0, 0.6)
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
