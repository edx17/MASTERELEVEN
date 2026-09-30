extends GutTest
## Modelo de atajada: la potencia y la colocación importan.

var t: Tuning


func before_each() -> void:
	t = Tuning.new()


func _shot(from: Vector3, aim_z: float, height: float, speed: float) -> SaveModel.Plan:
	var goal := Vector3(Pitch.HALF_LENGTH, 0, aim_z)
	var flat := Vector3(goal.x - from.x, 0, goal.z - from.z)
	var v := KickActions.shot_velocity(from, flat.normalized(), flat.length(), height, speed, t)
	return SaveModel.predict_crossing(BallState.new(from, v), Pitch.HALF_LENGTH, t)


func test_shot_height_follows_power() -> void:
	var low := _shot(Vector3(40, 0.11, 0), 0.0, 0.3, 18.0)
	var high := _shot(Vector3(40, 0.11, 0), 0.0, 1.9, 30.0)
	assert_true(low.on_target and high.on_target)
	assert_lt(low.point.y, 0.9, "tiro flojo, bajo")
	assert_between(high.point.y, 1.3, 2.44, "tiro fuerte, alto pero bajo el travesaño")


func test_power_and_placement_beat_the_keeper() -> void:
	var keeper := Vector3(Pitch.HALF_LENGTH - 0.6, 0, 0)
	var soft_center := SaveModel.evaluate(_shot(Vector3(38, 0.11, 0), 0.0, 0.5, 16.0), keeper, 70, 75)
	var hard_corner := SaveModel.evaluate(_shot(Vector3(38, 0.11, 0), 3.2, 1.9, 31.0), keeper, 70, 75)
	assert_gt(soft_center.chance, 0.85, "flojo al medio: atajada casi segura")
	assert_lt(hard_corner.chance, 0.35, "fuerte al ángulo: gol probable")


func test_close_full_power_is_not_the_same_as_soft() -> void:
	var keeper := Vector3(Pitch.HALF_LENGTH - 0.6, 0, 0)
	var soft := SaveModel.evaluate(_shot(Vector3(44, 0.11, -2), 2.5, 0.4, 15.0), keeper, 70, 75)
	var hard := SaveModel.evaluate(_shot(Vector3(44, 0.11, -2), 2.5, 1.7, 32.0), keeper, 70, 75)
	assert_gt(soft.chance, hard.chance + 0.25)


func test_off_target_is_not_on_target() -> void:
	var p := _shot(Vector3(40, 0.11, 0), 6.0, 1.0, 25.0)
	assert_false(p.on_target)
