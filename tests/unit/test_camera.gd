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
	assert_eq(cam.presets.size(), 7, "WE, TV, Amplia, Lejana, Cercana, Vertical y Dron")


func test_we_is_default_and_stick_matches_screen() -> void:
	# Cámara por defecto como la referencia (alta, lejana, lente cerrada).
	assert_eq(cam.config.display_name, "WE")
	assert_almost_eq(cam.screen_to_world(Vector3.RIGHT).x, 1.0, 0.05, "derecha = +X")
	assert_almost_eq(cam.screen_to_world(Vector3(0, 0, -1)).z, -1.0, 0.05, "arriba = -Z")


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
		if not child is GeometryInstance3D:
			continue
		var g := child as GeometryInstance3D
		if g.get_meta("base_shadow", 1) == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			# Público y butacas: no proyectan sombra, así que ni se dibujan.
			assert_false(g.visible, "%s oculto" % g.name)
		else:
			assert_eq(g.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	# La tribuna de enfrente: el público se ve pero no proyecta sombra.
	var crowd := m.stadium.get_node("StandNorth/Crowd") as GeometryInstance3D
	assert_true(crowd.visible)
	assert_eq(crowd.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_near_touchline_is_in_view() -> void:
	_preset("TV")
	m.ball.place(Vector3(0, 0.11, Pitch.HALF_WIDTH - 0.5))
	cam._focus = cam.target_focus()
	cam._apply()
	var screen := cam.unproject_position(m.ball.state.pos)
	var size := cam.get_viewport().get_visible_rect().size
	assert_between(screen.y, 0.0, size.y, "la pelota en la banda cercana se ve en pantalla")
