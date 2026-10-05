extends GutTest
## Paso B: jugadores low-poly estilo WE mejorados — cuerpo paramétrico,
## identidad guardada, malla, cara, ropa y pelo.


func _data(name: String, build: int = PlayerData.Build.AUTO, cm: int = 0) -> PlayerData:
	var d := PlayerData.new()
	d.player_name = name
	d.id = name
	d.build = build
	d.height = cm
	return d


## B1: la estatura en cm manda (también en el juego) y queda en 155-205.
func test_height_drives_body_height() -> void:
	var tall := _data("Alto", PlayerData.Build.NORMAL, 198)
	var short := _data("Bajo", PlayerData.Build.NORMAL, 166)
	assert_almost_eq(tall.body_height(), 198.0 / 178.0, 0.001)
	assert_lt(short.body_height(), 1.0)
	assert_eq(_data("X", PlayerData.Build.NORMAL, 230).height_cm(), 205, "tope")
	assert_eq(_data("Y", PlayerData.Build.NORMAL, 120).height_cm(), 155, "piso")


## B1: dos jugadores del mismo físico no salen idénticos; el físico manda la
## base (los pesados tienen más masa que los flacos).
func test_body_params_vary_per_player() -> void:
	var a := _data("Uno", PlayerData.Build.NORMAL).body_params()
	var b := _data("Otro", PlayerData.Build.NORMAL).body_params()
	assert_ne(str(a), str(b), "cada uno con su cuerpo")
	var heavy := _data("Pesado", PlayerData.Build.HEAVY).body_params()
	var slim := _data("Flaco", PlayerData.Build.SLIM).body_params()
	assert_gt(float(heavy["mass"]), float(slim["mass"]) + 0.8)
	var strong := _data("Fuerte", PlayerData.Build.NORMAL)
	strong.strength = 95
	var weak := _data("Fuerte", PlayerData.Build.NORMAL)
	weak.strength = 30
	assert_gt(float(strong.body_params()["muscle"]), float(weak.body_params()["muscle"]))
	assert_eq(_data("Z", PlayerData.Build.MUSCULAR).physique_letter(), "C")


## B1: el modelo escala con la estatura, la cadera sube con piernas largas
## (los pies siguen en el piso) y el paso de la animación se compensa.
func test_model_scales_and_compensates_stride() -> void:
	if not ModelVisual.available():
		pass_test("sin modelo")
		return
	var v := ModelVisual.new()
	add_child_autofree(v)
	v.setup({"shirt": Color.WHITE, "body": {"height": 194, "mass": 0.8, "muscle": 0.5, "shoulders": 0.2, "legs": 0.6}}, 1)
	assert_almost_eq(v._height, 194.0 / 178.0, 0.001)
	assert_gt(v._leg_len, 1.0)
	assert_gt(v._hip_lift(), 0.0, "la cadera sube con las piernas largas")
	v.update(1.0 / 60.0, 3.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
	var tall_scale := v._anim.speed_scale
	var w := ModelVisual.new()
	add_child_autofree(w)
	w.setup({"shirt": Color.WHITE, "body": {"height": 165, "mass": -0.3, "muscle": 0.3, "shoulders": 0.0, "legs": -0.5}}, 2)
	w.update(1.0 / 60.0, 3.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
	assert_lt(tall_scale, w._anim.speed_scale, "el alto da pasos más largos (animación más lenta)")
	# Pesado: más ancho de cintura que el normal.
	var belly := v._skel.find_bone("spine_01")
	assert_true(v._build_scales.has(belly))
	assert_gt((v._build_scales[belly] as Vector3).length(), Vector3.ONE.length())


## B4: el aspecto es del jugador (siempre el mismo) y lo cargado manda.
func test_look_is_stable_and_overridable() -> void:
	var d := _data("Gómez")
	var a := d.look()
	var b := _data("Gómez").look()
	assert_eq(a["skin_color"], b["skin_color"], "misma piel en cada partido")
	assert_eq(a["hair_color"], b["hair_color"])
	assert_eq(a["boots"], b["boots"])
	d.skin = 3
	d.hair_color = 3
	d.boots = 3
	d.facial_hair = 4
	var c := d.look()
	assert_eq(c["skin_color"], PlayerData.SKIN_COLORS[3])
	assert_eq(c["hair_color"], PlayerData.HAIR_COLORS[3])
	assert_eq(c["boots"], PlayerData.BOOT_COLORS[3])
	assert_eq(c["facial_hair"], 4)
	# Variedad: en un plantel no son todos iguales.
	var skins := {}
	for i in 30:
		skins[_data("Jugador %d" % i).skin_tone()] = true
	assert_gt(skins.size(), 2)


## B4: el ambidiestro no tiene pierna mala.
func test_both_footed_has_no_weak_foot() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	var p := m.teams[0].players[9]
	var left_side := p.flat_pos() + p.facing.rotated(Vector3.UP, PI * 0.5) * 0.3
	var right_side := p.flat_pos() + p.facing.rotated(Vector3.UP, -PI * 0.5) * 0.3
	p.data.foot = PlayerData.Foot.RIGHT
	var weak_any := KickActions.uses_weak_foot(p, left_side) or KickActions.uses_weak_foot(p, right_side)
	assert_true(weak_any, "el diestro tiene un lado malo")
	p.data.foot = PlayerData.Foot.BOTH
	assert_false(KickActions.uses_weak_foot(p, left_side))
	assert_false(KickActions.uses_weak_foot(p, right_side))
	assert_eq(p.data.foot_name(), "Ambidiestro")


## B4: el modelo usa la piel del jugador (no una al azar).
func test_model_uses_the_player_skin() -> void:
	if not ModelVisual.available():
		pass_test("sin modelo")
		return
	var d := _data("Pérez")
	d.skin = 2
	var v := ModelVisual.new()
	add_child_autofree(v)
	var look := {"shirt": Color.WHITE}
	look.merge(d.look())
	v.setup(look, 99)
	assert_eq(v.skin_color, PlayerData.SKIN_COLORS[2])


## B2: malla clásica más fina (con UV de la ropa), cara dibujada y manga larga.
func test_classic_mesh_has_uv_and_more_detail() -> void:
	if not ModelVisual.available():
		pass_test("sin modelo")
		return
	var v := ModelVisual.new()
	add_child_autofree(v)
	v.setup({"shirt": Color.WHITE, "facial_hair": 4, "long_sleeves": true}, 7)
	var data := ClassicBody.prepare(v._skel)
	var arr: Array = data["arrays"]
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	assert_eq(uvs.size(), verts.size(), "UV en cada vértice")
	var tris := verts.size() / 3
	gut.p("cuerpo clásico: %d triángulos" % tris)
	assert_between(tris, 1500, 6000, "más fino que antes pero liviano")
	# La ropa ocupa su región de la textura (docs/KIT_UV.md).
	var in_torso := 0
	for uv in uvs:
		if uv.x < 0.5 and uv.y < 0.5:
			in_torso += 1
	assert_gt(in_torso, 100)
	if GameSettings.player_style == GameSettings.PlayerStyle.CLASSIC:
		assert_true(bool(v._body_mat.get_shader_parameter("draw_face")), "cara dibujada")
		assert_eq(int(v._body_mat.get_shader_parameter("beard")), 4)
		assert_true(bool(v._body_mat.get_shader_parameter("long_sleeves")))


## B2: manga larga con lluvia/nieve; arqueros casi siempre.
func test_long_sleeves_rule() -> void:
	var cold := MatchConditions.new()
	cold.weather = MatchConditions.Weather.SNOW
	var clear := MatchConditions.new()
	var d := _data("Ramírez")
	assert_true(Footballer.long_sleeves_for(d, false, cold), "con nieve, todos")
	var keepers := 0
	var field := 0
	for i in 40:
		var p := _data("J%d" % i)
		if Footballer.long_sleeves_for(p, true, clear):
			keepers += 1
		if Footballer.long_sleeves_for(p, false, clear):
			field += 1
	assert_gt(keepers, 25, "los arqueros casi siempre")
	assert_lt(field, 15, "con buen tiempo, pocos")
