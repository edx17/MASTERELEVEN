class_name MatchRules
extends RefCounted
## Reglas mínimas (puras, testeables): detecta gol, saque de arco, córner y lateral
## a partir de la posición de la pelota y el último equipo que la tocó.

enum Restart { NONE, GOAL, GOAL_KICK, CORNER, THROW_IN, KICKOFF, FREE_KICK, PENALTY }


## Resultado de una salida de la pelota.
class Outcome:
	var type: int = Restart.NONE
	## Equipo que saca (o que hizo el gol, si type == GOAL).
	var team: int = -1
	## Lugar desde donde se reanuda.
	var spot: Vector3 = Vector3.ZERO

	func _init(p_type: int = Restart.NONE, p_team: int = -1, p_spot: Vector3 = Vector3.ZERO) -> void:
		type = p_type
		team = p_team
		spot = p_spot


## `attack_dir[i]` = +1 si el equipo i ataca hacia +X, -1 si ataca hacia -X.
## `last_touch_team` = índice del último equipo que tocó la pelota (0 o 1).
static func check(ball_pos: Vector3, ball_radius: float, last_touch_team: int, attack_dir: Array[int]) -> Outcome:
	var hl := Pitch.HALF_LENGTH
	var hw := Pitch.HALF_WIDTH
	# La pelota tiene que cruzar la línea por completo.
	if absf(ball_pos.x) > hl + ball_radius:
		var side := int(signf(ball_pos.x))
		var attacker := team_attacking_side(side, attack_dir)
		var defender := 1 - attacker
		if absf(ball_pos.z) < Pitch.GOAL_HALF_WIDTH and ball_pos.y < Pitch.GOAL_HEIGHT:
			return Outcome.new(Restart.GOAL, attacker, Vector3(0.0, ball_radius, 0.0))
		var zs := signf(ball_pos.z) if ball_pos.z != 0.0 else 1.0
		if last_touch_team == defender:
			var corner := Vector3(side * (hl - 0.4), ball_radius, zs * (hw - 0.4))
			return Outcome.new(Restart.CORNER, attacker, corner)
		var gk_spot := Vector3(side * (hl - Pitch.GOAL_AREA_DEPTH), ball_radius, zs * 4.0)
		return Outcome.new(Restart.GOAL_KICK, defender, gk_spot)
	if absf(ball_pos.z) > hw + ball_radius:
		var thrower := 1 - last_touch_team if last_touch_team >= 0 else 0
		var tx := clampf(ball_pos.x, -hl + 1.0, hl - 1.0)
		return Outcome.new(Restart.THROW_IN, thrower, Vector3(tx, ball_radius, signf(ball_pos.z) * hw))
	return Outcome.new()


static func team_attacking_side(side: int, attack_dir: Array[int]) -> int:
	return 0 if attack_dir[0] == side else 1
