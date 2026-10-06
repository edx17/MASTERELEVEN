extends GutTest
## Liga / Copa / Mundial con el diseño 03 "Mesa táctica".

var hub: CompetitionHub


func before_each() -> void:
	hub = CompetitionHub.new()
	add_child_autofree(hub)
	await get_tree().process_frame


func _cup() -> Competition:
	var c := Competition.create_cup(GameSettings.team_paths(), 0, 3)
	c.complete_round([2, 1], 10)
	return c


func test_league_shows_table_with_numbers_right_aligned() -> void:
	var c := Competition.create_league(GameSettings.team_paths(), 0, false, 3)
	c.complete_round([2, 0], 11)
	hub.open(c)
	assert_eq(hub.views(), ["Tabla", "Fixture"])
	assert_eq(hub.view, 0)
	var focus := get_viewport().gui_get_focus_owner()
	assert_not_null(focus)
	assert_eq(String(focus.name), "Play", "foco inicial en Jugar el partido")
	var labels := hub.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text == "PTS")
	assert_false(labels.is_empty(), "encabezado de la tabla")
	assert_eq((labels[0] as Label).horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)
	assert_eq(hub.user_campaign()["pj"], 1)
	var home: bool = c.rounds[0].any(func(g: Dictionary) -> bool: return g["home"] == 0)
	assert_eq(hub.user_campaign()["form"], ["G"] if home else ["P"], "2-0 es local-visitante")
	assert_string_ends_with(hub.user_status(), "de %d" % c.team_paths.size())


func test_cup_bracket_has_every_round_until_the_final() -> void:
	var c := _cup()
	hub.open(c)
	assert_eq(hub.views(), ["Llaves", "Fixture"])
	var cols := hub.bracket_columns()
	var n := (c.rounds[0] as Array).size()
	assert_eq((cols[0]["games"] as Array).size(), n, "primera ronda con todos los cruces")
	assert_eq(String(cols.back()["name"]), "Final")
	assert_eq((cols.back()["games"] as Array).size(), 1)
	# Las que faltan, por definir.
	assert_true((cols.back()["games"][0] as Dictionary).is_empty())
	assert_eq(hub.user_status(), "En carrera" if c.alive(0) else "Eliminado")


func test_tabs_switch_sections_with_l1_r1() -> void:
	hub.open(_cup())
	var ev := InputEventAction.new()
	ev.action = &"ui_tab_next"
	ev.pressed = true
	hub._unhandled_input(ev)
	assert_eq(hub.view, 1, "R1 / E: siguiente sección (Fixture)")
	hub._unhandled_input(ev)
	assert_eq(hub.view, 0, "vuelve a la primera (circular)")


func test_world_cup_opens_on_groups() -> void:
	var wc: Array[String] = []
	for i in 48:
		wc.append(GameSettings.team_paths()[i % GameSettings.team_paths().size()])
	var c := Competition.create_world_cup(wc, 0, 5)
	hub.open(c)
	assert_eq(hub.views(), ["Grupos", "Llaves", "Fixture"])
	assert_eq(hub.view, 0)
	assert_string_starts_with(hub.user_status(), "Grupo ")
	# Todavía en grupos: los 16avos por definir hasta la final.
	var cols := hub.bracket_columns()
	assert_eq((cols[0]["games"] as Array).size(), 16)
	assert_eq(String(cols.back()["name"]), "Final")


func test_tab_actions_survive_controls_reset() -> void:
	ControlsConfig.reset("user://test_controls_reset.cfg")
	assert_true(InputMap.has_action(&"ui_tab_prev"), "L1 / Q sigue después de volver a fábrica")
	assert_true(InputMap.has_action(&"ui_tab_next"), "R1 / E sigue después de volver a fábrica")
