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
## Bandera (selecciones; null = una de club con sus colores).
@export var flag: Texture2D = null
## País (id de la base: "arg", "eng"...; "" = ficticio), estadio y capacidad.
@export var country: String = ""
@export var stadium: String = ""
@export var capacity: int = 0
## Plantillas de camiseta (editor de camisetas; null = el diseño por código).
var kit_textures: Array = [null, null]
## Escudo propio (PNG importado en el Editor) o null: se dibuja el generado.
var crest: Texture2D = null
## Medias de cada uniforme (alfa 0 = del color de la camiseta).
@export var socks_color: Color = Color(0, 0, 0, 0)
@export var away_socks: Color = Color(0, 0, 0, 0)
## Segundo uniforme (camiseta y pantalón).
@export var away_color: Color = Color.WHITE
@export var away_secondary: Color = Color.WHITE
## Diseño de cada camiseta (0 lisa, 1 rayas verticales, 2 rayas finitas,
## 3 aros, 4 mitades, 5 banda diagonal, 6 franja en el pecho, 7 V en el
## pecho, 8 cuadros) y su segundo color.
@export var pattern: int = 0
@export var pattern_color: Color = Color.BLACK
@export var away_pattern: int = 0
@export var away_pattern_color: Color = Color.BLACK
@export var formation: FormationData
@export var players: Array[PlayerData] = []


## Uniforme 0 (titular) o 1 (alternativo): [camiseta, pantalón].
func kit(i: int) -> Array[Color]:
	if i == 1:
		return [away_color, away_secondary]
	return [color, secondary_color]


func kit_texture(i: int) -> Texture2D:
	return kit_textures[clampi(i, 0, 1)]


## Medias del uniforme 0 o 1 (alfa 0 = como la camiseta).
func kit_socks(i: int) -> Color:
	return away_socks if i == 1 else socks_color


## Diseño del uniforme 0 o 1: [diseño, segundo color].
func kit_pattern(i: int) -> Array:
	if i == 1:
		return [away_pattern, away_pattern_color]
	return [pattern, pattern_color]


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
