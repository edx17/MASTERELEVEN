extends Node
## Prueba de rendimiento: juega 30 s de CPU vs CPU con la cámara de juego y
## mide los cuadros por segundo reales en esta máquina (promedio, 1 % más
## lentos y peor cuadro). Muestra el resultado en pantalla y lo guarda en
## user://benchmark.txt. Se lanza desde el menú principal o con
## `-- --benchmark` (sale solo al terminar).

const WARMUP := 3.0
const DURATION := 30.0

var quit_when_done := false
var _match: MatchController
var _t := 0.0
var _frames: PackedFloat32Array = []
var _label: Label
var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	_match = load("res://scenes/match/match.tscn").instantiate()
	_match.break_auto_continue = true
	get_tree().root.add_child.call_deferred(_match)
	var menu := get_tree().current_scene
	if menu != null:
		menu.queue_free.call_deferred()
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 90)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)


func _process(scaled_dt: float) -> void:
	# Tiempo real del cuadro (el juego puede correr más lento: velocidad).
	var dt := scaled_dt / maxf(Engine.time_scale, 0.01)
	if _done:
		if Input.is_action_just_pressed(&"ui_accept") or Input.is_action_just_pressed(&"pause"):
			_back_to_menu()
		return
	_t += dt
	if _t < WARMUP:
		_label.text = "Prueba de rendimiento: preparando..."
		return
	_frames.append(dt)
	var left := WARMUP + DURATION - _t
	_label.text = "Prueba de rendimiento: %d s   FPS ahora: %d" % [ceili(left), Engine.get_frames_per_second()]
	if left <= 0.0:
		_finish()


func _finish() -> void:
	_done = true
	var r := summarize(_frames)
	var renderer := RenderingServer.get_current_rendering_method()
	var gpu := RenderingServer.get_video_adapter_name()
	var text := "PRUEBA DE RENDIMIENTO (%d s, CPU vs CPU)\nPromedio: %.0f FPS (%.1f ms)\n1 %% más lentos: %.0f FPS\nPeor cuadro: %.1f ms\nRenderer: %s   Placa: %s\n%s" % [
		DURATION, r["avg_fps"], r["avg_ms"], r["low1_fps"], r["worst_ms"], renderer, gpu,
		"OK: 60 FPS o más" if r["low1_fps"] >= 55.0 else "Por debajo de 60 FPS"]
	var f := FileAccess.open("user://benchmark.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
	print(text)
	_label.text = text + "\n\nGuardado en %s\nX / Enter: volver al menú" % ProjectSettings.globalize_path("user://benchmark.txt")
	if quit_when_done:
		get_tree().quit()


## {avg_fps, avg_ms, low1_fps, worst_ms} a partir de los tiempos de cuadro.
static func summarize(frames: PackedFloat32Array) -> Dictionary:
	if frames.is_empty():
		return {"avg_fps": 0.0, "avg_ms": 0.0, "low1_fps": 0.0, "worst_ms": 0.0}
	var total := 0.0
	for d in frames:
		total += d
	var sorted := frames.duplicate()
	sorted.sort()
	var n := maxi(1, int(sorted.size() * 0.01))
	var slow := 0.0
	for i in n:
		slow += sorted[sorted.size() - 1 - i]
	return {
		"avg_fps": frames.size() / total,
		"avg_ms": total / frames.size() * 1000.0,
		"low1_fps": n / slow,
		"worst_ms": sorted[sorted.size() - 1] * 1000.0,
	}


func _back_to_menu() -> void:
	# Start/Esc también abre la pausa del partido en este mismo cuadro: se
	# despausa después, ya en el menú.
	get_tree().set_deferred("paused", false)
	get_tree().paused = false
	if _match != null:
		_match.queue_free()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	queue_free()
