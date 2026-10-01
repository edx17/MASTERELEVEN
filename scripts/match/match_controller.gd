class_name MatchController
extends Node3D
## Raíz de la escena de partido. Arma el mundo, lleva la máquina de estados
## (saque del medio, juego, pelota parada, gol, entretiempo, final) y ejecuta
## la simulación en un orden fijo por cada tick de física:
##   humanos -> IA -> jugadores -> separación -> pelota -> posesión -> reglas -> reloj

signal goal_scored(team_index: int)
signal phase_changed(phase: int)

enum Phase { PLAYING, STOPPED, RESTART, GOAL, HALFTIME, FULLTIME }

const FORECAST_STEP := 0.1
const FORECAST_POINTS := 30
const STOP_DELAY := 1.1
const GOAL_DELAY := 3.0
const HALFTIME_DELAY := 3.0
const RESTART_AI_DELAY := 1.0
const RESTART_HUMAN_DELAY := 0.35
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
var stats := {"shots": [0, 0], "saves": [0, 0], "tackles": [0, 0], "tackles_won": [0, 0]}
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
## Pared en curso (L1 + X): {passer, receiver, run, time}. Vacío = ninguna.
var one_two := {}
## Mensaje grande para el HUD ("¡GOL!", "CÓRNER", ...).
var banner_text: String = ""

var _phase_timer: float = 0.0
var _restart_elapsed: float = 0.0
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
	return phase == Phase.RESTART and _restart_elapsed >= RESTART_AI_DELAY


func attack_dirs() -> Array[int]:
	var dirs: Array[int] = [teams[0].attack_dir, teams[1].attack_dir]
	return dirs


# --- Construcción -------------------------------------------------------------

func _build_world() -> void:
	# Luz, cielo y clima según las condiciones del partido.
	atmosphere = Atmosphere.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	atmosphere.setup(conditions)
	add_child(PitchBuilder.build(atmosphere.grass_params()))
	stadium = StadiumBuilder.build(GameSettings.home_team(), GameSettings.away_team())
	add_child(stadium)

	ball = Ball.new()
	ball.name = "Ball"
	add_child(ball)
	ball.setup(tuning)
	kicks = KickActions.new(ball, tuning)
	ball.kicked.connect(_on_ball_kicked)

	var datas: Array[TeamData] = [GameSettings.home_team(), GameSettings.away_team()]
	for i in 2:
		var d := datas[i]
		var team := Team.new(i, d.team_name, d.short_name, d.color, d.secondary_color, d.keeper_color)
		team.data = d
		team.formation = d.formation
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

	_camera = MatchCamera.new()
	add_child(_camera)
	_camera.setup(self)
	_camera.current = true
	_camera.mode_changed.connect(func(n: String) -> void: show_toast("Cámara: %s" % n))
	atmosphere.attach(_camera, self)
	show_toast(conditions.describe(), 4.0)

	var pause := PauseMenu.new()
	add_child(pause)


func _setup_controllers() -> void:
	match GameSettings.mode:
		GameSettings.Mode.VS_CPU:
			humans.append(HumanController.new(0, teams[0], self))
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

func _physics_process(dt: float) -> void:
	_update_phase(dt)
	_update_forecast()

	keeper_rush = [false, false]
	support_press = [false, false]
	_update_one_two(dt)
	for h in humans:
		h.tick(dt)
	for a in ais:
		a.tick(dt)
	for p in all_players():
		p.tick(dt, ball.owner_player == p)
	_separate_players()
	if phase == Phase.RESTART:
		_keep_distance_from_restart()

	ball.tick(dt)

	# Primero las reglas (una pelota que ya cruzó la línea no se puede atajar).
	if phase == Phase.PLAYING:
		_check_rules()
	if phase == Phase.PLAYING:
		_update_possession(dt)

	clock.running = phase in [Phase.PLAYING, Phase.STOPPED] or (phase == Phase.RESTART and restart_type != MatchRules.Restart.KICKOFF)
	clock.advance(dt)
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
				_setup_kickoff(1 - _pending.team)
		Phase.HALFTIME:
			if _phase_timer <= 0.0:
				for t in teams:
					t.attack_dir = -t.attack_dir
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
	if phase == Phase.RESTART:
		if player != restart_taker or _restart_elapsed < RESTART_HUMAN_DELAY:
			return null
		ball.frozen = false
		player.locked = false
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
	SaveModel.evaluate(plan, gk.flat_pos(), reaction, gk_skill, extra_reaction)
	var will_save := randf() < plan.chance
	# Embolsa si le llega cómoda y no tan fuerte; si no, da rebote.
	var parry := ball.speed() > 20.0 or plan.margin < 0.5
	save_plan = {"keeper": gk, "will_save": will_save, "parry": parry, "point": plan.point,
		"save_point": plan.save_point, "time_left": plan.time + 0.3, "chance": plan.chance}
	_show_dive(gk, plan.save_point)


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
	for n in mini(t.players.size(), formation.slots.size()):
		var p := t.players[n]
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
	if h < HEADER_MIN_HEIGHT or h > tuning.header_max_height or not p.can_touch_ball():
		return false
	if p.state != Footballer.State.NORMAL:
		return false
	return ball.flat_pos().distance_to(p.flat_pos()) < tuning.header_reach


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
		if p.is_keeper() and Pitch.in_penalty_area(bp, p.team.own_side()) and not is_back_pass_to(p):
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
	var hands := best.is_keeper() and Pitch.in_penalty_area(bp, best.team.own_side()) and not is_back_pass_to(best)
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
	elif Vector3(p.velocity.x, 0.0, p.velocity.z).length() < 3.5:
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
		var d := p.flat_pos().distance_to(ball.flat_pos())
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
			ball.kick(o.facing * 7.0 + Vector3.UP * 0.5, Vector3.ZERO, o)
			carrier.touch_block = tuning.lost_ball_cooldown
			# La barrida se lleva puesto al que conducía (como en WE).
			if randf() < tuning.slide_trip_chance:
				carrier.trip(tuning.trip_duration)
			return
		if o.is_keeper() and o.state == Footballer.State.NORMAL and d < tuning.keeper_smother_radius \
				and Pitch.in_penalty_area(o.flat_pos(), o.team.own_side()):
			# El arquero se tira a los pies del atacante.
			if randf() < tuning.keeper_smother_rate * dt:
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
	return false


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
				a.global_position -= push * 0.5
				b.global_position += push * 0.5
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
		_show_goal(outcome.team)
		teams[outcome.team].score += 1
		banner_text = "¡GOL!"
		_phase_timer = GOAL_DELAY
		_set_phase(Phase.GOAL)
		goal_scored.emit(outcome.team)
		return
	var names := {
		MatchRules.Restart.GOAL_KICK: "SAQUE DE ARCO",
		MatchRules.Restart.CORNER: "CÓRNER",
		MatchRules.Restart.THROW_IN: "LATERAL",
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
	_set_phase(Phase.RESTART)


func _setup_kickoff(kicking_team: int) -> void:
	for t in teams:
		for p in t.players:
			var spot := Formation.kickoff_spot(p.base_spot, t.index == kicking_team)
			p.teleport(t.to_world(spot), Vector3(t.attack_dir, 0.0, 0.0))
	var kt := teams[kicking_team]
	var taker := kt.players[9]
	var partner := kt.players[10]
	taker.teleport(Vector3(-kt.attack_dir * 0.5, 0.0, 0.0), Vector3(kt.attack_dir, 0.0, 0.0))
	partner.teleport(Vector3(-kt.attack_dir * 0.8, 0.0, 2.5), Vector3(kt.attack_dir, 0.0, 0.0))
	ball.place(Vector3(0.0, tuning.ball_radius, 0.0))
	banner_text = "SAQUE DEL MEDIO" if clock.half == 1 and teams[0].score + teams[1].score == 0 else ""
	_begin_restart(MatchRules.Restart.KICKOFF, taker)


func _setup_restart(outcome: MatchRules.Outcome) -> void:
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
			taker = _nearest_outfield(team, spot)
			var out := Vector3(signf(spot.x), 0.0, signf(spot.z)).normalized()
			stand = spot + out * 0.6
			look = (team.target_goal() - spot).normalized()
		_:
			taker = _nearest_outfield(team, spot)
			stand = spot + Vector3(0.0, 0.0, signf(spot.z) * 0.5)
			look = Vector3(0.0, 0.0, -signf(spot.z))
	ball.place(spot)
	taker.teleport(stand, look)
	_begin_restart(outcome.type, taker)


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
	# En el saque del medio, además, cada equipo en su campo.
	if restart_type == MatchRules.Restart.KICKOFF:
		for t in teams:
			for p in t.players:
				if p == restart_taker:
					continue
				if p.global_position.x * t.attack_dir > -0.3:
					p.global_position.x = -t.attack_dir * 0.3


## Volver al menú principal (desde el final o la pausa).
func exit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
