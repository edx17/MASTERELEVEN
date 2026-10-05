extends SceneTree
## Hoja con todas las banderas de las selecciones (para revisarlas):
##   godot --headless -s res://tools/flag_sheet.gd -- archivo.png

func _init() -> void:
	var out := "user://flags.png"
	for a in OS.get_cmdline_user_args():
		out = a
	var ns := TeamDB.nations()
	var cols := 10
	var cw := FlagPainter.W + 8
	var ch := FlagPainter.H + 8
	var sheet := Image.create(cw * cols, ch * int(ceil(ns.size() / float(cols))), false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.3, 0.3, 0.3))
	for i in ns.size():
		var img := FlagPainter.image(ns[i].get("flag", {}))
		sheet.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i((i % cols) * cw + 4, (i / cols) * ch + 4))
	sheet.save_png(out)
	print("banderas: ", ns.size(), " -> ", out)
	quit()
