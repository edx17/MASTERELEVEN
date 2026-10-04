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

enum Kind { GOAL, CHANCE, FOUL, OFFSIDE, CELEBRATION }

## Cuánto se muestra antes de la jugada: desde que empezó la acción (cuando
## el equipo ganó la pelota), pero nunca más de PRE_MAX ni menos de PRE_MIN;
## y POST segundos después (la pelota en la red, el rebote, la caída).
const PRE_MAX := 6.0
const PRE_MIN := 3.0
const POST := 3.0
## Compatibilidad (highlights viejos y tests): duración de referencia.
const SECONDS := PRE_MAX
const CHANCE_SECONDS := 4.0
## Festejo repetido: desde que termina la repetición del gol, hasta esto.
const CELEBRATION_SECONDS := 6.0
## Lo que se guarda como máximo (la jugada + el festejo entero).
const BUFFER_SECONDS := 20.0
const RATE := 60
## El final de la jugada, en cámara lenta.
const SLOW_FROM := 0.7
const SLOW_SPEED := 0.55
## Offside: se congela la imagen en el momento del pase.
const OFFSIDE_FREEZE := 1.4
## Duración de la cortina (entra y sale).
const WIPE_TIME := 0.55

var playing := false
## Repetición de un offside: x de la línea (NAN = sin línea). Se dibuja una
## franja a lo ancho de la cancha mientras dura.
var offside_line := NAN
var _line_mesh: MeshInstance3D
var kind: int = Kind.GOAL
var _match: MatchController
var _frames: Array = []
## Gestos pendientes de grabar en el cuadro actual: [jugador, evento, lado].
var _events: Array = []
## Golpe de la pelota en la red en este cuadro ([posición, velocidad]).
var _net_hit: Array = []
var _players: Array[Footballer] = []
## Cuadros grabados en total (índice absoluto del próximo cuadro).
var _count := 0
## Índices absolutos: inicio de la acción (cambio de posesión), última
## patada y la jugada a repetir (gol, falta, offside, remate).
var _action_start := 0
var _kick_frame := -1
var _event_frame := -1
var _holder_team := -1
## Ventana que se está mostrando (índices locales de _frames).
var _cursor := 0.0
var _first := 0
var _last := 0
## Cuadro local de la jugada (el pase del offside, para congelar ahí).
var _event_local := -1
var _freeze_left := 0.0
var _rolling := false
var _team := 0
var _caption := ""
## A quién sigue la cámara en el festejo repetido.
var _focus_player: Footballer = null
## Offside: [punto medio entre el que pasó y el adelantado, distancia de cámara].
var _side_shot := []
var _ui: CanvasLayer
var _card: PanelContainer
var _card_text: Label
var _card_icon: ColorRect
## Tarjeta del cartel: 0 ninguna, 1 amarilla, 2 roja.
var _card_kind := 0
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_card.add_child(row)
	# Tarjeta (amarilla o roja) delante del nombre del amonestado / expulsado.
	_card_icon = ColorRect.new()
	_card_icon.custom_minimum_size = Vector2(20, 28)
	_card_icon.visible = false
	row.add_child(_card_icon)
	_card_text = WEStyle.label("", 26)
	row.add_child(_card_text)
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


## Graba un cuadro (lo llama el partido en cada paso mientras se juega, con
## el juego detenido después de una falta y durante el festejo del gol).
func record() -> void:
	if playing:
		return
	var players := {}
	for p in _match.all_players():
		track(p)
		players[p] = [p.global_position, p.rotation.y, p.velocity, p.state, p.state_timer, p.tripped, p.trip_back]
	var ref := _match.referee
	var ref_state: Array = [ref.global_position, ref.rotation.y, ref.velocity.length()] if ref != null else []
	_frames.append({"ball": _match.ball.global_position, "spin": _match.ball.spin_pose(), "players": players,
		"events": _events, "ref": ref_state, "net": _net_hit})
	_events = []
	_net_hit = []
	# La acción empieza cuando un equipo gana la pelota.
	var owner := _match.ball.owner_player
	if owner != null and owner.team.index != _holder_team:
		_holder_team = owner.team.index
		_action_start = _count
	_count += 1
	var cap := int(BUFFER_SECONDS * RATE)
	if _frames.size() > cap:
		_frames = _frames.slice(_frames.size() - cap)


## Índice absoluto del primer cuadro guardado.
func _base() -> int:
	return _count - _frames.size()


## La pelota pegó en la red (se repite en la repetición).
func mark_net(pos: Vector3, speed: float) -> void:
	if not playing:
		_net_hit = [pos, speed]


## Se patea la pelota (para el offside: la repetición se congela ahí).
func mark_kick() -> void:
	_kick_frame = _count


## La jugada que se va a repetir pasa ahora (gol, falta, pelota afuera). Con
## `at_kick`, la jugada es la última patada (el pase del offside).
func mark_event(at_kick: bool = false) -> void:
	_event_frame = _kick_frame if at_kick and _kick_frame >= 0 else _count


## Dónde estaba `p` en el cuadro de la jugada (el pase del offside).
func position_at_event(p: Footballer) -> Vector3:
	if _frames.is_empty() or p == null:
		return Vector3.INF
	var i := clampi(_event_frame - _base(), 0, _frames.size() - 1) if _event_frame >= 0 else _frames.size() - 1
	var s: Array = (_frames[i]["players"] as Dictionary).get(p, [])
	return s[0] if not s.is_empty() else Vector3.INF


## Segundos grabados desde la jugada (para esperar los POST antes de mostrar).
func seconds_after_event() -> float:
	if _event_frame < 0:
		return INF
	return float(_count - _event_frame) / RATE


func clear() -> void:
	_frames.clear()
	_events.clear()
	_event_frame = -1
	_kick_frame = -1


func has_frames() -> bool:
	return _frames.size() > RATE


## [primero, último, jugada] en índices locales para mostrar la jugada.
func window() -> Array:
	var n := _frames.size()
	if n == 0:
		return [0, -1, -1]
	var base := _base()
	var ev := _event_frame - base if _event_frame >= 0 else n - 1
	ev = clampi(ev, 0, n - 1)
	var pre := clampf(float(_event_frame - _action_start) / RATE if _event_frame >= 0 else PRE_MAX, PRE_MIN, PRE_MAX)
	var first := maxi(0, ev - int(pre * RATE))
	var last := mini(n - 1, ev + int(POST * RATE))
	return [first, last, ev]


## Copia de la jugada que se va a mostrar (para los highlights del
## entretiempo y del final y para encadenar el festejo):
## {"frames", "kind", "team", "caption", "event", ...extra}.
func snapshot(p_kind: int, team: int, caption: String, extra: Dictionary = {}) -> Dictionary:
	var w := window()
	var clip := {"frames": _frames.slice(w[0], w[1] + 1), "kind": p_kind, "team": team, "caption": caption,
		"event": w[2] - w[0]}
	clip.merge(extra)
	return clip


## El festejo del gol, para mostrarlo otra vez desde otro ángulo (después de
## la repetición del gol). Vacío si no hay suficiente grabado.
func celebration_snapshot(scorer: Footballer, team: int, caption: String) -> Dictionary:
	var w := window()
	var from: int = w[1]
	var to := mini(_frames.size() - 1, from + int(CELEBRATION_SECONDS * RATE))
	if scorer == null or to - from < RATE * 2:
		return {}
	return {"frames": _frames.slice(from, to + 1), "kind": Kind.CELEBRATION, "team": team,
		"caption": caption, "event": -1, "focus": scorer}


## Muestra una jugada guardada (highlight o festejo) con la misma cortina.
func play_clip(clip: Dictionary) -> void:
	_frames = (clip["frames"] as Array).duplicate()
	_event_frame = -1
	_begin(clip["kind"], clip["team"], clip["caption"], 0, _frames.size() - 1, clip.get("event", -1), clip)


## Arranca la repetición de lo que se acaba de grabar. `team` = el que
## atacaba (para ubicar la cámara); `caption` = el cartel de abajo.
func start(p_kind: int, team: int, caption: String, extra: Dictionary = {}) -> void:
	var w := window()
	_begin(p_kind, team, caption, w[0], w[1], w[2], extra)


func _begin(p_kind: int, team: int, caption: String, first: int, last: int, event: int, extra: Dictionary) -> void:
	if last - first < RATE:
		finished.emit()
		return
	playing = true
	kind = p_kind
	_team = team
	_caption = caption
	_first = first
	_last = last
	_event_local = event
	_freeze_left = OFFSIDE_FREEZE if kind == Kind.OFFSIDE and event >= 0 else 0.0
	_focus_player = extra.get("focus")
	_card_kind = int(extra.get("card", 0))
	_side_shot = _offside_shot(extra) if kind == Kind.OFFSIDE else []
	if extra.has("line"):
		offside_line = extra["line"]
	_cursor = float(_first)
	_rolling = false
	# Cortina: cuando tapa la pantalla, aparece la repetición.
	_swoosh()
	_wipe.run(func() -> void:
		_tag.visible = true
		_show_line(kind == Kind.OFFSIDE and is_finite(offside_line))
		for p in _match.all_players():
			p.set_presenting(true)
		_apply_frame(float(_first), 0.0, true)
		_rolling = true)


## Toma lateral del offside: desde la banda, lejos, de frente a la línea,
## para ver al que da el pase y al adelantado en el momento del pase.
func _offside_shot(extra: Dictionary) -> Array:
	var a: Vector3 = extra.get("passer_pos", Vector3.INF)
	var b: Vector3 = extra.get("offender_pos", Vector3.INF)
	if a == Vector3.INF or b == Vector3.INF:
		if is_finite(offside_line):
			a = Vector3(offside_line - 10.0, 0, 0)
			b = Vector3(offside_line + 2.0, 0, 0)
		else:
			return []
	var mid := (a + b) * 0.5
	if is_finite(offside_line):
		mid.x = (mid.x + offside_line) * 0.5
	var span := maxf(absf(a.x - b.x), absf(a.z - b.z) * 0.6) + 12.0
	return [Vector3(mid.x, 0.0, clampf(mid.z, -12.0, 12.0)), clampf(span * 1.45, 32.0, 75.0)]


func tick(dt: float) -> void:
	_wipe.advance(dt)
	if not playing or not _rolling:
		return
	if _cursor > _first + 15 and (Input.is_action_just_pressed(&"ui_accept") or Input.is_action_just_pressed(&"pause")):
		stop()
		return
	var k := (_cursor - _first) / maxf(_last - _first, 1)
	var speed := SLOW_SPEED if k > SLOW_FROM and kind != Kind.CELEBRATION else 1.0
	# Offside: llega al pase y se congela un momento con la línea.
	if _freeze_left > 0.0 and _cursor >= _event_local:
		_cursor = float(_event_local)
		_freeze_left -= dt
		_apply_frame(_cursor, 0.0)
		# Todos quietos en ese instante (antes seguían con el gesto de correr).
		for p in _match.all_players():
			if p.visual != null:
				p.visual.freeze_pose()
		if _match.referee != null and _match.referee.visual != null:
			_match.referee.visual.freeze_pose()
		_update_card(k)
		return
	var prev := int(_cursor)
	_cursor += dt * RATE * speed
	if _cursor >= _last:
		stop()
		return
	var i := int(_cursor)
	for f in range(prev + 1, i + 1):
		for ev in _frames[f]["events"]:
			var p: Footballer = ev[0]
			if is_instance_valid(p) and p.visual != null:
				p.visual.play(ev[1], ev[2])
		var net: Array = _frames[f].get("net", [])
		if not net.is_empty():
			_match.hit_net_at(net[0], net[1])
	_apply_frame(_cursor, dt * speed)
	_update_card(k)


func _update_card(k: float) -> void:
	# El cartel aparece en la segunda mitad (en el offside, ya en el pase).
	var show_from := 0.0 if kind == Kind.OFFSIDE else 0.35
	_card.visible = k > show_from and _caption != ""
	_card_text.text = _caption
	_card_icon.visible = _card_kind > 0
	_card_icon.color = Color(1.0, 0.86, 0.1) if _card_kind == 1 else Color(0.9, 0.08, 0.08)


## Fuera de la fase de repetición la cortina avanza con el reloj de pantalla
## (al salir termina de destapar mientras se acomoda el saque).
func _process(dt: float) -> void:
	if _match != null and _match.phase != MatchController.Phase.REPLAY:
		_wipe.advance(dt)


func stop() -> void:
	if not playing or not _rolling:
		return
	_rolling = false
	_swoosh()
	_wipe.run(func() -> void:
		playing = false
		_tag.visible = false
		_card.visible = false
		_show_line(false)
		offside_line = NAN
		_focus_player = null
		for p in _match.all_players():
			p.set_presenting(false)
		clear()
		finished.emit())


## Línea del offside sobre el césped (franja amarilla a lo ancho).
func _show_line(on: bool) -> void:
	if not on:
		if _line_mesh != null:
			_line_mesh.visible = false
		return
	if _line_mesh == null:
		_line_mesh = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.14, Pitch.HALF_WIDTH * 2.0)
		_line_mesh.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.1, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_line_mesh.material_override = mat
		_line_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_match.add_child(_line_mesh)
	_line_mesh.position = Vector3(offside_line, 0.03, 0.0)
	_line_mesh.visible = true


## Cartel del gol: "GOL   CF  10  F. Acosta   173 cm   29 años".
## Cartel de las repeticiones: sólo número y nombre ("10   F. Acosta").
static func player_line(p: Footballer) -> String:
	return "" if p == null else "%d   %s" % [p.number, p.display_name]


static func scorer_line(p: Footballer, own_goal: bool) -> String:
	var d := p.base_data if p.base_data != null else p.data
	var code: String = "GK" if p.is_keeper() else TeamSheet.ROLE_CODES[clampi(p.tactical_role, 0, TeamSheet.ROLE_CODES.size() - 1)]
	var line := "%s   %d   %s   %d cm   %d años" % [code, p.number, p.display_name, d.height_cm(), d.get_age()]
	return line + ("   (en contra)" if own_goal else "")


## Pone la escena en el instante `t` (cuadro con fracción): interpola entre
## dos cuadros grabados, así la cámara lenta y la velocidad de pantalla no
## dan tirones.
func _apply_frame(t: float, dt: float, cut: bool = false) -> void:
	var i := clampi(int(t), 0, _frames.size() - 1)
	var j := mini(i + 1, _frames.size() - 1)
	var w := clampf(t - i, 0.0, 1.0)
	var f: Dictionary = _frames[i]
	var g: Dictionary = _frames[j]
	var players: Dictionary = f["players"]
	var next_players: Dictionary = g["players"]
	for p in players:
		if not is_instance_valid(p):
			continue
		var s: Array = players[p]
		var n: Array = next_players.get(p, s)
		p.visible = true
		p.global_position = (s[0] as Vector3).lerp(n[0], w)
		p.rotation.y = lerp_angle(s[1], n[1], w)
		p.velocity = (s[2] as Vector3).lerp(n[2], w)
		p.state = s[3]
		p.state_timer = lerpf(s[4], n[4], w)
		p.tripped = s[5]
		p.trip_back = s[6]
		if dt > 0.0:
			p._update_visual(dt)
	var r: Array = f.get("ref", [])
	var r2: Array = g.get("ref", r)
	if not r.is_empty() and _match.referee != null:
		_match.referee.global_position = (r[0] as Vector3).lerp(r2[0], w)
		_match.referee.rotation.y = lerp_angle(r[1], r2[1], w)
		if dt > 0.0:
			_match.referee.visual.update(dt, r[2], 8.4, PlayerVisual.Pose.NORMAL, 0.0)
	var ball: Vector3 = (f["ball"] as Vector3).lerp(g["ball"], w)
	var spin: Quaternion = (f.get("spin", Quaternion.IDENTITY) as Quaternion).slerp(g.get("spin", Quaternion.IDENTITY), w)
	_match.ball.replay_pose(ball, spin)
	_aim_camera(ball, 0.0 if cut else 4.0)


func _aim_camera(ball: Vector3, speed: float) -> void:
	var cam := _match.camera()
	if cam == null:
		return
	# Festejo: de frente al goleador, plano medio, siguiéndolo.
	if kind == Kind.CELEBRATION and is_instance_valid(_focus_player):
		var fp := _focus_player.global_position
		var to_field := Vector3(-fp.x, 0.0, -fp.z).normalized()
		var cam_pos := fp + to_field.rotated(Vector3.UP, 0.5) * 6.5 + Vector3(0, 1.9, 0)
		cam.set_shot(cam_pos, fp + Vector3(0, 1.2, 0), 34.0, speed)
		return
	# Offside: desde la banda, lejos, fija sobre el momento del pase.
	if kind == Kind.OFFSIDE and not _side_shot.is_empty():
		var mid: Vector3 = _side_shot[0]
		var d: float = _side_shot[1]
		cam.set_shot(Vector3(mid.x, d * 0.42, mid.z + d), mid + Vector3(0, 0.5, 0), 38.0, speed)
		return
	# Cámara: detrás del que ataca, baja y siguiendo la pelota.
	var dir := float(_match.teams[_team].attack_dir)
	var cam_pos2 := Vector3(ball.x - dir * 11.0, 3.6, ball.z + 7.5)
	cam.set_shot(cam_pos2, ball + Vector3(dir * 2.0, 0.3, 0.0), 40.0, speed)


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


## "Swoosh" de la cortina.
func _swoosh() -> void:
	if _match != null and _match.audio != null:
		_match.audio.play("swoosh", 0.8, randf_range(0.95, 1.05))
