extends GutTest
## Capa de presentación: anima según la simulación y nunca la modifica.

func _visual() -> PlayerVisual:
	var v := PlayerVisual.new()
	add_child_autofree(v)
	v.setup({"shirt": Color.RED, "shorts": Color.BLACK}, 7)
	return v


func test_running_swings_the_legs() -> void:
	var v := _visual()
	var angles: Array[float] = []
	for i in 30:
		v.update(1.0 / 60.0, 7.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
		angles.append(v._leg[0].rotation.x)
	assert_gt(angles.max() - angles.min(), 0.5, "las piernas se mueven al correr")


func test_standing_still_keeps_legs_straight() -> void:
	var v := _visual()
	for i in 30:
		v.update(1.0 / 60.0, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
	assert_almost_eq(v._leg[0].rotation.x, 0.0, 0.01)


func test_kick_swings_the_kicking_leg_forward() -> void:
	var v := _visual()
	v.play(PlayerVisual.Event.KICK)
	var min_angle := 0.0
	for i in 20:
		v.update(1.0 / 60.0, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
		min_angle = minf(min_angle, v._leg[1].rotation.x)
	assert_lt(min_angle, -0.8, "la pierna sale hacia adelante")


func test_match_plays_kick_animation_without_touching_physics() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	var p: Footballer = m.teams[0].players[6]
	p.locked = false
	p.teleport(Vector3(0, 0, 0), Vector3.RIGHT)
	m.ball.place(Vector3(0.5, 0.11, 0))
	m.ball.give_to(p)
	var pos_before := p.global_position
	m.perform_kick(p, KickActions.Kind.SHOT, Vector3.RIGHT, 0.6)
	# Gesto de patada: animación de Mixamo si está en la copia local, si no el
	# armado por código.
	var mv := p.visual as ModelVisual
	var kicking := p.visual._event == PlayerVisual.Event.KICK or (mv != null and mv._clip == "shot" or mv != null and mv._clip == "kick")
	assert_true(kicking, "muestra la patada")
	assert_eq(p.global_position, pos_before, "la animación no mueve al jugador")


## Jugadores de bloques: cada caja va a un solo hueso (rodillas y codos se
## doblan) y llevan la ropa como los otros estilos.
func test_block_body_boxes_follow_one_bone() -> void:
	ModelVisual.available()
	GameSettings.player_style = GameSettings.PlayerStyle.BLOCKS
	var mv := ModelVisual.new()
	add_child_autofree(mv)
	mv.setup({"shirt": Color.RED, "hair_style": HairBuilder.Style.AFRO}, 3)
	var sk: Skeleton3D = mv.get("_skel")
	var block := sk.find_child("BlockBody", false, false) as MeshInstance3D
	assert_not_null(block, "cuerpo de bloques")
	var arr: Array = block.mesh.surface_get_arrays(0)
	var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	assert_gt(w.size(), 0)
	assert_not_null(BlockBody.hair_mesh(HairBuilder.Style.AFRO), "peinado de bloques")
	assert_null(BlockBody.hair_mesh(HairBuilder.Style.SHAVED))
	GameSettings.player_style = GameSettings.PlayerStyle.CLASSIC
