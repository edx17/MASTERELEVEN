class_name SaveModel
extends RefCounted
## Modelo de atajada (puro y testeable). Cuando sale un remate se predice la
## trayectoria hasta la línea de gol; el arquero llega si, en algún punto del
## tramo final (dentro de su zona), su tiempo de reacción más lo que puede
## desplazarse/estirarse alcanza para cubrir la distancia a la pelota. Así un
## arquero adelantado achica el ángulo (le basta menos desplazamiento), pero una
## pelota que le pasa por arriba (vaselina) no la alcanza. La potencia importa
## (menos tiempo), la colocación importa (más distancia) y los atributos del
## arquero importan. No es perfecto: hay un margen aleatorio.

## Profundidad (m desde la línea) del tramo de trayectoria que se evalúa.
const ZONE_DEPTH := 9.0
## Altura máxima que alcanza el arquero saltando con los brazos estirados.
const MAX_REACH_HEIGHT := 2.7

class Plan:
	## El remate va al arco (entre los palos y bajo el travesaño).
	var on_target: bool = false
	## Punto de cruce de la línea (x en la línea, y altura, z lateral).
	var point: Vector3 = Vector3.ZERO
	## Segundos hasta cruzar la línea.
	var time: float = 0.0
	## Margen (m): lo que el arquero alcanza menos lo que necesita (el mejor
	## punto del tramo final).
	var margin: float = 0.0
	## Probabilidad de atajarla.
	var chance: float = 0.0
	## Punto (y tiempo) donde el arquero la intercepta mejor.
	var save_point: Vector3 = Vector3.ZERO
	var save_time: float = 0.0
	## Tramo final de la trayectoria: posiciones y tiempos (zona del arquero).
	var path: PackedVector3Array = PackedVector3Array()
	var times: PackedFloat32Array = PackedFloat32Array()


## Predice el cruce de la línea de gol `goal_x` (simulando la física real) y
## guarda el tramo final de la trayectoria.
static func predict_crossing(state: BallState, goal_x: float, t: Tuning, max_time: float = 2.5) -> Plan:
	var plan := Plan.new()
	var sim := state.copy()
	var side := signf(goal_x)
	var elapsed := 0.0
	var step := 0
	while elapsed < max_time:
		var prev := sim.pos
		BallPhysics.step(sim, BallPhysics.SIM_DT, t)
		elapsed += BallPhysics.SIM_DT
		step += 1
		if side * sim.pos.x >= side * goal_x:
			var k := 0.0
			if absf(sim.pos.x - prev.x) > 0.0001:
				k = (goal_x - prev.x) / (sim.pos.x - prev.x)
			plan.point = prev.lerp(sim.pos, clampf(k, 0.0, 1.0))
			plan.time = elapsed
			plan.path.append(plan.point)
			plan.times.append(elapsed)
			plan.on_target = absf(plan.point.z) < Pitch.GOAL_HALF_WIDTH and plan.point.y < Pitch.GOAL_HEIGHT
			plan.save_point = plan.point
			plan.save_time = plan.time
			return plan
		if step % 2 == 0 and absf(goal_x - sim.pos.x) <= ZONE_DEPTH:
			plan.path.append(sim.pos)
			plan.times.append(elapsed)
		if sim.vel.length() < 0.5:
			break
	plan.time = INF
	return plan


## Evalúa la atajada de un arquero ubicado en `keeper_pos`.
## - reaction / goalkeeping: atributos 1..99.
## - extra_reaction: segundos de más (tiro desviado, visión tapada).
## Tiempo de reacción del arquero ante un remate (s): se queda plantado y
## recién después se mueve.
static func reaction_time(reaction: int, extra_reaction: float = 0.0) -> float:
	return lerpf(0.40, 0.25, PlayerData.unit(reaction)) + extra_reaction


static func evaluate(plan: Plan, keeper_pos: Vector3, reaction: int, goalkeeping: int, extra_reaction: float = 0.0) -> Plan:
	if not plan.on_target:
		plan.chance = 0.0
		return plan
	# Informe técnico: reacción del arquero 0,3-0,4 s ante un tiro repentino;
	# desplazamiento ~6-7 m/s en distancias cortas (la estirada lateral, algo menos).
	var react_time := reaction_time(reaction, extra_reaction)
	var dive_speed := lerpf(4.5, 6.5, PlayerData.unit(goalkeeping))
	var reach := lerpf(0.8, 1.4, PlayerData.unit(goalkeeping))
	var goal_x := plan.point.x
	var best := -INF
	var n := plan.path.size()
	for i in n:
		var pt: Vector3 = plan.path[i]
		# Sólo sirve lo que queda entre el arquero y la línea (lo que ya le
		# pasó por delante no lo puede atajar) y a una altura alcanzable.
		if absf(pt.x - goal_x) > absf(keeper_pos.x - goal_x) + 0.3 and i < n - 1:
			continue
		if pt.y > MAX_REACH_HEIGHT:
			continue
		var margin := _margin_at(pt, plan.times[i], keeper_pos, react_time, dive_speed, reach)
		if margin > best:
			best = margin
			plan.save_point = pt
			plan.save_time = plan.times[i]
	if best == -INF:
		best = -3.0 # le pasó por arriba
	plan.margin = best
	# Con margen justo (0) no es moneda al aire: la estirada al límite suele
	# no llegar limpia.
	plan.chance = clampf(0.45 + plan.margin * 0.7, 0.03, 0.9)
	return plan


static func _margin_at(pt: Vector3, time: float, keeper_pos: Vector3, react_time: float, dive_speed: float, reach: float) -> float:
	var lateral := Vector2(keeper_pos.x - pt.x, keeper_pos.z - pt.z).length()
	var needed := lateral
	# Los ángulos (arriba) y las pelotas rasantes lejos del cuerpo cuestan más.
	if pt.y > 1.9:
		needed += 0.5 + (pt.y - 1.9) * 0.8
	elif pt.y < 0.4 and lateral > 1.0:
		needed += 0.25
	var available := maxf(time - react_time, 0.0) * dive_speed + reach
	return available - needed
