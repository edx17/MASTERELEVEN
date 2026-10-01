class_name PlayerVisual
extends Node3D
## Presentación del jugador, separada de la simulación: el Footballer se mueve
## por código y esta capa sólo "muestra" lo que pasa (nunca cambia la física).
## Recibe cada tick la velocidad y el estado, y eventos puntuales (patear,
## cabecear, atajar...). Hoy es un humanoide armado por piezas y animado por
## código; cuando estén los modelos con esqueleto se reemplaza por una
## versión con AnimationPlayer que implementa la misma interfaz:
##   setup(colors, seed), update(dt, speed, sprint_speed, state), play(event, side)

## Eventos que dispara la simulación.
## Las variantes (atajada alta/baja, achique, recepción, festejo...) usan
## un clip propio en ModelVisual; acá se dibujan con el gesto más parecido.
enum Event { KICK, PASS, HEADER, THROW, DIVE_LEFT, DIVE_RIGHT, CATCH, TACKLE,
		RECEIVE, CHEST, CATCH_HIGH, CATCH_LOW, BLOCK, CELEBRATE, DEJECTED, ROLL,
		FEINT, ROULETTE, STEPOVER, HIGH_FIVE }
## Estado continuo (lo decide el Footballer a partir de su State).
enum Pose { NORMAL, SLIDING, FALLEN }

const SKIN_TONES: Array[Color] = [Color(0.96, 0.8, 0.66), Color(0.87, 0.67, 0.5), Color(0.66, 0.47, 0.33), Color(0.45, 0.31, 0.21)]
const HAIR_TONES: Array[Color] = [Color(0.08, 0.06, 0.05), Color(0.3, 0.18, 0.08), Color(0.75, 0.6, 0.3), Color(0.5, 0.25, 0.1)]

# Medidas (m) de un jugador de ~1,80 m.
const HIP_Y := 0.95
const THIGH := 0.46
const SHIN := 0.46
const SHOULDER_Y := 1.45
const UPPER_ARM := 0.3
const FOREARM := 0.28

var _hips: Node3D
var _torso: Node3D
var _leg: Array[Node3D] = [] # [izq, der] pivote en la cadera
var _knee: Array[Node3D] = []
var _arm: Array[Node3D] = [] # pivote en el hombro
var _elbow: Array[Node3D] = []
var _phase: float = 0.0
var _event: int = -1
var _event_t: float = 0.0
var _event_len: float = 0.0
var _event_side: float = 1.0
var _pose: int = Pose.NORMAL
var _lean: float = 0.0


## colors: {shirt, shorts, socks, boots}. `seed` varía piel y pelo.
func setup(colors: Dictionary, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var skin := _mat(SKIN_TONES[rng.randi() % SKIN_TONES.size()])
	var hair := _mat(HAIR_TONES[rng.randi() % HAIR_TONES.size()])
	var shirt := _mat(colors.get("shirt", Color.WHITE))
	var shorts := _mat(colors.get("shorts", Color.BLACK))
	var socks := _mat(colors.get("socks", colors.get("shirt", Color.WHITE)))
	var boots := _mat(colors.get("boots", Color(0.08, 0.08, 0.08)))

	_hips = Node3D.new()
	_hips.position.y = HIP_Y
	add_child(_hips)
	_box(_hips, Vector3(0.36, 0.2, 0.22), Vector3(0, 0.02, 0), shorts)

	_torso = Node3D.new()
	_hips.add_child(_torso)
	_box(_torso, Vector3(0.42, 0.5, 0.24), Vector3(0, 0.3, 0), shirt)
	# Cuello y cabeza.
	_capsule(_torso, 0.06, 0.12, Vector3(0, 0.6, 0), skin)
	var head := _sphere(_torso, 0.12, Vector3(0, 0.76, 0.01), skin)
	head.scale = Vector3(0.95, 1.1, 1.0)
	var cap := _sphere(_torso, 0.125, Vector3(0, 0.8, -0.015), hair)
	cap.scale = Vector3(1.0, 0.75, 1.05)

	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		# Pierna: muslo con short, pantorrilla con media y botín.
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.1, 0.0, 0.0)
		_hips.add_child(leg)
		_capsule(leg, 0.085, THIGH, Vector3(0, -THIGH * 0.5, 0), skin)
		_capsule(leg, 0.095, THIGH * 0.45, Vector3(0, -THIGH * 0.2, 0), shorts)
		var knee := Node3D.new()
		knee.position.y = -THIGH
		leg.add_child(knee)
		_capsule(knee, 0.07, SHIN, Vector3(0, -SHIN * 0.5, 0), socks)
		_box(knee, Vector3(0.1, 0.07, 0.24), Vector3(0, -SHIN + 0.0, 0.05), boots)
		_leg.append(leg)
		_knee.append(knee)
		# Brazo: manga corta de la camiseta y antebrazo.
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.26, SHOULDER_Y - HIP_Y, 0.0)
		_torso.add_child(arm)
		_capsule(arm, 0.055, UPPER_ARM, Vector3(0, -UPPER_ARM * 0.5, 0), skin)
		_capsule(arm, 0.065, UPPER_ARM * 0.5, Vector3(0, -UPPER_ARM * 0.2, 0), shirt)
		var elbow := Node3D.new()
		elbow.position.y = -UPPER_ARM
		arm.add_child(elbow)
		_capsule(elbow, 0.045, FOREARM, Vector3(0, -FOREARM * 0.5, 0), skin)
		_arm.append(arm)
		_elbow.append(elbow)


## Avanza la animación. speed: m/s del jugador.
func update(dt: float, speed: float, sprint_speed: float, pose: int, accel: float) -> void:
	_pose = pose
	var run := clampf(speed / maxf(sprint_speed, 0.1), 0.0, 1.0)
	# Cadencia: ~1,4 zancadas/s trotando, ~2,3 en sprint.
	_phase = fmod(_phase + dt * lerpf(1.4, 2.4, run) * TAU * (1.0 if speed > 0.3 else 0.0), TAU)
	_lean = lerpf(_lean, clampf(accel * 0.02 + run * 0.18, -0.15, 0.35), 1.0 - exp(-8.0 * dt))
	if _event >= 0:
		_event_t += dt
		if _event_t >= _event_len:
			_event = -1
	_apply(run)


## Dónde se ve la pelota cuando el arquero la tiene en las manos (global).
func hold_point() -> Vector3:
	return global_transform * Vector3(0.0, 1.0, 0.35)


## Dónde toca la pelota el gesto recién lanzado (pie derecho; cabeza en el
## cabezazo), en coordenadas globales. La pelota se dibuja saliendo de ahí.
func contact_point(event: int) -> Vector3:
	if event == Event.HEADER:
		return global_transform * Vector3(0.0, 1.85, 0.15)
	return global_transform * Vector3(-0.12, 0.11, 0.45)


func play(event: int, side: float = 1.0) -> void:
	match event:
		Event.CATCH_HIGH, Event.CATCH_LOW, Event.BLOCK:
			event = Event.CATCH
		Event.ROLL:
			event = Event.THROW
		Event.RECEIVE, Event.DEJECTED:
			return # sin gesto propio en el humanoide armado por piezas
	_event = event
	_event_t = 0.0
	_event_side = side
	# Duraciones pensadas para que el gesto se lea desde la cámara de TV.
	match event:
		Event.KICK: _event_len = 0.55
		Event.PASS: _event_len = 0.42
		Event.HEADER: _event_len = 0.6
		Event.THROW: _event_len = 0.6
		Event.CATCH: _event_len = 0.45
		Event.TACKLE: _event_len = 0.45
		Event.CHEST: _event_len = 0.5
		Event.CELEBRATE: _event_len = 2.5
		Event.FEINT: _event_len = 0.35
		Event.ROULETTE: _event_len = 0.7
		Event.STEPOVER: _event_len = 0.6
		Event.HIGH_FIVE: _event_len = 0.5
		_: _event_len = 1.1


func _apply(run: float) -> void:
	var swing := sin(_phase)
	var amp := lerpf(0.0, 0.9, run) if run > 0.04 else 0.0
	var rest := Vector3.ZERO
	_hips.position = Vector3(0, HIP_Y - absf(cos(_phase)) * 0.04 * run, 0)
	_hips.rotation = rest
	_torso.rotation = Vector3(_lean, 0, 0)
	for i in 2:
		var s := swing if i == 0 else -swing
		_leg[i].rotation = Vector3(-s * amp, 0, 0)
		# La rodilla se dobla cuando la pierna va hacia atrás.
		_knee[i].rotation = Vector3(maxf(0.0, -s) * amp * 1.3 + 0.05, 0, 0)
		_arm[i].rotation = Vector3(s * amp * 0.8, 0, (-1.0 if i == 0 else 1.0) * 0.12)
		_elbow[i].rotation = Vector3(-0.3 - run * 0.9, 0, 0)

	match _pose:
		Pose.SLIDING:
			_hips.position.y = 0.3
			_hips.rotation = Vector3(-1.1, 0, 0)
			_leg[1].rotation = Vector3(-1.2, 0, 0)
			_knee[1].rotation = Vector3(0.0, 0, 0)
			_leg[0].rotation = Vector3(-0.4, 0, 0)
			_knee[0].rotation = Vector3(1.2, 0, 0)
			return
		Pose.FALLEN:
			_hips.position.y = 0.2
			_hips.rotation = Vector3(-1.45, 0, 0)
			return

	if _event < 0:
		return
	var k := clampf(_event_t / _event_len, 0.0, 1.0)
	# Curva de golpe: carga (atrás) y golpe (adelante).
	var strike := sin(k * PI)
	match _event:
		Event.KICK, Event.PASS:
			var power := 1.4 if _event == Event.KICK else 0.9
			var leg_angle := lerpf(0.9, -power, smoothstep(0.0, 0.55, k)) if k < 0.8 else lerpf(-power, 0.0, (k - 0.8) / 0.2)
			_leg[1].rotation = Vector3(leg_angle, 0, 0)
			_knee[1].rotation = Vector3(maxf(0.0, 1.0 - k * 2.0) * 1.2, 0, 0)
			_arm[0].rotation = Vector3(-0.6 * strike, 0, -0.5 * strike)
			_torso.rotation.x = _lean - 0.15 * strike
		Event.HEADER:
			_hips.position.y += 0.35 * strike
			_torso.rotation.x = -0.4 + 0.9 * k
		Event.THROW:
			for i in 2:
				_arm[i].rotation = Vector3(lerpf(-2.8, -0.8, k), 0, 0)
		Event.CATCH:
			for i in 2:
				_arm[i].rotation = Vector3(-1.4 * strike, 0, 0)
		Event.CHEST:
			# Pecho afuera para bajarla, brazos abiertos.
			_torso.rotation.x = _lean - 0.45 * strike
			for i in 2:
				_arm[i].rotation = Vector3(0, 0, (-1.0 if i == 0 else 1.0) * 0.8 * strike)
		Event.FEINT:
			# Carga la pierna como para patear y frena.
			_leg[1].rotation = Vector3(0.9 * strike, 0, 0)
			_knee[1].rotation = Vector3(1.0 * strike, 0, 0)
		Event.ROULETTE:
			_hips.rotation.y = k * TAU
		Event.STEPOVER:
			# Pasa una pierna y la otra por encima de la pelota.
			var first := k < 0.5
			var kk := sin(fmod(k * 2.0, 1.0) * PI)
			_leg[1 if first else 0].rotation = Vector3(-0.6 * kk, 0, (1.0 if first else -1.0) * -0.7 * kk)
		Event.CELEBRATE:
			# Brazos arriba y saltito.
			_hips.position.y += 0.2 * absf(sin(k * PI * 4.0))
			for i in 2:
				_arm[i].rotation = Vector3(-2.9 * minf(k * 5.0, 1.0), 0, 0)
		Event.TACKLE:
			_leg[1].rotation = Vector3(-1.2 * strike, 0, 0)
			_torso.rotation.x = _lean + 0.35 * strike
		Event.DIVE_LEFT, Event.DIVE_RIGHT:
			var dir := -1.0 if _event == Event.DIVE_LEFT else 1.0
			var up := minf(k * 3.0, 1.0)
			_hips.rotation = Vector3(0, 0, -dir * 1.35 * up)
			_hips.position.y = HIP_Y * lerpf(1.0, 0.45, up)
			for i in 2:
				_arm[i].rotation = Vector3(0, 0, dir * 2.8 * up)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _capsule(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = maxf(height, radius * 2.0)
	c.radial_segments = 8
	c.rings = 2
	mi.mesh = c
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
