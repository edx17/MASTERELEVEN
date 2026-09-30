extends GutTest
## Formación y conversión espacio de equipo <-> mundo.


func test_team_space_mirrors_for_away_team() -> void:
	var home := Team.new(0, "A", "A", Color.WHITE, Color.BLACK, Color.YELLOW)
	var away := Team.new(1, "B", "B", Color.WHITE, Color.BLACK, Color.YELLOW)
	home.attack_dir = 1
	away.attack_dir = -1
	var gk := Vector2(0.0, 0.0)
	assert_almost_eq(home.to_world(gk).x, -Pitch.HALF_LENGTH, 0.001)
	assert_almost_eq(away.to_world(gk).x, Pitch.HALF_LENGTH, 0.001)
	assert_almost_eq(home.progress_of(home.to_world(Vector2(0.3, 0.5))), 0.3, 0.001)
	assert_almost_eq(away.lateral_of(away.to_world(Vector2(0.3, 0.5))), 0.5, 0.001)


func test_kickoff_spots_are_in_own_half() -> void:
	for spot in Formation.SPOTS_442:
		assert_lt(Formation.kickoff_spot(spot, true).x, 0.5)
		# El que no saca queda fuera del círculo central (9,15 m => x <= 0.41).
		assert_lte(Formation.kickoff_spot(spot, false).x, 0.41)
