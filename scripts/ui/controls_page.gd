class_name ControlsPage
extends Control
## Opciones > Controles: cada acción con su botón del mando (con ícono) y su
## tecla. Elegir una fila y apretar cualquier botón o tecla la cambia (si otra
## acción la usaba, se intercambian). Queda guardado entre partidas.

signal back_pressed

var help: Label
var _rows: Array[Button] = []
var _capturing: StringName = &""
var _capture_wait := 0.0
var _status: ButtonIcons.IconLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WEStyle.px(900), WEStyle.px(560))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", int(WEStyle.px(8)))
	add_child(box)
	var head := MarginContainer.new()
	head.add_theme_constant_override("margin_left", int(WEStyle.px(12)))
	head.custom_minimum_size.y = WEStyle.px(WEStyle.HEADER_ROW_H)
	head.add_child(WEStyle.make_cells(["Acción", "Mando", "Teclado"], COLS, "LLL", true))
	box.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	for a in ControlsConfig.ACTIONS:
		var b := WEStyle.make_row_button(HBoxContainer.new())
		b.pressed.connect(_start_capture.bind(a))
		b.focus_entered.connect(func() -> void:
			if help != null:
				help.text = "{X} cambiar: después apretá el botón del mando o la tecla nueva (Esc cancela).")
		list.add_child(b)
		_rows.append(b)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", int(WEStyle.px(16)))
	box.add_child(bottom)
	var reset := WEStyle.make_action_button("Restaurar", func() -> void:
		ControlsConfig.reset()
		_save()
		refresh())
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(reset)
	var back := WEStyle.make_action_button("Volver", func() -> void: back_pressed.emit())
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(back)
	_status = ButtonIcons.IconLabel.new(WEStyle.font_px(WEStyle.BODY_M), false, WEStyle.TEXT_DIM)
	box.add_child(_status)
	_status.show_text("Mover: stick izquierdo o cruceta (WASD). Stick derecho: comba en la pelota parada y marsellesa.")
	refresh()


## Columnas: acción (se estira), mando y teclado (px de 1080).
const COLS := [0, 220, 220]


## Rearma el texto de cada fila con lo asignado ahora.
func refresh() -> void:
	for i in _rows.size():
		var a: StringName = ControlsConfig.ACTIONS[i]
		var b := _rows[i]
		for c in b.get_children():
			b.remove_child(c)
			c.queue_free()
		var hb := HBoxContainer.new()
		hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = WEStyle.px(12)
		hb.offset_right = -WEStyle.px(12)
		hb.add_theme_constant_override("separation", int(WEStyle.px(12)))
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		var name_l := WEStyle.make_body_label(ControlsConfig.ACTION_NAMES[a], WEStyle.BODY_L)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(name_l)
		var pad := ButtonIcons.IconLabel.new(WEStyle.font_px(WEStyle.BODY_L), false, WEStyle.ACCENT)
		pad.custom_minimum_size = Vector2(WEStyle.px(COLS[1]), 0)
		pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pad.fit_content = true
		hb.add_child(pad)
		pad.show_text("..." if _capturing == a else ControlsConfig.pad_text(a))
		var key := WEStyle.make_body_label("..." if _capturing == a else ControlsConfig.key_text(a), WEStyle.BODY_L, WEStyle.ACCENT)
		key.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
		key.custom_minimum_size = Vector2(WEStyle.px(COLS[2]), 0)
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(key)


func first_row() -> Button:
	return _rows[0]


func is_capturing() -> bool:
	return _capturing != &""


func _start_capture(a: StringName) -> void:
	_capturing = a
	_capture_wait = 0.2 # que el mismo X que eligió la fila no cuente
	_status.show_text("Apretá el botón o la tecla para «%s».   Esc: cancelar" % ControlsConfig.ACTION_NAMES[a])
	refresh()


func _process(dt: float) -> void:
	_capture_wait = maxf(0.0, _capture_wait - dt)


func _input(event: InputEvent) -> void:
	if _capturing == &"" or not visible:
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
	if _capture_wait > 0.0:
		return
	if event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_finish("Sin cambios.")
		return
	if ControlsConfig.is_bindable(event):
		bind(_capturing, event)


## Asigna `event` a `action` y lo guarda (lo usa la captura y los tests).
func bind(action: StringName, event: InputEvent) -> void:
	ControlsConfig.rebind(action, event)
	_save()
	_finish("Listo: «%s» cambiado." % ControlsConfig.ACTION_NAMES[action])


func _finish(msg: String) -> void:
	var idx := ControlsConfig.ACTIONS.find(_capturing)
	_capturing = &""
	_status.show_text(msg)
	refresh()
	if idx >= 0:
		_rows[idx].grab_focus()


func _save() -> void:
	if GameSettings.persist:
		ControlsConfig.save()
