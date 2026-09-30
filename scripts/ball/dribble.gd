class_name Dribble
extends RefCounted
## Conducción con pelota independiente (estilo WE2002): el jugador no "lleva"
## la pelota pegada; le da toques que la hacen rodar libre por delante y la
## vuelve a alcanzar. La distancia de cada toque depende de la velocidad, del
## control del jugador y de la presión rival. Funciones puras y testeables.

## Radio (desde el punto del pie) en el que el conductor puede volver a tocarla.
const TOUCH_REACH := 0.55
## Distancia del pie al centro del jugador, en la dirección en la que mira.
const FOOT_OFFSET := 0.35
## Alcance extendido para un toque de giro (cambio de dirección > TURN_ANGLE).
const TURN_REACH := 1.0
const TURN_ANGLE := deg_to_rad(40.0)
## Tiempo mínimo entre toques.
const TOUCH_COOLDOWN := 0.18
## Por debajo de esta velocidad el jugador "pisa" la pelota en vez de tocarla.
const SHIELD_SPEED := 0.9


## Punto del pie del jugador (donde se controla la pelota).
static func foot_point(player_pos: Vector3, facing: Vector3) -> Vector3:
	return Vector3(player_pos.x, 0.0, player_pos.z) + Vector3(facing.x, 0.0, facing.z).normalized() * FOOT_OFFSET


## Cuánto se adelanta la pelota en un toque.
## - speed_frac: 0 = trotando (o más lento), 1 = sprint a fondo
## - control: atributo ball_control centrado (-1..1)
## - pressure: 0..1 (rival encima = 1): bajo presión se toca más corto.
static func touch_distance(speed_frac: float, control: float, pressure: float, t: Tuning) -> float:
	var d := lerpf(t.dribble_distance, t.dribble_distance_sprint, clampf(speed_frac, 0.0, 1.0))
	# Buen control: toques más cortos. Mal control: la pelota se va más lejos.
	d *= 1.0 - 0.3 * control
	d *= 1.0 - 0.25 * clampf(pressure, 0.0, 1.0)
	return maxf(d, 0.2)


## Velocidad con la que sale la pelota en un toque para quedar `distance`
## metros por delante de un jugador que va a `player_speed` en `dir`.
## Ventaja relativa: v_rel = sqrt(2·a·d) con a = desaceleración al rodar.
static func touch_velocity(player_speed: float, dir: Vector3, distance: float, t: Tuning) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return Vector3.ZERO
	# Desaceleración efectiva = rozamiento + arrastre del aire (≈ k·v²); se
	# itera dos veces porque depende de la velocidad final.
	var rel := sqrt(2.0 * t.rolling_decel * distance)
	for i in 2:
		var v := player_speed + rel
		rel = sqrt(2.0 * (t.rolling_decel + t.air_drag * v * v) * distance)
	return flat.normalized() * (player_speed + rel)


## Presión 0..1 según la distancia al rival más cercano.
static func pressure_from_distance(opponent_distance: float) -> float:
	return clampf(1.0 - (opponent_distance - 1.0) / 4.0, 0.0, 1.0)


## ¿La pelota está "expuesta" (lejos del pie del conductor)? Entre toques un
## rival bien ubicado se la puede quedar: ahí está el timing de la defensa.
static func is_exposed(ball_pos: Vector3, player_pos: Vector3, facing: Vector3) -> bool:
	var foot := foot_point(player_pos, facing)
	return Vector3(ball_pos.x - foot.x, 0.0, ball_pos.z - foot.z).length() > TOUCH_REACH


## Alcance del toque: si el jugador pide un cambio de dirección marcado
## respecto de hacia dónde rueda la pelota, estira la pierna y llega más lejos.
static func reach_for(intent: Vector3, ball_vel: Vector3) -> float:
	var i := Vector3(intent.x, 0.0, intent.z)
	var v := Vector3(ball_vel.x, 0.0, ball_vel.z)
	if i.length_squared() < 0.04 or v.length() < 1.0:
		return TOUCH_REACH
	return TURN_REACH if i.angle_to(v) > TURN_ANGLE else TOUCH_REACH
