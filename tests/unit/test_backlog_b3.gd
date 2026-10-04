extends GutTest
## Animaciones de campo: zurdos con la izquierda, el gesto del pase (no de
## remate) con el cuerpo abriéndose hacia el pase, cabezazo de primera en los
## centros y salto anticipado al cabezazo.

var m: MatchController
var dt := 1.0 / 60.0


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	for p in m.all_players():
		p.locked = false


func _mixamo() -> bool:
	if MixamoLibrary.library(ModelVisual._body_scene) == null:
		pass_test("sin animaciones de Mixamo en esta copia")
		return false
	return true


func _visual() -> ModelVisual:
	var v := ModelVisual.new()
	add_child_autofree(v)
	v.setup({"shirt": Color.RED, "shorts": Color.BLACK}, 3)
	v._anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return v


func test_left_footed_players_kick_with_the_left() -> void:
	if not _mixamo():
		return
	var v := _visual()
	v.left_footed = true
	v.play(PlayerVisual.Event.PASS)
	assert_eq(v._clip, "pass_l")
	v._clip = ""
	v.play(PlayerVisual.Event.KICK)
	assert_eq(v._clip, "shot_l")
	v.left_footed = false
	v._clip = ""
	v.play(PlayerVisual.Event.KICK)
	assert_eq(v._clip, "shot")


func test_a_pass_uses_the_pass_gesture_and_opens_the_body() -> void:
	var t := m.teams[0]
	var p: Footballer = t.players[6]
	var mate: Footballer = t.players[7]
	p.teleport(Vector3(0, 0, 0), Vector3.RIGHT)
	mate.teleport(Vector3(0, 0, 20))
	m.ball.place(Vector3(0.4, 0.11, 0))
	m.ball.give_to(p)
	var seen: Array = []
	p.visual.played.connect(func(ev: int, _s: float) -> void: seen.append(ev))
	m.perform_kick(p, KickActions.Kind.SHORT_PASS, Vector3(0, 0, 1), 1.0, mate)
	assert_has(seen, PlayerVisual.Event.PASS, "gesto de pase aunque salga fuerte")
	assert_gt(absf(p.visual.aim_yaw), 0.8, "el pase sale al costado: el cuerpo se abre")


func test_cross_receiver_heads_it_first_time() -> void:
	var t := m.teams[0]
	var p: Footballer = t.players[9]
	p.teleport(t.target_goal() - Vector3(t.attack_dir * 9.0, 0, 0))
	m.ball.intended_receiver = p
	m.last_kick = {"kind": KickActions.Kind.LONG_PASS, "team": 0, "player": t.players[7]}
	assert_true(m._wants_header(p, 1.6), "en el área, de primera")
	p.teleport(Vector3(0, 0, 0))
	assert_false(m._wants_header(p, 1.6), "lejos del área la baja")


func test_header_jump_is_anticipated() -> void:
	if not _mixamo():
		return
	var v := _visual()
	assert_true(v.anticipate_header(0.3, 1.9))
	assert_true(v._clip.begins_with("header"))
	var clip := v._clip
	# El golpe llega a tiempo: el cabezazo no reinicia el salto.
	v.play(PlayerVisual.Event.HEADER, 1.9)
	assert_eq(v._clip, clip)
