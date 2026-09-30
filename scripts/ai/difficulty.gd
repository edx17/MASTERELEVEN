class_name Difficulty
extends RefCounted
## Niveles de dificultad de la CPU. Sólo se aplican a los equipos que maneja
## la CPU; los compañeros del humano juegan siempre en "Normal".

enum Level { EASY, NORMAL, HARD }

const NAMES := ["Fácil", "Normal", "Difícil"]

var level: int = Level.NORMAL
## Multiplicador del tiempo de reacción ante cada patada.
var reaction_mult: float = 1.0
## Ruido en la evaluación de opciones de pase (más = decisiones peores).
var decision_noise: float = 0.3
## Probabilidad por tick de intentar una entrada estando a distancia.
var tackle_rate: float = 0.035
## Presionantes en estado PRESIÓN.
var pressers: int = 2
## Multiplicador de la ganas de rematar.
var shot_eagerness: float = 1.0
## Bonus (puntos de atributo) al arquero.
var keeper_bonus: int = 0
## Frecuencia de desmarques en ataque (0..1).
var run_rate: float = 0.7


static func make(p_level: int) -> Difficulty:
	var d := Difficulty.new()
	d.level = p_level
	match p_level:
		Level.EASY:
			d.reaction_mult = 1.45
			d.decision_noise = 0.7
			d.tackle_rate = 0.018
			d.pressers = 1
			d.shot_eagerness = 0.75
			d.keeper_bonus = -10
			d.run_rate = 0.45
		Level.HARD:
			d.reaction_mult = 0.8
			d.decision_noise = 0.12
			d.tackle_rate = 0.05
			d.pressers = 2
			d.shot_eagerness = 1.15
			d.keeper_bonus = 8
			d.run_rate = 0.9
	return d
