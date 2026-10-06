class_name MatchHud
extends CanvasLayer
## HUD del partido (rediseño estadio de noche, tokens de WEStyle):
## - arriba al centro: el marcador (rótulo de la competición, escudo, sigla,
##   el resultado sobre dorado, sigla y escudo rival) y debajo el reloj; al
##   haber un gol el resultado se enciende un instante
## - arriba a la derecha: la estrategia de la CPU; a la izquierda, el viento
## - abajo al centro: radar con los 22 jugadores y la pelota
## - abajo a los costados: panel del jugador controlado de cada lado (puesto,
##   nombre, barra de energía) y encima la barra de potencia mientras se carga
## - carteles del partido (FALTA, CÓRNER, GOL...) en Bebas, bajo el marcador.

const POS_NAMES := ["GK", "DF", "MF", "FW"]
const POS_COLORS := [Color(0.8, 0.72, 0.15), Color(0.2, 0.45, 0.8), Color(0.25, 0.62, 0.32), Color(0.78, 0.22, 0.2)]
## Panel del jugador (px de 1080).
const PANEL_W := 400.0
const PANEL_H := 72.0
const PANEL_SIZE := Vector2(PANEL_W * 2.0 / 3.0, PANEL_H * 2.0 / 3.0)

var _match: MatchController
var _score: Label
var _clock: Label
## Marcador (lo único que queda en la repetición).
var _top: Control
var _score_box: PanelContainer
var _last_goals := -1
var _was_replaying := false
## Estrategia activa de cada equipo (arriba a la derecha).
var _strategy: Label
var _banner: Label
var _banner_box: PanelContainer
var _hint: Label
var _radar: Radar
## Paneles inferiores: [0] = equipo local (izquierda), [1] = visitante (derecha).
var _panels: Array[PlayerPanel] = []
## Mentalidad (3 barras) y estrategia, al lado del panel de cada humano.
var _tactics: Array[TacticsBox] = []
var _tactic_labels: Array[Label] = []


## Caja de fondo del HUD: bg_night translúcido, borde de 1 px y radio.
static func hud_style(alpha: float = 0.88, radius: int = WEStyle.RADIUS_BUTTON) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(WEStyle.BG_NIGHT, alpha)
	sb.border_color = WEStyle.LINE
	sb.set_border_width_all(WEStyle.BORDER)
	sb.set_corner_radius_all(int(WEStyle.px(radius)))
	sb.content_margin_left = WEStyle.px(14)
	sb.content_margin_right = WEStyle.px(14)
	sb.content_margin_top = WEStyle.px(4)
	sb.content_margin_bottom = WEStyle.px(4)
	return sb


func setup(p_match: MatchController) -> void:
	_match = p_match
	layer = 5
	var t0 := _match.teams[0]
	var t1 := _match.teams[1]

	# Marcador al centro: rótulo, barra con el resultado y reloj.
	var top := VBoxContainer.new()
	_top = top
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = WEStyle.px(24)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override("separation", 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var label := GameSettings.match_label if GameSettings.match_label != "" else "Amistoso"
	var tag := _tab(WEStyle.make_caption_label(label, WEStyle.ACCENT), 0.82)
	top.add_child(tag)
	var bar := PanelContainer.new()
	var bsb := hud_style(0.9)
	bsb.content_margin_top = WEStyle.px(6)
	bsb.content_margin_bottom = WEStyle.px(6)
	bar.add_theme_stylebox_override("panel", bsb)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(WEStyle.px(14)))
	bar.add_child(row)
	row.add_child(_crest(t0))
	row.add_child(_code(t0))
	_score_box = PanelContainer.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = WEStyle.ACCENT
	ssb.set_corner_radius_all(int(WEStyle.px(WEStyle.RADIUS_BUTTON)))
	ssb.content_margin_left = WEStyle.px(16)
	ssb.content_margin_right = WEStyle.px(16)
	_score_box.add_theme_stylebox_override("panel", ssb)
	_score_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_score_box)
	_score = WEStyle.make_title_label("0 - 0", WEStyle.TITLE_M, WEStyle.BG_NIGHT)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_box.add_child(_score)
	row.add_child(_code(t1))
	row.add_child(_crest(t1))
	_clock = WEStyle.make_body_label("1T  00:00", WEStyle.BODY_L)
	_clock.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_tab(_clock, 0.82))

	# Viento: flecha (en la dirección de pantalla) y velocidad, arriba a la izquierda.
	if _match.conditions != null and _match.conditions.wind_speed >= 0.5:
		var wind := WindIndicator.new()
		wind.wind = _match.conditions.wind_vector()
		wind.position = Vector2(WEStyle.px(WEStyle.MARGIN_X), WEStyle.px(32))
		wind.size = Vector2(WEStyle.px(200), WEStyle.px(44))
		add_child(wind)

	_strategy = WEStyle.make_body_label("", WEStyle.BODY_M, WEStyle.TEXT_MAIN)
	_strategy.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
	_strategy.add_theme_color_override("font_outline_color", Color(WEStyle.BG_NIGHT, 0.85))
	_strategy.add_theme_constant_override("outline_size", 4)
	_strategy.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_strategy.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_strategy.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_strategy.position += Vector2(-WEStyle.px(WEStyle.MARGIN_X), WEStyle.px(32))
	add_child(_strategy)

	# Carteles del partido (FALTA, CÓRNER, GOL...): Bebas grande sobre una
	# caja oscura con una línea dorada abajo.
	_banner_box = PanelContainer.new()
	var nsb := hud_style(0.85)
	nsb.border_color = WEStyle.ACCENT
	nsb.border_width_bottom = WEStyle.FOCUS_BORDER * 2
	nsb.content_margin_left = WEStyle.px(40)
	nsb.content_margin_right = WEStyle.px(40)
	_banner_box.add_theme_stylebox_override("panel", nsb)
	_banner_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner_box.offset_top = WEStyle.px(230)
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner_box)
	_banner = WEStyle.make_title_label("", 84)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_box.add_child(_banner)

	_radar = Radar.new()
	_radar.setup(_match)
	_radar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_radar.custom_minimum_size = Radar.SIZE
	_radar.size = Radar.SIZE
	_radar.position = Vector2(-Radar.SIZE.x * 0.5, -Radar.SIZE.y - WEStyle.px(24))
	add_child(_radar)

	var mx := WEStyle.px(WEStyle.MARGIN_X)
	var by := PANEL_SIZE.y + WEStyle.px(32)
	for side in 2:
		var panel := PlayerPanel.new()
		var right := side == 1
		panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT if right else Control.PRESET_BOTTOM_LEFT)
		panel.size = PANEL_SIZE
		panel.position = Vector2(-PANEL_SIZE.x - mx if right else mx, -by)
		add_child(panel)
		_panels.append(panel)
		# Al lado del panel, hacia el centro de la pantalla.
		var box := TacticsBox.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT if right else Control.PRESET_BOTTOM_LEFT)
		box.size = TacticsBox.SIZE
		var gap := WEStyle.px(12)
		box.position = Vector2(-PANEL_SIZE.x - mx - gap - TacticsBox.SIZE.x if right else mx + PANEL_SIZE.x + gap, -by)
		add_child(box)
		_tactics.append(box)
		var tl := WEStyle.make_caption_label("", WEStyle.ACCENT)
		tl.add_theme_color_override("font_outline_color", Color(WEStyle.BG_NIGHT, 0.85))
		tl.add_theme_constant_override("outline_size", 4)
		tl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT if right else Control.PRESET_BOTTOM_LEFT)
		tl.position = Vector2(-PANEL_SIZE.x - mx if right else mx, -by - WEStyle.px(30))
		tl.size = Vector2(PANEL_SIZE.x, WEStyle.px(24))
		if right:
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(tl)
		_tactic_labels.append(tl)

	_hint = _label("", 18)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.position.y -= Radar.SIZE.y + 30
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	# Se muestra con los íconos de los botones.
	_hint.self_modulate.a = 0.0
	var hm := ButtonIcons.Mirror.new(int(WEStyle.font_px(WEStyle.BODY_L)), true)
	hm.source = _hint
	hm.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hm.custom_minimum_size = Vector2(900, 30)
	hm.position = Vector2(-450, _hint.position.y - 30)
	add_child(hm)


## Pestaña del marcador (rótulo arriba, reloj abajo), centrada.
func _tab(content: Control, alpha: float) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", hud_style(alpha))
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(content)
	return pc


func _crest(team: Team) -> Control:
	var crest := WEStyle.Crest.new()
	crest.team = team.data
	crest.label_font = WEStyle.font(WEStyle.Typeface.TITLE)
	crest.custom_minimum_size = Vector2(WEStyle.px(36), WEStyle.px(40))
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return crest


func _code(team: Team) -> Label:
	var l := WEStyle.make_body_label(team.short_name.to_upper(), WEStyle.BODY_L)
	l.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.custom_minimum_size.x = WEStyle.px(64)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Gol: el resultado se enciende un instante (FADE_TIME).
func _flash_score() -> void:
	_score_box.modulate = Color(1.6, 1.6, 1.6)
	var tw := _score_box.create_tween()
	tw.tween_property(_score_box, "modulate", Color.WHITE, WEStyle.FADE_TIME)


func _process(_dt: float) -> void:
	if _match == null:
		return
	var t0 := _match.teams[0]
	var t1 := _match.teams[1]
	_score.text = "%d - %d" % [t0.score, t1.score]
	var goals := t0.score + t1.score
	if _last_goals >= 0 and goals > _last_goals:
		_flash_score()
	_last_goals = goals
	# En la repetición sólo queda el marcador (la marca y el cartel los pone
	# la repetición).
	if _match.phase == MatchController.Phase.REPLAY:
		for c in get_children():
			if c is CanvasItem:
				(c as CanvasItem).visible = c == _top
		_was_replaying = true
		return
	if _was_replaying:
		_was_replaying = false
		for c in get_children():
			if c is CanvasItem:
				(c as CanvasItem).visible = true
	_clock.text = "%s  %s" % ["1T" if _match.clock.half == 1 else "2T", _match.clock.display()]
	# Pausa > Pantalla: radar y marcador se pueden apagar.
	_radar.visible = GameSettings.show_radar
	_top.visible = GameSettings.show_score
	_clock.get_parent().visible = GameSettings.show_score
	if _match.training != null:
		# Entrenamiento: sin marcador ni reloj (los datos de la práctica los
		# muestra TrainingSession).
		_top.visible = false
	# Arriba a la derecha sólo la estrategia de la CPU; la del humano (y su
	# mentalidad) va al lado del panel de su jugador.
	var lines := []
	for t in _match.teams:
		var human := _human_for_team(t.index) != null
		_tactics[t.index].visible = human and _match.training == null
		_tactics[t.index].mentality = t.mentality
		_tactics[t.index].queue_redraw()
		_tactic_labels[t.index].visible = human
		_tactic_labels[t.index].text = Strategy.NAMES[t.strategy] if t.strategy != Strategy.Kind.NONE else ""
		if t.strategy != Strategy.Kind.NONE and not human:
			lines.append("%s: %s" % [t.short_name, Strategy.NAMES[t.strategy]])
	_strategy.text = "\n".join(lines)
	_banner.text = _match.banner_text.to_upper()
	if _match.phase == MatchController.Phase.FULLTIME:
		_banner.text = "FINAL   %s %d - %d %s" % [t0.short_name, t0.score, t1.score, t1.short_name]
	_banner_box.visible = _banner.text != ""
	if _match.phase == MatchController.Phase.FULLTIME:
		_banner.text = "FINAL   %s %d - %d %s" % [t0.short_name, t0.score, t1.score, t1.short_name]
		_hint.text = "{X} / Start: volver al menú"
	else:
		_hint.text = _match.toast_text
		# Cuenta de los 6 s del arquero (en los últimos 3).
		var left := _match.hands_time_left()
		if left >= 0.0 and left < 3.0 and _hint.text == "":
			_hint.text = "Arquero: %d s ({TRI} la suelta)" % ceili(left)
		var throw_left := _match.throw_in_time_left()
		if throw_left >= 0.0 and throw_left < 3.0 and _hint.text == "":
			var what: String = {MatchRules.Restart.FREE_KICK: "Tiro libre", MatchRules.Restart.CORNER: "Córner",
				MatchRules.Restart.GOAL_KICK: "Saque de arco"}.get(_match.restart_type, "Lateral")
			_hint.text = "%s: %d s" % [what, ceili(throw_left)]
	for side in 2:
		var h := _human_for_team(side)
		var p: Footballer = h.controlled if h != null else _reference_player(_match.teams[side])
		var charging := h != null and h.is_charging()
		_panels[side].show_player(p, h.power if charging else -1.0,
			Footballer.SLOT_COLORS[h.slot] if h != null else Color(0.8, 0.8, 0.8))


func _human_for_team(index: int) -> HumanController:
	for h in _match.humans:
		if h.team.index == index:
			return h
	return null


## Para el equipo de la CPU se muestra el jugador más cercano a la pelota.
func _reference_player(team: Team) -> Footballer:
	var best: Footballer = null
	var best_d := INF
	for p in team.players:
		var d := p.flat_pos().distance_to(_match.ball.flat_pos())
		if d < best_d:
			best_d = d
			best = p
	return best


static func _label(text: String, _size: int) -> Label:
	var l := WEStyle.make_body_label(text, WEStyle.BODY_L)
	l.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
	l.add_theme_color_override("font_outline_color", Color(WEStyle.BG_NIGHT, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	return l


## Panel inferior: [POS] Nombre, barra de energía y barra de potencia encima.
## Mentalidad: cuadrado con tres barras gruesas (rojo ofensiva, verde
## equilibrada, azul defensiva); la activa encendida y las otras apagadas.
class TacticsBox:
	extends Control
	const SIZE := Vector2(48, 48)
	const COLORS := [Color("#D95555"), Color("#3FB96B"), Color(0.3, 0.55, 0.95)]
	var mentality := 0

	func _draw() -> void:
		draw_style_box(MatchHud.hud_style(0.88), Rect2(Vector2.ZERO, SIZE))
		# De arriba hacia abajo: ofensiva (+1), equilibrada (0), defensiva (-1).
		for i in 3:
			var level := 1 - i
			var on := level == mentality
			var c: Color = COLORS[i] if on else Color(COLORS[i], 0.18)
			draw_rect(Rect2(8, 8 + i * 11.5, SIZE.x - 16, 8), c)


class PlayerPanel:
	extends Control

	var _pos: Label
	var _name: Label
	var _stamina: ColorRect
	var _worn: ColorRect
	var _power_bg: ColorRect
	var _power: ColorRect
	var _bar_x := 0.0
	var _bar_w := 0.0

	func _init() -> void:
		var bg := Panel.new()
		bg.add_theme_stylebox_override("panel", MatchHud.hud_style(0.88, WEStyle.RADIUS_CARD))
		bg.size = MatchHud.PANEL_SIZE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		var pad := WEStyle.px(12)
		_pos = WEStyle.make_body_label("", WEStyle.BODY_S, WEStyle.TEXT_MAIN)
		_pos.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
		_pos.position = Vector2(pad, pad)
		_pos.size = Vector2(WEStyle.px(52), WEStyle.px(28))
		_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_pos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_pos)
		_bar_x = pad * 2.0 + WEStyle.px(52)
		_bar_w = MatchHud.PANEL_SIZE.x - _bar_x - pad
		_name = WEStyle.make_body_label("", WEStyle.BODY_L)
		_name.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
		_name.position = Vector2(_bar_x, pad - WEStyle.px(4))
		_name.size = Vector2(_bar_w, WEStyle.px(30))
		_name.clip_text = true
		add_child(_name)
		var stamina_bg := ColorRect.new()
		stamina_bg.color = WEStyle.LINE
		stamina_bg.position = Vector2(_bar_x, MatchHud.PANEL_SIZE.y - pad - WEStyle.px(6))
		stamina_bg.size = Vector2(_bar_w, WEStyle.px(6))
		add_child(stamina_bg)
		_stamina = ColorRect.new()
		_stamina.color = WEStyle.ACCENT_GREEN
		_stamina.position = stamina_bg.position
		_stamina.size = stamina_bg.size
		add_child(_stamina)
		# Lo que se perdió por el cansancio acumulado (ya no se recupera).
		_worn = ColorRect.new()
		_worn.color = Color(WEStyle.DANGER, 0.55)
		_worn.position = stamina_bg.position
		_worn.size = Vector2(0, stamina_bg.size.y)
		add_child(_worn)
		_power_bg = ColorRect.new()
		_power_bg.color = Color(WEStyle.BG_NIGHT, 0.8)
		_power_bg.position = Vector2(0, -WEStyle.px(18))
		_power_bg.size = Vector2(MatchHud.PANEL_SIZE.x * 0.6, WEStyle.px(10))
		add_child(_power_bg)
		_power = ColorRect.new()
		_power.color = WEStyle.ACCENT
		_power.position = _power_bg.position
		_power.size = Vector2(0, _power_bg.size.y)
		add_child(_power)

	## `power` < 0 oculta la barra de potencia.
	func show_player(p: Footballer, power: float, accent: Color) -> void:
		visible = p != null
		if p == null:
			return
		var role := clampi(p.role, 0, 3)
		_pos.text = MatchHud.POS_NAMES[role]
		var sb := StyleBoxFlat.new()
		sb.bg_color = MatchHud.POS_COLORS[role]
		sb.set_corner_radius_all(int(WEStyle.px(WEStyle.RADIUS_BUTTON)))
		_pos.add_theme_stylebox_override("normal", sb)
		_name.text = "%d  %s" % [p.number, p.display_name]
		_name.add_theme_color_override("font_color", accent)
		# Energía; a la derecha, en oscuro, el tope perdido por el desgaste.
		_stamina.size.x = _bar_w * p.stamina_fraction()
		_worn.size.x = _bar_w * clampf(p.wear / 100.0, 0.0, 1.0)
		_worn.position.x = _bar_x + _bar_w - _worn.size.x
		_power_bg.visible = power >= 0.0
		_power.visible = power >= 0.0
		_power.size.x = _power_bg.size.x * clampf(power, 0.0, 1.0)


## Radar de la cancha (vista cenital) con jugadores y pelota.
class Radar:
	extends Control

	const SIZE := Vector2(210, 136)
	var _match: MatchController

	func setup(m: MatchController) -> void:
		_match = m
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		# Si la pelota (o el jugador controlado) pasa por detrás del radar en
		# pantalla, el radar se vuelve casi transparente para no tapar la jugada.
		var target := 1.0
		if _hides_play():
			target = 0.18
		modulate.a = move_toward(modulate.a, target, dt * 5.0)
		queue_redraw()

	func _hides_play() -> bool:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return false
		var rect := get_global_rect().grow(40.0)
		var points: Array[Vector3] = [_match.ball.state.pos]
		for h in _match.humans:
			if h.controlled != null:
				points.append(h.controlled.global_position + Vector3.UP)
		for pt in points:
			if not cam.is_position_behind(pt) and rect.has_point(cam.unproject_position(pt)):
				return true
		return false

	## Radar visible (opacidad actual); lo usan los tests.
	func opacity() -> float:
		return modulate.a

	func _to_radar(pos: Vector3) -> Vector2:
		var x := (pos.x / Pitch.HALF_LENGTH * 0.5 + 0.5) * SIZE.x
		var y := (pos.z / Pitch.HALF_WIDTH * 0.5 + 0.5) * SIZE.y
		return Vector2(x, y)

	func _draw() -> void:
		if _match == null:
			return
		var line := Color(WEStyle.TEXT_MAIN, 0.55)
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(WEStyle.PITCH_DARK, 0.6))
		draw_rect(Rect2(Vector2.ZERO, SIZE), WEStyle.LINE.lightened(0.2), false, 1.0)
		PitchMarkings.draw_2d(self, Rect2(Vector2.ZERO, SIZE), line, 1.0, Pitch.HALF_LENGTH, Pitch.HALF_WIDTH, false)
		for t in _match.teams:
			for p in t.players:
				var r := 3.5 if p.is_human() else 2.8
				draw_circle(_to_radar(p.global_position), r, t.color.lightened(0.15))
				if p.is_human():
					draw_arc(_to_radar(p.global_position), r + 1.5, 0, TAU, 12, Color.WHITE, 1.0)
		draw_circle(_to_radar(_match.ball.state.pos), 3.0, WEStyle.ACCENT)


## Flecha del viento según cómo se ve la cancha desde la cámara actual.
class WindIndicator:
	extends Control
	var wind: Vector3 = Vector3.ZERO

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var cam := get_viewport().get_camera_3d()
		var dir := Vector2(wind.x, wind.z)
		if cam != null:
			var right := cam.global_basis.x
			var down := -cam.global_basis.y
			right.y = 0.0
			down.y = 0.0
			dir = Vector2(wind.dot(right.normalized()), wind.dot(down.normalized()))
		dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
		var c := Vector2(14, 15)
		var col := WEStyle.TEXT_MAIN
		draw_circle(c, 13.0, Color(WEStyle.BG_NIGHT, 0.75))
		var tip := c + dir * 10.0
		draw_line(c - dir * 9.0, tip, col, 2.5, true)
		var side := dir.orthogonal() * 4.5
		draw_colored_polygon(PackedVector2Array([tip + dir * 2.0, tip - dir * 5.0 + side, tip - dir * 5.0 - side]), col)
		draw_string(WEStyle.font(WEStyle.Typeface.SEMIBOLD), Vector2(32, 21), "%d m/s" % roundi(wind.length()),
			HORIZONTAL_ALIGNMENT_LEFT, -1, WEStyle.font_px(WEStyle.BODY_M), col)
