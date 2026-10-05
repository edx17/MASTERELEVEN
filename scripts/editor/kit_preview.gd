class_name KitPreview
extends SubViewportContainer
## Vista 3D de un jugador para el Editor (camisetas, botines, aspecto): el
## mismo modelo del juego en un mundo aparte, girando despacio (o al ángulo
## del deslizador).

var _vp: SubViewport
var _model: Node3D
var spin := true
var angle := 0.0


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(260, 360)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.size = Vector2i(260, 360)
	_vp.transparent_bg = false
	add_child(_vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.05, 3.6)
	cam.fov = 38
	_vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.95, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	_vp.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.2, 0.27)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.65, 0.65, 0.7)
	env.environment = e
	_vp.add_child(env)


## Muestra un jugador con estos colores (como ModelVisual.setup) y, si hay,
## la plantilla de camiseta.
func show_player(colors: Dictionary, tex: Texture2D = null, seed: int = 7) -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	if not ModelVisual.available():
		return
	var v := ModelVisual.new()
	_vp.add_child(v)
	v.setup(colors, seed)
	if tex != null:
		v.set_kit_texture(tex)
	_model = v


func _process(dt: float) -> void:
	if _model == null:
		return
	if spin:
		angle += dt * 0.6
	_model.rotation.y = angle
	(_model as ModelVisual).update(dt, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
