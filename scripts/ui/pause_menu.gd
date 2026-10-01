class_name PauseMenu
extends CanvasLayer
## Pausa (Esc / Start). También resuelve la salida al menú al final del partido.

var _panel: PanelContainer
var _resume: Button
var _formation_btn: Button
var _difficulty_btn: Button
var _stick_btn: Button
var _speed_btn: Button
var _keeper_btn: Button
var _label_btn: Button


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
	_formation_btn = _button(box, "", _cycle_formation)
	_difficulty_btn = _button(box, "", _cycle_difficulty)
	_stick_btn = _button(box, "", _cycle_stick)
	_speed_btn = _button(box, "", _cycle_speed)
	_keeper_btn = _button(box, "", _cycle_keeper)
	_label_btn = _button(box, "", _cycle_label)
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
	# Durante la presentación, Start la saltea (no pausa).
	if m != null and m.phase == MatchController.Phase.INTRO:
		return
	if Input.is_action_just_pressed(&"pause"):
		_toggle()


func _toggle() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_panel.visible = paused
	if paused:
		_refresh()
		_resume.grab_focus()


## Equipo del jugador 1 (el que cambia de formación desde la pausa).
func _my_team_index() -> int:
	var m := get_parent() as MatchController
	if m != null and not m.humans.is_empty():
		return m.humans[0].team.index
	return 0


func _refresh() -> void:
	GameSettings.save_settings()
	var m := get_parent() as MatchController
	if m == null:
		return
	var t := m.teams[_my_team_index()]
	_formation_btn.text = "Formación (%s): %s" % [t.short_name, t.formation.formation_name if t.formation else "-"]
	_difficulty_btn.text = "Dificultad CPU: %s" % Difficulty.NAMES[GameSettings.difficulty]
	_speed_btn.text = "Velocidad del juego: %+d" % GameSettings.game_speed
	_keeper_btn.text = "Arquero a los 6 s: %s" % GameSettings.KEEPER_AUTO_NAMES[GameSettings.keeper_auto_action]
	_label_btn.text = "Sobre los jugadores: %s" % GameSettings.PLAYER_LABEL_NAMES[GameSettings.player_label]
	var dirs := GameSettings.stick_directions
	_stick_btn.text = "Movimiento: %s" % ("%d direcciones" % dirs if dirs > 0 else "libre")


func _cycle_formation() -> void:
	var m := get_parent() as MatchController
	if m == null:
		return
	var all := FormationLibrary.load_all()
	var t := m.teams[_my_team_index()]
	var idx := 0
	for i in all.size():
		if t.formation != null and all[i].formation_name == t.formation.formation_name:
			idx = i
	m.set_formation(t.index, all[(idx + 1) % all.size()])
	_refresh()


func _cycle_difficulty() -> void:
	var m := get_parent() as MatchController
	GameSettings.difficulty = (GameSettings.difficulty + 1) % Difficulty.NAMES.size()
	if m != null:
		m.apply_difficulty(GameSettings.difficulty)
	_refresh()


## Velocidad -2 .. +2 (se aplica al volver al partido).
func _cycle_speed() -> void:
	GameSettings.game_speed = GameSettings.game_speed + 1 if GameSettings.game_speed < 2 else -2
	Engine.time_scale = GameSettings.game_time_scale()
	_refresh()


func _cycle_label() -> void:
	GameSettings.player_label = (GameSettings.player_label + 1) % GameSettings.PLAYER_LABEL_NAMES.size()
	var m := get_parent() as MatchController
	if m != null:
		for p in m.all_players():
			p.refresh_label()
	_refresh()


func _cycle_keeper() -> void:
	GameSettings.keeper_auto_action = 1 - GameSettings.keeper_auto_action
	_refresh()


## Rumbos del stick: 8 -> 16 -> libre.
func _cycle_stick() -> void:
	var opts := GameSettings.STICK_OPTIONS
	var i := opts.find(GameSettings.stick_directions)
	GameSettings.stick_directions = opts[(i + 1) % opts.size()]
	_refresh()


func _exit() -> void:
	var m := get_parent() as MatchController
	if m != null:
		m.exit_to_menu()
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
