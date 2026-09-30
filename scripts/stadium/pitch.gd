class_name Pitch
extends RefCounted
## Medidas reglamentarias de la cancha (FIFA: 105 x 68 m) y utilidades geométricas.
## Sistema de coordenadas: X = largo (arcos en ±HALF_LENGTH), Z = ancho
## (laterales en ±HALF_WIDTH), Y = arriba. La cámara de TV mira desde +Z.

const HALF_LENGTH := 52.5
const HALF_WIDTH := 34.0
const GOAL_HALF_WIDTH := 3.66
const GOAL_HEIGHT := 2.44
const GOAL_DEPTH := 2.0
const POST_RADIUS := 0.06
const PENALTY_AREA_DEPTH := 16.5
const PENALTY_AREA_HALF_WIDTH := 20.16
const GOAL_AREA_DEPTH := 5.5
const GOAL_AREA_HALF_WIDTH := 9.16
const CENTER_CIRCLE_RADIUS := 9.15
const PENALTY_SPOT_DISTANCE := 11.0
const LINE_WIDTH := 0.12


## Está dentro del área grande del arco ubicado en el lado `side` (+1 / -1).
static func in_penalty_area(pos: Vector3, side: int) -> bool:
	var dx := side * HALF_LENGTH - pos.x
	return dx * side >= 0.0 and dx * side <= PENALTY_AREA_DEPTH and absf(pos.z) <= PENALTY_AREA_HALF_WIDTH


## Punto central del arco del lado `side`.
static func goal_center(side: int) -> Vector3:
	return Vector3(side * HALF_LENGTH, 0.0, 0.0)


static func clamp_to_field(pos: Vector3, margin: float = 0.0) -> Vector3:
	return Vector3(
		clampf(pos.x, -HALF_LENGTH + margin, HALF_LENGTH - margin),
		pos.y,
		clampf(pos.z, -HALF_WIDTH + margin, HALF_WIDTH - margin))
