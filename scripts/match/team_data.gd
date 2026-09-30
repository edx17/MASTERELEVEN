class_name TeamData
extends Resource
## Datos de un club o selección (ficticio). Los 11 primeros de `players` son
## los titulares, en el orden de los slots de la formación.

@export var id: String = ""
@export var team_name: String = ""
## Abreviatura de 3 letras para el marcador.
@export var short_name: String = ""
@export var color: Color = Color.WHITE
@export var secondary_color: Color = Color.BLACK
@export var keeper_color: Color = Color.YELLOW
@export var formation: FormationData
@export var players: Array[PlayerData] = []


func starters() -> Array[PlayerData]:
	var out: Array[PlayerData] = []
	for i in mini(11, players.size()):
		out.append(players[i])
	return out
