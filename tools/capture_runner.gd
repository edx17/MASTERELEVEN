extends Node
## Capturas del partido para revisar cámara y presentación sin abrir el editor.
## Se activa arrancando el juego con un argumento de usuario:
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-method gl_compatibility \
##       --resolution 1280x720 -- --capture=/ruta/de/salida
## Guarda una captura por modo de cámara, una de un lateral sobre la banda
## cercana a la cámara y una con el modo debug, y sale.

var out_dir := "user://"
var _match: MatchController
var _camera: MatchCamera
var _frame := 0
## [frame, acción]. Las acciones de "setup" preparan la escena; "shot:<n>" guarda.
var _script := [
	[20, "freeze"],
	[40, "shot:capture_tv.png"],
	[45, "throw_in"],
	[90, "shot:capture_tv_throw_in.png"],
	[95, "attack"],
	[140, "shot:capture_tv_attack.png"],
	[145, "preset:Amplia"],
	[190, "shot:capture_amplia.png"],
	[195, "preset:Cercana"],
	[240, "shot:capture_cercana.png"],
	[245, "preset:Vertical"],
	[290, "shot:capture_vertical.png"],
	[295, "preset:Dron"],
	[340, "shot:capture_dron.png"],
	[345, "preset:TV"],
	[350, "debug"],
	[390, "shot:capture_debug.png"],
	# Vista cenital (Dron) con simulación exacta: forma del equipo en ataque,
	# córner y saque de arco (con el debug mostrando objetivos).
	[395, "tactical_view"],
	[396, "attack_live"],
	[397, "simulate:3.0"],
	[440, "shot:capture_shape_attack.png"],
	[445, "corner"],
	[446, "simulate:2.5"],
	[490, "shot:capture_corner.png"],
	[495, "goal_kick"],
	[496, "simulate:2.5"],
	[540, "shot:capture_goal_kick.png"],
	# Gestos: remate con estirada del arquero y un pase (cámara Cercana).
	[545, "preset:Cercana"],
	[546, "shoot_scene"],
	[547, "simulate:0.12"],
	[560, "shot:capture_kick.png"],
	[561, "simulate:0.25"],
	[575, "shot:capture_dive.png"],
	[580, "pass_scene"],
	[581, "simulate:0.2"],
	[595, "shot:capture_pass.png"],
	[600, "quit"],
]


func _ready() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	GameSettings.camera_preset = 0
	_match = load("res://scenes/match/match.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_match)
	# Saca el menú principal para que no tape la escena.
	_remove_menu.call_deferred()


func _remove_menu() -> void:
	var menu := get_tree().current_scene
	if menu != null and menu != _match:
		menu.queue_free()


func _process(_delta: float) -> void:
	_frame += 1
	for step in _script:
		if step[0] == _frame:
			_run(step[1])


func _run(action: String) -> void:
	if _camera == null:
		for c in _match.get_children():
			if c is MatchCamera:
				_camera = c
	if action == "freeze":
		# Simulación congelada: la cámara se acomoda y las fotos son estables.
		_match.set_physics_process(false)
	elif action == "throw_in":
		_place(Vector3(-8, 0, Pitch.HALF_WIDTH - 0.3), Vector3(-8.5, 0.11, Pitch.HALF_WIDTH - 0.6))
	elif action == "attack":
		_place(Vector3(36, 0, -8), Vector3(36.5, 0.11, -8))
	elif action == "tactical_view":
		# Vista táctica sólo para capturas: dron alto que ve toda la cancha.
		var c := CameraConfig.new()
		c.display_name = "Táctica"
		c.mode = CameraConfig.Mode.TOPDOWN
		c.camera_height = 118.0
		c.base_fov = 50.0
		c.follow_speed = 100.0
		_camera.config = c
		_camera._focus = Vector3.ZERO
	elif action.begins_with("simulate:"):
		# Avanza la simulación un tiempo exacto sin depender de los FPS.
		var secs := float(action.trim_prefix("simulate:"))
		for i in int(secs * 60.0):
			_match._physics_process(1.0 / 60.0)
	elif action == "unfreeze":
		_match.set_physics_process(true)
	elif action == "attack_live":
		var t0 := _match.teams[0]
		var carrier: Footballer = t0.players[6]
		_place(t0.to_world(Vector2(0.55, 0.1)), t0.to_world(Vector2(0.56, 0.1)) + Vector3(0, 0.11, 0), carrier)
	elif action == "corner":
		var t0 := _match.teams[0]
		var spot := Vector3(t0.attack_dir * (Pitch.HALF_LENGTH - 0.4), 0.11, -(Pitch.HALF_WIDTH - 0.4))
		_match._pending = MatchRules.Outcome.new(MatchRules.Restart.CORNER, 0, spot)
		_match._setup_restart(_match._pending)
	elif action == "goal_kick":
		var t1 := _match.teams[1]
		var spot2 := Vector3(t1.own_side() * (Pitch.HALF_LENGTH - 5.5), 0.11, 4.0)
		_match._pending = MatchRules.Outcome.new(MatchRules.Restart.GOAL_KICK, 1, spot2)
		_match._setup_restart(_match._pending)
	elif action == "shoot_scene":
		# Remate cruzado desde la puerta del área contra el arquero rival.
		var t1 := _match.teams[1]
		var shooter: Footballer = _match.teams[0].players[9]
		var goal := t1.own_goal()
		_place(goal + Vector3(-t1.own_side() * 16.0, 0, 3.0), goal + Vector3(-t1.own_side() * 15.5, 0.11, 3.0), shooter)
		shooter.facing = Vector3(t1.own_side(), 0, 0)
		var gk := t1.keeper()
		gk.teleport(goal + Vector3(-t1.own_side() * 1.0, 0, 0), Vector3(-t1.own_side(), 0, 0))
		_camera._focus = shooter.flat_pos()
		_match.perform_kick(shooter, KickActions.Kind.SHOT, Vector3(0, 0, -1), 0.8)
	elif action == "pass_scene":
		var p: Footballer = _match.teams[0].players[6]
		_place(Vector3(-5, 0, 2), Vector3(-4.5, 0.11, 2), p)
		_camera._focus = p.flat_pos()
		_match.perform_kick(p, KickActions.Kind.SHORT_PASS, Vector3(1, 0, 0), 0.5)
	elif action.begins_with("preset:"):
		var name := action.trim_prefix("preset:")
		for i in _camera.presets.size():
			if _camera.presets[i].display_name == name:
				_camera.set_preset(i)
	elif action == "debug":
		for c in _match.get_children():
			if c is DebugOverlay:
				c._set_enabled(true)
	elif action.begins_with("shot:"):
		_save(action.trim_prefix("shot:"))
	elif action == "quit":
		get_tree().quit()


func _place(player_pos: Vector3, ball_pos: Vector3, who: Footballer = null) -> void:
	var p: Footballer = who if who != null else _match.teams[0].players[9]
	_match.phase = MatchController.Phase.PLAYING
	_match.restart_taker = null
	_match.ball.frozen = false
	p.locked = false
	p.teleport(player_pos, Vector3.RIGHT)
	_match.ball.place(ball_pos)
	_match.ball.give_to(p)
	_match.humans[0].select(p)


func _save(file: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.trim_suffix("/") + "/" + file
	print("captura: %s (%s)" % [path, error_string(img.save_png(path))])
