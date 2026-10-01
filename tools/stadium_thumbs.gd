extends Node
## Miniaturas de los estadios para el menú (assets/ui/stadiums/<n>.png): una
## toma aérea de cada estilo de StadiumStyles, de tarde y despejado.
## xvfb-run godot --rendering-method forward_plus -- --stadium-thumbs=res://assets/ui/stadiums

const W := 384
const H := 216

var out_dir := "res://assets/ui/stadiums"
var root: Window


func _ready() -> void:
	root = get_tree().root
	var menu := get_tree().current_scene
	if menu != null:
		menu.queue_free()
	_run.call_deferred()


func _run() -> void:
	var frame := get_tree().process_frame
	root.size = Vector2i(W, H)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	for i in StadiumStyles.STYLES.size():
		StadiumStyles.current = StadiumStyles.get_style(i)
		var world := Node3D.new()
		root.add_child(world)
		var atmosphere := Atmosphere.new()
		world.add_child(atmosphere)
		atmosphere.setup(MatchConditions.create(MatchConditions.TimeOfDay.AFTERNOON, MatchConditions.Weather.CLEAR, 0.0, 0.0, 0.0))
		world.add_child(PitchBuilder.build(atmosphere.grass_params()))
		world.add_child(StadiumBuilder.build(load(GameSettings.DEFAULT_HOME), load(GameSettings.DEFAULT_AWAY)))
		# Toma aérea desde una esquina, alta, para que se vea la forma del estadio.
		var cam := Camera3D.new()
		world.add_child(cam)
		cam.fov = 50.0
		cam.position = Vector3(105.0, 82.0, 118.0)
		cam.look_at(Vector3(0.0, 4.0, 0.0))
		cam.make_current()
		for f in 8:
			await frame
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var path := out_dir.path_join("%d.png" % i)
		img.save_png(ProjectSettings.globalize_path(path))
		print("miniatura: ", path)
		world.queue_free()
		await frame
	get_tree().quit()
