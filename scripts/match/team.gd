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
## Diseño de la camiseta que se usa en este partido y su segundo color.
var pattern: int = 0
var pattern_color: Color = Color.BLACK
## Plantilla de camiseta (editor) o null.
var kit_texture: Texture2D = null
## Medias (alfa 0 = del color de la camiseta).
var socks_color: Color = Color(0, 0, 0, 0)
## +1 ataca hacia +X, -1 hacia -X. Se invierte en el entretiempo.
var attack_dir: int = 1
## Los que están en la cancha (los expulsados salen de esta lista).
var players: Array[Footballer] = []
## Plantel completo del partido, en el orden de la formación (el puesto de
## cada uno no cambia aunque haya expulsados).
var roster: Array[Footballer] = []
var sent_off: Array[Footballer] = []
## Cambios: hasta MAX_SUBS por partido, de los suplentes del banco.
const MAX_SUBS := 3
var bench: Array[PlayerData] = []
## Los que salieron reemplazados (no vuelven a entrar).
var subbed_off: Array[Footballer] = []
var subs_used: int = 0
## Cambios pedidos que se hacen en la próxima pelota parada: [{out, in}].
var pending_subs: Array[Dictionary] = []
## Condición del día de cada jugador del plantel (PlayerData -> Condition).
var conditions := {}
## Capitán y pateadores elegidos en la Dirección del equipo (null = automático).
var captain: PlayerData = null
## Tiro libre corto (cerca del área) y largo (de lejos; si no hay, el corto).
var fk_taker: PlayerData = null
var fk_long_taker: PlayerData = null
## Córner desde la izquierda y desde la derecha (mirando al arco rival; si no
## hay de la derecha, el de la izquierda).
var ck_taker: PlayerData = null
var ck_right_taker: PlayerData = null
var pk_taker: PlayerData = null
## Estrategias asignadas a los cuatro botones y la que está activa.
var strategy_slots: Array[int] = Strategy.DEFAULT_SLOTS.duplicate()
var strategy: int = Strategy.Kind.NONE
## Mentalidad (L2 + cruceta izquierda / derecha): -1 defensiva (atacan
## menos), 0 equilibrada, +1 ofensiva (suben más jugadores al ataque).
var mentality: int = 0
const MENTALITY_NAMES := ["Defensiva", "Equilibrada", "Ofensiva"]
var score: int = 0


func _init(p_index: int, p_name: String, p_short: String, p_color: Color, p_secondary: Color, p_keeper: Color) -> void:
	index = p_index
	team_name = p_name
	short_name = p_short
	color = p_color
	secondary_color = p_secondary
	keeper_color = p_keeper


## Puesto del jugador en la formación (índice del plantel).
func slot_of(p: Footballer) -> int:
	return roster.find(p)


func condition_of(d: PlayerData) -> int:
	return conditions.get(d, PlayerData.Condition.NORMAL)


## El que está en la cancha con esos datos (o null).
## Jugador de campo en la cancha con la etiqueta `tag` (el de mejor ficha
## para eso si hay varios), o null.
func tagged(tag: String) -> Footballer:
	var best: Footballer = null
	var best_v := -1
	for p in players:
		if p.is_keeper() or p.data == null or not p.data.has_ability(tag):
			continue
		var v := p.data.curve + p.data.shooting + p.data.technique
		if v > best_v:
			best_v = v
			best = p
	return best


## Capitán: el elegido, o el que tiene la cinta en la ficha.
func captain_data() -> PlayerData:
	if captain != null:
		return captain
	for p in players:
		if p.base_data != null and p.base_data.has_ability("capitan"):
			return p.base_data
	return null


func on_pitch(d: PlayerData) -> Footballer:
	if d == null:
		return null
	for p in players:
		if p.base_data == d:
			return p
	return null


func subs_left() -> int:
	return MAX_SUBS - subs_used - pending_subs.size()


## Suplente arquero en el banco (o null).
func bench_keeper() -> PlayerData:
	for d in bench:
		if d.position == PlayerData.Position.GK:
			return d
	return null


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
