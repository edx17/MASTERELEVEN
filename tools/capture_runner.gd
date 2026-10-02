extends Node
## Capturas del partido para revisar cámara y presentación sin abrir el editor.
## Se activa arrancando el juego con un argumento de usuario:
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-method gl_compatibility \
##       --resolution 1280x720 -- --capture=/ruta/de/salida
## Guarda una captura por modo de cámara, una de un lateral sobre la banda
## cercana a la cámara y una con el modo debug, y sale.

var out_dir := "user://"
var _match: MatchController
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
			[25, "intro:6"], [40, "shot:capture_tv.png"], [45, "quit"]]
	# `--late`: con el reloj en el segundo tiempo (minuto ~72).
	if "--late" in OS.get_cmdline_user_args():
		_script.insert(1, [21, "late"])
	# `--subs`: pantalla de cambios de la pausa y un jugador de campo en el arco.
	if "--subs" in OS.get_cmdline_user_args():
		_script = [[20, "freeze"], [25, "late"], [30, "subs_menu"], [50, "shot:capture_subs.png"],
			[55, "subs_close"], [56, "preset:Cercana"], [57, "keeper_red"], [58, "simulate:0.5"],
			[80, "shot:capture_field_keeper.png"], [85, "quit"]]
	# `--stadium=N`: estadio (StadiumStyles).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stadium="):
			GameSettings.stadium_choice = int(arg.trim_prefix("--stadium="))
	# `--intro`: la presentación previa (menú, calentamiento, túnel, saludo...).
	if "--intro" in OS.get_cmdline_user_args():
		GameSettings.play_intro = true
		_script = [[5, "freeze"], [30, "shot:intro_menu.png"],
			[35, "intro:1"], [36, "simulate:4"], [50, "shot:intro_warmup.png"],
			[55, "intro:2"], [56, "simulate:2.5"], [62, "shot:intro_tunnel_mouth.png"],
			[63, "simulate:6"], [70, "shot:intro_tunnel.png"],
			[75, "intro:3"], [76, "simulate:1"], [84, "shot:intro_lineup.png"],
			[85, "simulate:2"], [92, "shot:intro_lineup2.png"],
			[95, "intro:4"], [96, "simulate:3.5"], [110, "shot:intro_handshake.png"],
			[111, "simulate:3"], [118, "shot:intro_handshake2.png"],
			[119, "simulate:3"], [126, "shot:intro_handshake3.png"],
			[135, "intro:5"], [136, "simulate:0.3"], [145, "shot:intro_formation.png"], [150, "quit"]]
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	GameSettings.camera_preset = 0
	_match = load("res://scenes/match/match.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_match)
	# Saca el menú principal para que no tape la escena.
	_remove_menu.call_deferred()


func _remove_menu() -> void:
	var menu := get_tree().current_scene
	if menu != null and menu != _match:
		menu.queue_free()


func _process(_delta: float) -> void:
	_frame += 1
	for step in _script:
		if step[0] == _frame:
			_run(step[1])


func _run(action: String) -> void:
	if _camera == null:
		for c in _match.get_children():
			if c is MatchCamera:
				_camera = c
	if action == "freeze":
		# Simulación congelada: la cámara se acomoda y las fotos son estables.
		_match.set_physics_process(false)
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
			_match._physics_process(1.0 / 60.0)
			# Las animaciones avanzan con el mismo reloj (si no, quedan congeladas).
			for p in _match.all_players():
				if p.visual is ModelVisual:
					(p.visual as ModelVisual)._anim.advance(1.0 / 60.0)
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
	elif action == "subs_menu":
		var pm := _pause_menu()
		var t0 := _match.teams[0]
		t0.players[9].wear = 31.0
		pm._open_subs()
		pm._pick_out(t0.players[9])
		pm._pick_in(t0.bench[3])
	elif action == "subs_close":
		_pause_menu()._subs_panel.visible = false
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
