class_name PauseMenu
extends CanvasLayer
## Pausa (Esc / Start). También resuelve la salida al menú al final del partido.

var _panel: PanelContainer
var _resume: Button


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)
	_resume = _button(box, "Continuar", _toggle)
	_button(box, "Salir al menú", _exit)
	_panel.visible = false


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _process(_dt: float) -> void:
	var m := get_parent() as MatchController
	if m != null and m.phase == MatchController.Phase.FULLTIME and not _panel.visible:
		if Input.is_action_just_pressed(&"ui_accept") or Input.is_action_just_pressed(&"pause"):
			_exit()
		return
	if Input.is_action_just_pressed(&"pause"):
		_toggle()


func _toggle() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_panel.visible = paused
	if paused:
		_resume.grab_focus()


func _exit() -> void:
	var m := get_parent() as MatchController
	if m != null:
		m.exit_to_menu()
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
