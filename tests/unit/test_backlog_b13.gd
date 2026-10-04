extends GutTest
## Correcciones de la prueba de B11 (pasos 3-4): fritura en las faltas,
## festejo del ganador, cámara del entretiempo, cambios animados y salida del
## público por los pasillos.

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


func _step(n: int) -> void:
	for i in n:
		m._physics_process(dt)


## El swoosh de la repetición es un "whoosh" grave (no ruido agudo, que
## sonaba a fritura en cada falta).
func test_swoosh_is_dark_not_hiss() -> void:
	var d := MatchAudio.sound("swoosh").data
	var prev := 0.0
	var diff := 0.0
	var mag := 0.0
	for i in d.size() / 2:
		var v := float(d.decode_s16(i * 2))
		diff += absf(v - prev)
		mag += absf(v)
		prev = v
	var approx_hz := diff / maxf(mag, 1.0) * MatchAudio.RATE / 4.0
	assert_lt(approx_hz, 2000.0, "grave (antes ~2900 Hz de ruido)")


## Final: los ganadores festejan toda la toma (los que corren a juntarse
## hacen un festejo; los demás, brazos arriba hasta el final).
func test_winners_celebrate_through_the_whole_shot() -> void:
	_start()
	m.teams[0].score = 1
	m.clock.half = 2
	m._end_half()
	_step(int(MatchController.WHISTLE_COAST / dt) + 2)
	var party: Array = []
	var cheer: Array = []
	for p in m.walk_off:
		if p is Footballer and p.team == m.teams[0]:
			var kind: String = m.walk_off[p][0]
			if kind == "party":
				party.append(p)
			elif kind == "stay":
				cheer.append(p)
	assert_gt(party.size(), 3, "varios corren a juntarse")
	assert_gt(cheer.size(), 2)
	_step(int((MatchController.FULLTIME_REACTIONS - 1.0) / dt))
	var celebrating := 0
	for p: Footballer in party:
		if p.celebrate_timer > 0.0:
			celebrating += 1
	assert_gt(celebrating, party.size() / 2, "festejando al final de la toma")
	for p: Footballer in cheer:
		assert_eq(p.visual._event, PlayerVisual.Event.CHEER, "sigue con los brazos arriba")


## Entretiempo: toma aérea con toda la cancha, alternada con la del túnel.
func test_halftime_camera_alternates_aerial_and_tunnel() -> void:
	_start()
	m.clock.half = 1
	m._end_half()
	_step(int(MatchController.WHISTLE_COAST / dt) + 2)
	var cam := m.camera()
	_step(30)
	assert_gt(cam.shot_pos.y, 70.0, "aérea, con toda la cancha")
	_step(int(MatchController.HALFTIME_SHOT / dt))
	assert_lt(cam.shot_pos.y, 4.0, "desde el túnel")
	assert_gt(cam.shot_pos.z, StadiumBuilder.tunnel_z, "adentro del túnel")


## Cambio animado: el suplente espera junto al cuarto árbitro en la mitad de
## cancha; el que sale llega, lo saluda y se va; el que entra corre a la
## cancha. El reloj no corre y no se reanuda hasta que termina.
func test_substitution_scene() -> void:
	_start()
	var t := m.teams[0]
	var out := t.players[7]
	out.teleport(Vector3(-t.attack_dir * 8.0, 0.0, Pitch.HALF_WIDTH - 10.0))
	var spot := Vector3(-t.attack_dir * 20.0, 0.11, Pitch.HALF_WIDTH)
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.THROW_IN, 1, spot))
	m._restart_elapsed = 5.0
	var clock0 := m.clock.total_game_seconds()
	var inn := m.substitute(out, t.bench[0])
	assert_not_null(inn)
	assert_eq(m.sub_scenes.size(), 1, "arranca la escena")
	assert_true(out.visible, "el que sale sigue en la cancha")
	assert_lt(inn.flat_pos().distance_to(m.sub_spot(t)), 0.5, "el suplente espera en la mitad de cancha")
	assert_true(m.fourth_official.visible, "con el cuarto árbitro")
	assert_false(m.restart_ready(), "no se reanuda durante el cambio")
	var greeted := false
	for i in int(MatchController.SUB_MAX_TIME / dt) + 30:
		_step(1)
		if m.sub_scenes.is_empty():
			break
		greeted = greeted or String(m.sub_scenes[0]["stage"]) == "greet"
	assert_true(m.sub_scenes.is_empty(), "terminó")
	assert_true(greeted, "pasó por el saludo")
	assert_false(out.visible, "el que salió ya no está")
	assert_lt(inn.global_position.z, Pitch.HALF_WIDTH, "el que entró está en la cancha")
	assert_almost_eq(m.clock.total_game_seconds(), clock0, 1.0, "casi sin tiempo de partido")
	assert_false(m.fourth_official.visible)


## Si el que sale está lejos, sale por la línea más cercana y el suplente
## entra enseguida.
func test_far_substitution_exits_by_the_nearest_line() -> void:
	_start()
	var t := m.teams[0]
	var out := t.players[9]
	out.teleport(Vector3(t.attack_dir * 40.0, 0.0, -20.0))
	var spot := Vector3(t.attack_dir * 30.0, 0.11, -Pitch.HALF_WIDTH)
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.THROW_IN, 1, spot))
	m.substitute(out, t.bench[0])
	assert_eq(String(m.sub_scenes[0]["stage"]), "far")
	for i in int(MatchController.SUB_MAX_TIME / dt) + 30:
		_step(1)
		if m.sub_scenes.is_empty():
			break
	assert_true(m.sub_scenes.is_empty())
	assert_false(out.visible)


## Tribunas con escaleras y bocas de salida (vomitorios): el público sabe
## dónde están para irse por ahí (rectangulares y el ovalado).
func test_stands_have_vomitories_for_the_crowd() -> void:
	for st_i in [0, 4]:
		GameSettings.stadium_choice = st_i
		_start()
		var voms := m.stadium.find_children("Vomitories", "MeshInstance3D", true, false)
		assert_gt(voms.size(), 0, "estadio %d: bocas de salida" % st_i)
		var faces := 0
		for v in voms:
			var mesh := (v as MeshInstance3D).mesh
			if mesh != null and mesh.get_surface_count() > 0:
				faces += mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		assert_gt(faces, 100, "con geometría")
		var crowds := m.stadium.find_children("Crowd", "MultiMeshInstance3D", true, false)
		assert_gt(crowds.size(), 0)
		var with_layout := 0
		for c in crowds:
			if float((c as GeometryInstance3D).get_instance_shader_parameter("layout_on")) > 0.5:
				with_layout += 1
		assert_gt(with_layout, 0, "el público conoce las salidas")
		m.queue_free()
		await get_tree().process_frame
	GameSettings.stadium_choice = 0


## Los vomitorios quedan en la misma grilla en todas las filas (la que usa
## el shader para encontrarlos).
func test_vomitory_grid_matches_the_shader() -> void:
	var base := 120
	var x0 := StadiumBuilder.vomitory_x0(base)
	for extra: int in [0, 4, 9]:
		var shift: int = extra / 2
		for vx in StadiumBuilder.vomitory_xs(base + extra, shift):
			var k := roundf((vx - x0) / (StadiumBuilder.VOM_EVERY * StadiumBuilder.SEAT_PITCH))
			var on_grid := x0 + k * StadiumBuilder.VOM_EVERY * StadiumBuilder.SEAT_PITCH
			assert_almost_eq(vx, on_grid, StadiumBuilder.SEAT_PITCH * 0.51)
