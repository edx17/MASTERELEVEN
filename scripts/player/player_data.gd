class_name PlayerData
extends Resource
## Datos de un jugador (ficticio). Los atributos van de 1 a 99; 50 es un
## jugador promedio. La lógica del partido lee estos valores, nunca nombres
## ni números hardcodeados.

enum Position { GK, DF, MF, FW }
## BOTH = ambidiestro (sin pierna mala).
enum Foot { RIGHT, LEFT, BOTH }
## Físico (sólo presentación). AUTO = según los atributos.
enum Build { AUTO = -1, NORMAL, HEAVY, SLIM, TALL, SHORT, STOCKY, MUSCULAR }

@export var id: String = ""
## Número único del jugador dentro de una Liga Master (0 = fuera de una
## carrera): sigue al jugador aunque cambie de club u orden en el plantel.
@export var pid: int = 0
@export var player_name: String = ""
@export var number: int = 1
@export var position: Position = Position.MF
@export var foot: Foot = Foot.RIGHT
@export_group("Aspecto")
@export var build: Build = Build.AUTO
## Peinado (HairBuilder.Style); -1 = al azar.
@export var hair: int = -1
## Edad (0 = se calcula de forma estable a partir del nombre).
@export var age: int = 0
## Altura en cm (0 = según el físico).
@export var height: int = 0
## Tono de piel A-D (0 clara, 1 trigueña, 2 oscura, 3 muy oscura); -1 = auto.
@export_range(-1, 3) var skin: int = -1
## Color de pelo (HAIR_COLORS); -1 = auto.
@export_range(-1, 6) var hair_color: int = -1
## Barba / bigote (FACIAL_HAIR) y su color (-1 = el del pelo); -1 = auto.
@export_range(-1, 4) var facial_hair: int = -1
@export_range(-1, 6) var facial_hair_color: int = -1
## Botines tipo A-H (BOOT_COLORS); -1 = auto.
@export_range(-1, 7) var boots: int = -1

@export_group("Identidad")
## País (nombre, p. ej. "Argentina"); para la bandera y las selecciones.
@export var nationality: String = ""
## Puesto detallado como en el WE (GK, CB, LB, RB, DMF, CMF, LMF, RMF, AMF,
## SS, LWF, RWF, CF); "" = según el puesto general y la formación.
@export var role_code: String = ""
## Otros puestos en los que puede jugar.
@export var alt_roles: PackedStringArray = []

@export_group("Atributos")
@export_range(1, 99) var speed: int = 60
@export_range(1, 99) var acceleration: int = 60
@export_range(1, 99) var stamina: int = 60
@export_range(1, 99) var strength: int = 60
@export_range(1, 99) var passing: int = 60
@export_range(1, 99) var shooting: int = 60
@export_range(1, 99) var technique: int = 60
@export_range(1, 99) var ball_control: int = 60
@export_range(1, 99) var heading: int = 60
@export_range(1, 99) var defense: int = 60
@export_range(1, 99) var reaction: int = 60
@export_range(1, 99) var balance: int = 60
@export_range(1, 99) var goalkeeping: int = 20
## Ficha ampliada (0 = se deriva de los otros atributos; ver fill_extended()).
@export_range(0, 99) var attack: int = 0
@export_range(0, 99) var jump: int = 0
@export_range(0, 99) var shot_power: int = 0
@export_range(0, 99) var curve: int = 0

@export_group("Habilidades especiales")
## Ids de ABILITY_NAMES (como las estrellitas del WE).
@export var abilities: PackedStringArray = []
## Festejo de gol preferido (índice de Celebrations.LIST; -1 = al azar).
@export var celebration: int = -1


## Atributo normalizado a -1..1 alrededor del promedio (50).
static func centered(value: int) -> float:
	return clampf((value - 50) / 49.0, -1.0, 1.0)


## Atributo normalizado a 0..1.
static func unit(value: int) -> float:
	return clampf((value - 1) / 98.0, 0.0, 1.0)


## Altura relativa de cada físico (1 = normal, ~1,80 m) y agilidad para girar
## (los bajos y flacos giran más cerrado; los altos y pesados, más abierto).
const BUILD_HEIGHT := {Build.NORMAL: 1.0, Build.HEAVY: 0.99, Build.SLIM: 1.02, Build.TALL: 1.08,
	Build.SHORT: 0.91, Build.STOCKY: 0.95, Build.MUSCULAR: 1.0}
const BUILD_AGILITY := {Build.NORMAL: 1.0, Build.HEAVY: 0.9, Build.SLIM: 1.08, Build.TALL: 0.92,
	Build.SHORT: 1.15, Build.STOCKY: 0.95, Build.MUSCULAR: 1.0}


## Altura relativa (1 = 1,78 m): la estatura en cm manda (también en el
## juego: cabezazos y cuerpo a cuerpo).
func body_height() -> float:
	return height_cm() / 178.0


# --- Aspecto guardado (B4): piel, pelo, barba y botines ----------------------

const SKIN_COLORS: Array[Color] = [Color(0.96, 0.8, 0.66), Color(0.84, 0.64, 0.47), Color(0.55, 0.37, 0.25),
	Color(0.36, 0.24, 0.16)]
const SKIN_NAMES := ["A (clara)", "B (trigueña)", "C (oscura)", "D (muy oscura)"]
const HAIR_COLORS: Array[Color] = [Color(0.06, 0.05, 0.04), Color(0.2, 0.12, 0.06), Color(0.42, 0.27, 0.13),
	Color(0.82, 0.66, 0.34), Color(0.62, 0.26, 0.1), Color(0.62, 0.62, 0.6), Color(0.85, 0.85, 0.82)]
const HAIR_COLOR_NAMES := ["negro", "castaño oscuro", "castaño claro", "rubio", "pelirrojo", "canoso", "teñido"]
const FACIAL_HAIR_NAMES := ["nada", "de tres días", "bigote", "candado", "barba"]
const BOOT_COLORS: Array[Color] = [Color(0.05, 0.05, 0.06), Color(0.92, 0.92, 0.9), Color(0.7, 0.72, 0.76),
	Color(0.15, 0.35, 0.85), Color(0.85, 0.12, 0.1), Color(0.85, 0.65, 0.15), Color(0.95, 0.45, 0.1),
	Color(0.2, 0.7, 0.3)]
const BOOT_NAMES := ["A negros", "B blancos", "C plateados", "D azules", "E rojos", "F dorados", "G naranjas", "H verdes"]


## Azar estable por jugador (0..1) para lo que no está cargado.
func _r(k: String) -> float:
	return float(hash(id + player_name + k) % 10000) / 10000.0


static func _pick(r: float, weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var acc := 0.0
	for i in weights.size():
		acc += float(weights[i]) / total
		if r < acc:
			return i
	return weights.size() - 1


func skin_tone() -> int:
	return skin if skin >= 0 else _pick(_r("skin"), [40, 30, 18, 12])


func hair_color_index() -> int:
	if hair_color >= 0:
		return hair_color
	# Más oscuro en pieles oscuras; canoso sólo en los veteranos.
	var w := [35, 30, 15, 12, 4, 0, 1] if skin_tone() <= 1 else [80, 15, 3, 0, 0, 0, 2]
	if get_age() >= 33:
		w[5] = 15
	return _pick(_r("hc"), w)


func facial_hair_index() -> int:
	return facial_hair if facial_hair >= 0 else _pick(_r("fh"), [58, 18, 5, 9, 10])


func facial_hair_color_index() -> int:
	return facial_hair_color if facial_hair_color >= 0 else hair_color_index()


## Botines: la mayoría negros o blancos; algunos de color.
func boots_index() -> int:
	return boots if boots >= 0 else _pick(_r("bt"), [45, 25, 6, 7, 6, 4, 4, 3])


func foot_name() -> String:
	return ["Diestro", "Zurdo", "Ambidiestro"][clampi(foot, 0, 2)]


## Aspecto para los visuales (lo lee ModelVisual / PlayerVisual).
func look() -> Dictionary:
	return {"skin_color": SKIN_COLORS[skin_tone()], "hair_color": HAIR_COLORS[hair_color_index()],
		"facial_hair": facial_hair_index(), "beard_color": HAIR_COLORS[facial_hair_color_index()],
		"boots": BOOT_COLORS[boots_index()]}


## Letra del físico como en el WE (ficha y editor).
const BUILD_LETTERS := {Build.SLIM: "A", Build.NORMAL: "B", Build.MUSCULAR: "C", Build.STOCKY: "D",
	Build.HEAVY: "E", Build.SHORT: "F", Build.TALL: "G"}
const BUILD_NAMES := {Build.SLIM: "delgado", Build.NORMAL: "estándar", Build.MUSCULAR: "musculoso",
	Build.STOCKY: "robusto", Build.HEAVY: "corpulento", Build.SHORT: "bajo", Build.TALL: "alto"}


func physique_letter() -> String:
	return BUILD_LETTERS.get(visual_build(), "B")


## Base del cuerpo por físico: [masa (-1 flaco .. 1 pesado), músculo (0..1),
## hombros (-1..1), piernas (-1 cortas .. 1 largas)].
const BODY_BASE := {Build.SLIM: [-0.6, 0.2, -0.4, 0.2], Build.NORMAL: [0.0, 0.35, 0.0, 0.0],
	Build.MUSCULAR: [0.1, 0.9, 0.5, 0.0], Build.STOCKY: [0.5, 0.6, 0.3, -0.3],
	Build.HEAVY: [0.9, 0.3, 0.2, -0.2], Build.SHORT: [0.0, 0.35, -0.1, -0.4],
	Build.TALL: [-0.1, 0.35, 0.1, 0.5]}


## Cuerpo paramétrico (ModelVisual.set_body): el físico da la base y los
## atributos y una variación propia de cada jugador lo terminan, así dos
## jugadores del mismo físico no son idénticos.
func body_params() -> Dictionary:
	var base: Array = BODY_BASE.get(visual_build(), BODY_BASE[Build.NORMAL])
	var seed_str := id + player_name
	var j := func(k: String) -> float: return float(hash(seed_str + k) % 1000) / 500.0 - 1.0
	return {
		"height": height_cm(),
		"mass": clampf(float(base[0]) + 0.15 * centered(balance) + 0.12 * j.call("m"), -1.0, 1.0),
		"muscle": clampf(float(base[1]) + 0.25 * centered(strength) + 0.1 * j.call("u"), 0.0, 1.0),
		"shoulders": clampf(float(base[2]) + 0.15 * j.call("s"), -1.0, 1.0),
		"legs": clampf(float(base[3]) + 0.25 * j.call("l"), -1.0, 1.0),
	}


func agility() -> float:
	return BUILD_AGILITY.get(visual_build(), 1.0)


## Físico a mostrar: el elegido, o uno coherente con los atributos (con algo
## de azar estable por jugador, para que haya de todo en cada equipo).
func visual_build() -> Build:
	if build != Build.AUTO:
		return build
	var r := float(hash(id + player_name) % 1000) / 1000.0
	if position == Position.GK or heading >= 75:
		return Build.TALL if r < 0.7 else Build.STOCKY
	if strength >= 72:
		return Build.MUSCULAR if r < 0.5 else Build.STOCKY
	if speed >= 75 and strength < 60:
		return Build.SLIM if r < 0.6 else Build.SHORT
	if technique >= 75 and strength < 55:
		return Build.SHORT if r < 0.5 else Build.SLIM
	if stamina < 45 and r < 0.5:
		return Build.HEAVY
	if r < 0.1:
		return Build.HEAVY
	return Build.NORMAL if r < 0.7 else (Build.TALL if r < 0.85 else Build.STOCKY)


## Altura en cm para la ficha (la cargada, o según el físico con una
## variación estable).
func height_cm() -> int:
	if height > 0:
		return clampi(height, 155, 205)
	var r := float(hash(player_name + "cm") % 1000) / 1000.0
	return clampi(roundi(178.0 * BUILD_HEIGHT.get(visual_build(), 1.0) + lerpf(-4.0, 4.0, r)), 155, 205)


# --- Condición del día (flechas del WE) ----------------------------------------

## De mejor a peor: roja hacia arriba, naranja, amarilla (normal), azul, gris
## hacia abajo.
enum Condition { TOP, GOOD, NORMAL, LOW, BAD }
const CONDITION_NAMES := ["Excelente", "Buena", "Normal", "Baja", "Mala"]
## Puntos que se suman a cada atributo según la condición.
const CONDITION_DELTA := [6, 3, 0, -3, -6]
## Probabilidad de cada condición al empezar un partido.
const CONDITION_ODDS := [0.1, 0.25, 0.35, 0.2, 0.1]
## Atributos que muestra la ficha (en este orden) y que cambian con la
## condición. 1-99.
const ATTRIBUTES := ["attack", "defense", "balance", "stamina", "speed", "acceleration", "reaction",
	"jump", "heading", "technique", "passing", "shot_power", "shooting", "ball_control", "curve",
	"strength", "goalkeeping"]
const ATTRIBUTE_NAMES := ["Ataque", "Defensa", "Balance", "Estamina", "Velocidad", "Aceleración",
	"Respuesta", "Potencia de salto", "Precisión de cabeza", "Técnica", "Precisión de pase",
	"Potencia de remate", "Precisión de remate", "Gambeta", "Curva", "Fuerza", "Arquero"]


## Nivel de potencia de remate como en el WE (5 a 9).
func shot_level() -> int:
	return clampi(roundi(SetPieceKicks.power_level(self)), 5, 9)


static func roll_condition(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	for i in CONDITION_ODDS.size():
		r -= CONDITION_ODDS[i]
		if r < 0.0:
			return i
	return Condition.NORMAL


## Copia con los atributos del día (la misma si la condición es normal).
func with_condition(c: int) -> PlayerData:
	var delta: int = CONDITION_DELTA[clampi(c, 0, CONDITION_DELTA.size() - 1)]
	if delta == 0:
		return self
	var d := duplicate() as PlayerData
	for a in ATTRIBUTES:
		if int(get(a)) > 0: # los de la ficha ampliada sin cargar quedan en 0
			d.set(a, clampi(int(get(a)) + delta, 1, 99))
	return d


# --- Físico en el cuerpo a cuerpo ------------------------------------------------

## Peso extra por físico (los pesados y musculosos empujan más).
const BUILD_MASS := {Build.NORMAL: 0.0, Build.HEAVY: 0.2, Build.SLIM: -0.15, Build.TALL: 0.05,
	Build.SHORT: -0.12, Build.STOCKY: 0.15, Build.MUSCULAR: 0.2}


## Fuerza en un choque (-1.5..1.5): fuerza, equilibrio y físico.
func body_power() -> float:
	return 0.6 * centered(strength) + 0.4 * centered(balance) + BUILD_MASS.get(visual_build(), 0.0)


## Peso relativo al separarse de otro (1 = promedio).
func mass() -> float:
	return 1.0 + 0.35 * centered(strength) + BUILD_MASS.get(visual_build(), 0.0)


# --- Habilidades especiales ------------------------------------------------------

const ABILITY_NAMES := {
	"gambeteador": "Gambeteador",
	"especialista": "Lanzador de tiros libres",
	"penales": "Especialista en penales",
	"corners": "Lanzador de córners",
	"muro": "Muro defensivo",
	"ataja_penales": "Atajador de penales",
	"capitan": "Capitán",
	"pasador": "Pasador",
	"goleador": "Goleador",
	"cabeceador": "Cabeceador",
	"marcador": "Marcador",
	"atajador": "Arquero de mano a mano",
}


func has_ability(id: String) -> bool:
	return abilities.has(id)


## Habilidades que corresponden a los atributos (las usa el generador de datos).
func suggested_abilities() -> PackedStringArray:
	var out := PackedStringArray()
	if position == Position.GK:
		if goalkeeping >= 78 or reaction >= 80:
			out.append("atajador")
		return out
	if passing >= 76:
		out.append("pasador")
	if shooting >= 76:
		out.append("goleador")
	if ball_control >= 70 and technique >= 66:
		out.append("gambeteador")
	if heading >= 76:
		out.append("cabeceador")
	if technique >= 70 and shooting >= 64 and passing >= 66:
		out.append("especialista")
	if defense >= 78:
		out.append("marcador")
	return out


## Completa la ficha ampliada que no venga cargada (atributos en 0 y
## altura), de forma estable a partir del resto, y suma las etiquetas que le
## correspondan. La usan el generador de datos y la migración de los equipos.
func fill_extended(tags: bool = true) -> void:
	var j := func(salt: String) -> int: return int(absi(hash(player_name + salt)) % 9) - 4
	var gk := position == Position.GK
	if attack <= 0:
		var a := 25.0
		match position:
			Position.FW: a = (shooting + ball_control + speed) / 3.0 + 8.0
			Position.MF: a = (passing + technique + shooting) / 3.0
			Position.DF: a = defense * 0.35 + passing * 0.3 + 5.0
		attack = clampi(roundi(a) + j.call("at"), 1, 99)
	if jump <= 0:
		var bonus := {Build.TALL: 6, Build.SHORT: -6, Build.SLIM: 2, Build.HEAVY: -4}.get(visual_build(), 0) as int
		jump = clampi(roundi(heading * 0.6 + strength * 0.2 + reaction * 0.2) + bonus + j.call("ju"), 1, 99)
	if shot_power <= 0:
		shot_power = clampi(roundi(strength * 0.5 + shooting * 0.5) - (15 if gk else 0) + j.call("sp"), 1, 99)
	if curve <= 0:
		curve = clampi(roundi(technique * 0.6 + passing * 0.4) - 4 - (15 if gk else 0) + j.call("cu"), 1, 99)
	if height <= 0:
		height = height_cm()
	if not tags:
		return
	for tag in suggested_tags():
		if not abilities.has(tag):
			abilities.append(tag)


## Capitán del plantel: el titular de campo más experimentado (edad y
## ficha), si ninguno lo tiene ya.
static func pick_captain(players: Array) -> PlayerData:
	var best: PlayerData = null
	var best_score := -INF
	for i in mini(11, players.size()):
		var p: PlayerData = players[i]
		if p.abilities.has("capitan"):
			return p
		if p.position == Position.GK:
			continue
		var score := p.get_age() * 3.0 + p.reaction + p.defense * 0.5 + p.passing * 0.5
		if score > best_score:
			best_score = score
			best = p
	return best


## Etiquetas de la ficha ampliada que corresponden a los atributos.
func suggested_tags() -> PackedStringArray:
	var out := PackedStringArray()
	if position == Position.GK:
		if reaction >= 70 and goalkeeping >= 70:
			out.append("ataja_penales")
		return out
	if curve >= 72 and passing >= 66:
		out.append("corners")
	if shooting >= 70 and balance >= 60 and technique >= 62:
		out.append("penales")
	if defense >= 74 and strength >= 66:
		out.append("muro")
	return out


func get_age() -> int:
	return age if age > 0 else 18 + absi(int(hash(player_name + "edad"))) % 17
