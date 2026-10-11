class_name Pitch
extends RefCounted
## Medidas reglamentarias de la cancha y utilidades geométricas. Dependen de
## la disciplina (Discipline.use): fútbol 105 x 68 m, futsal 40 x 20 m.
## Sistema de coordenadas: X = largo (arcos en ±HALF_LENGTH), Z = ancho
## (laterales en ±HALF_WIDTH), Y = arriba. La cámara de TV mira desde +Z.

static var HALF_LENGTH := 52.5
static var HALF_WIDTH := 34.0
static var GOAL_HALF_WIDTH := 3.66
static var GOAL_HEIGHT := 2.44
static var GOAL_DEPTH := 2.0
static var POST_RADIUS := 0.06
static var PENALTY_AREA_DEPTH := 16.5
static var PENALTY_AREA_HALF_WIDTH := 20.16
static var GOAL_AREA_DEPTH := 5.5
static var GOAL_AREA_HALF_WIDTH := 9.16
static var CENTER_CIRCLE_RADIUS := 9.15
static var PENALTY_SPOT_DISTANCE := 11.0
static var LINE_WIDTH := 0.12
## Futsal: punto del doble penal (desde la línea de fondo; 0 = no hay).
static var SECOND_PENALTY_DISTANCE := 0.0
## Escala de la cancha respecto de la de fútbol (largo): para cámaras y
## distancias pensadas para 105 m.
static var SCALE := 1.0
## Área redondeada del futsal: dos cuartos de círculo (radio = profundidad)
## centrados al costado de los postes, unidos por una recta.
static var ROUNDED_AREA := false
## Distancia de los rivales en una pelota parada (9,15 m; 5 m en futsal).
static var RESTART_DISTANCE := 9.15


## Pone las medidas de una disciplina ({half_length, half_width, ...}).
static func configure(d: Dictionary) -> void:
	HALF_LENGTH = float(d.get("half_length", 52.5))
	HALF_WIDTH = float(d.get("half_width", 34.0))
	GOAL_HALF_WIDTH = float(d.get("goal_half_width", 3.66))
	GOAL_HEIGHT = float(d.get("goal_height", 2.44))
	GOAL_DEPTH = float(d.get("goal_depth", 2.0))
	POST_RADIUS = float(d.get("post_radius", 0.06))
	PENALTY_AREA_DEPTH = float(d.get("penalty_area_depth", 16.5))
	PENALTY_AREA_HALF_WIDTH = float(d.get("penalty_area_half_width", 20.16))
	GOAL_AREA_DEPTH = float(d.get("goal_area_depth", 5.5))
	GOAL_AREA_HALF_WIDTH = float(d.get("goal_area_half_width", 9.16))
	CENTER_CIRCLE_RADIUS = float(d.get("center_circle_radius", 9.15))
	PENALTY_SPOT_DISTANCE = float(d.get("penalty_spot", 11.0))
	LINE_WIDTH = float(d.get("line_width", 0.12))
	SECOND_PENALTY_DISTANCE = float(d.get("second_penalty_spot", 0.0))
	ROUNDED_AREA = bool(d.get("rounded_area", false))
	RESTART_DISTANCE = float(d.get("restart_distance", 9.15))
	SCALE = HALF_LENGTH / 52.5


## Está dentro del área grande del arco ubicado en el lado `side` (+1 / -1).
static func in_penalty_area(pos: Vector3, side: int) -> bool:
	var dx := side * HALF_LENGTH - pos.x
	if dx * side < 0.0 or dx * side > PENALTY_AREA_DEPTH or absf(pos.z) > PENALTY_AREA_HALF_WIDTH:
		return false
	if not ROUNDED_AREA:
		return true
	var straight := PENALTY_AREA_HALF_WIDTH - PENALTY_AREA_DEPTH
	if absf(pos.z) <= straight:
		return true
	return Vector2(dx, absf(pos.z) - straight).length() <= PENALTY_AREA_DEPTH


## Punto central del arco del lado `side`.
static func goal_center(side: int) -> Vector3:
	return Vector3(side * HALF_LENGTH, 0.0, 0.0)


static func clamp_to_field(pos: Vector3, margin: float = 0.0) -> Vector3:
	return Vector3(
		clampf(pos.x, -HALF_LENGTH + margin, HALF_LENGTH - margin),
		pos.y,
		clampf(pos.z, -HALF_WIDTH + margin, HALF_WIDTH - margin))
