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
	MenuNav.source = MenuNav.Source.KEYBOARD


func _home() -> HomeScreen:
	return menu.get("_home")


func test_side_menu_order_and_initial_focus() -> void:
	var h := _home()
	var names: Array = h.menu_items.map(func(b: Button) -> String: return b.text)
	assert_eq(names, ["Partido amistoso", "Liga Master", "Copa", "Editar", "Opciones", "Salir"])
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
	MenuNav.source = MenuNav.Source.KEYBOARD
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
	MenuNav.source = MenuNav.Source.GAMEPAD
	MenuNav.input_source_changed.emit(MenuNav.source)
	assert_eq(get_viewport().gui_get_focus_owner(), focus)
	assert_eq(MenuNav.source_of(_joy_motion(0.2)), -1, "el ruido del stick no cuenta")
	assert_eq(MenuNav.source_of(_joy_motion(0.9)), MenuNav.Source.GAMEPAD)


func _joy_motion(v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_Y
	e.axis_value = v
	return e
