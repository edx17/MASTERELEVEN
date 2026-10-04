extends GutTest
## Arquero: se tira a tiempo (nunca después de que pasó la pelota), no hace
## el gesto de agarrar una pelota que le pasa por arriba, y después de un
## rebote no la persigue sin parar.

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


func test_dive_never_comes_after_the_ball() -> void:
	# Reacciona tarde (0,6 s) a una pelota que llega en 0,4 s: igual se tira antes.
	assert_lt(MatchController.dive_time(0.6, 0.4), 0.4)
	# Con tiempo, se tira justo antes del contacto.
	assert_almost_eq(MatchController.dive_time(0.1, 1.0), 1.0 - MatchController.DIVE_LEAD, 0.001)


func test_no_catch_gesture_for_a_ball_over_his_head() -> void:
	var gk := m.teams[1].keeper()
	var seen: Array = []
	gk.visual.played.connect(func(ev: int, _s: float) -> void: seen.append(ev))
	var goal := m.teams[1].own_goal()
	gk.teleport(goal - Vector3(m.teams[1].own_side() * 6.0, 0, 0))
	# Globo que pasa a 4 m de altura por donde está el arquero.
	m.ball.place(goal - Vector3(m.teams[1].own_side() * 16.0, -4.0, 0))
	m.ball.state.vel = Vector3(m.teams[1].own_side() * 15.0, 4.0, 0.0)
	m._update_forecast()
	m._show_dive(gk, gk.flat_pos() + Vector3(0, 2.3, 0.3))
	assert_eq(seen.size(), 0, "no ataja en el aire una pelota que pasa por arriba")
	# Una pelota rasante, en cambio: se agacha.
	m.ball.place(goal - Vector3(m.teams[1].own_side() * 16.0, -0.11, 0))
	m.ball.state.vel = Vector3(m.teams[1].own_side() * 15.0, 0.0, 0.0)
	m._update_forecast()
	m._show_dive(gk, gk.flat_pos() + Vector3(0, 0.1, 0.3))
	assert_has(seen, PlayerVisual.Event.CATCH_LOW, "rasante: se agacha")


func test_keeper_does_not_chase_his_own_rebound() -> void:
	var t := m.teams[1]
	var gk := t.keeper()
	var goal := t.own_goal()
	gk.teleport(goal - Vector3(t.own_side() * 2.0, 0, 0))
	m.ball.place(goal - Vector3(t.own_side() * 6.0, -0.11, 3.0))
	m.ball.state.vel = Vector3(0, 0, 2)
	m.ball.last_toucher = gk
	m.ball.kick_age = 0.1
	var ai: TeamAI = m.ais[1]
	m._update_forecast()
	ai.keeper.tick(gk, ai, dt)
	assert_ne(gk.debug_state, "sale", "recién rebotó en él: primero se reacomoda")
