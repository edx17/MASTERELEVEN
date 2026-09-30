class_name MatchClock
extends RefCounted
## Reloj de partido acelerado: 90 minutos de juego en `real_minutes` reales.

const HALF_GAME_SECONDS := 45.0 * 60.0

var half: int = 1
## Segundos de juego transcurridos en el tiempo actual (0..2700).
var game_seconds: float = 0.0
var running: bool = false
var _scale: float = 1.0


func _init(real_minutes: float = 5.0) -> void:
	# Cuántos segundos de juego pasan por cada segundo real.
	_scale = (HALF_GAME_SECONDS * 2.0) / maxf(real_minutes * 60.0, 1.0)


func advance(real_dt: float) -> void:
	if running:
		game_seconds = minf(game_seconds + real_dt * _scale, HALF_GAME_SECONDS)


func is_half_over() -> bool:
	return game_seconds >= HALF_GAME_SECONDS


func start_second_half() -> void:
	half = 2
	game_seconds = 0.0


## Minuto absoluto del partido (0..90).
func total_game_seconds() -> float:
	return game_seconds + (HALF_GAME_SECONDS if half == 2 else 0.0)


## Texto "MM:SS" como en la TV (el segundo tiempo arranca en 45:00).
func display() -> String:
	var total := int(total_game_seconds())
	return "%02d:%02d" % [total / 60, total % 60]
