extends Control
## Menú principal mínimo de la Fase 1: elegir modo, duración y jugar.
## Navegable con teclado (flechas + Enter) o mando (cruceta + A/Cruz).

const MATCH_SCENE := "res://scenes/match/match.tscn"

var _duration_btn: Button
var _two_players_btn: Button
var _info: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.2, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "MASTER ELEVEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Fase 1 — Partido amistoso"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	box.add_child(sub)
	box.add_child(Control.new())

	var first := _button(box, "Jugar vs CPU", _start.bind(GameSettings.Mode.VS_CPU))
	_two_players_btn = _button(box, "2 Jugadores", _start.bind(GameSettings.Mode.TWO_PLAYERS))
	_button(box, "CPU vs CPU (demo)", _start.bind(GameSettings.Mode.CPU_VS_CPU))
	_duration_btn = _button(box, "", _cycle_duration)
	_button(box, "Salir", get_tree().quit)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 16)
	_info.modulate = Color(1, 1, 1, 0.75)
	box.add_child(_info)

	_refresh()
	Input.joy_connection_changed.connect(func(_d: int, _c: bool) -> void: _refresh())
	first.grab_focus()


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 52)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _refresh() -> void:
	_duration_btn.text = "Duración: %d min" % GameSettings.match_minutes
	var pads := Input.get_connected_joypads().size()
	_two_players_btn.disabled = not InputRouter.can_play_two_players()
	var pad_text := "Sin mandos conectados (se juega con teclado)" if pads == 0 else "Mandos conectados: %d" % pads
	_info.text = pad_text + "\nMover: WASD / stick   Pase: J / A   Tiro: K / X   Largo: L / B   Hueco: I / Y\nSprint: Shift / RB   Cambiar: Q / LB   Cámara: C / Select   Pausa: Esc / Start"


func _cycle_duration() -> void:
	var opts := GameSettings.DURATION_OPTIONS
	var idx := opts.find(GameSettings.match_minutes)
	GameSettings.match_minutes = opts[(idx + 1) % opts.size()]
	_refresh()


func _start(mode: int) -> void:
	GameSettings.set_mode(mode)
	get_tree().change_scene_to_file(MATCH_SCENE)
