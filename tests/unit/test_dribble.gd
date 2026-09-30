extends GutTest
## Conducción guiada (resorte + pulso de toques).

var t: Tuning


func before_each() -> void:
	t = Tuning.new()


func test_faster_means_longer_touches() -> void:
	assert_gt(Dribble.touch_distance(1.0, 0.0, 0.0, t), Dribble.touch_distance(0.0, 0.0, 0.0, t))


func test_better_control_means_shorter_touches() -> void:
	assert_lt(Dribble.touch_distance(1.0, 0.8, 0.0, t), Dribble.touch_distance(1.0, -0.8, 0.0, t))


func test_pressure_shortens_touches() -> void:
	assert_lt(Dribble.touch_distance(1.0, 0.0, 1.0, t), Dribble.touch_distance(1.0, 0.0, 0.0, t))


func test_pulse_goes_out_and_back() -> void:
	var d := 1.0
	assert_almost_eq(Dribble.pulse(0.0, d), 0.35, 0.001, "recién tocada, cerca del pie")
	assert_almost_eq(Dribble.pulse(0.5, d), 1.0, 0.001, "en el medio del ciclo, lo más lejos")
	assert_almost_eq(Dribble.pulse(1.0, d), 0.35, 0.001, "vuelve al pie")


func test_shielding_puts_ball_away_from_opponent() -> void:
	var target := Dribble.dribble_target(Vector3.ZERO, Vector3.RIGHT, 0.5, Vector3(2, 0, 0), true)
	assert_lt(target.x, 0.0, "la pelota queda del otro lado del rival")


func test_exposed_when_far_from_foot() -> void:
	assert_false(Dribble.is_exposed(Vector3(0.6, 0.1, 0), Vector3.ZERO, Vector3.RIGHT))
	assert_true(Dribble.is_exposed(Vector3(1.5, 0.1, 0), Vector3.ZERO, Vector3.RIGHT))
