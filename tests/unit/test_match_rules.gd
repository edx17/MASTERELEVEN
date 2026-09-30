extends GutTest
## Reglas mínimas: gol, córner, saque de arco y lateral.

const R := 0.11
var dirs: Array[int] = [1, -1] # equipo 0 ataca hacia +X


func test_ball_inside_field_is_nothing() -> void:
	var o := MatchRules.check(Vector3(10, R, 5), R, 0, dirs)
	assert_eq(o.type, MatchRules.Restart.NONE)


func test_ball_on_the_line_is_still_in_play() -> void:
	var o := MatchRules.check(Vector3(Pitch.HALF_LENGTH + 0.05, R, 0), R, 0, dirs)
	assert_eq(o.type, MatchRules.Restart.NONE, "tiene que cruzar la línea por completo")


func test_goal_for_team_attacking_that_side() -> void:
	var o := MatchRules.check(Vector3(Pitch.HALF_LENGTH + 0.5, 0.5, 1.0), R, 0, dirs)
	assert_eq(o.type, MatchRules.Restart.GOAL)
	assert_eq(o.team, 0)
	var o2 := MatchRules.check(Vector3(-Pitch.HALF_LENGTH - 0.5, 0.5, -1.0), R, 0, dirs)
	assert_eq(o2.type, MatchRules.Restart.GOAL)
	assert_eq(o2.team, 1, "gol en contra también cuenta para el rival")


func test_over_the_bar_is_not_goal() -> void:
	var o := MatchRules.check(Vector3(Pitch.HALF_LENGTH + 0.5, 3.0, 0.0), R, 0, dirs)
	assert_eq(o.type, MatchRules.Restart.GOAL_KICK)
	assert_eq(o.team, 1)


func test_corner_when_defender_touched_last() -> void:
	var o := MatchRules.check(Vector3(Pitch.HALF_LENGTH + 0.5, R, 10.0), R, 1, dirs)
	assert_eq(o.type, MatchRules.Restart.CORNER)
	assert_eq(o.team, 0)
	assert_gt(o.spot.z, 0.0, "córner del lado por donde salió")


func test_goal_kick_when_attacker_touched_last() -> void:
	var o := MatchRules.check(Vector3(-Pitch.HALF_LENGTH - 0.5, R, 12.0), R, 1, dirs)
	assert_eq(o.type, MatchRules.Restart.GOAL_KICK)
	assert_eq(o.team, 0)


func test_throw_in_goes_to_other_team() -> void:
	var o := MatchRules.check(Vector3(5.0, R, Pitch.HALF_WIDTH + 0.5), R, 0, dirs)
	assert_eq(o.type, MatchRules.Restart.THROW_IN)
	assert_eq(o.team, 1)
	assert_almost_eq(o.spot.z, Pitch.HALF_WIDTH, 0.001)


func test_sides_swap_after_halftime() -> void:
	var swapped: Array[int] = [-1, 1]
	var o := MatchRules.check(Vector3(Pitch.HALF_LENGTH + 0.5, 0.5, 0.0), R, 0, swapped)
	assert_eq(o.team, 1)
