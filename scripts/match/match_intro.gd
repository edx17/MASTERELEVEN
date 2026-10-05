class_name MatchIntro
extends Node
## Presentación previa al partido, al estilo WE:
##   1. Menú previo con el estadio de fondo (la cámara gira alrededor) y los
##      jugadores calentando: rondos 4 contra 1 en cada mitad y los arqueros
##      en su área atajando remates.
##   2. Calentamiento: un par de tomas cerca de los jugadores.
##   3. Salida por el túnel: dos filas que caminan hasta la mitad de la cancha.
##   4. Formación protocolar frente a la tribuna (cada equipo en su fila; nadie
##      pasa por delante del otro).
##   5. Presentación: la cámara recorre de frente a los 11 de cada equipo y el
##      locutor los nombra uno por uno (señal `player_announced`).
##   6. Foto del equipo (el del jugador 1): dos filas y el flash.
##   7. Pantalla con las formaciones de los dos equipos.
## Arriba, el cartel con los dos equipos y el recuadro "EN VIVO" con el
## estadio y el clima; en la formación protocolar, la bandera gigante.
## X / Start saltea la etapa (en el menú previo, X elige la opción).
## Sólo presentación: no toca la pelota ni el reloj; al terminar, el partido
## arranca con el saque del medio.

signal finished
## La cámara de la presentación llega a `player` (el locutor lo nombra).
signal player_announced(player: Footballer)

enum Step { MENU, WARMUP, TUNNEL, LINEUP, PRESENT_HOME, PRESENT_AWAY, PHOTO, FORMATION, DONE }

## Velocidades (m/s) iguales para todos: así las filas no se desarman.
const WALK := 1.9
## Paso firme de la salida del túnel (la fila tiene que llegar a formarse).
const WALK_IN := 2.3
const JOG := 4.2
## Fila de los dos equipos en la formación protocolar.
const ROW_Z := 3.0
## Presentación: segundos de cámara por jugador y distancia de la toma.
const PER_PLAYER := 0.8
const DOLLY_DIST := 3.4
## Momento del corte a la toma lateral (la boca del túnel depende del
## estadio: StadiumBuilder.tunnel_z).
const TUNNEL_CUT := 4.5
## Duración de cada etapa (s); el menú espera al jugador.
const DURATION := {Step.WARMUP: 6.0, Step.TUNNEL: 9.0, Step.LINEUP: 4.0,
		Step.PRESENT_HOME: PER_PLAYER * 11.0 + 0.6, Step.PRESENT_AWAY: PER_PLAYER * 11.0 + 0.6, Step.PHOTO: 4.0, Step.FORMATION: 5.0}
## Foto del equipo: centro de las dos filas y cuándo salta el flash.
const PHOTO_X := -8.0
const PHOTO_FLASH := 1.6
## Bandera gigante desplegada atrás de la formación protocolar (m).
const FLAG_SIZE := Vector2(26.0, 16.0)
## Rondo: radio de la ronda y velocidad del pase (m/s).
const RONDO_RADIUS := 4.5
const RONDO_PASS_SPEED := 9.0
## Arqueros: cada cuánto les patean y cuánto tarda la pelota.
const KEEPER_SHOT_EVERY := 2.4
const KEEPER_SHOT_FLIGHT := 0.7

var step: int = Step.MENU
var _t := 0.0
var _match: MatchController
var _cam: MatchCamera
var _targets := {}
## Cabeza: [giro buscado, tiempo hasta cambiarlo] por jugador.
var _looks := {}
## Rondos del calentamiento ({center, ring, mid, ball, from, to, t, dur, hold}).
var _rondos: Array[Dictionary] = []
## Arqueros atajando en el calentamiento ({keeper, ball, home, t, from, to, dive}).
var _keeper_drills: Array[Dictionary] = []
## Pelotas sueltas del calentamiento (utilería, quietas en el césped).
var _loose_balls: Array[MeshInstance3D] = []
## Entrenador de arqueros: le patea desde el borde del área.
const COACH_DIST := 11.0
const LOOSE_BALLS := 7
## Jugador que se está presentando (índice en la fila).
var _announced := -1
var _caption: PanelContainer
var _ui: CanvasLayer
var _menu: VBoxContainer
var _hint: Control
var _formation: Control
## Dirección del equipo de la previa (alineación libre, pateadores, capitán).
var sheet: TeamSheet
## Cartel con los once titulares durante la formación (como en el WE).
var _lineup: PanelContainer
## Cartel con los dos equipos (al empezar) y recuadro "EN VIVO".
var _banner: Control
var _live: Control
var _flash: ColorRect
var flag_mesh: MeshInstance3D
## Equipo de la foto.
var photo_team: Team
var _lineup_team := -1
var _rng := RandomNumberGenerator.new()


func setup(m: MatchController, cam: MatchCamera) -> void:
	_match = m
	_cam = cam
	_rng.seed = 1234
	for p in _match.all_players():
		p.set_presenting(true)
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
	_tick_overlays(dt)
	match step:
		Step.MENU:
			# La cámara recorre el estadio por dentro, a la altura de la bandeja
			# baja (de fondo del menú, como en el WE).
			var a := 0.6 + _t * 0.08
			_cam.set_shot(Vector3(cos(a) * 58.0, 16.0, sin(a) * 40.0), Vector3(0, 3, 0), 50.0)
			_warmup_tick(dt)
		Step.WARMUP:
			_warmup_tick(dt)
			if _t > 3.0 and _t - dt <= 3.0:
				# Segunda toma: el arquero atajando.
				var gk := _match.teams[1].keeper()
				if gk != null:
					# De costado: el entrenador que patea y el arquero que ataja.
					var mid := gk.flat_pos() + Vector3(gk.team.attack_dir * COACH_DIST * 0.5, 0.0, 0.0)
					_cam.set_shot(mid + Vector3(gk.team.attack_dir * 1.5, 2.4, 11.5), mid + Vector3(0, 0.9, 0), 46.0)
		Step.PRESENT_HOME, Step.PRESENT_AWAY:
			_walk_to_targets()
			_update_looks(dt)
			_dolly(_match.teams[0 if step == Step.PRESENT_HOME else 1])
		Step.TUNNEL:
			_walk_to_targets()
			_update_looks(dt)
			if true:
				if _t < TUNNEL_CUT:
					# Salen del túnel: cámara en la cancha, mirando la boca.
					_cam.set_shot(Vector3(7.0, 2.0, StadiumBuilder.tunnel_z - 9.0), Vector3(0.0, 1.4, StadiumBuilder.tunnel_z), 38.0)
				else:
					if _t - dt < TUNNEL_CUT:
						_skip_ahead_on_pitch()
					var lead: Footballer = _match.teams[0].players[0]
					_cam.set_shot(lead.flat_pos() + Vector3(-9.0, 3.0, 6.0), lead.flat_pos() + Vector3(2.0, 1.2, -3.0), 35.0, 1.5)
		Step.LINEUP:
			_walk_to_targets()
			_update_looks(dt)
			# Primero los titulares del local y después los del visitante.
			show_lineup(0 if _t < DURATION[Step.LINEUP] * 0.5 else 1)
			# Paneo a lo largo de las dos filas, frente a los jugadores.
			var k := clampf(_t / DURATION[Step.LINEUP], 0.0, 1.0)
			var x := lerpf(-14.0, 14.0, smoothstep(0.0, 1.0, k))
			_cam.set_shot(Vector3(x, 2.1, ROW_Z + 8.5), Vector3(x * 0.85, 1.3, ROW_Z), 40.0, 0.0 if _t <= dt else 3.0)
			# Al final, la bandera gigante detrás de las filas, desde arriba.
			if _t > DURATION[Step.LINEUP] * 0.72:
				_cam.set_shot(Vector3(0.0, 14.0, ROW_Z + 22.0), Vector3(0.0, 0.0, ROW_Z - 8.0), 42.0, 2.0)
		Step.PHOTO:
			for p in photo_team.players:
				p.desired_move = Vector3.ZERO
				p.facing = Vector3.BACK
	if DURATION.has(step) and _t >= DURATION[step]:
		_enter(step + 1)


func _enter(s: int) -> void:
	step = s
	_t = 0.0
	_menu.visible = s == Step.MENU
	_formation.visible = s == Step.FORMATION
	if s != Step.LINEUP:
		_lineup.visible = false
		_lineup_team = -1
	_caption.visible = false
	_announced = -1
	if s >= Step.TUNNEL:
		_clear_warmup()
	_hint.visible = s != Step.MENU and s != Step.DONE
	_banner.visible = s == Step.WARMUP
	_live.visible = s in [Step.WARMUP, Step.TUNNEL]
	if flag_mesh != null:
		flag_mesh.visible = s in [Step.LINEUP, Step.PRESENT_HOME, Step.PRESENT_AWAY]
	match s:
		Step.MENU:
			_setup_warmup()
			(_menu.get_child(1) as Button).grab_focus()
		Step.WARMUP:
			_cut_wide()
		Step.TUNNEL:
			_line_up_in_tunnel()
			_assign_stances()
		Step.LINEUP:
			_set_lineup_targets()
			_show_flag()
		Step.PHOTO:
			_setup_photo()
		Step.FORMATION:
			_formation.queue_redraw()
			_cam.set_shot(Vector3(0, 60, 40), Vector3(0, 0, 0), 45.0)
		Step.DONE:
			_ui.visible = false
			if flag_mesh != null:
				flag_mesh.queue_free()
				flag_mesh = null
			for p in _match.all_players():
				p.set_presenting(false)
				p.desired_move = Vector3.ZERO
				p.speed_override = 0.0
				if p.visual is ModelVisual:
					(p.visual as ModelVisual).stance = ModelVisual.Stance.AUTO
					(p.visual as ModelVisual).look_yaw = 0.0
			_cam.end_cinematic()
			finished.emit()


# --- Movimiento de los jugadores ------------------------------------------------

## Calentamiento: en cada mitad, dos rondos 4 contra 1 con los diez de
## campo y el arquero en su área atajando remates. Las pelotas son de
## utilería (la del partido no se toca).
func _setup_warmup() -> void:
	_clear_warmup()
	for t in _match.teams:
		var field: Array[Footballer] = []
		for p in t.players:
			if not p.is_keeper():
				field.append(p)
		var groups := [field.slice(0, 5), field.slice(5, 10)]
		for g in groups.size():
			var group: Array = groups[g]
			if group.size() < 3:
				continue
			var center := t.to_world(Vector2(0.3, -0.35 if g == 0 else 0.35))
			var ring: Array[Footballer] = []
			for i in group.size() - 1:
				ring.append(group[i])
			var mid: Footballer = group[group.size() - 1]
			for i in ring.size():
				var ang := TAU * i / ring.size() + 0.4 * g
				var spot := center + Vector3(cos(ang), 0.0, sin(ang)) * RONDO_RADIUS
				ring[i].teleport(spot, (center - spot).normalized())
			mid.teleport(center, Vector3(t.attack_dir, 0, 0))
			var r := {"center": center, "ring": ring, "mid": mid, "ball": _prop_ball(),
				"from": 0, "to": 1, "t": 0.0, "dur": 0.5, "hold": 0.0}
			_rondos.append(r)
		var gk := t.keeper()
		if gk != null:
			var home := t.own_goal() + Vector3(t.attack_dir * 0.9, 0.0, 0.0)
			gk.teleport(home, Vector3(t.attack_dir, 0, 0))
			_keeper_drills.append({"keeper": gk, "ball": _prop_ball(), "home": home,
				"t": -_rng.randf_range(0.2, 1.2), "from": Vector3.ZERO, "to": Vector3.ZERO, "dive": -1,
				"coach": _coach(home + Vector3(t.attack_dir * COACH_DIST, 0.0, 0.0), -t.attack_dir)})
		# Pelotas sueltas por el área y la medialuna (como en una previa real).
		for i in LOOSE_BALLS:
			var b := _prop_ball()
			var off := Vector3(t.attack_dir * _rng.randf_range(12.0, 24.0), 0.11, _rng.randf_range(-14.0, 14.0))
			b.global_position = t.own_goal() + off
			b.visible = true
			_loose_balls.append(b)


## Un entrenador de buzo (sin número) parado en `pos`, mirando hacia el arco.
func _coach(pos: Vector3, face_x: float) -> Node3D:
	var v: PlayerVisual = ModelVisual.new() if ModelVisual.available() else PlayerVisual.new()
	_match.add_child(v)
	v.setup({"shirt": Color(0.13, 0.14, 0.18), "shorts": Color(0.13, 0.14, 0.18),
		"socks": Color(0.13, 0.14, 0.18)}, 77 + int(pos.x))
	v.global_position = pos
	v.rotation.y = atan2(face_x, 0.0)
	return v


func _prop_ball() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.95)
	mat.roughness = 0.6
	mi.material_override = mat
	mi.visible = false
	_match.add_child(mi)
	return mi


func _clear_warmup() -> void:
	for r in _rondos:
		(r["ball"] as Node).queue_free()
	for d in _keeper_drills:
		(d["ball"] as Node).queue_free()
		if d.has("coach"):
			(d["coach"] as Node).queue_free()
	for b in _loose_balls:
		b.queue_free()
	_loose_balls.clear()
	_rondos.clear()
	_keeper_drills.clear()


## Cambio antes del partido (TeamSheet → MatchController.swap_lineup): el
## suplente toma el lugar del titular en el calentamiento, la fila y las
## miradas (el titular se borra; si quedaba referenciado, se cerraba el juego).
func replace_player(old: Footballer, new: Footballer) -> void:
	for r in _rondos:
		var ring: Array[Footballer] = r["ring"]
		var i := ring.find(old)
		if i >= 0:
			ring[i] = new
		if r["mid"] == old:
			r["mid"] = new
	for d in _keeper_drills:
		if d["keeper"] == old:
			d["keeper"] = new
	if _targets.has(old):
		_targets[new] = _targets[old]
		_targets.erase(old)
	if _looks.has(old):
		_looks[new] = _looks[old]
		_looks.erase(old)


func _warmup_tick(dt: float) -> void:
	for r in _rondos:
		_rondo_tick(r, dt)
	for d in _keeper_drills:
		_keeper_drill_tick(d, dt)


## Rondo: la pelota va de pie en pie por la ronda; el del medio la persigue.
func _rondo_tick(r: Dictionary, dt: float) -> void:
	var ring: Array[Footballer] = r["ring"]
	var center: Vector3 = r["center"]
	var ball := r["ball"] as MeshInstance3D
	ball.visible = true
	var from: Footballer = ring[r["from"]]
	var to: Footballer = ring[r["to"]]
	var bpos: Vector3
	if r["hold"] > 0.0:
		# La pelota en el pie del que la recibió (un toque y la pasa).
		r["hold"] -= dt
		bpos = to.flat_pos() + to.facing * 0.4
		if r["hold"] <= 0.0:
			r["from"] = r["to"]
			var next: int = r["to"]
			while next == r["to"]:
				next = _rng.randi() % ring.size()
			r["to"] = next
			r["t"] = 0.0
			r["dur"] = maxf(0.3, ring[next].flat_pos().distance_to(to.flat_pos()) / RONDO_PASS_SPEED)
			to.visual.play(PlayerVisual.Event.PASS)
	else:
		r["t"] += dt
		var k: float = clampf(r["t"] / r["dur"], 0.0, 1.0)
		bpos = (from.flat_pos() + from.facing * 0.4).lerp(to.flat_pos() + to.facing * 0.4, k)
		if k >= 1.0:
			r["hold"] = _rng.randf_range(0.25, 0.5)
	ball.global_position = bpos + Vector3.UP * 0.11
	# La ronda mira la pelota; cada uno vuelve a su lugar si se corrió.
	for i in ring.size():
		var p := ring[i]
		var ang := TAU * i / ring.size()
		var spot := center + (p.flat_pos() - center).normalized() * RONDO_RADIUS
		if p.flat_pos().distance_to(center) < 0.5:
			spot = center + Vector3(cos(ang), 0.0, sin(ang)) * RONDO_RADIUS
		if p.flat_pos().distance_to(spot) > 0.4:
			_move(p, spot, WALK)
		else:
			p.desired_move = Vector3.ZERO
			var look := Vector3(bpos.x - p.flat_pos().x, 0.0, bpos.z - p.flat_pos().z)
			if look.length() > 0.2:
				p.facing = look.normalized()
	# El del medio va a la pelota (sin salir de la ronda).
	var mid: Footballer = r["mid"]
	var chase := center + (bpos - center).limit_length(RONDO_RADIUS * 0.6)
	if mid.flat_pos().distance_to(chase) > 0.3:
		_move(mid, chase, JOG * 0.6)
	else:
		mid.desired_move = Vector3.ZERO


## Arquero: le patean desde el punto penal a un costado, arriba o abajo, y
## él ataja (estirada, en el aire o agachado) y vuelve al medio del arco.
func _keeper_drill_tick(d: Dictionary, dt: float) -> void:
	var gk: Footballer = d["keeper"]
	var ball := d["ball"] as MeshInstance3D
	var home: Vector3 = d["home"]
	d["t"] += dt
	var t: float = d["t"]
	if t < 0.0:
		ball.visible = false
		_move_or_stop(gk, home, WALK)
		var cv: PlayerVisual = d.get("coach") as PlayerVisual
		if cv != null:
			cv.update(dt, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
		return
	if d["dive"] < 0:
		# Nuevo remate.
		var side := gk.team.attack_dir
		var coach: Node3D = d.get("coach")
		d["from"] = home + Vector3(side * 10.0, 0.11, _rng.randf_range(-2.0, 2.0))
		if coach != null:
			# El entrenador patea: la pelota sale de su pie.
			d["from"] = coach.global_position + Vector3(-side * 0.5, 0.11, 0.1)
			if coach is PlayerVisual:
				(coach as PlayerVisual).play(PlayerVisual.Event.KICK)
		var kind := _rng.randi() % 4
		var z := 0.0
		var h := 1.0
		match kind:
			0:
				z = 2.0
				d["dive"] = PlayerVisual.Event.DIVE_LEFT if side > 0 else PlayerVisual.Event.DIVE_RIGHT
			1:
				z = -2.0
				d["dive"] = PlayerVisual.Event.DIVE_RIGHT if side > 0 else PlayerVisual.Event.DIVE_LEFT
			2:
				h = 2.1
				d["dive"] = PlayerVisual.Event.CATCH_HIGH
			_:
				h = 0.15
				d["dive"] = PlayerVisual.Event.CATCH_LOW
		d["to"] = home + Vector3(0.0, h, z)
		d["played"] = false
	ball.visible = true
	var coach_v: PlayerVisual = d.get("coach") as PlayerVisual
	if coach_v != null:
		coach_v.update(dt, 0.0, 8.4, PlayerVisual.Pose.NORMAL, 0.0)
	var k := clampf(t / KEEPER_SHOT_FLIGHT, 0.0, 1.0)
	var from: Vector3 = d["from"]
	var to: Vector3 = d["to"]
	ball.global_position = from.lerp(to, k) + Vector3.UP * sin(k * PI) * 0.6
	gk.desired_move = Vector3.ZERO
	gk.facing = Vector3(gk.team.attack_dir, 0, 0)
	if not d["played"] and t > KEEPER_SHOT_FLIGHT - 0.35:
		d["played"] = true
		gk.visual.play(d["dive"], to.y)
	if t > KEEPER_SHOT_FLIGHT:
		# La ataja: la pelota queda en las manos un momento y se va.
		ball.global_position = to
		if t > KEEPER_SHOT_FLIGHT + 0.5:
			ball.visible = false
			d["dive"] = -1
			d["t"] = -(KEEPER_SHOT_EVERY - KEEPER_SHOT_FLIGHT)


func _move_or_stop(p: Footballer, tgt: Vector3, speed: float) -> void:
	if p.flat_pos().distance_to(tgt) > 0.3:
		_move(p, tgt, speed)
	else:
		p.desired_move = Vector3.ZERO
		p.facing = Vector3(p.team.attack_dir, 0, 0)


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
	# Fila prolija: el que todavía venía caminando ya está en su lugar, todos
	# de frente a la cámara (antes alguno pasaba por delante de la toma).
	for p in _targets:
		p.desired_move = Vector3.ZERO
		p.teleport(_targets[p], Vector3.BACK)
	# El árbitro en el medio, entre los dos equipos.
	if _match.referee != null:
		_match.referee.release()
		_match.referee.teleport(Vector3(0.0, 0.0, ROW_Z))
		_match.referee.facing = Vector3.BACK


## Presentación: dolly de frente a la fila de `t`, de punta a punta; al
## llegar a cada jugador el locutor lo nombra (cartel con número, puesto y
## nombre).
func _dolly(t: Team) -> void:
	var row := _row_order(t)
	var k := clampf((_t - 0.3) / PER_PLAYER, 0.0, row.size() - 1.0)
	var i0 := floori(k)
	var i1 := mini(i0 + 1, row.size() - 1)
	var f := smoothstep(0.0, 1.0, k - i0)
	var at := row[i0].flat_pos().lerp(row[i1].flat_pos(), f)
	# Primer cuadro: corte directo; después la cámara se desliza (dolly).
	_cam.set_shot(at + Vector3(0.2, 1.55, DOLLY_DIST), at + Vector3(0.0, 1.35, 0.0), 26.0, 0.0 if _announced < 0 else 6.0)
	var who := clampi(roundi(k), 0, row.size() - 1)
	if who != _announced:
		_announced = who
		_announce(row[who])


## Fila de `t` en el orden en que la recorre la cámara (de afuera hacia el
## centro de la cancha).
func _row_order(t: Team) -> Array[Footballer]:
	var row: Array[Footballer] = t.players.duplicate()
	row.sort_custom(func(a: Footballer, b: Footballer) -> bool: return absf(a.flat_pos().x) > absf(b.flat_pos().x))
	return row


func _announce(p: Footballer) -> void:
	for c in _caption.get_children():
		_caption.remove_child(c)
		c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_caption.add_child(row)
	var num := WEStyle.label(str(p.number), 40, Color.WHITE)
	num.custom_minimum_size = Vector2(64, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(num)
	var box := VBoxContainer.new()
	row.add_child(box)
	box.add_child(WEStyle.label(p.display_name, 30, Color.WHITE))
	var pos: String = "ARQUERO" if p.is_keeper() else TeamSheet.role_code(p)
	box.add_child(WEStyle.label("%s · %s" % [pos, p.team.team_name], 18, Color(0.85, 0.88, 0.95)))
	_caption.visible = true
	player_announced.emit(p)


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
		# El que presenta la cámara mira al frente.
		if _announced >= 0 and step in [Step.PRESENT_HOME, Step.PRESENT_AWAY]:
			var row := _row_order(_match.teams[0 if step == Step.PRESENT_HOME else 1])
			if row[_announced] == p:
				want = 0.0
		mv.look_yaw = lerpf(mv.look_yaw, want, 1.0 - exp(-4.0 * dt))


func _walk_to_targets() -> void:
	for p: Footballer in _targets:
		var tgt: Vector3 = _targets[p]
		if p.flat_pos().distance_to(tgt) < 0.3:
			p.desired_move = Vector3.ZERO
			# En la fila, mirando a la tribuna principal (la cámara).
			p.facing = Vector3.BACK
		else:
			_move(p, tgt, WALK_IN)


## Todos a la misma velocidad (m/s), sin importar sus atributos.
func _move(p: Footballer, tgt: Vector3, speed: float) -> void:
	var d := tgt - p.flat_pos()
	d.y = 0.0
	p.speed_override = speed
	p.desired_move = d.normalized() if d.length() > 0.05 else Vector3.ZERO
	p.wants_sprint = false


# --- Bandera gigante y foto ----------------------------------------------------------

## Bandera del equipo: la de la selección si tiene, si no tres franjas con
## los colores del club.
static func flag_texture(t: TeamData) -> Texture2D:
	if t != null and t.flag != null:
		return t.flag
	var img := Image.create(48, 30, false, Image.FORMAT_RGB8)
	var cols := [t.color, t.secondary_color, t.color] if t != null else [Color.WHITE, Color.BLACK, Color.WHITE]
	for x in 48:
		for y in 30:
			img.set_pixel(x, y, cols[mini(x / 16, 2)])
	return ImageTexture.create_from_image(img)


## La hinchada despliega la bandera del local en el césped, detrás de las
## filas (ondea un poco).
func _show_flag() -> void:
	if flag_mesh == null:
		flag_mesh = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = FLAG_SIZE
		pm.subdivide_width = 24
		pm.subdivide_depth = 12
		flag_mesh.mesh = pm
		var sh := Shader.new()
		sh.code = """shader_type spatial;
uniform sampler2D flag_tex : source_color, filter_nearest;
void vertex() {
	VERTEX.y += 0.18 + 0.16 * sin(VERTEX.x * 0.7 + TIME * 2.3) * cos(VERTEX.z * 0.5 + TIME * 1.7);
}
void fragment() {
	ALBEDO = texture(flag_tex, UV).rgb;
	ROUGHNESS = 0.9;
}
"""
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("flag_tex", flag_texture(_match.teams[0].data))
		flag_mesh.material_override = mat
		flag_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_match.add_child(flag_mesh)
	flag_mesh.position = Vector3(0.0, 0.0, ROW_Z - FLAG_SIZE.y * 0.5 - 4.0)
	flag_mesh.visible = true


## Foto del equipo del jugador 1: seis atrás y cinco adelante, de frente a
## la cámara; a los PHOTO_FLASH segundos, el flash.
func _setup_photo() -> void:
	photo_team = _match.humans[0].team if not _match.humans.is_empty() else _match.teams[0]
	var row: Array[Footballer] = photo_team.players.duplicate()
	for i in row.size():
		var p := row[i]
		var back := i < 6
		var n := 6 if back else row.size() - 6
		var k := (i if back else i - 6) - (n - 1) * 0.5
		var pos := Vector3(PHOTO_X + k * (0.9 if back else 1.15), 0.0, ROW_Z + (0.0 if back else 1.1))
		p.teleport(pos, Vector3.BACK)
		_targets.erase(p)
		if p.visual is ModelVisual:
			(p.visual as ModelVisual).stance = ModelVisual.Stance.BEHIND if back else ModelVisual.Stance.HIPS
			(p.visual as ModelVisual).look_yaw = 0.0
	# El otro equipo, fuera de cuadro.
	for p in _match.teams[1 - photo_team.index].players:
		_targets.erase(p)
		p.teleport(Vector3(-PHOTO_X + (p.number % 11) * 1.0, 0.0, ROW_Z - 6.0), Vector3.BACK)
	_cam.set_shot(Vector3(PHOTO_X, 1.6, ROW_Z + 10.5), Vector3(PHOTO_X, 1.05, ROW_Z), 34.0)
	_caption_text("FOTO DEL EQUIPO", photo_team.team_name)


func _caption_text(title: String, sub: String) -> void:
	for c in _caption.get_children():
		_caption.remove_child(c)
		c.queue_free()
	var box := VBoxContainer.new()
	_caption.add_child(box)
	box.add_child(WEStyle.label(title, 30, Color.WHITE))
	box.add_child(WEStyle.label(sub, 18, Color(0.85, 0.88, 0.95)))
	_caption.visible = true


## Flash de la foto y el cartel de equipos que se desvanece.
func _tick_overlays(_dt: float) -> void:
	if step == Step.PHOTO:
		var since := _t - PHOTO_FLASH
		_flash.color.a = clampf(1.0 - since / 0.45, 0.0, 1.0) if since >= 0.0 else 0.0
	else:
		_flash.color.a = 0.0
	if step == Step.WARMUP:
		_banner.modulate.a = clampf(minf(_t / 0.4, (DURATION[Step.WARMUP] - _t) / 0.6), 0.0, 1.0)


# --- Cámara ---------------------------------------------------------------------

func _cut_wide() -> void:
	_cam.set_shot(Vector3(-30.0, 12.0, 45.0), Vector3(-10.0, 0.0, 0.0), 40.0)


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
	_option("Dirección del equipo", open_team_sheet)
	_option("Saltear la presentación", func() -> void: _enter(Step.DONE))
	_option("Salir al menú", func() -> void: _match.exit_to_menu())
	var cond := Label.new()
	cond.text = String(StadiumStyles.current["name"]) + (" · " + _match.conditions.describe() if _match.conditions != null else "")
	cond.add_theme_font_size_override("font_size", 18)
	cond.add_theme_color_override("font_outline_color", Color.BLACK)
	cond.add_theme_constant_override("outline_size", 6)
	_menu.add_child(cond)
	var hint := ButtonIcons.IconLabel.new(18)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 6)
	hint.custom_minimum_size = Vector2(220, 30)
	hint.position = Vector2(1060, 650)
	_ui.add_child(hint)
	hint.show_text("{X} / Start: saltear")
	_hint = hint
	sheet = TeamSheet.new()
	_ui.add_child(sheet)
	sheet.closed.connect(func() -> void:
		if step == Step.MENU:
			_menu.visible = true
			(_menu.get_child(2) as Button).grab_focus())
	sheet.play_pressed.connect(func() -> void: _enter(Step.WARMUP))
	_lineup = PanelContainer.new()
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(0.02, 0.12, 0.08, 0.78)
	lsb.border_color = Color(0.2, 0.7, 0.45, 0.9)
	lsb.border_width_top = 4
	lsb.set_content_margin_all(14)
	_lineup.add_theme_stylebox_override("panel", lsb)
	_lineup.position = Vector2(40, 70)
	_lineup.visible = false
	_ui.add_child(_lineup)
	# Cartel del jugador presentado (abajo a la izquierda, como en la TV).
	_caption = PanelContainer.new()
	var csb := lsb.duplicate() as StyleBoxFlat
	csb.set_content_margin_all(12)
	_caption.add_theme_stylebox_override("panel", csb)
	_caption.position = Vector2(60, 540)
	_caption.visible = false
	_ui.add_child(_caption)
	_build_tv_graphics()
	_formation = FormationBoard.new()
	(_formation as FormationBoard).match_ref = _match
	_formation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_formation)


## Cartel de los dos equipos (abajo al centro, como en la TV) y el recuadro
## "EN VIVO" con el estadio y el clima (arriba a la izquierda).
func _build_tv_graphics() -> void:
	var t0 := _match.teams[0]
	var t1 := _match.teams[1]
	var banner := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.03, 0.05, 0.14, 0.88)
	bsb.border_color = Color(1.0, 0.85, 0.25)
	bsb.border_width_top = 3
	bsb.border_width_bottom = 3
	bsb.content_margin_left = 22
	bsb.content_margin_right = 22
	bsb.content_margin_top = 8
	bsb.content_margin_bottom = 8
	banner.add_theme_stylebox_override("panel", bsb)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	banner.position.y -= 70
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.add_child(row)
	for t in [t0, t1]:
		if t == t1:
			row.add_child(WEStyle.label("vs", 26, Color(1.0, 0.85, 0.25)))
		var chip := ColorRect.new()
		chip.color = t.color
		chip.custom_minimum_size = Vector2(14, 40)
		if t == t0:
			row.add_child(chip)
		var name := WEStyle.label(t.team_name.to_upper(), 34, Color.WHITE)
		row.add_child(name)
		if t == t1:
			row.add_child(chip)
	banner.visible = false
	_ui.add_child(banner)
	_banner = banner
	var live := PanelContainer.new()
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(0.02, 0.02, 0.06, 0.8)
	lsb.set_content_margin_all(8)
	live.add_theme_stylebox_override("panel", lsb)
	live.position = Vector2(30, 24)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 12)
	live.add_child(lrow)
	var tag := Label.new()
	tag.text = " EN VIVO "
	tag.add_theme_font_size_override("font_size", 20)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.85, 0.08, 0.08)
	tag.add_theme_stylebox_override("normal", tsb)
	lrow.add_child(tag)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	lrow.add_child(info)
	info.add_child(WEStyle.label(String(StadiumStyles.current.get("name", "")), 20, Color.WHITE))
	if _match.conditions != null:
		info.add_child(WEStyle.label(_match.conditions.describe(), 16, Color(0.8, 0.85, 0.95)))
	live.visible = false
	_ui.add_child(live)
	_live = live
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_flash)


func live_text() -> String:
	var parts := []
	for l in _live.get_child(0).get_child(1).get_children():
		parts.append((l as Label).text)
	return " · ".join(parts)


## Previa: la Dirección del equipo del jugador 1 (cambios libres).
func open_team_sheet() -> void:
	var idx := _match.humans[0].team.index if not _match.humans.is_empty() else 0
	_menu.visible = false
	sheet.open(_match, _match.teams[idx], true)


## Cartel de los titulares: puesto (siglas del WE), número y nombre.
func show_lineup(team_index: int) -> void:
	_lineup.visible = true
	if _lineup_team == team_index:
		return
	_lineup_team = team_index
	for c in _lineup.get_children():
		_lineup.remove_child(c)
		c.queue_free()
	var t := _match.teams[team_index]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_lineup.add_child(box)
	box.add_child(WEStyle.label(t.team_name, 26, Color.WHITE))
	for p in t.roster:
		if not t.players.has(p):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var code := Label.new()
		code.text = "GK" if p.is_keeper() else TeamSheet.role_code(p)
		code.custom_minimum_size = Vector2(44, 0)
		code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		code.add_theme_font_size_override("font_size", 18)
		var sb := StyleBoxFlat.new()
		var pos := PlayerData.Position.GK if p.is_keeper() else TacticalRole.to_position(p.tactical_role)
		sb.bg_color = TeamSheet.POS_COLORS[pos]
		code.add_theme_stylebox_override("normal", sb)
		row.add_child(code)
		var num := WEStyle.label(str(p.number), 22)
		num.custom_minimum_size = Vector2(34, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(num)
		row.add_child(WEStyle.label(p.display_name, 22))


func _option(text: String, cb: Callable) -> void:
	var b := WEStyle.bar(text, cb, 400.0, 22)
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
