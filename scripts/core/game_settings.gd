extends Node
## Autoload "GameSettings": opciones elegidas en el menú que el partido necesita
## (modo de juego, duración) y acceso único a los parámetros de ajuste (Tuning).

enum Mode { VS_CPU, TWO_PLAYERS, CPU_VS_CPU }

const TUNING_PATH := "res://data/config/tuning.tres"
const DURATION_OPTIONS: Array[int] = [5, 7, 10, 3]
const DEFAULT_HOME := "res://data/teams/aurora.tres"
const DEFAULT_AWAY := "res://data/teams/halcones.tres"
const STICK_OPTIONS: Array[int] = [8, 16, 0]

## Minutos reales que dura un partido completo (los 90' se aceleran a esto).
var match_minutes: int = 5
var mode: int = Mode.VS_CPU
var tuning: Tuning
## Equipos del próximo partido (rutas a TeamData).
var home_team_path: String = DEFAULT_HOME
var away_team_path: String = DEFAULT_AWAY
## Modo de cámara elegido (índice en MatchCamera.PRESETS); se recuerda entre partidos.
var camera_preset: int = 0
## Ayudas visuales (se podrán activar desde el menú de opciones, Fase 8).
## Marca en el piso del receptor del pase que se está cargando.
var show_pass_target: bool = false
## Dificultad de la CPU (Difficulty.Level).
var difficulty: int = 1
## Rumbos del stick del humano: 8, 16 (estilo WE2002) o 0 = libre. Arranca
## con el valor de tuning.tres y se cambia desde la pausa.
var stick_directions: int = 8


func _ready() -> void:
	tuning = load(TUNING_PATH) as Tuning
	if tuning == null:
		push_warning("No se pudo cargar %s; se usan valores por defecto." % TUNING_PATH)
		tuning = Tuning.new()
	stick_directions = tuning.stick_directions
	InputRouter.setup_for_mode(mode)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_check_capture_mode()


## Herramienta de desarrollo: `-- --capture=<carpeta>` saca capturas y sale.
func _check_capture_mode() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--benchmark":
			start_benchmark(true)
		if arg.begins_with("--capture="):
			var runner: Node = load("res://tools/capture_runner.gd").new()
			runner.set("out_dir", arg.trim_prefix("--capture="))
			get_tree().root.add_child.call_deferred(runner)


## Prueba de rendimiento (tools/benchmark_runner.gd). `quit`: sale al terminar.
func start_benchmark(quit: bool = false) -> void:
	var runner: Node = load("res://tools/benchmark_runner.gd").new()
	runner.set("quit_when_done", quit)
	get_tree().root.add_child.call_deferred(runner)


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
