extends Node
## Autoload "GameSettings": opciones elegidas en el menú que el partido necesita
## (modo de juego, duración) y acceso único a los parámetros de ajuste (Tuning).

enum Mode { VS_CPU, TWO_PLAYERS, CPU_VS_CPU }

const TUNING_PATH := "res://data/config/tuning.tres"
const DURATION_OPTIONS: Array[int] = [5, 7, 10, 3]
const DEFAULT_HOME := "res://data/teams/aurora.tres"
const DEFAULT_AWAY := "res://data/teams/halcones.tres"

## Minutos reales que dura un partido completo (los 90' se aceleran a esto).
var match_minutes: int = 5
var mode: int = Mode.VS_CPU
var tuning: Tuning
## Equipos del próximo partido (rutas a TeamData).
var home_team_path: String = DEFAULT_HOME
var away_team_path: String = DEFAULT_AWAY


func _ready() -> void:
	tuning = load(TUNING_PATH) as Tuning
	if tuning == null:
		push_warning("No se pudo cargar %s; se usan valores por defecto." % TUNING_PATH)
		tuning = Tuning.new()
	InputRouter.setup_for_mode(mode)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func set_mode(new_mode: int) -> void:
	mode = new_mode
	InputRouter.setup_for_mode(mode)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	# Reasigna dispositivos automáticamente al conectar/desconectar un mando.
	InputRouter.setup_for_mode(mode)


func home_team() -> TeamData:
	return load(home_team_path) as TeamData


func away_team() -> TeamData:
	return load(away_team_path) as TeamData
