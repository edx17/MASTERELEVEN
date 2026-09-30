class_name Team
extends RefCounted
## Equipo dentro de un partido: identidad visual, dirección de ataque, jugadores
## y conversión entre "espacio de equipo" (formación) y coordenadas del mundo.

var index: int = 0
var data: TeamData
## Formación en uso (puede cambiarse en el partido).
var formation: FormationData
var team_name: String = ""
var short_name: String = ""
var color: Color = Color.WHITE
var secondary_color: Color = Color.BLACK
var keeper_color: Color = Color.YELLOW
## +1 ataca hacia +X, -1 hacia -X. Se invierte en el entretiempo.
var attack_dir: int = 1
var players: Array[Footballer] = []
var score: int = 0


func _init(p_index: int, p_name: String, p_short: String, p_color: Color, p_secondary: Color, p_keeper: Color) -> void:
	index = p_index
	team_name = p_name
	short_name = p_short
	color = p_color
	secondary_color = p_secondary
	keeper_color = p_keeper


func keeper() -> Footballer:
	for p in players:
		if p.is_keeper():
			return p
	return null


## Lado (+1/-1) del arco propio.
func own_side() -> int:
	return -attack_dir


func own_goal() -> Vector3:
	return Pitch.goal_center(own_side())


func target_goal() -> Vector3:
	return Pitch.goal_center(attack_dir)


## Convierte espacio de equipo (x 0..1 desde el arco propio, y -1..1) a mundo.
func to_world(spot: Vector2) -> Vector3:
	var x := attack_dir * Pitch.HALF_LENGTH * (2.0 * spot.x - 1.0)
	# y < 0 = lado derecho mirando hacia el arco rival.
	var z := -attack_dir * spot.y * Pitch.HALF_WIDTH
	return Vector3(x, 0.0, z)


## Fracción 0..1 de una posición del mundo medida desde el arco propio.
func progress_of(pos: Vector3) -> float:
	return clampf((attack_dir * pos.x / Pitch.HALF_LENGTH + 1.0) * 0.5, 0.0, 1.0)


## Posición lateral -1..1 en espacio de equipo (inversa de to_world en Z).
func lateral_of(pos: Vector3) -> float:
	return clampf(-attack_dir * pos.z / Pitch.HALF_WIDTH, -1.0, 1.0)
