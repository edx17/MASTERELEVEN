extends GutTest
## Energía (informe técnico: el sprint gasta, el descanso recupera) y
## tiempo de reacción de la IA.

var m: MatchController
var dt := 1.0 / 60.0


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate() as MatchController
	add_child_autofree(m)
	m.set_physics_process(false)


func _runner() -> Footballer:
	var p: Footballer = m.teams[0].players[6]
	p.teleport(Vector3(-40, 0, 10), Vector3.RIGHT)
	return p


func test_sprint_drains_and_rest_recovers() -> void:
	var p := _runner()
	for i in int(10.0 / dt):
		p.desired_move = Vector3.RIGHT
		p.wants_sprint = true
		p.tick(dt, false)
	var after_sprint := p.stamina
	assert_between(100.0 - after_sprint, 12.0, 40.0, "10 s de sprint gastan ~20-30 puntos")
	for i in int(5.0 / dt):
		p.desired_move = Vector3.ZERO
		p.wants_sprint = false
		p.tick(dt, false)
	assert_gt(p.stamina, after_sprint + 5.0, "parado se recupera")


func test_tired_player_is_slower_and_cannot_sprint() -> void:
	var p := _runner()
	p.stamina = 0.0
	for i in int(2.0 / dt):
		p.desired_move = Vector3.RIGHT
		p.wants_sprint = true
		p.tick(dt, false)
	var speed := Vector3(p.velocity.x, 0, p.velocity.z).length()
	assert_lt(speed, m.tuning.run_speed, "sin energía no sprinta y corre algo más lento")


func test_fatigue_hurts_accuracy() -> void:
	assert_gt(KickAccuracy.fatigue_penalty(0.1), KickAccuracy.fatigue_penalty(1.0) + 1.5)


func test_ai_reacts_after_a_delay() -> void:
	# Juego en marcha, alguien patea: la IA tarda un instante en reaccionar.
	var kicker: Footballer = m.teams[0].players[9]
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	kicker.locked = false
	m.ball.give_to(kicker)
	m.perform_kick(kicker, KickActions.Kind.SHORT_PASS, Vector3.LEFT, 0.5)
	m._physics_process(dt)
	var waiting := 0
	for p in m.teams[1].players:
		if p.reaction_timer > 0.0:
			waiting += 1
	assert_gt(waiting, 5, "los rivales todavía están reaccionando")
	for i in 20:
		m._physics_process(dt)
	for p in m.teams[1].players:
		assert_eq(p.reaction_timer, 0.0, "a los 0,33 s todos reaccionaron")
