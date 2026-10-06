extends GutTest
## Menús circulares y desplazamiento con el botón apretado.

var box: VBoxContainer


func before_each() -> void:
	box = VBoxContainer.new()
	box.size = Vector2(300, 400)
	add_child_autofree(box)
	for i in 5:
		var b := Button.new()
		b.text = "Opción %d" % i
		b.custom_minimum_size = Vector2(300, 40)
		box.add_child(b)
	await get_tree().process_frame


func test_wraps_at_both_ends() -> void:
	var first: Button = box.get_child(0)
	var last: Button = box.get_child(4)
	first.grab_focus()
	assert_eq(MenuNav.step(first, -1), last, "arriba de todo, para arriba: el último")
	assert_eq(MenuNav.step(last, 1), first, "abajo de todo, para abajo: el primero")
	assert_eq(MenuNav.step(first, 1), box.get_child(1), "en el medio, normal")


func test_holding_speeds_up() -> void:
	var first: Button = box.get_child(0)
	first.grab_focus()
	var ev := InputEventAction.new()
	ev.action = &"ui_down"
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.action_press(&"ui_down")
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), box.get_child(1), "un paso al apretar")
	# Mantenido 1,2 s: avanza solo varias veces.
	for i in 72:
		MenuNav._process(1.0 / 60.0)
	Input.action_release(&"ui_down")
	var idx := box.get_children().find(get_viewport().gui_get_focus_owner())
	assert_ne(idx, 1, "siguió moviéndose")
	assert_true(MenuNav.handles(first))
	assert_false(MenuNav.handles(LineEdit.new()))
