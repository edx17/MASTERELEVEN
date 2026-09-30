class_name Dribble
extends RefCounted
## Conducción guiada (estilo WE2002): la pelota se mueve con su propia física,
## pero mientras un jugador la conduce, un "resorte" la mantiene dentro de una
## distancia ideal delante del pie. Esa distancia late con los toques (sale un
## poco y vuelve) y depende de la velocidad, del control del jugador y de la
## presión rival. La pelota no queda pegada, pero tampoco se escapa sola: se
## pierde por una entrada, una barrida o un rival que la toca cuando queda
## expuesta. Funciones puras y testeables.

## Distancia del pie al centro del jugador, en la dirección en la que mira.
const FOOT_OFFSET := 0.35
## Por debajo de esta velocidad el jugador la pisa / la protege.
const SHIELD_SPEED := 1.2
## Más allá de esta distancia al pie, la pelota está expuesta a un rival.
const EXPOSED_DISTANCE := 0.7


## Punto del pie del jugador (donde se controla la pelota).
static func foot_point(player_pos: Vector3, facing: Vector3) -> Vector3:
	return Vector3(player_pos.x, 0.0, player_pos.z) + Vector3(facing.x, 0.0, facing.z).normalized() * FOOT_OFFSET


## Distancia máxima que se adelanta la pelota en cada toque.
## - speed_frac: 0 = trotando (o más lento), 1 = sprint a fondo
## - control: atributo ball_control centrado (-1..1)
## - pressure: 0..1 (rival encima = 1): bajo presión se toca más corto.
static func touch_distance(speed_frac: float, control: float, pressure: float, t: Tuning) -> float:
	var d := lerpf(t.dribble_distance, t.dribble_distance_sprint, clampf(speed_frac, 0.0, 1.0))
	# Buen control: toques más cortos. Mal control: la pelota se va más lejos.
	d *= 1.0 - 0.25 * control
	d *= 1.0 - 0.2 * clampf(pressure, 0.0, 1.0)
	return maxf(d, 0.15)


## Duración de un ciclo de toque (s): más largo en sprint.
static func touch_period(speed_frac: float) -> float:
	return lerpf(0.42, 0.62, clampf(speed_frac, 0.0, 1.0))


## Distancia pie-pelota a lo largo de un ciclo de toque: tras el toque la
## pelota sale hasta `max_distance` y el jugador la vuelve a alcanzar.
## `phase` va de 0 a 1 dentro del ciclo.
static func pulse(phase: float, max_distance: float) -> float:
	var s := 0.5 - 0.5 * cos(TAU * phase)
	return max_distance * (0.35 + 0.65 * s)


## Punto objetivo de la pelota mientras se conduce.
## Con un rival encima y yendo lento, el jugador la cubre con el cuerpo:
## la pelota va al lado opuesto al rival.
static func dribble_target(player_pos: Vector3, facing: Vector3, distance: float, shield_from: Vector3,
		shielding: bool) -> Vector3:
	var base := Vector3(player_pos.x, 0.0, player_pos.z)
	if shielding:
		var away := base - Vector3(shield_from.x, 0.0, shield_from.z)
		if away.length_squared() > 0.0001:
			return base + away.normalized() * 0.55
	return foot_point(player_pos, facing) + Vector3(facing.x, 0.0, facing.z).normalized() * distance


## Rigidez del resorte según el control (mejor control = sigue más rápido).
static func spring_rate(control_unit: float) -> float:
	return lerpf(7.0, 13.0, clampf(control_unit, 0.0, 1.0))


## Presión 0..1 según la distancia al rival más cercano.
static func pressure_from_distance(opponent_distance: float) -> float:
	return clampf(1.0 - (opponent_distance - 1.0) / 4.0, 0.0, 1.0)


## ¿La pelota está "expuesta" (lejos del pie del conductor)? Entre toques un
## rival bien ubicado se la puede quedar: ahí está el timing de la defensa.
static func is_exposed(ball_pos: Vector3, player_pos: Vector3, facing: Vector3) -> bool:
	var foot := foot_point(player_pos, facing)
	return Vector3(ball_pos.x - foot.x, 0.0, ball_pos.z - foot.z).length() > EXPOSED_DISTANCE
