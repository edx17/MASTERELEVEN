class_name Footballer
extends CharacterBody3D
## Jugador (placeholder: cápsula de color + número). No decide nada por sí mismo:
## un controlador humano o la IA escriben `desired_move`, `wants_sprint`, etc.
## y el partido llama a `tick()` en orden determinista.

enum Role { GK, DF, MF, FW }
enum State { NORMAL, SLIDING, RECOVERING }

const SLOT_COLORS: Array[Color] = [Color(1.0, 0.85, 0.1), Color(0.2, 0.9, 1.0)]

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

var _tuning: Tuning
var _arrow: Label3D
var _pass_marker: MeshInstance3D
var _body_mat: StandardMaterial3D


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


## Desbalance breve (entrada fallida): no puede tocar la pelota ni acelerar.
func stagger(duration: float) -> void:
	if state != State.NORMAL:
		return
	state = State.RECOVERING
	state_timer = duration
	velocity *= 0.4


## Mueve instantáneamente al jugador (reubicaciones de pelota parada).
func teleport(pos: Vector3, look_dir: Vector3 = Vector3.ZERO) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)
	velocity = Vector3.ZERO
	state = State.NORMAL
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
		State.NORMAL:
			_tick_normal(dt, has_ball)

	velocity.y = 0.0
	# Integración propia (decisión B): no hay colisiones físicas entre jugadores,
	# así que no se usa move_and_slide() y el movimiento es determinista.
	global_position += velocity * dt
	global_position.y = 0.0
	_apply_facing()


func _tick_normal(dt: float, has_ball: bool) -> void:
	var move := desired_move
	move.y = 0.0
	if move.length() > 1.0:
		move = move.normalized()
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
	if speed_override > 0.0:
		max_speed = speed_override

	# Giro dependiente de la velocidad: lento gira rápido, en sprint abre la curva.
	var cur_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var turn := lerpf(_tuning.turn_rate, _tuning.turn_rate_sprint, clampf(cur_speed / _tuning.sprint_speed, 0.0, 1.0))
	if has_ball:
		turn *= _tuning.turn_rate_ball_factor
	if move.length_squared() > 0.01:
		facing = _rotate_towards(facing, move.normalized(), turn * dt)

	# El jugador acelera en la dirección en la que mira (no se desliza de costado),
	# salvo a baja velocidad, donde puede ajustar libremente.
	var wish := move
	if move.length_squared() > 0.01 and cur_speed > 2.0:
		wish = facing * move.length()
	var target_vel := wish * max_speed
	var rate := (_tuning.acceleration * (1.0 + 0.15 * acc_attr)) if move.length_squared() > 0.01 else _tuning.deceleration
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
	if _arrow == null:
		return
	_arrow.visible = slot >= 0
	if slot >= 0:
		_arrow.modulate = SLOT_COLORS[slot % SLOT_COLORS.size()]


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

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = team.color if not is_keeper() else team.keeper_color
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	body.mesh = capsule
	body.material_override = _body_mat
	body.position.y = 0.9
	add_child(body)

	# "Nariz" para ver hacia dónde mira.
	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.14, 0.3)
	nose.mesh = box
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = team.secondary_color
	nose.material_override = nose_mat
	nose.position = Vector3(0.0, 1.45, 0.32)
	add_child(nose)

	# Pantalón (segundo color) para distinguir mejor a los equipos.
	var shorts := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.37
	cyl.bottom_radius = 0.37
	cyl.height = 0.35
	shorts.mesh = cyl
	shorts.material_override = nose_mat
	shorts.position.y = 0.75
	add_child(shorts)

	var label := Label3D.new()
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

	_arrow = Label3D.new()
	_arrow.text = "▼"
	_arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Indicador discreto sobre la cabeza del jugador controlado.
	_arrow.font_size = 64
	_arrow.outline_size = 10
	_arrow.pixel_size = 0.005
	_arrow.position.y = 2.5
	_arrow.no_depth_test = true
	_arrow.visible = false
	add_child(_arrow)
	_apply_facing()
