extends GutTest
## Forma del equipo: el bloque se mueve como unidad según el estado.

const S := TeamShape.State
var f442: FormationData
var f433: FormationData


func before_all() -> void:
	f442 = FormationLibrary.build("4-4-2")
	f433 = FormationLibrary.build("4-3-3")


func _xs(shape: Array[Vector2], f: FormationData, role: int) -> Array[float]:
	var out: Array[float] = []
	for i in shape.size():
		if f.tactical_role(i) == role:
			out.append(shape[i].x)
	return out


func test_all_formations_are_valid() -> void:
	for f in FormationLibrary.DEFINITIONS:
		assert_true(FormationLibrary.build(f).is_valid(), f)


func test_block_advances_with_the_ball_when_attacking() -> void:
	var back := TeamShape.compute(f442, S.ATTACKING, Vector2(0.4, 0.0))
	var fwd := TeamShape.compute(f442, S.ATTACKING, Vector2(0.75, 0.0))
	for i in range(1, 11):
		assert_gt(fwd[i].x, back[i].x - 0.001, "puesto %d acompaña el avance" % i)
	# La línea defensiva sube de verdad (no se queda en campo propio).
	assert_gt(_xs(fwd, f442, TacticalRole.Kind.CB)[0], 0.4)


func test_ball_side_fullback_overlaps_other_tucks_in() -> void:
	# Pelota por la derecha (y < 0) en ataque.
	var shape := TeamShape.compute(f442, S.ATTACKING, Vector2(0.65, -0.7))
	var right_fb := shape[1] # y base -0.7
	var left_fb := shape[4] # y base +0.7
	assert_gt(right_fb.x, left_fb.x + 0.1, "el lateral del lado de la pelota pasa")
	assert_lt(absf(left_fb.y), 0.5, "el del otro lado cierra")


func test_defending_is_compact_and_narrow() -> void:
	var ball := Vector2(0.5, 0.0)
	var att := TeamShape.compute(f442, S.ATTACKING, ball)
	var dfn := TeamShape.compute(f442, S.DEFENDING, ball)
	var span_att := att[9].x - att[2].x
	var span_def := dfn[9].x - dfn[2].x
	assert_lt(span_def, span_att, "defendiendo, las líneas se juntan")
	var width_att := absf(att[5].y - att[8].y)
	var width_def := absf(dfn[5].y - dfn[8].y)
	assert_lt(width_def, width_att, "defendiendo, el bloque se cierra a lo ancho")


func test_defenders_form_a_line_when_defending() -> void:
	var dfn := TeamShape.compute(f442, S.DEFENDING, Vector2(0.45, 0.3))
	var xs := _xs(dfn, f442, TacticalRole.Kind.CB) + _xs(dfn, f442, TacticalRole.Kind.FB)
	assert_lt(xs.max() - xs.min(), 0.03)


func test_block_shifts_to_ball_side() -> void:
	var left := TeamShape.compute(f433, S.DEFENDING, Vector2(0.4, 0.8))
	var right := TeamShape.compute(f433, S.DEFENDING, Vector2(0.4, -0.8))
	assert_gt(left[6].y, right[6].y + 0.3, "el volante central se corre con la pelota")


func test_without_ball_most_players_stay_behind_it() -> void:
	var dfn := TeamShape.compute(f442, S.DEFENDING, Vector2(0.4, 0.0))
	var ahead := 0
	for i in range(1, 11):
		if dfn[i].x > 0.43:
			ahead += 1
	assert_lte(ahead, 2, "sólo los delanteros quedan adelante de la pelota")


func test_striker_stays_on_last_line_ahead_of_ball() -> void:
	var att := TeamShape.compute(f433, S.ATTACKING, Vector2(0.6, 0.0))
	assert_gt(att[9].x, 0.7)


func test_pressing_line_is_higher_than_defending() -> void:
	var ball := Vector2(0.8, 0.0)
	assert_gt(TeamShape.defensive_line(S.PRESSING, ball.x), TeamShape.defensive_line(S.DEFENDING, ball.x))


func test_zones() -> void:
	assert_eq(Zones.third(0.1), Zones.Third.DEFENSIVE)
	assert_eq(Zones.third(0.9), Zones.Third.ATTACKING)
	assert_eq(Zones.lane(-0.95), Zones.Lane.RIGHT)
	assert_eq(Zones.lane(0.0), Zones.Lane.CENTER)
	assert_eq(Zones.lane(0.95), Zones.Lane.LEFT)
