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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := WEStyle.label("CONFIGURAR CONTROLES", 30, Color(1.0, 0.9, 0.35))
	title.position = Vector2(80, 30)
	add_child(title)
	var pc := WEStyle.panel(Vector2(1120, 0))
	pc.position = Vector2(80, 80)
	add_child(pc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	pc.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	for h: Array in [["ACCIÓN", 520], ["MANDO", 200], ["TECLADO", 200]]:
		var l := WEStyle.label(h[0], 18, Color(1.0, 0.9, 0.35))
		l.custom_minimum_size = Vector2(h[1], 0)
		head.add_child(l)
	for a in ControlsConfig.ACTIONS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(1080, 34)
		b.focus_mode = Control.FOCUS_ALL
		WEStyle.style_bar(b)
		b.pressed.connect(_start_capture.bind(a))
		b.focus_entered.connect(func() -> void:
			if help != null:
				help.text = "{X} cambiar: después apretá el botón del mando o la tecla nueva (Esc cancela).")
		box.add_child(b)
		_rows.append(b)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 20)
	box.add_child(bottom)
	var reset := WEStyle.bar("RESTAURAR", func() -> void:
		ControlsConfig.reset()
		_save()
		refresh(), 260.0, 20)
	bottom.add_child(reset)
	var back := WEStyle.bar("VOLVER", func() -> void: back_pressed.emit(), 260.0, 20)
	bottom.add_child(back)
	_status = ButtonIcons.IconLabel.new(18, false, Color(0.85, 0.92, 1.0))
	_status.custom_minimum_size = Vector2(1080, 30)
	box.add_child(_status)
	_status.show_text("Mover: stick izquierdo o cruceta (WASD). Stick derecho: comba en la pelota parada y marsellesa.")
	refresh()


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
		hb.offset_left = 16
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		var name_l := WEStyle.label(ControlsConfig.ACTION_NAMES[a], 19)
		name_l.custom_minimum_size = Vector2(520, 0)
		hb.add_child(name_l)
		var pad := ButtonIcons.IconLabel.new(19, false, Color(0.6, 0.85, 1.0))
		pad.custom_minimum_size = Vector2(200, 0)
		pad.fit_content = true
		hb.add_child(pad)
		pad.show_text("..." if _capturing == a else ControlsConfig.pad_text(a))
		var key := WEStyle.label("..." if _capturing == a else ControlsConfig.key_text(a), 19, Color(0.6, 0.85, 1.0))
		key.custom_minimum_size = Vector2(200, 0)
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
