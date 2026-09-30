class_name GoalkeeperController
extends RefCounted
## Comportamiento del arquero (lo maneja siempre la IA):
## - ubicación sobre la bisectriz pelota-arco, más adelantado si el equipo
##   defiende alto (arquero "líbero"),
## - atajada según el plan del SaveModel (si no llega, se lanza tarde),
## - achique en el mano a mano dentro del área,
## - salida a cortar centros que caen en el área chica,
## - reposición según el estado del equipo: corta a un defensor libre en la
##   salida, rápida en contraataque, larga si presionan.

var team: Team
var _match: MatchController
var _hold: float = 0.0


func _init(p_team: Team, p_match: MatchController) -> void:
	team = p_team
	_match = p_match


func tick(p: Footballer, ai: TeamAI, dt: float) -> void:
	var ball := _match.ball
	var own := team.own_side()
	var goal := team.own_goal()
	p.speed_override = 0.0
	if ball.owner_player == p:
		_distribute(p, ai, dt)
		return
	_hold = 0.0

	var bp := ball.flat_pos()
	var v := ball.state.vel
	# 1) Remate en curso: se tira al punto de cruce.
	var plan: Dictionary = _match.save_plan
	if plan.get("keeper") == p:
		var pt: Vector3 = plan["point"]
		var spot := Vector3(goal.x - own * 0.4, 0.0, clampf(pt.z, -Pitch.GOAL_HALF_WIDTH, Pitch.GOAL_HALF_WIDTH))
		p.speed_override = _match.tuning.keeper_dive_speed * (1.0 if plan["will_save"] else 0.55)
		p.debug_state = "estirada" if plan["will_save"] else "no llega"
		ai.go_to(p, spot, true)
		return
	# 2) Centro que cae en el área chica: sale a cortarlo si llega antes.
	if ball.is_loose() and ball.state.pos.y > 1.2 and v.x * own > 0.0:
		var landing := _landing_point()
		if _in_goal_area(landing) and _arrives_first(p, landing):
			p.debug_state = "sale al centro"
			ai.go_to(p, landing, true)
			return
	# 3) Pelota viniendo al arco (no remate): se ubica donde va a cruzar.
	if ball.is_loose() and v.x * own > 4.0 and absf(bp.x - goal.x) < 35.0:
		var t_cross := (goal.x - own * 0.6 - bp.x) / v.x
		if t_cross > 0.0 and t_cross < 2.0:
			var z_cross := bp.z + v.z * t_cross
			if absf(z_cross) < Pitch.GOAL_HALF_WIDTH + 1.5:
				var spot2 := Vector3(goal.x - own * 0.6, 0.0, clampf(z_cross, -Pitch.GOAL_HALF_WIDTH + 0.3, Pitch.GOAL_HALF_WIDTH - 0.3))
				p.speed_override = _match.tuning.keeper_dive_speed
				p.debug_state = "cubre el arco"
				ai.go_to(p, spot2, true)
				return
	# 4) Mano a mano: atacante con pelota encarando dentro del área.
	var carrier := ball.owner_player
	if carrier != null and carrier.team != team and Pitch.in_penalty_area(bp, own) and bp.distance_to(goal) < 14.0:
		p.debug_state = "achica"
		ai.go_to(p, bp, true)
		return
	# 5) Pelota suelta y lenta en el área: sale a buscarla.
	if ball.is_loose() and Pitch.in_penalty_area(bp, own) and v.length() < 9.0:
		if _arrives_first(p, bp):
			p.debug_state = "sale"
			ai.go_to(p, bp, true)
			return
	# 6) Ubicación: sobre la línea pelota-centro del arco. Si el equipo
	# defiende alto y la pelota está lejos, se adelanta (líbero).
	p.debug_state = "ubicación"
	var to_ball := bp - goal
	var off := clampf(to_ball.length() * 0.12, 0.8, 4.0)
	var line_x := TeamShape.defensive_line(ai.state, team.progress_of(bp))
	if team.progress_of(bp) > 0.5:
		off = maxf(off, clampf((line_x - 0.1) * Pitch.HALF_LENGTH * 2.0 * 0.5, 0.0, 14.0))
	var spot3 := goal + to_ball.normalized() * off
	if off < 5.0:
		spot3.z = clampf(spot3.z, -Pitch.GOAL_HALF_WIDTH, Pitch.GOAL_HALF_WIDTH)
	ai.go_to(p, spot3, false)
	p.look_at_point(bp)


## Primer punto de la trayectoria en el que la pelota, bajando, queda a
## altura de manos (< 1,8 m).
func _landing_point() -> Vector3:
	var f := _match.ball_forecast
	var prev_y := _match.ball.state.pos.y
	for bp in f:
		if bp.y < prev_y and bp.y < 1.8:
			return Vector3(bp.x, 0.0, bp.z)
		prev_y = bp.y
	return _match.ball.flat_pos()


func _in_goal_area(pos: Vector3) -> bool:
	var own := team.own_side()
	var dx := own * Pitch.HALF_LENGTH - pos.x
	return dx * own >= 0.0 and dx * own <= Pitch.GOAL_AREA_DEPTH + 1.5 and absf(pos.z) <= Pitch.GOAL_AREA_HALF_WIDTH + 1.0


func _arrives_first(p: Footballer, point: Vector3) -> bool:
	var mine := p.flat_pos().distance_to(point)
	for o in _match.opponents_of(team).players:
		if o.flat_pos().distance_to(point) < mine - 1.0:
			return false
	return true


## Reposición según el estado del equipo.
func _distribute(p: Footballer, ai: TeamAI, dt: float) -> void:
	p.desired_move = Vector3.ZERO
	p.facing = Vector3(team.attack_dir, 0.0, 0.0)
	p.debug_state = "repone"
	_hold += dt
	var wait := _match.tuning.keeper_hold_time
	if ai.state == TeamShape.State.COUNTER_ATTACK:
		wait *= 0.4
	if _hold < wait:
		return
	_hold = 0.0
	var pressed := ai.opponents_near_own_box() >= 3
	var mate := ai.best_pass_option(p, true)
	if mate != null and not pressed and randf() < 0.75:
		_match.perform_kick(p, KickActions.Kind.SHORT_PASS, mate.flat_pos() - p.flat_pos(), 0.5)
	else:
		var target := ai.long_ball_target()
		_match.perform_kick(p, KickActions.Kind.LONG_PASS, target - p.flat_pos(), randf_range(0.5, 0.85))
