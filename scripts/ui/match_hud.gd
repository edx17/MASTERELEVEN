class_name MatchHud
extends CanvasLayer
## HUD estilo WE2002:
## - arriba a la izquierda: colores de los equipos y marcador ("0 - 1")
## - arriba a la derecha: tiempo y reloj ("2nd 27:57")
## - abajo al centro: radar con los 22 jugadores y la pelota
## - abajo a los costados: panel del jugador controlado de cada lado (posición,
##   nombre, barra de energía) y encima la barra de potencia mientras se carga.
## Construido por código; sin marcas ni banderas reales.

const POS_NAMES := ["GK", "DF", "MF", "FW"]
const POS_COLORS := [Color(0.95, 0.75, 0.15), Color(0.25, 0.6, 0.95), Color(0.3, 0.8, 0.4), Color(0.9, 0.25, 0.25)]
const PANEL_SIZE := Vector2(250, 44)

var _match: MatchController
var _score: Label
var _clock: Label
## Marcador (lo único que queda en la repetición).
var _top: Control
var _was_replaying := false
## Estrategia activa de cada equipo (debajo del reloj).
var _strategy: Label
var _banner: Label
var _hint: Label
var _radar: Radar
## Paneles inferiores: [0] = equipo local (izquierda), [1] = visitante (derecha).
var _panels: Array[PlayerPanel] = []


func setup(p_match: MatchController) -> void:
	_match = p_match
	layer = 5

	# Marcador.
	var top := HBoxContainer.new()
	_top = top
	top.position = Vector2(24, 18)
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	top.add_child(_flag(_match.teams[0]))
	_score = _label("0 - 0", 30)
	top.add_child(_score)
	top.add_child(_flag(_match.teams[1]))

	# Viento: flecha (en la dirección de pantalla) y velocidad, bajo el marcador.
	if _match.conditions != null and _match.conditions.wind_speed >= 0.5:
		var wind := WindIndicator.new()
		wind.wind = _match.conditions.wind_vector()
		wind.position = Vector2(26, 64)
		wind.size = Vector2(130, 30)
		add_child(wind)

	# Reloj.
	_clock = _label("1st 00:00", 28)
	_clock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_clock.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_clock.position += Vector2(-28, 18)
	_clock.add_theme_font_size_override("font_size", 28)
	add_child(_clock)

	_strategy = _label("", 18)
	_strategy.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_strategy.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_strategy.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_strategy.position += Vector2(-28, 58)
	add_child(_strategy)

	_banner = _label("", 40)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position.y = 110
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_banner)

	_radar = Radar.new()
	_radar.setup(_match)
	_radar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_radar.custom_minimum_size = Radar.SIZE
	_radar.size = Radar.SIZE
	_radar.position = Vector2(-Radar.SIZE.x * 0.5, -Radar.SIZE.y - 14)
	add_child(_radar)

	for side in 2:
		var panel := PlayerPanel.new()
		var right := side == 1
		panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT if right else Control.PRESET_BOTTOM_LEFT)
		panel.size = PANEL_SIZE
		panel.position = Vector2(-PANEL_SIZE.x - 30 if right else 30, -PANEL_SIZE.y - 28)
		add_child(panel)
		_panels.append(panel)

	_hint = _label("", 18)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.position.y -= Radar.SIZE.y + 30
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)


func _process(_dt: float) -> void:
	if _match == null:
		return
	var t0 := _match.teams[0]
	var t1 := _match.teams[1]
	_score.text = "%d - %d" % [t0.score, t1.score]
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
	_clock.text = "%s %s" % ["1st" if _match.clock.half == 1 else "2nd", _match.clock.display()]
	var lines := []
	for t in _match.teams:
		if t.strategy != Strategy.Kind.NONE:
			lines.append("%s: %s" % [t.short_name, Strategy.NAMES[t.strategy]])
	_strategy.text = "\n".join(lines)
	_banner.text = _match.banner_text
	if _match.phase == MatchController.Phase.FULLTIME:
		_banner.text = "FINAL   %s %d - %d %s" % [t0.short_name, t0.score, t1.score, t1.short_name]
		_hint.text = "Enter / Start para volver al menú"
	else:
		_hint.text = _match.toast_text
		# Cuenta de los 6 s del arquero (en los últimos 3).
		var left := _match.hands_time_left()
		if left >= 0.0 and left < 3.0 and _hint.text == "":
			_hint.text = "Arquero: %d s (Triángulo la suelta)" % ceili(left)
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


func _flag(team: Team) -> Control:
	# "Bandera" genérica de club: dos franjas con sus colores.
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	for c in [team.color, team.secondary_color, team.color]:
		var r := ColorRect.new()
		r.color = c
		r.custom_minimum_size = Vector2(12, 26)
		box.add_child(r)
	return box


static func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	return l


## Panel inferior: [POS] Nombre, barra de energía y barra de potencia encima.
class PlayerPanel:
	extends Control

	var _pos_bg: ColorRect
	var _pos: Label
	var _name: Label
	var _stamina: ColorRect
	var _worn: ColorRect
	var _power_bg: ColorRect
	var _power: ColorRect

	func _init() -> void:
		var bg := ColorRect.new()
		bg.color = Color(0.05, 0.06, 0.09, 0.82)
		bg.size = MatchHud.PANEL_SIZE
		add_child(bg)
		_pos_bg = ColorRect.new()
		_pos_bg.position = Vector2(8, 8)
		_pos_bg.size = Vector2(40, 24)
		add_child(_pos_bg)
		_pos = MatchHud._label("", 17)
		_pos.position = Vector2(8, 7)
		_pos.size = Vector2(40, 24)
		_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_pos)
		_name = MatchHud._label("", 20)
		_name.position = Vector2(58, 5)
		add_child(_name)
		var stamina_bg := ColorRect.new()
		stamina_bg.color = Color(0.2, 0.2, 0.22)
		stamina_bg.position = Vector2(58, 34)
		stamina_bg.size = Vector2(180, 5)
		add_child(stamina_bg)
		_stamina = ColorRect.new()
		_stamina.color = Color(0.9, 0.35, 0.45)
		_stamina.position = stamina_bg.position
		_stamina.size = stamina_bg.size
		add_child(_stamina)
		# Lo que se perdió por el cansancio acumulado (ya no se recupera).
		_worn = ColorRect.new()
		_worn.color = Color(0.45, 0.12, 0.15)
		_worn.position = stamina_bg.position
		_worn.size = Vector2(0, 5)
		add_child(_worn)
		_power_bg = ColorRect.new()
		_power_bg.color = Color(0, 0, 0, 0.6)
		_power_bg.position = Vector2(0, -12)
		_power_bg.size = Vector2(MatchHud.PANEL_SIZE.x * 0.6, 8)
		add_child(_power_bg)
		_power = ColorRect.new()
		_power.color = Color(1.0, 0.82, 0.15)
		_power.position = _power_bg.position
		_power.size = Vector2(0, 8)
		add_child(_power)

	## `power` < 0 oculta la barra de potencia.
	func show_player(p: Footballer, power: float, accent: Color) -> void:
		visible = p != null
		if p == null:
			return
		var role := clampi(p.role, 0, 3)
		_pos.text = MatchHud.POS_NAMES[role]
		_pos_bg.color = MatchHud.POS_COLORS[role].darkened(0.2)
		_name.text = "%d  %s" % [p.number, p.display_name]
		_name.add_theme_color_override("font_color", accent)
		# Energía; a la derecha, en oscuro, el tope perdido por el desgaste.
		_stamina.size.x = 180.0 * p.stamina_fraction()
		_worn.size.x = 180.0 * clampf(p.wear / 100.0, 0.0, 1.0)
		_worn.position.x = 58.0 + 180.0 - _worn.size.x
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
		var line := Color(1, 1, 1, 0.75)
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.05, 0.12, 0.07, 0.45))
		draw_rect(Rect2(Vector2.ZERO, SIZE), line, false, 1.5)
		draw_line(Vector2(SIZE.x * 0.5, 0), Vector2(SIZE.x * 0.5, SIZE.y), line, 1.0)
		draw_arc(SIZE * 0.5, Pitch.CENTER_CIRCLE_RADIUS / Pitch.HALF_WIDTH * 0.5 * SIZE.y, 0, TAU, 24, line, 1.0)
		for side in [-1, 1]:
			var a := _to_radar(Vector3(side * Pitch.HALF_LENGTH, 0, -Pitch.PENALTY_AREA_HALF_WIDTH))
			var b := _to_radar(Vector3(side * (Pitch.HALF_LENGTH - Pitch.PENALTY_AREA_DEPTH), 0, Pitch.PENALTY_AREA_HALF_WIDTH))
			draw_rect(Rect2(Vector2(minf(a.x, b.x), a.y), Vector2(absf(b.x - a.x), b.y - a.y)), line, false, 1.0)
		for t in _match.teams:
			for p in t.players:
				var r := 3.5 if p.is_human() else 2.8
				draw_circle(_to_radar(p.global_position), r, t.color.lightened(0.15))
				if p.is_human():
					draw_arc(_to_radar(p.global_position), r + 1.5, 0, TAU, 12, Color.WHITE, 1.0)
		draw_circle(_to_radar(_match.ball.state.pos), 3.0, Color(1.0, 0.2, 0.2))


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
		var col := Color(1, 1, 1, 0.9)
		draw_circle(c, 13.0, Color(0, 0, 0, 0.45))
		var tip := c + dir * 10.0
		draw_line(c - dir * 9.0, tip, col, 2.5, true)
		var side := dir.orthogonal() * 4.5
		draw_colored_polygon(PackedVector2Array([tip + dir * 2.0, tip - dir * 5.0 + side, tip - dir * 5.0 - side]), col)
		draw_string(get_theme_default_font(), Vector2(32, 21), "%d m/s" % roundi(wind.length()),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
