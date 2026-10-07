extends GutTest
## Controles táctiles: tocar ✕ aprieta el botón A del mando (ui_accept) y el
## stick mueve el eje izquierdo (move_*).

var pad: Control


func before_each() -> void:
	var tc = load("res://scripts/ui/touch_controls.gd")
	pad = tc.Pad.new()
	pad.size = Vector2(1280, 720)
	add_child_autofree(pad)
	await get_tree().process_frame


func _touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var t := InputEventScreenTouch.new()
	t.position = pos
	t.pressed = pressed
	t.index = index
	pad._input(t)
	Input.flush_buffered_events()


func test_cross_button_is_the_pad_a_button() -> void:
	var c: Vector2 = pad.button_center(Vector2(250, 150))
	_touch(c, true)
	assert_true(Input.is_action_pressed(&"ui_accept"), "✕ = aceptar")
	_touch(c, false)
	assert_false(Input.is_action_pressed(&"ui_accept"))


func test_stick_moves_the_left_axis() -> void:
	var c: Vector2 = pad.stick_center()
	_touch(c + Vector2(WEStyle.px(170), 0), true, 1)
	assert_gt(Input.get_action_strength(&"move_right"), 0.5, "stick a la derecha")
	_touch(c, false, 1)
	assert_eq(Input.get_action_strength(&"move_right"), 0.0)


func test_touch_outside_the_pad_is_left_for_the_menus() -> void:
	assert_true(pad._hit(Vector2(640, 360)).is_empty(), "el centro de la pantalla no es del mando")


func test_fades_when_idle_and_lights_up_on_touch() -> void:
	var tc = load("res://scripts/ui/touch_controls.gd")
	pad.modulate.a = tc.IDLE_ALPHA
	var c: Vector2 = pad.button_center(Vector2(250, 150))
	_touch(c, true)
	assert_eq(pad.modulate.a, tc.ACTIVE_ALPHA, "al tocar se marca")
	_touch(c, false)
	pad.fade(0.5)
	assert_eq(pad.modulate.a, tc.ACTIVE_ALPHA, "un rato después de soltar sigue marcado")
	for i in 20:
		pad.fade(0.25)
	assert_almost_eq(pad.modulate.a, tc.IDLE_ALPHA, 0.01, "después se apaga")


func test_hidden_outside_the_match_and_releases_buttons() -> void:
	var tc = load("res://scripts/ui/touch_controls.gd").new()
	add_child_autofree(tc)
	assert_false(tc.in_match(), "en los menús no hay mando: se toca la pantalla")
	var c: Vector2 = pad.button_center(Vector2(250, 150))
	_touch(c, true)
	assert_true(Input.is_action_pressed(&"ui_accept"))
	pad.release_all()
	Input.flush_buffered_events()
	assert_false(Input.is_action_pressed(&"ui_accept"), "al ocultarse suelta lo apretado")
