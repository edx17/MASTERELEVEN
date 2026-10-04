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
	# Hoja de peinados ("hair" en el nombre): primer plano de cada peinado, de
	# frente (3/4) arriba y de costado abajo.
	var hair := out.contains("hair")
	# Hoja de físicos ("build" en el nombre): normal, gordo, flaco, alto, bajo,
	# fornido y musculoso; de frente arriba y de costado abajo.
	var builds := out.contains("build")
	# Hoja del lateral ("throw" en el nombre): esperando con la pelota.
	var throw := out.contains("throw")
	# Hoja del apretón de manos ("shake"): el que espera y el que pasa.
	var shake := out.contains("shake")
	# Hoja de camisetas ("kit"): un equipo por columna, de frente arriba y de
	# espaldas abajo (diseño, número y escudo pintados en la tela).
	var kits := out.contains("kit")
	var team_list: Array = []
	if kits:
		for path in GameSettings.team_paths():
			team_list.append(load(path))
		stances = []
		for k in team_list.size() * 2:
			stances.append(1)
	if shake:
		stances = [1, 1, 1, 1]
	if throw:
		stances = [1, 1]
	if builds:
		stances = []
		for k in 14:
			stances.append(1)
	if hair:
		stances = []
		for k in HairBuilder.Style.size() * 2:
			stances.append(1)
		cam.position = Vector3(0.0, 1.62, 1.05)
		cam.look_at(Vector3(0, 1.6, 0))
		cam.fov = 32
	var sheet := Image.create(W * stances.size(), H, false, Image.FORMAT_RGB8)
	for i in stances.size():
		var v := ModelVisual.new()
		root.add_child(v)
		var look := {"shirt": Color(0.35, 0.65, 0.95), "shorts": Color(0.95, 0.95, 0.95), "number": 10}
		if hair:
			look["hair_style"] = i % HairBuilder.Style.size()
		if throw:
			v.throw_hold = true
		if builds:
			look["build"] = i % 7
			look["hair_style"] = HairBuilder.Style.FADE
		if kits:
			var td: TeamData = team_list[i % team_list.size()]
			look = {"shirt": td.color, "shorts": td.secondary_color, "number": [10, 7, 23, 9, 5, 14, 11, 8][i % 8],
				"pattern": td.pattern, "shirt2": td.pattern_color}
		v.setup(look, 3 + i)
		# Primero de frente, después de costado (girado 90°).
		v.rotation.y = 0.0 if i < stances.size() / 2 else PI * 0.5
		if kits:
			v.rotation.y = 0.0 if i < stances.size() / 2 else PI
		if hair:
			v.rotation.y = 0.5 if i < stances.size() / 2 else PI * 0.85
		v.stance = maxi(stances[i], 1)
		if stances[i] < 0:
			v.update(1.0 / 60.0, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
			v.play(PlayerVisual.Event.HIGH_FIVE)
		if shake:
			v.update(1.0 / 60.0, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
			v.play(PlayerVisual.Event.HANDSHAKE, 1.0 if i % 2 == 0 else -1.0)
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
