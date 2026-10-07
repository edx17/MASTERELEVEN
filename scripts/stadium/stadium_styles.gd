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
##   dirt        tierra en las áreas chicas y el medio (0..1; estadios humildes)
##   oval        lo arma OvalStadiumBuilder (cuenco ovalado de 4 bandejas);
##               flood es fijo: reflectores colgados del techo

const STYLES := [
	{
		"name": "Estadio Virtual",
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
		"dirt": 0.75,
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
	{
		# Coloso ovalado de cuatro bandejas (inventado): butacas grises,
		# anillos LED, anillo VIP, techo traslúcido con pasarela y columnas en V.
		"name": "Coloso del Sur",
		"oval": true,
		# gap: de la línea lateral a la boca del túnel (el muro de la cancha
		# hundida, OvalStadiumBuilder.B0 - 0,2).
		"gap": 10.8, "wall": 5.0,
		# Bancos embutidos en el muro de la cancha hundida (al lado del túnel).
		"bench": 10.6,
		"stands": {"North": [12, 10, 12, 10], "West": [12, 10, 12, 10], "East": [12, 10, 12, 10], "South": [12, 10, 12, 10]},
		"corners": [12, 10, 12, 10],
		"tier_step": [1.4, 2.4],
		"roof": {},
		"seat": Color(0.6, 0.61, 0.64), "tier_colors": [],
		"club_text": false, "track": false, "towers": false,
		"flood": [16.0, 18.0, 44.0, false],
	},
]

## Estadio del partido en curso (lo fija MatchController antes de armar el
## mundo; Atmosphere lo lee para ubicar las luces).
static var current: Dictionary = STYLES[0]


## Altura (m) del borde del techo de una tribuna con `tiers` filas por bandeja
## (las mismas cuentas que StadiumBuilder._stand y _roof).
static func roof_height(style: Dictionary, tiers: Array) -> float:
	var rows := 0
	for t in tiers:
		rows += int(t)
	var step: Array = style["tier_step"]
	var y := rows * StadiumBuilder.ROW_RISE + (tiers.size() - 1) * float(step[1])
	return y + 5.0


## Reflectores de la noche: [posición base por esquina (x, z) desde el centro,
## altura, con mástil]. Con techo, cuelgan debajo del borde, en las esquinas
## (arriba del techo el propio techo los tapa).
static func flood_layout(style: Dictionary) -> Array:
	var f: Array = style["flood"]
	if style.get("oval", false):
		return [Pitch.HALF_LENGTH + float(f[0]), Pitch.HALF_WIDTH + float(f[1]), float(f[2]), false]
	if f[3]:
		return [Pitch.HALF_LENGTH + float(f[0]), Pitch.HALF_WIDTH + float(f[1]), float(f[2]), true]
	var tiers: Array = style["corners"] if not (style["corners"] as Array).is_empty() else style["stands"]["North"]
	var gap: float = style["gap"]
	return [Pitch.HALF_LENGTH + gap * 0.5, Pitch.HALF_WIDTH + gap * 0.5, roof_height(style, tiers) - 3.0, false]


static func names() -> Array:
	var out := []
	for s in STYLES:
		out.append(s["name"])
	return out


static func get_style(i: int) -> Dictionary:
	return STYLES[clampi(i, 0, STYLES.size() - 1)]


## Estadio del partido según el local: con estadio real (clubes de la base)
## y "al azar" (choice < 0), una forma según la capacidad y el nombre real;
## con un estadio elegido en el menú, ése. Sin estadio real, al azar.
static func for_team(team: TeamData, choice: int, rng_pick: int = -1) -> Dictionary:
	if choice >= 0:
		return get_style(choice)
	if team == null or team.stadium == "":
		return get_style(rng_pick if rng_pick >= 0 else randi() % STYLES.size())
	var cap := team.capacity
	var i := 0
	if cap >= 65000:
		i = 4 # cuenco ovalado de cuatro bandejas
	elif cap >= 45000:
		i = 2
	elif cap >= 30000:
		i = 3
	elif cap >= 15000:
		i = 1
	var st := get_style(i).duplicate()
	st["name"] = team.stadium
	return st
