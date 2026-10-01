class_name StadiumStyles
extends RefCounted
## Estadios disponibles, como datos (los arma StadiumBuilder). Todos ficticios:
## sólo toman ideas de arquitectura de estadios conocidos, sin nombres, escudos
## ni marcas reales.
##
## Campos:
##   name        nombre que se muestra
##   gap         distancia (m) de la línea al primer escalón de las tribunas
##   wall        distancia (m) de la línea al muro perimetral
##   stands      {"North"/"South"/"West"/"East": [filas por bandeja]}
##   corners     filas por bandeja de las esquinas (vacío = esquinas abiertas)
##   tier_step   [voladizo hacia atrás, subida] (m) entre bandejas
##   roof        {tribuna: "beams" | "cantilever" | "truss" | "none"}
##   seat        null = color del club local; o un Color fijo
##   tier_colors colores de butacas por bandeja (pisa `seat`)
##   club_text   el nombre del local escrito con butacas en la tribuna norte
##   track       pista de atletismo entre la cancha y las tribunas
##   towers      torres cilíndricas con rampas en espiral por fuera
##   flood       [x desde la línea de fondo, z desde la lateral, altura, mástil]

const STYLES := [
	{
		"name": "Estadio Master",
		"gap": 7.0, "wall": 5.0,
		"stands": {"North": [26, 20], "West": [22, 16], "East": [22, 16], "South": [18]},
		"corners": [],
		"tier_step": [2.5, 3.2],
		"roof": {"North": "beams", "West": "beams", "East": "beams", "South": "beams"},
		"seat": null, "tier_colors": [],
		"club_text": true, "track": false, "towers": false,
		"flood": [22.0, 30.0, 46.0, true],
	},
	{
		# Estilo inglés: tribunas pegadas a la cancha, esquinas cerradas, todo
		# techado con un voladizo liviano y butacas rojas.
		"name": "Northbridge Park",
		"gap": 6.0, "wall": 5.0,
		"stands": {"North": [22, 16, 12], "West": [20, 16], "East": [20, 16], "South": [20, 14]},
		"corners": [20, 16],
		"tier_step": [2.0, 3.0],
		"roof": {"North": "cantilever", "West": "cantilever", "East": "cantilever", "South": "cantilever", "Corner": "cantilever"},
		"seat": Color(0.58, 0.05, 0.07), "tier_colors": [],
		"club_text": true, "track": false, "towers": false,
		"flood": [6.0, 8.0, 34.0, false],
	},
	{
		# Herradura rioplatense: pista alrededor de la cancha, dos bandejas
		# (la baja blanca y la alta roja), casi sin techo.
		"name": "Gran Coliseo del Plata",
		"gap": 13.0, "wall": 11.5,
		"stands": {"North": [18, 22], "West": [16, 22], "East": [16, 22], "South": [16, 20]},
		"corners": [16, 22],
		"tier_step": [1.5, 2.4],
		"roof": {"North": "beams", "West": "none", "East": "none", "South": "none", "Corner": "none"},
		"seat": null, "tier_colors": [Color(0.86, 0.86, 0.86), Color(0.66, 0.08, 0.1)],
		"club_text": false, "track": true, "towers": false,
		"flood": [48.0, 46.0, 58.0, true],
	},
	{
		# Tres bandejas empinadas, techo sostenido por vigas rojas y torres
		# cilíndricas con rampas en espiral alrededor.
		"name": "Stadio delle Torri",
		"gap": 7.0, "wall": 5.0,
		"stands": {"North": [16, 14, 12], "West": [16, 14, 12], "East": [16, 14, 12], "South": [16, 14, 12]},
		"corners": [16, 14, 12],
		"tier_step": [1.2, 4.0],
		"roof": {"North": "truss", "West": "truss", "East": "truss", "South": "truss", "Corner": "truss"},
		"seat": null, "tier_colors": [],
		"club_text": true, "track": false, "towers": true,
		"flood": [8.0, 10.0, 44.0, false],
	},
]

## Estadio del partido en curso (lo fija MatchController antes de armar el
## mundo; Atmosphere lo lee para ubicar las luces).
static var current: Dictionary = STYLES[0]


static func names() -> Array:
	var out := []
	for s in STYLES:
		out.append(s["name"])
	return out


static func get_style(i: int) -> Dictionary:
	return STYLES[clampi(i, 0, STYLES.size() - 1)]
