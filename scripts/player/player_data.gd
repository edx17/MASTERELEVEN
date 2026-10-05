class_name PlayerData
extends Resource
## Datos de un jugador (ficticio). Los atributos van de 1 a 99; 50 es un
## jugador promedio. La lógica del partido lee estos valores, nunca nombres
## ni números hardcodeados.

enum Position { GK, DF, MF, FW }
enum Foot { RIGHT, LEFT }
## Físico (sólo presentación). AUTO = según los atributos.
enum Build { AUTO = -1, NORMAL, HEAVY, SLIM, TALL, SHORT, STOCKY, MUSCULAR }

@export var id: String = ""
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


func body_height() -> float:
	return BUILD_HEIGHT.get(visual_build(), 1.0)


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
		return height
	var r := float(hash(player_name + "cm") % 1000) / 1000.0
	return roundi(178.0 * body_height() + lerpf(-4.0, 4.0, r))


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
