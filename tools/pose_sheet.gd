extends Node
## Hoja de poses del jugador (ModelVisual) de frente, para ajustar posturas y
## camiseta. xvfb-run godot --rendering-method forward_plus -- --poses=archivo.png

const W := 260
const H := 420

var out := "user://poses.png"
var root: Window


func _ready() -> void:
	root = get_tree().root
	var menu := get_tree().current_scene
	if menu != null:
		menu.queue_free()
	_run.call_deferred()


func _run() -> void:
	var process_frame := get_tree().process_frame
	root.size = Vector2i(W, H)
	ModelVisual.available()
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0.0, 1.1, 3.4)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.fov = 40
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees = Vector3(-40, 25, 0)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.35, 0.45, 0.35)
	e.ambient_light_color = Color(0.6, 0.6, 0.6)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	root.add_child(env)
	# -1 = choque de manos (en el punto más alto).
	var stances := [1, 2, 3, 4, -1, 1, 2, 3, 4, -1]
	var sheet := Image.create(W * stances.size(), H, false, Image.FORMAT_RGB8)
	for i in stances.size():
		var v := ModelVisual.new()
		root.add_child(v)
		v.setup({"shirt": Color(0.35, 0.65, 0.95), "shorts": Color(0.95, 0.95, 0.95), "number": 10}, 3)
		# Primero de frente, después de costado (girado 90°).
		v.rotation.y = 0.0 if i < stances.size() / 2 else PI * 0.5
		v.stance = maxi(stances[i], 1)
		if stances[i] < 0:
			v.update(1.0 / 60.0, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
			v.play(PlayerVisual.Event.HIGH_FIVE)
		for f in 20:
			v.update(1.0 / 60.0, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
			await process_frame
		await process_frame
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(i * W, 0))
		v.queue_free()
		await process_frame
	sheet.save_png(out)
	print("hoja: ", out)
	get_tree().quit()
