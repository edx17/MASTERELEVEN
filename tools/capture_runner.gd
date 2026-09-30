extends Node
## Capturas del partido para revisar cámara y presentación sin abrir el editor.
## Se activa arrancando el juego con un argumento de usuario:
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-method gl_compatibility \
##       --resolution 1280x720 -- --capture=/ruta/de/salida
## Guarda capture_center.png, capture_attack.png y capture_debug.png y sale.

var out_dir := "user://"
var _match: MatchController
var _frame := 0


func _ready() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
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
	if _frame == 2 and _match.is_inside_tree():
		_match.set_physics_process(false)
	match _frame:
		150:
			_save("capture_center.png")
			_match.set_physics_process(true)
		160:
			# Jugada cerca del arco rival para ver la vista diagonal.
			var p: Footballer = _match.teams[0].players[9]
			_match.phase = MatchController.Phase.PLAYING
			_match.restart_taker = null
			_match.ball.frozen = false
			p.locked = false
			p.teleport(Vector3(36, 0, -8), Vector3.RIGHT)
			_match.ball.place(Vector3(36.5, 0.11, -8))
			_match.ball.give_to(p)
			# Se congela la simulación: la cámara se acomoda y la foto es estable.
			_match.set_physics_process(false)
		280:
			_save("capture_attack.png")
		290:
			for c in _match.get_children():
				if c is DebugOverlay:
					c._set_enabled(true)
		330:
			_save("capture_debug.png")
			get_tree().quit()


func _save(file: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.trim_suffix("/") + "/" + file
	print("captura: %s (%s)" % [path, error_string(img.save_png(path))])
