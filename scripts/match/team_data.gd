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
## Segundo uniforme (camiseta y pantalón).
@export var away_color: Color = Color.WHITE
@export var away_secondary: Color = Color.WHITE
@export var formation: FormationData
@export var players: Array[PlayerData] = []


## Uniforme 0 (titular) o 1 (alternativo): [camiseta, pantalón].
func kit(i: int) -> Array[Color]:
	if i == 1:
		return [away_color, away_secondary]
	return [color, secondary_color]


## Promedios del plantel titular para las barras de la elección de equipo
## (0..1): ataque, defensa, fuerza, velocidad y técnica.
func ratings() -> Array[float]:
	var sums := [0.0, 0.0, 0.0, 0.0, 0.0]
	var xi := starters()
	for p in xi:
		sums[0] += (p.shooting + p.ball_control) * 0.5
		sums[1] += p.defense if p.position != PlayerData.Position.GK else p.goalkeeping
		sums[2] += (p.strength + p.balance) * 0.5
		sums[3] += (p.speed + p.acceleration) * 0.5
		sums[4] += (p.technique + p.passing) * 0.5
	var out: Array[float] = []
	for v in sums:
		out.append(clampf((v / maxf(xi.size(), 1) - 40.0) / 50.0, 0.05, 1.0))
	return out


func starters() -> Array[PlayerData]:
	var out: Array[PlayerData] = []
	for i in mini(11, players.size()):
		out.append(players[i])
	return out
