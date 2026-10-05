extends GutTest
## Paso A: jugabilidad WE2002 — potencia 6-9, remate en carrera, lectura del
## pase en profundidad, despeje a fondo, rebotes jugables y cámara Lejana.

var m: MatchController
var dt := 1.0 / 60.0


func _start() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	for p in m.all_players():
		p.locked = false


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


## Pone la pelota delante de `p`, a `dist` m del arco rival, y patea.
func _shoot(p: Footballer, dist: float, power: float, vel := Vector3.ZERO) -> Vector3:
	var t := p.team
	var spot := Vector3(t.attack_dir * (Pitch.HALF_LENGTH - dist), m.tuning.ball_radius, 0.0)
	var fwd := Vector3(t.attack_dir, 0.0, 0.0)
	p.teleport(Vector3(spot.x, 0.0, 0.0) - fwd * 0.5, fwd)
	p.velocity = vel
	m.ball.owner_player = null
	m.ball.state.pos = spot
	m.ball.state.vel = Vector3.ZERO
	m.kicks.randomize_error = false
	m.kicks.pressure = 0.0
	m.kicks.shoot(p, Vector3.ZERO, power)
	return m.ball.state.vel


func test_power_levels_spread_the_shot_speed() -> void:
	assert_gt(KickActions.power_speed_factor(9.0) / KickActions.power_speed_factor(6.0), 1.2, "9 bastante más fuerte que 6")
	assert_lt(KickActions.long_range_factor(6.0, 38.0), 0.9, "con 6, de 38 m pierde fuerza")
	assert_almost_eq(KickActions.long_range_factor(8.5, 38.0), 1.0, 0.001, "con 8 o más llega entera")
	assert_almost_eq(KickActions.long_range_factor(6.0, 15.0), 1.0, 0.001, "de cerca no importa")
	var weak := PlayerData.new()
	weak.shot_power = 40
	var strong := PlayerData.new()
	strong.shot_power = 95
	assert_lt(weak.shot_level(), 7)
	assert_eq(strong.shot_level(), 9)


func test_strong_shooter_hits_harder_in_open_play() -> void:
	_start()
	var p := m.teams[0].players[9]
	p.data.shot_power = 40
	var weak := _shoot(p, 30.0, 0.8).length()
	p.data.shot_power = 95
	var strong := _shoot(p, 30.0, 0.8).length()
	assert_gt(strong, weak * 1.18)


## A toda carrera sale más alto y menos preciso; parado, más controlado.
func test_running_shot_goes_higher_and_less_accurate() -> void:
	_start()
	var p := m.teams[0].players[9]
	var fwd := Vector3(p.team.attack_dir, 0.0, 0.0)
	var still := _shoot(p, 20.0, 0.6)
	var err_still := m.kicks.last_error
	var run := _shoot(p, 20.0, 0.6, fwd * m.tuning.sprint_speed)
	var err_run := m.kicks.last_error
	assert_gt(run.y, still.y + 0.3, "sale más alto")
	assert_gt(err_run, err_still * 1.3, "menos preciso")


## Pase rival al hueco: el defensor que mejor lo lee sale a cortarlo.
func test_defender_reads_the_through_pass() -> void:
	_start()
	var att := m.teams[0]
	var def := m.teams[1]
	var dir := float(att.attack_dir)
	for o in def.players:
		if not o.is_keeper():
			o.teleport(Vector3(-dir * 40.0, 0.0, o.global_position.z * 0.2 + 30.0))
	var passer := att.players[6]
	var runner := att.players[9]
	passer.teleport(Vector3(dir * 5.0, 0.0, 0.0), Vector3(dir, 0, 0))
	runner.teleport(Vector3(dir * 18.0, 0.0, 8.0), Vector3(dir, 0, 0))
	var cb := def.players[3]
	cb.data.defense = 90
	cb.data.reaction = 90
	cb.teleport(Vector3(dir * 16.0, 0.0, 3.0), Vector3(-dir, 0, 0))
	m.ball.give_to(passer)
	_step(2)
	m.perform_kick(passer, KickActions.Kind.THROUGH_PASS, Vector3(dir, 0, 0.35), 0.55, runner)
	_step(20)
	var ai := m.ais[1]
	var reading := ai._lane_cutter == cb or ai._chaser == cb
	assert_true(reading, "el central sale a cortar el pase")
	var before := cb.flat_pos().distance_to(m.ball.flat_pos())
	_step(10)
	assert_lt(cb.flat_pos().distance_to(m.ball.flat_pos()), before, "va hacia la pelota")


## La marca se adelanta a la carrera del delantero que pica al arco.
func test_marker_anticipates_the_run() -> void:
	_start()
	var ai := m.ais[1]
	var def := m.teams[1]
	var o := m.teams[0].players[9]
	var p := def.players[3]
	p.data.defense = 90
	p.data.reaction = 90
	o.teleport(Vector3(0, 0, 0))
	var to_goal := (def.own_goal() - o.flat_pos()).normalized()
	o.velocity = to_goal * 7.0
	ai._mark(p, o)
	var lead := p.debug_target.distance_to(o.flat_pos())
	o.velocity = Vector3.ZERO
	ai._mark(p, o)
	var calm := p.debug_target.distance_to(o.flat_pos())
	assert_gt(lead, calm + 1.5, "se adelanta a la carrera")


## Despeje a fondo: desde el área propia pasa la mitad de cancha.
func test_full_clearance_reaches_the_other_half() -> void:
	_start()
	var p := m.teams[0].players[3]
	var t := p.team
	var spot := Vector3(-t.attack_dir * (Pitch.HALF_LENGTH - 14.0), m.tuning.ball_radius, 0.0)
	p.teleport(spot - Vector3(t.attack_dir * 0.5, 0, 0), Vector3(t.attack_dir, 0, 0))
	m.ball.owner_player = null
	m.ball.state.pos = spot
	m.kicks.clearance(p, Vector3(t.attack_dir, 0, 0), 1.0)
	var s := m.ball.state.copy()
	for i in 600:
		var ev := BallPhysics.step(s, BallPhysics.SIM_DT, m.tuning)
		if ev & BallPhysics.EV_BOUNCE:
			break
	assert_gt(s.pos.x * t.attack_dir, 0.0, "primer pique en el campo rival")


## Rebote jugable: a veces queda adelante, en el área; más con un arquero flojo.
func test_front_rebounds_are_playable() -> void:
	_start()
	var gk := m.teams[1].keeper()
	gk.data.goalkeeping = 40
	var bad := MatchController.front_rebound_chance(gk, 28.0)
	gk.data.goalkeeping = 95
	var good := MatchController.front_rebound_chance(gk, 28.0)
	assert_gt(bad, good, "el flojo deja más rebotes")
	assert_gt(good, 0.0)
	var v := MatchController.front_rebound(Vector3(30.0, 0.0, 0.0))
	assert_lt(v.x, -5.0, "vuelve hacia la cancha")
	var s := BallState.new(Vector3(Pitch.HALF_LENGTH - 0.8, 1.0, 0.0), v)
	for i in 400:
		if BallPhysics.step(s, BallPhysics.SIM_DT, m.tuning) & BallPhysics.EV_BOUNCE:
			break
	assert_true(Pitch.in_penalty_area(Vector3(s.pos.x, 0, s.pos.z), 1), "cae en el área")


## Cámara Lejana: más alta y con los nombres de todos.
func test_far_camera_shows_everyone_names() -> void:
	_start()
	var cam := m.camera()
	var idx := -1
	for i in cam.presets.size():
		if cam.presets[i].display_name == "Lejana":
			idx = i
	assert_gt(idx, -1, "existe la cámara Lejana")
	cam.set_preset(idx, false)
	assert_true(Footballer.names_override)
	var p := m.teams[1].players[5]
	assert_true(p._label.visible, "nombre visible aunque no lo maneje nadie")
	assert_eq(p._label.text, p.display_name)
	cam.set_preset(0, false)
	assert_false(Footballer.names_override)
