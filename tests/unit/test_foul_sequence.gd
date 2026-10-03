extends GutTest
## La falta como en el WE: el derribado queda en el piso, el árbitro va y
## muestra la tarjeta, repetición y tiro libre con la cámara atrás del
## pateador (en campo rival). El arquero que se tiró sobre la pelota se
## levanta con ella en una mano.

var m: MatchController
var dt := 1.0 / 60.0


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.show_replays = false
	GameSettings.replay_chances = false
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	for p in m.all_players():
		p.locked = false


func _foul_with_card() -> Footballer:
	var t0 := m.teams[0]
	for i in 40:
		var victim: Footballer = t0.players[9]
		var offender: Footballer = m.teams[1].players[4 + i % 5]
		var spot := Vector3(t0.attack_dir * 20.0, 0, 6.0)
		victim.teleport(spot, Vector3(t0.attack_dir, 0, 0))
		offender.teleport(spot - Vector3(t0.attack_dir, 0, 0), Vector3(t0.attack_dir, 0, 0))
		m.phase = MatchController.Phase.PLAYING
		m.call_foul(offender, victim, true)
		if not m.card_scene.is_empty():
			return offender
		for j in 400:
			if m.phase == MatchController.Phase.RESTART:
				break
			m._physics_process(dt)
		m.phase = MatchController.Phase.PLAYING
	return null


func test_referee_follows_the_play_from_a_distance() -> void:
	var p := Referee.trail_point(Vector3(30, 0, 20))
	assert_lt(p.x, 30.0, "del lado del centro")
	assert_lt(p.z, 20.0)
	assert_true(absf(p.x) <= Pitch.HALF_LENGTH and absf(p.z) <= Pitch.HALF_WIDTH, "adentro de la cancha")
	var ball := Vector3(20, 0.11, 10)
	for i in 300:
		m.referee.tick(dt, ball, true)
	assert_lt(m.referee.global_position.distance_to(Referee.trail_point(ball)), 0.6, "llega a su lugar")


func test_card_scene_then_restart() -> void:
	var off := _foul_with_card()
	assert_not_null(off, "alguna de las faltas fue con tarjeta")
	if off == null:
		return
	var shown := false
	for i in 600:
		m._physics_process(dt)
		if m.referee.card_left > 0.0:
			shown = true
			assert_true(m.camera().cinematic, "toma cerca del árbitro")
			assert_lt(m.referee.global_position.distance_to(m.card_scene.get("pos", m.referee.global_position)), Referee.CARD_DISTANCE + 0.8)
		if m.phase == MatchController.Phase.RESTART:
			break
	assert_true(shown, "el árbitro mostró la tarjeta")
	assert_true(m.card_scene.is_empty())
	assert_eq(m.phase, MatchController.Phase.RESTART, "después, el tiro libre")
	if off.sent_off:
		assert_false(off.visible, "el expulsado se va")


func test_every_foul_is_replayed() -> void:
	var t0 := m.teams[0]
	var victim: Footballer = t0.players[9]
	var offender: Footballer = m.teams[1].players[3]
	victim.teleport(Vector3(-t0.attack_dir * 30.0, 0, 0), Vector3(t0.attack_dir, 0, 0))
	offender.teleport(Vector3(-t0.attack_dir * 31.0, 0, 0), Vector3(-t0.attack_dir, 0, 0))
	m.call_foul(offender, victim, false)
	assert_false(m.replay_request.is_empty(), "también una falta en mitad de cancha")


func test_free_kick_camera_behind_the_taker_only_in_the_rival_half() -> void:
	var t := m.teams[0]
	var attack := Vector3(t.attack_dir * 25.0, 0, 5.0)
	var own := Vector3(-t.attack_dir * 25.0, 0, 5.0)
	assert_true(MatchController.wants_set_piece_camera(MatchRules.Restart.FREE_KICK, t, attack))
	assert_false(MatchController.wants_set_piece_camera(MatchRules.Restart.FREE_KICK, t, own), "en campo propio, la cámara del partido")
	assert_true(MatchController.wants_set_piece_camera(MatchRules.Restart.PENALTY, t, t.target_goal()))
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.FREE_KICK, 0, attack + Vector3(0, 0.11, 0)))
	assert_true(m.camera().cinematic, "toma de tiro libre")
	var cam := m.camera().shot_pos
	var goal := t.target_goal()
	assert_gt(Vector2(cam.x, cam.z).distance_to(Vector2(goal.x, goal.z)), Vector2(attack.x, attack.z).distance_to(Vector2(goal.x, goal.z)), "atrás de la pelota")
	# Se patea: sigue un momento a la pelota y vuelve la cámara del partido.
	m.restart_taker = null
	m.phase = MatchController.Phase.PLAYING
	for i in int(MatchController.SET_PIECE_FOLLOW / dt) + 5:
		m._physics_process(dt)
	assert_false(m.camera().cinematic)
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.FREE_KICK, 0, own + Vector3(0, 0.11, 0)))
	assert_false(m.camera().cinematic)


func test_keeper_gets_up_with_the_ball_in_one_hand() -> void:
	if MixamoLibrary.library(ModelVisual._body_scene) == null:
		pass_test("sin animaciones de Mixamo en esta copia")
		return
	var v := ModelVisual.new()
	add_child_autofree(v)
	v.setup({"shirt": Color.GREEN, "shorts": Color.BLACK}, 1)
	v._anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	v.keeper = true
	v.holding = true
	v.play(PlayerVisual.Event.SMOTHER, 1.0)
	assert_eq(v._clip, "gk_smother")
	for i in 400:
		v.update(dt, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
		v._anim.advance(dt)
		if v._clip == "gk_stand_up":
			break
	assert_eq(v._clip, "gk_stand_up", "después de tirarse, se levanta")
	v._skel.force_update_all_bone_transforms()
	var hand := v._skel.global_transform * v._skel.get_bone_global_pose(v._skel.find_bone("hand_l")).origin
	assert_lt(v.hold_point().distance_to(hand), 0.2, "con la pelota en una mano")
