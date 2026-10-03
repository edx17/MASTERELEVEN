class_name Replay
extends Node
## Repeticiones, como en el WE: graba los últimos segundos de juego (pelota,
## jugadores y sus gestos) y los vuelve a mostrar después de un gol o de una
## jugada peligrosa (remate cerca del palo, atajada al córner, falta
## importante). En pantalla sólo queda el marcador, la marca "REPETICIÓN"
## arriba a la derecha y un cartel simple abajo (quién hizo el gol o la
## jugada). Entra y sale con una cortina; X / Start la saltea.
## Sólo presentación: no toca la simulación.

signal finished

enum Kind { GOAL, CHANCE, FOUL }

## Segundos que se guardan y que se muestran según el tipo de jugada.
const SECONDS := 6.0
const CHANCE_SECONDS := 4.0
const RATE := 60
## El final, en cámara lenta.
const SLOW_FROM := 0.7
const SLOW_SPEED := 0.55
## Duración de la cortina (entra y sale).
const WIPE_TIME := 0.55

var playing := false
var kind: int = Kind.GOAL
var _match: MatchController
var _frames: Array = []
## Gestos pendientes de grabar en el cuadro actual: [jugador, evento, lado].
var _events: Array = []
var _players: Array[Footballer] = []
var _cursor := 0.0
var _first := 0
var _rolling := false
var _team := 0
var _caption := ""
var _ui: CanvasLayer
var _card: PanelContainer
var _card_text: Label
var _tag: Control
var _wipe: Wipe


func setup(m: MatchController) -> void:
	_match = m
	_ui = CanvasLayer.new()
	_ui.layer = 7
	add_child(_ui)
	# Marca de repetición: punto rojo y texto, arriba a la derecha.
	_tag = HBoxContainer.new()
	_tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tag.position += Vector2(-36, 22)
	_tag.add_theme_constant_override("separation", 10)
	_ui.add_child(_tag)
	var dot := Dot.new()
	dot.custom_minimum_size = Vector2(22, 34)
	_tag.add_child(dot)
	_tag.add_child(WEStyle.label("REPETICIÓN", 28, Color.WHITE))
	# Cartel de abajo.
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.82)
	sb.border_color = Color(1.0, 0.85, 0.3, 0.9)
	sb.border_width_top = 3
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_card.add_theme_stylebox_override("panel", sb)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.position.y -= 50
	_ui.add_child(_card)
	_card_text = WEStyle.label("", 26)
	_card.add_child(_card_text)
	_tag.visible = false
	_card.visible = false
	_wipe = Wipe.new()
	_wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_wipe)


## Empieza a seguir a un jugador (también a los que entran después).
func track(p: Footballer) -> void:
	if _players.has(p) or p.visual == null:
		return
	_players.append(p)
	p.visual.played.connect(func(ev: int, side: float) -> void:
		if not playing:
			_events.append([p, ev, side]))


## Graba un cuadro (lo llama el partido en cada paso mientras se juega).
func record() -> void:
	if playing:
		return
	var players := {}
	for p in _match.all_players():
		track(p)
		players[p] = [p.global_position, p.rotation.y, p.velocity, p.state, p.state_timer, p.tripped, p.trip_back]
	var ref := _match.referee
	var ref_state: Array = [ref.global_position, ref.rotation.y, ref.velocity.length()] if ref != null else []
	_frames.append({"ball": _match.ball.global_position, "players": players, "events": _events, "ref": ref_state})
	_events = []
	var cap := int(SECONDS * RATE)
	if _frames.size() > cap:
		_frames = _frames.slice(_frames.size() - cap)


func clear() -> void:
	_frames.clear()
	_events.clear()


func has_frames() -> bool:
	return _frames.size() > RATE


## Arranca la repetición. `team` = el que atacaba (para ubicar la cámara);
## `caption` = el cartel de abajo.
func start(p_kind: int, team: int, caption: String) -> void:
	if not has_frames():
		finished.emit()
		return
	playing = true
	kind = p_kind
	_team = team
	_caption = caption
	var seconds := SECONDS if kind == Kind.GOAL else CHANCE_SECONDS
	_first = maxi(0, _frames.size() - int(seconds * RATE))
	_cursor = float(_first)
	_rolling = false
	# Cortina: cuando tapa la pantalla, aparece la repetición.
	_wipe.run(func() -> void:
		_tag.visible = true
		for p in _match.all_players():
			p.set_presenting(true)
		_apply_frame(_first, 0.0)
		_rolling = true)


func tick(dt: float) -> void:
	_wipe.advance(dt)
	if not playing or not _rolling:
		return
	if _cursor > _first + 15 and (Input.is_action_just_pressed(&"ui_accept") or Input.is_action_just_pressed(&"pause")):
		stop()
		return
	var k := (_cursor - _first) / maxf(_frames.size() - 1 - _first, 1)
	var speed := SLOW_SPEED if k > SLOW_FROM else 1.0
	var prev := int(_cursor)
	_cursor += dt * RATE * speed
	var i := int(_cursor)
	if i >= _frames.size():
		stop()
		return
	for f in range(prev + 1, i + 1):
		for ev in _frames[f]["events"]:
			var p: Footballer = ev[0]
			if is_instance_valid(p) and p.visual != null:
				p.visual.play(ev[1], ev[2])
	_apply_frame(i, dt * speed)
	# El cartel aparece en la segunda mitad.
	_card.visible = k > 0.35 and _caption != ""
	_card_text.text = _caption


## Fuera de la fase de repetición la cortina avanza con el reloj de pantalla
## (al salir termina de destapar mientras se acomoda el saque).
func _process(dt: float) -> void:
	if _match != null and _match.phase != MatchController.Phase.REPLAY:
		_wipe.advance(dt)


func stop() -> void:
	if not playing or not _rolling:
		return
	_rolling = false
	_wipe.run(func() -> void:
		playing = false
		_tag.visible = false
		_card.visible = false
		for p in _match.all_players():
			p.set_presenting(false)
		clear()
		finished.emit())


## Cartel del gol: "GOL   CF  10  F. Acosta   173 cm   29 años".
static func scorer_line(p: Footballer, own_goal: bool) -> String:
	var d := p.base_data if p.base_data != null else p.data
	var code: String = "GK" if p.is_keeper() else TeamSheet.ROLE_CODES[clampi(p.tactical_role, 0, TeamSheet.ROLE_CODES.size() - 1)]
	var line := "%s   %d   %s   %d cm   %d años" % [code, p.number, p.display_name, d.height_cm(), d.get_age()]
	return line + ("   (en contra)" if own_goal else "")


func _apply_frame(i: int, dt: float) -> void:
	var f: Dictionary = _frames[i]
	var players: Dictionary = f["players"]
	for p in players:
		if not is_instance_valid(p):
			continue
		var s: Array = players[p]
		p.visible = true
		p.global_position = s[0]
		p.rotation.y = s[1]
		p.velocity = s[2]
		p.state = s[3]
		p.state_timer = s[4]
		p.tripped = s[5]
		p.trip_back = s[6]
		if dt > 0.0:
			p._update_visual(dt)
	var r: Array = f.get("ref", [])
	if not r.is_empty() and _match.referee != null:
		_match.referee.global_position = r[0]
		_match.referee.rotation.y = r[1]
		if dt > 0.0:
			_match.referee.visual.update(dt, r[2], 8.4, PlayerVisual.Pose.NORMAL, 0.0)
	var ball: Vector3 = f["ball"]
	_match.ball.global_position = ball
	# Cámara: detrás del que ataca, baja y siguiendo la pelota.
	var dir := float(_match.teams[_team].attack_dir)
	var cam_pos := Vector3(ball.x - dir * 11.0, 3.6, ball.z + 7.5)
	_match.camera().set_shot(cam_pos, ball + Vector3(dir * 2.0, 0.3, 0.0), 40.0, 4.0 if dt > 0.0 else 0.0)


## Punto rojo que late (marca de repetición).
class Dot:
	extends Control
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var a := 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 5.0))
		draw_circle(size * 0.5, 9.0, Color(0.95, 0.12, 0.1, a))


## Cortina de transición: una franja con el nombre del juego cruza la
## pantalla; cuando la tapa del todo se llama a `on_cover`.
class Wipe:
	extends Control
	var _t := -1.0
	var _on_cover: Callable
	var _covered := false

	func run(on_cover: Callable) -> void:
		_on_cover = on_cover
		_covered = false
		_t = 0.0
		visible = true

	func advance(dt: float) -> void:
		if _t < 0.0:
			return
		_t += dt
		var half := Replay.WIPE_TIME * 0.5
		if not _covered and _t >= half:
			_covered = true
			if _on_cover.is_valid():
				_on_cover.call()
		if _t >= Replay.WIPE_TIME + 0.12:
			_t = -1.0
			visible = false
		queue_redraw()

	func _draw() -> void:
		if _t < 0.0:
			return
		var w := size.x
		var half := Replay.WIPE_TIME * 0.5
		# Entra de la izquierda, tapa (con una pausa corta) y sale por la derecha.
		var x := 0.0
		if _t < half:
			x = lerpf(-w * 1.3, 0.0, ease(_t / half, 0.5))
		elif _t < half + 0.12:
			x = 0.0
		else:
			x = lerpf(0.0, w * 1.3, ease((_t - half - 0.12) / half, 2.0))
		var skew := w * 0.15
		var band := PackedVector2Array([Vector2(x - skew, 0), Vector2(x + w + skew, 0),
			Vector2(x + w, size.y), Vector2(x - skew * 2.0, size.y)])
		draw_colored_polygon(band, Color(0.1, 0.08, 0.32))
		draw_rect(Rect2(x - skew, size.y * 0.44, w + skew * 2.0, size.y * 0.12), Color(0.42, 0.36, 0.9))
		var font := get_theme_default_font()
		draw_string(font, Vector2(x, size.y * 0.5 + 18), "MASTER ELEVEN", HORIZONTAL_ALIGNMENT_CENTER, w, 52, Color(1.0, 0.88, 0.3))
