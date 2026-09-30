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

var tuning: Tuning
var ball: Ball
var teams: Array[Team] = []
var clock: MatchClock
var kicks: KickActions
var humans: Array[HumanController] = []
var ais: Array[SimpleAI] = []

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
## Mensaje grande para el HUD ("¡GOL!", "CÓRNER", ...).
var banner_text: String = ""

var _phase_timer: float = 0.0
var _restart_elapsed: float = 0.0
var _pending: MatchRules.Outcome = null
var _first_half_kicker: int = 0
var _camera: MatchCamera
var _hud: MatchHud


func _ready() -> void:
	tuning = GameSettings.tuning
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


## La IA ejecutora puede sacar.
func restart_ready() -> bool:
	return phase == Phase.RESTART and _restart_elapsed >= RESTART_AI_DELAY


func attack_dirs() -> Array[int]:
	var dirs: Array[int] = [teams[0].attack_dir, teams[1].attack_dir]
	return dirs


# --- Construcción -------------------------------------------------------------

func _build_world() -> void:
	_build_lighting()
	add_child(PitchBuilder.build())
	stadium = StadiumBuilder.build(GameSettings.home_team())
	add_child(stadium)

	ball = Ball.new()
	ball.name = "Ball"
	add_child(ball)
	ball.setup(tuning)
	kicks = KickActions.new(ball, tuning)

	var datas: Array[TeamData] = [GameSettings.home_team(), GameSettings.away_team()]
	for i in 2:
		var d := datas[i]
		var team := Team.new(i, d.team_name, d.short_name, d.color, d.secondary_color, d.keeper_color)
		team.data = d
		team.attack_dir = 1 if i == 0 else -1
		teams.append(team)
		var formation := d.formation
		var starters := d.starters()
		for n in starters.size():
			var p := Footballer.new()
			add_child(p)
			p.setup(team, starters[n], formation.roles[n], formation.slots[n], tuning)
			team.players.append(p)

	_camera = MatchCamera.new()
	add_child(_camera)
	_camera.setup(self)
	_camera.current = true
	_camera.mode_changed.connect(func(n: String) -> void: show_toast("Cámara: %s" % n))

	var pause := PauseMenu.new()
	add_child(pause)


## Iluminación de tarde: sol bajo desde atrás de la tribuna principal (sombras
## largas sobre el césped), cielo, ambiente moderado y tonemapping fílmico.
func _build_lighting() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.5, 0.78)
	sky_mat.sky_horizon_color = Color(0.75, 0.8, 0.85)
	sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.2)
	sky_mat.ground_horizon_color = Color(0.5, 0.52, 0.5)
	sky.sky_material = sky_mat
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 0.95
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	# Luz desde atrás de la tribuna principal (-Z), baja y algo lateral.
	sun.rotation_degrees = Vector3(-38.0, 160.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)


func _setup_controllers() -> void:
	match GameSettings.mode:
		GameSettings.Mode.VS_CPU:
			humans.append(HumanController.new(0, teams[0], self))
		GameSettings.Mode.TWO_PLAYERS:
			humans.append(HumanController.new(0, teams[0], self))
			humans.append(HumanController.new(1, teams[1], self))
	for t in teams:
		ais.append(SimpleAI.new(t, self))


# --- Bucle principal ----------------------------------------------------------

func _physics_process(dt: float) -> void:
	_update_phase(dt)
	_update_forecast()

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
func perform_kick(player: Footballer, kind: int, dir: Vector3, power: float) -> Footballer:
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
	var receiver := kicks.execute(kind, player, dir, clampf(power, 0.0, 1.0))
	kicks.throw_in_mode = false
	kick_count += 1
	save_plan = {}
	if kind == KickActions.Kind.SHOT:
		stats["shots"][player.team.index] += 1
		_plan_save(player)
	last_kick = {"kind": kind, "team": player.team.index, "pos": player.flat_pos(), "keeper": player.is_keeper()}
	return receiver


## Primer punto de la trayectoria predicha de la pelota suelta al que `p`
## llega a tiempo corriendo en sprint (compartido por IA y humanos).
func loose_ball_intercept(p: Footballer) -> Vector3:
	var speed := tuning.sprint_speed
	for i in ball_forecast.size():
		var t := (i + 1) * FORECAST_STEP
		var bp := ball_forecast[i]
		if bp.y > 2.2:
			continue
		var flat := Vector3(bp.x, 0.0, bp.z)
		if p.flat_pos().distance_to(flat) <= speed * t + 0.6:
			return flat
	if ball_forecast.is_empty():
		return ball.flat_pos()
	var last := ball_forecast[ball_forecast.size() - 1]
	return Vector3(last.x, 0.0, last.z)


## Decide al momento del remate si el arquero rival llega (SaveModel).
func _plan_save(shooter: Footballer) -> void:
	var defenders := opponents_of(shooter.team)
	var gk := defenders.keeper()
	if gk == null:
		return
	var goal_x := defenders.own_side() * Pitch.HALF_LENGTH
	var plan := SaveModel.predict_crossing(ball.state, goal_x, tuning)
	if not plan.on_target:
		return
	var reaction := gk.data.reaction if gk.data else 60
	var gk_skill := gk.data.goalkeeping if gk.data else 60
	SaveModel.evaluate(plan, gk.flat_pos(), reaction, gk_skill)
	var will_save := randf() < plan.chance
	# Embolsa si le llega cómoda y no tan fuerte; si no, da rebote.
	var parry := ball.speed() > 20.0 or plan.margin < 0.5
	save_plan = {"keeper": gk, "will_save": will_save, "parry": parry, "point": plan.point,
		"time_left": plan.time + 0.3, "chance": plan.chance}


## El jugador tiene la pelota al alcance del pie para patearla ahora.
func can_kick(player: Footballer) -> bool:
	if ball.owner_player == player and ball.state.pos.y > 0.5:
		return player.is_keeper() # en las manos del arquero
	if ball.owner_player != null and ball.owner_player != player:
		return false
	if ball.owner_player == null and not player.can_touch_ball():
		return false
	return ball.flat_pos().distance_to(player.flat_pos()) < KICK_REACH and ball.state.pos.y < 1.8


# --- Posesión -----------------------------------------------------------------

func _update_possession(dt: float) -> void:
	if ball.owner_player == null:
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
	for p in all_players():
		if not p.can_touch_ball():
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
		var hmax := tuning.control_height
		if p.is_keeper() and Pitch.in_penalty_area(bp, p.team.own_side()):
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
	if best.is_keeper() and Pitch.in_penalty_area(bp, best.team.own_side()):
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
	ball.give_to(best, true)


func _try_steal(dt: float) -> void:
	var carrier := ball.owner_player
	if carrier.is_keeper() and Pitch.in_penalty_area(carrier.flat_pos(), carrier.team.own_side()):
		return # el arquero con la pelota en las manos no se roba
	var bp := ball.flat_pos()
	for o in opponents_of(carrier.team).players:
		if not o.can_touch_ball():
			continue
		var d := o.flat_pos().distance_to(bp)
		if o.state == Footballer.State.SLIDING and d < tuning.slide_reach:
			ball.kick(o.facing * 7.0 + Vector3.UP * 0.5, Vector3.ZERO, o)
			carrier.touch_block = tuning.lost_ball_cooldown
			return
		if o.is_keeper() and o.state == Footballer.State.NORMAL and d < tuning.keeper_smother_radius \
				and Pitch.in_penalty_area(o.flat_pos(), o.team.own_side()):
			# El arquero se tira a los pies del atacante.
			if randf() < tuning.keeper_smother_rate * dt:
				carrier.touch_block = tuning.lost_ball_cooldown
				ball.give_to(o)
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
	return clampf(chance, 0.05, 0.92)


## Resuelve una entrada. Si sale bien, el defensor se queda con la pelota; si
## no, queda desbalanceado un instante. Devuelve true si robó.
func _resolve_tackle(defender: Footballer, carrier: Footballer) -> bool:
	defender.tackle_cooldown = tuning.tackle_cooldown
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
