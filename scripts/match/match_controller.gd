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

const TEAM_DATA := [
	{"name": "Deportivo Aurora", "short": "AUR", "color": Color(0.35, 0.65, 0.95), "secondary": Color(0.95, 0.95, 0.95), "keeper": Color(0.15, 0.15, 0.15)},
	{"name": "Atlético Halcones", "short": "HAL", "color": Color(0.85, 0.15, 0.15), "secondary": Color(0.08, 0.08, 0.08), "keeper": Color(0.2, 0.85, 0.35)},
]
const SURNAMES := [
	"Arrieta", "Benavídez", "Castañar", "Duarte", "Echeverri", "Ferrán", "Galdós", "Hidalgo",
	"Irigoyen", "Jáuregui", "Kessler", "Larrea", "Maidana", "Nazar", "Olmedo", "Pereyra",
	"Quiroga", "Rivadeo", "Salcedo", "Taborda", "Urquiza", "Valdano", "Werthein", "Zabala",
]

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
## Estadísticas simples del partido, por equipo.
var stats := {"shots": [0, 0], "saves": [0, 0]}
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
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.5, 0.85)
	sky_mat.sky_horizon_color = Color(0.7, 0.8, 0.9)
	sky_mat.ground_horizon_color = Color(0.35, 0.4, 0.35)
	sky.sky_material = sky_mat
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	add_child(PitchBuilder.build())

	ball = Ball.new()
	ball.name = "Ball"
	add_child(ball)
	ball.setup(tuning)
	kicks = KickActions.new(ball, tuning)

	for i in 2:
		var d: Dictionary = TEAM_DATA[i]
		var team := Team.new(i, d["name"], d["short"], d["color"], d["secondary"], d["keeper"])
		team.attack_dir = 1 if i == 0 else -1
		teams.append(team)
		var names := SURNAMES.duplicate()
		names.shuffle()
		for n in Formation.SPOTS_442.size():
			var p := Footballer.new()
			add_child(p)
			p.setup(team, n + 1, Formation.ROLES_442[n], Formation.SPOTS_442[n], names[n], tuning)
			team.players.append(p)

	_camera = MatchCamera.new()
	add_child(_camera)
	_camera.setup(self)
	_camera.current = true

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


func _update_phase(dt: float) -> void:
	_phase_timer -= dt
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
	elif ball.owner_player != player:
		var near := ball.is_loose() and player.can_touch_ball() \
			and ball.flat_pos().distance_to(player.flat_pos()) < 1.5 and ball.state.pos.y < 1.8
		if not near:
			return null
	var receiver := kicks.execute(kind, player, dir, clampf(power, 0.0, 1.0))
	kicks.throw_in_mode = false
	kick_count += 1
	if kind == KickActions.Kind.SHOT:
		stats["shots"][player.team.index] += 1
	last_kick = {"kind": kind, "team": player.team.index, "pos": player.flat_pos(), "keeper": player.is_keeper()}
	return receiver


# --- Posesión -----------------------------------------------------------------

func _update_possession(dt: float) -> void:
	if ball.owner_player == null:
		_try_take_loose_ball()
	else:
		_try_steal(dt)


func _try_take_loose_ball() -> void:
	var bp := ball.flat_pos()
	var h := ball.state.pos.y
	var best: Footballer = null
	var best_d := INF
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
		var hmax := tuning.control_height
		if p.is_keeper() and Pitch.in_penalty_area(bp, p.team.own_side()):
			reach = tuning.keeper_reach if ball.speed() > 8.0 else 1.1
			hmax = tuning.keeper_catch_height
		if d < reach and h < hmax and d < best_d:
			best = p
			best_d = d
	if best == null:
		return
	var v := ball.state.vel
	if best.is_keeper() and Pitch.in_penalty_area(bp, best.team.own_side()):
		# Tiros fuertes y lejos del cuerpo: a veces da rebote en vez de atajar.
		if ball.speed() > 19.0 and best_d > 0.9 and randf() < 0.35:
			# Rebote hacia afuera (al costado del arco), no al medio del área.
			var wide := signf(bp.z) if absf(bp.z) > 0.3 else (1.0 if randf() < 0.5 else -1.0)
			var parry := Vector3(-v.x * 0.25, absf(v.y) * 0.3 + 3.0, wide * randf_range(5.0, 9.0))
			stats["saves"][best.team.index] += 1
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
	ball.give_to(best)


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
		if o.state != Footballer.State.NORMAL or d > tuning.steal_radius:
			continue
		var rate := tuning.steal_rate_pressing if o.pressing else tuning.steal_rate
		if carrier.is_sprinting():
			rate *= 1.3
		# Desde atrás es mucho más difícil sacarla limpia.
		if carrier.facing.dot((o.flat_pos() - carrier.flat_pos()).normalized()) < -0.2:
			rate *= 0.4
		if randf() < rate * dt:
			carrier.touch_block = tuning.lost_ball_cooldown
			if randf() < 0.55:
				ball.give_to(o)
			else:
				var away := (bp - carrier.flat_pos()).normalized() * 3.0 + o.facing * 3.0
				ball.kick(away, Vector3.ZERO, o)
			return


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
