class_name KickActions
extends RefCounted
## Ejecución de pases y tiros, compartida por humanos e IA.
## Cada acción recibe la dirección pedida (stick o intención de la IA) y la
## potencia 0..1 de la barra. Devuelve el receptor elegido (o null).

enum Kind { SHORT_PASS, THROUGH_PASS, LONG_PASS, SHOT }

## Altura desde la que se hace un lateral (manos).
const THROW_IN_HEIGHT := 1.8

var ball: Ball
var tuning: Tuning
## Lateral en curso: los pases salen con las manos.
var throw_in_mode: bool = false


func _init(p_ball: Ball, p_tuning: Tuning) -> void:
	ball = p_ball
	tuning = p_tuning


func execute(kind: int, player: Footballer, dir: Vector3, power: float) -> Footballer:
	if throw_in_mode:
		return _throw_in(kind, player, dir, power)
	match kind:
		Kind.SHORT_PASS:
			return short_pass(player, dir, power)
		Kind.THROUGH_PASS:
			return through_pass(player, dir, power)
		Kind.LONG_PASS:
			return long_pass(player, dir, power)
		Kind.SHOT:
			shoot(player, dir, power)
	return null


func _dir_or_facing(player: Footballer, dir: Vector3) -> Vector3:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 0.04:
		return player.facing
	return d.normalized()


func _mates(player: Footballer, include_keeper: bool = false) -> Array[Footballer]:
	var out: Array[Footballer] = []
	for m in player.team.players:
		if m != player and (include_keeper or not m.is_keeper()):
			out.append(m)
	return out


static func _positions(list: Array[Footballer]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for m in list:
		out.append(m.flat_pos())
	return out


func _pick(player: Footballer, dir: Vector3, min_d: float, max_d: float, prefer_far: bool, include_keeper: bool = false) -> Footballer:
	var mates := _mates(player, include_keeper)
	var pos := _positions(mates)
	var idx := PassTargeting.choose(ball.flat_pos(), dir, pos, tuning.pass_cone_degrees, min_d, max_d, prefer_far)
	if idx < 0:
		# Segundo intento con un cono más abierto para no "regalar" la pelota.
		idx = PassTargeting.choose(ball.flat_pos(), dir, pos, tuning.pass_cone_degrees * 1.6, min_d, max_d, prefer_far)
	return mates[idx] if idx >= 0 else null


## Pase rasante al compañero en la dirección pedida, con adelanto según su carrera.
func short_pass(player: Footballer, dir: Vector3, power: float) -> Footballer:
	var d := _dir_or_facing(player, dir)
	var receiver := _pick(player, d, 2.5, tuning.short_pass_max_distance, false, true)
	var arrive := lerpf(tuning.short_pass_arrive_min, tuning.short_pass_arrive_max, power)
	var target: Vector3
	if receiver == null:
		target = ball.flat_pos() + d * lerpf(8.0, 18.0, power)
	else:
		target = _lead_target(receiver, arrive)
	_ground_pass_to(player, target, arrive)
	_assign_receiver(receiver, target)
	return receiver


## Pase al hueco: rasante al espacio delante del receptor.
func through_pass(player: Footballer, dir: Vector3, power: float) -> Footballer:
	var d := _dir_or_facing(player, dir)
	var receiver := _pick(player, d, 4.0, 45.0, false)
	var lead := lerpf(tuning.through_lead_min, tuning.through_lead_max, power)
	var target: Vector3
	if receiver == null:
		target = ball.flat_pos() + d * (12.0 + lead)
	else:
		var attack := Vector3(player.team.attack_dir, 0.0, 0.0)
		var run := (attack * 0.65 + d * 0.35).normalized()
		target = receiver.flat_pos() + run * lead
	target = Pitch.clamp_to_field(target, 1.5)
	_ground_pass_to(player, target, 2.5)
	_assign_receiver(receiver, target)
	return receiver


## Pase largo / centro por arriba. La potencia define la altura del globo (o la
## distancia si no hay compañero en esa dirección).
func long_pass(player: Footballer, dir: Vector3, power: float) -> Footballer:
	var d := _dir_or_facing(player, dir)
	var receiver := _pick(player, d, 12.0, 75.0, true)
	var angle := lerpf(tuning.long_pass_angle_min, tuning.long_pass_angle_max, power)
	var target: Vector3
	if receiver == null:
		target = ball.flat_pos() + d * lerpf(tuning.long_pass_free_min, tuning.long_pass_free_max, power)
	else:
		# Adelanto aproximado según el tiempo de vuelo.
		var flight := BallPhysics.lob_landing(BallPhysics.lob_speed(receiver.flat_pos().distance_to(ball.flat_pos()), angle, tuning), angle, tuning).y
		target = receiver.flat_pos() + receiver.velocity * flight * 0.8
	target = Pitch.clamp_to_field(target, 0.5)
	_lob_to(player, target, angle)
	_assign_receiver(receiver, target)
	return receiver


## Tiro al arco: la dirección vertical del stick elige el palo; la potencia
## define velocidad y altura (a potencia máxima puede irse por arriba).
func shoot(player: Footballer, dir: Vector3, power: float) -> void:
	var side := player.team.attack_dir
	var aim_z := 0.0
	if absf(dir.z) > 0.2:
		aim_z = signf(dir.z) * lerpf(1.8, 3.1, absf(dir.z))
	else:
		aim_z = randf_range(-1.2, 1.2)
	var goal := Vector3(side * Pitch.HALF_LENGTH, 0.0, aim_z)
	var to := goal - ball.flat_pos()
	var flat := Vector3(to.x, 0.0, to.z).normalized()
	var err := randf_range(-1.0, 1.0) * tuning.shot_error_max * (0.35 + power * power)
	flat = flat.rotated(Vector3.UP, deg_to_rad(err))
	var speed := lerpf(tuning.shot_speed_min, tuning.shot_speed_max, power)
	var angle := lerpf(tuning.shot_angle_min, tuning.shot_angle_max, power)
	# Desde lejos hace falta algo más de elevación para que no muera rodando.
	angle += clampf((to.length() - 16.0) * 0.12, 0.0, 4.0)
	if power > 0.95:
		angle += 5.0
	var a := deg_to_rad(angle)
	var vel := flat * cos(a) * speed + Vector3.UP * sin(a) * speed
	# Un poco de comba natural hacia el centro del arco.
	var curl := Vector3(0.0, signf(aim_z) * side * randf_range(0.0, 3.0), 0.0)
	ball.intended_receiver = null
	ball.kick(vel, curl, player)


func _throw_in(kind: int, player: Footballer, dir: Vector3, power: float) -> Footballer:
	var d := _dir_or_facing(player, dir)
	var far := kind == Kind.LONG_PASS or kind == Kind.THROUGH_PASS
	var receiver := _pick(player, d, 3.0, 30.0 if far else 18.0, far)
	var target: Vector3
	if receiver == null:
		target = ball.flat_pos() + d * lerpf(8.0, 20.0, power)
	else:
		target = receiver.flat_pos()
	target = Pitch.clamp_to_field(target, 1.0)
	ball.state.pos.y = THROW_IN_HEIGHT
	var dist := target.distance_to(ball.flat_pos())
	var angle := 22.0
	var speed := BallPhysics.lob_speed(dist, angle, tuning) * 0.9
	var flat := (target - ball.flat_pos()).normalized()
	var a := deg_to_rad(angle)
	ball.kick(flat * cos(a) * speed + Vector3.UP * sin(a) * speed, Vector3.ZERO, player)
	_assign_receiver(receiver, target)
	return receiver


func _lead_target(receiver: Footballer, arrive: float) -> Vector3:
	var target := receiver.flat_pos()
	var rv := Vector3(receiver.velocity.x, 0.0, receiver.velocity.z)
	if rv.length() > 0.5:
		var dist := target.distance_to(ball.flat_pos())
		var v0 := BallPhysics.ground_pass_speed(dist, arrive, tuning)
		var time := 2.0 * dist / (v0 + arrive)
		target += rv * time * 0.85
	return Pitch.clamp_to_field(target, 0.8)


func _ground_pass_to(player: Footballer, target: Vector3, arrive: float) -> void:
	var from := ball.flat_pos()
	var to := target - from
	to.y = 0.0
	var dist := maxf(to.length(), 0.5)
	var v0 := minf(BallPhysics.ground_pass_speed(dist, arrive, tuning), 32.0)
	var dir := to / dist if to.length() > 0.01 else player.facing
	if ball.state.pos.y < 0.4:
		ball.state.pos.y = tuning.ball_radius
	ball.kick(dir * v0, Vector3.ZERO, player)


func _lob_to(player: Footballer, target: Vector3, angle_deg: float) -> void:
	var from := ball.flat_pos()
	var to := target - from
	to.y = 0.0
	var dist := maxf(to.length(), 1.0)
	var speed := BallPhysics.lob_speed(dist, angle_deg, tuning)
	var dir := to / dist
	var a := deg_to_rad(angle_deg)
	if ball.state.pos.y < 0.4:
		ball.state.pos.y = tuning.ball_radius
	ball.kick(dir * cos(a) * speed + Vector3.UP * sin(a) * speed, Vector3.ZERO, player)


func _assign_receiver(receiver: Footballer, target: Vector3) -> void:
	ball.intended_receiver = receiver
	if receiver != null:
		receiver.set_pass_target(target, 3.0)
