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



func test_kpi_save_rate_in_the_box_is_realistic() -> void:
	# Informe técnico: atajadas de tiros al arco dentro del área < 75 %.
	# Muestra de tiros variados (distancia, ángulo, colocación, potencia).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var total := 0.0
	var n := 0
	for i in 300:
		var dist := rng.randf_range(7.0, 16.5)
		var z := rng.randf_range(-12.0, 12.0)
		var from := Vector3(Pitch.HALF_LENGTH - dist, 0.11, z)
		var power := rng.randf_range(0.3, 1.0)
		var speed := lerpf(t.shot_speed_min, t.shot_speed_max, power)
		var height := lerpf(t.shot_height_min, t.shot_height_max, power)
		var plan := _shot(from, rng.randf_range(-3.4, 3.4), height, speed)
		if not plan.on_target:
			continue
		# Arquero bien ubicado: sobre la línea pelota-centro del arco, 1,2 m adelante.
		var goal := Vector3(Pitch.HALF_LENGTH, 0, 0)
		var keeper := goal + (Vector3(from.x, 0, from.z) - goal).normalized() * 1.2
		total += SaveModel.evaluate(plan, keeper, 70, 72).chance
		n += 1
	var rate := total / n
	gut.p("Atajadas esperadas en el área: %.0f %% (%d tiros al arco)" % [rate * 100.0, n])
	assert_between(rate, 0.45, 0.75)
