extends GutTest
## Estadios (4 estilos, túnel con hueco y sin muro en la salida), peinados con
## volumen y físicos de los jugadores.


func test_every_stadium_builds_with_a_tunnel_and_an_open_exit() -> void:
	for i in StadiumStyles.STYLES.size():
		var style := StadiumStyles.get_style(i)
		var st := StadiumBuilder.build(null, null, style)
		add_child_autofree(st)
		var south := st.get_node("StandSouth")
		assert_not_null(south.get_node_or_null("Tunnel"), "%s: túnel" % style["name"])
		assert_almost_eq(StadiumBuilder.tunnel_z, Pitch.HALF_WIDTH + float(style["gap"]), 0.01)
		# Nada sólido en el camino de salida (x = 0, de la boca a la cancha).
		for child in st.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
				var mi := child as MeshInstance3D
				var size: Vector3 = (mi.mesh as BoxMesh).size
				var aabb := AABB(mi.position - size * 0.5, size)
				var crosses := aabb.has_point(Vector3(0.0, 0.5, Pitch.HALF_WIDTH + float(style["wall"])))
				assert_false(crosses, "%s: el muro no tapa la salida del túnel" % style["name"])


func test_corner_stands_only_in_closed_stadiums() -> void:
	var open := StadiumBuilder.build(null, null, StadiumStyles.get_style(0))
	var closed := StadiumBuilder.build(null, null, StadiumStyles.get_style(1))
	add_child_autofree(open)
	add_child_autofree(closed)
	assert_null(open.get_node_or_null("StandNorthEast"))
	assert_not_null(closed.get_node_or_null("StandNorthEast"))
	var towers := StadiumBuilder.build(null, null, StadiumStyles.get_style(3))
	add_child_autofree(towers)
	assert_not_null(towers.get_node_or_null("Towers"))


func test_hair_styles_have_volume_except_shaved() -> void:
	for style in HairBuilder.Style.size():
		var m := HairBuilder.mesh(style)
		if style == HairBuilder.Style.SHAVED:
			assert_null(m)
			continue
		assert_not_null(m, HairBuilder.NAMES[style])
		if style == HairBuilder.Style.HORSESHOE:
			continue # pelado arriba: sólo la corona de los costados
		var top := m.get_aabb().end.y
		assert_gt(top, HairBuilder.CENTER.y + HairBuilder.RADII.y - 0.02, "%s cubre la cabeza" % HairBuilder.NAMES[style])
	# Largos: llegan por debajo de la nuca.
	assert_lt(HairBuilder.mesh(HairBuilder.Style.LONG_PARTED).get_aabb().position.y, 1.52)
	assert_lt(HairBuilder.mesh(HairBuilder.Style.DREADS).get_aabb().position.y, 1.55)


func test_body_builds_change_height_and_width() -> void:
	ModelVisual.available()
	var heights := {}
	var bellies := {}
	for b in [PlayerData.Build.NORMAL, PlayerData.Build.HEAVY, PlayerData.Build.TALL, PlayerData.Build.SHORT]:
		var v := ModelVisual.new()
		add_child_autofree(v)
		v.setup({"shirt": Color.RED, "build": b, "hair_style": HairBuilder.Style.SHAVED}, 2)
		heights[b] = v._height
		bellies[b] = v._build_scales.get(v._skel.find_bone("spine_01"), Vector3.ONE)
	assert_gt(heights[PlayerData.Build.TALL], heights[PlayerData.Build.NORMAL])
	assert_lt(heights[PlayerData.Build.SHORT], heights[PlayerData.Build.NORMAL])
	assert_gt(bellies[PlayerData.Build.HEAVY].z, 1.2, "panza")


func test_auto_build_follows_attributes() -> void:
	var gk := PlayerData.new()
	gk.position = PlayerData.Position.GK
	assert_true(gk.visual_build() in [PlayerData.Build.TALL, PlayerData.Build.STOCKY])
	var strong := PlayerData.new()
	strong.strength = 85
	assert_true(strong.visual_build() in [PlayerData.Build.MUSCULAR, PlayerData.Build.STOCKY])
	var chosen := PlayerData.new()
	chosen.build = PlayerData.Build.HEAVY
	assert_eq(chosen.visual_build(), PlayerData.Build.HEAVY)


func test_rain_falls_diagonally_with_wind() -> void:
	var calm := Atmosphere.new()
	add_child_autofree(calm)
	calm.setup(MatchConditions.create(MatchConditions.TimeOfDay.AFTERNOON, MatchConditions.Weather.RAIN, 0.0, 0.0, 0.6))
	var windy := Atmosphere.new()
	add_child_autofree(windy)
	windy.setup(MatchConditions.create(MatchConditions.TimeOfDay.AFTERNOON, MatchConditions.Weather.RAIN, 9.0, 90.0, 0.6))
	var d0: Vector3 = (calm.precipitation.process_material as ParticleProcessMaterial).direction
	var d1: Vector3 = (windy.precipitation.process_material as ParticleProcessMaterial).direction
	assert_lt(Vector2(d0.x, d0.z).length(), 0.05, "sin viento cae derecha")
	assert_gt(Vector2(d1.x, d1.z).length(), 0.4, "con viento fuerte, en diagonal")


func test_at_night_the_stadium_casts_no_shadows() -> void:
	var st := StadiumBuilder.build(null, null, StadiumStyles.get_style(0))
	add_child_autofree(st)
	StadiumBuilder.disable_shadows(st)
	StadiumBuilder.set_camera_side(st, "StandSouth")
	for n in st.find_children("*", "GeometryInstance3D", true, false):
		assert_eq((n as GeometryInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, n.name)
