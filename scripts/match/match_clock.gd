class_name MatchClock
extends RefCounted
## Reloj de partido acelerado: 90 minutos de juego (2 x 20 en futsal) en
## `real_minutes` reales. Corre sólo con la pelota en juego (ver
## MatchController): en futsal es el "reloj parado" del reglamento.

const HALF_GAME_SECONDS := 45.0 * 60.0
## Segundos de juego de cada tiempo (45' en fútbol, 20' en futsal).
var half_seconds: float = HALF_GAME_SECONDS

var half: int = 1
## Segundos de juego transcurridos en el tiempo actual (0..2700).
var game_seconds: float = 0.0
var running: bool = false
var _scale: float = 1.0


func _init(real_minutes: float = 5.0, half_minutes: float = 45.0) -> void:
	half_seconds = half_minutes * 60.0
	# Cuántos segundos de juego pasan por cada segundo real.
	_scale = (half_seconds * 2.0) / maxf(real_minutes * 60.0, 1.0)


## Segundos de juego por segundo real.
func rate() -> float:
	return _scale


func advance(real_dt: float) -> void:
	if running:
		game_seconds = minf(game_seconds + real_dt * _scale, half_seconds)


func is_half_over() -> bool:
	return game_seconds >= half_seconds


func start_second_half() -> void:
	half = 2
	game_seconds = 0.0


## Segundos absolutos del partido (0..90' en fútbol, 0..40' en futsal).
func total_game_seconds() -> float:
	return game_seconds + (half_seconds if half == 2 else 0.0)


## Minuto equivalente de un partido de 90' (para las decisiones de la CPU:
## cambios, hacer tiempo, ir al ataque), sea cual sea la duración del tiempo.
func football_minute() -> float:
	return total_game_seconds() / (half_seconds * 2.0) * 90.0


## Avance del tiempo actual (0..1).
func half_progress() -> float:
	return clampf(game_seconds / half_seconds, 0.0, 1.0)


## Texto "MM:SS" como en la TV (el segundo tiempo arranca en 45:00, o en
## 20:00 en futsal).
func display() -> String:
	var total := int(total_game_seconds())
	return "%02d:%02d" % [total / 60, total % 60]
