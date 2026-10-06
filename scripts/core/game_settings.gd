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
## Uniforme de cada equipo: 0 = titular, 1 = alternativo.
var home_kit: int = 0
var away_kit: int = 0
## Modo de cámara elegido (índice en MatchCamera.PRESETS); se recuerda entre partidos.
var camera_preset: int = 0
## Ayudas visuales (Opciones > Ayudas).
## Marca en el piso del receptor del pase que se está cargando.
var show_pass_target: bool = false
## Línea del offside en la cancha mientras atacás.
var show_offside_line: bool = false
## Dónde va a caer la pelota cuando va por el aire.
var show_ball_landing: bool = false

## Gráficos (Opciones > Gráficos).
var window_mode: int = 0
const WINDOW_MODE_NAMES := ["ventana", "pantalla completa"]
var resolution: int = 0
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
var vsync: bool = true
var antialias: int = 1
const ANTIALIAS_NAMES := ["no", "2x", "4x"]
var render_scale: int = 0
const RENDER_SCALES := [1.0, 0.85, 0.7]
var shadow_quality: int = 2
const SHADOW_NAMES := ["sin sombras", "bajas", "altas"]
var crowd_level: int = 0
const CROWD_NAMES := ["lleno", "medio", "poco"]
const CROWD_FACTORS := [1.0, 0.6, 0.3]
var fps_limit: int = 0
const FPS_LIMITS := [0, 60, 30]


## Cuánto público se dibuja (Gráficos > Público).
func crowd_factor() -> float:
	return float(CROWD_FACTORS[clampi(crowd_level, 0, CROWD_FACTORS.size() - 1)])


## Aplica las opciones de gráficos a la ventana y al render (sin efecto en
## los tests y herramientas sin pantalla).
func apply_graphics() -> void:
	Engine.max_fps = int(FPS_LIMITS[clampi(fps_limit, 0, FPS_LIMITS.size() - 1)])
	if DisplayServer.get_name() == "headless":
		return
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(antialias, 0, 2)]
	var sc := float(RENDER_SCALES[clampi(render_scale, 0, RENDER_SCALES.size() - 1)])
	vp.scaling_3d_scale = sc
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if sc < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	if shadow_quality > 0:
		RenderingServer.directional_shadow_atlas_set_size(2048 if shadow_quality == 1 else 4096, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if _is_tool_run():
		return
	if window_mode == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size := RESOLUTIONS[clampi(resolution, 0, RESOLUTIONS.size() - 1)]
		var screen := DisplayServer.screen_get_usable_rect()
		size = Vector2i(mini(size.x, screen.size.x), mini(size.y, screen.size.y))
		get_window().size = size
		get_window().position = screen.position + (screen.size - size) / 2


## Sin sombras: las luces que se van creando (estadio, reflectores) no proyectan.
func _on_node_added(n: Node) -> void:
	if shadow_quality == 0 and n is Light3D:
		(n as Light3D).set_deferred("shadow_enabled", false)
## Dificultad de la CPU (Difficulty.Level).
var difficulty: int = 1
## Condiciones del próximo partido: índice del horario / clima elegido o -1 =
## al azar; viento: 0 sin, 1 leve, 2 fuerte, -1 al azar. Por defecto, tarde
## despejada y sin viento.
var time_choice: int = MatchConditions.TimeOfDay.AFTERNOON
var weather_choice: int = MatchConditions.Weather.CLEAR
var wind_choice: int = 0
## Césped: 0 seco, 1 húmedo, 2 mojado, -1 según el clima.
var pitch_choice: int = -1
## Estado del césped: 0 = en buen estado, 1 = gastado (pozos y calvas; en el
## Club House siempre gastado).
var pitch_wear: int = 0
const PITCH_WEAR_NAMES := ["En buen estado", "Gastado"]
## Offside (como la opción del WE).
var offside: bool = true
## Estadio (StadiumStyles.STYLES); -1 = al azar.
var stadium_choice: int = 0
const WIND_NAMES := ["Sin viento", "Viento leve", "Viento fuerte"]
const PITCH_NAMES := ["Césped seco", "Césped húmedo", "Césped mojado"]
const PITCH_WETNESS := [0.0, 0.4, 0.85]

## Velocidad del juego (como la opción del WE2002): nivel -2..+2. Todo el
## partido (jugadores, pelota, animaciones) corre a esa escala de tiempo; el
## reloj del partido se compensa (la duración en minutos reales no cambia).
var game_speed: int = 0
const GAME_SPEEDS := {-2: 0.68, -1: 0.76, 0: 0.84, 1: 0.92, 2: 1.0}


func game_time_scale() -> float:
	return GAME_SPEEDS.get(game_speed, 0.84)


## Marca sobre los jugadores: 0 = nombre del que manejás (como el WE),
## 1 = número de todos, 2 = nada.
var player_label: int = 0
const PLAYER_LABEL_NAMES := ["nombre del controlado", "números", "nada", "nombres de todos"]

## El próximo partido arranca con la presentación (lo pide el menú principal).
var play_intro: bool = false

## Arquero al cumplir los 6 s con la pelota en las manos: 0 = pelotazo
## hacia adelante, 1 = la suelta y la juega con los pies.
var keeper_auto_action: int = 0
const KEEPER_AUTO_NAMES := ["patea", "la suelta"]

## Rumbos del stick del humano: 8, 16 (estilo WE2002) o 0 = libre. Arranca
## con el valor de tuning.tres y se cambia desde la pausa.
var stick_directions: int = 8

## Configuración guardada entre sesiones (las opciones del menú y de la pausa).
## Opciones: en la carpeta del jugador (UserData.config_path()).
const SETTINGS_PATH := ""
const SAVED := ["match_minutes", "difficulty", "time_choice", "weather_choice", "wind_choice",
	"pitch_choice", "pitch_wear", "stadium_choice", "game_speed", "player_label", "keeper_auto_action",
	"stick_directions", "camera_preset", "show_pass_target", "offside", "home_team_path", "away_team_path",
	"home_kit", "away_kit", "show_replays", "replay_chances", "player_style", "sfx_volume", "crowd_volume", "music_volume",
	"show_radar", "show_score", "wc_playoff", "active_optionfile", "show_offside_line", "show_ball_landing",
	"window_mode", "resolution", "vsync", "antialias", "render_scale", "shadow_quality", "crowd_level", "fps_limit",
	"input_source"]
## Falso en los tests y las herramientas: no leen ni pisan la configuración
## del jugador (así los resultados no dependen de lo que eligió).
var persist := true
## Último dispositivo usado en los menús (InputRouter.Source; -1 = no se sabe):
## sólo el valor inicial de las indicaciones de control al abrir el juego.
var input_source: int = -1
## Condición al azar de los jugadores en cada partido (flechas). En los
## tests y herramientas todos llegan normales (resultados repetibles).
var random_conditions := true
## Repetición después de cada gol (apagada en tests y herramientas).
var show_replays := true
## Estilo de los jugadores: clásico (pocos polígonos, como el WE de PS1; por
## defecto), retro (el modelo base estilo PS1, beta) o detallado (el modelo
## con músculos).
enum PlayerStyle { CLASSIC, RETRO, DETAILED, BLOCKS }
const PLAYER_STYLE_NAMES := ["clásicos", "retro PS1 (beta)", "detallados", "bloques"]
var player_style: int = PlayerStyle.CLASSIC
## Repetición también de las jugadas peligrosas (remates cerca, atajadas al
## córner, faltas importantes).
var replay_chances := true
## Partido de Liga / Copa en curso: de qué lado juega el humano y el
## resultado al terminar (lo lee el menú al volver). No se guardan.
var competition_match := false
## Entrenamiento en el Club House (TrainingSession): qué se practica al
## entrar (TrainingSession.Kind y, en los desafíos, TrainingSession.Challenge).
var training := false
## Partido > Tanda de penales: sólo la definición por penales.
var shootout := false
## Mundial 2026: las 6 selecciones elegidas para los cupos del repechaje
## (de las 12 candidatas marcadas "po" en data/db/nations.json).
var wc_playoff: Array = ["ita", "pol", "kos", "den", "cod", "irq"]
const WC_PLAYOFF_SLOTS := 6
## Option File activo (nombre; "" = la base del juego).
var active_optionfile := ""
## Archivo de la Liga / Copa / Mundial que se está jugando.
var active_save := ""
## El Editor se abrió desde el menú del juego (muestra "Volver al juego").
var editor_from_game := false
const EDITOR_SCENE := "res://scenes/editor/editor_main.tscn"
var training_kind: int = 0
var training_challenge: int = 0
var human_side: int = 0
var last_result: Array = []
## Goles del partido jugado: [[lado (0 local / 1 visitante), pid del autor
## (0 si no se sabe o fue en contra)]]. Lo usa la Liga Master.
var last_scorers: Array = []
## Tarjetas y lesiones del partido jugado: [[lado, pid, "y" | "r" | "i1" | "i2"]].
var last_events: Array = []
## Partido de la Liga Master en curso (active_save es la carrera).
var master_match := false
## Volumen de efectos (silbato, pelota) y del público, 0..10.
var sfx_volume: int = 8
## Pantalla del partido (pausa > Pantalla): radar y marcador/reloj.
var show_radar := true
var show_score := true
var crowd_volume: int = 7
## Volumen de la música del menú, 0..10.
var music_volume: int = 6


func _ready() -> void:
	tuning = load(TUNING_PATH) as Tuning
	if tuning == null:
		push_warning("No se pudo cargar %s; se usan valores por defecto." % TUNING_PATH)
		tuning = Tuning.new()
	stick_directions = tuning.stick_directions
	persist = not _is_tool_run()
	# Tests y herramientas: carpeta aparte (no se tocan los datos del jugador).
	UserData.sandbox = not persist
	if persist:
		UserData.migrate_old()
	UserData.ensure_dirs()
	random_conditions = persist
	if "--retro" in OS.get_cmdline_user_args():
		player_style = PlayerStyle.RETRO
	if "--detailed" in OS.get_cmdline_user_args():
		player_style = PlayerStyle.DETAILED
	if "--blocks" in OS.get_cmdline_user_args():
		player_style = PlayerStyle.BLOCKS
	show_replays = persist
	replay_chances = persist
	if persist:
		load_settings()
		ControlsConfig.load_saved()
		apply_graphics.call_deferred()
	get_tree().node_added.connect(_on_node_added)
	InputRouter.setup_for_mode(mode)
	InputRouter.start(input_source if persist else -1)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_check_capture_mode()
	# El Editor como programa aparte (exportación "Editor", con la etiqueta
	# editor_app) o con `-- --editor`.
	if OS.has_feature("editor_app") or "--editor" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred(EDITOR_SCENE)
		get_window().title = "Master Eleven · Editor"


## Corre un test, una captura, la hoja de poses o la prueba de rendimiento
## automática (no un jugador).
func _is_tool_run() -> bool:
	for a in OS.get_cmdline_args():
		if a.contains("gut_cmdln"):
			return true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture=") or a.begins_with("--poses=") or a.begins_with("--stadium-thumbs=") or a.begins_with("--menu-shot=") or a.begins_with("--import-players=") or a.begins_with("--editor-shot=") or a == "--benchmark":
			return true
	return false


## Guarda las opciones (si es una partida de verdad).
func save_settings(path: String = SETTINGS_PATH) -> void:
	if not persist and path == SETTINGS_PATH:
		return
	if path == "":
		path = UserData.config_path()
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	for key in SAVED:
		cfg.set_value("options", key, get(key))
	cfg.save(path)


## Activa el Option File elegido (si existe; si no, la base).
func apply_option_file() -> void:
	var of: OptionFile = null
	if active_optionfile != "":
		of = OptionFile.load_named(active_optionfile)
		if of == null:
			active_optionfile = ""
	TeamDB.use_option_file(of)


## Lee las opciones guardadas; lo que falte o no tenga sentido queda como está.
func load_settings(path: String = SETTINGS_PATH) -> void:
	if path == "":
		path = UserData.config_path()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for key in SAVED:
		if not cfg.has_section_key("options", key):
			continue
		var v: Variant = cfg.get_value("options", key)
		if typeof(v) == typeof(get(key)):
			set(key, v)
	if not match_minutes in DURATION_OPTIONS:
		match_minutes = DURATION_OPTIONS[0]
	difficulty = clampi(difficulty, 0, Difficulty.NAMES.size() - 1)
	time_choice = clampi(time_choice, -1, MatchConditions.TIME_NAMES.size() - 1)
	weather_choice = clampi(weather_choice, -1, MatchConditions.WEATHER_NAMES.size() - 1)
	wind_choice = clampi(wind_choice, -1, WIND_NAMES.size() - 1)
	pitch_choice = clampi(pitch_choice, -1, PITCH_NAMES.size() - 1)
	pitch_wear = clampi(pitch_wear, 0, PITCH_WEAR_NAMES.size() - 1)
	stadium_choice = clampi(stadium_choice, -1, StadiumStyles.STYLES.size() - 1)
	game_speed = clampi(game_speed, -2, 2)
	player_label = clampi(player_label, 0, PLAYER_LABEL_NAMES.size() - 1)
	keeper_auto_action = clampi(keeper_auto_action, 0, 1)
	if not stick_directions in STICK_OPTIONS:
		stick_directions = tuning.stick_directions
	camera_preset = maxi(camera_preset, 0)
	apply_option_file()
	if not TeamDB.exists(home_team_path):
		home_team_path = DEFAULT_HOME
	if not TeamDB.exists(away_team_path):
		away_team_path = DEFAULT_AWAY
	sfx_volume = clampi(sfx_volume, 0, 10)
	crowd_volume = clampi(crowd_volume, 0, 10)
	music_volume = clampi(music_volume, 0, 10)
	home_kit = clampi(home_kit, 0, 1)
	away_kit = clampi(away_kit, 0, 1)


## Herramienta de desarrollo: `-- --capture=<carpeta>` saca capturas y sale.
func _check_capture_mode() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--poses="):
			var poses: Node = load("res://tools/pose_sheet.gd").new()
			poses.set("out", arg.trim_prefix("--poses="))
			get_tree().root.add_child.call_deferred(poses)
		if arg.begins_with("--import-players="):
			var imp: Node = load("res://tools/import_players.gd").new()
			imp.set("files", arg.trim_prefix("--import-players=").split(",", false))
			get_tree().root.add_child.call_deferred(imp)
		if arg.begins_with("--editor-shot="):
			var es: Node = load("res://tools/editor_shot.gd").new()
			es.set("out", arg.trim_prefix("--editor-shot="))
			get_tree().root.add_child.call_deferred(es)
		if arg.begins_with("--menu-shot="):
			var shot: Node = load("res://tools/menu_shot.gd").new()
			shot.set("out", arg.trim_prefix("--menu-shot="))
			get_tree().root.add_child.call_deferred(shot)
		if arg.begins_with("--stadium-thumbs="):
			var thumbs: Node = load("res://tools/stadium_thumbs.gd").new()
			thumbs.set("out_dir", arg.trim_prefix("--stadium-thumbs="))
			get_tree().root.add_child.call_deferred(thumbs)
		if arg == "--benchmark":
			start_benchmark(true)
		if arg.begins_with("--capture="):
			var runner: Node = load("res://tools/capture_runner.gd").new()
			runner.set("out_dir", arg.trim_prefix("--capture="))
			get_tree().root.add_child.call_deferred(runner)


## Condiciones del partido según lo elegido en el menú (lo "al azar" se sortea acá).
func make_conditions() -> MatchConditions:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var c := MatchConditions.random(rng)
	if time_choice >= 0:
		c.time_of_day = time_choice as MatchConditions.TimeOfDay
	if weather_choice >= 0:
		c.weather = weather_choice as MatchConditions.Weather
	if wind_choice >= 0:
		c.wind_speed = [0.0, 4.0, 9.0][wind_choice]
	if time_choice >= 0 or weather_choice >= 0:
		c.wetness = MatchConditions.default_wetness(c.weather, c.time_of_day, rng)
	if pitch_choice >= 0:
		c.wetness = PITCH_WETNESS[pitch_choice]
	return c


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


## Todos los equipos (data/teams), en orden alfabético de archivo.
func team_paths() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open("res://data/teams")
	if dir == null:
		return [DEFAULT_HOME, DEFAULT_AWAY]
	for f in dir.get_files():
		var name := f.trim_suffix(".remap")
		if name.ends_with(".tres") and not out.has("res://data/teams/" + name):
			out.append("res://data/teams/" + name)
	out.sort()
	return out


## Uniforme que no se confunda: si las camisetas se parecen, el visitante
## usa el otro.
static func kits_clash(a: Color, b: Color) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.35


func home_team() -> TeamData:
	return TeamDB.load_team(home_team_path)


func away_team() -> TeamData:
	return TeamDB.load_team(away_team_path)
