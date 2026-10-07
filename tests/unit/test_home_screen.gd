extends GutTest
## Menú principal, diseño 01 "Central de partido".

var menu: Control


func before_each() -> void:
	menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	if menu.call("_current") == "title":
		menu.call("leave_title")
	await get_tree().process_frame


func after_each() -> void:
	InputRouter.set_source(InputRouter.Source.KEYBOARD, true)


func _home() -> HomeScreen:
	return menu.get("_home")


func test_side_menu_order_and_initial_focus() -> void:
	var h := _home()
	var names: Array = h.menu_items.map(func(b: Button) -> String: return b.text)
	assert_eq(names, ["Partido amistoso", "Liga Virtual", "Copa", "Editar", "Opciones", "Salir"])
	assert_eq(get_viewport().gui_get_focus_owner(), h.menu_items[0], "foco inicial en el primer ítem")
	assert_almost_eq(h.menu_items[0].custom_minimum_size.y, WEStyle.px(72), 0.01)
	assert_almost_eq(h.menu_items[0].custom_minimum_size.x, WEStyle.px(420), 0.01)


func test_right_enters_content_and_left_returns() -> void:
	var h := _home()
	h.menu_items[2].grab_focus()
	assert_eq(h.menu_items[2].get_node(h.menu_items[2].focus_neighbor_right), h.continue_button)
	h.continue_button.grab_focus()
	var ev := InputEventAction.new()
	ev.action = &"ui_left"
	ev.pressed = true
	h.continue_button.gui_input.emit(ev)
	assert_eq(get_viewport().gui_get_focus_owner(), h.menu_items[2], "vuelve al último ítem del menú")
	# Arriba/abajo en el menú es circular.
	assert_eq(MenuNav.step(h.menu_items[0], -1), h.menu_items[5])


func test_footer_follows_the_input_source() -> void:
	InputRouter.set_source(InputRouter.Source.KEYBOARD, true)
	var kb := ButtonIcons.get_hint(&"ui_accept")
	assert_true(kb.get_child(0) is PanelContainer, "tecla dibujada")
	assert_eq((kb.get_child(0).get_child(0) as Label).text, "ENTER")
	kb.free()
	var pad := ButtonIcons.get_hint(&"ui_accept", 1)
	assert_true(pad.get_child(0) is TextureRect, "botón del mando")
	pad.free()
	assert_eq(ButtonIcons.hint_ids(&"ui_cancel", false), ["ESC"])
	assert_eq(ButtonIcons.hint_ids(&"ui_cancel", true), ["O"])
	assert_eq(ButtonIcons.hint_ids(&"ui_tabs", true), ["L1", "R1"], "L1 y R1 separados")
	assert_eq(ButtonIcons.hint_ids(&"ui_tabs", false), ["Q", "E"])
	# El pie se rearma al cambiar de dispositivo, sin mover el foco.
	var focus := get_viewport().gui_get_focus_owner()
	InputRouter.set_source(InputRouter.Source.GAMEPAD, true)
	assert_eq(get_viewport().gui_get_focus_owner(), focus)
	assert_eq(InputRouter.source_of(_joy_motion(0.1)), -1, "el ruido del stick no cuenta")
	assert_eq(InputRouter.source_of(_joy_motion(0.9)), InputRouter.Source.GAMEPAD)


func _joy_motion(v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_Y
	e.axis_value = v
	return e


## La tarjeta sale de una partida real: el club, el rival de la próxima
## fecha y si es local o visitante (antes era un Boca - River fijo).
func test_featured_match_comes_from_the_save() -> void:
	var m := MasterCareer.create("arg", "colon", "real", 5)
	m.save()
	var info := HomeScreen.match_info(m.file)
	assert_false(info.is_empty())
	assert_eq(info["mode"], "Liga Virtual")
	assert_eq((info["user"] as TeamData).team_name, m.user_team().team_name)
	var g := m.user_match()
	var comp := m.current_comp()
	assert_eq((info["home"] as TeamData).team_name, comp.team(g["home"]).team_name)
	assert_eq((info["away"] as TeamData).team_name, comp.team(g["away"]).team_name)
	assert_eq(info["venue"], "Local" if comp.team_paths[g["home"]] == m.user_path() else "Visitante")
	m.delete_file()
	MasterCareer.deactivate()


func test_without_saves_the_card_says_so() -> void:
	var h := _home()
	h.featured = {}
	h._fill_match()
	h._fill_club()
	var texts: Array = h.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_true(texts.has("SIN PARTIDAS GUARDADAS"))
	assert_false(texts.has("BOCA JUNIORS"), "nada de partidos inventados")
