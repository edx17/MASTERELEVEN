class_name SaveModel
extends RefCounted
## Modelo de atajada (puro y testeable). Cuando sale un remate se predice dónde
## y cuándo cruza la línea; el arquero llega si su tiempo de reacción más lo que
## puede desplazarse/estirarse alcanza para cubrir esa distancia. La potencia
## importa (menos tiempo), la colocación importa (más distancia) y los
## atributos del arquero importan. No es perfecto: hay un margen aleatorio.

class Plan:
	## El remate va al arco (entre los palos y bajo el travesaño).
	var on_target: bool = false
	## Punto de cruce de la línea (x en la línea, y altura, z lateral).
	var point: Vector3 = Vector3.ZERO
	## Segundos hasta cruzar la línea.
	var time: float = 0.0
	## Margen (m): lo que el arquero alcanza menos lo que necesita.
	var margin: float = 0.0
	## Probabilidad de atajarla.
	var chance: float = 0.0


## Predice el cruce de la línea de gol `goal_x` (simulando la física real).
static func predict_crossing(state: BallState, goal_x: float, t: Tuning, max_time: float = 2.5) -> Plan:
	var plan := Plan.new()
	var sim := state.copy()
	var side := signf(goal_x)
	var elapsed := 0.0
	while elapsed < max_time:
		var prev := sim.pos
		BallPhysics.step(sim, BallPhysics.SIM_DT, t)
		elapsed += BallPhysics.SIM_DT
		if side * sim.pos.x >= side * goal_x:
			var k := 0.0
			if absf(sim.pos.x - prev.x) > 0.0001:
				k = (goal_x - prev.x) / (sim.pos.x - prev.x)
			plan.point = prev.lerp(sim.pos, clampf(k, 0.0, 1.0))
			plan.time = elapsed
			plan.on_target = absf(plan.point.z) < Pitch.GOAL_HALF_WIDTH and plan.point.y < Pitch.GOAL_HEIGHT
			return plan
		if sim.vel.length() < 0.5:
			break
	plan.time = INF
	return plan


## Evalúa la atajada de un arquero ubicado en `keeper_pos`.
## - reaction / goalkeeping: atributos 1..99.
static func evaluate(plan: Plan, keeper_pos: Vector3, reaction: int, goalkeeping: int) -> Plan:
	if not plan.on_target:
		plan.chance = 0.0
		return plan
	var react_time := lerpf(0.38, 0.18, PlayerData.unit(reaction))
	var dive_speed := lerpf(4.0, 6.0, PlayerData.unit(goalkeeping))
	var reach := lerpf(0.9, 1.5, PlayerData.unit(goalkeeping))
	var lateral := Vector2(keeper_pos.x - plan.point.x, keeper_pos.z - plan.point.z).length()
	var needed := lateral
	# Los ángulos (arriba) y las pelotas rasantes lejos del cuerpo cuestan más.
	if plan.point.y > 1.9:
		needed += 0.5
	elif plan.point.y < 0.4 and lateral > 1.0:
		needed += 0.25
	var available := maxf(plan.time - react_time, 0.0) * dive_speed + reach
	plan.margin = available - needed
	plan.chance = clampf(0.5 + plan.margin * 0.7, 0.03, 0.92)
	return plan
