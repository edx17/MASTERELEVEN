class_name BallPhysics
extends RefCounted
## Física propia de la pelota (decisión A): integración manual, determinista y
## fácil de ajustar. Incluye gravedad, arrastre del aire, efecto Magnus,
## piques con pérdida de energía, rozamiento al rodar y colisiones con postes,
## travesaño y red. Todo es estático y sin nodos para poder testearlo solo.

const EV_BOUNCE := 1
const EV_POST := 2
const EV_NET := 4

## Paso fijo para las simulaciones de predicción (resolución de pases, IA).
const SIM_DT := 1.0 / 120.0
const REST_SPEED := 0.05


## Avanza el estado `dt` segundos. Devuelve una máscara de eventos EV_*.
static func step(s: BallState, dt: float, t: Tuning) -> int:
	var events := 0
	var r := t.ball_radius
	var prev := s.pos
	var grounded := s.pos.y <= r + 0.001 and absf(s.vel.y) < 0.01

	var acc := -s.vel * s.vel.length() * t.air_drag
	if s.spin.length_squared() > 0.0001:
		acc += t.magnus * s.spin.cross(s.vel)

	if grounded:
		acc.y = 0.0
		var hv := Vector3(s.vel.x, 0.0, s.vel.z)
		var hs := hv.length()
		if hs > 0.0:
			var dec := t.rolling_decel * dt
			if dec >= hs or hs < REST_SPEED:
				s.vel.x = 0.0
				s.vel.z = 0.0
			else:
				s.vel -= hv / hs * dec
		# En el piso el efecto se "come" rápido.
		s.spin *= maxf(0.0, 1.0 - 3.0 * dt)
	else:
		acc.y -= t.gravity

	s.vel += acc * dt
	s.pos += s.vel * dt
	s.spin *= maxf(0.0, 1.0 - t.spin_decay * dt)

	# Pique contra el pasto.
	if s.pos.y < r:
		s.pos.y = r
		if s.vel.y < -t.bounce_min_speed:
			s.vel.y = -s.vel.y * t.ground_restitution
			s.vel.x *= t.bounce_friction
			s.vel.z *= t.bounce_friction
			s.spin *= 0.7
			events |= EV_BOUNCE
		else:
			s.vel.y = 0.0

	for side in [-1, 1]:
		events |= _collide_goal(prev, s, side, t)
	return events


# --- Arcos -------------------------------------------------------------------

static func _collide_goal(prev: Vector3, s: BallState, side: int, t: Tuning) -> int:
	# Chequeo rápido: lejos del arco no hay nada que hacer.
	if absf(absf(s.pos.x) - Pitch.HALF_LENGTH) > Pitch.GOAL_DEPTH + 1.0 or signf(s.pos.x) != side:
		return 0
	var events := 0
	var r := t.ball_radius
	var gx := side * Pitch.HALF_LENGTH
	var reach := r + Pitch.POST_RADIUS

	# Postes (cilindros verticales).
	if s.pos.y < Pitch.GOAL_HEIGHT + reach:
		for pz in [-Pitch.GOAL_HALF_WIDTH, Pitch.GOAL_HALF_WIDTH]:
			var d := Vector3(s.pos.x - gx, 0.0, s.pos.z - pz)
			var dist := d.length()
			if dist < reach and dist > 0.0001:
				var n := d / dist
				s.pos.x = gx + n.x * reach
				s.pos.z = pz + n.z * reach
				if _reflect(s, n, t.post_restitution):
					events |= EV_POST

	# Travesaño (cilindro horizontal a lo largo de Z).
	if absf(s.pos.z) < Pitch.GOAL_HALF_WIDTH:
		var d2 := Vector3(s.pos.x - gx, s.pos.y - Pitch.GOAL_HEIGHT, 0.0)
		var dist2 := d2.length()
		if dist2 < reach and dist2 > 0.0001:
			var n2 := d2 / dist2
			s.pos.x = gx + n2.x * reach
			s.pos.y = Pitch.GOAL_HEIGHT + n2.y * reach
			if _reflect(s, n2, t.post_restitution):
				events |= EV_POST

	# Red: fondo, costados y techo como paredes finas.
	var back_x := side * (Pitch.HALF_LENGTH + Pitch.GOAL_DEPTH)
	if _net_plane(prev, s, 0, back_x, side, t):
		events |= EV_NET
	for pz2 in [-Pitch.GOAL_HALF_WIDTH, Pitch.GOAL_HALF_WIDTH]:
		if _net_plane(prev, s, 2, pz2, side, t):
			events |= EV_NET
	if _net_plane(prev, s, 1, Pitch.GOAL_HEIGHT, side, t):
		events |= EV_NET
	return events


## Refleja la componente de la velocidad que va contra la normal `n`.
static func _reflect(s: BallState, n: Vector3, restitution: float) -> bool:
	var vn := s.vel.dot(n)
	if vn >= 0.0:
		return false
	s.vel -= (1.0 + restitution) * vn * n
	return true


## Pared de red perpendicular al eje `axis` (0=x, 1=y, 2=z) ubicada en `plane`.
## Detecta si el segmento prev->pos la cruzó dentro de los límites del arco.
static func _net_plane(prev: Vector3, s: BallState, axis: int, plane: float, side: int, t: Tuning) -> bool:
	var r := t.ball_radius
	var from_side := signf(prev[axis] - plane)
	if from_side == 0.0:
		from_side = -signf(s.vel[axis])
	var eff := plane + from_side * r
	# Sólo cuenta si venía del lado `from_side` y ahora lo atravesó.
	if from_side * (prev[axis] - eff) < -0.0001 or from_side * (s.pos[axis] - eff) >= 0.0:
		return false
	# Punto de cruce aproximado: se usa la posición actual para verificar límites.
	var p := s.pos
	var inside_depth := side * p.x >= Pitch.HALF_LENGTH - r and side * p.x <= Pitch.HALF_LENGTH + Pitch.GOAL_DEPTH + r
	var inside_width := absf(p.z) <= Pitch.GOAL_HALF_WIDTH + r
	var inside_height := p.y <= Pitch.GOAL_HEIGHT + r
	var ok := false
	match axis:
		0: ok = inside_width and inside_height
		1: ok = inside_depth and inside_width and side * p.x > Pitch.HALF_LENGTH
		2: ok = inside_depth and inside_height and side * p.x > Pitch.HALF_LENGTH
	if not ok:
		return false
	s.pos[axis] = eff
	s.vel[axis] = -s.vel[axis] * t.net_restitution
	# La red absorbe: frena también el resto del movimiento.
	for other in 3:
		if other != axis:
			s.vel[other] *= 0.55
	s.spin *= 0.3
	return true


# --- Predicción y resolución de pases -----------------------------------------

## Simula hacia adelante y devuelve la posición luego de `time` segundos.
static func predict(s: BallState, time: float, t: Tuning) -> Vector3:
	var sim := s.copy()
	var elapsed := 0.0
	while elapsed < time:
		step(sim, SIM_DT, t)
		elapsed += SIM_DT
	return sim.pos


## Velocidad inicial para que un pase rasante recorra `distance` y llegue con
## `arrive_speed`. Solución analítica de dv/ds = -(a + k·v²)/v.
static func ground_pass_speed(distance: float, arrive_speed: float, t: Tuning) -> float:
	var a := t.rolling_decel
	var k := t.air_drag
	if k < 0.00001:
		return sqrt(arrive_speed * arrive_speed + 2.0 * a * distance)
	return sqrt(((a + k * arrive_speed * arrive_speed) * exp(2.0 * k * distance) - a) / k)


## Tiempo aproximado (s) que tarda un pase rasante en recorrer `distance`
## saliendo a `speed`. Devuelve INF si la pelota se frena antes.
static func ground_travel_time(speed: float, distance: float, t: Tuning) -> float:
	var sim := BallState.new(Vector3(0.0, t.ball_radius, 0.0), Vector3(speed, 0.0, 0.0))
	var elapsed := 0.0
	while sim.pos.x < distance:
		step(sim, SIM_DT, t)
		elapsed += SIM_DT
		if sim.vel.x <= 0.0 or elapsed > 10.0:
			return INF
	return elapsed


## Distancia horizontal del primer pique de una pelota lanzada con `speed` y
## ángulo `angle_deg` desde el piso. También devuelve el tiempo de vuelo.
static func lob_landing(speed: float, angle_deg: float, t: Tuning) -> Vector2:
	var ang := deg_to_rad(angle_deg)
	var sim := BallState.new(Vector3(0.0, t.ball_radius, 0.0), Vector3(cos(ang), sin(ang), 0.0) * speed)
	var elapsed := 0.0
	# Primer paso fuera del piso para no confundirlo con un pique.
	while elapsed < 8.0:
		var ev := step(sim, SIM_DT, t)
		elapsed += SIM_DT
		if ev & EV_BOUNCE or (sim.pos.y <= t.ball_radius + 0.0001 and elapsed > SIM_DT * 2.0):
			return Vector2(sim.pos.x, elapsed)
	return Vector2(sim.pos.x, elapsed)


## Velocidad para que un globo con ángulo `angle_deg` pique a `distance` metros.
## Búsqueda binaria sobre la simulación real (respeta arrastre del aire).
static func lob_speed(distance: float, angle_deg: float, t: Tuning) -> float:
	var lo := 1.0
	var hi := 45.0
	for i in 22:
		var mid := (lo + hi) * 0.5
		if lob_landing(mid, angle_deg, t).x < distance:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5
