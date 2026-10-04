extends GutTest
## Backlog B11 (paso 3): pelota parada a la WE2002 — carrera, tiros libres
## según el stick, penal de 5 direcciones y arquero sobre la línea.

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


## Pelota quieta a `dist` metros del arco rival del equipo 0, de frente.
func _fk_spot(dist: float) -> Vector3:
	var t := m.teams[0]
	return Vector3(t.attack_dir * (Pitch.HALF_LENGTH - dist), m.tuning.ball_radius, 0.0)


## Patea un tiro libre directo y devuelve la trayectoria (posiciones).
func _fk_path(kind: int, stick: Vector3, power: float, dist: float = 22.0, shot_power: int = 75) -> Array:
	var p := m.teams[0].players[9]
	p.data.shot_power = shot_power
	m.ball.owner_player = null
	m.ball.state.pos = _fk_spot(dist)
	m.ball.state.vel = Vector3.ZERO
	m.ball.state.spin = Vector3.ZERO
	m.kicks.randomize_error = false
	var aim := Vector3(m.teams[0].attack_dir, 0.0, 0.0)
	p.global_position = Vector3(m.ball.state.pos.x, 0.0, 0.0) - aim * 0.5
	p.facing = aim
	var right := Vector3(0.0, 0.0, m.teams[0].attack_dir) # derecha de la pantalla mirando al arco
	SetPieceKicks.free_kick(m.kicks, p, aim, kind, stick, power, 0.0, right)
	var s := m.ball.state.copy()
	var path: Array = []
	for i in 240:
		BallPhysics.step(s, BallPhysics.SIM_DT, m.tuning)
		path.append(s.pos)
	return path


## Altura de la trayectoria cuando recorrió `d` metros desde la pelota.
func _height_at(path: Array, start: Vector3, d: float) -> float:
	for q: Vector3 in path:
		if Vector2(q.x - start.x, q.z - start.z).length() >= d:
			return q.y
	return -1.0


func _sideways_at_goal(path: Array) -> float:
	for q: Vector3 in path:
		if absf(q.x) >= Pitch.HALF_LENGTH - 0.2:
			return q.z
	return (path[-1] as Vector3).z


func test_free_kick_type_follows_the_stick() -> void:
	var sq := KickActions.Kind.SHOT
	var ci := KickActions.Kind.LONG_PASS
	assert_eq(SetPieceKicks.fk_type(sq, Vector3.ZERO, 0.6), SetPieceKicks.Fk.NORMAL)
	assert_eq(SetPieceKicks.fk_type(sq, Vector3(0, 0, 1), 0.6), SetPieceKicks.Fk.PLACED, "atrás + cuadrado")
	assert_eq(SetPieceKicks.fk_type(sq, Vector3(0, 0, -1), 0.2), SetPieceKicks.Fk.LOW, "adelante + toque")
	assert_eq(SetPieceKicks.fk_type(sq, Vector3(0, 0, -1), 0.9), SetPieceKicks.Fk.POWER, "adelante cargado")
	assert_eq(SetPieceKicks.fk_type(sq, Vector3(1, 0, 0), 0.6), SetPieceKicks.Fk.CURL, "costado")
	assert_eq(SetPieceKicks.fk_type(sq, Vector3(-0.7, 0, -0.7), 0.6), SetPieceKicks.Fk.CURL, "arriba + costado")
	assert_eq(SetPieceKicks.fk_type(ci, Vector3(0.7, 0, -0.7), 0.2), SetPieceKicks.Fk.SOFT_LOB, "globito")
	assert_eq(SetPieceKicks.fk_type(ci, Vector3(0, 0, 1), 1.0), SetPieceKicks.Fk.LOW_POST, "atrás + círculo a fondo")


## Atrás + Cuadrado: pasa por encima de la barrera y baja antes del travesaño.
func test_placed_free_kick_clears_the_wall_and_dips() -> void:
	_start()
	var start := _fk_spot(22.0)
	var path := _fk_path(KickActions.Kind.SHOT, Vector3(0, 0, 1), 0.6)
	assert_gt(_height_at(path, start, 9.15), 2.0, "pasa la barrera")
	var at_goal := _height_at(path, start, 21.8)
	assert_between(at_goal, 0.2, Pitch.GOAL_HEIGHT, "baja y entra")


## Adelante + toque: rasante, por debajo de la barrera.
func test_low_free_kick_goes_under_the_wall() -> void:
	_start()
	var start := _fk_spot(22.0)
	var path := _fk_path(KickActions.Kind.SHOT, Vector3(0, 0, -1), 0.2)
	assert_lt(_height_at(path, start, 9.15), 0.3, "por el piso")


## Costado: dobla hacia el lado del stick (y para el otro con el otro lado).
func test_curl_free_kick_bends_toward_the_stick() -> void:
	_start()
	var right := _sideways_at_goal(_fk_path(KickActions.Kind.SHOT, Vector3(1, 0, 0), 0.6))
	var left := _sideways_at_goal(_fk_path(KickActions.Kind.SHOT, Vector3(-1, 0, 0), 0.6))
	var dir := float(m.teams[0].attack_dir)
	assert_gt(right * dir, 0.8, "a la derecha de la pantalla")
	assert_lt(left * dir, -0.8, "a la izquierda")


## Cañonazo: con potencia de remate alta sale bastante más fuerte.
func test_power_free_kick_needs_shot_power() -> void:
	_start()
	_fk_path(KickActions.Kind.SHOT, Vector3(0, 0, -1), 0.95, 30.0, 45)
	var weak := m.ball.state.vel.length()
	_fk_path(KickActions.Kind.SHOT, Vector3(0, 0, -1), 0.95, 30.0, 95)
	var strong := m.ball.state.vel.length()
	assert_gt(strong, weak * 1.15)


func test_penalty_five_zones() -> void:
	assert_eq(SetPieceKicks.penalty_zone(Vector3.ZERO), Vector2i(0, 0), "al medio")
	assert_eq(SetPieceKicks.penalty_zone(Vector3(1, 0, -1)), Vector2i(1, 1), "arriba a la derecha")
	assert_eq(SetPieceKicks.penalty_zone(Vector3(1, 0, 0.5)), Vector2i(1, -1), "abajo a la derecha")
	assert_eq(SetPieceKicks.penalty_zone(Vector3(-1, 0, -1)), Vector2i(-1, 1), "arriba a la izquierda")
	assert_eq(SetPieceKicks.penalty_zone(Vector3(-1, 0, 0)), Vector2i(-1, -1), "abajo a la izquierda")
	var ok := SetPieceKicks.penalty_target(Vector2i(1, 1), 1.0, 0.7)
	assert_lt(ok.y, Pitch.GOAL_HEIGHT, "arriba pero adentro")
	assert_almost_eq(ok.x, SetPieceKicks.PK_SIDE_Z, 0.01)
	var over := SetPieceKicks.penalty_target(Vector2i(1, 1), 1.0, 1.0)
	assert_gt(over.y, Pitch.GOAL_HEIGHT, "pasada de fuerza: por arriba")
	assert_lt(SetPieceKicks.penalty_target(Vector2i(0, -1), 1.0, 0.4).y,
		SetPieceKicks.penalty_target(Vector2i(0, -1), 1.0, 0.85).y, "más fuerza, más alta")


func test_penalty_save_chance_depends_on_the_guess() -> void:
	assert_eq(SetPieceKicks.penalty_save_chance(Vector2i(1, 1), Vector2i(-1, 1), 90), 0.0, "otro lado")
	var low := SetPieceKicks.penalty_save_chance(Vector2i(1, -1), Vector2i(1, -1), 70)
	var high := SetPieceKicks.penalty_save_chance(Vector2i(1, 1), Vector2i(1, -1), 70)
	assert_gt(low, high, "la alta es más difícil")
	assert_gt(SetPieceKicks.penalty_save_chance(Vector2i(0, 0), Vector2i(0, 0), 70), 0.7, "al medio y se quedó")


## Penal de la CPU: toma carrera (no le pega desde al lado de la pelota), el
## arquero espera sobre la línea y la pelota sale hacia el arco.
func test_penalty_runup_and_keeper_on_the_line() -> void:
	_start()
	var att := m.teams[0]
	var gk := m.teams[1].keeper()
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.PENALTY, 0, m.penalty_spot(m.teams[1])))
	var taker := m.restart_taker
	var spot := m.ball.flat_pos()
	assert_gt(taker.flat_pos().distance_to(spot), 2.0, "arranca atrás de la pelota")
	var before := m.kick_count
	var max_off := 0.0
	for i in int(8.0 / dt):
		_step(1)
		if m.kick_count != before:
			break
		max_off = maxf(max_off, absf(gk.flat_pos().x - m.teams[1].own_goal().x))
	assert_ne(m.kick_count, before, "pateó")
	assert_lt(max_off, 1.6, "el arquero no sale a buscarlo")
	assert_gt(m.ball.state.vel.x * att.attack_dir, 10.0, "sale hacia el arco")


## Tiro libre del humano con la cámara atrás: el stick derecho gira la mira y
## el pateador no gira en el lugar; le pega después de la carrera.
func test_human_free_kick_aims_with_right_stick_and_runs_up() -> void:
	_start(GameSettings.Mode.VS_CPU)
	var h: HumanController = m.humans[0]
	var input := ScriptedInput.new()
	h.input = input
	var t := h.team
	var spot := t.target_goal() - Vector3(t.attack_dir * 24.0, 0.0, 0.0)
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.FREE_KICK, t.index, Vector3(spot.x, 0.11, spot.z)))
	assert_true(m.free_kick_camera_active(), "cámara atrás")
	var taker := m.restart_taker
	h.select(taker)
	var aim0 := m.set_piece_aim()
	input.right = Vector3(1, 0, 0)
	_step(40)
	input.right = Vector3.ZERO
	assert_gt(aim0.angle_to(m.set_piece_aim()), 0.2, "giró la mira")
	var facing := taker.facing
	input.move = Vector3(1, 0, 0)
	_step(10)
	assert_almost_eq(facing.angle_to(taker.facing), 0.0, 0.05, "no gira en el lugar")
	# Atrás + cuadrado al llegar: colocado.
	input.move = Vector3(0, 0, 1)
	var before := m.kick_count
	m.order_free_kick(taker, KickActions.Kind.SHOT, 0.6, h)
	assert_eq(m.kick_count, before, "primero toma carrera")
	for i in int(5.0 / dt):
		_step(1)
		if m.kick_count != before:
			break
	assert_ne(m.kick_count, before, "pateó")
	assert_gt(m.ball.state.vel.y, 2.0, "colocado: sale por arriba")


## Sonidos nuevos generados por código: suenan (no son silencio), no saturan
## y los loops lo son.
func test_new_generated_sounds() -> void:
	for n in ["whistles", "applause", "swoosh", "chant", "menu_music"]:
		var t0 := Time.get_ticks_msec()
		var w := MatchAudio.sound(n)
		var ms := Time.get_ticks_msec() - t0
		var d := w.data
		var peak := 0
		for i in range(0, d.size(), 64):
			peak = maxi(peak, absi(d.decode_s16(i)))
		gut.p("%s: %.1f s, %d ms, pico %d" % [n, d.size() / 2.0 / MatchAudio.RATE, ms, peak])
		assert_gt(peak, 3000, "%s suena" % n)
		assert_lt(peak, 32000, "%s no satura" % n)
	assert_eq(MatchAudio.sound("chant").loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(MatchAudio.sound("menu_music").loop_mode, AudioStreamWAV.LOOP_FORWARD)


## Si el tiempo termina con un tiro libre armado, el pateador (que estaba
## "trabado" esperando patear) también se va caminando al túnel.
func test_set_piece_taker_walks_off_at_halftime() -> void:
	_start()
	var t := m.teams[0]
	var spot := t.target_goal() - Vector3(t.attack_dir * 24.0, 0.0, 0.0)
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.FREE_KICK, 0, Vector3(spot.x, 0.11, spot.z)))
	var taker := m.restart_taker
	assert_true(taker.locked)
	m.phase = MatchController.Phase.PLAYING
	m._end_half()
	_step(int(MatchController.WHISTLE_COAST / dt) + 2)
	assert_false(taker.locked, "destrabado")
	var tunnel := Vector3(0, 0, StadiumBuilder.tunnel_z)
	var d0 := taker.flat_pos().distance_to(tunnel)
	_step(120)
	if m.walk_off.get(taker, [""])[0] == "tunnel":
		assert_lt(taker.flat_pos().distance_to(tunnel), d0, "camina")


## Cambio antes del partido durante el calentamiento: el suplente entra al
## rondo / al arco y el juego no se cierra (el titular borrado no queda
## referenciado).
func test_lineup_swap_during_warmup_does_not_crash() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	GameSettings.play_intro = true
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	var intro := m.intro
	var t := m.teams[0]
	var out: Footballer = (intro._rondos[0]["ring"] as Array)[0]
	var mid_out: Footballer = intro._rondos[1]["mid"]
	var gk_out := t.keeper()
	var sub := m.swap_lineup(out, t.bench[0])
	var sub2 := m.swap_lineup(mid_out, t.bench[1])
	var gk_in: PlayerData = null
	for d: PlayerData in t.bench:
		if d.position == PlayerData.Position.GK:
			gk_in = d
	var sub_gk := m.swap_lineup(gk_out, gk_in) if gk_in != null else null
	await get_tree().process_frame # se borran los titulares
	for i in 120:
		m._physics_process(dt)
	assert_true((intro._rondos[0]["ring"] as Array).has(sub), "entró al rondo")
	assert_eq(intro._rondos[1]["mid"], sub2, "el del medio")
	if sub_gk != null:
		assert_eq(intro._keeper_drills[0]["keeper"], sub_gk, "el arquero suplente ataja")
	GameSettings.play_intro = false
