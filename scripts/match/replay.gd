class_name Replay
extends Node
## Repetición del gol, como en el WE: graba los últimos segundos de juego
## (pelota y jugadores, más sus gestos) y después del festejo los vuelve a
## mostrar con una cámara que sigue la pelota, el cartel "REPETICIÓN" y la
## ficha del goleador abajo (puesto, número, nombre, altura y edad).
## X / Start la saltea. Sólo presentación: no toca la simulación.

signal finished

## Segundos que se guardan y que se muestran.
const SECONDS := 6.0
const RATE := 60
## Velocidad de la repetición (un poco en cámara lenta al final).
const SLOW_FROM := 0.7
const SLOW_SPEED := 0.55

var playing := false
var _match: MatchController
var _frames: Array = []
## Gestos pendientes de grabar en el cuadro actual: [jugador, evento, lado].
var _events: Array = []
var _players: Array[Footballer] = []
var _cursor := 0.0
var _start := 0
var _scorer: Footballer
var _scoring_team := 0
var _ui: CanvasLayer
var _card: PanelContainer
var _card_text: Label
var _tag: Label


func setup(m: MatchController) -> void:
	_match = m
	_ui = CanvasLayer.new()
	_ui.layer = 6
	add_child(_ui)
	_tag = WEStyle.label("REPETICIÓN", 30, Color(1.0, 0.9, 0.35))
	_tag.position = Vector2(40, 90)
	_ui.add_child(_tag)
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.85)
	sb.border_color = Color(0.7, 0.75, 0.85, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_card.add_theme_stylebox_override("panel", sb)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.position.y -= 150
	_ui.add_child(_card)
	_card_text = WEStyle.label("", 26)
	_card.add_child(_card_text)
	_ui.visible = false


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
		players[p] = [p.global_position, p.rotation.y, p.velocity, p.state, p.state_timer, p.tripped]
	_frames.append({"ball": _match.ball.global_position, "players": players, "events": _events})
	_events = []
	var cap := int(SECONDS * RATE)
	if _frames.size() > cap:
		_frames = _frames.slice(_frames.size() - cap)


func clear() -> void:
	_frames.clear()
	_events.clear()


func has_frames() -> bool:
	return _frames.size() > RATE


## Arranca la repetición del gol de `team` (`scorer` puede ser null).
func start(team: int, scorer: Footballer) -> void:
	if not has_frames():
		finished.emit()
		return
	playing = true
	_scoring_team = team
	_scorer = scorer
	_start = 0
	_cursor = 0.0
	_ui.visible = true
	_card.visible = false
	for p in _match.all_players():
		p.set_presenting(true)
	_apply_frame(0, 0.0)


func tick(dt: float) -> void:
	if not playing:
		return
	if _cursor > 0.3 and (Input.is_action_just_pressed(&"ui_accept") or Input.is_action_just_pressed(&"pause")):
		stop()
		return
	var k := _cursor / maxf(_frames.size() - 1, 1)
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
	# La ficha del goleador en la segunda mitad de la repetición.
	_card.visible = k > 0.45 and _scorer != null
	if _card.visible and _card_text.text == "":
		_card_text.text = scorer_line(_scorer, _scorer.team.index != _scoring_team)


func stop() -> void:
	if not playing:
		return
	playing = false
	_ui.visible = false
	_card_text.text = ""
	for p in _match.all_players():
		p.set_presenting(false)
	clear()
	finished.emit()


## Texto de la ficha: "MF  3  Nombre  178 cm  23 años".
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
		if dt > 0.0:
			p._update_visual(dt)
	var ball: Vector3 = f["ball"]
	_match.ball.global_position = ball
	# Cámara: detrás del que ataca, baja y siguiendo la pelota.
	var dir := float(_match.teams[_scoring_team].attack_dir)
	var cam_pos := Vector3(ball.x - dir * 11.0, 3.6, ball.z + 7.5)
	_match.camera().set_shot(cam_pos, ball + Vector3(dir * 2.0, 0.3, 0.0), 40.0, 4.0 if i > 0 else 0.0)
