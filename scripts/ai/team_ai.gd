class_name TeamAI
extends RefCounted
## IA de equipo (Fase 3). Mueve al equipo como unidad:
## - Estado táctico (4 veces por segundo): DEFENSA, SALIDA, ATAQUE,
##   CONTRAATAQUE, PRESIÓN, REPLIEGUE, según posesión, zona de la pelota,
##   tiempo desde que cambió la posesión y cuántos rivales quedaron mal parados.
## - Forma del equipo (TeamShape) según ese estado: línea defensiva, compacidad,
##   ancho, laterales que pasan, delanteros en la última línea.
## - Roles del momento: con la pelota, apoyos (triángulos cerca del que la
##   tiene) y un desmarque en la última línea; sin la pelota, presión,
##   cobertura y marcas en zona; pelota suelta, el que llega primero.
## - Pelotas paradas (SetPieceShape) y arquero (GoalkeeperController).
## - Decisiones del que conduce: conducir, pasar (corto, largo, al hueco,
##   centro) o rematar, según el estado y lo que ve.
## Maneja a todos los jugadores del equipo que no controla un humano (también
## a los compañeros del humano, que así lo acompañan).

const S := TeamShape.State
const STATE_INTERVAL := 0.25
const CARRIER_INTERVAL := 0.2
const ARRIVE_RADIUS := 0.8
const SHOOT_DISTANCE := 26.0
const RUNNER_HOLD := 2.0

var team: Team
var difficulty: Difficulty
var state: int = S.DEFENDING
## Objetivos de forma por puesto (espacio de equipo), recalculados con el estado.
var shape: Array[Vector2] = []
## Etiqueta del rol actual de cada jugador (depuración).
var roles := {}
var keeper: GoalkeeperController

var _match: MatchController
var _time := 0.0
var _state_timer := 0.0
var _carrier_timer := 0.0
var _last_kick_seen := -1
var _possession_team := -1
var _possession_since := 0.0
var _pressers: Array[Footballer] = []
var _cover: Footballer = null
var _chaser: Footballer = null
var _markers := {}
var _supporters := {}
var _runner: Footballer = null
var _runner_target := Vector3.ZERO
var _runner_until := 0.0
var _set_piece_key := ""
var _set_piece_targets := {}


func _init(p_team: Team, p_match: MatchController, p_difficulty: Difficulty = null) -> void:
	team = p_team
	_match = p_match
	difficulty = p_difficulty if p_difficulty != null else Difficulty.make(Difficulty.Level.NORMAL)
	keeper = GoalkeeperController.new(team, _match)
	_update_shape()


func state_name() -> String:
	return TeamShape.STATE_NAMES[state]


# --- Bucle -----------------------------------------------------------------

func tick(dt: float) -> void:
	_time += dt
	var ball := _match.ball
	_track_possession(ball)
	_trigger_reactions(ball)
	_state_timer -= dt
	if _state_timer <= 0.0:
		_state_timer = STATE_INTERVAL
		_update_state(ball)
		_update_shape()
		_assign_roles(ball)
	_carrier_timer -= dt

	var owner := ball.owner_player
	# Cuadrado mantenido por el humano defendiendo: un compañero sale a presionar.
	var helper: Footballer = null
	if _match.support_press[team.index] and owner != null and owner.team != team:
		helper = _support_helper(owner)
	for p in team.players:
		if p.is_human():
			continue
		if p.reaction_timer > 0.0 and owner != p and _match.restart_taker != p:
			p.debug_state = "reacciona"
			continue # mantiene la orden anterior (tiempo de reacción)
		p.pressing = false
		if not p.is_keeper():
			p.speed_override = 0.0
		if _match.restart_taker == p:
			p.debug_state = "saque"
			_restart_taker(p)
			continue
		if _match.waiting_kickoff(p):
			# Esperando el saque del medio: quieto, mirando la pelota.
			p.debug_state = "espera el saque"
			p.desired_move = Vector3.ZERO
			p.wants_sprint = false
			p.look_at_point(ball.flat_pos())
			continue
		if p.is_keeper():
			keeper.tick(p, self, dt)
			continue
		if _rival_keeper_holds(ball):
			# Arquero rival con la pelota en las manos: nadie lo encima, todos
			# vuelven a su puesto (fuera del área) esperando la reposición.
			p.debug_state = "repliega"
			_retreat_from_keeper(p, ball)
			continue
		if p == helper:
			p.debug_state = "presiona (pedido)"
			_chase(p, ball, true)
			continue
		if owner == p:
			p.debug_state = "conduce"
			_carrier(p, ball)
			continue
		if _match.is_stopped():
			_stopped(p, ball)
			continue
		if p.has_pass_target() and ball.intended_receiver == p and ball.is_loose():
			p.debug_state = "recibe"
			_receive(p, ball)
			continue
		if p == _chaser:
			p.debug_state = "va a la pelota"
			_chase(p, ball, false)
			continue
		if p in _pressers:
			p.debug_state = "presiona"
			_chase(p, ball, true)
			continue
		if p == _cover and owner != null:
			p.debug_state = "cubre"
			go_to(p, owner.flat_pos() + (team.own_goal() - owner.flat_pos()).normalized() * 6.0, true)
			continue
		if _markers.has(p) and not _match.is_ghost_runner(_markers[p]):
			p.debug_state = "marca"
			_mark(p, _markers[p])
			continue
		if p == _runner:
			p.debug_state = "desmarque"
			go_to(p, _runner_target, true)
			continue
		if _supporters.has(p):
			p.debug_state = "apoyo"
			var sp: Vector3 = _supporters[p]
			go_to(p, sp, p.flat_pos().distance_to(sp) > 8.0, true)
			p.look_at_point(ball.flat_pos())
			continue
		p.debug_state = "posición"
		_hold_shape(p, ball)


# --- Posesión, reacción y estado --------------------------------------------

func _track_possession(ball: Ball) -> void:
	var owner := ball.owner_player
	if owner != null and owner.team.index != _possession_team:
		_possession_team = owner.team.index
		_possession_since = _time


## Tiempo de reacción ante cada patada (informe técnico: 0,15-0,25 s).
func _trigger_reactions(ball: Ball) -> void:
	if _match.kick_count == _last_kick_seen:
		return
	_last_kick_seen = _match.kick_count
	var t := _match.tuning
	for p in team.players:
		if not p.is_human() and not p.is_keeper() and ball.last_toucher != p:
			var r := PlayerData.unit(p.data.reaction) if p.data else 0.5
			p.reaction_timer = lerpf(t.ai_reaction_max, t.ai_reaction_min, r) * difficulty.reaction_mult


func _update_state(ball: Ball) -> void:
	var bx := team.progress_of(ball.flat_pos())
	var since := _time - _possession_since
	if _possession_team < 0:
		state = S.DEFENDING
		return
	if _possession_team == team.index:
		var just_won := since < 3.5
		var was_defending := state in [S.DEFENDING, S.PRESSING, S.RETREATING]
		if (was_defending or state == S.COUNTER_ATTACK) and just_won and bx > 0.25 and bx < 0.8 \
				and _opponents_goal_side(bx) <= 5:
			state = S.COUNTER_ATTACK
		elif bx < 0.33:
			state = S.BUILD_UP
		else:
			state = S.ATTACKING
	else:
		var lost_recently := since < 4.0
		if lost_recently and bx > 0.55:
			state = S.PRESSING # contrapresión donde se perdió
		elif difficulty.level == Difficulty.Level.HARD and bx > 0.66:
			state = S.PRESSING
		elif lost_recently and _own_players_ahead(bx) >= 5:
			state = S.RETREATING
		else:
			state = S.DEFENDING


## Rivales entre la pelota y su arco (los que "quedan para defender").
func _opponents_goal_side(bx: float) -> int:
	var n := 0
	for o in _match.opponents_of(team).players:
		if not o.is_keeper() and team.progress_of(o.flat_pos()) > bx:
			n += 1
	return n


## Propios que quedaron adelante de la pelota (mal parados al perderla).
func _own_players_ahead(bx: float) -> int:
	var n := 0
	for p in team.players:
		if not p.is_keeper() and team.progress_of(p.flat_pos()) > bx + 0.05:
			n += 1
	return n


func _update_shape() -> void:
	var f := team.formation if team.formation != null else FormationLibrary.build("4-4-2")
	var bp := _match.ball.flat_pos() if _match.ball != null else Vector3.ZERO
	shape = TeamShape.compute(f, state, Vector2(team.progress_of(bp), team.lateral_of(bp)))


## Objetivo de forma de un jugador (mundo).
func shape_target(p: Footballer) -> Vector3:
	var i := team.slot_of(p)
	if i < 0 or i >= shape.size():
		return p.flat_pos()
	return team.to_world(shape[i])


# --- Roles del momento -------------------------------------------------------

func _assign_roles(ball: Ball) -> void:
	_pressers.clear()
	_cover = null
	_chaser = null
	_markers.clear()
	_supporters.clear()
	roles.clear()
	if _match.is_stopped():
		_runner = null
		return
	var owner := ball.owner_player
	if owner != null and owner.team == team:
		_assign_support(owner)
		_assign_runner(owner, ball)
	elif owner != null:
		_runner = null
		_assign_defense(owner, ball)
	else:
		_chaser = _best_chaser(ball)
	for p in _pressers:
		roles[p] = "presión"
	if _cover != null:
		roles[_cover] = "cobertura"
	for p in _markers:
		roles[p] = "marca"
	for p in _supporters:
		roles[p] = "apoyo"
	if _runner != null:
		roles[_runner] = "desmarque"


func _field_players() -> Array[Footballer]:
	var out: Array[Footballer] = []
	for p in team.players:
		if not p.is_keeper() and not p.is_human() and p.state == Footballer.State.NORMAL:
			out.append(p)
	return out


## Apoyos: triángulos adelante a ambos lados y uno de seguridad atrás.
func _assign_support(carrier: Footballer) -> void:
	var cp := carrier.flat_pos()
	var fwd := Vector3(team.attack_dir, 0.0, 0.0)
	var points: Array[Vector3] = [
		cp + fwd.rotated(Vector3.UP, deg_to_rad(40.0)) * 13.0,
		cp + fwd.rotated(Vector3.UP, deg_to_rad(-40.0)) * 13.0,
	]
	if state == S.BUILD_UP or state == S.ATTACKING:
		points.append(cp - fwd * 9.0 + Vector3(0.0, 0.0, -signf(cp.z) * 5.0))
	var free := _field_players()
	free.erase(carrier)
	for pt in points:
		var target := _away_from_opponents(Pitch.clamp_to_field(pt, 2.0))
		var best: Footballer = null
		var best_d := 25.0
		for p in free:
			if p == _runner and _time < _runner_until:
				continue
			var d := p.flat_pos().distance_to(target)
			if d < best_d:
				best_d = d
				best = p
		if best != null:
			_supporters[best] = target
			free.erase(best)


## Desmarque: un delantero (o extremo/enganche) ataca el espacio en la última
## línea rival para recibir al hueco.
func _assign_runner(carrier: Footballer, ball: Ball) -> void:
	var bx := team.progress_of(ball.flat_pos())
	if bx < 0.3:
		_runner = null
		return
	if _runner != null and _time < _runner_until and not _supporters.has(_runner) and _runner != carrier:
		_runner_target = _runner_spot(_runner, bx)
		return
	_runner = null
	if randf() > difficulty.run_rate:
		return
	var best: Footballer = null
	var best_x := -1.0
	for p in _field_players():
		if p == carrier or _supporters.has(p):
			continue
		var k := p.tactical_role
		if not (TacticalRole.is_forward(k) or k == TacticalRole.Kind.AM or (state == S.COUNTER_ATTACK and k == TacticalRole.Kind.WM)):
			continue
		var x := team.progress_of(p.flat_pos())
		if x > best_x:
			best_x = x
			best = p
	if best != null:
		_runner = best
		_runner_until = _time + RUNNER_HOLD
		_runner_target = _runner_spot(best, bx)


func _runner_spot(p: Footballer, bx: float) -> Vector3:
	var last_line := _opponent_last_line()
	var x := clampf(last_line + 0.03, bx + 0.05, 0.93)
	var y := team.lateral_of(p.flat_pos()) * 0.7
	return team.to_world(Vector2(x, y))


## Última línea rival (el defensor más retrasado, en espacio de este equipo).
func _opponent_last_line() -> float:
	var best := 0.0
	for o in _match.opponents_of(team).players:
		if not o.is_keeper():
			best = maxf(best, team.progress_of(o.flat_pos()))
	return best


## Defensa: presión (1 o 2), cobertura y marcas en zona.
func _assign_defense(carrier: Footballer, ball: Ball) -> void:
	var n := difficulty.pressers if state == S.PRESSING else 1
	var candidates := _field_players()
	candidates.sort_custom(func(a: Footballer, b: Footballer) -> bool:
		return _time_to_ball(a, ball) < _time_to_ball(b, ball))
	var human_t := INF
	for p in team.players:
		if p.is_human():
			human_t = minf(human_t, _time_to_ball(p, ball))
	for p in candidates:
		if _pressers.size() >= n:
			break
		# Si el humano llega antes, la IA sólo acompaña la presión si está cerca.
		if human_t < _time_to_ball(p, ball) and p.flat_pos().distance_to(carrier.flat_pos()) > 10.0:
			continue
		_pressers.append(p)
	for p in candidates:
		if p in _pressers:
			continue
		if p.flat_pos().distance_to(carrier.flat_pos()) < 20.0:
			_cover = p
		break
	# Marcas: rivales en nuestra mitad, cada uno por el jugador libre más cercano
	# a su zona (los delanteros propios no marcan).
	var free: Array[Footballer] = []
	for p in candidates:
		if p in _pressers or p == _cover or TacticalRole.is_forward(p.tactical_role):
			continue
		free.append(p)
	for o in _match.opponents_of(team).players:
		if o.is_keeper() or o == carrier or free.is_empty():
			continue
		if team.progress_of(o.flat_pos()) > 0.55:
			continue
		var best: Footballer = null
		var best_d := 14.0
		for p in free:
			var d := shape_target(p).distance_to(o.flat_pos())
			if d < best_d:
				best_d = d
				best = p
		if best != null:
			_markers[best] = o
			free.erase(best)


func _best_chaser(ball: Ball) -> Footballer:
	var best: Footballer = null
	var best_t := INF
	var human_t := INF
	for p in team.players:
		if p.is_keeper() or p.state != Footballer.State.NORMAL:
			continue
		var t := _time_to_ball(p, ball)
		if p.is_human():
			human_t = minf(human_t, t)
		elif t < best_t:
			best_t = t
			best = p
	if best != null and human_t < best_t - 0.4:
		return null
	return best


func _time_to_ball(p: Footballer, ball: Ball) -> float:
	return p.flat_pos().distance_to(_intercept_point(p, ball)) / _match.tuning.sprint_speed


func _intercept_point(p: Footballer, ball: Ball) -> Vector3:
	if not ball.is_loose():
		# Contra un portador: cerrarle el paso del lado del arco propio.
		var carrier := ball.owner_player
		var to_goal := (team.own_goal() - carrier.flat_pos()).normalized()
		var d := p.flat_pos().distance_to(carrier.flat_pos())
		if d < 2.5:
			return ball.flat_pos()
		var ahead := Vector3(carrier.velocity.x, 0.0, carrier.velocity.z) * clampf(d / 8.0, 0.1, 0.7)
		return carrier.flat_pos() + ahead + to_goal * 1.2
	return _match.loose_ball_intercept(p)


# --- Comportamientos -----------------------------------------------------------

## Lleva al jugador hacia `target`. Con `relaxed` (acomodarse en la forma,
## sin urgencia) va al paso que pide la distancia: camina si está cerca,
## trota a media distancia y corre sólo si quedó lejos, como un jugador real.
func go_to(p: Footballer, target: Vector3, sprint: bool, relaxed: bool = false) -> void:
	p.debug_target = target
	var to := target - p.flat_pos()
	to.y = 0.0
	var d := to.length()
	if d < ARRIVE_RADIUS:
		p.desired_move = Vector3.ZERO
		p.wants_sprint = false
		return
	# Frena al acercarse para no pasarse de largo.
	var pace := clampf(d / 3.0, 0.25, 1.0)
	if relaxed and not sprint:
		pace = minf(pace, clampf(remap(d, 2.0, 14.0, 0.3, 1.0), 0.3, 1.0))
	p.desired_move = to / d * pace
	p.wants_sprint = sprint


func _hold_shape(p: Footballer, ball: Ball) -> void:
	var target := shape_target(p)
	var d := p.flat_pos().distance_to(target)
	var urgent := state in [S.COUNTER_ATTACK, S.RETREATING] and d > 4.0
	go_to(p, target, urgent or d > 14.0, not urgent)
	p.look_at_point(ball.flat_pos())


## El arquero rival tiene la pelota en las manos (no se lo presiona).
func _rival_keeper_holds(ball: Ball) -> bool:
	return ball.in_hands and ball.owner_player != null and ball.owner_player.team != team


## Distancia mínima (m) a la línea del arco rival mientras su arquero tiene la
## pelota en las manos: afuera del área y un poco más.
const KEEPER_HOLD_GAP := 24.0

func _retreat_from_keeper(p: Footballer, ball: Ball) -> void:
	var target := shape_target(p)
	var limit := team.attack_dir * (Pitch.HALF_LENGTH - KEEPER_HOLD_GAP)
	if team.attack_dir * target.x > team.attack_dir * limit:
		target.x = limit
	go_to(p, target, p.flat_pos().distance_to(target) > 15.0, true)
	p.look_at_point(ball.flat_pos())


## Compañero de la CPU más cercano al rival con la pelota (para la presión
## pedida con Cuadrado).
func _support_helper(carrier: Footballer) -> Footballer:
	var best: Footballer = null
	var best_d := INF
	for p in _field_players():
		var d := p.flat_pos().distance_to(carrier.flat_pos())
		if d < best_d:
			best_d = d
			best = p
	return best


func _chase(p: Footballer, ball: Ball, pressing: bool) -> void:
	go_to(p, _intercept_point(p, ball), true)
	if p.desired_move.length_squared() < 0.01:
		p.desired_move = (ball.flat_pos() - p.flat_pos()).normalized() * 0.5
	p.pressing = pressing
	# Entrada: no en cada cuadro (sería infalible por insistencia).
	if pressing and randf() < difficulty.tackle_rate:
		p.wants_tackle = true
	if pressing and ball.owner_player != null:
		var d := p.flat_pos().distance_to(ball.flat_pos())
		var ahead := p.facing.dot((ball.flat_pos() - p.flat_pos()).normalized()) > 0.8
		if d < 2.0 and ahead and randf() < 0.01:
			p.start_slide(ball.flat_pos() - p.flat_pos())


## Marca en zona: se ubica del lado del arco propio del rival asignado.
func _mark(p: Footballer, o: Footballer) -> void:
	var goal := team.own_goal()
	var target := o.flat_pos() + (goal - o.flat_pos()).normalized() * 1.8
	go_to(p, Pitch.clamp_to_field(target, 0.5), p.flat_pos().distance_to(target) > 4.0)
	p.look_at_point(_match.ball.flat_pos())


func _receive(p: Footballer, ball: Ball) -> void:
	var target := p.pass_target
	var meet := _match.loose_ball_intercept(p)
	if meet.distance_to(p.flat_pos()) < target.distance_to(p.flat_pos()):
		target = meet
	go_to(p, target, true)
	if p.desired_move.length_squared() < 0.01:
		p.look_at_point(ball.flat_pos())


## Juego detenido: pelotas paradas o forma.
func _stopped(p: Footballer, ball: Ball) -> void:
	# En la barrera: quieto en su lugar, mirando la pelota.
	if _match.wall_targets.has(p):
		p.debug_state = "barrera"
		go_to(p, _match.wall_targets[p], false)
		p.look_at_point(ball.flat_pos())
		return
	var r := _match.upcoming_restart()
	if r.is_empty():
		p.debug_state = "posición"
		_hold_shape(p, ball)
		return
	var key := "%d|%d|%s" % [r["type"], r["team"], str(r["spot"])]
	if key != _set_piece_key:
		_set_piece_key = key
		_set_piece_targets = SetPieceShape.targets(team, r["type"], r["team"], r["spot"], r.get("taker"))
	if _set_piece_targets.has(p):
		p.debug_state = "pelota parada"
		var t: Vector3 = _set_piece_targets[p]
		go_to(p, t, p.flat_pos().distance_to(t) > 6.0)
		p.look_at_point(ball.flat_pos())
	else:
		p.debug_state = "posición"
		_hold_shape(p, ball)


# --- El que tiene la pelota ------------------------------------------------------

func _carrier(p: Footballer, ball: Ball) -> void:
	var goal := team.target_goal()
	var to_goal := goal - p.flat_pos()
	var dist_goal := to_goal.length()
	var nearest := _nearest_opponent(p.flat_pos())
	var opp_dist := INF if nearest == null else nearest.flat_pos().distance_to(p.flat_pos())

	# Conducción: hacia el arco esquivando al rival más cercano, sin irse por la raya.
	var dir := to_goal.normalized()
	if state == S.BUILD_UP:
		# En la salida se progresa por afuera, sin apurarse.
		dir = (dir + Vector3(0.0, 0.0, signf(p.global_position.z) * 0.4)).normalized()
	if nearest != null and opp_dist < 6.0:
		var away := (p.flat_pos() - nearest.flat_pos()).normalized()
		dir = (dir + away * (6.0 - opp_dist) / 6.0 * 0.9).normalized()
	if absf(p.global_position.z) > Pitch.HALF_WIDTH - 4.0:
		dir.z -= signf(p.global_position.z) * 0.6
		dir = dir.normalized()
	p.desired_move = dir
	p.debug_target = p.flat_pos() + dir * 4.0
	var blocked := nearest != null and opp_dist < 3.5 and dir.dot((nearest.flat_pos() - p.flat_pos()).normalized()) > 0.5
	p.wants_sprint = not blocked and state != S.BUILD_UP

	if _carrier_timer > 0.0 or p.possession_time < 0.3 or not _match.can_kick(p):
		return
	_carrier_timer = CARRIER_INTERVAL

	# Remate.
	if dist_goal < SHOOT_DISTANCE and absf(p.global_position.z) < 20.0:
		var chance := clampf(remap(dist_goal, SHOOT_DISTANCE, 10.0, 0.06, 0.9), 0.06, 0.9) * difficulty.shot_eagerness
		if not _lane_clear(p.flat_pos(), goal, 1.6):
			chance *= 0.35
		if state == S.COUNTER_ATTACK:
			chance *= 1.2
		if randf() < chance:
			_match.perform_kick(p, KickActions.Kind.SHOT, Vector3(0.0, 0.0, randf_range(-1.0, 1.0)), randf_range(0.45, 0.85))
			return
	# Centro desde la banda con gente en el área.
	if KickActions.is_cross_position(p, ball.flat_pos()) and _mates_in_box() >= 1:
		if randf() < 0.55 or opp_dist < 4.0:
			_match.perform_kick(p, KickActions.Kind.LONG_PASS, goal - p.flat_pos(), randf_range(0.2, 0.55))
			return
	var best := _evaluate_passes(p)
	var pressured := opp_dist < 3.0
	var space_ahead := _space_ahead(p, dir)
	var do_pass := false
	match state:
		S.BUILD_UP:
			do_pass = pressured or best.get("score", -INF) > 0.1 or p.possession_time > 1.8
		S.COUNTER_ATTACK:
			do_pass = pressured or (best.get("kind", -1) == KickActions.Kind.THROUGH_PASS and best["score"] > 0.3) \
				or space_ahead < 7.0
		_:
			do_pass = pressured or (space_ahead < 9.0 and best.get("score", -INF) > 0.1) \
				or best.get("score", -INF) > 0.45 or p.possession_time > 2.5
	if do_pass and best.has("mate"):
		var mate: Footballer = best["mate"]
		var target: Vector3 = best["target"]
		_match.perform_kick(p, best["kind"], target - p.flat_pos(), best["power"], mate)


## Mejor opción de pase: {mate, target, kind, power, score} (vacío si no hay).
func _evaluate_passes(p: Footballer) -> Dictionary:
	var best := {}
	var best_score := -INF
	var my_x := team.progress_of(p.flat_pos())
	for m in team.players:
		if m == p or m.is_keeper():
			continue
		var target := m.flat_pos()
		var kind := KickActions.Kind.SHORT_PASS
		var bonus := 0.0
		if m == _runner and _time < _runner_until:
			target = _runner_target
			kind = KickActions.Kind.THROUGH_PASS
			bonus = 0.5
		var d := target.distance_to(p.flat_pos())
		if d < 5.0 or d > 50.0:
			continue
		var lane := _lane_min_distance(p.flat_pos(), target)
		if lane < 1.4:
			continue
		if d > 30.0 and kind != KickActions.Kind.THROUGH_PASS:
			kind = KickActions.Kind.LONG_PASS
		var open := minf(_open_space(m.flat_pos()), 10.0) / 10.0
		# El avance pesa más que la comodidad: se juega para progresar. El pase
		# hacia atrás sólo conviene si no hay otra cosa (o en la salida).
		var gain := (team.progress_of(target) - my_x) * 5.0
		if gain < 0.0 and state != S.BUILD_UP:
			gain *= 1.5
		var risk := clampf(1.0 - (lane - 1.4) / 4.0, 0.0, 1.0)
		var score := gain + open * 0.8 - risk * 0.8 - d / 60.0 + bonus
		score += randf_range(-1.0, 1.0) * difficulty.decision_noise
		if state == S.BUILD_UP:
			score += open * 0.4 # en la salida, prioridad a no perderla
		if score > best_score:
			best_score = score
			# Pases firmes: menos tiempo de pelota suelta y menos intercepciones.
			var power := 0.6 if kind == KickActions.Kind.SHORT_PASS else (0.5 if kind == KickActions.Kind.THROUGH_PASS else 0.45)
			best = {"mate": m, "target": target, "kind": kind, "power": power, "score": score}
	return best


## Mejor compañero para un pase (lo usa el arquero para reponer).
func best_pass_option(p: Footballer, _from_keeper: bool = false) -> Footballer:
	var best := _evaluate_passes(p)
	return best.get("mate")


## Blanco para un pelotazo: delante del delantero más adelantado.
func long_ball_target() -> Vector3:
	var best: Footballer = null
	var best_x := -1.0
	for p in team.players:
		if p.is_keeper():
			continue
		var x := team.progress_of(p.flat_pos())
		if x > best_x:
			best_x = x
			best = p
	if best == null:
		return team.to_world(Vector2(0.6, 0.0))
	return best.flat_pos() + Vector3(team.attack_dir * 5.0, 0.0, 0.0)


## Rivales cerca del área propia (para decidir si la salida es corta o larga).
func opponents_near_own_box() -> int:
	var n := 0
	for o in _match.opponents_of(team).players:
		if team.progress_of(o.flat_pos()) < 0.25:
			n += 1
	return n


func _mates_in_box() -> int:
	var n := 0
	for m in team.players:
		if Pitch.in_penalty_area(m.flat_pos(), team.attack_dir):
			n += 1
	return n


## Ejecutor de pelota parada de la IA.
func _restart_taker(p: Footballer) -> void:
	p.desired_move = Vector3.ZERO
	if not _match.restart_ready():
		return
	match _match.restart_type:
		MatchRules.Restart.CORNER:
			if randf() < 0.2:
				var short := _nearest_mate(p)
				if short != null:
					_match.perform_kick(p, KickActions.Kind.SHORT_PASS, short.flat_pos() - p.flat_pos(), 0.35, short)
					return
			_match.perform_kick(p, KickActions.Kind.LONG_PASS, team.target_goal() - p.flat_pos(), randf_range(0.3, 0.7))
			return
		MatchRules.Restart.PENALTY:
			# Al palo: a un costado y a media altura, con algo de azar.
			var aim := Vector3(0.0, 0.0, 1.0 if randf() < 0.5 else -1.0)
			_match.perform_kick(p, KickActions.Kind.SHOT, aim, randf_range(0.55, 0.8))
			return
		MatchRules.Restart.FREE_KICK:
			var goal := team.target_goal()
			if p.flat_pos().distance_to(goal) < 28.0 and absf(p.flat_pos().z) < 18.0 and randf() < 0.6:
				var aim2 := Vector3(0.0, 0.0, signf(randf() - 0.5))
				_match.perform_kick(p, KickActions.Kind.SHOT, aim2, randf_range(0.6, 0.85))
				return
		MatchRules.Restart.GOAL_KICK:
			var best := _evaluate_passes(p)
			if best.has("mate") and best["score"] > 0.0 and opponents_near_own_box() < 3:
				_match.perform_kick(p, KickActions.Kind.SHORT_PASS, best["target"] - p.flat_pos(), 0.45, best["mate"])
			else:
				_match.perform_kick(p, KickActions.Kind.LONG_PASS, long_ball_target() - p.flat_pos(), 0.8)
			return
	var best2 := _evaluate_passes(p)
	if best2.has("mate"):
		_match.perform_kick(p, best2["kind"], best2["target"] - p.flat_pos(), best2["power"], best2["mate"])
	else:
		_match.perform_kick(p, KickActions.Kind.SHORT_PASS, Vector3(team.attack_dir, 0.0, 0.0), 0.4)


# --- Utilidades -----------------------------------------------------------------

func _nearest_opponent(pos: Vector3) -> Footballer:
	var best: Footballer = null
	var best_d := INF
	for o in _match.opponents_of(team).players:
		var d := o.flat_pos().distance_to(pos)
		if d < best_d:
			best_d = d
			best = o
	return best


func _nearest_mate(p: Footballer) -> Footballer:
	var best: Footballer = null
	var best_d := INF
	for m in team.players:
		if m == p or m.is_keeper():
			continue
		var d := m.flat_pos().distance_to(p.flat_pos())
		if d < best_d:
			best_d = d
			best = m
	return best


func _open_space(pos: Vector3) -> float:
	var o := _nearest_opponent(pos)
	return 10.0 if o == null else o.flat_pos().distance_to(pos)


func _lane_min_distance(from: Vector3, to: Vector3) -> float:
	var best := INF
	for o in _match.opponents_of(team).players:
		var closest := Geometry3D.get_closest_point_to_segment(o.flat_pos(), from, to)
		best = minf(best, closest.distance_to(o.flat_pos()))
	return best


func _lane_clear(from: Vector3, to: Vector3, margin: float) -> bool:
	return _lane_min_distance(from, to) >= margin


## Distancia al rival más cercano dentro de un cono de 50° hacia adelante.
func _space_ahead(p: Footballer, dir: Vector3) -> float:
	var best := INF
	for o in _match.opponents_of(team).players:
		var to := o.flat_pos() - p.flat_pos()
		var d := to.length()
		if d > 0.1 and dir.angle_to(to / d) < deg_to_rad(50.0):
			best = minf(best, d)
	return best


## Corre un punto de apoyo lejos del rival más cercano (para quedar libre).
func _away_from_opponents(point: Vector3) -> Vector3:
	var o := _nearest_opponent(point)
	if o == null:
		return point
	var d := point - o.flat_pos()
	if d.length() < 4.0 and d.length() > 0.01:
		return Pitch.clamp_to_field(point + d.normalized() * (4.0 - d.length()), 2.0)
	return point
