extends GutTest
## Backlog B11 (paso 2): correcciones de tu prueba de B10.

var m: MatchController
var dt := 1.0 / 60.0


func _start(mode: int = GameSettings.Mode.CPU_VS_CPU) -> void:
	GameSettings.set_mode(mode)
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


## La pelota que llega al fondo de la red rebota un poco (se ve el golpe) en
## lugar de frenarse en seco.
func test_ball_bounces_off_the_back_net() -> void:
	var t := Tuning.new()
	var s := BallState.new()
	s.pos = Vector3(Pitch.HALF_LENGTH + Pitch.GOAL_DEPTH - 0.3, 0.5, 0.0)
	s.vel = Vector3(20.0, 0.0, 0.0)
	for i in 10:
		BallPhysics.step(s, 1.0 / 120.0, t)
	assert_lt(s.vel.x, -20.0 * 0.07, "vuelve desde la red")


## Offside: en la pausa todos quedan quietos (las animaciones no siguen).
func test_offside_freeze_stops_every_animation() -> void:
	_start()
	_step(120)
	var t := m.teams[0]
	m.replay.mark_kick()
	_step(30)
	m.phase = MatchController.Phase.PLAYING
	m.call_offside(t.players[9], m.offside_line(t), t.players[6])
	GameSettings.replay_chances = true
	m._phase_timer = 0.0
	for i in int((Replay.POST + 0.5) / dt):
		if m.phase == MatchController.Phase.REPLAY:
			break
		m._physics_process(dt)
	m.replay._wipe.advance(1.0)
	for i in 600:
		m.replay.tick(dt)
		if m.replay._freeze_left > 0.0 and m.replay._cursor >= m.replay._event_local:
			break
	m.replay.tick(dt)
	for p in m.all_players():
		if p.visual is ModelVisual and (p.visual as ModelVisual)._anim != null:
			assert_eq((p.visual as ModelVisual)._anim.speed_scale, 0.0, "%s quieto" % p.name)
	assert_eq(m.replay._caption, "", "sin cartel en el offside")


## Entretiempo: caminando (no trotando) y entran al túnel sin trabarse.
func test_halftime_players_walk_into_the_tunnel() -> void:
	_start()
	m._end_half()
	_step(int(MatchController.WHISTLE_COAST / dt) + 2)
	var walkers: Array = []
	for p in m.walk_off:
		if p is Footballer and m.walk_off[p][0] == "tunnel":
			walkers.append(p)
	_step(120)
	for p in walkers:
		assert_lt((p as Footballer).velocity.length(), 2.2, "camina")
	# Sin la pantalla: se les da tiempo para llegar todos al túnel.
	m._phase_timer = INF
	for i in int(70.0 / dt):
		m._physics_process(dt)
	var inside := 0
	for p in walkers:
		if not (p as Footballer).visible:
			inside += 1
	assert_gt(inside, walkers.size() * 0.8, "entraron al túnel (%d de %d)" % [inside, walkers.size()])


## Empate: se saludan de a dos (el más cercano, propio o rival).
func test_draw_players_greet_each_other() -> void:
	_start()
	m.clock.half = 2
	m._end_half()
	_step(int(MatchController.WHISTLE_COAST / dt) + 2)
	var greet := 0
	for p in m.walk_off:
		if p is Footballer and m.walk_off[p][0] == "greet":
			greet += 1
			var mate: Footballer = m.walk_off[p][1]
			assert_eq(m.walk_off[mate][1], p, "de a pares")
	assert_gt(greet, 18)


## Repeticiones: cartel con número y nombre; en las tarjetas, el ícono.
func test_replay_caption_number_name_and_card() -> void:
	_start()
	_step(150)
	var p: Footballer = m.teams[0].players[9]
	assert_eq(Replay.player_line(p), "%d   %s" % [p.number, p.display_name])
	m.replay.mark_event()
	m.replay.start(Replay.Kind.FOUL, 0, Replay.player_line(p), {"card": 1})
	m.replay._wipe.advance(1.0)
	for i in 300:
		m.replay.tick(dt)
	assert_true(m.replay._card_icon.visible, "tarjeta amarilla")
	assert_true(m.replay._card_icon.color.is_equal_approx(Color(1.0, 0.86, 0.1)))


## Carteles del partido en mayúsculas; flecha del jugador más chica; la
## mentalidad al lado del panel del humano; el público se va del todo.
func test_hud_banner_arrow_and_tactics_box() -> void:
	_start(GameSettings.Mode.VS_CPU)
	m.banner_text = "Saque de arco"
	var hud: MatchHud = null
	for c in m.find_children("*", "", true, false):
		if c is MatchHud:
			hud = c
	hud._process(dt)
	assert_eq(hud._banner.text, "SAQUE DE ARCO")
	var t := m.humans[0].team
	m.set_mentality(t, 1)
	hud._process(dt)
	assert_true(hud._tactics[t.index].visible)
	assert_eq(hud._tactics[t.index].mentality, 1)
	var cone := (t.players[9] as Footballer)._arrow.mesh as CylinderMesh
	assert_lte(cone.top_radius, 0.17, "flecha a la mitad")
	m.phase = MatchController.Phase.FULLTIME
	m._break_shown = true
	m._stands_t = MatchController.STANDS_EMPTY_TIME * 2.0
	m._empty_stands(dt)
	assert_gt(float(StadiumBuilder.crowd_material.get_shader_parameter("empty")), 1.0, "se van todos")
