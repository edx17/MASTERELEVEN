class_name Formation
extends RefCounted
## Formación fija 4-4-2 de la Fase 1 (en la Fase 2 se agregan las demás).
## Coordenadas en espacio de equipo: x 0..1 (arco propio -> rival), y -1..1.

const SPOTS_442: Array[Vector2] = [
	Vector2(0.015, 0.0), # 1 ARQ
	Vector2(0.21, -0.68), # 2 LD
	Vector2(0.18, -0.22), # 3 DFC
	Vector2(0.18, 0.22), # 4 DFC
	Vector2(0.21, 0.68), # 5 LI
	Vector2(0.36, -0.7), # 6 MD
	Vector2(0.33, -0.2), # 7 MC
	Vector2(0.33, 0.2), # 8 MC
	Vector2(0.36, 0.7), # 9 MI
	Vector2(0.46, -0.16), # 10 DC
	Vector2(0.45, 0.16), # 11 DC
]

const ROLES_442: Array[int] = [
	Footballer.Role.GK,
	Footballer.Role.DF, Footballer.Role.DF, Footballer.Role.DF, Footballer.Role.DF,
	Footballer.Role.MF, Footballer.Role.MF, Footballer.Role.MF, Footballer.Role.MF,
	Footballer.Role.FW, Footballer.Role.FW,
]

## Posición para el saque del medio: todos en campo propio y fuera del círculo
## si el equipo no saca.
static func kickoff_spot(base: Vector2, kicking: bool) -> Vector2:
	var limit := 0.49 if kicking else 0.40
	return Vector2(minf(base.x, limit), base.y)
