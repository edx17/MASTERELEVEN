class_name ModelVisual
extends PlayerVisual
## Presentación con modelo humano con esqueleto (CC0 de Quaternius: Universal
## Base Characters + Universal Animation Library, mismo esqueleto). Misma
## interfaz que PlayerVisual; la simulación no se entera del cambio.
## - Locomoción: animaciones de la librería según la velocidad (quieto,
##   caminar, trotar, sprint) con la cadencia ajustada a la velocidad real.
## - Gestos de fútbol que la librería no trae (patada, pase, cabezazo,
##   saque, atajada, estirada, barrida, caída): se aplican moviendo huesos
##   encima de la animación, justo después de que el AnimationPlayer la aplica.
## - Si están las animaciones de fútbol de Mixamo en la copia local
##   (MixamoLibrary), los gestos usan esas animaciones en lugar de los armados
##   por código; el arquero usa su postura de espera y el que conduce, la de
##   conducción.
## - Colores del club por zona del cuerpo (camiseta, short, medias, piel,
##   botines, pelo) con un shader; la zona se hornea una vez en la malla.

const BODY_PATH := "res://assets/models/players/player_body.gltf"
const ANIMS_PATH := "res://assets/animations/ual1_standard.glb"
const BODY_MESH := "SuperHero_Male"

## [animación, velocidad (m/s) a la que se ve natural].
## Umbral: desde qué velocidad se usa; nominal: velocidad a la que la
## animación se ve natural (el pie no patina).
const LOCOMOTION := [["Idle", 0.0, 0.0], ["Walk", 0.35, 1.5], ["Jog_Fwd", 2.4, 3.9], ["Sprint", 6.6, 7.4]]
const BLEND := 0.18
## Tiempo (s) que tarda en levantarse tras una caída (el clip se acelera para
## terminar justo cuando la simulación le devuelve el control).
const GETUP_TIME := 0.9
## Clips que no se cortan por otro gesto (en el piso, festejando).
const UNINTERRUPTIBLE := ["trip", "get_up", "celebrate"]

static var _body_scene: PackedScene
static var _anim_lib: AnimationLibrary
static var _region_mesh: ArrayMesh
static var _checked := false

var _model: Node3D
var _skel: Skeleton3D
var _anim: AnimationPlayer
var _current := ""
var _bones := {}
var _speed := 0.0
var _run := 0.0
## Rotación animada limpia y última rotación puesta por un gesto, por hueso.
var _clean := {}
var _last_set := {}
## Animaciones de fútbol (Mixamo) disponibles, clip en curso y cuánto le queda.
var _mx: AnimationLibrary
var _clip := ""
var _clip_left := 0.0
var _slide_played := false
## Lo fija el Footballer: es arquero / lleva la pelota (elige la locomoción).
var keeper := false
var carrying := false
## Lo fija el Footballer: derribado por una barrida, cuánto le falta para
## volver a jugar y velocidad de costado (+ = hacia el +X del modelo).
var tripped := false
var recover_left := 0.0
var side_speed := 0.0
var _trip_played := false
var _getup_played := false


## Hay modelo y animaciones importados en el proyecto.
static func available() -> bool:
	if not _checked:
		_checked = true
		if ResourceLoader.exists(BODY_PATH) and ResourceLoader.exists(ANIMS_PATH):
			_body_scene = load(BODY_PATH) as PackedScene
			var lib_scene := load(ANIMS_PATH) as PackedScene
			if _body_scene != null and lib_scene != null:
				var tmp := lib_scene.instantiate()
				var ap := tmp.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if ap != null:
					_anim_lib = ap.get_animation_library(&"")
				tmp.free()
	return _body_scene != null and _anim_lib != null


func setup(colors: Dictionary, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_model = _body_scene.instantiate() as Node3D
	add_child(_model)
	_skel = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	for n in ["pelvis", "spine_01", "spine_03", "thigh_l", "thigh_r", "calf_l", "calf_r",
			"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "Head"]:
		_bones[n] = _skel.find_bone(n)

	var body := _skel.find_child(BODY_MESH, false, false) as MeshInstance3D
	if body != null:
		if _region_mesh == null:
			_region_mesh = _bake_regions(body.mesh)
		body.mesh = _region_mesh
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://scripts/player/player_body.gdshader")
		var shirt: Color = colors.get("shirt", Color.WHITE)
		var skin: Color = SKIN_TONES[rng.randi() % SKIN_TONES.size()]
		mat.set_shader_parameter("shirt", shirt)
		mat.set_shader_parameter("shorts", colors.get("shorts", Color.BLACK))
		mat.set_shader_parameter("socks", colors.get("socks", shirt))
		mat.set_shader_parameter("boots", colors.get("boots", Color(0.06, 0.06, 0.06)))
		mat.set_shader_parameter("skin", skin)
		mat.set_shader_parameter("hair", HAIR_TONES[rng.randi() % HAIR_TONES.size()])
		mat.set_shader_parameter("hands", colors.get("gloves", skin))
		body.material_override = mat
	if colors.has("number"):
		_add_back_number(int(colors["number"]), colors.get("shirt", Color.WHITE))
	var dark := _mat(Color(0.05, 0.04, 0.04))
	for extra in ["Eyebrows", "Eyes"]:
		var mi := _skel.find_child(extra, false, false) as MeshInstance3D
		if mi != null:
			mi.material_override = dark

	_anim = AnimationPlayer.new()
	_model.add_child(_anim)
	_anim.root_node = _anim.get_path_to(_model)
	_anim.add_animation_library(&"", _anim_lib)
	_mx = MixamoLibrary.library(_body_scene)
	if _mx != null:
		_anim.add_animation_library(&"mx", _mx)
	_anim.mixer_applied.connect(_apply_gestures)
	_play_locomotion(0.0)


## Número en la espalda: sigue al hueso del pecho (se mueve con el torso).
func _add_back_number(number: int, shirt: Color) -> void:
	var bone := _skel.find_bone("spine_03")
	if bone < 0:
		return
	var attach := BoneAttachment3D.new()
	attach.bone_name = "spine_03"
	_skel.add_child(attach)
	var label := Label3D.new()
	label.text = str(number)
	label.font_size = 128
	label.pixel_size = 0.0022
	label.outline_size = 10
	var light_shirt := shirt.get_luminance() > 0.55
	label.modulate = Color(0.08, 0.08, 0.1) if light_shirt else Color(0.97, 0.97, 0.97)
	label.outline_modulate = Color(0.97, 0.97, 0.97, 0.6) if light_shirt else Color(0.05, 0.05, 0.08, 0.6)
	label.double_sided = false
	label.shaded = true
	attach.add_child(label)
	# Pose deseada en el espacio del modelo (espalda = -Z, mirando hacia atrás),
	# pasada al espacio del hueso en reposo.
	var rest := _skel.get_bone_global_rest(bone)
	var desired := Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, rest.origin.y + 0.02, -0.16))
	label.transform = rest.affine_inverse() * desired


func update(dt: float, speed: float, sprint_speed: float, pose: int, accel: float) -> void:
	_pose = pose
	_speed = speed
	_run = clampf(speed / maxf(sprint_speed, 0.1), 0.0, 1.0)
	# Esfuerzo: inclinación al arrancar y en el sprint.
	var effort := 0.22 if speed > 6.6 else _run * 0.1
	_lean = lerpf(_lean, clampf(accel * 0.02 + effort, -0.15, 0.35), 1.0 - exp(-8.0 * dt))
	if _event >= 0:
		_event_t += dt
		if _event_t >= _event_len:
			_event = -1
	# Barrida con la animación de Mixamo (una vez por barrida).
	if pose == Pose.SLIDING:
		if not _slide_played and _play_clip("slide"):
			_slide_played = true
	else:
		_slide_played = false
	# Derribado: se cae y, al final, se levanta (a tiempo con la simulación).
	if pose == Pose.FALLEN and tripped:
		if not _trip_played:
			_trip_played = _play_clip("trip", 1.25, true)
		elif not _getup_played and recover_left <= GETUP_TIME:
			var m: Dictionary = MixamoLibrary.marks.get("get_up", {})
			var span: float = m.get("end", 1.6) - m.get("start", 0.0)
			_getup_played = _play_clip("get_up", span / maxf(recover_left, 0.3))
	else:
		_trip_played = false
		_getup_played = false
		if _clip == "trip":
			_clip_left = 0.0 # lo reubicaron (pelota parada): vuelve a estar de pie
	if _clip != "":
		_clip_left -= dt
		if _clip_left <= 0.0:
			_clip = ""
			_current = "" # vuelve a la locomoción con mezcla
	if _clip == "":
		_play_locomotion(speed)
		_place_model()
	else:
		_model.transform = Transform3D.IDENTITY


## Gestos: con animación de Mixamo si está disponible; si no, por código.
func play(event: int, side: float = 1.0) -> void:
	if _clip.begins_with("gk_dive") and event != Event.DIVE_LEFT and event != Event.DIVE_RIGHT:
		return # ya está volando: la estirada termina (atrapa o rechaza en el aire)
	if _clip in UNINTERRUPTIBLE:
		return
	super.play(event, side)
	var clip := ""
	match event:
		Event.KICK:
			clip = "gk_kick" if keeper else "kick"
		Event.PASS:
			clip = "gk_kick" if keeper else "pass"
		Event.HEADER:
			clip = "header"
		Event.THROW:
			clip = "gk_throw" if keeper else ""
		Event.CATCH:
			clip = "gk_catch"
		Event.CATCH_HIGH:
			clip = "gk_catch_high"
		Event.CATCH_LOW:
			clip = "gk_catch_low"
		Event.BLOCK:
			clip = "gk_block"
		Event.ROLL:
			clip = "gk_roll"
		Event.TACKLE:
			clip = "tackle"
		Event.RECEIVE:
			clip = "receive"
		Event.CELEBRATE:
			clip = "celebrate"
		Event.DEJECTED:
			clip = "gk_miss" if keeper else ""
		Event.ROULETTE:
			if _mx != null and _mx.has_animation("spin"):
				var m: Dictionary = MixamoLibrary.marks["spin"]
				if _play_clip("spin", (m["end"] - m["start"]) / MatchController.ROULETTE_TIME):
					_event = -1
			return
		Event.FEINT:
			# La carga de la patada, cortada antes del golpe.
			if _mx != null and _mx.has_animation("kick"):
				var mk: Dictionary = MixamoLibrary.marks["kick"]
				var c: float = mk["contact"]
				if _play_clip("kick", 1.0, false, maxf(0.0, c - 0.4), c - 0.05):
					_event = -1
			return
		Event.DIVE_RIGHT:
			clip = "gk_dive_px"
		Event.DIVE_LEFT:
			clip = "gk_dive_nx"
	# La atajada anticipada y la de contacto son el mismo gesto: no se reinicia.
	if clip != "" and clip == _clip and clip.begins_with("gk_"):
		_event = -1
		return
	if clip != "" and _play_clip(clip):
		_event = -1 # la animación reemplaza al gesto armado por código


## Punto medio entre las manos (sigue a la atajada, la estirada y la caída).
func hold_point() -> Vector3:
	var l := _skel.find_bone("hand_l")
	var r := _skel.find_bone("hand_r")
	if l < 0 or r < 0:
		return super.hold_point()
	var mid := (_skel.get_bone_global_pose(l).origin + _skel.get_bone_global_pose(r).origin) * 0.5
	var p := _skel.global_transform * mid
	# Las manos agarran la pelota por delante de los huesos de la muñeca.
	return p + global_basis.z * 0.12


## Pie (punta del botín) o cabeza en la pose actual del gesto.
func contact_point(event: int) -> Vector3:
	var bones: Array = ["Head"] if event == Event.HEADER else ["foot_r", "ball_r"]
	var sum := Vector3.ZERO
	var n := 0
	for bn in bones:
		var b := _skel.find_bone(bn)
		if b >= 0:
			sum += _skel.get_bone_global_pose(b).origin
			n += 1
	if n == 0:
		return super.contact_point(event)
	var p := _skel.global_transform * (sum / n)
	if event == Event.HEADER:
		p += global_basis.z * 0.12 # la frente, no el centro de la cabeza
	return p


## Reproduce un clip de fútbol desde un poco antes del golpe. false si no está.
## `hold`: queda en el último cuadro hasta que otro clip lo reemplace.
func _play_clip(clip: String, speed: float = 1.0, hold: bool = false, from: float = -1.0, to: float = -1.0) -> bool:
	if _mx == null or not _mx.has_animation(clip):
		return false
	var m: Dictionary = MixamoLibrary.marks.get(clip, {})
	var start: float = m.get("start", 0.0) if from < 0.0 else from
	var end: float = m.get("end", _mx.get_animation(clip).length) if to < 0.0 else to
	_clip = clip
	_clip_left = INF if hold else (end - start) / speed
	_anim.speed_scale = speed
	_anim.play("mx/" + clip, 0.08)
	_anim.seek(start, true)
	return true


## Elige la animación de locomoción y ajusta la cadencia a la velocidad real.
func _play_locomotion(speed: float) -> void:
	var pick: Array = LOCOMOTION[0]
	for entry in LOCOMOTION:
		if speed >= float(entry[1]):
			pick = entry
	var anim_name: String = pick[0]
	if _mx != null:
		# Arquero quieto: postura de espera. Conduciendo al trote: conducción.
		if keeper and anim_name == "Idle" and _mx.has_animation("gk_idle"):
			pick = ["mx/gk_idle", 0.0, 0.0]
		elif carrying and anim_name == "Jog_Fwd" and _mx.has_animation("dribble"):
			pick = ["mx/dribble", 2.4, 2.8]
		elif keeper and absf(side_speed) > 0.6 and absf(side_speed) > speed * 0.7 and speed < 4.5 \
				and _mx.has_animation("gk_side_a"):
			# Arquero que se acomoda de costado mirando la pelota: paso lateral.
			var a_side := signf(side_speed) == MixamoLibrary.side_sign
			pick = ["mx/gk_side_a" if a_side else "mx/gk_side_b", 0.6, MixamoLibrary.side_nominal]
		anim_name = pick[0]
	if anim_name != _current:
		_current = anim_name
		_anim.play(anim_name, BLEND)
	var nominal := float(pick[2])
	_anim.speed_scale = 1.0 if nominal <= 0.0 else clampf(speed / nominal, 0.7, 1.35)


## Poses de cuerpo entero (barrida, caída, estirada, salto de cabeza): se
## mueve el modelo alrededor de la cadera, sin tocar al Footballer.
func _place_model() -> void:
	var rot := Vector3.ZERO
	var offset := Vector3.ZERO
	match _pose:
		Pose.SLIDING:
			rot.x = -1.2
			offset.y = -0.6
		Pose.FALLEN:
			rot.x = -1.45
			offset.y = -0.78
	var k := clampf(_event_t / maxf(_event_len, 0.01), 0.0, 1.0) if _event >= 0 else 0.0
	match _event:
		Event.DIVE_LEFT, Event.DIVE_RIGHT:
			# Estirada: despega, vuela de costado con los brazos extendidos y cae.
			var dir := -1.0 if _event == Event.DIVE_LEFT else 1.0
			var tilt := minf(k * 4.0, 1.0)
			rot.z = -dir * 1.45 * tilt
			offset.x = dir * 0.9 * minf(k * 2.5, 1.0)
			offset.y = 0.7 * sin(minf(k * 1.6, 1.0) * PI) - 0.55 * tilt
		Event.HEADER:
			# Salto a cabecear.
			offset.y = 0.6 * sin(k * PI)
		Event.TACKLE:
			# Entrada: se tira hacia adelante sobre la pierna.
			rot.x = 0.25 * sin(k * PI)
			offset.z = 0.35 * sin(k * PI)
		Event.KICK:
			# Remate: el cuerpo acompaña hacia adelante.
			rot.x = 0.12 * sin(k * PI)
	var pivot := Vector3(0.0, HIP_Y, 0.0)
	var basis := Basis.from_euler(rot)
	_model.transform = Transform3D(basis, pivot - basis * pivot + offset)


## Gestos que la librería no trae, aplicados sobre la pose ya animada.
func _apply_gestures() -> void:
	# Deshace lo del cuadro anterior en los huesos que la animación no volvió
	# a escribir (si no, el gesto se acumularía cuadro a cuadro).
	for b in _last_set:
		if _skel.get_bone_pose_rotation(b).is_equal_approx(_last_set[b]):
			_skel.set_bone_pose_rotation(b, _clean[b])
	_last_set.clear()
	if _clip != "":
		return # la animación de Mixamo manda
	# Inclinación del torso al acelerar / correr (esfuerzo en el sprint).
	_rotate_bone("spine_01", Vector3.RIGHT, _lean)
	if _pose == Pose.SLIDING:
		_rotate_bone("thigh_r", Vector3.RIGHT, -1.2)
		_rotate_bone("thigh_l", Vector3.RIGHT, -0.3)
		_rotate_bone("calf_l", Vector3.RIGHT, 1.1)
		_rotate_bone("upperarm_l", Vector3.FORWARD, -0.9)
		_rotate_bone("upperarm_r", Vector3.FORWARD, 0.9)
		return
	if _event < 0:
		return
	var k := clampf(_event_t / _event_len, 0.0, 1.0)
	var strike := sin(k * PI)
	match _event:
		Event.KICK, Event.PASS:
			# Carga atrás (rodilla doblada), golpe adelante y acompañamiento;
			# brazo contrario abierto para equilibrar y torso que gira.
			var power := 1.7 if _event == Event.KICK else 1.1
			var back := 1.1 if _event == Event.KICK else 0.7
			var leg := 0.0
			if k < 0.35:
				leg = lerpf(0.0, back, smoothstep(0.0, 0.35, k))
			elif k < 0.6:
				leg = lerpf(back, -power, smoothstep(0.35, 0.6, k))
			else:
				leg = lerpf(-power, 0.0, smoothstep(0.6, 1.0, k))
			_rotate_bone("thigh_r", Vector3.RIGHT, leg)
			_rotate_bone("calf_r", Vector3.RIGHT, 1.6 * maxf(0.0, leg) / maxf(back, 0.01))
			_rotate_bone("upperarm_l", Vector3.FORWARD, 1.0 * strike)
			_rotate_bone("upperarm_r", Vector3.FORWARD, -0.5 * strike)
			_rotate_bone("spine_01", Vector3.UP, 0.35 * strike)
			_rotate_bone("spine_01", Vector3.RIGHT, -0.2 * strike)
		Event.HEADER:
			_rotate_bone("spine_01", Vector3.RIGHT, lerpf(-0.6, 0.6, smoothstep(0.2, 0.7, k)))
			_rotate_bone("Head", Vector3.RIGHT, lerpf(-0.4, 0.5, smoothstep(0.2, 0.7, k)))
			_rotate_bone("upperarm_l", Vector3.FORWARD, 1.2 * strike)
			_rotate_bone("upperarm_r", Vector3.FORWARD, -1.2 * strike)
			_rotate_bone("calf_l", Vector3.RIGHT, 1.2 * strike)
			_rotate_bone("calf_r", Vector3.RIGHT, 1.0 * strike)
		Event.THROW:
			var a := lerpf(-2.9, -0.8, smoothstep(0.3, 0.8, k))
			_rotate_bone("upperarm_l", Vector3.RIGHT, a)
			_rotate_bone("upperarm_r", Vector3.RIGHT, a)
			_rotate_bone("spine_01", Vector3.RIGHT, lerpf(-0.3, 0.3, k))
		Event.STEPOVER:
			# Bicicleta: una pierna y después la otra pasan por encima de la
			# pelota (de adentro hacia afuera), con el cuerpo que acompaña.
			var first := k < 0.5
			var kk := sin(fmod(k * 2.0, 1.0) * PI)
			var leg := "thigh_r" if first else "thigh_l"
			var out := -1.0 if first else 1.0 # derecha = -X del modelo
			_rotate_bone(leg, Vector3.RIGHT, -0.7 * kk)
			_rotate_bone(leg, Vector3.FORWARD, out * 0.6 * kk)
			_rotate_bone("calf_r" if first else "calf_l", Vector3.RIGHT, 0.9 * kk)
			_rotate_bone("spine_01", Vector3.FORWARD, -out * 0.2 * kk)
		Event.CHEST:
			# Pecho afuera para bajar la pelota y brazos abiertos.
			_rotate_bone("spine_01", Vector3.RIGHT, -0.45 * strike)
			_rotate_bone("upperarm_l", Vector3.FORWARD, -0.9 * strike)
			_rotate_bone("upperarm_r", Vector3.FORWARD, 0.9 * strike)
		Event.CELEBRATE:
			_rotate_bone("upperarm_l", Vector3.RIGHT, -2.9 * minf(k * 5.0, 1.0))
			_rotate_bone("upperarm_r", Vector3.RIGHT, -2.9 * minf(k * 5.0, 1.0))
		Event.CATCH:
			_rotate_bone("upperarm_l", Vector3.RIGHT, -1.4 * strike)
			_rotate_bone("upperarm_r", Vector3.RIGHT, -1.4 * strike)
			_rotate_bone("spine_01", Vector3.RIGHT, 0.3 * strike)
		Event.TACKLE:
			_rotate_bone("thigh_r", Vector3.RIGHT, -1.4 * strike)
			_rotate_bone("calf_r", Vector3.RIGHT, 0.2 * strike)
			_rotate_bone("thigh_l", Vector3.RIGHT, 0.5 * strike)
			_rotate_bone("calf_l", Vector3.RIGHT, 1.0 * strike)
			_rotate_bone("upperarm_l", Vector3.FORWARD, 0.9 * strike)
			_rotate_bone("upperarm_r", Vector3.FORWARD, -0.9 * strike)
		Event.DIVE_LEFT, Event.DIVE_RIGHT:
			# Brazos estirados por encima de la cabeza, piernas juntas.
			var up := minf(k * 4.0, 1.0)
			_rotate_bone("upperarm_l", Vector3.RIGHT, -2.9 * up)
			_rotate_bone("upperarm_r", Vector3.RIGHT, -2.9 * up)
			_rotate_bone("lowerarm_l", Vector3.RIGHT, 0.2 * up)
			_rotate_bone("lowerarm_r", Vector3.RIGHT, 0.2 * up)


## Gira un hueso alrededor de un eje del modelo (espacio del esqueleto),
## sobre su articulación; los hijos lo acompañan. Se parte siempre de la
## rotación animada "limpia" del hueso: si la animación de este cuadro no lo
## escribió, se usa la guardada, así el gesto no se acumula cuadro a cuadro.
func _rotate_bone(bone_name: String, axis: Vector3, angle: float) -> void:
	var b: int = _bones.get(bone_name, -1)
	if b < 0:
		return
	if absf(angle) < 0.0001:
		return
	var base := _skel.get_bone_pose_rotation(b)
	if not _last_set.has(b):
		_clean[b] = base
	# Rotación global del padre armada a mano con las rotaciones locales (pedirle
	# la pose global al esqueleto lo obliga a recalcular todo: muy caro x22).
	var pg := Quaternion.IDENTITY
	var p := _skel.get_bone_parent(b)
	while p >= 0:
		pg = _skel.get_bone_pose_rotation(p) * pg
		p = _skel.get_bone_parent(p)
	var r := Quaternion(axis.normalized(), angle)
	var q := (pg.inverse() * r * pg * base).normalized()
	_skel.set_bone_pose_rotation(b, q)
	_last_set[b] = q


## Copia la malla del cuerpo marcando en el color de vértice (canal rojo) la
## zona de cada vértice según su posición en la pose de reposo (T-pose).
static func _bake_regions(src: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		colors.resize(verts.size())
		for i in verts.size():
			colors[i] = Color(_region(verts[i]) / 10.0, 0.0, 0.0)
		arrays[Mesh.ARRAY_COLOR] = colors
		var flags: int = src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return out


## Zona del cuerpo de un vértice en reposo (modelo de 1,81 m en T-pose).
static func _region(v: Vector3) -> int:
	var ax := absf(v.x)
	if v.y < 0.085:
		return 4 # botines
	if v.y < 0.47:
		return 2 # medias
	if v.y < 0.56:
		return 3 # rodillas
	if ax > 0.7:
		return 6 # manos
	if v.y < 0.98:
		return 1 if ax < 0.32 else 3 # short
	if v.y > 1.52:
		# Cabeza: pelo arriba y atrás, piel en la cara y el cuello.
		if v.y > 1.76 or (v.y > 1.6 and v.z < -0.03):
			return 5
		return 3
	if ax < 0.25:
		return 0 # torso
	return 0 if ax < 0.46 else 3 # manga corta / brazo
