class_name MatchHud
extends CanvasLayer
## HUD del partido: marcador, reloj, barra de potencia, jugador controlado y
## carteles de eventos. Construido por código.

var _match: MatchController
var _score: Label
var _clock: Label
var _banner: Label
var _players: Array[Label] = []
var _bars: Array[ProgressBar] = []
var _hint: Label


func setup(p_match: MatchController) -> void:
	_match = p_match
	layer = 5

	var top := PanelContainer.new()
	top.position = Vector2(20, 16)
	top.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0.6)))
	add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	top.add_child(row)
	var t0 := _match.teams[0]
	var t1 := _match.teams[1]
	row.add_child(_color_chip(t0.color))
	_score = _label("", 26)
	row.add_child(_score)
	row.add_child(_color_chip(t1.color))
	_clock = _label("00:00", 26)
	_clock.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	row.add_child(_clock)

	_banner = _label("", 64)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position.y = 120
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_banner)

	for i in _match.humans.size():
		var box := VBoxContainer.new()
		var right := i == 1
		box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT if right else Control.PRESET_BOTTOM_LEFT)
		box.grow_vertical = Control.GROW_DIRECTION_BEGIN
		box.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
		box.position += Vector2(-20 if right else 20, -20)
		box.custom_minimum_size = Vector2(300, 0)
		add_child(box)
		var lbl := _label("", 22)
		lbl.add_theme_color_override("font_color", Footballer.SLOT_COLORS[i])
		box.add_child(lbl)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(300, 18)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Footballer.SLOT_COLORS[i]
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", _panel_style(Color(0, 0, 0, 0.55)))
		box.add_child(bar)
		_players.append(lbl)
		_bars.append(bar)

	_hint = _label("", 20)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.position.y -= 60
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)


func _process(_dt: float) -> void:
	if _match == null:
		return
	var t0 := _match.teams[0]
	var t1 := _match.teams[1]
	_score.text = "%s  %d - %d  %s" % [t0.short_name, t0.score, t1.score, t1.short_name]
	_clock.text = "%s  %s" % [_match.clock.display(), "1T" if _match.clock.half == 1 else "2T"]
	_banner.text = _match.banner_text
	if _match.phase == MatchController.Phase.FULLTIME:
		_banner.text = "FINAL   %s %d - %d %s" % [t0.short_name, t0.score, t1.score, t1.short_name]
		_hint.text = "Enter / Start para volver al menú"
	else:
		_hint.text = ""
	for i in _match.humans.size():
		var h := _match.humans[i]
		var p := h.controlled
		_players[i].text = "P%d  #%d %s" % [i + 1, p.number, p.display_name] if p != null else "P%d" % (i + 1)
		_bars[i].value = h.power if h.is_charging() else 0.0
		_bars[i].modulate.a = 1.0 if h.is_charging() else 0.35


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


func _color_chip(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.custom_minimum_size = Vector2(14, 28)
	return r


func _panel_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
