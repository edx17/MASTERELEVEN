extends Node
## Captura del menú principal (para revisar su diseño):
## xvfb-run godot -- --menu-shot=archivo.png

var out := "user://menu.png"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for f in 20:
		await get_tree().process_frame
	var img := get_tree().root.get_texture().get_image()
	img.save_png(out)
	print("menú: ", out)
	get_tree().quit()
