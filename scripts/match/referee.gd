class_name Referee
extends Node3D
## Árbitro (sólo presentación; no toca la pelota ni a los jugadores). Sigue
## la jugada a distancia, en diagonal y del lado del centro de la cancha; en
## una falta va hasta el infractor y le muestra la tarjeta (amarilla o roja).

const RUN_SPEED := 6.4
const JOG_SPEED := 3.2
const ACCEL := 9.0
## Distancia a la que sigue la jugada (m a lo largo y a lo ancho).
const TRAIL_X := 7.0
const TRAIL_Z := 9.0
## Distancia a la que se para frente al amonestado.
const CARD_DISTANCE := 1.8
## Cuánto tiempo muestra la tarjeta (s).
const CARD_TIME := 2.0
const YELLOW := Color(1.0, 0.86, 0.1)
const RED := Color(0.9, 0.08, 0.08)

var visual: PlayerVisual
var velocity := Vector3.ZERO
var facing := Vector3.FORWARD
## Si no es INF, va hacia ahí en lugar de seguir la jugada.
var target := Vector3.INF
## Punto que mira cuando está quieto.
var look := Vector3.INF
var card_left := 0.0
var _card: Node3D
var _prev_speed := 0.0


func _ready() -> void:
	visual = ModelVisual.new() if ModelVisual.available() else PlayerVisual.new()
	add_child(visual)
	var black := Color(0.05, 0.05, 0.06)
	visual.setup({"shirt": black, "shorts": black, "socks": black}, 777)
	_build_card()


func _build_card() -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.14, 0.01)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = YELLOW
	mat.emission_enabled = true
	mat.emission = YELLOW
	mat.emission_energy_multiplier = 0.4
	mi.material_override = mat
	_card = mi
	if visual is ModelVisual and (visual as ModelVisual)._skel != null:
		var skel := (visual as ModelVisual)._skel
		var att := BoneAttachment3D.new()
		att.bone_name = "hand_r"
		skel.add_child(att)
		att.add_child(mi)
		# Entre los dedos, un poco por encima de la mano.
		mi.position = Vector3(0.0, 0.1, 0.03)
	else:
		visual.add_child(mi)
		mi.position = Vector3(-0.3, 2.15, 0.0)
	mi.visible = false


## Mueve al árbitro un paso (lo llama el partido).
func tick(dt: float, ball_pos: Vector3, playing: bool) -> void:
	var goal := target
	if goal == Vector3.INF and playing:
		goal = trail_point(ball_pos)
	var to := Vector3.ZERO if goal == Vector3.INF else goal - global_position
	to.y = 0.0
	var want := Vector3.ZERO
	var d := to.length()
	if d > 0.4:
		var speed := RUN_SPEED if d > 9.0 or target != Vector3.INF else (JOG_SPEED if d > 2.0 else 1.4)
		want = to / d * speed
	velocity = velocity.move_toward(want, ACCEL * dt)
	global_position += velocity * dt
	global_position.y = 0.0
	var spd := velocity.length()
	if spd > 0.8:
		facing = velocity / spd
	else:
		var focus := look if look != Vector3.INF else ball_pos
		var f := focus - global_position
		f.y = 0.0
		if f.length_squared() > 0.04:
			facing = facing.slerp(f.normalized(), minf(1.0, 6.0 * dt)).normalized()
	rotation.y = atan2(facing.x, facing.z)
	if card_left > 0.0:
		card_left -= dt
		if card_left <= 0.0:
			_card.visible = false
	var accel := (spd - _prev_speed) / maxf(dt, 0.001)
	_prev_speed = spd
	visual.update(dt, spd, 8.4, PlayerVisual.Pose.NORMAL, accel)


## Dónde se ubica siguiendo la jugada: atrás y en diagonal, del lado del
## centro (no tapa la banda ni el arco).
static func trail_point(ball_pos: Vector3) -> Vector3:
	var sx := -signf(ball_pos.x) if absf(ball_pos.x) > 1.0 else 1.0
	var sz := -signf(ball_pos.z) if absf(ball_pos.z) > 1.0 else 1.0
	var p := Vector3(ball_pos.x + sx * TRAIL_X, 0.0, ball_pos.z + sz * TRAIL_Z)
	p.x = clampf(p.x, -Pitch.HALF_LENGTH + 6.0, Pitch.HALF_LENGTH - 6.0)
	p.z = clampf(p.z, -Pitch.HALF_WIDTH + 4.0, Pitch.HALF_WIDTH - 4.0)
	return p


## Saque del medio: a un costado del círculo central (del lado de enfrente de
## la cámara, para no tapar), en el campo del equipo que saca.
static func kickoff_spot(kicking_attack_dir: int) -> Vector3:
	return Vector3(-kicking_attack_dir * 4.0, 0.0, -(Pitch.CENTER_CIRCLE_RADIUS + 1.5))


## Va hasta el jugador (se para enfrente, a la distancia de amonestar).
func approach(p: Vector3, from: Vector3) -> void:
	var dir := from - p
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.01 else Vector3.RIGHT
	target = p + dir * CARD_DISTANCE
	look = p


func arrived() -> bool:
	if target == Vector3.INF:
		return true
	var d := target - global_position
	d.y = 0.0
	return d.length() < 0.6


## Levanta la tarjeta (amarilla o roja).
func show_card(red: bool) -> void:
	var c := RED if red else YELLOW
	var mat := (_card as MeshInstance3D).material_override as StandardMaterial3D
	mat.albedo_color = c
	mat.emission = c
	_card.visible = true
	card_left = CARD_TIME
	velocity = Vector3.ZERO
	visual.play(PlayerVisual.Event.CARD)


## Vuelve a seguir la jugada.
func release() -> void:
	target = Vector3.INF
	look = Vector3.INF


func teleport(p: Vector3) -> void:
	global_position = Vector3(p.x, 0.0, p.z)
	velocity = Vector3.ZERO
