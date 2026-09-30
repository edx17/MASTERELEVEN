extends GutTest
## Modos de cámara y traducción del stick a la cancha.

var m: MatchController
var cam: MatchCamera


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	GameSettings.camera_preset = 0
	m = load("res://scenes/match/match.tscn").instantiate() as MatchController
	add_child_autofree(m)
	m.set_physics_process(false)
	for c in m.get_children():
		if c is MatchCamera:
			cam = c


func after_each() -> void:
	GameSettings.camera_preset = 0


func _preset(name: String) -> void:
	for i in cam.presets.size():
		if cam.presets[i].display_name == name:
			cam.set_preset(i, false)
			cam._apply()
			return
	fail_test("no existe el modo %s" % name)


func test_all_presets_load() -> void:
	assert_eq(cam.presets.size(), 5)


func test_tv_stick_matches_screen() -> void:
	_preset("TV")
	assert_almost_eq(cam.screen_to_world(Vector3.RIGHT).x, 1.0, 0.05, "derecha = +X")
	assert_almost_eq(cam.screen_to_world(Vector3(0, 0, -1)).z, -1.0, 0.05, "arriba = -Z (hacia la tribuna)")


func test_vertical_up_is_attack_direction() -> void:
	_preset("Vertical")
	var up := cam.screen_to_world(Vector3(0, 0, -1))
	assert_almost_eq(up.x, float(m.humans[0].team.attack_dir), 0.05, "arriba = hacia el arco rival")


func test_drone_keeps_tv_orientation() -> void:
	_preset("Dron")
	assert_almost_eq(cam.screen_to_world(Vector3.RIGHT).x, 1.0, 0.05)
	assert_almost_eq(cam.screen_to_world(Vector3(0, 0, -1)).z, -1.0, 0.05)


func test_camera_side_stand_only_casts_shadow() -> void:
	_preset("TV")
	var south := m.stadium.get_node("StandSouth")
	for child in south.get_children():
		if child is GeometryInstance3D:
			assert_eq((child as GeometryInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)


func test_near_touchline_is_in_view() -> void:
	_preset("TV")
	m.ball.place(Vector3(0, 0.11, Pitch.HALF_WIDTH - 0.5))
	cam._focus = cam.target_focus()
	cam._apply()
	var screen := cam.unproject_position(m.ball.state.pos)
	var size := cam.get_viewport().get_visible_rect().size
	assert_between(screen.y, 0.0, size.y, "la pelota en la banda cercana se ve en pantalla")
