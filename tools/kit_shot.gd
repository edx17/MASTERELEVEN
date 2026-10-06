extends Node
## Foto del jugador con un kit (para revisar la conversión de kits DLS):
##   xvfb-run godot -- --kit-shot=entrada.png,salida.png
## Si la entrada no es una plantilla del juego (1024), se toma como kit de
## Dream League Soccer y se convierte. Sale el jugador de frente y de espaldas
## y, al lado, la plantilla convertida.

var args := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var parts := args.split(",")
	var src := Image.load_from_file(parts[0])
	var tpl := src if src.get_width() == KitTemplate.SIZE else KitTemplate.from_dls(src)
	var tex := ImageTexture.create_from_image(tpl)
	if src.get_width() != KitTemplate.SIZE:
		tex.resource_name = "prueba_dls.png"
	var shots: Array[Image] = []
	for angle in [0.0, PI]:
		var pv := KitPreview.new()
		pv.size = Vector2(360, 520)
		get_tree().root.add_child(pv)
		pv.spin = false
		pv.show_player({"shirt": Color.WHITE, "shorts": Color.WHITE, "socks": Color.WHITE, "pattern": 0, "shirt2": Color.WHITE, "number": 10, "hair_style": HairBuilder.Style.FADE}, tex)
		pv.angle = angle
		for f in 10:
			await get_tree().process_frame
		var im := (pv.get_child(0) as SubViewport).get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		shots.append(im)
		pv.queue_free()
	var sheet := Image.create(360 * 2 + 520, 520, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, mini(360, shots[i].get_width()), mini(520, shots[i].get_height())), Vector2i(i * 360, 0))
	var small := tpl.duplicate() as Image
	small.convert(Image.FORMAT_RGBA8)
	small.resize(520, 520)
	sheet.blit_rect(small, Rect2i(0, 0, 520, 520), Vector2i(720, 0))
	sheet.save_png(parts[1])
	print("kit: ", parts[1])
	get_tree().quit()
