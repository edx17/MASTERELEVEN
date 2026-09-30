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
	[395, "quit"],
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


func _place(player_pos: Vector3, ball_pos: Vector3) -> void:
	var p: Footballer = _match.teams[0].players[9]
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
