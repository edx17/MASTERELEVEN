extends SceneTree
## Saca capturas del partido para revisar cámara y presentación sin abrir el
## editor. Necesita una build con renderizado (no --headless), por ejemplo:
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-method gl_compatibility \
##       -s res://tools/capture.gd -- /ruta/de/salida
## Guarda: capture_center.png, capture_attack.png, capture_debug.png.

var _out := "user://"
var _match: MatchController
var _frame := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0].trim_suffix("/") + "/"
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	_match = load("res://scenes/match/match.tscn").instantiate()
	root.add_child(_match)


func _process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		150:
			_save("capture_center.png")
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
		280:
			_save("capture_attack.png")
		290:
			for c in _match.get_children():
				if c is DebugOverlay:
					c._set_enabled(true)
		330:
			_save("capture_debug.png")
			return true
	return false


func _save(file: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := _out + file
	var err := img.save_png(path)
	print("captura: %s (%s)" % [path, error_string(err)])
