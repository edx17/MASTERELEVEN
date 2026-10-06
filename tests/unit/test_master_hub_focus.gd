extends GutTest
## Liga Master: después de cambiar de sección con L1 / R1 se vuelve a Jugar /
## Simular (antes el foco quedaba trabado en las filas del centro).

var hub: MasterHub


func before_each() -> void:
	hub = MasterHub.new()
	add_child_autofree(hub)
	hub.open(MasterCareer.create("arg", "colon", "real", 5))
	await get_tree().process_frame


func after_each() -> void:
	MasterCareer.deactivate()


func test_tab_switch_returns_focus_to_play() -> void:
	var div := hub.find_child("DivRow", true, false) as Control
	assert_not_null(div)
	div.grab_focus()
	var ev := InputEventAction.new()
	ev.action = &"ui_tab_next"
	ev.pressed = true
	hub._unhandled_input(ev)
	await get_tree().process_frame
	var owner := get_viewport().gui_get_focus_owner()
	assert_not_null(owner)
	assert_eq(String(owner.name), "Play", "vuelve a Jugar el partido")


func test_center_rows_lead_back_to_the_left_column() -> void:
	await get_tree().process_frame
	var div := hub.find_child("DivRow", true, false) as Control
	assert_ne(div.focus_neighbor_top, NodePath(""), "arriba desde División vuelve a la izquierda")
	assert_eq(div.get_node(div.focus_neighbor_top).name, "Play")
	var cal := hub.find_child("CalendarLink", true, false) as Control
	assert_eq(cal.get_node(cal.focus_neighbor_left).name, "Play")
