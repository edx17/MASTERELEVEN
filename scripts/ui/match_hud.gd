class_name MatchHud
extends CanvasLayer
## HUD simple estilo WE:
##   AUR  1 - 0  HAL
##        72:34
## más el jugador seleccionado y una barra de potencia chica abajo al centro
## que sólo aparece mientras se carga una acción. Construido por código.

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
	top.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0.55)))
	add_child(top)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	top.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	row.add_child(_color_chip(_match.teams[0].color))
	_score = _label("", 24)
	row.add_child(_score)
	row.add_child(_color_chip(_match.teams[1].color))
	_clock = _label("00:00", 20)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	col.add_child(_clock)

	_banner = _label("", 56)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position.y = 110
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_banner)

	for i in _match.humans.size():
		# Nombre del jugador seleccionado (abajo, a cada lado).
		var right := i == 1
		var lbl := _label("", 18)
		lbl.add_theme_color_override("font_color", Footballer.SLOT_COLORS[i])
		lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT if right else Control.PRESET_BOTTOM_LEFT)
		lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
		lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
		lbl.position += Vector2(-20 if right else 20, -16)
		add_child(lbl)
		_players.append(lbl)
		# Barra de potencia chica, abajo al centro (una por humano).
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(160, 10)
		bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
		bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
		bar.position += Vector2(-90 + i * 180 if _match.humans.size() > 1 else 0, -28)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Footballer.SLOT_COLORS[i]
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", _panel_style(Color(0, 0, 0, 0.5), 3, 0))
		bar.visible = false
		add_child(bar)
		_bars.append(bar)

	_hint = _label("", 18)
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
	_clock.text = _match.clock.display()
	_banner.text = _match.banner_text
	if _match.phase == MatchController.Phase.FULLTIME:
		_banner.text = "FINAL   %s %d - %d %s" % [t0.short_name, t0.score, t1.score, t1.short_name]
		_hint.text = "Enter / Start para volver al menú"
	else:
		_hint.text = ""
	for i in _match.humans.size():
		var h := _match.humans[i]
		var p := h.controlled
		_players[i].text = "P%d  %d %s" % [i + 1, p.number, p.display_name] if p != null else "P%d" % (i + 1)
		_bars[i].visible = h.is_charging()
		_bars[i].value = h.power


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l


func _color_chip(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.custom_minimum_size = Vector2(10, 24)
	return r


func _panel_style(c: Color, radius: int = 6, margin: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.5
	s.content_margin_bottom = margin * 0.5
	return s
