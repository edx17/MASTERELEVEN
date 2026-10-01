class_name MatchIntro
extends Node
## Presentación previa al partido, al estilo WE:
##   1. Menú previo con el estadio de fondo (la cámara gira alrededor) y los
##      jugadores calentando.
##   2. Calentamiento: un par de tomas cerca de los jugadores.
##   3. Salida por el túnel: dos filas que caminan hasta la mitad de la cancha.
##   4. Formación protocolar frente a la tribuna y saludo: el visitante pasa
##      saludando frente a la fila del local.
##   5. Pantalla con las formaciones de los dos equipos.
## X / Start saltea la etapa (en el menú previo, X elige la opción).
## Sólo presentación: no toca la pelota ni el reloj; al terminar, el partido
## arranca con el saque del medio.

signal finished

enum Step { MENU, WARMUP, TUNNEL, LINEUP, HANDSHAKE, FORMATION, DONE }

## Velocidades (m/s) iguales para todos: así las filas no se desarman.
const WALK := 1.9
## Paso firme de la salida del túnel (la fila tiene que llegar a formarse).
const WALK_IN := 2.3
const JOG := 4.2
## Fila del local en el saludo y carril (1 m adelante) por donde pasa el visitante.
const ROW_Z := 3.0
const LANE_Z := ROW_Z + 1.0
## Momento del corte a la toma lateral (la boca del túnel depende del
## estadio: StadiumBuilder.tunnel_z).
const TUNNEL_CUT := 4.5
## Duración de cada etapa (s); el menú espera al jugador.
const DURATION := {Step.WARMUP: 6.0, Step.TUNNEL: 9.0, Step.LINEUP: 4.0, Step.HANDSHAKE: 12.0, Step.FORMATION: 5.0}

var step: int = Step.MENU
var _t := 0.0
var _match: MatchController
var _cam: MatchCamera
var _targets := {}
## Punto de paso antes del destino (el visitante sale al carril del saludo).
var _via := {}
## Cabeza: [giro buscado, tiempo hasta cambiarlo] por jugador.
var _looks := {}
## Choques de manos ya hechos (visitante, local).
var _fives := {}
var _ui: CanvasLayer
var _menu: VBoxContainer
var _hint: Label
var _formation: Control
var _rng := RandomNumberGenerator.new()


func setup(m: MatchController, cam: MatchCamera) -> void:
	_match = m
	_cam = cam
	_rng.seed = 1234
	_build_ui()
	_enter(Step.MENU)


func is_active() -> bool:
	return step != Step.DONE


## Avanza la presentación (lo llama el partido en lugar de la simulación).
func tick(dt: float) -> void:
	if step == Step.DONE:
		return
	_t += dt
	if step != Step.MENU and _t > 0.3 and (Input.is_action_just_pressed(&"ui_accept") or Input.is_action_just_pressed(&"pause")):
		_enter(step + 1)
		return
	match step:
		Step.MENU:
			# La cámara recorre el estadio por dentro, a la altura de la bandeja
			# baja (de fondo del menú, como en el WE).
			var a := 0.6 + _t * 0.08
			_cam.set_shot(Vector3(cos(a) * 58.0, 16.0, sin(a) * 40.0), Vector3(0, 3, 0), 50.0)
			_warmup_moves()
		Step.WARMUP:
			_warmup_moves()
			if _t > 3.0 and _t - dt <= 3.0:
				_cut_close_on(_match.teams[1].players[_rng.randi_range(5, 10)])
		Step.TUNNEL, Step.HANDSHAKE:
			_walk_to_targets()
			_update_looks(dt)
			if step == Step.HANDSHAKE:
				_high_fives()
			if step == Step.TUNNEL:
				if _t < TUNNEL_CUT:
					# Salen del túnel: cámara en la cancha, mirando la boca.
					_cam.set_shot(Vector3(7.0, 2.0, StadiumBuilder.tunnel_z - 9.0), Vector3(0.0, 1.4, StadiumBuilder.tunnel_z), 38.0)
				else:
					if _t - dt < TUNNEL_CUT:
						_skip_ahead_on_pitch()
					var lead: Footballer = _match.teams[0].players[0]
					_cam.set_shot(lead.flat_pos() + Vector3(-9.0, 3.0, 6.0), lead.flat_pos() + Vector3(2.0, 1.2, -3.0), 35.0, 1.5)
			else:
				var walker := _match.teams[1].players[5]
				_cam.set_shot(walker.flat_pos() + Vector3(2.0, 2.2, 7.5), walker.flat_pos() + Vector3(-2.0, 1.3, 0.0), 35.0, 1.5)
		Step.LINEUP:
			_walk_to_targets()
			_update_looks(dt)
			# Paneo a lo largo de las dos filas, frente a los jugadores.
			var k := clampf(_t / DURATION[Step.LINEUP], 0.0, 1.0)
			var x := lerpf(-16.0, 16.0, k)
			_cam.set_shot(Vector3(x, 1.8, 9.5), Vector3(x * 0.9, 1.4, 2.0), 38.0, 3.0)
	if DURATION.has(step) and _t >= DURATION[step]:
		_enter(step + 1)


func _enter(s: int) -> void:
	step = s
	_t = 0.0
	_menu.visible = s == Step.MENU
	_formation.visible = s == Step.FORMATION
	_hint.visible = s != Step.MENU and s != Step.DONE
	match s:
		Step.MENU:
			_scatter_for_warmup()
			(_menu.get_child(1) as Button).grab_focus()
		Step.WARMUP:
			_cut_wide()
		Step.TUNNEL:
			_line_up_in_tunnel()
			_assign_stances()
		Step.LINEUP:
			_set_lineup_targets()
		Step.HANDSHAKE:
			_set_handshake_targets()
		Step.FORMATION:
			_formation.queue_redraw()
			_cam.set_shot(Vector3(0, 60, 40), Vector3(0, 0, 0), 45.0)
		Step.DONE:
			_ui.visible = false
			for p in _match.all_players():
				p.desired_move = Vector3.ZERO
				p.speed_override = 0.0
				if p.visual is ModelVisual:
					(p.visual as ModelVisual).stance = ModelVisual.Stance.AUTO
					(p.visual as ModelVisual).look_yaw = 0.0
			_cam.end_cinematic()
			finished.emit()


# --- Movimiento de los jugadores ------------------------------------------------

func _scatter_for_warmup() -> void:
	for t in _match.teams:
		for p in t.players:
			var spot := t.to_world(Vector2(_rng.randf_range(0.1, 0.45), _rng.randf_range(-0.8, 0.8)))
			p.teleport(spot, Vector3(t.attack_dir, 0, 0))
			_targets[p] = spot


## Calentamiento: trotan entre puntos de su campo.
func _warmup_moves() -> void:
	for t in _match.teams:
		for p in t.players:
			var tgt: Vector3 = _targets.get(p, p.flat_pos())
			if p.flat_pos().distance_to(tgt) < 1.0:
				tgt = t.to_world(Vector2(_rng.randf_range(0.08, 0.46), _rng.randf_range(-0.85, 0.85)))
				_targets[p] = tgt
			_move(p, tgt, JOG)


func _line_up_in_tunnel() -> void:
	# Dos filas saliendo del túnel (bajo la tribuna de la cámara, en la mitad).
	for i in 2:
		var t := _match.teams[i]
		var side := -1.0 if i == 0 else 1.0
		for n in t.players.size():
			var p: Footballer = t.players[n]
			var pos := Vector3(side * 0.9, 0.0, StadiumBuilder.tunnel_z + 1.0 + n * 1.3)
			p.teleport(pos, Vector3.FORWARD)
			_targets[p] = Vector3(side * (2.0 + n * 1.05), 0.0, ROW_Z)


## Corte de la salida: las filas aparecen ya en la cancha (el trayecto desde
## el túnel es largo), caminando hacia el centro.
func _skip_ahead_on_pitch() -> void:
	for i in 2:
		var t := _match.teams[i]
		var side := -1.0 if i == 0 else 1.0
		for n in t.players.size():
			var p: Footballer = t.players[n]
			p.teleport(Vector3(side * 0.9, 0.0, 7.0 + n * 1.1), Vector3.FORWARD)


func _set_lineup_targets() -> void:
	for p in _targets:
		p.desired_move = Vector3.ZERO


## Saludo protocolar: la fila visitante da un paso al frente y pasa en fila,
## 1 m por delante de la fila local (sin atravesarla), de derecha a izquierda,
## chocando los cinco con cada uno.
func _set_handshake_targets() -> void:
	var away := _match.teams[1]
	_fives.clear()
	for n in away.players.size():
		var p: Footballer = away.players[n]
		_via[p] = Vector3(p.flat_pos().x, 0.0, LANE_Z)
		# El primero de la fila es el que llega más lejos (nadie lo atraviesa).
		_targets[p] = Vector3(-14.0 - (away.players.size() - 1 - n) * 1.05, 0.0, LANE_Z)


## El visitante que pasa frente a un local: los dos levantan la derecha (se
## arranca un poco antes para que las manos se junten justo enfrente).
func _high_fives() -> void:
	for w: Footballer in _match.teams[1].players:
		if _via.has(w) or w.flat_pos().z < LANE_Z - 0.2:
			continue
		for h: Footballer in _match.teams[0].players:
			var dx := w.flat_pos().x - h.flat_pos().x
			if dx > 0.0 and dx < 0.45 and not _fives.has([w, h]):
				_fives[[w, h]] = true
				w.visual.play(PlayerVisual.Event.HIGH_FIVE)
				h.visual.play(PlayerVisual.Event.HIGH_FIVE)


## Cada uno parado a su manera en la formación: brazos al costado, mano en el
## pecho, manos atrás o en la cintura.
func _assign_stances() -> void:
	var pool := [ModelVisual.Stance.RELAXED, ModelVisual.Stance.RELAXED, ModelVisual.Stance.HEART,
			ModelVisual.Stance.BEHIND, ModelVisual.Stance.BEHIND, ModelVisual.Stance.HIPS]
	for p in _match.all_players():
		if p.visual is ModelVisual:
			(p.visual as ModelVisual).stance = pool[_rng.randi() % pool.size()]
		_looks[p] = [0.0, _rng.randf_range(1.0, 4.0)]


## Cabezas que se giran a mirar a los compañeros de al lado y vuelven al
## frente; en el saludo, el local mira al visitante que se acerca.
func _update_looks(dt: float) -> void:
	for p: Footballer in _looks:
		if not p.visual is ModelVisual:
			continue
		var mv := p.visual as ModelVisual
		var look: Array = _looks[p]
		look[1] -= dt
		if look[1] <= 0.0:
			var r := _rng.randf()
			look[0] = 0.0 if r < 0.45 else (0.75 if r < 0.72 else -0.75)
			look[1] = _rng.randf_range(1.2, 3.5)
		var want: float = look[0]
		if step == Step.HANDSHAKE and p.team.index == 0:
			var near := _nearest_walker(p)
			if near != null:
				var off := near.flat_pos() - p.flat_pos()
				want = clampf(atan2(off.x, off.z), -1.1, 1.1)
		mv.look_yaw = lerpf(mv.look_yaw, want, 1.0 - exp(-4.0 * dt))


func _nearest_walker(h: Footballer) -> Footballer:
	var best: Footballer = null
	var best_d := 3.5
	for w: Footballer in _match.teams[1].players:
		var d := w.flat_pos().distance_to(h.flat_pos())
		if d < best_d and w.flat_pos().x > h.flat_pos().x - 0.6:
			best = w
			best_d = d
	return best


func _walk_to_targets() -> void:
	for p: Footballer in _targets:
		var tgt: Vector3 = _via.get(p, _targets[p])
		if _via.has(p) and p.flat_pos().distance_to(tgt) < 0.35:
			_via.erase(p)
			tgt = _targets[p]
		if p.flat_pos().distance_to(tgt) < 0.3:
			p.desired_move = Vector3.ZERO
			# En la fila, mirando a la tribuna principal (la cámara).
			if step != Step.HANDSHAKE or p.team.index == 0:
				p.facing = Vector3.BACK
		else:
			_move(p, tgt, WALK if step == Step.HANDSHAKE else WALK_IN)


## Todos a la misma velocidad (m/s), sin importar sus atributos.
func _move(p: Footballer, tgt: Vector3, speed: float) -> void:
	var d := tgt - p.flat_pos()
	d.y = 0.0
	p.speed_override = speed
	p.desired_move = d.normalized() if d.length() > 0.05 else Vector3.ZERO
	p.wants_sprint = false


# --- Cámara ---------------------------------------------------------------------

func _cut_wide() -> void:
	_cam.set_shot(Vector3(-30.0, 12.0, 45.0), Vector3(-10.0, 0.0, 0.0), 40.0)


func _cut_close_on(p: Footballer) -> void:
	_cam.set_shot(p.flat_pos() + Vector3(3.0, 1.6, 6.0), p.flat_pos() + Vector3(0, 1.2, 0), 32.0)


# --- Interfaz -------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 8
	add_child(_ui)
	# Menú previo al estilo WE: barras violáceas a la izquierda.
	_menu = VBoxContainer.new()
	_menu.position = Vector2(40, 90)
	_menu.add_theme_constant_override("separation", 6)
	_ui.add_child(_menu)
	var title := Label.new()
	title.text = "%s  vs  %s" % [_match.teams[0].team_name, _match.teams[1].team_name]
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	_menu.add_child(title)
	_option("Comenzar el partido", func() -> void: _enter(Step.WARMUP))
	_option("Saltear la presentación", func() -> void: _enter(Step.DONE))
	_option("Salir al menú", func() -> void: _match.exit_to_menu())
	var cond := Label.new()
	cond.text = String(StadiumStyles.current["name"]) + (" · " + _match.conditions.describe() if _match.conditions != null else "")
	cond.add_theme_font_size_override("font_size", 18)
	cond.add_theme_color_override("font_outline_color", Color.BLACK)
	cond.add_theme_constant_override("outline_size", 6)
	_menu.add_child(cond)
	_hint = Label.new()
	_hint.text = "X / Start: saltear"
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position += Vector2(-200, -50)
	_ui.add_child(_hint)
	_formation = FormationBoard.new()
	(_formation as FormationBoard).match_ref = _match
	_formation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_formation)


func _option(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(380, 44)
	b.add_theme_font_size_override("font_size", 22)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.18, 0.45, 0.88)
	style.set_corner_radius_all(2)
	style.content_margin_left = 16
	b.add_theme_stylebox_override("normal", style)
	var focus := style.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.45, 0.38, 0.85, 0.95)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("hover", focus)
	b.pressed.connect(cb)
	_menu.add_child(b)


## Pantalla de formaciones: los dos equipos en una cancha con sus nombres.
class FormationBoard:
	extends Control
	var match_ref: MatchController

	func _draw() -> void:
		if match_ref == null:
			return
		var vp := get_viewport_rect().size
		var field := Rect2(vp.x * 0.1, vp.y * 0.14, vp.x * 0.8, vp.y * 0.72)
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55))
		draw_rect(field, Color(0.12, 0.38, 0.16, 0.95))
		draw_rect(field, Color(1, 1, 1, 0.8), false, 2.0)
		draw_line(Vector2(field.get_center().x, field.position.y), Vector2(field.get_center().x, field.end.y), Color(1, 1, 1, 0.8), 2.0)
		draw_arc(field.get_center(), field.size.y * 0.13, 0, TAU, 40, Color(1, 1, 1, 0.8), 2.0)
		var font := get_theme_default_font()
		for t in match_ref.teams:
			var left := t.index == 0
			draw_string(font, Vector2(field.position.x + (10.0 if left else field.size.x * 0.5 + 10.0), field.position.y - 14.0),
				"%s   %s" % [t.team_name, t.formation.formation_name if t.formation else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
			for p in t.players:
				# base_spot: x 0..1 (arco propio -> rival), y -1..1 (derecha -> izquierda).
				var depth := p.base_spot.x * 0.5
				var px := field.position.x + field.size.x * (depth if left else 1.0 - depth)
				var py := field.get_center().y + (-p.base_spot.y if left else p.base_spot.y) * field.size.y * 0.42
				var c := t.keeper_color if p.is_keeper() else t.color
				draw_circle(Vector2(px, py), 13.0, c)
				draw_arc(Vector2(px, py), 13.0, 0, TAU, 20, Color(0, 0, 0, 0.7), 2.0)
				draw_string(font, Vector2(px - 6.0, py + 6.0), str(p.number), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.BLACK)
				draw_string(font, Vector2(px - 40.0, py + 30.0), p.display_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color.WHITE)
