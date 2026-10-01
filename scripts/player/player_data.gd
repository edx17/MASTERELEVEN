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


## Atributo normalizado a -1..1 alrededor del promedio (50).
static func centered(value: int) -> float:
	return clampf((value - 50) / 49.0, -1.0, 1.0)


## Atributo normalizado a 0..1.
static func unit(value: int) -> float:
	return clampf((value - 1) / 98.0, 0.0, 1.0)


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
