extends GutTest
## Regla 6: indicaciones de control según el último dispositivo usado.

var _saved_events: Array = []


func before_each() -> void:
	InputRouter.set_source(InputRouter.Source.KEYBOARD, true)
	_saved_events = InputMap.action_get_events(&"ui_accept").duplicate()


func after_each() -> void:
	InputMap.action_erase_events(&"ui_accept")
	for e in _saved_events:
		InputMap.action_add_event(&"ui_accept", e)
	InputRouter.set_source(InputRouter.Source.KEYBOARD, true)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func _pad_button(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	return e


func _stick(v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = v
	return e


func _footer_texts(f: WEStyle.HintFooter) -> Array:
	var out: Array = []
	for c in f.get_child(0).get_children():
		if c is HBoxContainer:
			for k in c.get_children():
				out.append("PAD" if k is TextureRect else (k.get_child(0) as Label).text)
	return out


func test_last_used_device_wins_and_is_saved() -> void:
	var seen: Array = []
	var cb := func(s: int) -> void: seen.append(s)
	InputRouter.events().source_changed.connect(cb)
	InputRouter.set_source(InputRouter.Source.GAMEPAD, true)
	assert_eq(GameSettings.input_source, InputRouter.Source.GAMEPAD, "queda como preferencia")
	InputRouter.observe(_key(KEY_ENTER))
	assert_eq(InputRouter.source, InputRouter.Source.GAMEPAD, "margen anti-parpadeo: un cambio enseguida no cuenta")
	InputRouter.set_source(InputRouter.Source.KEYBOARD, true)
	assert_eq(seen, [InputRouter.Source.GAMEPAD, InputRouter.Source.KEYBOARD])
	InputRouter.events().source_changed.disconnect(cb)


func test_saved_preference_is_only_the_initial_value() -> void:
	InputRouter.start(InputRouter.Source.GAMEPAD)
	assert_true(InputRouter.is_gamepad(), "arranca con lo guardado")
	InputRouter.start(-1)
	assert_eq(InputRouter.source == InputRouter.Source.GAMEPAD, not Input.get_connected_joypads().is_empty(),
		"sin preferencia: mando sólo si hay uno conectado")


func test_stick_noise_uses_the_configured_deadzone() -> void:
	var dz := InputRouter.stick_deadzone()
	assert_eq(dz, InputMap.action_get_deadzone(&"move_left"))
	assert_eq(InputRouter.source_of(_stick(dz * 0.9)), -1)
	assert_eq(InputRouter.source_of(_stick(dz + 0.05)), InputRouter.Source.GAMEPAD)
	assert_eq(InputRouter.source_of(_pad_button(JOY_BUTTON_A)), InputRouter.Source.GAMEPAD)
	var echo := _key(KEY_DOWN)
	echo.echo = true
	assert_eq(InputRouter.source_of(echo), -1, "la repetición de una tecla no cuenta")


func test_footer_rebuilds_on_source_and_rebinding() -> void:
	var f := WEStyle.HintFooter.new("01  /  Prueba", [[&"ui_accept", "Aceptar"], [&"ui_cancel", "Volver"]])
	add_child_autofree(f)
	assert_eq(_footer_texts(f), ["ENTER", "ESC"])
	InputRouter.set_source(InputRouter.Source.GAMEPAD, true)
	assert_eq(_footer_texts(f), ["PAD", "PAD"], "se rearma al pasar al mando")
	InputRouter.set_source(InputRouter.Source.KEYBOARD, true)
	# Reasignar Aceptar a la barra espaciadora: la indicación cambia.
	InputMap.action_erase_events(&"ui_accept")
	InputMap.action_add_event(&"ui_accept", _key(KEY_SPACE))
	InputRouter.notify_bindings_changed()
	assert_eq(_footer_texts(f), ["ESPACIO", "ESC"])
	f.set_hints([[&"ui_tabs", "Sección"]])
	assert_eq(_footer_texts(f), ["Q", "E"], "Q y E separadas")
