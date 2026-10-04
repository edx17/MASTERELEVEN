extends GutTest
## IA ofensiva en los centros (ocupa el área) y remate potente (L1 + R1 +
## Cuadrado: carga y perfila más lento, sale mucho más fuerte y menos preciso).

var m: MatchController
var inp: ScriptedInput
var dt := 1.0 / 60.0


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	inp = ScriptedInput.new()
	m.humans[0].input = inp
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false
	for p in m.all_players():
		p.locked = false


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


func test_attackers_fill_the_box_on_a_cross() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	var t := m.teams[0]
	var ai: TeamAI = m.ais[0]
	# Defensores rivales bien atrás: nadie queda en offside yendo al área.
	for o in m.teams[1].players:
		if not o.is_keeper():
			o.teleport(t.target_goal() - Vector3(t.attack_dir * 3.0, 0, randf_range(-8, 8)))
			o.locked = true
	var winger: Footballer = t.players[7]
	var pos := t.target_goal() - Vector3(t.attack_dir * 14.0, 0, -26.0)
	winger.teleport(pos)
	m.ball.place(pos + Vector3(0, 0.11, 0))
	m.ball.give_to(winger)
	ai._assign_roles(m.ball)
	var runs := 0
	for p in ai.roles:
		if ai.roles[p] == "al área":
			runs += 1
	assert_gte(runs, 3, "primer palo, punto penal, segundo palo")
	# Al rato hay compañeros adentro del área.
	# (el que tira el centro se queda con la pelota: se mide la llegada)
	for i in 420:
		m._physics_process(dt)
		winger.teleport(pos)
		m.ball.place(pos + Vector3(0, 0.11, 0))
		m.ball.give_to(winger)
	assert_gte(ai._mates_in_box(), 2)


func test_box_spots_cover_near_post_spot_and_far_post() -> void:
	var t := m.teams[0]
	var ai: TeamAI = m.ais[0]
	var ball_z := 25.0
	var spots := ai.box_spots(Vector3(t.target_goal().x, 0, ball_z))
	assert_eq(spots.size(), 4)
	for i in 3:
		assert_true(Pitch.in_penalty_area(spots[i], t.attack_dir), "adentro del área")
	assert_gt(spots[1].z * ball_z, 0.0, "primer palo del lado del centro")
	assert_lt(spots[2].z * ball_z, 0.0, "segundo palo del otro lado")


func _shot(variant: int) -> float:
	var p: Footballer = m.teams[0].players[9]
	var pos := Vector3(m.teams[0].attack_dir * 25.0, 0, 0)
	p.teleport(pos, Vector3(m.teams[0].attack_dir, 0, 0))
	m.ball.place(pos + Vector3(m.teams[0].attack_dir * 0.5, 0.11, 0))
	m.ball.give_to(p)
	m.kicks.randomize_error = false
	m.perform_kick(p, KickActions.Kind.SHOT, Vector3.ZERO, 0.7, null, variant)
	return m.ball.speed()


func test_power_shot_is_faster_and_less_accurate() -> void:
	var normal := _shot(KickActions.Variant.NORMAL)
	var err_normal := m.kicks.last_error
	var strong := _shot(KickActions.Variant.POWER)
	assert_gt(strong, normal * 1.2, "mucha más fuerza")
	assert_gt(m.kicks.last_error, err_normal * 2.0, "mucho menos preciso")


func test_human_power_shot_winds_up_slower() -> void:
	var p: Footballer = m.teams[0].players[9]
	for o in m.teams[1].players:
		if not o.is_keeper():
			o.teleport(Vector3(0, 0, 33))
			o.locked = true
	var pos := Vector3(m.teams[0].attack_dir * 25.0, 0, 0)
	p.teleport(pos, Vector3(m.teams[0].attack_dir, 0, 0))
	m.ball.place(pos + Vector3(m.teams[0].attack_dir * 0.5, 0.11, 0))
	m.ball.give_to(p)
	m.humans[0].select(p)
	_step(2)
	inp.hold(&"special")
	inp.hold(&"sprint")
	_step(2)
	inp.hold(&"shoot")
	_step(20)
	var h: HumanController = m.humans[0]
	assert_lt(h.power, 20.0 * dt / m.tuning.power_charge_time - 0.05, "carga más lento")
	inp.release(&"shoot")
	var kicks := m.kick_count
	_step(int(HumanController.POWER_WINDUP / dt) - 4)
	assert_eq(m.kick_count, kicks, "todavía se está perfilando")
	_step(10)
	assert_eq(m.kick_count, kicks + 1, "le pegó")
	assert_eq(m.last_kick["kind"], KickActions.Kind.SHOT)
	inp.release(&"special")
	inp.release(&"sprint")
