extends GutTest
## Modelo humano con esqueleto (CC0): animación por velocidad, gestos sin
## acumulación, colores por zona y costo acotado.

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
	assert_eq(v._current, "Jog_Fwd")
	_step(v, 8.0, 5)
	assert_eq(v._current, "Sprint")


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
	assert_eq(v._clip, "kick", "la patada usa la animación de Mixamo")
	var foot := v._skel.find_bone("foot_r")
	var max_z := -INF
	for i in 20:
		_step(v, 0.0, 1)
		v._skel.force_update_all_bone_transforms()
		max_z = maxf(max_z, v._skel.get_bone_global_pose(foot).origin.z)
	assert_gt(max_z, 0.3, "el pie derecho sale adelante con la animación retargeteada")
	v.play(PlayerVisual.Event.DIVE_RIGHT)
	assert_eq(v._clip, "gk_dive_px")
	for i in 60:
		_step(v, 0.0, 1)
	v._skel.force_update_all_bone_transforms()
	var pelvis := v._skel.get_bone_global_pose(v._skel.find_bone("pelvis")).origin
	assert_gt(pelvis.x, 0.3, "vuela de costado hacia +X")


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


func test_new_gestures_use_their_clips() -> void:
	if not _mixamo_or_skip():
		return
	var v := _visual()
	_step(v, 0.0, 5)
	v.play(PlayerVisual.Event.TACKLE)
	assert_eq(v._clip, "tackle", "entrada de pie")
	_step(v, 0.0, 60)
	v.play(PlayerVisual.Event.RECEIVE)
	assert_eq(v._clip, "receive", "control con la suela")
	_step(v, 0.0, 60)
	v.keeper = true
	for ev in [[PlayerVisual.Event.CATCH_HIGH, "gk_catch_high"], [PlayerVisual.Event.CATCH_LOW, "gk_catch_low"],
			[PlayerVisual.Event.BLOCK, "gk_block"], [PlayerVisual.Event.ROLL, "gk_roll"]]:
		v.play(ev[0])
		assert_eq(v._clip, ev[1])
		_step(v, 0.0, 150)
	v.play(PlayerVisual.Event.CELEBRATE)
	assert_eq(v._clip, "celebrate")
	v.play(PlayerVisual.Event.KICK)
	assert_eq(v._clip, "celebrate", "el festejo no se corta")


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
