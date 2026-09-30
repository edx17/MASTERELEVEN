class_name SimpleAI
extends RefCounted
## IA provisoria de la Fase 1 (se reemplaza en la Fase 2). Mueve a todos los
## jugadores de un equipo que no controla un humano:
## - forma un bloque que se desplaza con la pelota (Formation.dynamic_spot),
## - el más cercano va a buscar la pelota / presiona al portador,
## - otro cubre entre el portador y el arco,
## - el portador conduce hacia el arco, pasa si lo apuran y tira de cerca,
## - el arquero se para entre la pelota y el arco, ataja y reparte.

const DECISION_INTERVAL := 0.25
const SHOOT_DISTANCE := 28.0
const ARRIVE_RADIUS := 0.8

var team: Team
var _match: MatchController
var _decision_timer: float = 0.0
var _keeper_hold: float = 0.0


func _init(p_team: Team, p_match: MatchController) -> void:
	team = p_team
	_match = p_match


func tick(dt: float) -> void:
	var ball := _match.ball
	var owner := ball.owner_player
	var we_have_it := owner != null and owner.team == team
	var they_have_it := owner != null and owner.team != team
	_decision_timer -= dt

	var chaser := _pick_chaser(ball, they_have_it)
	var cover: Footballer = null
	if they_have_it:
		cover = _pick_cover(owner, chaser)

	var progress := team.progress_of(ball.flat_pos())
	var lateral := team.lateral_of(ball.flat_pos())

	for p in team.players:
		if p.is_human():
			continue
		p.pressing = false
		p.speed_override = 0.0
		if _match.restart_taker == p:
			_restart_taker(p, dt)
			continue
		if p.is_keeper():
			_keeper(p, ball, dt)
			continue
		if owner == p:
			_carrier(p, ball)
			continue
		if _match.is_stopped():
			_go_to(p, team.to_world(Formation.dynamic_spot(p.base_spot, p.role, progress, lateral, we_have_it)), false)
			continue
		if p.has_pass_target() and ball.intended_receiver == p and ball.is_loose():
			_receive(p, ball)
			continue
		if p == chaser:
			_chase(p, ball, they_have_it)
			continue
		if p == cover and owner != null:
			var goal := team.own_goal()
			var spot := owner.flat_pos() + (goal - owner.flat_pos()).normalized() * 6.0
			_go_to(p, spot, true)
			continue
		var home := team.to_world(Formation.dynamic_spot(p.base_spot, p.role, progress, lateral, we_have_it))
		_go_to(p, home, p.flat_pos().distance_to(home) > 12.0)
		p.look_at_point(ball.flat_pos())


# --- Selección de roles momentáneos -------------------------------------------

func _pick_chaser(ball: Ball, they_have_it: bool) -> Footballer:
	var owner := ball.owner_player
	if owner != null and owner.team == team:
		return null
	if _match.is_stopped():
		return null
	var best: Footballer = null
	var best_t := INF
	var human_t := INF
	for p in team.players:
		if p.is_keeper() or p.state != Footballer.State.NORMAL:
			continue
		var t := _time_to_ball(p, ball)
		if p.is_human():
			human_t = minf(human_t, t)
			continue
		if t < best_t:
			best_t = t
			best = p
	# Si el humano llega antes, la IA sólo acompaña si está bastante cerca.
	if best != null and human_t < best_t:
		if they_have_it and best.flat_pos().distance_to(ball.flat_pos()) < 12.0:
			return best
		if not they_have_it and best_t < human_t + 0.4:
			return best
		return null
	return best


func _pick_cover(owner: Footballer, chaser: Footballer) -> Footballer:
	var best: Footballer = null
	var best_d := INF
	for p in team.players:
		if p == chaser or p.is_keeper() or p.is_human():
			continue
		var d := p.flat_pos().distance_to(owner.flat_pos())
		if d < best_d:
			best_d = d
			best = p
	return best if best_d < 20.0 else null


## Tiempo estimado para llegar a la pelota (usa la trayectoria predicha).
func _time_to_ball(p: Footballer, ball: Ball) -> float:
	var target := _intercept_point(p, ball)
	return p.flat_pos().distance_to(target) / _match.tuning.sprint_speed


func _intercept_point(p: Footballer, ball: Ball) -> Vector3:
	if not ball.is_loose():
		# Contra un portador: ir a cerrarle el paso del lado del arco propio.
		var carrier := ball.owner_player
		var to_goal := (team.own_goal() - carrier.flat_pos()).normalized()
		var d := p.flat_pos().distance_to(carrier.flat_pos())
		if d < 2.5:
			return ball.flat_pos()
		var ahead := Vector3(carrier.velocity.x, 0.0, carrier.velocity.z) * clampf(d / 8.0, 0.1, 0.7)
		return carrier.flat_pos() + ahead + to_goal * 1.2
	return _match.loose_ball_intercept(p)


# --- Comportamientos ----------------------------------------------------------

func _go_to(p: Footballer, target: Vector3, sprint: bool) -> void:
	var to := target - p.flat_pos()
	to.y = 0.0
	var d := to.length()
	if d < ARRIVE_RADIUS:
		p.desired_move = Vector3.ZERO
		p.wants_sprint = false
		return
	# Frena al acercarse para no pasarse de largo.
	p.desired_move = to / d * clampf(d / 3.0, 0.25, 1.0)
	p.wants_sprint = sprint


func _chase(p: Footballer, ball: Ball, pressing: bool) -> void:
	var target := _intercept_point(p, ball)
	_go_to(p, target, true)
	if p.desired_move.length_squared() < 0.01:
		p.desired_move = (ball.flat_pos() - p.flat_pos()).normalized() * 0.5
	p.pressing = pressing
	# Barrida ocasional si el portador está justo adelante.
	if pressing and ball.owner_player != null:
		var d := p.flat_pos().distance_to(ball.flat_pos())
		var ahead := p.facing.dot((ball.flat_pos() - p.flat_pos()).normalized()) > 0.8
		if d < 2.0 and ahead and randf() < 0.012:
			p.start_slide(ball.flat_pos() - p.flat_pos())


func _receive(p: Footballer, ball: Ball) -> void:
	var target := p.pass_target
	# Si la pelota viene por el piso y se puede cortar antes, se va a su encuentro.
	var meet := _intercept_point(p, ball)
	if meet.distance_to(p.flat_pos()) < target.distance_to(p.flat_pos()):
		target = meet
	_go_to(p, target, true)
	if p.desired_move.length_squared() < 0.01:
		p.look_at_point(ball.flat_pos())


func _carrier(p: Footballer, ball: Ball) -> void:
	var goal := team.target_goal()
	var to_goal := goal - p.flat_pos()
	var dist_goal := to_goal.length()
	var nearest_opp := _nearest_opponent(p.flat_pos())
	var opp_dist := INF if nearest_opp == null else nearest_opp.flat_pos().distance_to(p.flat_pos())

	# Dirección de conducción: hacia el arco, esquivando al rival más cercano.
	var dir := to_goal.normalized()
	if nearest_opp != null and opp_dist < 6.0:
		var away := (p.flat_pos() - nearest_opp.flat_pos()).normalized()
		dir = (dir + away * (6.0 - opp_dist) / 6.0 * 0.9).normalized()
	# No irse por la raya.
	if absf(p.global_position.z) > Pitch.HALF_WIDTH - 4.0:
		dir.z -= signf(p.global_position.z) * 0.6
		dir = dir.normalized()
	p.desired_move = dir
	# Sprint si no hay nadie cerrándole el camino justo adelante.
	var blocked := nearest_opp != null and opp_dist < 3.5 \
		and dir.dot((nearest_opp.flat_pos() - p.flat_pos()).normalized()) > 0.5
	p.wants_sprint = not blocked

	if _decision_timer > 0.0 or p.possession_time < 0.35 or not _match.can_kick(p):
		return
	_decision_timer = DECISION_INTERVAL

	if dist_goal < SHOOT_DISTANCE and absf(p.global_position.z) < 20.0:
		var chance := clampf(remap(dist_goal, SHOOT_DISTANCE, 12.0, 0.1, 0.95), 0.1, 0.95)
		# Con un rival tapando el remate, mejor buscar otra opción.
		if not _lane_clear(p.flat_pos(), goal):
			chance *= 0.35
		if randf() < chance:
			var aim := Vector3(0.0, 0.0, randf_range(-1.0, 1.0))
			_match.perform_kick(p, KickActions.Kind.SHOT, aim, randf_range(0.45, 0.8))
			return
	# Cerca de la línea de fondo y sin ángulo: tirar el centro en vez de meterse.
	if team.progress_of(p.flat_pos()) > 0.92 and absf(p.global_position.z) > Pitch.GOAL_AREA_HALF_WIDTH:
		_match.perform_kick(p, KickActions.Kind.LONG_PASS, goal - p.flat_pos(), randf_range(0.2, 0.5))
		return
	var pressured := opp_dist < 3.2
	if pressured or randf() < 0.04 or p.possession_time > 3.5:
		var mate := _best_pass_option(p)
		if mate != null:
			var d := mate.flat_pos().distance_to(p.flat_pos())
			var dir_to := mate.flat_pos() - p.flat_pos()
			if d > 28.0:
				_match.perform_kick(p, KickActions.Kind.LONG_PASS, dir_to, 0.4)
			elif mate.flat_pos().distance_to(goal) < dist_goal - 8.0 and randf() < 0.35:
				_match.perform_kick(p, KickActions.Kind.THROUGH_PASS, dir_to, 0.3)
			else:
				_match.perform_kick(p, KickActions.Kind.SHORT_PASS, dir_to, 0.35)


## Mejor compañero para pasar: libre de marca, con línea de pase y hacia adelante.
func _best_pass_option(p: Footballer) -> Footballer:
	var best: Footballer = null
	var best_score := -INF
	var goal := team.target_goal()
	var my_goal_dist := p.flat_pos().distance_to(goal)
	for m in team.players:
		if m == p or m.is_keeper():
			continue
		var d := m.flat_pos().distance_to(p.flat_pos())
		if d < 5.0 or d > 45.0:
			continue
		var open := _open_space(m.flat_pos())
		if not _lane_clear(p.flat_pos(), m.flat_pos()):
			continue
		var forward := (my_goal_dist - m.flat_pos().distance_to(goal)) / 10.0
		var score := forward + open * 0.1 - d / 40.0 + randf() * 0.3
		if score > best_score:
			best_score = score
			best = m
	return best


func _nearest_opponent(pos: Vector3) -> Footballer:
	var best: Footballer = null
	var best_d := INF
	for o in _match.opponents_of(team).players:
		var d := o.flat_pos().distance_to(pos)
		if d < best_d:
			best_d = d
			best = o
	return best


func _open_space(pos: Vector3) -> float:
	var o := _nearest_opponent(pos)
	return 10.0 if o == null else minf(o.flat_pos().distance_to(pos), 10.0)


func _lane_clear(from: Vector3, to: Vector3) -> bool:
	for o in _match.opponents_of(team).players:
		var closest := Geometry3D.get_closest_point_to_segment(o.flat_pos(), from, to)
		if closest.distance_to(o.flat_pos()) < 1.6:
			return false
	return true


func _keeper(p: Footballer, ball: Ball, dt: float) -> void:
	var own := team.own_side()
	var goal := team.own_goal()
	if ball.owner_player == p:
		# Reparte después de un momento.
		p.desired_move = Vector3.ZERO
		p.facing = Vector3(team.attack_dir, 0.0, 0.0)
		_keeper_hold += dt
		if _keeper_hold > _match.tuning.keeper_hold_time:
			_keeper_hold = 0.0
			var mate := _best_pass_option(p)
			if mate != null and randf() < 0.6:
				_match.perform_kick(p, KickActions.Kind.SHORT_PASS, mate.flat_pos() - p.flat_pos(), 0.5)
			else:
				var dir := Vector3(team.attack_dir, 0.0, randf_range(-0.5, 0.5))
				_match.perform_kick(p, KickActions.Kind.LONG_PASS, dir, randf_range(0.5, 0.9))
		return
	_keeper_hold = 0.0

	var bp := ball.flat_pos()
	var v := ball.state.vel
	# Pelota viniendo al arco: se tira hacia el punto donde va a cruzar la línea.
	if ball.is_loose() and v.x * own > 4.0 and absf(bp.x - goal.x) < 35.0:
		var t_cross := (goal.x - own * 0.6 - bp.x) / v.x
		if t_cross > 0.0 and t_cross < 2.0:
			var z_cross := bp.z + v.z * t_cross
			if absf(z_cross) < Pitch.GOAL_HALF_WIDTH + 1.5:
				var spot := Vector3(goal.x - own * 0.6, 0.0, clampf(z_cross, -Pitch.GOAL_HALF_WIDTH + 0.3, Pitch.GOAL_HALF_WIDTH - 0.3))
				p.speed_override = _match.tuning.keeper_dive_speed
				_go_to(p, spot, true)
				return
	# Atacante con pelota encarando dentro del área: sale a achicar.
	var carrier := ball.owner_player
	if carrier != null and carrier.team != team and Pitch.in_penalty_area(bp, own) and bp.distance_to(goal) < 14.0:
		_go_to(p, bp, true)
		return
	# Pelota suelta y lenta dentro del área: sale a buscarla.
	if ball.is_loose() and Pitch.in_penalty_area(bp, own) and v.length() < 9.0:
		var nearest_opp := _nearest_opponent(bp)
		var opp_d := INF if nearest_opp == null else nearest_opp.flat_pos().distance_to(bp)
		if bp.distance_to(p.flat_pos()) < opp_d + 2.0:
			_go_to(p, bp, true)
			return
	# Posición base: sobre la línea que une la pelota con el centro del arco.
	var to_ball := bp - goal
	var off := clampf(to_ball.length() * 0.12, 0.8, 4.0)
	var spot2 := goal + to_ball.normalized() * off
	spot2.z = clampf(spot2.z, -Pitch.GOAL_HALF_WIDTH, Pitch.GOAL_HALF_WIDTH)
	_go_to(p, spot2, false)
	p.look_at_point(bp)


## Ejecutor de pelota parada de la IA: apunta y saca después de una pausa.
func _restart_taker(p: Footballer, _dt: float) -> void:
	p.desired_move = Vector3.ZERO
	if not _match.restart_ready():
		return
	var mate := _best_pass_option(p)
	var kind := KickActions.Kind.SHORT_PASS
	var dir := Vector3(team.attack_dir, 0.0, 0.0)
	var pwr := 0.4
	if _match.restart_type == MatchRules.Restart.CORNER:
		kind = KickActions.Kind.LONG_PASS
		dir = (team.target_goal() - p.flat_pos()).normalized()
		pwr = randf_range(0.3, 0.7)
	elif mate != null:
		dir = mate.flat_pos() - p.flat_pos()
		if dir.length() > 28.0:
			kind = KickActions.Kind.LONG_PASS
	elif _match.restart_type == MatchRules.Restart.GOAL_KICK:
		kind = KickActions.Kind.LONG_PASS
		pwr = 0.8
	_match.perform_kick(p, kind, dir, pwr)
