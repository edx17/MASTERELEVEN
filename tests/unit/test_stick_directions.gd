extends GutTest
## Stick en 8/16 rumbos fijos (estilo WE2002).


func test_eight_directions_snaps_to_45_degrees() -> void:
	var s := StickDirections.new(8)
	var out := s.apply(Vector3(cos(0.3), 0.0, sin(0.3)))
	assert_almost_eq(out.z, 0.0, 0.001, "20° se lleva al rumbo de 0°")
	s = StickDirections.new(8)
	out = s.apply(Vector3(cos(0.6), 0.0, sin(0.6)))
	assert_almost_eq(Vector2(out.x, out.z).angle(), PI / 4.0, 0.001, "34° se lleva a la diagonal")


func test_sixteen_directions_are_finer() -> void:
	var s := StickDirections.new(16)
	var out := s.apply(Vector3(cos(0.3), 0.0, sin(0.3)))
	assert_almost_eq(Vector2(out.x, out.z).angle(), TAU / 16.0, 0.001)


func test_keeps_intensity_and_dead_zone() -> void:
	var s := StickDirections.new(8)
	var out := s.apply(Vector3(0.5, 0.0, 0.1))
	assert_almost_eq(Vector2(out.x, out.z).length(), Vector2(0.5, 0.1).length(), 0.001, "caminar con el stick apenas inclinado")
	assert_eq(s.apply(Vector3(0.05, 0.0, 0.0)), Vector3(0.05, 0.0, 0.0), "stick suelto pasa igual")
	assert_eq(s.sector, -1)


func test_hysteresis_avoids_zigzag_near_the_border() -> void:
	var s := StickDirections.new(8)
	s.apply(Vector3(1.0, 0.0, 0.0))
	# 24° está pasando el borde (22,5°) por poco: sigue en 0°.
	var out := s.apply(Vector3(cos(deg_to_rad(24.0)), 0.0, sin(deg_to_rad(24.0))))
	assert_almost_eq(out.z, 0.0, 0.001)
	# 35° ya es claramente la diagonal.
	out = s.apply(Vector3(cos(deg_to_rad(35.0)), 0.0, sin(deg_to_rad(35.0))))
	assert_almost_eq(Vector2(out.x, out.z).angle(), PI / 4.0, 0.001)


func test_free_mode_passes_through() -> void:
	var s := StickDirections.new(0)
	var v := Vector3(cos(0.3), 0.0, sin(0.3))
	assert_eq(s.apply(v), v)
