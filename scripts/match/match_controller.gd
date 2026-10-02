class_name MatchController
extends Node3D
## Raíz de la escena de partido. Arma el mundo, lleva la máquina de estados
## (saque del medio, juego, pelota parada, gol, entretiempo, final) y ejecuta
## la simulación en un orden fijo por cada tick de física:
##   humanos -> IA -> jugadores -> separación -> pelota -> posesión -> reglas -> reloj

signal goal_scored(team_index: int)
signal phase_changed(phase: int)
## Se mostró una tarjeta amarilla.
signal card_shown(player: Footballer)

enum Phase { PLAYING, STOPPED, RESTART, GOAL, HALFTIME, FULLTIME, INTRO, REPLAY }

const FORECAST_STEP := 0.1
const FORECAST_POINTS := 30
const STOP_DELAY := 1.1
const FOUL_DELAY := 2.0
const GOAL_DELAY := 3.0
const HALFTIME_DELAY := 3.0
const RESTART_AI_DELAY := 1.0
const RESTART_HUMAN_DELAY := 0.35
## Saque de arco: el arquero deja la pelota en la línea del área chica,
## retrocede para tomar carrera y recién ahí va a patear.
const GOAL_KICK_RUNUP := 5.0
const GOAL_KICK_WALK := 2.0
const GOAL_KICK_RUN := 5.2
const PLAYER_SEPARATION := 0.85
## Distancia máxima jugador-pelota para poder patear.
const KICK_REACH := 1.25
## Desde esta altura un toque es de cabeza (más abajo, pecho / muslo / pie).
const HEADER_MIN_HEIGHT := 1.3
## Duración de la marsellesa y de la bicicleta (s) y espera máxima de la pared.
const ROULETTE_TIME := 0.7
const STEPOVER_TIME := 0.6
const ONE_TWO_TIMEOUT := 4.0
## Un desvío más rápido que esto hacia el arco se trata como remate (plan de atajada).
const DEFLECTION_SHOT_SPEED := 12.0
## Tiempo tras el despeje del arquero con las manos en que un rival no la puede
## cortar (la pelota sube rápido; no se "rebota" en el que presiona).
const KEEPER_KICK_SHIELD := 0.3

var tuning: Tuning
## Horario, clima, viento y césped de este partido.
var conditions: MatchConditions
var atmosphere: Atmosphere
## Presentación previa (sólo al entrar desde el menú).
var intro: MatchIntro
var ball: Ball
var teams: Array[Team] = []
var clock: MatchClock
var kicks: KickActions
var humans: Array[HumanController] = []
var ais: Array[TeamAI] = []

var phase: Phase = Phase.RESTART
var restart_type: int = MatchRules.Restart.KICKOFF
var restart_taker: Footballer = null
## Veces que se pateó la pelota (lo usa el cambio automático de jugador).
var kick_count: int = 0
## Trayectoria predicha de la pelota suelta (cada FORECAST_STEP segundos).
var ball_forecast: Array[Vector3] = []
## Nodo raíz del estadio (la cámara oculta la tribuna que la tapa).
var stadium: Node3D
## Aviso corto en pantalla (p. ej. al cambiar de cámara).
var toast_text: String = ""
var _toast_timer: float = 0.0
## Estadísticas simples del partido, por equipo.
## Repetición de los goles y último goleador (ball.last_toucher del gol).
var replay: Replay
var audio: MatchAudio
var goal_scorer: Footballer

var stats := {"shots": [0, 0], "saves": [0, 0], "tackles": [0, 0], "tackles_won": [0, 0],
	"fouls": [0, 0], "yellows": [0, 0], "reds": [0, 0], "offsides": [0, 0], "subs": [0, 0], "injuries": [0, 0], "contacts": [0, 0]}
## Atajada planificada para el último remate (ver SaveModel):
## {keeper, will_save, parry, point, time_left, chance}. Vacío si no hay.
var save_plan := {}
## Datos de la última patada (depuración / futuras repeticiones).
var last_kick := {}
## Pedido del humano (Triángulo mantenido defendiendo): el arquero sale a
## achicar. Uno por equipo; los controladores humanos lo fijan en cada tick.
var keeper_rush: Array[bool] = [false, false]
## Pedido del humano (Cuadrado mantenido defendiendo): un compañero de la CPU
## sale a presionar al que lleva la pelota. Vale por tick, como keeper_rush.
var support_press: Array[bool] = [false, false]
## Barrera del tiro libre en curso: {Footballer: posición}.
var wall_targets := {}
## Tiempo que el arquero lleva con la pelota en las manos (regla de los 6 s).
var hands_time: float = 0.0
## Arquero que soltó la pelota de las manos (Triángulo): no la puede volver a
## agarrar hasta que la toque otro jugador (reglamento).
var keeper_released: Footballer = null
## Pared en curso (L1 + X): {passer, receiver, run, time}. Vacío = ninguna.
var one_two := {}
## Mensaje grande para el HUD ("¡GOL!", "CÓRNER", ...).
var banner_text: String = ""

var _phase_timer: float = 0.0
var _restart_elapsed: float = 0.0
## Saque de arco en curso: 0 = retrocede, 1 = listo, 2 = carrera hacia la
## pelota con la orden guardada (`_goal_kick_order`).
enum GoalKickStage { BACKING, READY, RUNNING }
var goal_kick_stage: int = GoalKickStage.READY
var _goal_kick_order: Array = []
var _goal_kick_kicking := false
var _pending: MatchRules.Outcome = null
var _first_half_kicker: int = 0
var _camera: MatchCamera
var _hud: MatchHud
## true mientras se ejecuta perform_kick (para distinguir desvíos).
var _in_kick: bool = false


func _ready() -> void:
	# Copia del ajuste para este partido: el clima la modifica (césped mojado,
	# nieve, viento) sin tocar los valores base.
	conditions = GameSettings.make_conditions()
	tuning = GameSettings.tuning.duplicate()
	conditions.apply_to(tuning)
	randomize()
	Engine.time_scale = GameSettings.game_time_scale()
	_build_world()
	clock = MatchClock.new(float(GameSettings.match_minutes))
	_setup_controllers()
	# El HUD va después de los controladores: necesita saber cuántos humanos hay.
	_hud = MatchHud.new()
	add_child(_hud)
	_hud.setup(self)
	var dbg := DebugOverlay.new()
	add_child(dbg)
	dbg.setup(self)
	_first_half_kicker = randi() % 2
	if GameSettings.play_intro:
		# Desde el menú: presentación previa (menú con el estadio de fondo,
		# calentamiento, túnel, saludo, formaciones) y después el saque.
		GameSettings.play_intro = false
		_set_phase(Phase.INTRO)
		_hud.visible = false
		intro = MatchIntro.new()
		add_child(intro)
		intro.setup(self, _camera)
		intro.finished.connect(_on_intro_finished)
	else:
		_setup_kickoff(_first_half_kicker)


# --- Consultas usadas por controladores/IA/HUD --------------------------------

func opponents_of(team: Team) -> Team:
	return teams[1 - team.index]


func all_players() -> Array[Footballer]:
	var out: Array[Footballer] = []
	for t in teams:
		out.append_array(t.players)
	return out


## Juego detenido (la IA vuelve a posiciones y no se disputa la pelota).
func is_stopped() -> bool:
	return phase != Phase.PLAYING


func is_restart_taker(p: Footballer) -> bool:
	return phase == Phase.RESTART and p != null and p == restart_taker


## Esperando el saque del medio: todos (menos el que saca) quietos en su
## puesto hasta que se saca, como en WE.
func waiting_kickoff(p: Footballer) -> bool:
	return phase == Phase.RESTART and restart_type == MatchRules.Restart.KICKOFF and p != restart_taker


## La IA ejecutora puede sacar.
func restart_ready() -> bool:
	if phase == Phase.RESTART and restart_type == MatchRules.Restart.GOAL_KICK and goal_kick_stage == GoalKickStage.BACKING:
		return false # todavía está tomando carrera
	return phase == Phase.RESTART and _restart_elapsed >= RESTART_AI_DELAY


## Saque de arco: la pelota quieta en el piso (el arquero no la lleva aunque
## sea el ejecutor).
func goal_kick_in_progress() -> bool:
	return phase == Phase.RESTART and restart_type == MatchRules.Restart.GOAL_KICK and restart_taker != null


func attack_dirs() -> Array[int]:
	var dirs: Array[int] = [teams[0].attack_dir, teams[1].attack_dir]
	return dirs


# --- Construcción -------------------------------------------------------------

func _build_world() -> void:
	# Luz, cielo y clima según las condiciones del partido.
	# Estadio elegido (las luces de la noche dependen de su forma).
	var st_i := GameSettings.stadium_choice
	if st_i < 0:
		st_i = randi() % StadiumStyles.STYLES.size()
	StadiumStyles.current = StadiumStyles.get_style(st_i)
	atmosphere = Atmosphere.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	atmosphere.setup(conditions)
	add_child(PitchBuilder.build(atmosphere.grass_params()))
	stadium = StadiumBuilder.build(GameSettings.home_team(), GameSettings.away_team())
	add_child(stadium)
	if conditions.time_of_day == MatchConditions.TimeOfDay.NIGHT:
		StadiumBuilder.disable_shadows(stadium)

	ball = Ball.new()
	ball.name = "Ball"
	add_child(ball)
	ball.setup(tuning)
	ball.set_winter_ball(conditions.is_snow())
	kicks = KickActions.new(ball, tuning)
	ball.kicked.connect(_on_ball_kicked)

	var datas: Array[TeamData] = [GameSettings.home_team(), GameSettings.away_team()]
	for i in 2:
		var d := datas[i]
		var kit := d.kit(GameSettings.home_kit if i == 0 else GameSettings.away_kit)
		if i == 1 and GameSettings.kits_clash(kit[0], teams[0].color):
			kit = d.kit(1 - GameSettings.away_kit)
		var team := Team.new(i, d.team_name, d.short_name, kit[0], kit[1], d.keeper_color)
		team.data = d
		team.formation = d.formation
		# Condición del día de todo el plantel (flechas).
		var cond_rng := RandomNumberGenerator.new()
		cond_rng.randomize()
		for pd in d.players:
			team.conditions[pd] = PlayerData.roll_condition(cond_rng) if GameSettings.random_conditions else PlayerData.Condition.NORMAL
		team.attack_dir = 1 if i == 0 else -1
		teams.append(team)
		var formation := d.formation
		var starters := d.starters()
		for n in starters.size():
			var p := Footballer.new()
			add_child(p)
			p.setup(team, starters[n], formation.roles[n], formation.slots[n], tuning)
			p.tactical_role = formation.tactical_role(n)
			team.players.append(p)
			team.roster.append(p)
		# Suplentes: los que siguen en la lista (se crean al entrar).
		for n in range(starters.size(), d.players.size()):
			team.bench.append(d.players[n])

	_camera = MatchCamera.new()
	add_child(_camera)
	_camera.setup(self)
	_camera.current = true
	_camera.mode_changed.connect(func(n: String) -> void: show_toast("Cámara: %s" % n))
	atmosphere.attach(_camera, self)
	show_toast(conditions.describe(), 4.0)

	replay = Replay.new()
	add_child(replay)
	replay.setup(self)
	audio = MatchAudio.new()
	add_child(audio)
	audio.setup(self)
	replay.finished.connect(_on_replay_finished)

	var pause := PauseMenu.new()
	add_child(pause)


func _setup_controllers() -> void:
	match GameSettings.mode:
		GameSettings.Mode.VS_CPU:
			# En la Liga / Copa el humano también puede jugar de visitante.
			humans.append(HumanController.new(0, teams[clampi(GameSettings.human_side, 0, 1)], self))
		GameSettings.Mode.TWO_PLAYERS:
			humans.append(HumanController.new(0, teams[0], self))
			humans.append(HumanController.new(1, teams[1], self))
	for t in teams:
		# La dificultad sólo afecta a los equipos que maneja la CPU.
		var has_human := false
		for h in humans:
			if h.team == t:
				has_human = true
		var level: int = Difficulty.Level.NORMAL if has_human else GameSettings.difficulty
		ais.append(TeamAI.new(t, self, Difficulty.make(level)))


# --- Bucle principal ----------------------------------------------------------

func _on_intro_finished() -> void:
	_hud.visible = true
	_setup_kickoff(_first_half_kicker)


func _physics_process(dt: float) -> void:
	if phase == Phase.REPLAY:
		replay.tick(dt)
		return
	if phase == Phase.INTRO:
		# Presentación: sólo se mueven los jugadores (la pelota quieta).
		intro.tick(dt)
		for p in all_players():
			p.tick(dt, false)
		return
	_update_phase(dt)
	_update_forecast()

	keeper_rush = [false, false]
	support_press = [false, false]
	_update_one_two(dt)
	_update_keeper_hands(dt)
	for h in humans:
		h.tick(dt)
	for a in ais:
		a.tick(dt)
	var goal_kick := goal_kick_in_progress()
	if goal_kick:
		_drive_goal_kick()
	for p in all_players():
		p.tick(dt, ball.owner_player == p and not (goal_kick and p == restart_taker))
	_separate_players()
	if phase == Phase.PLAYING:
		_body_contact(dt)
	if phase == Phase.RESTART:
		_keep_distance_from_restart()

	_update_throw_in_hold()
	ball.tick(dt)
	for t in teams:
		var gk := t.keeper()
		if gk != null:
			gk.ball_in_hands = ball.in_hands and ball.owner_player == gk

	# Primero las reglas (una pelota que ya cruzó la línea no se puede atajar).
	if phase == Phase.PLAYING:
		_check_rules()
	if phase == Phase.PLAYING:
		_update_possession(dt)
		_check_offside()

	clock.running = phase in [Phase.PLAYING, Phase.STOPPED] or (phase == Phase.RESTART and restart_type != MatchRules.Restart.KICKOFF)
	# El reloj va en tiempo real aunque el juego corra más lento (velocidad).
	# Grabación para la repetición (el juego y el primer instante del gol).
	if phase == Phase.PLAYING or (phase == Phase.GOAL and _phase_timer > GOAL_DELAY - 0.8):
		replay.record()
	var real_dt := dt / maxf(Engine.time_scale, 0.01)
	clock.advance(real_dt)
	# Cansancio acumulado: corre con el reloj del partido.
	if clock.running:
		var game_dt := real_dt * clock.rate()
		for p in all_players():
			p.accumulate_wear(game_dt)
	if clock.is_half_over() and phase == Phase.PLAYING:
		_end_half()


func show_toast(text: String, seconds: float = 1.5) -> void:
	toast_text = text
	_toast_timer = seconds


## Dirección de pantalla (stick) -> cancha, según la cámara actual.
func screen_to_world(v: Vector3) -> Vector3:
	return _camera.screen_to_world(v) if _camera != null else v


func _process(dt: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= dt
		if _toast_timer <= 0.0:
			toast_text = ""


func _update_phase(dt: float) -> void:
	_phase_timer -= dt
	if not save_plan.is_empty():
		save_plan["time_left"] -= dt
		save_plan["elapsed"] += dt
		# La estirada recién cuando la pelota está por llegar.
		if not save_plan["dove"] and save_plan["elapsed"] >= save_plan["dive_at"]:
			save_plan["dove"] = true
			_show_dive(save_plan["keeper"], save_plan["save_point"])
		if save_plan["time_left"] <= 0.0 or not ball.is_loose():
			save_plan = {}
	match phase:
		Phase.RESTART:
			_restart_elapsed += dt
			if _restart_elapsed > 0.8:
				banner_text = ""
		Phase.STOPPED:
			if _phase_timer <= 0.0:
				_setup_restart(_pending)
		Phase.GOAL:
			if _phase_timer <= 0.0:
				if GameSettings.show_replays and replay.has_frames():
					banner_text = ""
					_set_phase(Phase.REPLAY)
					replay.start(_pending.team, goal_scorer)
				else:
					_setup_kickoff(1 - _pending.team)
		Phase.HALFTIME:
			if _phase_timer <= 0.0:
				for t in teams:
					t.attack_dir = -t.attack_dir
				for p in all_players():
					p.rest_at_halftime()
				clock.start_second_half()
				_setup_kickoff(1 - _first_half_kicker)
		Phase.FULLTIME:
			pass


func _set_phase(p: Phase) -> void:
	phase = p
	phase_changed.emit(p)


func _update_forecast() -> void:
	ball_forecast.clear()
	if not ball.is_loose():
		return
	var sim := ball.state.copy()
	var steps := int(round(FORECAST_STEP / BallPhysics.SIM_DT))
	for i in FORECAST_POINTS:
		for s in steps:
			BallPhysics.step(sim, BallPhysics.SIM_DT, tuning)
		ball_forecast.append(sim.pos)


# --- Pases y tiros ------------------------------------------------------------

## Punto único por el que pasan todos los pases/tiros (humanos e IA).
## `receiver`: compañero elegido de antemano (el humano lo ve marcado al cargar).
func perform_kick(player: Footballer, kind: int, dir: Vector3, power: float, receiver_hint: Footballer = null,
		variant: int = KickActions.Variant.NORMAL) -> Footballer:
	if player == null:
		return null
	var from_restart := restart_type if phase == Phase.RESTART else -1
	kicks.set_piece = from_restart in [MatchRules.Restart.FREE_KICK, MatchRules.Restart.PENALTY]
	# El adelantado que la juega de primera (cabezazo, remate) también está
	# en offside: se cobra antes de que su patada cuente.
	if phase == Phase.PLAYING and not _offside.is_empty() and player != _offside["kicker"]:
		if (_offside["flagged"] as Array).has(player):
			call_offside(player)
			_offside = {}
			return null
		_offside = {}
	if phase == Phase.RESTART:
		if player != restart_taker or _restart_elapsed < RESTART_HUMAN_DELAY:
			return null
		if restart_type == MatchRules.Restart.GOAL_KICK and not _goal_kick_kicking:
			# La orden se guarda: primero corre hasta la pelota.
			if _goal_kick_order.is_empty():
				_goal_kick_order = [kind, dir, power, receiver_hint, variant]
				goal_kick_stage = GoalKickStage.RUNNING
			return null
		player.speed_override = 0.0
		ball.frozen = false
		player.locked = false
		wall_targets = {}
		kicks.throw_in_mode = restart_type == MatchRules.Restart.THROW_IN
		restart_taker = null
		banner_text = ""
		_set_phase(Phase.PLAYING)
	elif phase != Phase.PLAYING:
		return null
	elif not can_kick(player):
		return null
	kicks.pressure = Dribble.pressure_from_distance(_nearest_opponent_distance(player))
	kicks.forced_receiver = receiver_hint
	kicks.variant = variant
	_snapshot_offside(player, from_restart)
	_in_kick = true
	var receiver := kicks.execute(kind, player, dir, clampf(power, 0.0, 1.0))
	_in_kick = false
	kicks.throw_in_mode = false
	kick_count += 1
	save_plan = {}
	if kind == KickActions.Kind.SHOT:
		stats["shots"][player.team.index] += 1
		_plan_save(player)
	last_kick = {"kind": kind, "team": player.team.index, "pos": player.flat_pos(), "keeper": player.is_keeper(), "player": player}
	return receiver


## Primer punto de la trayectoria predicha de la pelota suelta al que `p`
## llega a tiempo corriendo en sprint (compartido por IA y humanos).
func loose_ball_intercept(p: Footballer) -> Vector3:
	var speed := tuning.sprint_speed
	var hmax := control_height_for(p)
	for i in ball_forecast.size():
		var t := (i + 1) * FORECAST_STEP
		var bp := ball_forecast[i]
		# Sólo sirven los puntos donde la pelota ya está a altura de control.
		if bp.y > hmax:
			continue
		var flat := Vector3(bp.x, 0.0, bp.z)
		if p.flat_pos().distance_to(flat) <= speed * t + 0.6:
			return flat
	if ball_forecast.is_empty():
		return ball.flat_pos()
	var last := ball_forecast[ball_forecast.size() - 1]
	return Vector3(last.x, 0.0, last.z)


## Altura hasta la que `p` puede controlar una pelota suelta (pecho/muslo):
## el receptor designado de un pase, más; los demás, algo menos.
func control_height_for(p: Footballer) -> float:
	if p == ball.intended_receiver:
		return tuning.chest_control_height
	return tuning.loose_chest_height


## Decide al momento del remate si el arquero rival llega (SaveModel).
func _plan_save(shooter: Footballer) -> void:
	_plan_save_for(opponents_of(shooter.team), 0.0)


## Plan de atajada del arquero de `defenders` para la pelota tal como viaja
## ahora. `extra_reaction`: segundos de más (p. ej. pelota desviada).
func _plan_save_for(defenders: Team, extra_reaction: float) -> void:
	save_plan = {}
	var gk := defenders.keeper()
	if gk == null or gk.state != Footballer.State.NORMAL:
		return
	var goal_x := defenders.own_side() * Pitch.HALF_LENGTH
	var plan := SaveModel.predict_crossing(ball.state, goal_x, tuning)
	if not plan.on_target:
		return
	var bonus := ais[defenders.index].difficulty.keeper_bonus if defenders.index < ais.size() else 0
	var reaction := (gk.data.reaction if gk.data else 60) + bonus
	var gk_skill := (gk.data.goalkeeping if gk.data else 60) + bonus
	# Arquero que sale corriendo a achicar (Triángulo): reacciona peor al
	# remate (la picada pasa más fácil). Si se frena antes, la recupera.
	var gk_speed := Vector3(gk.velocity.x, 0.0, gk.velocity.z).length()
	extra_reaction += RUSH_REACTION * clampf((gk_speed - 2.5) / 3.0, 0.0, 1.0)
	SaveModel.evaluate(plan, gk.flat_pos(), reaction, gk_skill, extra_reaction)
	var will_save := randf() < plan.chance
	# Embolsa si le llega cómoda y no tan fuerte; si no, da rebote.
	var parry := ball.speed() > 20.0 or plan.margin < 0.5
	# Tiempos: reacciona plantado, se acomoda de costado y se tira cuando la
	# pelota está por llegar (lo que dura la estirada), no al momento del remate.
	var react := SaveModel.reaction_time(reaction, extra_reaction)
	save_plan = {"keeper": gk, "will_save": will_save, "parry": parry, "point": plan.point,
		"save_point": plan.save_point, "time_left": plan.time + 0.3, "chance": plan.chance,
		"elapsed": 0.0, "react": react, "dive_at": maxf(react, plan.save_time - DIVE_LEAD), "dove": false}


## Freno con la pelota (R2): pisa la pelota, que queda junto al pie, y el
## jugador se planta (un instante sin poder acelerar del todo).
func stop_with_ball(p: Footballer) -> void:
	if ball.owner_player != p or ball.in_hands:
		return
	p.velocity *= 0.1
	p.kick_brake = 0.25
	var foot := p.flat_pos() + p.facing * 0.35
	ball.state.pos = Vector3(foot.x, tuning.ball_radius, foot.z)
	ball.state.vel = Vector3(p.velocity.x, 0.0, p.velocity.z)
	ball.state.spin = Vector3.ZERO


## Reacción extra (s) del arquero que remata en plena carrera de achique.
const RUSH_REACTION := 0.2


## Lo que dura la estirada del arquero hasta el contacto (s).
const DIVE_LEAD := 0.3


## Lateral (sólo presentación): el que saca espera con la pelota en las dos
## manos atrás de la nuca; al sacar, la pelota sale desde las manos.
var _throw_holder: Footballer

func _update_throw_in_hold() -> void:
	var holder: Footballer = null
	if phase == Phase.RESTART and restart_type == MatchRules.Restart.THROW_IN and restart_taker != null:
		holder = restart_taker
	if _throw_holder != null and _throw_holder != holder and _throw_holder.visual != null:
		_throw_holder.visual.throw_hold = false
	_throw_holder = holder
	if holder == null or holder.visual == null:
		return
	holder.visual.throw_hold = true
	if holder.visual is ModelVisual:
		var off := (holder.visual as ModelVisual).throw_point() - ball.state.pos
		ball.visual_offset = off if off.length() < 3.0 else Vector3.ZERO


## Animación de quien la tocó (sólo presentación).
func _show_kick(kicker: Footballer) -> void:
	if kicker == null or kicker.visual == null:
		return
	var ev := PlayerVisual.Event.KICK
	if kicks.throw_in_mode:
		ev = PlayerVisual.Event.THROW
	elif _in_kick and kicks.hand_throw:
		# Saque con la mano del arquero: rodando, como en las bochas.
		ev = PlayerVisual.Event.ROLL
	elif ball.state.pos.y > 1.3:
		ev = PlayerVisual.Event.HEADER
	elif kicker.is_keeper() and ball.state.pos.y > 0.5:
		ev = PlayerVisual.Event.KICK
	elif _in_kick and ball.speed() < 16.0:
		ev = PlayerVisual.Event.PASS
	kicker.visual.play(ev)
	# Patada o pase a propósito: frena un instante mientras hace el gesto.
	if _in_kick and ev in [PlayerVisual.Event.KICK, PlayerVisual.Event.PASS] and not kicker.is_keeper():
		kicker.kick_brake = 0.3
	# La pelota se dibuja saliendo del pie (o de la cabeza) del gesto.
	if ev in [PlayerVisual.Event.KICK, PlayerVisual.Event.PASS, PlayerVisual.Event.HEADER]:
		var off := kicker.visual.contact_point(ev) - ball.state.pos
		ball.visual_offset = off if off.length() < 1.3 else Vector3.ZERO


## El arquero se tira hacia donde va la pelota (sólo presentación).
func _show_dive(gk: Footballer, point: Vector3) -> void:
	if gk.visual == null:
		return
	var rel := point - gk.flat_pos()
	rel.y = 0.0
	if rel.length() < 1.2:
		gk.visual.play(catch_event(point.y))
		return
	var right := gk.global_basis.x
	gk.visual.play(PlayerVisual.Event.DIVE_RIGHT if right.dot(rel) > 0.0 else PlayerVisual.Event.DIVE_LEFT)


## Toda patada que no pasa por perform_kick (desvío en el cuerpo, rebote del
## arquero, barrida) invalida el plan de atajada: la pelota cambió de rumbo.
## Si el desvío va al arco, se replanifica con algo más de reacción (el
## arquero se "come" el cambio de dirección).
func _on_ball_kicked(kicker: Footballer) -> void:
	_show_kick(kicker)
	if _in_kick:
		return
	if kicker != null and kicker.is_keeper():
		save_plan = {} # rebote del arquero: esa jugada ya se resolvió
		return
	save_plan = {}
	var v := ball.state.vel
	# Un desvío flojo no es un remate: el arquero la agarra como cualquier
	# pelota suelta (sin plan que le impida tocarla).
	if absf(v.x) < 3.0 or v.length() < DEFLECTION_SHOT_SPEED:
		return
	var defenders := teams[0] if int(signf(v.x)) == teams[0].own_side() else teams[1]
	_plan_save_for(defenders, 0.12)


## Reanudación que viene (para que la IA se ubique antes del saque):
## {type, team, spot, taker}. Vacío si no hay (juego, gol, saque del medio).
func upcoming_restart() -> Dictionary:
	if phase == Phase.STOPPED and _pending != null and _pending.type != MatchRules.Restart.GOAL:
		return {"type": _pending.type, "team": _pending.team, "spot": _pending.spot, "taker": null}
	if phase == Phase.RESTART and restart_type != MatchRules.Restart.KICKOFF and restart_taker != null:
		return {"type": restart_type, "team": restart_taker.team.index, "spot": ball.flat_pos(), "taker": restart_taker}
	return {}


## Aplica un nivel de dificultad a los equipos que maneja la CPU.
func apply_difficulty(level: int) -> void:
	for ai in ais:
		var has_human := false
		for h in humans:
			if h.team == ai.team:
				has_human = true
		if not has_human:
			ai.difficulty = Difficulty.make(level)


## Cambia la formación de un equipo durante el partido (menú de pausa).
func set_formation(team_index: int, formation: FormationData) -> void:
	var t := teams[team_index]
	t.formation = formation
	for n in mini(t.roster.size(), formation.slots.size()):
		var p := t.roster[n]
		p.base_spot = formation.slots[n]
		p.role = formation.roles[n] as Footballer.Role
		p.tactical_role = formation.tactical_role(n)
	show_toast("%s: %s" % [t.short_name, formation.formation_name])


## El jugador tiene la pelota al alcance del pie para patearla ahora.
func can_kick(player: Footballer) -> bool:
	if ball.owner_player == player and ball.state.pos.y > 0.5:
		return player.is_keeper() # en las manos del arquero
	if ball.owner_player == player:
		# El que conduce patea ya (como en WE), aunque la pelota esté en el
		# "toque" adelantado: no espera a volver a tenerla en el pie.
		return true
	if ball.owner_player != null and ball.owner_player != player:
		return false
	if ball.owner_player == null and not player.can_touch_ball():
		return false
	var d := ball.flat_pos().distance_to(player.flat_pos())
	if ball.state.pos.y < 1.8:
		return d < KICK_REACH
	# Pelota alta: de cabeza (saltando), con menos alcance.
	return in_header_reach(player)


## La pelota está donde el jugador la puede cabecear (saltando).
func in_header_reach(p: Footballer) -> bool:
	var h := ball.state.pos.y
	if h < HEADER_MIN_HEIGHT or h > tuning.header_max_height * 1.1 or not p.can_touch_ball():
		return false
	if p.state != Footballer.State.NORMAL:
		return false
	# Los altos llegan más arriba y un poco más lejos.
	var tall := p.data.body_height() if p.data else 1.0
	# El cabeceador salta mejor.
	if p.data != null and p.data.has_ability("cabeceador"):
		tall += 0.04
	if h > tuning.header_max_height * tall:
		return false
	return ball.flat_pos().distance_to(p.flat_pos()) < tuning.header_reach * lerpf(1.0, tall, 2.0)


# --- Posesión -----------------------------------------------------------------

func _update_possession(dt: float) -> void:
	if ball.owner_player == null:
		if not _try_header():
			_try_take_loose_ball()
	else:
		var carrier := ball.owner_player
		var opp := _nearest_opponent(carrier)
		carrier.dribble_pressure = 0.0 if opp == null else Dribble.pressure_from_distance(opp.flat_pos().distance_to(carrier.flat_pos()))
		if opp != null:
			carrier.shield_from = opp.flat_pos()
		_try_steal(dt)
	# Los pedidos de entrada valen sólo para este tick.
	for p in all_players():
		p.wants_tackle = false


func _nearest_opponent(p: Footballer) -> Footballer:
	var best: Footballer = null
	var best_d := INF
	for o in opponents_of(p.team).players:
		var d := o.flat_pos().distance_to(p.flat_pos())
		if d < best_d:
			best_d = d
			best = o
	return best


func _nearest_opponent_distance(p: Footballer) -> float:
	var o := _nearest_opponent(p)
	return INF if o == null else o.flat_pos().distance_to(p.flat_pos())


func _try_take_loose_ball() -> void:
	var bp := ball.flat_pos()
	var h := ball.state.pos.y
	var best: Footballer = null
	var best_d := INF
	var plan_keeper: Footballer = save_plan.get("keeper")
	var kicker := ball.last_toucher
	var keeper_kick := kicker != null and kicker.is_keeper() and ball.kick_age < KEEPER_KICK_SHIELD
	for p in all_players():
		if not p.can_touch_ball():
			continue
		if keeper_kick and p.team != kicker.team:
			continue
		var d := p.flat_pos().distance_to(bp)
		if p.state == Footballer.State.SLIDING:
			if d < tuning.slide_reach and h < 0.7:
				# Barrida a pelota suelta: la despeja hacia adelante.
				ball.kick(p.facing * 8.0 + Vector3.UP * 1.0, Vector3.ZERO, p)
				return
			continue
		var reach := tuning.control_radius
		if p == ball.intended_receiver:
			reach = tuning.receive_radius
		elif ball.speed() > tuning.intercept_fast_speed:
			# Un pase firme que pasa cerca no se corta "de casualidad": hay que
			# estar en la línea (como en WE).
			reach *= clampf(1.0 - (ball.speed() - tuning.intercept_fast_speed) / 12.0, 0.45, 1.0)
		# Pelota aérea: se baja con el pecho o el muslo (el receptor del pase,
		# más alta; cualquier otro, algo menos).
		var hmax := control_height_for(p)
		if keeper_can_use_hands(p):
			if p == plan_keeper:
				# Remate en curso: sólo la toca si el modelo dice que llega.
				if not save_plan["will_save"]:
					continue
				reach = tuning.keeper_reach + 0.4
			else:
				reach = tuning.keeper_reach if ball.speed() > 8.0 else 1.1
			hmax = tuning.keeper_catch_height
		if d < reach and h < hmax and d < best_d:
			best = p
			best_d = d
	if best == null:
		return
	var v := ball.state.vel
	var hands := keeper_can_use_hands(best)
	if hands:
		if best == plan_keeper and save_plan["parry"]:
			# Rebote hacia afuera (al costado del arco), no al medio del área.
			var wide := signf(bp.z) if absf(bp.z) > 0.3 else (1.0 if randf() < 0.5 else -1.0)
			var parry := Vector3(-v.x * 0.25, absf(v.y) * 0.3 + 3.0, wide * randf_range(5.0, 9.0))
			stats["saves"][best.team.index] += 1
			save_plan = {}
			ball.kick(parry, Vector3.ZERO, best)
			best.touch_block = 0.5
			return
	elif ball.speed() > 23.0 and randf() < 0.5:
		# Pelota muy fuerte: rebota en el cuerpo.
		ball.kick(-v * 0.25 + Vector3.UP * 1.5, Vector3.ZERO, best)
		best.touch_block = 0.25
		return
	if best.is_keeper() and ball.last_touch_team != best.team.index and ball.speed() > 12.0:
		stats["saves"][best.team.index] += 1
	var receiver := ball.intended_receiver
	if receiver != null and receiver != best:
		receiver.clear_pass_target()
	save_plan = {}
	if best.visual != null:
		if hands:
			best.visual.play(catch_event(h))
		elif best == receiver or ball.speed() > 6.0:
			_show_receive(best, h)
	ball.give_to(best, true, hands)


# --- Faltas -------------------------------------------------------------------

## Probabilidad de que una barrida (o una entrada fallida) sea falta: de
## atrás casi siempre, de costado a veces, de frente rara vez. Con el césped
## mojado se llega más tarde (más faltas).
func foul_chance(offender: Footballer, victim: Footballer, slide: bool) -> float:
	var to_off := offender.flat_pos() - victim.flat_pos()
	var front := victim.facing.dot(to_off.normalized()) if to_off.length() > 0.01 else 1.0
	var p: float
	if slide:
		p = 0.65 if front < -0.3 else (0.25 if front < 0.4 else 0.08)
	else:
		p = 0.35 if front < -0.3 else 0.1
	p += 0.1 * conditions.wetness if conditions != null else 0.0
	# El marcador entra limpio.
	if offender.data != null and offender.data.has_ability("marcador"):
		p *= 0.7
	return clampf(p, 0.0, 0.9)


## Cobra una falta: tiro libre donde fue (o penal si fue en el área del
## infractor), al que la recibió lo derriban, y quizás amarilla.
func call_foul(offender: Footballer, victim: Footballer, slide: bool) -> void:
	if phase != Phase.PLAYING:
		return
	var from_behind := victim.facing.dot((offender.flat_pos() - victim.flat_pos()).normalized()) < -0.3
	stats["fouls"][offender.team.index] += 1
	victim.trip(tuning.trip_duration * 0.8)
	_maybe_injure(victim, slide, from_behind)
	var spot := victim.flat_pos()
	var awarded := victim.team.index
	var type := MatchRules.Restart.FREE_KICK
	var text := "FALTA"
	if Pitch.in_penalty_area(spot, offender.team.own_side()):
		type = MatchRules.Restart.PENALTY
		text = "¡PENAL!"
		spot = penalty_spot(offender.team)
	else:
		spot = Pitch.clamp_to_field(spot, 1.0)
	# Tarjeta (como en el WE): barrida de atrás = roja directa casi siempre;
	# si no, amarilla a veces, y la segunda amarilla es roja. Al arquero
	# también lo pueden echar (ver _replace_keeper).
	var red := slide and from_behind and randf() < RED_FROM_BEHIND
	var yellow_p := (0.6 if from_behind else 0.2) if slide else (0.3 if from_behind else 0.05)
	if red:
		text += "   -   ROJA: %s" % offender.display_name
		send_off(offender)
		card_shown.emit(offender)
	elif randf() < yellow_p:
		offender.yellow_cards += 1
		stats["yellows"][offender.team.index] += 1
		if offender.yellow_cards >= 2:
			text += "   -   SEGUNDA AMARILLA, ROJA: %s" % offender.display_name
			send_off(offender)
		else:
			text += "   -   AMARILLA: %s" % offender.display_name
		card_shown.emit(offender)
	_pending = MatchRules.Outcome.new(type, awarded, Vector3(spot.x, tuning.ball_radius, spot.z))
	ball.owner_player = null
	ball.intended_receiver = null
	ball.state.vel = Vector3.ZERO
	save_plan = {}
	banner_text = text
	_phase_timer = FOUL_DELAY
	_set_phase(Phase.STOPPED)


# --- Offside ------------------------------------------------------------------

## Pase en curso: compañeros que estaban en posición adelantada cuando se
## pateó. {"team", "kicker", "flagged": Array[Footballer]}; vacío si no hay.
var _offside := {}


## Al patear: anota a los compañeros en posición adelantada (en campo rival,
## delante de la pelota y del penúltimo rival). No hay offside en laterales,
## saques de arco ni córners.
func _snapshot_offside(kicker: Footballer, from_restart: int) -> void:
	_offside = {}
	if not GameSettings.offside:
		return
	if from_restart in [MatchRules.Restart.THROW_IN, MatchRules.Restart.GOAL_KICK, MatchRules.Restart.CORNER]:
		return
	var flagged := offside_positions(kicker, ball.flat_pos())
	if not flagged.is_empty():
		_offside = {"team": kicker.team.index, "kicker": kicker, "flagged": flagged}


## Compañeros de `kicker` en posición adelantada con la pelota en `ball_pos`.
func offside_positions(kicker: Footballer, ball_pos: Vector3) -> Array[Footballer]:
	var team := kicker.team
	var dir := float(team.attack_dir)
	var depths: Array[float] = []
	for o in opponents_of(team).players:
		depths.append(o.flat_pos().x * dir)
	depths.sort()
	var second_last: float = depths[depths.size() - 2] if depths.size() >= 2 else 0.0
	var out: Array[Footballer] = []
	for m in team.players:
		if m == kicker:
			continue
		var d := m.flat_pos().x * dir
		if d > OFFSIDE_MARGIN and d > ball_pos.x * dir + OFFSIDE_MARGIN and d > second_last + OFFSIDE_MARGIN:
			out.append(m)
	return out


## Lo que tiene que sobrar para cobrarlo (m): "en línea" está habilitado.
const OFFSIDE_MARGIN := 0.3


## Si la toca primero uno que estaba adelantado, es offside; si la toca otro
## (o un rival), la jugada queda habilitada.
func _check_offside() -> void:
	if _offside.is_empty():
		return
	var t := ball.last_toucher
	if t == null or t == _offside["kicker"]:
		return
	var flagged: Array = _offside["flagged"]
	if t.team.index == _offside["team"] and flagged.has(t):
		call_offside(t)
	_offside = {}


## Offside: tiro libre para el que defiende donde estaba el adelantado.
func call_offside(p: Footballer) -> void:
	if phase != Phase.PLAYING:
		return
	stats["offsides"][p.team.index] += 1
	var spot := Pitch.clamp_to_field(p.flat_pos(), 1.0)
	_pending = MatchRules.Outcome.new(MatchRules.Restart.FREE_KICK, 1 - p.team.index, Vector3(spot.x, tuning.ball_radius, spot.z))
	ball.owner_player = null
	ball.intended_receiver = null
	ball.state.vel = Vector3.ZERO
	save_plan = {}
	banner_text = "FUERA DE JUEGO: %s" % p.display_name
	_phase_timer = FOUL_DELAY
	_set_phase(Phase.STOPPED)


## Probabilidad de roja directa en una barrida que es falta de atrás.
const RED_FROM_BEHIND := 0.85


## Expulsión: el jugador sale de la cancha (va al banco, no se dibuja) y el
## equipo sigue con uno menos; ya no cuenta para la IA, los controles, la
## posesión ni las reglas.
func send_off(p: Footballer) -> void:
	var t := p.team
	if not t.players.has(p):
		return
	var was_keeper := p.is_keeper()
	var slot := t.slot_of(p)
	t.players.erase(p)
	t.sent_off.append(p)
	p.sent_off = true
	stats["reds"][t.index] += 1
	for s in t.pending_subs.duplicate():
		if s["out"] == p:
			t.pending_subs.erase(s)
	_leave_pitch(p)
	if was_keeper:
		_replace_keeper(t, slot)


## Saca de la cancha a un expulsado o reemplazado (queda oculto en el banco).
func _leave_pitch(p: Footballer) -> void:
	var t := p.team
	if ball.owner_player == p:
		ball.owner_player = null
	if ball.intended_receiver == p:
		ball.intended_receiver = null
	p.desired_move = Vector3.ZERO
	p.velocity = Vector3.ZERO
	p.teleport(Vector3(-8.0 + t.index * 16.0, 0.0, Pitch.HALF_WIDTH + 3.5), Vector3.FORWARD)
	p.visible = false
	for h in humans:
		if h.controlled == p:
			p.set_human_slot(-1)
			h.controlled = null
			h.select(h.nearest_to_ball())


# --- Cambios ------------------------------------------------------------------

## Distancia al arco hasta la que el tiro libre lo patea el elegido.
const FK_TAKER_RANGE := 35.0

## Minuto desde el que la CPU cambia a los cansados.
const CPU_SUB_MINUTE := 55.0
## Energía (tope o actual) debajo de la cual la CPU considera cambiarlo.
const CPU_SUB_STAMINA := 80.0


## Pide un cambio: se hace ya si la pelota está parada; si no, en la próxima
## pelota parada. Devuelve false si no se puede (sin cambios, ya salió...).
func request_sub(out: Footballer, in_data: PlayerData) -> bool:
	var t := out.team
	if t.subs_left() <= 0 or not t.players.has(out) or not t.bench.has(in_data):
		return false
	for s in t.pending_subs:
		if s["out"] == out or s["in"] == in_data:
			return false
	t.pending_subs.append({"out": out, "in": in_data})
	var stopped := phase in [Phase.STOPPED, Phase.HALFTIME, Phase.GOAL]
	# Con un saque esperando también se puede, salvo que salga el que saca.
	if phase == Phase.RESTART and out != restart_taker and ball.owner_player != out:
		stopped = true
	if stopped:
		t.pending_subs.erase(t.pending_subs.back())
		substitute(out, in_data)
	else:
		show_toast("%s: cambio en la próxima pelota parada" % t.short_name)
	return true


## Hace los cambios pedidos (y los de la CPU) con la pelota parada.
func _make_pending_subs() -> void:
	for t in teams:
		if not _has_human(t):
			_cpu_strategy(t)
			_cpu_subs(t)
		for s in t.pending_subs.duplicate():
			t.pending_subs.erase(s)
			substitute(s["out"], s["in"])


## Cambio: `in_data` (del banco) entra en el puesto de `out`, en su lugar de
## la cancha. Devuelve el que entró (o null si no se pudo).
func substitute(out: Footballer, in_data: PlayerData, as_keeper := false) -> Footballer:
	var t := out.team
	if t.subs_used >= Team.MAX_SUBS or not t.players.has(out) or not t.bench.has(in_data):
		return null
	var p := Footballer.new()
	add_child(p)
	var role: int = Footballer.Role.GK if as_keeper else out.role
	p.setup(t, in_data, role, out.base_spot, tuning)
	p.tactical_role = out.tactical_role
	p.teleport(out.flat_pos(), out.facing)
	t.players[t.players.find(out)] = p
	var slot := t.slot_of(out)
	if slot >= 0:
		t.roster[slot] = p
	t.bench.erase(in_data)
	t.subbed_off.append(out)
	t.subs_used += 1
	stats["subs"][t.index] += 1
	_leave_pitch(out)
	show_toast("CAMBIO %s:  sale %s  -  entra %s" % [t.short_name, out.display_name, p.display_name], 2.5)
	return p


## Expulsaron al arquero: si quedan cambios y hay arquero suplente, entra él
## por un jugador de campo (un delantero, el más cansado); si no, va al arco
## el defensor más cerca del arco propio, con ropa de arquero y su número.
func _replace_keeper(t: Team, slot: int) -> void:
	var outfield: Array[Footballer] = []
	for p in t.players:
		if not p.is_keeper():
			outfield.append(p)
	if outfield.is_empty():
		return
	var sub_gk := t.bench_keeper()
	if sub_gk != null and t.subs_left() > 0:
		var out: Footballer = null
		for pref in [Footballer.Role.FW, Footballer.Role.MF, Footballer.Role.DF]:
			for p in outfield:
				if p.role == pref and (out == null or p.stamina < out.stamina):
					out = p
			if out != null:
				break
		var gk_spot := t.to_world(t.formation.slots[0]) if t.formation and slot >= 0 else t.own_goal()
		var gk := substitute(out, sub_gk, true)
		if gk != null:
			# El arquero va al arco; el delantero que salió deja su puesto vacío.
			var out_slot := t.roster.find(gk)
			if slot >= 0 and out_slot >= 0:
				t.roster[out_slot] = out
				t.roster[slot] = gk
				gk.base_spot = t.formation.slots[slot] if t.formation else gk.base_spot
				gk.tactical_role = t.formation.tactical_role(slot) if t.formation else gk.tactical_role
			gk.teleport(gk_spot, Vector3(t.attack_dir, 0.0, 0.0))
			return
	# Sin cambio: el defensor más cercano al arco propio se pone los guantes.
	var goal := t.own_goal()
	var best: Footballer = null
	for p in outfield:
		var d := p.flat_pos().distance_to(goal) - (8.0 if p.role == Footballer.Role.DF else 0.0)
		if best == null or d < best.flat_pos().distance_to(goal) - (8.0 if best.role == Footballer.Role.DF else 0.0):
			best = p
	var own_slot := t.slot_of(best)
	if slot >= 0 and own_slot >= 0:
		t.roster[own_slot] = t.roster[slot]
		t.roster[slot] = best
		if t.formation:
			best.base_spot = t.formation.slots[slot]
			best.tactical_role = t.formation.tactical_role(slot)
	best.make_keeper()
	show_toast("%s: %s va al arco" % [t.short_name, best.display_name], 2.5)


## La CPU cambia (de a uno por pelota parada) al más cansado desde el minuto
## 55, por un suplente del mismo puesto si hay.
func _cpu_subs(t: Team) -> void:
	if t.subs_left() <= 0 or clock.total_game_seconds() < CPU_SUB_MINUTE * 60.0:
		return
	var tired: Footballer = null
	for p in t.players:
		if p.is_keeper():
			continue
		var e := minf(p.stamina_cap(), p.stamina + 25.0)
		if e < CPU_SUB_STAMINA and (tired == null or e < minf(tired.stamina_cap(), tired.stamina + 25.0)):
			tired = p
	if tired == null:
		return
	var pick: PlayerData = null
	for d in t.bench:
		if d.position == PlayerData.Position.GK:
			continue
		if pick == null or (d.position == tired.data.position and pick.position != tired.data.position):
			pick = d
	if pick != null:
		t.pending_subs.append({"out": tired, "in": pick})


## Dos de la cancha intercambian sus puestos (no cuenta como cambio). Si uno
## pasa al arco o sale de él, se cambia la ropa.
func swap_slots(a: Footballer, b: Footballer) -> void:
	var t := a.team
	var sa := t.slot_of(a)
	var sb := t.slot_of(b)
	if t != b.team or sa < 0 or sb < 0 or a == b:
		return
	t.roster[sa] = b
	t.roster[sb] = a
	var spot_a := a.flat_pos()
	a.teleport(b.flat_pos(), b.facing)
	b.teleport(spot_a, a.facing)
	_apply_slot(a, sb)
	_apply_slot(b, sa)


## Pone al jugador en el puesto `slot` de la formación del equipo.
func _apply_slot(p: Footballer, slot: int) -> void:
	var f := p.team.formation
	var was_keeper := p.is_keeper()
	if f != null and slot < f.slots.size():
		p.base_spot = f.slots[slot]
		p.role = f.roles[slot] as Footballer.Role
		p.tactical_role = f.tactical_role(slot)
	if p.is_keeper() != was_keeper and p.visual != null:
		p.visual.recolor(p.kit_colors())


## Antes del partido: un suplente pasa a titular en el lugar de `out`, que
## vuelve al banco (no cuenta como cambio).
func swap_lineup(out: Footballer, in_data: PlayerData) -> Footballer:
	var t := out.team
	if not t.players.has(out) or not t.bench.has(in_data):
		return null
	var p := Footballer.new()
	add_child(p)
	p.setup(t, in_data, out.role, out.base_spot, tuning)
	p.tactical_role = out.tactical_role
	p.teleport(out.flat_pos(), out.facing)
	p.set_presenting(out.presenting)
	t.players[t.players.find(out)] = p
	t.roster[t.roster.find(out)] = p
	t.bench[t.bench.find(in_data)] = out.base_data
	for h in humans:
		if h.controlled == out:
			h.controlled = null
			h.select(p)
	out.queue_free()
	return p


## L2 + botón: activa la estrategia de ese botón (o la apaga si ya estaba).
func toggle_strategy(t: Team, slot: int) -> void:
	var kind: int = t.strategy_slots[clampi(slot, 0, t.strategy_slots.size() - 1)]
	set_strategy(t, Strategy.Kind.NONE if t.strategy == kind else kind)


func set_strategy(t: Team, kind: int) -> void:
	if t.strategy == kind:
		return
	t.strategy = kind
	show_toast("%s: %s" % [t.short_name, Strategy.NAMES[kind] if kind != Strategy.Kind.NONE else "sin estrategia"], 2.0)


## La CPU: todos al ataque si va perdiendo desde el 70', todos atrás si gana
## desde el 80'; si no, sin estrategia (la presión ya la decide su IA).
func _cpu_strategy(t: Team) -> void:
	var minute := clock.total_game_seconds() / 60.0
	var diff := t.score - opponents_of(t).score
	var kind := Strategy.Kind.NONE
	if minute >= 70.0 and diff < 0:
		kind = Strategy.Kind.ALL_ATTACK
	elif minute >= 80.0 and diff > 0:
		kind = Strategy.Kind.ALL_DEFENSE
	set_strategy(t, kind)


func _has_human(t: Team) -> bool:
	for h in humans:
		if h.team == t:
			return true
	return false


## Punto penal frente al arco de `team`.
func penalty_spot(team: Team) -> Vector3:
	return Vector3(team.own_side() * (Pitch.HALF_LENGTH - Pitch.PENALTY_SPOT_DISTANCE), 0.0, 0.0)


# --- Arquero con la pelota en las manos ---------------------------------------

## Reglamento: el arquero no puede tener la pelota en las manos más de 6 s.
## Al cumplirse, la juega solo según la opción elegida: pelotazo hacia
## adelante o la suelta para jugarla con los pies.
const KEEPER_HANDS_LIMIT := 6.0


func _update_keeper_hands(dt: float) -> void:
	if keeper_released != null and ball.last_toucher != keeper_released:
		keeper_released = null
	var gk := ball.owner_player
	if phase != Phase.PLAYING or gk == null or not ball.in_hands:
		hands_time = 0.0
		return
	hands_time += dt
	if hands_time < KEEPER_HANDS_LIMIT:
		return
	hands_time = 0.0
	if GameSettings.keeper_auto_action == 1:
		keeper_drop(gk)
	else:
		perform_kick(gk, KickActions.Kind.LONG_PASS, Vector3(gk.team.attack_dir, 0.0, 0.0), 0.8)


## Segundos que le quedan al arquero con la pelota en las manos (para el HUD).
func hands_time_left() -> float:
	return maxf(0.0, KEEPER_HANDS_LIMIT - hands_time) if ball.in_hands and phase == Phase.PLAYING else -1.0


## El arquero suelta la pelota y la juega con los pies (Triángulo, o al
## cumplirse los 6 s si así se eligió). No la puede volver a agarrar con las
## manos hasta que la toque otro.
func keeper_drop(gk: Footballer) -> void:
	if ball.owner_player != gk or not ball.in_hands:
		return
	ball.in_hands = false
	ball.state.pos = gk.flat_pos() + gk.facing * 0.5 + Vector3.UP * tuning.ball_radius
	ball.state.vel = Vector3.ZERO
	ball.visual_offset = Vector3.ZERO
	keeper_released = gk
	hands_time = 0.0


## El arquero puede usar las manos con esta pelota (en su área, no un pase
## atrás de un compañero, no la soltó él mismo).
func keeper_can_use_hands(gk: Footballer) -> bool:
	return gk.is_keeper() and Pitch.in_penalty_area(ball.flat_pos(), gk.team.own_side()) \
		and not is_back_pass_to(gk) and keeper_released != gk


# --- Gambetas y combinaciones (WE) --------------------------------------------

## Amague (Cuadrado + X / Círculo + X): hace el gesto de patear y engancha
## para el lado del stick (o lejos del rival más cercano). Los rivales cerca
## "se comen" el amague: quedan un instante sin reaccionar.
func perform_feint(p: Footballer, stick: Vector3) -> void:
	if ball.owner_player != p or phase != Phase.PLAYING:
		return
	var dir := Vector3(stick.x, 0.0, stick.z)
	if dir.length_squared() < 0.04 or dir.normalized().dot(p.facing) > 0.85:
		# Sin stick (o hacia adelante): engancha hacia el lado contrario al rival.
		var opp := _nearest_opponent(p)
		var side := 1.0
		if opp != null:
			side = -signf(p.facing.cross(opp.flat_pos() - p.flat_pos()).y)
			if side == 0.0:
				side = 1.0
		dir = p.facing.rotated(Vector3.UP, side * deg_to_rad(100.0))
	dir = dir.normalized()
	p.facing = dir
	p.velocity = dir * minf(Vector3(p.velocity.x, 0.0, p.velocity.z).length(), 2.5)
	ball.state.pos = Vector3(p.flat_pos().x, tuning.ball_radius, p.flat_pos().z) + dir * 0.45
	ball.state.vel = p.velocity
	p.start_skill(Footballer.Skill.FEINT, 0.35)
	_fool_defenders(p, 5.0, 0.5)
	if p.visual != null:
		p.visual.play(PlayerVisual.Event.FEINT)


## Marsellesa (giro de 360° con el stick derecho) y bicicleta (L1 x3).
func perform_skill(p: Footballer, skill: int) -> void:
	if ball.owner_player != p or phase != Phase.PLAYING or p.skill != Footballer.Skill.NONE:
		return
	match skill:
		Footballer.Skill.ROULETTE:
			p.start_skill(skill, ROULETTE_TIME)
			_fool_defenders(p, 3.0, 0.3)
			if p.visual != null:
				p.visual.play(PlayerVisual.Event.ROULETTE)
		Footballer.Skill.STEPOVER:
			p.start_skill(skill, STEPOVER_TIME)
			_fool_defenders(p, 5.0, 0.45)
			if p.visual != null:
				p.visual.play(PlayerVisual.Event.STEPOVER)


## Rivales de la CPU cerca del que gambetea: quedan `delay` s sin reaccionar.
func _fool_defenders(p: Footballer, radius: float, delay: float) -> void:
	for o in opponents_of(p.team).players:
		if o.is_human() or o.is_keeper():
			continue
		if o.flat_pos().distance_to(p.flat_pos()) < radius:
			o.reaction_timer = maxf(o.reaction_timer, delay)
			o.desired_move *= 0.3


## Pared (L1 + X): el receptor la devuelve de primera al espacio por donde
## corre el que la tocó.
func start_one_two(passer: Footballer, receiver: Footballer) -> void:
	if receiver == null or receiver.team != passer.team:
		return
	var fwd := Vector3(passer.team.attack_dir, 0.0, 0.0)
	var run := Pitch.clamp_to_field(passer.flat_pos() + fwd * 12.0, 2.0)
	one_two = {"passer": passer, "receiver": receiver, "run": run, "time": 0.0}


func cancel_one_two() -> void:
	one_two = {}


## Como en el WE: la marca rival sigue a la pelota y pierde por un rato al que
## pica en la pared (los primeros GHOST_TIME segundos).
const GHOST_TIME := 2.0

func is_ghost_runner(p: Footballer) -> bool:
	return not one_two.is_empty() and one_two["passer"] == p and float(one_two["time"]) < GHOST_TIME


## Comba en la pelota parada (stick derecho al patear un tiro libre o un
## córner, como la cruceta del WE): de costado curva hacia ese lado; adelante
## cae de golpe (topspin); atrás sale más alta y flota.
const SET_PIECE_CURL := 55.0
const SET_PIECE_DIP := 35.0

func apply_set_piece_curl(stick_world: Vector3) -> void:
	var v := Vector3(ball.state.vel.x, 0.0, ball.state.vel.z)
	if v.length() < 1.0 or stick_world.length() < 0.3:
		return
	var along := v.normalized()
	var perp := Vector3(along.z, 0.0, -along.x)
	var side := clampf(stick_world.dot(perp), -1.0, 1.0)
	var fwd := clampf(stick_world.dot(along), -1.0, 1.0)
	var axis := along.cross(Vector3.UP).normalized()
	ball.state.spin = Vector3(0.0, side * SET_PIECE_CURL, 0.0) - axis * fwd * SET_PIECE_DIP


func _update_one_two(dt: float) -> void:
	if one_two.is_empty():
		return
	one_two["time"] += dt
	var receiver: Footballer = one_two["receiver"]
	var passer: Footballer = one_two["passer"]
	var owner := ball.owner_player
	if one_two["time"] > ONE_TWO_TIMEOUT or phase != Phase.PLAYING or (owner != null and owner.team != passer.team):
		one_two = {}
		return
	if owner == receiver and not receiver.is_human():
		# La devuelve de primera al hueco por donde corre el que la tocó.
		var to_run: Vector3 = (one_two["run"] as Vector3) - receiver.flat_pos()
		one_two = {}
		perform_kick(receiver, KickActions.Kind.THROUGH_PASS, to_run, 0.45, passer)


## Gesto del arquero al embolsarla según la altura de la pelota.
static func catch_event(height: float) -> int:
	if height > 1.7:
		return PlayerVisual.Event.CATCH_HIGH
	if height < 0.45:
		return PlayerVisual.Event.CATCH_LOW
	return PlayerVisual.Event.CATCH


## Gesto del que recibe (sólo presentación): de pecho si viene alta; con la
## suela si llega frenado (a la carrera la recibe sin gesto, como en WE).
func _show_receive(p: Footballer, height: float) -> void:
	if height > 0.9:
		p.visual.play(PlayerVisual.Event.CHEST)
	elif Vector3(p.velocity.x, 0.0, p.velocity.z).length() < 1.2:
		# Casi quieto: control con la suela (el gesto es en el lugar; andando
		# se vería deslizarse de pie).
		p.visual.play(PlayerVisual.Event.RECEIVE)


## Duelo aéreo: una pelota alta que nadie puede bajar con el pecho la
## cabecea quien llegue (el más cercano). La CPU elige: cerca del arco rival,
## remate de cabeza; en su campo, despeje largo; si no, pase de cabeza a un
## compañero. El humano cabecea sólo si lo pidió (su orden guardada la
## ejecuta su controlador antes, con can_kick).
func _try_header() -> bool:
	var h := ball.state.pos.y
	if h < HEADER_MIN_HEIGHT:
		return false
	var best: Footballer = null
	var best_d := INF
	for p in all_players():
		if not in_header_reach(p) or not _wants_header(p, h):
			continue
		# Duelo aéreo: gana el que llega, y entre parejos el más alto.
		var d := p.flat_pos().distance_to(ball.flat_pos()) - ((p.data.body_height() if p.data else 1.0) - 1.0) * 6.0
		if d < best_d:
			best = p
			best_d = d
	if best == null:
		return false
	var kind := KickActions.Kind.SHORT_PASS
	var dir := best.facing
	var goal := best.team.target_goal()
	if not best.is_human() and best.flat_pos().distance_to(goal) < 18.0 and best.team.progress_of(best.flat_pos()) > 0.75:
		kind = KickActions.Kind.SHOT
		dir = Vector3.ZERO
	elif not best.is_human() and best.team.progress_of(best.flat_pos()) < 0.35:
		# Despeje: lejos del arco propio, hacia arriba de la cancha.
		kind = KickActions.Kind.CLEAR
		dir = Vector3(best.team.attack_dir, 0.0, signf(best.flat_pos().z) * 0.6).normalized()
	elif not best.is_human():
		dir = Vector3(best.team.attack_dir, 0.0, 0.0)
	_header_by(best, kind, dir)
	return true


## Si este jugador va a cabecear una pelota a esa altura (en vez de dejarla
## pasar o de bajarla con el pecho).
func _wants_header(p: Footballer, h: float) -> bool:
	# El arquero en su área la agarra con las manos.
	if p.is_keeper() and Pitch.in_penalty_area(p.flat_pos(), p.team.own_side()):
		return false
	# El humano cabecea cuando lo pide (orden guardada, ver HumanController).
	if p.is_human():
		return false
	# Atacante de la CPU cerca del arco: la cabecea aunque la pudiera bajar.
	if not p.is_human() and p.team.progress_of(p.flat_pos()) > 0.75 and p.flat_pos().distance_to(p.team.target_goal()) < 18.0:
		return true
	# El destinatario de un pase la deja bajar y la controla, y sus
	# compañeros no se la "roban" de cabeza.
	var recv := ball.intended_receiver
	if recv != null and recv.team == p.team:
		return false
	return h > control_height_for(p)


func _header_by(p: Footballer, kind: int, dir: Vector3) -> void:
	perform_kick(p, kind, dir, 0.55)
	p.touch_block = maxf(p.touch_block, 0.3)


## Pase atrás: la pelota la jugó a propósito (con el pie o de lateral) un
## compañero del arquero y nadie más la tocó. El arquero no puede usar las
## manos: la controla con los pies y se juega como un jugador más.
func is_back_pass_to(keeper: Footballer) -> bool:
	var passer: Footballer = last_kick.get("player")
	if passer == null or passer == keeper or passer.team != keeper.team:
		return false
	if last_kick.get("kind") == KickActions.Kind.SHOT:
		return false
	return ball.last_toucher == passer


func _try_steal(dt: float) -> void:
	var carrier := ball.owner_player
	if ball.in_hands:
		return # el arquero con la pelota en las manos no se roba
	var bp := ball.flat_pos()
	for o in opponents_of(carrier.team).players:
		if not o.can_touch_ball():
			continue
		var d := o.flat_pos().distance_to(bp)
		if o.state == Footballer.State.SLIDING and d < tuning.slide_reach:
			if randf() < foul_chance(o, carrier, true):
				call_foul(o, carrier, true)
				return
			ball.kick(o.facing * 7.0 + Vector3.UP * 0.5, Vector3.ZERO, o)
			carrier.touch_block = tuning.lost_ball_cooldown
			# La barrida se lleva puesto al que conducía (como en WE).
			if randf() < tuning.slide_trip_chance:
				carrier.trip(tuning.trip_duration)
			return
		if o.is_keeper() and o.state == Footballer.State.NORMAL and d < tuning.keeper_smother_radius \
				and Pitch.in_penalty_area(o.flat_pos(), o.team.own_side()):
			# El arquero se tira a los pies del atacante.
			var smother := tuning.keeper_smother_rate * (1.6 if o.data != null and o.data.has_ability("atajador") else 1.0)
			if randf() < smother * dt:
				carrier.touch_block = tuning.lost_ball_cooldown
				if o.visual != null:
					o.visual.play(PlayerVisual.Event.BLOCK)
				ball.give_to(o, false, true)
				stats["saves"][o.team.index] += 1
				return
			continue
		if o.state != Footballer.State.NORMAL or ball.state.pos.y > tuning.control_height:
			continue
		# Entrada pedida por su controlador (humano: presión encima del
		# portador; IA: cuando llega a distancia).
		if o.wants_tackle and o.tackle_cooldown <= 0.0 and d < tuning.tackle_range:
			if _resolve_tackle(o, carrier):
				return
			continue
		# Pelota expuesta (lejos del pie, p. ej. en sprint): quien se cruza bien
		# ubicado se la puede quedar sin hacer nada más.
		if d < tuning.control_radius and Dribble.is_exposed(ball.state.pos, carrier.global_position, carrier.facing):
			var edge := _duel_edge(o, carrier)
			if randf() < tuning.intercept_rate * (1.0 + 0.3 * edge) * dt:
				carrier.touch_block = tuning.lost_ball_cooldown
				ball.give_to(o, true)
				return


## Ventaja del defensor en un duelo (-2..2): defensa contra control.
func _duel_edge(defender: Footballer, carrier: Footballer) -> float:
	if defender.data == null or carrier.data == null:
		return 0.0
	return PlayerData.centered(defender.data.defense) - PlayerData.centered(carrier.data.ball_control)


## Probabilidad de éxito de una entrada (pura salvo por los datos de los
## jugadores): de frente es mucho más fácil que de atrás; la pelota expuesta
## ayuda y el conductor que la cubre quieto la protege.
func tackle_chance(defender: Footballer, carrier: Footballer) -> float:
	var to_def := (defender.flat_pos() - carrier.flat_pos()).normalized()
	var front := carrier.facing.dot(to_def)
	var base := tuning.tackle_side
	if front > 0.35:
		base = tuning.tackle_front
	elif front < -0.35:
		base = tuning.tackle_back
	var chance := base + 0.2 * _duel_edge(defender, carrier)
	if Dribble.is_exposed(ball.state.pos, carrier.global_position, carrier.facing):
		chance += 0.15
	var carrier_speed := Vector3(carrier.velocity.x, 0.0, carrier.velocity.z).length()
	if carrier_speed < Dribble.SHIELD_SPEED * 2.0 and carrier.dribble_pressure > 0.6:
		chance -= 0.12
	# Habilidades: el gambeteador la cuida, el marcador entra mejor.
	if carrier.data != null and carrier.data.has_ability("gambeteador"):
		chance -= 0.1
	if defender.data != null and defender.data.has_ability("marcador"):
		chance += 0.08
	# En plena marsellesa la pelota queda protegida por el cuerpo que gira.
	if carrier.skill == Footballer.Skill.ROULETTE:
		chance *= 0.35
	return clampf(chance, 0.05, 0.92)


## Resuelve una entrada. Si sale bien, el defensor se queda con la pelota; si
## no, queda desbalanceado un instante. Devuelve true si robó.
func _resolve_tackle(defender: Footballer, carrier: Footballer) -> bool:
	defender.tackle_cooldown = tuning.tackle_cooldown
	if defender.visual != null:
		defender.visual.play(PlayerVisual.Event.TACKLE)
	stats["tackles"][defender.team.index] += 1
	if randf() < tackle_chance(defender, carrier):
		carrier.touch_block = tuning.lost_ball_cooldown
		ball.give_to(defender, true)
		stats["tackles_won"][defender.team.index] += 1
		return true
	defender.stagger(tuning.tackle_fail_stagger)
	if randf() < foul_chance(defender, carrier, false):
		call_foul(defender, carrier, false)
		return true
	return false


# --- Cuerpo a cuerpo y lesiones ------------------------------------------------

## Choque de hombros: distancia, chance por segundo corriendo a la par, pausa
## entre choques y cuánto trastabilla el que pierde.
const CONTACT_DIST := 1.1
const CONTACT_RATE := 2.2
const CONTACT_COOLDOWN := 1.2
const CONTACT_STAGGER := 0.4
## Chance de lesión del que recibe la falta: barrida de atrás, barrida, otra.
const INJURY_CHANCE := [0.15, 0.07, 0.02]
## De las lesiones, cuántas no le dejan seguir bien.
const INJURY_SERIOUS := 0.35


## Probabilidad de que el que lleva la pelota pierda el choque de hombros:
## fuerza, equilibrio y físico de cada uno (el flaquito trastabilla).
func contact_loss_chance(defender: Footballer, carrier: Footballer) -> float:
	var dp := defender.data.body_power() if defender.data else 0.0
	var cp := carrier.data.body_power() if carrier.data else 0.0
	var chance := 0.42 + 0.3 * (dp - cp)
	if carrier.data != null and carrier.data.has_ability("gambeteador"):
		chance -= 0.08
	return clampf(chance, 0.08, 0.85)


## Corriendo a la par, el defensor y el que lleva la pelota chocan: el que
## pierde trastabilla (si es el que la lleva, la pelota queda suelta).
func _body_contact(dt: float) -> void:
	var carrier := ball.owner_player
	if carrier == null or ball.in_hands or carrier.state != Footballer.State.NORMAL or carrier.contact_cooldown > 0.0:
		return
	var cv := Vector3(carrier.velocity.x, 0.0, carrier.velocity.z)
	if cv.length() < 2.5:
		return
	for o in opponents_of(carrier.team).players:
		if o.is_keeper() or o.state != Footballer.State.NORMAL or o.contact_cooldown > 0.0:
			continue
		if o.flat_pos().distance_to(carrier.flat_pos()) > CONTACT_DIST:
			continue
		var ov := Vector3(o.velocity.x, 0.0, o.velocity.z)
		# Corriendo a la par o en diagonal (de frente es una entrada, no un choque).
		if ov.length() < 1.5 or ov.normalized().dot(cv.normalized()) < 0.0:
			continue
		if randf() > CONTACT_RATE * dt:
			continue
		resolve_contact(o, carrier, randf() < contact_loss_chance(o, carrier))
		return


## Resultado de un choque (separado para los tests).
func resolve_contact(defender: Footballer, carrier: Footballer, carrier_loses: bool) -> void:
	defender.contact_cooldown = CONTACT_COOLDOWN
	carrier.contact_cooldown = CONTACT_COOLDOWN
	stats["contacts"][defender.team.index] += 1
	var loser := carrier if carrier_loses else defender
	var steady := PlayerData.unit(loser.data.balance) if loser.data else 0.5
	loser.stagger(CONTACT_STAGGER * (1.3 - 0.6 * steady))
	if carrier_loses and ball.owner_player == carrier:
		ball.owner_player = null
		carrier.touch_block = tuning.lost_ball_cooldown


## Al que le hacen la falta se puede lesionar: un golpe (juega rengo) o algo
## peor (tiene que salir; la CPU lo cambia, al humano se le avisa).
func _maybe_injure(victim: Footballer, slide: bool, from_behind: bool) -> void:
	var chance: float = INJURY_CHANCE[0 if slide and from_behind else (1 if slide else 2)]
	if randf() >= chance:
		return
	injure(victim, Footballer.Injury.SERIOUS if randf() < INJURY_SERIOUS else Footballer.Injury.KNOCK)


func injure(p: Footballer, level: int) -> void:
	p.injury = maxi(p.injury, level)
	stats["injuries"][p.team.index] += 1
	var t := p.team
	if level == Footballer.Injury.SERIOUS:
		show_toast("LESIONADO: %s%s" % [p.display_name, "" if not _has_human(t) else "  (cambialo desde la pausa)"], 3.0)
		if not _has_human(t) and t.subs_left() > 0:
			var pick: PlayerData = null
			for d in t.bench:
				var gk := d.position == PlayerData.Position.GK
				if gk != p.is_keeper():
					continue
				if pick == null or (d.position == p.base_data.position and pick.position != p.base_data.position):
					pick = d
			if pick != null:
				t.pending_subs.append({"out": p, "in": pick})
	else:
		show_toast("%s quedó rengo" % p.display_name, 2.0)


## Separación suave entre jugadores (sin física de cuerpos, decisión B).
func _separate_players() -> void:
	var list := all_players()
	for i in list.size():
		for j in range(i + 1, list.size()):
			var a := list[i]
			var b := list[j]
			var d := b.global_position - a.global_position
			d.y = 0.0
			var dist := d.length()
			if dist >= PLAYER_SEPARATION or dist < 0.0001:
				continue
			var push := d / dist * (PLAYER_SEPARATION - dist)
			# Ejecutores quietos y arqueros no se dejan empujar: se corre el otro.
			var a_fixed := a.locked or a.is_keeper()
			var b_fixed := b.locked or b.is_keeper()
			if a_fixed and b_fixed:
				continue
			if a_fixed:
				b.global_position += push
			elif b_fixed:
				a.global_position -= push
			else:
				# El más pesado y fuerte corre al otro.
				var ma := a.data.mass() if a.data else 1.0
				var mb := b.data.mass() if b.data else 1.0
				var share := mb / (ma + mb)
				a.global_position -= push * share
				b.global_position += push * (1.0 - share)
	for p in list:
		_clamp_player(p)


## Límites de movimiento: nadie se va lejos de la cancha y el arquero nunca
## queda detrás de su propia línea.
func _clamp_player(p: Footballer) -> void:
	var pos := p.global_position
	var lim_x := Pitch.HALF_LENGTH + 3.0
	pos.z = clampf(pos.z, -Pitch.HALF_WIDTH - 3.0, Pitch.HALF_WIDTH + 3.0)
	if p.is_keeper():
		var own := p.team.own_side()
		if pos.x * own > Pitch.HALF_LENGTH - 0.4:
			pos.x = own * (Pitch.HALF_LENGTH - 0.4)
	pos.x = clampf(pos.x, -lim_x, lim_x)
	p.global_position = pos


# --- Reglas y pelotas paradas -------------------------------------------------

func _check_rules() -> void:
	var outcome := MatchRules.check(ball.state.pos, tuning.ball_radius, ball.last_touch_team, attack_dirs())
	if outcome.type == MatchRules.Restart.NONE:
		return
	_pending = outcome
	# Con el juego detenido nadie conserva la pelota en el pie.
	ball.owner_player = null
	ball.intended_receiver = null
	if outcome.type == MatchRules.Restart.GOAL:
		goal_scorer = ball.last_toucher
		_show_goal(outcome.team)
		teams[outcome.team].score += 1
		banner_text = "¡GOL!"
		_phase_timer = GOAL_DELAY
		_set_phase(Phase.GOAL)
		goal_scored.emit(outcome.team)
		return
	# Un remate que se va cerca: "uhh" del público.
	if outcome.type in [MatchRules.Restart.GOAL_KICK, MatchRules.Restart.CORNER] \
			and last_kick.get("kind") == KickActions.Kind.SHOT and absf(ball.state.pos.z) < 8.0:
		audio.cheer("ooh")
	var names := {
		MatchRules.Restart.GOAL_KICK: "SAQUE DE ARCO",
		MatchRules.Restart.CORNER: "CÓRNER",
		MatchRules.Restart.THROW_IN: "LATERAL",
		MatchRules.Restart.FREE_KICK: "TIRO LIBRE",
		MatchRules.Restart.PENALTY: "PENAL",
	}
	banner_text = names.get(outcome.type, "")
	_phase_timer = STOP_DELAY
	_set_phase(Phase.STOPPED)


## Festejo del goleador y lamento del arquero (sólo presentación).
func _show_goal(scoring_team: int) -> void:
	# El público salta unos segundos.
	if StadiumBuilder.crowd_material != null:
		StadiumBuilder.crowd_material.set_shader_parameter("cheer", 1.0)
		var tw := create_tween()
		tw.tween_interval(GOAL_DELAY)
		tw.tween_method(func(v: float) -> void: StadiumBuilder.crowd_material.set_shader_parameter("cheer", v), 1.0, 0.0, 1.5)
	var scorer := ball.last_toucher
	if scorer != null and scorer.team.index == scoring_team:
		scorer.celebrate(GOAL_DELAY)
	var keeper := teams[1 - scoring_team].keeper()
	if keeper != null and keeper.visual != null:
		keeper.visual.play(PlayerVisual.Event.DEJECTED)


## Terminó la repetición: vuelve la cámara del partido y se saca del medio.
func _on_replay_finished() -> void:
	if _camera != null:
		_camera.end_cinematic()
	if phase == Phase.REPLAY:
		_setup_kickoff(1 - _pending.team)


func camera() -> MatchCamera:
	return _camera


func _end_half() -> void:
	if clock.half == 1:
		banner_text = "ENTRETIEMPO"
		_phase_timer = HALFTIME_DELAY
		_set_phase(Phase.HALFTIME)
	else:
		banner_text = "FINAL"
		_set_phase(Phase.FULLTIME)
	ball.frozen = true


func _begin_restart(type: int, taker: Footballer) -> void:
	# La repetición empieza en la jugada (no antes de la pelota parada).
	replay.clear()
	restart_type = type
	restart_taker = taker
	_restart_elapsed = 0.0
	ball.intended_receiver = null
	for p in all_players():
		p.locked = false
		p.clear_pass_target()
		p.touch_block = 0.0
	taker.locked = true
	ball.give_to(taker)
	ball.frozen = true
	_goal_kick_order = []
	goal_kick_stage = GoalKickStage.READY
	if type == MatchRules.Restart.GOAL_KICK:
		# El arquero se mueve solo (toma carrera); la pelota queda en la línea.
		taker.locked = false
		goal_kick_stage = GoalKickStage.BACKING
	_set_phase(Phase.RESTART)


func _setup_kickoff(kicking_team: int) -> void:
	_make_pending_subs()
	for t in teams:
		for p in t.players:
			var spot := Formation.kickoff_spot(p.base_spot, t.index == kicking_team)
			p.teleport(t.to_world(spot), Vector3(t.attack_dir, 0.0, 0.0))
	var kt := teams[kicking_team]
	# Los dos de arriba (con expulsados, los dos últimos que quedan).
	var taker := kt.players[mini(9, kt.players.size() - 2)]
	var partner := kt.players[mini(10, kt.players.size() - 1)]
	taker.teleport(Vector3(-kt.attack_dir * 0.5, 0.0, 0.0), Vector3(kt.attack_dir, 0.0, 0.0))
	partner.teleport(Vector3(-kt.attack_dir * 0.8, 0.0, 2.5), Vector3(kt.attack_dir, 0.0, 0.0))
	ball.place(Vector3(0.0, tuning.ball_radius, 0.0))
	banner_text = "SAQUE DEL MEDIO" if clock.half == 1 and teams[0].score + teams[1].score == 0 else ""
	_begin_restart(MatchRules.Restart.KICKOFF, taker)


func _setup_restart(outcome: MatchRules.Outcome) -> void:
	_make_pending_subs()
	var team := teams[outcome.team]
	var spot := outcome.spot
	var taker: Footballer
	var stand: Vector3
	var look: Vector3
	match outcome.type:
		MatchRules.Restart.GOAL_KICK:
			taker = team.keeper()
			stand = spot - Vector3(team.attack_dir * 0.6, 0.0, 0.0)
			look = Vector3(team.attack_dir, 0.0, 0.0)
		MatchRules.Restart.CORNER:
			taker = team.on_pitch(team.ck_taker)
			if taker == null or taker.is_keeper():
				taker = _nearest_outfield(team, spot)
			var out := Vector3(signf(spot.x), 0.0, signf(spot.z)).normalized()
			stand = spot + out * 0.6
			look = (team.target_goal() - spot).normalized()
		MatchRules.Restart.FREE_KICK:
			# El pateador elegido, si es para pegarle al arco; si no, el más cerca.
			taker = team.on_pitch(team.fk_taker) if spot.distance_to(team.target_goal()) < FK_TAKER_RANGE else null
			if taker == null or taker.is_keeper():
				taker = _nearest_outfield(team, spot)
			look = (team.target_goal() - spot).normalized()
			stand = spot - look * 0.7
		MatchRules.Restart.PENALTY:
			taker = team.on_pitch(team.pk_taker)
			if taker == null:
				taker = _best_shooter(team)
			look = (team.target_goal() - spot).normalized()
			stand = spot - look * 1.3
		_:
			taker = _nearest_outfield(team, spot)
			stand = spot + Vector3(0.0, 0.0, signf(spot.z) * 0.5)
			look = Vector3(0.0, 0.0, -signf(spot.z))
	ball.place(spot)
	taker.teleport(stand, look)
	wall_targets = {}
	if outcome.type == MatchRules.Restart.FREE_KICK:
		_build_wall(opponents_of(team), spot)
	_begin_restart(outcome.type, taker)


## Dónde arranca la carrera del saque de arco: atrás de la pelota y un poco
## abierto hacia el centro (entra en diagonal, como los arqueros).
func goal_kick_runup_spot() -> Vector3:
	var spot := ball.flat_pos()
	var fwd := Vector3(restart_taker.team.attack_dir, 0.0, 0.0)
	return spot - fwd * GOAL_KICK_RUNUP + Vector3(0.0, 0.0, -signf(spot.z) * 1.8)


## Mueve al arquero en el saque de arco: retrocede, espera y, con la orden
## dada, corre a la pelota y patea al llegar.
func _drive_goal_kick() -> void:
	var k := restart_taker
	var spot := ball.flat_pos()
	var runup := goal_kick_runup_spot()
	k.wants_sprint = false
	match goal_kick_stage:
		GoalKickStage.BACKING:
			var d := runup - k.flat_pos()
			if d.length() < 0.3:
				goal_kick_stage = GoalKickStage.READY
				k.desired_move = Vector3.ZERO
			else:
				k.speed_override = GOAL_KICK_WALK
				k.desired_move = d.normalized()
		GoalKickStage.READY:
			k.desired_move = Vector3.ZERO
			k.speed_override = 0.0
			k.facing = (spot - k.flat_pos()).normalized()
		GoalKickStage.RUNNING:
			var approach := (spot - runup).normalized()
			var contact := spot - approach * 0.55
			var d2 := contact - k.flat_pos()
			if d2.length() < 0.35:
				var o := _goal_kick_order
				_goal_kick_kicking = true
				k.desired_move = Vector3.ZERO
				k.speed_override = 0.0
				perform_kick(k, o[0], o[1], o[2], o[3], o[4])
				_goal_kick_kicking = false
				_goal_kick_order = []
				goal_kick_stage = GoalKickStage.READY
			else:
				k.speed_override = GOAL_KICK_RUN
				k.desired_move = d2.normalized()


## Barrera: en un tiro libre cerca del arco, 2-4 defensores a 9,15 m de la
## pelota, en la línea hacia el centro del arco.
func _build_wall(defenders: Team, spot: Vector3) -> void:
	var goal := defenders.own_goal()
	var dist := spot.distance_to(goal)
	if dist > 32.0:
		return
	var count := 4 if dist < 22.0 else (3 if dist < 27.0 else 2)
	var dir := (goal - spot).normalized()
	var side := Vector3(-dir.z, 0.0, dir.x)
	var center := spot + dir * Pitch.CENTER_CIRCLE_RADIUS
	var used: Array[Footballer] = []
	for i in count:
		var pos := center + side * (i - (count - 1) * 0.5) * 0.65
		var best: Footballer = null
		var best_d := INF
		for p in defenders.players:
			if p.is_keeper() or p in used:
				continue
			var d := p.flat_pos().distance_to(pos)
			if d < best_d:
				best_d = d
				best = p
		if best == null:
			return
		used.append(best)
		wall_targets[best] = pos
		best.teleport(pos, -dir)


## El mejor rematador del equipo (patea los penales).
func _best_shooter(team: Team) -> Footballer:
	var best: Footballer = null
	var best_v := -1
	for p in team.players:
		if p.is_keeper():
			continue
		var v: int = p.data.shooting if p.data else 50
		if v > best_v:
			best_v = v
			best = p
	return best


func _nearest_outfield(team: Team, pos: Vector3) -> Footballer:
	var best: Footballer = null
	var best_d := INF
	for p in team.players:
		if p.is_keeper():
			continue
		var d := p.flat_pos().distance_to(pos)
		if d < best_d:
			best_d = d
			best = p
	return best


## Durante una pelota parada los rivales quedan a 9,15 m de la pelota.
func _keep_distance_from_restart() -> void:
	if restart_taker == null:
		return
	var min_d := Pitch.CENTER_CIRCLE_RADIUS
	var bp := ball.flat_pos()
	for p in opponents_of(restart_taker.team).players:
		var d := p.flat_pos() - bp
		var dist := d.length()
		if dist < min_d:
			var dir := d / dist if dist > 0.01 else Vector3(-restart_taker.team.attack_dir, 0.0, 0.0)
			var target := Pitch.clamp_to_field(bp + dir * min_d, 0.5)
			p.global_position = Vector3(target.x, 0.0, target.z)
	# Penal: todos (salvo el que patea y el arquero) fuera del área.
	if restart_type == MatchRules.Restart.PENALTY:
		var defenders := opponents_of(restart_taker.team)
		var line := absf(Pitch.HALF_LENGTH - Pitch.PENALTY_AREA_DEPTH) - 1.0
		for p in all_players():
			if p == restart_taker or p == defenders.keeper():
				continue
			if Pitch.in_penalty_area(p.flat_pos(), defenders.own_side()):
				p.global_position.x = defenders.own_side() * line
	# Saque de arco: los rivales fuera del área.
	if restart_type == MatchRules.Restart.GOAL_KICK:
		var own := restart_taker.team
		var gline := absf(Pitch.HALF_LENGTH - Pitch.PENALTY_AREA_DEPTH) - 1.0
		for p in opponents_of(own).players:
			if Pitch.in_penalty_area(p.flat_pos(), own.own_side()):
				p.global_position.x = own.own_side() * gline
	# En el saque del medio, además, cada equipo en su campo.
	if restart_type == MatchRules.Restart.KICKOFF:
		for t in teams:
			for p in t.players:
				if p == restart_taker:
					continue
				if p.global_position.x * t.attack_dir > -0.3:
					p.global_position.x = -t.attack_dir * 0.3


## Volver al menú principal (desde el final o la pausa).
func _exit_tree() -> void:
	Engine.time_scale = 1.0


func exit_to_menu() -> void:
	# Partido de Liga / Copa: cuenta sólo si se jugó hasta el final.
	GameSettings.last_result = [teams[0].score, teams[1].score] if phase == Phase.FULLTIME else []
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
