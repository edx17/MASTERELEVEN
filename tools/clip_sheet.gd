extends SceneTree
## Hoja de cuadros de clips de Mixamo ya retargeteados (para elegir gestos).
## xvfb-run godot --rendering-method gl_compatibility -s tools/clip_sheet.gd -- --out=dir --clips=A,B

const COLS := 8
const W := 200
const H := 260

var t0 := 0.0
var t1 := -1.0

func _initialize() -> void:
	var out := "user://"
	var clips: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--clips="):
			clips = a.substr(8).split(",")
		elif a.begins_with("--range="):
			var r := a.substr(8).split(",")
			t0 = float(r[0])
			t1 = float(r[1])
	_run.call_deferred(out, clips)


func _run(out: String, clips: PackedStringArray) -> void:
	root.size = Vector2i(W, H)
	var body_scene := load(ModelVisual.BODY_PATH) as PackedScene
	var body := body_scene.instantiate() as Node3D
	root.add_child(body)
	var skel := body.find_child("Skeleton3D", true, false) as Skeleton3D
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(4.5, 1.2, 0.0)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.fov = 45
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees = Vector3(-40, 60, 0)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	floor_mi.mesh = pm
	root.add_child(floor_mi)
	var ap := AnimationPlayer.new()
	body.add_child(ap)
	ap.root_node = ap.get_path_to(body)
	var lib := AnimationLibrary.new()
	ap.add_animation_library(&"", lib)
	for c in clips:
		# Un clip de la librería (con sus opciones) o un archivo suelto.
		var spec: Dictionary = MixamoLibrary.CLIPS.get(c, {"file": c})
		var anim := MixamoLibrary._retarget(MixamoLibrary.file_path(spec["file"]), skel, spec)
		if anim == null:
			print("sin clip ", c)
			continue
		lib.add_animation(c, anim)
		var sheet := Image.create(W * COLS, H, false, Image.FORMAT_RGB8)
		for i in COLS:
			var end := anim.length if t1 < 0.0 else minf(t1, anim.length)
			var t := lerpf(t0, end, float(i) / float(COLS - 1))
			ap.play(c)
			ap.seek(t, true)
			await process_frame
			await process_frame
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(i * W, 0))
		sheet.save_png(out + "/" + c + ".png")
		print(c, " len=", anim.length, " cuadros de ", t0, " a ", anim.length if t1 < 0.0 else t1)
	quit()
