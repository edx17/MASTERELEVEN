extends GutTest

## Modelo humano con esqueleto (CC0): animación por velocidad, gestos sin
## acumulación, colores por zona y costo acotado.


func after_each() -> void:
	GameSettings.player_style = GameSettings.PlayerStyle.WE


func _visual() -> ModelVisual:
	var v := ModelVisual.new()
	add_child_autofree(v)
	v.setup({"shirt": Color.RED, "shorts": Color.BLACK}, 3)
	v._anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return v


func _step(v: ModelVisual, speed: float, frames: int) -> void:
	for i in frames:
		v.update(1.0 / 60.0, speed, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
		v._anim.advance(1.0 / 60.0)


func test_models_are_imported() -> void:
	assert_true(ModelVisual.available(), "assets/models/players + assets/animations importados")


func test_locomotion_follows_speed() -> void:
	var v := _visual()
	_step(v, 0.0, 5)
	assert_eq(v._current, "Stand_%d" % ModelVisual.Stance.RELAXED, "parado derecho (no en guardia), con los brazos al costado")
	_step(v, 4.5, 5)
	# Con la tanda nueva de Mixamo (si está) usa su trote y su sprint.
	assert_has(["Jog_Fwd", "mx/jog"], v._current)
	_step(v, 8.0, 5)
	assert_has(["Sprint", "mx/sprint"], v._current)


func test_gestures_do_not_accumulate() -> void:
	var v := _visual()
	var b := v._skel.find_bone("spine_03")
	var heights: Array[float] = []
	for i in 6:
		_step(v, 0.0, 30)
		v._skel.force_update_all_bone_transforms()
		heights.append(v._skel.get_bone_global_pose(b).origin.y)
	assert_gt(heights.min(), 1.15, "el torso no se va doblando cuadro a cuadro (%s)" % [heights])


func test_kick_moves_the_right_leg_forward() -> void:
	var v := _visual()
	_step(v, 0.0, 10)
	var foot := v._skel.find_bone("foot_r")
	v._skel.force_update_all_bone_transforms()
	var before := v._skel.get_bone_global_pose(foot).origin.z
	v.play(PlayerVisual.Event.KICK)
	var max_z := before
	for i in 20:
		_step(v, 0.0, 1)
		v._skel.force_update_all_bone_transforms()
		max_z = maxf(max_z, v._skel.get_bone_global_pose(foot).origin.z)
	assert_gt(max_z - before, 0.25, "el pie derecho sale hacia adelante (+Z)")


func test_body_regions() -> void:
	assert_eq(ModelVisual._region(Vector3(0, 0.05, 0.05)), 4, "botines")
	assert_eq(ModelVisual._region(Vector3(0.1, 0.3, 0)), 2, "medias")
	assert_eq(ModelVisual._region(Vector3(0.1, 0.8, 0)), 1, "short")
	assert_eq(ModelVisual._region(Vector3(0, 1.2, 0.1)), 0, "camiseta")
	assert_eq(ModelVisual._region(Vector3(0, 1.65, 0.08)), 3, "cara")
	assert_eq(ModelVisual._region(Vector3(0.85, 1.4, 0)), 6, "manos")


func test_22_animated_players_fit_the_frame_budget() -> void:
	var vs: Array[ModelVisual] = []
	for i in 22:
		vs.append(_visual())
	var t := Time.get_ticks_usec()
	for f in 30:
		for v in vs:
			v.update(1.0 / 60.0, 6.0, 8.4, PlayerVisual.Pose.NORMAL, 2.0)
			v._anim.advance(1.0 / 60.0)
			v._skel.force_update_all_bone_transforms()
	var ms := (Time.get_ticks_usec() - t) / 1000.0 / 30.0
	gut.p("animación de 22 jugadores: %.2f ms por cuadro" % ms)
	assert_lt(ms, 6.0, "bien por debajo de 16,6 ms (60 FPS)")


func test_mixamo_clips_when_present() -> void:
	# Las animaciones de Mixamo no van en el repo: el test sólo corre si están.
	var lib := MixamoLibrary.library(ModelVisual._body_scene)
	if lib == null:
		pass_test("sin animaciones de Mixamo en esta copia")
		return
	var v := _visual()
	_step(v, 0.0, 5)
	v.play(PlayerVisual.Event.KICK)
	assert_has(["shot", "kick"], v._clip, "la patada usa la animación de Mixamo (el remate si está)")
	var foot := v._skel.find_bone("foot_r")
	var max_z := -INF
	for i in 20:
		_step(v, 0.0, 1)
		v._skel.force_update_all_bone_transforms()
		max_z = maxf(max_z, v._skel.get_bone_global_pose(foot).origin.z)
	assert_gt(max_z, 0.3, "el pie derecho sale adelante con la animación retargeteada")
	v.play(PlayerVisual.Event.DIVE_RIGHT)
	assert_eq(v._clip, "gk_dive_px")
	var max_x := 0.0
	for i in 60:
		_step(v, 0.0, 1)
		v._skel.force_update_all_bone_transforms()
		max_x = maxf(max_x, v._skel.get_bone_global_pose(v._skel.find_bone("pelvis")).origin.x)
	assert_gt(max_x, 0.3, "vuela de costado hacia +X")
	assert_eq(v._clip, "", "y la estirada termina rápido (no queda flotando)")


func _mixamo_or_skip() -> bool:
	if MixamoLibrary.library(ModelVisual._body_scene) == null:
		pass_test("sin animaciones de Mixamo en esta copia")
		return false
	return true


func test_tripped_player_falls_and_gets_up_in_time() -> void:
	if not _mixamo_or_skip():
		return
	var v := _visual()
	v.tripped = true
	var left := 1.7
	var clips: Array[String] = []
	while left > 0.0:
		v.recover_left = left
		v.update(1.0 / 60.0, 0.0, 8.4, PlayerVisual.Pose.FALLEN, 0.0)
		v._anim.advance(1.0 / 60.0)
		if clips.is_empty() or clips[-1] != v._clip:
			clips.append(v._clip)
		left -= 1.0 / 60.0
	assert_eq(clips.slice(0, 2), ["trip", "get_up"] as Array[String], "se cae y después se levanta")
	v.tripped = false
	v.recover_left = 0.0
	_step(v, 0.0, 6)
	assert_eq(v._clip, "", "al volver a jugar, vuelve la locomoción")


func _has_clip(clip: String) -> bool:
	return MixamoLibrary.file_path(MixamoLibrary.CLIPS[clip]["file"]) != ""


func test_new_gestures_use_their_clips() -> void:
	if not _mixamo_or_skip():
		return
	var v := _visual()
	_step(v, 0.0, 5)
	# Sólo se exigen los clips cuyos archivos están (si falta uno, ese gesto
	# se hace por código).
	if _has_clip("tackle"):
		v.play(PlayerVisual.Event.TACKLE)
		assert_eq(v._clip, "tackle", "entrada de pie")
		_step(v, 0.0, 60)
	if _has_clip("receive"):
		v.play(PlayerVisual.Event.RECEIVE)
		assert_eq(v._clip, "receive", "control con la suela")
	_step(v, 0.0, 60)
	v.keeper = true
	for ev in [[PlayerVisual.Event.CATCH_HIGH, "gk_catch_high"], [PlayerVisual.Event.CATCH_LOW, "gk_catch_low"],
			[PlayerVisual.Event.BLOCK, "gk_block"], [PlayerVisual.Event.ROLL, "gk_roll"]]:
		if not _has_clip(ev[1]):
			continue
		v.play(ev[0])
		assert_eq(v._clip, ev[1])
		_step(v, 0.0, 150)
	v.play(PlayerVisual.Event.CELEBRATE)
	var party := v._clip
	assert_has(["celebrate", "celebrate2"], party, "uno de los festejos al azar")
	v.play(PlayerVisual.Event.KICK)
	assert_eq(v._clip, party, "el festejo no se corta")


func test_keeper_side_steps_when_moving_sideways() -> void:
	if not _mixamo_or_skip():
		return
	var v := _visual()
	v.keeper = true
	v.side_speed = 2.0
	_step(v, 2.0, 5)
	assert_true(v._current.begins_with("mx/gk_side"), "paso lateral (%s)" % v._current)
	v.side_speed = -2.0
	_step(v, 2.0, 5)
	var other := v._current
	v.side_speed = 2.0
	_step(v, 2.0, 5)
	assert_ne(other, v._current, "cada lado usa su versión")


func test_mixamo_file_names_accept_windows_numbering() -> void:
	var c := MixamoLibrary.file_candidates("Goalkeeper_Catch_1")
	assert_has(c, "Goalkeeper_Catch_1")
	assert_has(c, "Goalkeeper Catch 1")
	assert_has(c, "Goalkeeper Catch (1)")
	assert_eq(MixamoLibrary.file_candidates("Soccer_Pass").size(), 2, "sin número, sin variante numerada")


func test_stances_and_high_five_move_the_arms() -> void:
	var v := _visual()
	var arm: int = v._bones["upperarm_r"]
	var rots := {}
	for st in [ModelVisual.Stance.RELAXED, ModelVisual.Stance.HEART, ModelVisual.Stance.BEHIND, ModelVisual.Stance.HIPS]:
		v.stance = st
		_step(v, 0.0, 3)
		rots[st] = v._skel.get_bone_pose_rotation(arm)
	assert_false(rots[ModelVisual.Stance.RELAXED].is_equal_approx(rots[ModelVisual.Stance.HEART]), "mano en el pecho")
	assert_false(rots[ModelVisual.Stance.RELAXED].is_equal_approx(rots[ModelVisual.Stance.BEHIND]), "manos atrás")
	v.stance = ModelVisual.Stance.RELAXED
	_step(v, 0.0, 3)
	var hand_down: Vector3 = v._skel.get_bone_global_pose(v._bones["hand_r"]).origin
	v.play(PlayerVisual.Event.HIGH_FIVE)
	_step(v, 0.0, 22)
	var hand_up: Vector3 = v._skel.get_bone_global_pose(v._bones["hand_r"]).origin
	assert_gt(hand_up.y - hand_down.y, 0.5, "choca los cinco: la mano sube")


func test_standing_never_shows_the_t_pose() -> void:
	var v := _visual()
	# Parado, y también a mitad de la mezcla de parado a caminar: las manos
	# quedan abajo (en la pose en T están a la altura de los hombros).
	_step(v, 0.0, 10)
	var shoulder: float = v._skel.get_bone_global_pose(v._bones["upperarm_l"]).origin.y
	for frames in [0, 4]:
		if frames > 0:
			_step(v, 1.0, frames)
		for hand in ["hand_l", "hand_r"]:
			var y: float = v._skel.get_bone_global_pose(v._bones[hand]).origin.y
			assert_lt(y, shoulder - 0.3, "%s abajo (cuadro %d de la mezcla)" % [hand, frames])


func test_kit_is_painted_on_the_shirt() -> void:
	# Diseño, número y escudo van en el material de la camiseta (no hay un
	# cartel con el número pegado a la espalda).
	var v := ModelVisual.new()
	add_child_autofree(v)
	v.setup({"shirt": Color.RED, "shorts": Color.BLACK, "number": 23, "pattern": 1, "shirt2": Color.BLACK}, 5)
	assert_null(v._number_label)
	assert_eq(v._body_mat.get_shader_parameter("number"), 23)
	assert_eq(v._body_mat.get_shader_parameter("pattern"), 1)
	assert_eq(v._body_mat.get_shader_parameter("shirt2"), Color.BLACK)
	var atlas := ModelVisual.digit_atlas()
	assert_eq(atlas.get_width(), atlas.get_height() * 70 / 9, "10 dígitos de 7x9")
	# La posición de reposo viaja en la malla (CUSTOM0).
	var body := v._skel.find_child(ModelVisual.BODY_MESH, false, false) as MeshInstance3D
	assert_ne(body.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM0, 0)


func test_team_kits_have_designs() -> void:
	var striped := 0
	for path in GameSettings.team_paths():
		var td: TeamData = load(path)
		if td.pattern > 0:
			striped += 1
	assert_gte(striped, 4, "varios equipos con camisetas con diseño")


func test_classic_body_wears_the_kit() -> void:
	# Cuerpo clásico (pocos polígonos, proporciones normales), con la misma
	# ropa: el material del cuerpo con diseño y número.
	GameSettings.player_style = GameSettings.PlayerStyle.CLASSIC
	var v := ModelVisual.new()
	add_child_autofree(v)
	v.setup({"shirt": Color.RED, "shorts": Color.BLACK, "number": 8, "pattern": 1, "shirt2": Color.BLACK}, 9)
	assert_not_null(v._classic)
	assert_eq(v._classic.material_override, v._body_mat)
	var body := v._skel.find_child(ModelVisual.BODY_MESH, false, false) as MeshInstance3D
	assert_false(body.visible, "el modelo musculoso queda oculto")
	var tris: int = v._classic.mesh.surface_get_array_len(0) / 3
	# B15: malla más fina (siluetas, orejas, nariz), sigue siendo liviana.
	assert_between(tris, 200, 2500, "pocos polígonos (%d)" % tris)
	assert_ne(v._classic.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM0, 0, "con la posición de reposo para la ropa")


## Diseño Definitivo WE (por defecto): el modelo de Blender sobre el
## esqueleto del juego, con la ropa del club, pelado y sin cara.
func test_we_design_is_the_default_and_wears_the_kit() -> void:
	assert_eq(GameSettings.player_style, GameSettings.PlayerStyle.WE)
	if not ModelVisual.available() or not WeBody.available():
		pass_test("sin modelo")
		return
	var v := ModelVisual.new()
	add_child_autofree(v)
	v.setup({"shirt": Color.RED, "shorts": Color.BLACK, "number": 8, "pattern": 1, "shirt2": Color.BLACK,
		"hair_style": HairBuilder.Style.AFRO}, 9)
	assert_not_null(v._classic)
	assert_eq(String(v._classic.name), "WeBody")
	assert_eq(v._classic.material_override, v._body_mat)
	var body := v._skel.find_child(ModelVisual.BODY_MESH, false, false) as MeshInstance3D
	assert_false(body.visible, "el modelo musculoso queda oculto")
	assert_false(v.hair_node != null and v.hair_node.visible, "pelado (sin peinado)")
	assert_false(bool(v._body_mat.get_shader_parameter("draw_face")), "sin cara por ahora")
	var mesh: Mesh = v._classic.mesh
	var tris: int = mesh.surface_get_array_len(0) / 3
	if mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_INDEX:
		tris = mesh.surface_get_array_index_len(0) / 3
	assert_between(tris, 300, 2000, "pocos polígonos (%d)" % tris)
	assert_ne(mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM0, 0, "con la posición de reposo para la ropa")
	# Todas las zonas de la ropa del modelo llegan al shader.
	var arr := mesh.surface_get_arrays(0)
	var zones := {}
	var torso := 0
	for c: Color in arr[Mesh.ARRAY_COLOR]:
		zones[int(round(c.r * 10.0))] = true
		if c.g > 0.5:
			torso += 1
	for z in [0, 1, 2, 3, 4, 6]:
		assert_true(zones.has(z), "zona %d" % z)
	assert_gt(torso, 20, "torso de la camiseta (diseño y número)")
	# El modelo mide lo mismo que el esqueleto (1,81 m, en pose T).
	var aabb := mesh.get_aabb()
	assert_almost_eq(aabb.end.y, 1.81, 0.03)
	assert_almost_eq(aabb.position.y, 0.0, 0.02)


## Cada vértice del Diseño Definitivo WE se mueve con huesos del juego (los
## pesos suman 1) y la piel apunta a huesos existentes.
func test_we_body_skin_maps_to_game_bones() -> void:
	if not ModelVisual.available() or not WeBody.available():
		pass_test("sin modelo")
		return
	var v := ModelVisual.new()
	add_child_autofree(v)
	v.setup({"shirt": Color.WHITE}, 3)
	var data := WeBody.prepare(v._skel)
	var skin: Skin = data["skin"]
	var names := {}
	for i in skin.get_bind_count():
		names[v._skel.get_bone_name(skin.get_bind_bone(i))] = true
	for n in ["pelvis", "spine_03", "Head", "upperarm_l", "lowerarm_r", "hand_l", "thigh_r", "calf_l", "foot_r", "ball_l"]:
		assert_true(names.has(n), "hueso %s" % n)
	var arr: Array = data["arrays"]
	var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := w.size() / (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for i in range(0, w.size(), per):
		var sum := 0.0
		for j in per:
			sum += w[i + j]
		assert_almost_eq(sum, 1.0, 0.01)
		if absf(sum - 1.0) > 0.01:
			break
