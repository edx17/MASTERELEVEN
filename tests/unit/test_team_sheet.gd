extends GutTest
## Dirección del equipo (pantalla estilo WE), condición del día, pateadores
## elegidos e intercambios de la alineación.

var m: MatchController


func before_each() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	m.phase = MatchController.Phase.PLAYING
	m.restart_taker = null
	m.ball.frozen = false


func _sheet(prematch: bool) -> TeamSheet:
	var sh := TeamSheet.new()
	add_child_autofree(sh)
	sh.open(m, m.teams[0], prematch)
	return sh


func test_squad_has_23_players() -> void:
	for t in m.teams:
		assert_eq(t.data.players.size(), 23)
		assert_eq(t.bench.size(), 12)
	var sh := _sheet(false)
	assert_eq(sh.entries().size(), 23, "la lista muestra a los 23")


func test_condition_changes_the_attributes() -> void:
	var d: PlayerData = m.teams[0].data.players[5]
	assert_eq(d.with_condition(PlayerData.Condition.NORMAL), d, "normal: los mismos datos")
	var top := d.with_condition(PlayerData.Condition.TOP)
	assert_eq(top.speed, mini(d.speed + 6, 99))
	var bad := d.with_condition(PlayerData.Condition.BAD)
	assert_eq(bad.passing, d.passing - 6)
	# El que entra juega con la condición de su día.
	var t := m.teams[0]
	var sub: PlayerData = t.bench[3]
	t.conditions[sub] = PlayerData.Condition.TOP
	m.phase = MatchController.Phase.STOPPED
	var p := m.substitute(t.players[7], sub)
	assert_eq(p.base_data, sub)
	assert_eq(p.data.technique, mini(sub.technique + 6, 99))


func test_condition_odds_cover_all_states() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var seen := {}
	for i in 400:
		seen[PlayerData.roll_condition(rng)] = true
	assert_eq(seen.size(), 5)


func test_column_cycles_with_l1_r1() -> void:
	var sh := _sheet(false)
	assert_eq(sh.column, TeamSheet.Column.POSITION)
	sh.cycle_column(1)
	assert_eq(sh.column, TeamSheet.Column.ENERGY)
	sh.cycle_column(1)
	assert_eq(sh.column, TeamSheet.Column.CONDITION)
	sh.cycle_column(1)
	assert_eq(sh.column, TeamSheet.Column.POSITION)
	sh.cycle_column(-1)
	assert_eq(sh.column, TeamSheet.Column.CONDITION)


func test_focus_survives_the_column_change() -> void:
	# Con el cursor en un jugador, L1 / R1 rearma la lista: el foco no se pierde.
	var sh := _sheet(false)
	sh._rows[4].grab_focus()
	sh._focus_index = 4
	sh.cycle_column(1)
	var owner := sh.get_viewport().gui_get_focus_owner()
	assert_not_null(owner, "sigue habiendo foco")
	assert_eq(owner, sh._rows[4], "en el mismo jugador")
	# Y con el cursor en el menú, vuelve al mismo botón.
	(sh._menu.get_child(1) as Control).grab_focus()
	sh.cycle_column(1)
	assert_eq(sh.get_viewport().gui_get_focus_owner(), sh._menu.get_child(1))


func test_prematch_swap_is_free() -> void:
	var t := m.teams[0]
	var sh := _sheet(true)
	var starter := t.roster[9]
	var e := sh.entries()
	var bench_entry := e[11 + 4]
	var incoming: PlayerData = bench_entry["d"]
	sh.press_entry(e[9])
	sh.press_entry(bench_entry)
	assert_eq(t.roster[9].base_data, incoming, "el suplente pasa a titular")
	assert_true(t.bench.has(starter.base_data), "el titular vuelve al banco")
	assert_eq(t.subs_used, 0, "en la previa no cuenta como cambio")
	assert_eq(t.players.size(), 11)


func test_in_match_swap_is_a_substitution() -> void:
	var t := m.teams[0]
	var sh := _sheet(false)
	var e := sh.entries()
	sh.press_entry(e[8])
	sh.press_entry(e[11 + 2])
	assert_eq(t.pending_subs.size(), 1, "con la pelota en juego, queda pedido")
	assert_eq(t.subs_left(), 2)


func test_two_starters_swap_positions() -> void:
	var t := m.teams[0]
	var gk := t.roster[0]
	var df := t.roster[2]
	m.swap_slots(gk, df)
	assert_true(df.is_keeper(), "el defensor pasa al arco")
	assert_false(gk.is_keeper())
	assert_eq(t.slot_of(df), 0)
	assert_eq(df.kit_colors()["shirt"], t.keeper_color, "con la ropa de arquero")
	assert_eq(gk.kit_colors()["shirt"], t.color)


func test_chosen_takers_take_the_set_pieces() -> void:
	var t := m.teams[0]
	var ck: PlayerData = t.roster[3].base_data
	var fk: PlayerData = t.roster[6].base_data
	var pk: PlayerData = t.roster[4].base_data
	t.ck_taker = ck
	t.fk_taker = fk
	t.pk_taker = pk
	var corner := Vector3(t.attack_dir * Pitch.HALF_LENGTH, 0.11, Pitch.HALF_WIDTH)
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.CORNER, 0, corner))
	assert_eq(m.restart_taker.base_data, ck, "córner")
	var near := t.target_goal() - Vector3(t.attack_dir * 24.0, 0.0, -4.0)
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.FREE_KICK, 0, Vector3(near.x, 0.11, near.z)))
	assert_eq(m.restart_taker.base_data, fk, "tiro libre cerca del arco")
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.PENALTY, 0, m.penalty_spot(m.teams[1])))
	assert_eq(m.restart_taker.base_data, pk, "penal")


func test_sheet_sets_captain_and_taker() -> void:
	var t := m.teams[0]
	var sh := _sheet(false)
	sh._choose(TeamSheet.Mode.CAPTAIN)
	sh.press_entry(sh.entries()[5])
	assert_eq(t.captain, t.roster[5].base_data)
	sh._choose(TeamSheet.Mode.PK)
	sh.press_entry(sh.entries()[10])
	assert_eq(t.pk_taker, t.roster[10].base_data)
	assert_eq(sh.mode, TeamSheet.Mode.SUBSTITUTE, "vuelve al menú")
