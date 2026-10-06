extends Node
## Capturas del partido para revisar cámara y presentación sin abrir el editor.
## Se activa arrancando el juego con un argumento de usuario:
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-method gl_compatibility \
##       --resolution 1280x720 -- --capture=/ruta/de/salida
## Guarda una captura por modo de cámara, una de un lateral sobre la banda
## cercana a la cámara y una con el modo debug, y sale.

var out_dir := "user://"
var _match: MatchController
var _replay_angle := -1
var _camera: MatchCamera
var _frame := 0
## [frame, acción]. Las acciones de "setup" preparan la escena; "shot:<n>" guarda.
var _script := [
	[20, "freeze"],
	[40, "shot:capture_tv.png"],
	[45, "throw_in"],
	[90, "shot:capture_tv_throw_in.png"],
	[95, "attack"],
	[140, "shot:capture_tv_attack.png"],
	[145, "preset:Amplia"],
	[190, "shot:capture_amplia.png"],
	[195, "preset:Cercana"],
	[240, "shot:capture_cercana.png"],
	[245, "preset:Vertical"],
	[290, "shot:capture_vertical.png"],
	[295, "preset:Dron"],
	[340, "shot:capture_dron.png"],
	[345, "preset:TV"],
	[350, "debug"],
	[390, "shot:capture_debug.png"],
	# Vista cenital (Dron) con simulación exacta: forma del equipo en ataque,
	# córner y saque de arco (con el debug mostrando objetivos).
	[395, "tactical_view"],
	[396, "attack_live"],
	[397, "simulate:3.0"],
	[440, "shot:capture_shape_attack.png"],
	[445, "corner"],
	[446, "simulate:2.5"],
	[490, "shot:capture_corner.png"],
	[495, "goal_kick"],
	[496, "simulate:2.5"],
	[540, "shot:capture_goal_kick.png"],
	# Gestos: remate con estirada del arquero y un pase (cámara Cercana).
	[545, "preset:Cercana"],
	[546, "shoot_scene"],
	[547, "simulate:0.02"],
	[552, "shot:capture_contact.png"],
	[553, "simulate:0.1"],
	[560, "shot:capture_kick.png"],
	[561, "simulate:0.25"],
	[575, "shot:capture_dive.png"],
	[580, "pass_scene"],
	[581, "simulate:0.02"],
	[588, "shot:capture_pass_contact.png"],
	[589, "simulate:0.18"],
	[595, "shot:capture_pass.png"],
	[600, "shoot_scene"],
	[601, "simulate:0.12"],
	[606, "shot:capture_kick2.png"],
	[607, "simulate:0.25"],
	[615, "shot:capture_dive2.png"],
	[616, "simulate:0.3"],
	[630, "shot:capture_dive3.png"],
	# Barrida que derriba, entrada de pie y festejo de gol.
	[640, "slide_scene"],
	[641, "simulate:0.35"],
	[655, "shot:capture_slide.png"],
	[656, "simulate:0.5"],
	[670, "shot:capture_trip.png"],
	[671, "simulate:0.8"],
	[685, "shot:capture_get_up.png"],
	[690, "tackle_scene"],
	[691, "simulate:0.2"],
	[705, "shot:capture_tackle.png"],
	[710, "goal_scene"],
	[711, "simulate:1.3"],
	[725, "shot:capture_celebrate.png"],
	# Gambetas: marsellesa, bicicleta y amague.
	[730, "skill:roulette"],
	[731, "simulate:0.3"],
	[740, "shot:capture_roulette.png"],
	[745, "skill:stepover"],
	[746, "simulate:0.15"],
	[755, "shot:capture_stepover.png"],
	[760, "skill:feint"],
	[761, "simulate:0.15"],
	[770, "shot:capture_feint.png"],
	[780, "quit"],
]


func _ready() -> void:
	# `-- --capture=<dir> --quick`: sólo las vistas de juego (para comparar look).
	if "--quick" in OS.get_cmdline_user_args():
		_script = [[20, "freeze"], [40, "shot:capture_tv.png"], [95, "attack"],
			[140, "shot:capture_tv_attack.png"], [145, "corner"], [146, "simulate:1.5"],
			[190, "shot:capture_corner.png"], [195, "preset:Cercana"], [196, "keeper_hold"],
			[197, "simulate:0.6"], [215, "shot:capture_keeper_hold.png"],
			[220, "slide_scene"], [221, "simulate:1.2"], [235, "shot:capture_slide_mark.png"], [240, "quit"]]
	# `--cond=horario,clima,viento,césped` (índices; -1 = al azar).
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cond="):
			var v := a.trim_prefix("--cond=").split(",")
			GameSettings.time_choice = int(v[0])
			GameSettings.weather_choice = int(v[1])
			GameSettings.wind_choice = int(v[2]) if v.size() > 2 else 0
			GameSettings.pitch_choice = int(v[3]) if v.size() > 3 else -1
	# `--tunnel`: la boca del túnel con los equipos saliendo y la vista de TV.
	if "--tunnel" in OS.get_cmdline_user_args():
		GameSettings.play_intro = true
		_script = [[5, "freeze"], [10, "intro:2"], [11, "simulate:2.5"], [20, "shot:intro_tunnel_mouth.png"],
			[25, "intro:8"], [40, "shot:capture_tv.png"], [45, "quit"]]
	# `--late`: con el reloj en el segundo tiempo (minuto ~72).
	if "--late" in OS.get_cmdline_user_args():
		_script.insert(1, [21, "late"])
	# `--subs`: pantalla de cambios de la pausa y un jugador de campo en el arco.
	if "--subs" in OS.get_cmdline_user_args():
		_script = [[20, "freeze"], [25, "late"], [30, "subs_menu"], [50, "shot:capture_subs.png"],
			[55, "subs_close"], [56, "preset:Cercana"], [57, "keeper_red"], [58, "simulate:0.5"],
			[80, "shot:capture_field_keeper.png"], [85, "quit"]]
	# `--sheet`: la Dirección del equipo con sus tres columnas y un cambio marcado.
	if "--sheet" in OS.get_cmdline_user_args():
		GameSettings.random_conditions = true
		_script = [[20, "freeze"], [25, "late"], [26, "sheet"], [45, "shot:capture_sheet_position.png"],
			[46, "sheet_col"], [60, "shot:capture_sheet_energy.png"], [61, "sheet_col"], [62, "sheet_mark"],
			[80, "shot:capture_sheet_condition.png"], [85, "quit"]]
	# `--pause`: la pausa y su submenú de Opciones de juego.
	if "--pause" in OS.get_cmdline_user_args():
		_script = [[20, "freeze"], [30, "train_pause"], [50, "shot:capture_pause.png"], [51, "pause_sub:game"],
			[70, "shot:capture_pause_sub.png"], [75, "quit"]]
	# `--replay`: un gol y su repetición con la ficha del goleador.
	if "--replay" in OS.get_cmdline_user_args():
		GameSettings.show_replays = true
		# `--replay-angle=0|1|2`: toma del gol (de siempre, detrás del arco, árbitro).
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--replay-angle="):
				_replay_angle = int(a.trim_prefix("--replay-angle="))
		_script = [[20, "freeze"], [22, "replay_goal"], [23, "until_replay"], [30, "shot:capture_replay_wipe.png"],
			[31, "simulate:1.2"], [40, "shot:capture_replay.png"],
			[41, "simulate:3.0"], [58, "shot:capture_replay_card.png"], [62, "quit"]]
	# `--foul`: falta con tarjeta del árbitro, repetición y tiro libre con la
	# cámara atrás del pateador.
	if "--foul" in OS.get_cmdline_user_args():
		GameSettings.replay_chances = true
		_script = [[20, "freeze"], [22, "foul_card"], [23, "simulate:0.9"], [30, "shot:foul_down.png"],
			[31, "until_card"], [40, "shot:foul_card.png"], [41, "until_replay"], [42, "simulate:2.0"],
			[50, "shot:foul_replay.png"], [51, "until_restart"], [52, "simulate:0.4"],
			[60, "shot:foul_freekick.png"], [65, "quit"]]
	# `--training`: el Club House y cada práctica, más el menú de práctica.
	if "--training" in OS.get_cmdline_user_args():
		GameSettings.training = true
		GameSettings.training_kind = 0
		_script = [[20, "freeze"], [22, "train:0"], [23, "simulate:0.8"], [30, "shot:train_free.png"],
			[31, "train_overview"], [38, "shot:train_overview.png"], [39, "end_cinematic"],
			[40, "train:1"], [41, "simulate:0.4"], [48, "shot:train_freekick.png"],
			[50, "train:4"], [51, "simulate:1.2"], [58, "shot:train_slalom.png"],
			[60, "train:5"], [61, "simulate:0.6"], [68, "shot:train_passing.png"],
			[70, "train:6"], [71, "simulate:1.0"], [78, "shot:train_rondo.png"],
			[80, "train:7"], [81, "simulate:0.4"], [88, "shot:train_targets.png"],
			[90, "train_pause"], [98, "shot:train_pause.png"], [100, "quit"]]
	# `--shot=x,y,z,mx,my,mz[,fov]`: una sola toma fija sin jugadores.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_script = [[20, "freeze"], [21, "hide_players"], [22, "cam:" + a.trim_prefix("--shot=")],
				[30, "shot:shot.png"], [32, "quit"]]
	# `--far`: la cámara Lejana (con los nombres de todos) en un ataque.
	if "--far" in OS.get_cmdline_user_args():
		_script = [[20, "freeze"], [25, "preset:Lejana"], [30, "attack"], [80, "shot:capture_lejana.png"], [85, "quit"]]
	# `--retro`: jugadores con el modelo retro (estilo PS1).
	if "--retro" in OS.get_cmdline_user_args():
		GameSettings.player_style = 1
	# `--teams=local,visitante` (rutas: db:club:arg:boca, db:nat:bra...).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--teams="):
			var tv := arg.trim_prefix("--teams=").split(",")
			GameSettings.home_team_path = tv[0]
			GameSettings.away_team_path = tv[1]
			GameSettings.stadium_choice = -1
	# `--stadium=N`: estadio (StadiumStyles).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stadium="):
			GameSettings.stadium_choice = int(arg.trim_prefix("--stadium="))
	# `--intro`: la presentación previa (menú, calentamiento, túnel, presentación...).
	if "--intro" in OS.get_cmdline_user_args():
		GameSettings.play_intro = true
		_script = [[5, "freeze"], [30, "shot:intro_menu.png"],
			[35, "intro:1"], [36, "simulate:1.5"], [42, "shot:intro_warmup.png"],
			[43, "simulate:2.6"], [50, "shot:intro_warmup_keeper.png"],
			[55, "intro:2"], [56, "simulate:2.5"], [62, "shot:intro_tunnel_mouth.png"],
			[63, "simulate:6"], [70, "shot:intro_tunnel.png"],
			[75, "intro:3"], [76, "simulate:1"], [84, "shot:intro_lineup.png"],
			[85, "simulate:2"], [92, "shot:intro_lineup2.png"],
			[93, "simulate:0.6"], [94, "shot:intro_flag.png"],
			[95, "intro:4"], [96, "simulate:1.5"], [110, "shot:intro_present.png"],
			[111, "simulate:4"], [118, "shot:intro_present2.png"],
			[119, "intro:5"], [120, "simulate:6"], [126, "shot:intro_present_away.png"],
			[127, "intro:6"], [128, "simulate:1.2"], [132, "shot:intro_photo.png"],
			[133, "simulate:0.45"], [134, "shot:intro_photo_flash.png"],
			[135, "intro:7"], [136, "simulate:0.3"], [145, "shot:intro_formation.png"], [150, "quit"]]
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	GameSettings.camera_preset = 0
	_match = load("res://scenes/match/match.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_match)
	# Saca el menú principal para que no tape la escena.
	_remove_menu.call_deferred()


func _remove_menu() -> void:
	if _replay_angle >= 0 and _match.replay != null:
		_match.replay.force_angle = _replay_angle
	var menu := get_tree().current_scene
	if menu != null and menu != _match:
		menu.queue_free()


func _process(_delta: float) -> void:
	_frame += 1
	for step in _script:
		if step[0] == _frame:
			_run(step[1])


## Un paso de simulación con las animaciones al mismo reloj (si no, quedan
## congeladas): jugadores, expulsados que siguen a la vista y árbitro.
func _step_all() -> void:
	_match._physics_process(1.0 / 60.0)
	var visuals: Array = []
	for t in _match.teams:
		for p in t.players + t.sent_off:
			visuals.append(p.visual)
	if _match.referee != null:
		visuals.append(_match.referee.visual)
	for v in visuals:
		if v is ModelVisual:
			(v as ModelVisual)._anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			(v as ModelVisual)._anim.advance(1.0 / 60.0)


func _run(action: String) -> void:
	if _camera == null:
		for c in _match.get_children():
			if c is MatchCamera:
				_camera = c
	if action == "freeze":
		# Simulación congelada: la cámara se acomoda y las fotos son estables.
		_match.set_physics_process(false)
	elif action == "hide_players":
		for p in _match.all_players():
			p.visible = false
		# `--empty=F`: fracción del público que ya se fue (salida por los pasillos).
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--empty=") and StadiumBuilder.crowd_material != null:
				StadiumBuilder.crowd_material.set_shader_parameter("empty", float(a.trim_prefix("--empty=")))
	elif action.begins_with("cam:"):
		# cam:x,y,z,mira_x,mira_y,mira_z[,fov]: toma fija para revisar algo.
		var v := action.trim_prefix("cam:").split(",")
		var fov := float(v[6]) if v.size() > 6 else 45.0
		_camera.set_shot(Vector3(float(v[0]), float(v[1]), float(v[2])),
			Vector3(float(v[3]), float(v[4]), float(v[5])), fov)
	elif action == "throw_in":
		_place(Vector3(-8, 0, Pitch.HALF_WIDTH - 0.3), Vector3(-8.5, 0.11, Pitch.HALF_WIDTH - 0.6))
	elif action == "attack":
		_place(Vector3(36, 0, -8), Vector3(36.5, 0.11, -8))
	elif action == "tactical_view":
		# Vista táctica sólo para capturas: dron alto que ve toda la cancha.
		var c := CameraConfig.new()
		c.display_name = "Táctica"
		c.mode = CameraConfig.Mode.TOPDOWN
		c.camera_height = 118.0
		c.base_fov = 50.0
		c.follow_speed = 100.0
		_camera.config = c
		_camera._focus = Vector3.ZERO
	elif action.begins_with("simulate:"):
		# Avanza la simulación un tiempo exacto sin depender de los FPS.
		var secs := float(action.trim_prefix("simulate:"))
		# Animaciones sólo con el reloj de la simulación: entre la simulación y
		# la foto pasan cuadros reales (lentos sin GPU) que la adelantarían.
		for p in _match.all_players():
			if p.visual is ModelVisual:
				(p.visual as ModelVisual)._anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for i in int(secs * 60.0):
			_step_all()
	elif action == "real_time":
		_match.set_physics_process(true)
	elif action == "unfreeze":
		_match.set_physics_process(true)
	elif action == "attack_live":
		var t0 := _match.teams[0]
		var carrier: Footballer = t0.players[6]
		_place(t0.to_world(Vector2(0.55, 0.1)), t0.to_world(Vector2(0.56, 0.1)) + Vector3(0, 0.11, 0), carrier)
	elif action == "corner":
		var t0 := _match.teams[0]
		var spot := Vector3(t0.attack_dir * (Pitch.HALF_LENGTH - 0.4), 0.11, -(Pitch.HALF_WIDTH - 0.4))
		_match._pending = MatchRules.Outcome.new(MatchRules.Restart.CORNER, 0, spot)
		_match._setup_restart(_match._pending)
	elif action == "goal_kick":
		var t1 := _match.teams[1]
		var spot2 := Vector3(t1.own_side() * (Pitch.HALF_LENGTH - 5.5), 0.11, 4.0)
		_match._pending = MatchRules.Outcome.new(MatchRules.Restart.GOAL_KICK, 1, spot2)
		_match._setup_restart(_match._pending)
	elif action == "shoot_scene":
		# Remate cruzado desde la puerta del área contra el arquero rival.
		var t1 := _match.teams[1]
		var shooter: Footballer = _match.teams[0].players[9]
		var goal := t1.own_goal()
		_place(goal + Vector3(-t1.own_side() * 16.0, 0, 3.0), goal + Vector3(-t1.own_side() * 15.5, 0.11, 3.0), shooter)
		shooter.facing = Vector3(t1.own_side(), 0, 0)
		var gk := t1.keeper()
		gk.teleport(goal + Vector3(-t1.own_side() * 1.0, 0, 0), Vector3(-t1.own_side(), 0, 0))
		_camera._focus = shooter.flat_pos()
		_match.perform_kick(shooter, KickActions.Kind.SHOT, Vector3(0, 0, -1), 0.8)
	elif action == "pass_scene":
		var p: Footballer = _match.teams[0].players[6]
		_place(Vector3(-5, 0, 2), Vector3(-4.5, 0.11, 2), p)
		_camera._focus = p.flat_pos()
		_match.perform_kick(p, KickActions.Kind.SHORT_PASS, Vector3(1, 0, 0), 0.5)
	elif action == "slide_scene":
		var carrier: Footballer = _match.teams[0].players[6]
		_place(Vector3(-5, 0, 2), Vector3(-4.6, 0.11, 2), carrier)
		var slider: Footballer = _match.teams[1].players[6]
		slider.teleport(Vector3(-2.6, 0, 2), Vector3.LEFT)
		slider.start_slide(Vector3.LEFT)
		_match.tuning.slide_trip_chance = 1.0
		_camera._focus = carrier.flat_pos()
	elif action == "tackle_scene":
		_match.tuning.slide_trip_chance = 0.5
		var c2: Footballer = _match.teams[0].players[6]
		_place(Vector3(-5, 0, 2), Vector3(-4.6, 0.11, 2), c2)
		var d2: Footballer = _match.teams[1].players[6]
		d2.teleport(Vector3(-3.8, 0, 2), Vector3.LEFT)
		d2.visual.play(PlayerVisual.Event.TACKLE)
		_camera._focus = c2.flat_pos()
	elif action == "goal_scene":
		var scorer: Footballer = _match.teams[0].players[9]
		_place(Vector3(30, 0, 4), Vector3(30.5, 0.11, 4), scorer)
		_match.ball.owner_player = null
		_match.ball.last_toucher = scorer
		_match._show_goal(0)
		_camera._focus = scorer.flat_pos()
	elif action == "late":
		# Segundo tiempo avanzado (nieve acumulada).
		_match.clock.half = 2
		_match.clock.game_seconds = MatchClock.HALF_GAME_SECONDS * 0.6
	elif action.begins_with("intro:"):
		_match.intro._enter(int(action.trim_prefix("intro:")))
	elif action == "foul_card":
		# Falta de atrás a 22 m del arco rival, hasta que salga con tarjeta.
		var t0 := _match.teams[0]
		var spot := t0.target_goal() - Vector3(t0.attack_dir * 22.0, 0, -2.0)
		for i in 40:
			var victim: Footballer = t0.players[9]
			var offender: Footballer = _match.teams[1].players[5]
			_match.phase = MatchController.Phase.PLAYING
			_match.card_scene = {}
			_match.replay_request = {}
			victim.teleport(spot, Vector3(t0.attack_dir, 0, 0))
			offender.teleport(spot - Vector3(t0.attack_dir * 0.9, 0, 0), Vector3(t0.attack_dir, 0, 0))
			for k in 90:
				_match._physics_process(1.0 / 60.0)
			_match.phase = MatchController.Phase.PLAYING
			_match.ball.place(spot + Vector3(t0.attack_dir * 0.6, 0.11, 0))
			_match.ball.state.vel = Vector3.ZERO
			_match.call_foul(offender, victim, true)
			if not _match.card_scene.is_empty():
				break
		_camera._focus = spot
	elif action == "until_card":
		for i in 600:
			if _match.referee.card_left > 0.0:
				break
			_step_all()
		for i in 40:
			_step_all()
	elif action.begins_with("train:"):
		_match.training.start(int(action.trim_prefix("train:")))
		_camera._focus = _match.ball.flat_pos()
	elif action == "train_overview":
		# Vista general: la cancha, los árboles y el edificio del club.
		_camera.set_shot(Vector3(-30.0, 22.0, 60.0), Vector3(0.0, 2.0, -25.0), 55.0)
	elif action == "end_cinematic":
		_camera.end_cinematic()
	elif action == "train_pause":
		process_mode = Node.PROCESS_MODE_ALWAYS
		for c in _match.get_children():
			if c is PauseMenu:
				(c as PauseMenu)._toggle()
	elif action.begins_with("pause_sub:"):
		_pause_menu()._open_sub(action.trim_prefix("pause_sub:"))
	elif action == "until_restart":
		for i in 1200:
			if _match.phase == MatchController.Phase.RESTART:
				break
			_step_all()
	elif action == "until_replay":
		# Pasa el festejo hasta que arranca la cortina de la repetición.
		for i in 900:
			if _match.phase == MatchController.Phase.REPLAY:
				break
			_match._physics_process(1.0 / 60.0)
		for i in 10:
			_match._physics_process(1.0 / 60.0)
	elif action == "replay_goal":
		var t0 := _match.teams[0]
		var shooter: Footballer = t0.players[9]
		var goal := t0.target_goal()
		_match.teams[1].keeper().teleport(goal - Vector3(t0.attack_dir * 12.0, 0, 18.0))
		_place(goal - Vector3(t0.attack_dir * 20.0, 0, 6.0), goal - Vector3(t0.attack_dir * 19.5, -0.11, 6.0), shooter)
		_camera._focus = shooter.flat_pos()
		# Corre hacia el arco y remata (se graba para la repetición).
		GameSettings.offside = false
		for i in 50:
			shooter.desired_move = Vector3(t0.attack_dir, 0, 0.3).normalized()
			shooter.wants_sprint = true
			_match._physics_process(1.0 / 60.0)
		# Si la simulación cortó el juego (falta, offside), se reanuda para el remate.
		_match.phase = MatchController.Phase.PLAYING
		_match.restart_taker = null
		_match.ball.frozen = false
		shooter.state = Footballer.State.NORMAL
		_match.ball.place(shooter.flat_pos() + Vector3(t0.attack_dir * 0.5, 0.11, 0))
		_match.ball.give_to(shooter)
		_match.kicks.randomize_error = false
		_match.perform_kick(shooter, KickActions.Kind.SHOT, (goal - shooter.flat_pos()).normalized(), 0.8)
		for i in 90:
			_match._physics_process(1.0 / 60.0)
			if _match.phase == MatchController.Phase.GOAL:
				break
	elif action == "sheet":
		var t0 := _match.teams[0]
		for p in _match.all_players():
			p.wear = randf_range(12.0, 34.0)
			p.stamina = randf_range(45.0, p.stamina_cap())
		_pause_menu()._sheet.open(_match, t0, false)
		_pause_menu()._sheet._rows[9].grab_focus()
	elif action == "sheet_col":
		_pause_menu()._sheet.cycle_column(1)
		_pause_menu()._sheet._rows[9].grab_focus()
	elif action == "sheet_mark":
		var sh := _pause_menu()._sheet
		sh.press_entry(sh.entries()[9])
		sh._rows[14].grab_focus()
	elif action == "subs_menu":
		var sh := _pause_menu()._sheet
		var t0 := _match.teams[0]
		t0.players[9].wear = 31.0
		sh.open(_match, t0, false)
		sh.press_entry(sh.entries()[9])
		sh._rows[14].grab_focus()
	elif action == "subs_close":
		_pause_menu()._sheet.close()
	elif action == "keeper_red":
		# Sin cambios: el defensor más cercano va al arco con ropa de arquero.
		var t1 := _match.teams[1]
		t1.subs_used = Team.MAX_SUBS
		_match.send_off(t1.keeper())
		var gk := t1.keeper()
		gk.teleport(t1.own_goal() + Vector3(-t1.own_side() * 6.0, 0, 2.0), Vector3(-t1.own_side(), 0, 0))
		_match.phase = MatchController.Phase.PLAYING
		_match.restart_taker = null
		_match.ball.frozen = false
		_match.ball.give_to(gk, false, true)
		_camera._focus = gk.flat_pos()
	elif action == "keeper_hold":
		var t1 := _match.teams[1]
		var gk := t1.keeper()
		gk.teleport(t1.own_goal() + Vector3(-t1.own_side() * 6.0, 0, 2.0), Vector3(-t1.own_side(), 0, 0))
		_match.phase = MatchController.Phase.PLAYING
		_match.restart_taker = null
		_match.ball.frozen = false
		_match.ball.give_to(gk, false, true)
		_camera._focus = gk.flat_pos()
	elif action.begins_with("skill:"):
		var sp: Footballer = _match.teams[0].players[9]
		_place(Vector3(10, 0, 4), Vector3(10.5, 0.11, 4), sp)
		sp.celebrate_timer = 0.0
		sp.skill = Footballer.Skill.NONE
		if sp.visual is ModelVisual:
			(sp.visual as ModelVisual)._clip = ""
		_camera._focus = sp.flat_pos()
		match action.trim_prefix("skill:"):
			"roulette":
				_match.perform_skill(sp, Footballer.Skill.ROULETTE)
			"stepover":
				_match.perform_skill(sp, Footballer.Skill.STEPOVER)
			"feint":
				_match.perform_feint(sp, Vector3.ZERO)
	elif action.begins_with("preset:"):
		var name := action.trim_prefix("preset:")
		for i in _camera.presets.size():
			if _camera.presets[i].display_name == name:
				_camera.set_preset(i)
	elif action == "debug":
		for c in _match.get_children():
			if c is DebugOverlay:
				c._set_enabled(true)
	elif action.begins_with("shot:"):
		_save(action.trim_prefix("shot:"))
	elif action == "quit":
		get_tree().quit()


func _pause_menu() -> PauseMenu:
	for c in _match.get_children():
		if c is PauseMenu:
			return c
	return null


func _place(player_pos: Vector3, ball_pos: Vector3, who: Footballer = null) -> void:
	var p: Footballer = who if who != null else _match.teams[0].players[9]
	_match.phase = MatchController.Phase.PLAYING
	_match.restart_taker = null
	_match.ball.frozen = false
	p.locked = false
	p.teleport(player_pos, Vector3.RIGHT)
	_match.ball.place(ball_pos)
	_match.ball.give_to(p)
	_match.humans[0].select(p)


func _save(file: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.trim_suffix("/") + "/" + file
	print("captura: %s (%s)" % [path, error_string(img.save_png(path))])
