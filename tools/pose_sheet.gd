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
	# Hoja de caras ("face"): piel, pelo y barba (cuerpo clásico), de frente.
	var faces := out.contains("face")
	# Prueba del mapeo UV del uniforme ("uv"): cada región de un color con una
	# grilla (docs/KIT_UV.md); de frente, de espaldas y de costado.
	var uvtest := out.contains("uvtest")
	var uv_tex: Texture2D = null
	if uvtest:
		var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
		for y in 256:
			for x in 256:
				var u := x / 256.0
				var vv := y / 256.0
				var c := Color(0.2, 0.2, 0.2)
				if vv < 0.5 and u < 0.5:
					c = Color(0.9, 0.2, 0.2).lerp(Color(0.2, 0.3, 0.95), u * 2.0)
				elif vv < 0.25:
					c = Color(0.2, 0.8, 0.3) if u < 0.75 else Color(0.95, 0.85, 0.2)
				elif vv >= 0.5 and vv < 0.75:
					c = [Color(0.9, 0.5, 0.1), Color(0.6, 0.2, 0.8), Color(0.1, 0.8, 0.8), Color(0.9, 0.9, 0.9)][int(u * 4.0)]
				if x % 16 == 0 or y % 16 == 0:
					c = c.darkened(0.5)
				img.set_pixel(x, y, c)
		uv_tex = ImageTexture.create_from_image(img)
		stances = [1, 1, 1]
	# Hoja de físicos ("build" en el nombre): normal, gordo, flaco, alto, bajo,
	# fornido y musculoso; de frente arriba y de costado abajo.
	var builds := out.contains("build")
	# Hoja de cuerpos paramétricos ("body"): de 1,60 a 2,03 m, flacos,
	# normales, musculosos y pesados; de frente arriba y de costado abajo.
	var bodies := out.contains("body")
	var body_list := [
		{"height": 160, "mass": -0.4, "muscle": 0.3, "shoulders": -0.3, "legs": -0.3},
		{"height": 170, "mass": -0.7, "muscle": 0.15, "shoulders": -0.5, "legs": 0.3},
		{"height": 178, "mass": 0.0, "muscle": 0.35, "shoulders": 0.0, "legs": 0.0},
		{"height": 183, "mass": 0.1, "muscle": 0.95, "shoulders": 0.6, "legs": 0.0},
		{"height": 188, "mass": 0.6, "muscle": 0.6, "shoulders": 0.3, "legs": -0.4},
		{"height": 194, "mass": 0.95, "muscle": 0.3, "shoulders": 0.2, "legs": -0.2},
		{"height": 203, "mass": -0.2, "muscle": 0.35, "shoulders": 0.1, "legs": 0.8}]
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
	# Hoja de reacciones del final ("gestures"): aplaudir, cabeza, cintura y
	# protesta; de frente arriba y de costado abajo.
	var gestures := out.contains("gesture")
	var gesture_events := [PlayerVisual.Event.APPLAUD, PlayerVisual.Event.HEAD_HOLD,
		PlayerVisual.Event.HANDS_HIPS, PlayerVisual.Event.PROTEST]
	if gestures:
		stances = [1, 1, 1, 1, 1, 1, 1, 1]
	if shake:
		stances = [1, 1, 1, 1]
	if throw:
		stances = [1, 1]
	if builds or bodies:
		stances = []
		for k in 14:
			stances.append(1)
	if faces:
		stances = [1, 1, 1, 1, 1, 1, 1, 1]
		cam.position = Vector3(0.0, 1.66, 0.62)
		cam.look_at(Vector3(0, 1.66, 0))
		cam.fov = 32
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
		if faces:
			look["skin_color"] = PlayerData.SKIN_COLORS[i % 4]
			look["hair_color"] = PlayerData.HAIR_COLORS[[0, 3, 1, 4, 2, 0, 5, 1][i]]
			look["facial_hair"] = [0, 1, 2, 3, 4, 0, 4, 1][i]
			look["beard_color"] = look["hair_color"]
			look["hair_style"] = HairBuilder.Style.FADE
			look["long_sleeves"] = i % 2 == 1
		if bodies:
			look["body"] = body_list[i % 7]
			look["hair_style"] = HairBuilder.Style.FADE
		if kits:
			var td: TeamData = team_list[i % team_list.size()]
			look = {"shirt": td.color, "shorts": td.secondary_color, "number": [10, 7, 23, 9, 5, 14, 11, 8][i % 8],
				"pattern": td.pattern, "shirt2": td.pattern_color, "long_sleeves": (i % team_list.size()) % 2 == 1}
		v.setup(look, 3 + i)
		if uvtest:
			(v as ModelVisual).set_kit_texture(uv_tex)
		# Primero de frente, después de costado (girado 90°).
		v.rotation.y = 0.0 if i < stances.size() / 2 else PI * 0.5
		if kits:
			v.rotation.y = 0.0 if i < stances.size() / 2 else PI
		if hair:
			v.rotation.y = 0.5 if i < stances.size() / 2 else PI * 0.85
		if faces:
			v.rotation.y = [0.0, 0.35, 0.0, -0.35, 0.0, 0.5, 0.0, -0.5][i]
		if uvtest:
			v.rotation.y = [0.0, PI, PI * 0.5][i]
		v.stance = maxi(stances[i], 1)
		if stances[i] < 0:
			v.update(1.0 / 60.0, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
			v.play(PlayerVisual.Event.HIGH_FIVE)
		if shake:
			v.update(1.0 / 60.0, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
			v.play(PlayerVisual.Event.HANDSHAKE, 1.0 if i % 2 == 0 else -1.0)
		if gestures:
			v.update(1.0 / 60.0, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
			v.play(gesture_events[i % 4], 4.0)
		for f in (90 if gestures else 20):
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
