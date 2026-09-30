extends GutTest
## Precisión de pases y remates.


func test_better_passer_is_more_accurate() -> void:
	assert_lt(KickAccuracy.pass_error(90, 80, 0.0, 0.0, 0.5), KickAccuracy.pass_error(40, 40, 0.0, 0.0, 0.5))


func test_pressure_and_body_angle_hurt_passes() -> void:
	var clean := KickAccuracy.pass_error(70, 70, 0.0, 0.0, 0.5)
	assert_gt(KickAccuracy.pass_error(70, 70, 1.0, 0.0, 0.5), clean, "bajo presión")
	assert_gt(KickAccuracy.pass_error(70, 70, 0.0, 150.0, 0.5), clean, "pase de espaldas")


func test_long_shots_and_full_power_are_less_accurate() -> void:
	var base := KickAccuracy.shot_error(75, 70, 70, 0.0, 0.0, 12.0, 0.5)
	assert_gt(KickAccuracy.shot_error(75, 70, 70, 0.0, 0.0, 30.0, 0.5), base, "de lejos")
	assert_gt(KickAccuracy.shot_error(75, 70, 70, 0.0, 0.0, 12.0, 1.0), base, "a fondo")


func test_assist_blends_stick_and_target() -> void:
	var to_target := Vector3(1, 0, 0)
	var stick := Vector3(0, 0, 1) # 90° de diferencia
	var full := KickAccuracy.assisted_direction(to_target, stick, 1.0)
	var none := KickAccuracy.assisted_direction(to_target, stick, 0.0)
	var half := KickAccuracy.assisted_direction(to_target, stick, 0.5)
	assert_almost_eq(full.angle_to(to_target), 0.0, 0.001)
	assert_almost_eq(none.angle_to(stick), 0.0, 0.001)
	assert_almost_eq(rad_to_deg(half.angle_to(to_target)), 45.0, 0.1)


func test_no_stick_goes_to_target() -> void:
	var d := KickAccuracy.assisted_direction(Vector3(3, 0, 4), Vector3.ZERO, 0.8)
	assert_almost_eq(d.angle_to(Vector3(3, 0, 4)), 0.0, 0.001)
