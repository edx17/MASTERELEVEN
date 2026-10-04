extends GutTest
## Escenarios: el predio del Club House y el estadio ovalado gigante.


func _oval() -> Node3D:
	var td: TeamData = load("res://data/teams/aurora.tres")
	var away: TeamData = load("res://data/teams/halcones.tres")
	var root := OvalStadiumBuilder.build(td, away, StadiumStyles.STYLES[StadiumStyles.STYLES.size() - 1])
	add_child_autofree(root)
	return root


func test_oval_stadium_has_four_sectors_tiers_and_roof() -> void:
	var st: Dictionary = StadiumStyles.STYLES[StadiumStyles.STYLES.size() - 1]
	assert_true(st.get("oval", false))
	assert_false(String(st["name"]).to_lower().contains("monumental"), "nombre inventado")
	var root := _oval()
	for n in ["StandNorth", "StandSouth", "StandWest", "StandEast"]:
		var s := root.get_node_or_null(n)
		assert_not_null(s, n)
		assert_not_null(s.get_node_or_null("Steps"))
		assert_not_null(s.get_node_or_null("Crowd"), "público en " + n)
	for n in ["Roof", "RoofRedLine", "Skywalk", "VColumns", "Screen_E", "Screen_W", "Surroundings"]:
		assert_not_null(root.find_child(n, true, false), n)
	var leds := root.find_children("Led*", "MeshInstance3D", true, false)
	assert_eq(leds.size(), 8, "anillo LED y cinta LED en los cuatro sectores")
	for l in leds:
		var mi := l as MeshInstance3D
		assert_gt(mi.mesh.surface_get_array_len(0), 0, "%s/%s" % [mi.get_parent().name, mi.name])
	# Cuatro bandejas: la 4.ª arranca bien arriba de la 1.ª.
	assert_gt(OvalStadiumBuilder.tier_front(3).y, 25.0)
	# Cancha hundida: la explanada está a nivel de calle y no tapa la cancha.
	var plaza := root.find_child("Plaza", true, false) as MeshInstance3D
	var verts: PackedVector3Array = plaza.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in verts:
		assert_false(absf(v.x) < Pitch.HALF_LENGTH + 5.0 and absf(v.z) < Pitch.HALF_WIDTH + 5.0, "sin piso sobre la cancha")
		if absf(v.x) < Pitch.HALF_LENGTH + 5.0 and absf(v.z) < Pitch.HALF_WIDTH + 5.0:
			break
	assert_almost_eq(StadiumBuilder.tunnel_z, OvalStadiumBuilder.B0 - 0.2, 0.01, "túnel único central")
	# Las esquinas de la cancha (con lugar para el córner) quedan adentro del muro.
	var corner := Vector2(Pitch.HALF_LENGTH + 2.5, Pitch.HALF_WIDTH + 2.5)
	var inside := pow(corner.x / OvalStadiumBuilder.A0, OvalStadiumBuilder.SHAPE) + pow(corner.y / OvalStadiumBuilder.B0, OvalStadiumBuilder.SHAPE)
	assert_lt(inside, 1.0, "el muro no se mete en las esquinas")


func test_oval_lights_hang_from_the_roof() -> void:
	var st: Dictionary = StadiumStyles.STYLES[StadiumStyles.STYLES.size() - 1]
	var f := StadiumStyles.flood_layout(st)
	assert_false(f[3], "sin mástiles")
	assert_gt(f[2], 30.0)


func test_club_house_is_a_training_complex() -> void:
	var td: TeamData = load("res://data/teams/aurora.tres")
	var root := ClubHouseBuilder.build(td)
	add_child_autofree(root)
	for n in ["ClubHouse", "MiniStand", "ClubWall", "SidePitch_L", "SidePitch_R", "Horizon"]:
		assert_not_null(root.find_child(n, true, false), n)
	var labels := root.find_child("ClubWall", true, false).find_children("*", "Label3D", true, false)
	assert_gt(labels.size(), 3)
	assert_eq((labels[0] as Label3D).text, td.team_name.to_upper(), "el nombre del club en el vallado")
	var plain := ClubHouseBuilder.build(null)
	add_child_autofree(plain)
	var l2 := plain.find_child("ClubWall", true, false).find_children("*", "Label3D", true, false)
	assert_eq((l2[0] as Label3D).text, "MASTER ELEVEN")
