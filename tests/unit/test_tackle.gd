extends GutTest
## Entradas: el ángulo importa.

var m: MatchController


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate() as MatchController
	add_child_autofree(m)
	m.set_physics_process(false)


func test_front_tackle_is_easier_than_from_behind() -> void:
	var carrier: Footballer = m.teams[0].players[9]
	var defender: Footballer = m.teams[1].players[3]
	carrier.teleport(Vector3(0, 0, 0), Vector3.RIGHT)
	m.ball.place(Vector3(0.6, 0.11, 0))
	m.ball.give_to(carrier)
	defender.teleport(Vector3(1.2, 0, 0), Vector3.LEFT)
	var front := m.tackle_chance(defender, carrier)
	defender.teleport(Vector3(-1.0, 0, 0), Vector3.RIGHT)
	var back := m.tackle_chance(defender, carrier)
	assert_gt(front, back + 0.3)
	assert_lt(front, 0.95, "nunca es segura")
