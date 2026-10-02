class_name KickActions
extends RefCounted
## Ejecución de pases y tiros, compartida por humanos e IA.
## Cada acción recibe la dirección pedida (stick o intención de la IA) y la
## potencia 0..1 de la barra. Devuelve el receptor elegido (o null).
## Hay ayuda para encontrar receptor (pass_assist), pero la dirección del stick
## pesa y cada patada tiene un error según atributos, presión, orientación del
## cuerpo y potencia (KickAccuracy): los pases y remates se pueden fallar.

## CLEAR: despeje (largo y alto, lejos del arco propio, sin receptor).
enum Kind { SHORT_PASS, THROUGH_PASS, LONG_PASS, SHOT, CLEAR }
## Variante de la patada (combinaciones del WE):
## SHOT: LOW = remate rasante (doble Cuadrado), HIGH = globo / picada (L1 + Cuadrado).
## LONG_PASS: LOW = centro raso (doble Círculo), HIGH = centro alto (L1 + Círculo).
## Variantes (WE): LOW = rasante (doble toque; centro: triple toque al primer
## palo), HIGH = con L1 (globo, centro bombeado), MID = centro a media altura
## (doble Círculo), PLACED = tiro colocado (R2 tras cargar el remate).
enum Variant { NORMAL, LOW, HIGH, MID, PLACED }

## Altura desde la que se hace un lateral (manos).
const THROW_IN_HEIGHT := 1.8

var ball: Ball
var tuning: Tuning
## Lateral en curso: los pases salen con las manos.
var throw_in_mode: bool = false
## Presión rival sobre el pateador (0..1); la fija el partido antes de patear.
var pressure: float = 0.0
## Último error aplicado en grados (depuración / tests).
var last_error: float = 0.0
## Si es false no se sortea error (tests deterministas).
var randomize_error: bool = true
## Receptor elegido de antemano (el humano lo ve marcado mientras carga la
## barra y queda "trabado" al soltar). Se consume en la próxima patada.
var forced_receiver: Footballer = null
## La última patada fue un saque con la mano del arquero (para la animación).
var hand_throw: bool = false
## Variante de la próxima patada (se consume al patear).
var variant: int = Variant.NORMAL


func _init(p_ball: Ball, p_tuning: Tuning) -> void:
	ball = p_ball
	tuning = p_tuning


func execute(kind: int, player: Footballer, dir: Vector3, power: float) -> Footballer:
	hand_throw = false
	var forced := forced_receiver
	forced_receiver = null
	var v := variant
	variant = Variant.NORMAL
	if forced != null and (forced.team != player.team or forced == player):
		forced = null
	if throw_in_mode:
		return _throw_in(kind, player, dir, power, forced)
	if player.is_keeper() and ball.in_hands:
		# Arquero con la pelota en las manos: pase corto / al hueco = saque con
		# la mano, rodando por el piso (no se tira para arriba); pase largo o
		# tiro = pelotazo de volea.
		if kind == Kind.SHORT_PASS or kind == Kind.THROUGH_PASS:
			hand_throw = true
			var d := _dir_or_facing(player, dir)
			ball.state.pos = player.flat_pos() + d * 0.6 + Vector3.UP * tuning.ball_radius
			ball.state.vel = Vector3.ZERO
			return short_pass(player, dir, power, forced)
		return long_pass(player, dir, maxf(power, 0.4), forced)
	match kind:
		Kind.SHORT_PASS:
			return short_pass(player, dir, power, forced)
		Kind.THROUGH_PASS:
			return through_pass(player, dir, power, forced, v)
		Kind.LONG_PASS:
			return long_pass(player, dir, power, forced, v)
		Kind.SHOT:
			if v == Variant.HIGH:
				chip(player, dir, power)
			else:
				shoot(player, dir, power, v == Variant.LOW, v == Variant.PLACED)
		Kind.CLEAR:
			clearance(player, dir, power)
	return null


## A quién iría un pase de tipo `kind` hacia `dir` si se patea ahora (el
## mismo criterio que la ejecución). null para remates o si no hay nadie.
func preview_receiver(kind: int, player: Footballer, dir: Vector3) -> Footballer:
	var d := _dir_or_facing(player, dir)
	if throw_in_mode:
		var far := kind == Kind.LONG_PASS or kind == Kind.THROUGH_PASS
		return _pick(player, d, 3.0, 30.0 if far else 18.0, far)
	match kind:
		Kind.SHORT_PASS:
			return _pick_always(player, d, 2.5, tuning.short_pass_max_distance)
		Kind.THROUGH_PASS:
			return _pick(player, d, 4.0, 45.0, false)
		Kind.LONG_PASS:
			if is_cross_position(player, kick_origin(player)):
				return _best_in_box(player)
			return _pick_long(player, d)
	return null


## Desde dónde sale el pase: la pelota si está al pie; si todavía viene
## (toque de primera pedido de antemano), desde el pie del que la va a patear.
## Elegir desde la pelota en vuelo mandaba el pase de primera a cualquier lado.
func kick_origin(player: Footballer) -> Vector3:
	var bp := ball.flat_pos()
	if bp.distance_to(player.flat_pos()) <= 1.5:
		return bp
	return player.flat_pos() + player.facing * 0.5


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
	var from := kick_origin(player)
	var idx := PassTargeting.choose(from, dir, pos, tuning.pass_cone_degrees, min_d, max_d, prefer_far)
	if idx < 0:
		# Segundo intento con un cono más abierto para no "regalar" la pelota.
		idx = PassTargeting.choose(from, dir, pos, tuning.pass_cone_degrees * 1.6, min_d, max_d, prefer_far)
	return mates[idx] if idx >= 0 else null


## Receptor de un pase largo: en el cono del stick y, si no hay nadie, el
## compañero más cercano a esa dirección (hasta 100°): un pelotazo al vacío
## sin nadie que vaya a buscarlo casi nunca es lo que se quiso hacer.
func _pick_long(player: Footballer, dir: Vector3) -> Footballer:
	var r := _pick(player, dir, 12.0, 75.0, true)
	if r != null:
		return r
	var mates := _mates(player)
	var idx := PassTargeting.choose(kick_origin(player), dir, _positions(mates), 100.0, 10.0, 75.0, false)
	return mates[idx] if idx >= 0 else null


## Como _pick, pero el pase corto siempre busca a alguien: si no hay nadie en
## el cono, abre más el ángulo y, en última instancia, elige al compañero más
## cercano a la dirección pedida (nunca "suelta" la pelota al vacío).
func _pick_always(player: Footballer, dir: Vector3, min_d: float, max_d: float) -> Footballer:
	var r := _pick(player, dir, min_d, max_d, false, true)
	if r != null:
		return r
	var mates := _mates(player, true)
	var pos := _positions(mates)
	var idx := PassTargeting.choose(kick_origin(player), dir, pos, 179.0, min_d, max_d * 1.3, false)
	return mates[idx] if idx >= 0 else null


## Pase rasante al compañero en la dirección pedida, con adelanto según su carrera.
func short_pass(player: Footballer, dir: Vector3, power: float, forced: Footballer = null) -> Footballer:
	var d := _dir_or_facing(player, dir)
	var receiver := forced if forced != null else _pick_always(player, d, 2.5, tuning.short_pass_max_distance)
	var arrive := lerpf(tuning.short_pass_arrive_min, tuning.short_pass_arrive_max, power)
	var target: Vector3
	if receiver == null:
		target = ball.flat_pos() + d * lerpf(8.0, 18.0, power)
	else:
		target = _lead_target(receiver, arrive)
	_ground_pass_to(player, target, arrive, dir, power)
	_assign_receiver(receiver, target)
	return receiver


## Pase al hueco: rasante al espacio delante del receptor.
func through_pass(player: Footballer, dir: Vector3, power: float, forced: Footballer = null,
		v: int = Variant.NORMAL) -> Footballer:
	var d := _dir_or_facing(player, dir)
	var receiver := forced if forced != null else _pick(player, d, 4.0, 45.0, false)
	var lead := lerpf(tuning.through_lead_min, tuning.through_lead_max, power)
	var target: Vector3
	if receiver == null:
		target = ball.flat_pos() + d * (12.0 + lead)
	else:
		var attack := Vector3(player.team.attack_dir, 0.0, 0.0)
		var run := (attack * 0.65 + d * 0.35).normalized()
		target = receiver.flat_pos() + run * lead
		# Al hueco de verdad: la pelota tiene que caer detrás de la última
		# línea rival (el receptor la gana corriendo), no en los pies.
		var line := last_defender_x(player.team)
		var dir_x := float(player.team.attack_dir)
		if (target.x - line) * dir_x < 4.0 and (line * dir_x) < Pitch.HALF_LENGTH - 8.0:
			target.x = line + dir_x * 4.0
	target = Pitch.clamp_to_field(target, 1.5)
	if v == Variant.HIGH:
		# Filtrado por elevación (L1 + Triángulo): picada por arriba de la
		# línea, cae a espaldas de los centrales.
		_lob_to(player, target, lerpf(24.0, 32.0, power), dir, power)
	else:
		_ground_pass_to(player, target, 3.5, dir, power)
	_assign_receiver(receiver, target)
	return receiver


## X (cancha) del defensor rival más retrasado (sin el arquero): la última línea.
func last_defender_x(team: Team) -> float:
	var best := -INF
	var line := 0.0
	for p: Footballer in _opponents(team):
		if p.is_keeper():
			continue
		var depth: float = p.flat_pos().x * team.attack_dir
		if depth > best:
			best = depth
			line = p.flat_pos().x
	return line


func _opponents(team: Team) -> Array:
	var out := []
	for n in team.players[0].get_parent().get_children():
		if n is Footballer and n.team != team:
			out.append(n)
	return out


## Pase largo / centro por arriba. La potencia define la altura del globo (o la
## distancia si no hay compañero en esa dirección). Desde una banda en campo
## rival es un centro: busca el área y sale con comba hacia el arco.
func long_pass(player: Footballer, dir: Vector3, power: float, forced: Footballer = null, v: int = Variant.NORMAL) -> Footballer:
	var d := _dir_or_facing(player, dir)
	var angle := lerpf(tuning.long_pass_angle_min, tuning.long_pass_angle_max, power)
	var cross := is_cross_position(player, ball.flat_pos())
	var receiver: Footballer
	var target: Vector3
	var spin := Vector3.ZERO
	if cross:
		receiver = forced if forced != null else _best_in_box(player)
		var side := player.team.attack_dir
		var box_spot := Vector3(side * (Pitch.HALF_LENGTH - 9.0), 0.0, -signf(ball.state.pos.z) * 1.5)
		target = receiver.flat_pos() if receiver != null else box_spot
		# El stick corre el centro al primer o segundo palo.
		target.z += clampf(d.z, -1.0, 1.0) * 4.0 * (1.0 if receiver == null else 0.4)
		angle = lerpf(14.0, 30.0, power)
		if v == Variant.LOW:
			# Centro rasante (triple Círculo): tenso y por el piso al primer
			# palo, para empujarla.
			if forced == null:
				target = Vector3(side * (Pitch.HALF_LENGTH - 5.0), 0.0, signf(ball.state.pos.z) * 2.0)
				receiver = _closest_mate_to(player, target)
			target = Pitch.clamp_to_field(target, 0.5)
			_ground_pass_to(player, target, 9.0, dir, power)
			_assign_receiver(receiver, target)
			return receiver
		if v == Variant.HIGH:
			angle += 14.0 # centro alto, bombeado
		elif v == Variant.MID:
			# Centro a media altura (doble Círculo): tenso, al punto penal,
			# para anticipar de palomita.
			angle = lerpf(8.0, 12.0, power)
		# Centro con comba hacia el arco (~40 rad/s).
		spin = Vector3(0.0, -signf(ball.state.pos.z) * side * 40.0, 0.0)
	else:
		receiver = forced if forced != null else _pick_long(player, d)
		if receiver == null:
			target = ball.flat_pos() + d * lerpf(tuning.long_pass_free_min, tuning.long_pass_free_max, power)
		else:
			# Adelanto aproximado según el tiempo de vuelo.
			var flight := BallPhysics.lob_landing(BallPhysics.lob_speed(receiver.flat_pos().distance_to(ball.flat_pos()), angle, tuning), angle, tuning).y
			target = receiver.flat_pos() + receiver.velocity * flight * 0.8
		if v == Variant.LOW:
			target = Pitch.clamp_to_field(target, 0.5)
			_ground_pass_to(player, target, 7.0, dir, power)
			_assign_receiver(receiver, target)
			return receiver
		if v == Variant.HIGH:
			angle += 12.0
	target = Pitch.clamp_to_field(target, 0.5)
	_lob_to(player, target, angle, dir, power, spin)
	_assign_receiver(receiver, target)
	return receiver


## Banda en el último tercio: el pase largo se convierte en centro.
static func is_cross_position(player: Footballer, ball_pos: Vector3) -> bool:
	var progress := player.team.progress_of(ball_pos)
	return progress > 0.7 and absf(ball_pos.z) > Pitch.PENALTY_AREA_HALF_WIDTH - 4.0


func _best_in_box(player: Footballer) -> Footballer:
	var best: Footballer = null
	var best_d := INF
	var goal := player.team.target_goal()
	for m in _mates(player):
		if not Pitch.in_penalty_area(m.flat_pos(), player.team.attack_dir):
			continue
		var dd := m.flat_pos().distance_to(goal)
		if dd < best_d:
			best_d = dd
			best = m
	return best


## Tiro al arco: la dirección vertical del stick elige el palo; la potencia
## define velocidad y altura (a potencia máxima puede irse por arriba). Con la
## pelota en el aire sale de cabeza o de volea. La precisión depende de
## shooting/technique/balance, la presión, la orientación y la distancia.
## La patada es un tiro libre o un penal (para el especialista). La fija el partido.
var set_piece := false


func shoot(player: Footballer, dir: Vector3, power: float, low: bool = false, placed: bool = false) -> void:
	var side := player.team.attack_dir
	var aim_z := 0.0
	if absf(dir.z) > 0.2:
		aim_z = signf(dir.z) * lerpf(1.8, 3.1, absf(dir.z))
	else:
		aim_z = randf_range(-1.2, 1.2) if randomize_error else 0.0
	if placed:
		# Colocado (R2): abre el pie y busca el palo (el que marca el stick o,
		# sin stick, el más lejano), sacrificando potencia por precisión.
		var post_side := signf(dir.z) if absf(dir.z) > 0.2 else -signf(ball.state.pos.z)
		if post_side == 0.0:
			post_side = 1.0
		aim_z = post_side * 3.0
	var goal := Vector3(side * Pitch.HALF_LENGTH, 0.0, aim_z)
	var to := goal - ball.flat_pos()
	var flat := Vector3(to.x, 0.0, to.z).normalized()
	var height := ball.state.pos.y
	var header := height > 1.3
	var volley := not header and height > 0.5
	var data := player.data
	var shooting := data.shooting if data else 60
	if header and data:
		shooting = data.heading
	var err := KickAccuracy.shot_error(shooting, data.technique if data else 60, data.balance if data else 60,
		pressure, rad_to_deg(player.facing.angle_to(flat)), to.length(), power)
	if volley:
		err *= 1.5
	if placed:
		err *= PLACED_ERROR
	# Pierna mala: con la pelota del lado de la pierna menos hábil sale mordido.
	var weak := not header and uses_weak_foot(player, ball.flat_pos())
	if weak:
		err *= WEAK_FOOT_ERROR
	# Habilidades especiales.
	if data != null:
		if data.has_ability("goleador") and to.length() < 20.0:
			err *= 0.8
		if header and data.has_ability("cabeceador"):
			err *= 0.75
		if set_piece and data.has_ability("especialista"):
			err *= 0.65
	err += KickAccuracy.fatigue_penalty(player.stamina_fraction())
	last_error = err
	if randomize_error:
		flat = flat.rotated(Vector3.UP, deg_to_rad(randf_range(-err, err)))
	var speed := lerpf(tuning.shot_speed_min, tuning.shot_speed_max, power)
	if header:
		speed *= 0.6
	elif placed:
		speed *= PLACED_SPEED
	if weak:
		speed *= WEAK_FOOT_SPEED
	# La potencia define a qué altura llega al arco: floja = rasante, fuerte =
	# a media altura / arriba; a fondo (>95 %) se puede ir por arriba.
	var aim_height := lerpf(tuning.shot_height_min, tuning.shot_height_max, power)
	if power > 0.95:
		aim_height += 0.9
	if header:
		aim_height = lerpf(0.3, 1.6, power)
	elif placed:
		aim_height = lerpf(0.3, 1.3, power)
	elif low:
		# Remate rasante (doble Cuadrado): por el piso, algo más preciso.
		aim_height = 0.12
		err *= 0.85
		last_error = err
	if randomize_error:
		aim_height += randf_range(-1.0, 1.0) * err * 0.06
	var vel := shot_velocity(ball.state.pos, flat, to.length(), maxf(aim_height, 0.15), speed, tuning)
	if low and not header:
		# Rasante de verdad: sale por el piso (rueda), no bombeada para llegar baja.
		vel = flat * speed * 0.92
		if ball.state.pos.y < 0.4:
			ball.state.pos.y = tuning.ball_radius
	# Un poco de comba natural hacia el centro del arco.
	# Comba natural del empeine hacia el centro del arco (0-30 rad/s).
	var curl := Vector3(0.0, signf(aim_z) * side * randf_range(0.0, 30.0), 0.0) if randomize_error else Vector3.ZERO
	ball.intended_receiver = null
	ball.kick(vel, curl, player)


## Pierna mala: más error y algo menos de potencia.
const WEAK_FOOT_ERROR := 1.4
const WEAK_FOOT_SPEED := 0.9


## Patea con la pierna menos hábil: la pelota está claramente del otro lado
## del cuerpo (con la pelota al medio usa la buena).
static func uses_weak_foot(player: Footballer, ball_pos: Vector3) -> bool:
	if player.data == null:
		return false
	var off := player.ball_offset_side(ball_pos)
	if absf(off) < 0.12:
		return false
	var left := off > 0.0
	return left == (player.data.foot == PlayerData.Foot.RIGHT)


## Tiro colocado: menos error y menos velocidad que el remate normal.
const PLACED_ERROR := 0.45
const PLACED_SPEED := 0.78


func _closest_mate_to(player: Footballer, point: Vector3) -> Footballer:
	var best: Footballer = null
	var best_d := INF
	for m in _mates(player):
		var d := m.flat_pos().distance_to(point)
		if d < best_d:
			best_d = d
			best = m
	return best


## Globo / picada (L1 + Cuadrado): por arriba del arquero, cae justo detrás
## de la línea. La potencia lo hace más alto y más largo.
func chip(player: Footballer, dir: Vector3, power: float) -> void:
	var side := player.team.attack_dir
	var aim_z := signf(dir.z) * 1.5 if absf(dir.z) > 0.2 else 0.0
	var goal := Vector3(side * Pitch.HALF_LENGTH, 0.0, aim_z)
	var to := goal - ball.flat_pos()
	var flat := Vector3(to.x, 0.0, to.z).normalized()
	var data := player.data
	var err := KickAccuracy.shot_error(data.shooting if data else 60, data.technique if data else 60,
		data.balance if data else 60, pressure, rad_to_deg(player.facing.angle_to(flat)), to.length(), power)
	err = err * 1.2 + KickAccuracy.fatigue_penalty(player.stamina_fraction())
	last_error = err
	var dist := to.length() + lerpf(0.0, 2.5, power)
	if randomize_error:
		flat = flat.rotated(Vector3.UP, deg_to_rad(randf_range(-err, err)))
		dist *= 1.0 + randf_range(-1.0, 1.0) * err * 0.012
	var angle := lerpf(36.0, 48.0, power)
	var speed := BallPhysics.lob_speed(dist, angle, tuning)
	var a := deg_to_rad(angle)
	if ball.state.pos.y < 0.4:
		ball.state.pos.y = tuning.ball_radius
	ball.intended_receiver = null
	ball.kick(flat * cos(a) * speed + Vector3.UP * sin(a) * speed, Vector3.ZERO, player)


## Despeje: largo y alto, lejos del arco propio (hacia adelante y al costado
## donde apunte el stick). No busca compañero.
func clearance(player: Footballer, dir: Vector3, power: float) -> void:
	var fwd := Vector3(player.team.attack_dir, 0.0, 0.0)
	var d := _dir_or_facing(player, dir)
	# Nunca hacia el arco propio: se corrige hacia adelante.
	if d.dot(fwd) < 0.3:
		d = (d + fwd * 1.5).normalized()
	var target := Pitch.clamp_to_field(ball.flat_pos() + d * lerpf(28.0, 45.0, maxf(power, 0.5)), 1.0)
	ball.intended_receiver = null
	_lob_to(player, target, 34.0, Vector3.ZERO, power)
	ball.intended_receiver = null


## Velocidad de salida para que un remate a `speed` recorra `distance` en la
## dirección `flat` y llegue a la línea a `aim_height`. Aproximación balística
## con el tiempo de vuelo estimado (el arrastre se compensa un poco).
static func shot_velocity(from: Vector3, flat: Vector3, distance: float, aim_height: float, speed: float, t: Tuning) -> Vector3:
	var time := distance / maxf(speed * 0.93, 1.0)
	var vy := (aim_height - from.y + 0.5 * t.gravity * time * time) / maxf(time, 0.05)
	vy = clampf(vy, -speed * 0.3, speed * 0.6)
	var vh := sqrt(maxf(speed * speed - vy * vy, speed * speed * 0.5))
	return flat * vh + Vector3.UP * vy


func _throw_in(kind: int, player: Footballer, dir: Vector3, power: float, forced: Footballer = null) -> Footballer:
	var d := _dir_or_facing(player, dir)
	var far := kind == Kind.LONG_PASS or kind == Kind.THROUGH_PASS
	var receiver := forced if forced != null else _pick(player, d, 3.0, 30.0 if far else 18.0, far)
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


## Dirección final de un pase: asistencia hacia el objetivo + stick + error.
func _pass_direction(player: Footballer, to_target: Vector3, stick: Vector3, power: float) -> Vector3:
	var dir := KickAccuracy.assisted_direction(to_target, stick, tuning.pass_assist)
	var data := player.data
	var err := KickAccuracy.pass_error(data.passing if data else 60, data.technique if data else 60,
		pressure, rad_to_deg(player.facing.angle_to(dir)), power)
	if data != null and data.has_ability("pasador"):
		err *= 0.65
	err += KickAccuracy.fatigue_penalty(player.stamina_fraction())
	last_error = err
	if randomize_error:
		dir = dir.rotated(Vector3.UP, deg_to_rad(randf_range(-err, err)))
	return dir


func _ground_pass_to(player: Footballer, target: Vector3, arrive: float, stick: Vector3 = Vector3.ZERO, power: float = 0.5) -> void:
	var from := ball.flat_pos()
	var to := target - from
	to.y = 0.0
	var dist := maxf(to.length(), 0.5)
	var v0 := minf(BallPhysics.ground_pass_speed(dist, arrive, tuning), 32.0)
	var dir := _pass_direction(player, to, stick, power) if to.length() > 0.01 else player.facing
	if ball.state.pos.y < 0.4:
		ball.state.pos.y = tuning.ball_radius
	ball.kick(dir * v0, Vector3.ZERO, player)


func _lob_to(player: Footballer, target: Vector3, angle_deg: float, stick: Vector3 = Vector3.ZERO,
		power: float = 0.5, spin: Vector3 = Vector3.ZERO) -> void:
	var from := ball.flat_pos()
	var to := target - from
	to.y = 0.0
	var dist := maxf(to.length(), 1.0)
	var dir := _pass_direction(player, to, stick, power)
	# El error también afecta la distancia (≈ 1 % por grado de error).
	if randomize_error:
		dist *= 1.0 + randf_range(-1.0, 1.0) * last_error * 0.01
	var speed := BallPhysics.lob_speed(dist, angle_deg, tuning)
	var a := deg_to_rad(angle_deg)
	if ball.state.pos.y < 0.4:
		ball.state.pos.y = tuning.ball_radius
	ball.kick(dir * cos(a) * speed + Vector3.UP * sin(a) * speed, spin, player)


func _assign_receiver(receiver: Footballer, target: Vector3) -> void:
	ball.intended_receiver = receiver
	if receiver != null:
		receiver.set_pass_target(target, 3.0)
