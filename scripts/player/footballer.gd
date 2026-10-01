class_name Footballer
extends CharacterBody3D
## Jugador (placeholder: cápsula de color + número). No decide nada por sí mismo:
## un controlador humano o la IA escriben `desired_move`, `wants_sprint`, etc.
## y el partido llama a `tick()` en orden determinista.

enum Role { GK, DF, MF, FW }
enum State { NORMAL, SLIDING, RECOVERING }
## Gambetas en curso: amague (enganche), marsellesa, bicicleta y el pique
## que sale después de la bicicleta.
enum Skill { NONE, FEINT, ROULETTE, STEPOVER, BURST }

## Hasta esta velocidad se puede desplazar de costado mirando a otro lado.
const STRAFE_MAX_SPEED := 4.5
const SLOT_COLORS: Array[Color] = [Color(1.0, 0.85, 0.1), Color(0.2, 0.9, 1.0)]

## Empezó una barrida (lo usa la presentación: marcas en el césped mojado).
signal slide_started

var team: Team
## Datos y atributos del jugador (recurso editable).
var data: PlayerData
var number: int = 1
var role: Role = Role.MF
var display_name: String = ""
## Posición base de la formación en "espacio de equipo": x 0..1 (arco propio ->
## arco rival), y -1..1 (lado derecho -> izquierdo mirando al ataque).
var base_spot: Vector2 = Vector2.ZERO
## Rol táctico del puesto (TacticalRole.Kind).
var tactical_role: int = TacticalRole.Kind.CM

# --- Entradas escritas por el controlador (humano o IA) ----------------------
var desired_move: Vector3 = Vector3.ZERO
var wants_sprint: bool = false
## Presionando al rival (aumenta la chance de robo).
var pressing: bool = false
## Velocidad máxima especial (p. ej. estirada del arquero). 0 = normal.
var speed_override: float = 0.0

# --- Estado ------------------------------------------------------------------
var facing: Vector3 = Vector3.RIGHT
var state: State = State.NORMAL
var state_timer: float = 0.0
## Tiempo durante el que no puede tocar la pelota.
var touch_block: float = 0.0
## Quieto obligado (ejecutor de pelota parada).
var locked: bool = false
## Humano que lo controla (-1 = IA).
var human_slot: int = -1
## Destino de un pase dirigido a este jugador.
var pass_target: Vector3 = Vector3.ZERO
var pass_target_timer: float = 0.0
## Tiempo con la pelota en el pie (para que la IA no la devuelva al instante).
var possession_time: float = 0.0
## Presión rival 0..1 sobre este jugador (la calcula el partido; acorta los toques).
var dribble_pressure: float = 0.0
## Toques de conducción dados (depuración).
var touches: int = 0
## Depuración (F9): hacia dónde va y qué está haciendo según su controlador.
var debug_target: Vector3 = Vector3.ZERO
var debug_state: String = ""
## Energía 0..100 (ver update_stamina).
var stamina: float = 100.0
## Tiempo de reacción pendiente (IA): mientras corre, mantiene la orden anterior.
var reaction_timer: float = 0.0
## Posición del rival más cercano (la fija el partido; sirve para cubrir la pelota).
var shield_from: Vector3 = Vector3.ZERO
## Tiempo hasta poder intentar otra entrada.
var tackle_cooldown: float = 0.0
## El controlador pide una entrada este tick (la resuelve el partido).
var wants_tackle: bool = false
## Punto al que mira mientras se desplaza despacio (el arquero de costado,
## de frente a la pelota). Lo fija el controlador cada tick; INF = no.
var face_point: Vector3 = Vector3.INF
## En el piso tras una barrida (dentro de RECOVERING): se cae y se levanta.
var tripped: bool = false
## Festejando un gol: no se mueve hasta que termina.
var celebrate_timer: float = 0.0
## Gambeta en curso y cuánto le queda.
var skill: int = Skill.NONE
var skill_timer: float = 0.0
## Conducción cerrada (L1 mantenido con la pelota): pelota pegada, giros más
## cortos, algo más lento. Lo fija el controlador cada tick.
var close_control: bool = false
## Tarjetas amarillas en el partido.
var yellow_cards: int = 0
## Arquero con la pelota en las manos (lo fija el partido; para la pose).
var ball_in_hands: bool = false

var _tuning: Tuning
var _arrow: MeshInstance3D
var _pass_marker: MeshInstance3D
var _control_ring: MeshInstance3D
var _label: Label3D
## Capa de presentación (modelo y animaciones); no afecta la simulación.
var visual: PlayerVisual
var _prev_speed: float = 0.0


func setup(p_team: Team, p_data: PlayerData, p_role: int, p_spot: Vector2, tuning: Tuning) -> void:
	team = p_team
	data = p_data
	number = data.number
	role = p_role as Role
	base_spot = p_spot
	display_name = data.player_name
	_tuning = tuning
	facing = Vector3(team.attack_dir, 0.0, 0.0)
	name = "%s_%d" % [team.short_name, number]
	_build_visuals()


## Energía 0..1 (se gasta en sprint y se recupera trotando/parado).
func stamina_fraction() -> float:
	return clampf(stamina / 100.0, 0.0, 1.0)


## Actualiza la energía (informe técnico: sprint continuo gasta ~20-30 puntos
## en 10 s; se recupera más rápido parado que trotando). El atributo stamina
## del jugador reduce el gasto.
func update_stamina(dt: float) -> void:
	var endurance := PlayerData.unit(data.stamina) if data else 0.6
	var moving := Vector3(velocity.x, 0.0, velocity.z).length()
	if is_sprinting() and moving > _tuning.run_speed * 0.8:
		stamina -= _tuning.stamina_sprint_drain * (1.3 - 0.6 * endurance) * dt
	elif moving > 1.5:
		stamina += _tuning.stamina_regen_jog * dt
	else:
		stamina += _tuning.stamina_regen_rest * dt
	stamina = clampf(stamina, 0.0, 100.0)


## Multiplicador de velocidad por cansancio: debajo del umbral cae hasta el mínimo.
func fatigue_speed_factor() -> float:
	var th := _tuning.stamina_tired_threshold
	if stamina >= th:
		return 1.0
	return lerpf(_tuning.stamina_min_speed_factor, 1.0, stamina / th)


func is_keeper() -> bool:
	return role == Role.GK


func is_human() -> bool:
	return human_slot >= 0


func flat_pos() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)


func has_pass_target() -> bool:
	return pass_target_timer > 0.0


func set_pass_target(point: Vector3, duration: float) -> void:
	pass_target = Vector3(point.x, 0.0, point.z)
	pass_target_timer = duration


func clear_pass_target() -> void:
	pass_target_timer = 0.0


func is_sprinting() -> bool:
	return wants_sprint and desired_move.length_squared() > 0.04 and state == State.NORMAL


func can_touch_ball() -> bool:
	return touch_block <= 0.0 and state != State.RECOVERING


func start_slide(direction: Vector3) -> void:
	if state != State.NORMAL or locked:
		return
	var d := Vector3(direction.x, 0.0, direction.z)
	if d.length_squared() > 0.01:
		facing = d.normalized()
	state = State.SLIDING
	state_timer = _tuning.slide_duration
	velocity = facing * _tuning.slide_speed
	slide_started.emit()


## Desbalance breve (entrada fallida): no puede tocar la pelota ni acelerar.
func stagger(duration: float) -> void:
	if state != State.NORMAL:
		return
	state = State.RECOVERING
	state_timer = duration
	velocity *= 0.4


## Derribado por una barrida: queda en el piso y se levanta (no puede tocar
## la pelota ni moverse mientras tanto).
func trip(duration: float) -> void:
	if state == State.SLIDING:
		return
	state = State.RECOVERING
	state_timer = duration
	tripped = true
	velocity *= 0.3


func start_skill(kind: int, duration: float) -> void:
	skill = kind
	skill_timer = duration


func _tick_skill(dt: float) -> void:
	if skill == Skill.NONE:
		return
	skill_timer -= dt
	if skill_timer <= 0.0:
		# Tras la bicicleta, pique: sale disparado hacia donde apunte.
		if skill == Skill.STEPOVER:
			start_skill(Skill.BURST, 0.6)
		else:
			skill = Skill.NONE


## Festejo de gol (sólo presentación; el partido está detenido).
func celebrate(duration: float) -> void:
	celebrate_timer = duration
	if visual != null:
		visual.play(PlayerVisual.Event.CELEBRATE)


## Mueve instantáneamente al jugador (reubicaciones de pelota parada).
func teleport(pos: Vector3, look_dir: Vector3 = Vector3.ZERO) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)
	velocity = Vector3.ZERO
	state = State.NORMAL
	tripped = false
	celebrate_timer = 0.0
	skill = Skill.NONE
	if look_dir.length_squared() > 0.01:
		facing = Vector3(look_dir.x, 0.0, look_dir.z).normalized()
	_apply_facing()


## Avanza un paso de simulación. `has_ball` lo informa el partido.
func tick(dt: float, has_ball: bool) -> void:
	touch_block = maxf(0.0, touch_block - dt)
	tackle_cooldown = maxf(0.0, tackle_cooldown - dt)
	pass_target_timer = maxf(0.0, pass_target_timer - dt)
	possession_time = possession_time + dt if has_ball else 0.0
	reaction_timer = maxf(0.0, reaction_timer - dt)
	celebrate_timer = maxf(0.0, celebrate_timer - dt)
	_tick_skill(dt)
	update_stamina(dt)

	match state:
		State.SLIDING:
			state_timer -= dt
			velocity = velocity.move_toward(Vector3.ZERO, _tuning.slide_speed * 0.8 * dt)
			if state_timer <= 0.0:
				state = State.RECOVERING
				state_timer = _tuning.slide_recovery
		State.RECOVERING:
			state_timer -= dt
			velocity = velocity.move_toward(Vector3.ZERO, _tuning.deceleration * dt)
			if state_timer <= 0.0:
				state = State.NORMAL
				tripped = false
		State.NORMAL:
			_tick_normal(dt, has_ball)

	velocity.y = 0.0
	# Integración propia (decisión B): no hay colisiones físicas entre jugadores,
	# así que no se usa move_and_slide() y el movimiento es determinista.
	global_position += velocity * dt
	global_position.y = 0.0
	face_point = Vector3.INF
	_apply_facing()
	_update_visual(dt)


func _update_visual(dt: float) -> void:
	if visual == null:
		return
	var spd := Vector3(velocity.x, 0.0, velocity.z).length()
	var accel := (spd - _prev_speed) / maxf(dt, 0.001)
	_prev_speed = spd
	var pose := PlayerVisual.Pose.NORMAL
	if state == State.SLIDING:
		pose = PlayerVisual.Pose.SLIDING
	elif state == State.RECOVERING and (tripped or state_timer > 0.3):
		pose = PlayerVisual.Pose.FALLEN
	if visual is ModelVisual:
		var mv := visual as ModelVisual
		mv.keeper = is_keeper()
		mv.carrying = possession_time > 0.0
		mv.tripped = tripped
		mv.recover_left = state_timer if state == State.RECOVERING else 0.0
		# Desplazamiento de costado (eje X del modelo = su izquierda).
		mv.side_speed = velocity.dot(global_basis.x)
		mv.holding = ball_in_hands
	visual.update(dt, spd, _tuning.sprint_speed, pose, accel)


func _tick_normal(dt: float, has_ball: bool) -> void:
	var move := desired_move
	move.y = 0.0
	if move.length() > 1.0:
		move = move.normalized()
	if celebrate_timer > 0.0:
		velocity = velocity.move_toward(Vector3.ZERO, _tuning.deceleration * dt)
		return
	if locked:
		# Puede girar para apuntar pero no desplazarse.
		if move.length_squared() > 0.04:
			facing = move.normalized()
		velocity = Vector3.ZERO
		return

	# Sin energía no se puede sprintar.
	var sprinting := wants_sprint and stamina > 3.0
	var max_speed := _tuning.sprint_speed if sprinting else _tuning.run_speed
	# Atributos: velocidad ±8 %, aceleración ±15 %.
	var spd_attr := 0.0
	var acc_attr := 0.0
	if data != null:
		spd_attr = PlayerData.centered(data.speed)
		acc_attr = PlayerData.centered(data.acceleration)
	max_speed *= 1.0 + 0.08 * spd_attr
	max_speed *= fatigue_speed_factor()
	if has_ball:
		max_speed *= _tuning.dribble_speed_factor
		if close_control:
			max_speed *= 0.78
	match skill:
		Skill.ROULETTE, Skill.STEPOVER:
			max_speed *= 0.5
		Skill.BURST:
			max_speed *= 1.05
	if speed_override > 0.0:
		max_speed = speed_override

	# Giro estilo WE: el cuerpo sigue al stick casi al instante; en sprint abre
	# un poco la curva. Un cambio de dirección grande (más de ~100°) es un
	# "corte": frena en seco y sale para el otro lado (no da una vuelta ancha).
	var cur_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var turn := lerpf(_tuning.turn_rate, _tuning.turn_rate_sprint, clampf(cur_speed / _tuning.sprint_speed, 0.0, 1.0))
	if has_ball:
		turn *= _tuning.turn_rate_ball_factor
		if close_control:
			turn *= 1.4
	var cut := false
	if face_point != Vector3.INF and not sprinting and cur_speed < STRAFE_MAX_SPEED:
		# Se desplaza de costado sin dejar de mirar el punto (arquero).
		var look := face_point - global_position
		look.y = 0.0
		if look.length_squared() > 0.01:
			facing = _rotate_towards(facing, look.normalized(), turn * dt)
	elif move.length_squared() > 0.01:
		var off := absf(facing.signed_angle_to(move.normalized(), Vector3.UP))
		cut = off > deg_to_rad(_tuning.cut_angle) and cur_speed > 1.5
		facing = _rotate_towards(facing, move.normalized(), (turn * 2.0 if cut else turn) * dt)

	# Se acelera hacia donde pide el stick; la inercia la da la aceleración
	# (sin arcos de "auto": el jugador no se desliza de costado porque el
	# cuerpo gira más rápido de lo que cambia la velocidad).
	var target_vel := move * max_speed
	var rate := (_tuning.acceleration * (1.0 + 0.15 * acc_attr)) if move.length_squared() > 0.01 else _tuning.deceleration
	if cut:
		rate = maxf(rate, _tuning.deceleration * 1.3)
	if skill == Skill.BURST:
		rate *= 1.6
	velocity = velocity.move_toward(target_vel, rate * dt)


static func _rotate_towards(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	var angle := from.signed_angle_to(to, Vector3.UP)
	if absf(angle) <= max_angle:
		return to
	return from.rotated(Vector3.UP, signf(angle) * max_angle).normalized()


## Mira hacia un punto sin moverse (IA/esperas).
func look_at_point(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length_squared() > 0.01 and desired_move.length_squared() < 0.01:
		facing = d.normalized()


func set_human_slot(slot: int) -> void:
	human_slot = slot
	refresh_label()
	if _arrow == null:
		return
	_arrow.visible = slot >= 0
	_control_ring.visible = slot >= 0
	if slot >= 0:
		var c := SLOT_COLORS[slot % SLOT_COLORS.size()]
		(_arrow.material_override as StandardMaterial3D).albedo_color = c
		(_control_ring.material_override as StandardMaterial3D).albedo_color = Color(c, 0.9)


## Marca sobre la cabeza (GameSettings.player_label): el nombre del que
## maneja el humano arriba de la flecha (como en el WE), los números de todos,
## o nada.
func refresh_label() -> void:
	if _label == null:
		return
	match GameSettings.player_label:
		0:
			_label.visible = human_slot >= 0
			_label.text = display_name
			_label.font_size = 110
			_label.position.y = 3.25
		1:
			_label.visible = true
			_label.text = str(number)
			_label.font_size = 72
			_label.position.y = 2.15
		_:
			_label.visible = false


## Marca en el piso del compañero que va a recibir el pase que se está
## cargando (slot = humano que pasa; -1 = sin marca).
func set_pass_marker(slot: int) -> void:
	if _pass_marker == null:
		_pass_marker = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.45
		torus.outer_radius = 0.6
		torus.rings = 24
		_pass_marker.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pass_marker.material_override = mat
		_pass_marker.scale = Vector3(1.0, 0.08, 1.0)
		_pass_marker.position.y = 0.04
		_pass_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_pass_marker)
	_pass_marker.visible = slot >= 0
	if slot >= 0:
		var c := SLOT_COLORS[slot % SLOT_COLORS.size()]
		(_pass_marker.material_override as StandardMaterial3D).albedo_color = Color(c, 0.85)


func _apply_facing() -> void:
	if facing.length_squared() > 0.0001:
		rotation.y = atan2(facing.x, facing.z)


func _build_visuals() -> void:
	var shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.35
	capsule_shape.height = 1.8
	shape.shape = capsule_shape
	shape.position.y = 0.9
	add_child(shape)
	# Decisión B: sin física realista entre jugadores; la separación se hace por código.
	collision_layer = 2
	collision_mask = 0

	# Presentación (separada de la simulación): modelo humano con esqueleto si
	# está importado (assets/), si no el humanoide armado por piezas.
	visual = ModelVisual.new() if ModelVisual.available() else PlayerVisual.new()
	add_child(visual)
	var shirt := team.keeper_color if is_keeper() else team.color
	var colors := {"shirt": shirt, "shorts": team.secondary_color, "socks": shirt, "number": number}
	if is_keeper():
		colors["gloves"] = Color(0.95, 0.95, 0.9)
	visual.setup(colors, team.index * 100 + number)

	var label := Label3D.new()
	_label = label
	label.text = str(number)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 72
	label.outline_size = 14
	label.pixel_size = 0.006
	label.modulate = Color.WHITE
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.position.y = 2.15
	label.no_depth_test = true
	add_child(label)
	refresh_label()

	# Flecha (cono invertido) bien visible sobre la cabeza del jugador
	# controlado, como en WE; legible también con las cámaras lejanas.
	_arrow = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.32
	cone.bottom_radius = 0.0
	cone.height = 0.5
	cone.radial_segments = 4
	_arrow.mesh = cone
	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_mat.no_depth_test = true
	arrow_mat.render_priority = 1
	_arrow.material_override = arrow_mat
	_arrow.position.y = 2.75
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.visible = false
	add_child(_arrow)

	# Anillo en el piso del jugador controlado (del color del humano).
	_control_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.55
	ring.outer_radius = 0.75
	ring.rings = 24
	_control_ring.mesh = ring
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_control_ring.material_override = ring_mat
	_control_ring.scale = Vector3(1.0, 0.06, 1.0)
	_control_ring.position.y = 0.03
	_control_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_control_ring.visible = false
	add_child(_control_ring)
	_apply_facing()
