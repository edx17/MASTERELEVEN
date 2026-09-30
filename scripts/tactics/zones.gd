class_name Zones
extends RefCounted
## Zonas del campo en espacio de equipo: 3 tercios (defensivo, medio, ataque)
## x 5 carriles (derecha, centro-derecha, centro, centro-izquierda, izquierda).

enum Third { DEFENSIVE, MIDDLE, ATTACKING }
enum Lane { RIGHT, RIGHT_CENTER, CENTER, LEFT_CENTER, LEFT }

const THIRD_NAMES := ["defensivo", "medio", "ataque"]
const LANE_NAMES := ["derecha", "centro-der", "centro", "centro-izq", "izquierda"]


static func third(x: float) -> int:
	if x < 1.0 / 3.0:
		return Third.DEFENSIVE
	if x < 2.0 / 3.0:
		return Third.MIDDLE
	return Third.ATTACKING


static func lane(y: float) -> int:
	return clampi(int(floor((clampf(y, -1.0, 0.9999) + 1.0) * 2.5)), 0, 4)


## Centro de una zona (espacio de equipo).
static func center(t: int, l: int) -> Vector2:
	return Vector2((t + 0.5) / 3.0, -1.0 + (l + 0.5) * 0.4)


static func describe(p: Vector2) -> String:
	return "%s / %s" % [THIRD_NAMES[third(p.x)], LANE_NAMES[lane(p.y)]]
