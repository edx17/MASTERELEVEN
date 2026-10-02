extends GutTest
## Tanda 3 de animaciones: festejos a elección, chilena, arranque y giro en
## carrera, arquero que ordena, falta fuerte (queda en el piso), arquero que
## se tira encima para hacer tiempo, lesionado.

var m: MatchController
var dt := 1.0 / 60.0


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.show_replays = false
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


func _step_visual(v: ModelVisual, speed: float, frames: int, pose: int = PlayerVisual.Pose.NORMAL) -> void:
	for i in frames:
		v.update(dt, speed, 8.4, pose, 0.0)
		v._anim.advance(dt)


func test_celebration_uses_the_favourite_or_a_random_one() -> void:
	if not _mixamo():
		return
	var d := PlayerData.new()
	d.celebration = 2
	assert_eq(Celebrations.pick(d), 2, "el preferido del jugador")
	d.celebration = -1
	for i in 10:
		assert_true(Celebrations.available(Celebrations.pick(d)), "al azar, uno que esté")
	for i in Celebrations.LIST.size():
		var t := Celebrations.duration(i)
		assert_between(t, Celebrations.MIN_TIME, Celebrations.MAX_TIME)


func test_visual_plays_the_chosen_celebration() -> void:
	if not _mixamo():
		return
	var v := _visual()
	_step_visual(v, 0.0, 5)
	v.play(PlayerVisual.Event.CELEBRATE, 6)
	assert_eq(v._clip, Celebrations.clip(6))
	assert_almost_eq(v._clip_left, Celebrations.duration(6), 0.01)
	v.play(PlayerVisual.Event.KICK)
	assert_eq(v._clip, Celebrations.clip(6), "el festejo no se corta")


func test_chilena_with_the_back_to_goal() -> void:
	var t := m.teams[0]
	var p: Footballer = t.players[9]
	var goal := t.target_goal()
	p.teleport(goal - Vector3(t.attack_dir * 10.0, 0, 0), Vector3(-t.attack_dir, 0, 0))
	m.ball.place(p.flat_pos() + Vector3(-t.attack_dir * 0.5, 1.5, 0))
	assert_true(m.is_chilena(p, KickActions.Kind.SHOT), "de espaldas, pelota a media altura")
	assert_false(m.is_chilena(p, KickActions.Kind.SHORT_PASS), "sólo el remate")
	p.teleport(p.flat_pos(), Vector3(t.attack_dir, 0, 0))
	assert_false(m.is_chilena(p, KickActions.Kind.SHOT), "de frente es una volea")
	p.teleport(p.flat_pos(), Vector3(-t.attack_dir, 0, 0))
	m.ball.place(p.flat_pos() + Vector3(-t.attack_dir * 0.5, 0.3, 0))
	assert_false(m.is_chilena(p, KickActions.Kind.SHOT), "pelota baja: no")


func test_chilena_shoots_and_leaves_him_on_the_ground() -> void:
	var t := m.teams[0]
	var p: Footballer = t.players[9]
	var goal := t.target_goal()
	p.teleport(goal - Vector3(t.attack_dir * 10.0, 0, 0), Vector3(-t.attack_dir, 0, 0))
	m.ball.place(p.flat_pos() + Vector3(-t.attack_dir * 0.4, 1.4, 0))
	m.ball.state.vel = Vector3.ZERO
	m.perform_kick(p, KickActions.Kind.SHOT, Vector3.ZERO, 0.8)
	assert_eq(m.stats["chilenas"][0], 1)
	assert_eq(p.state, Footballer.State.RECOVERING, "queda en el piso")
	assert_gt(m.ball.state.vel.x * t.attack_dir, 5.0, "la pelota va al arco")


func test_sprint_start_and_turn_gestures() -> void:
	var p: Footballer = m.teams[0].players[6]
	var seen: Array = []
	p.visual.played.connect(func(ev: int, _s: float) -> void: seen.append(ev))
	p.teleport(Vector3(0, 0, 10), Vector3.RIGHT)
	p.desired_move = Vector3.RIGHT
	p.wants_sprint = true
	p.tick(dt, false)
	assert_has(seen, PlayerVisual.Event.SPRINT_START, "R1 desde parado: arranque")
	for i in 90:
		p.tick(dt, false)
	seen.clear()
	p.desired_move = Vector3.LEFT
	for i in 10:
		p.tick(dt, false)
	assert_has(seen, PlayerVisual.Event.SPRINT_TURN, "corte a toda velocidad: giro")
	assert_eq(seen.count(PlayerVisual.Event.SPRINT_TURN), 1, "una sola vez por giro")


func test_hard_foul_leaves_the_victim_down() -> void:
	var t0 := m.teams[0]
	var victim: Footballer = t0.players[9]
	var offender: Footballer = m.teams[1].players[3]
	victim.teleport(Vector3(0, 0, 5), Vector3(t0.attack_dir, 0, 0))
	offender.teleport(Vector3(-t0.attack_dir, 0, 5), Vector3(t0.attack_dir, 0, 0))
	m.call_foul(offender, victim, true)
	assert_true(victim.tripped)
	assert_true(victim.trip_back, "de atrás: cae de espaldas")
	assert_almost_eq(victim.state_timer, MatchController.HARD_FOUL_DOWN, 0.01)
	assert_gt(m._phase_timer, MatchController.FOUL_DELAY, "el juego espera a que se levante")


func test_fallen_idle_after_the_fall() -> void:
	if not _mixamo():
		return
	var v := _visual()
	v.tripped = true
	v.recover_left = 3.0
	for i in 100:
		v.recover_left -= dt
		_step_visual(v, 0.0, 1, PlayerVisual.Pose.FALLEN)
	assert_eq(v._clip, "fallen_idle", "tirado en el piso dolorido")
	while v.recover_left > 0.5:
		v.recover_left -= dt
		_step_visual(v, 0.0, 1, PlayerVisual.Pose.FALLEN)
	assert_eq(v._clip, "get_up", "y se levanta a tiempo")


func test_keeper_directs_with_ball_far_or_in_hands() -> void:
	var gk := m.teams[0].keeper()
	var t := m.teams[0]
	m.ball.place(t.target_goal() - Vector3(t.attack_dir * 10.0, 0, 0) + Vector3(0, 0.11, 0))
	m._physics_process(dt)
	assert_true(gk.directing, "pelota en el otro campo")
	m.ball.place(gk.flat_pos() + Vector3(t.attack_dir * 8.0, 0.11, 0))
	m._physics_process(dt)
	assert_false(gk.directing)
	m.ball.give_to(gk, false, true)
	m._physics_process(dt)
	assert_true(gk.directing, "con la pelota en las manos")


func test_keeper_smothers_when_winning_late() -> void:
	var gk := m.teams[0].keeper()
	m.teams[0].score = 1
	assert_false(m._smother_catch(gk, 2.0), "pelota alta: atajada normal")
	m.clock.half = 2
	m.clock.game_seconds = 40.0 * 60.0 # minuto 85
	assert_true(m._smother_catch(gk, 1.0), "gana sobre el final: se tira encima")
	assert_true(m.wasting_time(m.teams[0]), "y hace tiempo con la pelota en las manos")
	assert_false(m.wasting_time(m.teams[1]))
	m.teams[0].score = 0
	m.teams[1].score = 1
	for p in m.teams[1].players:
		p.teleport(Vector3(0, 0, 30))
	assert_false(m._smother_catch(gk, 1.0), "perdiendo no hace tiempo")
	m.teams[1].players[9].teleport(gk.flat_pos() + Vector3(1.5, 0, 0))
	assert_true(m._smother_catch(gk, 0.3), "pelota dividida con un rival encima")


func test_injured_player_limps() -> void:
	if not _mixamo():
		return
	var v := _visual()
	v.injured = true
	_step_visual(v, 2.0, 10)
	assert_eq(v._current, "mx/injured_jog")
