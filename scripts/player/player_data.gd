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


## Altura en cm para la ficha (según el físico, con una variación estable).
func height_cm() -> int:
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
## Atributos que muestra la ficha y que cambian con la condición.
const ATTRIBUTES := ["speed", "acceleration", "stamina", "strength", "passing", "shooting",
	"technique", "ball_control", "heading", "defense", "reaction", "balance", "goalkeeping"]
const ATTRIBUTE_NAMES := ["Velocidad", "Aceleración", "Resistencia", "Fuerza", "Pases", "Tiro",
	"Técnica", "Dominio", "Cabeza", "Defensa", "Respuesta", "Balance", "Arquero"]


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
	"pasador": "Pasador: pases precisos al hueco",
	"goleador": "Goleador: define mejor en el área",
	"gambeteador": "Gambeteador: difícil de sacarle la pelota",
	"cabeceador": "Cabeceador: gana arriba",
	"especialista": "Especialista en tiros libres",
	"marcador": "Marcador: entradas más limpias",
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


func get_age() -> int:
	return age if age > 0 else 18 + absi(int(hash(player_name + "edad"))) % 17
