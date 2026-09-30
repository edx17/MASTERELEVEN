extends GutTest
## Elección de receptor según la dirección del stick.

var mates: Array[Vector3] = [
	Vector3(10, 0, 0), # 0: adelante
	Vector3(0, 0, 10), # 1: abajo en pantalla
	Vector3(-8, 0, 0), # 2: atrás
	Vector3(40, 0, 2), # 3: lejos adelante
]


func test_picks_teammate_in_stick_direction() -> void:
	assert_eq(PassTargeting.choose(Vector3.ZERO, Vector3(1, 0, 0), mates, 50.0, 2.0, 35.0), 0)
	assert_eq(PassTargeting.choose(Vector3.ZERO, Vector3(0, 0, 1), mates, 50.0, 2.0, 35.0), 1)
	assert_eq(PassTargeting.choose(Vector3.ZERO, Vector3(-1, 0, 0), mates, 50.0, 2.0, 35.0), 2)


func test_nobody_in_cone_returns_minus_one() -> void:
	assert_eq(PassTargeting.choose(Vector3.ZERO, Vector3(0, 0, -1), mates, 30.0, 2.0, 35.0), -1)


func test_long_pass_prefers_far_teammate() -> void:
	assert_eq(PassTargeting.choose(Vector3.ZERO, Vector3(1, 0, 0), mates, 50.0, 5.0, 70.0, true), 3)
