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
const UNINTERRUPTIBLE := ["trip", "get_up", "celebrate", "celebrate2"]

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
var _foot_l := -1
var _foot_r := -1
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
## Material del cuerpo (colores de la ropa) y número de la espalda.
var _body_mat: ShaderMaterial
## Cuerpo del modo retro (o null) y su piel / pelo.
var _retro: MeshInstance3D
var _retro_colors := {}
var _number_label: Label3D
var carrying := false
## Lo fija el Footballer: derribado por una barrida, cuánto le falta para
## volver a jugar y velocidad de costado (+ = hacia el +X del modelo).
var tripped := false
## Arquero con la pelota en las manos: brazos que la sostienen contra el pecho.
var holding := false
## Postura parado (formación, espera): AUTO = brazos al costado; HEART = mano
## en el pecho; BEHIND = manos atrás; HIPS = manos en la cintura. `look_yaw`
## gira la cabeza (radianes, + = hacia su izquierda).
enum Stance { AUTO, RELAXED, HEART, BEHIND, HIPS }
var stance: int = Stance.AUTO
var look_yaw := 0.0
var _breath := 0.0
## Físico (PlayerData.Build): escala visible por zona y altura total.
## [panza baja, panza alta, pecho, grosor de brazo, de muslo, de pantorrilla, altura]
const BUILDS := {
	PlayerData.Build.NORMAL: [Vector3(1, 1, 1), Vector3(1.02, 1, 1.02), Vector3(1.14, 1, 1.12), 1.0, 1.0, 1.0, 1.0],
	PlayerData.Build.HEAVY: [Vector3(1.26, 1, 1.45), Vector3(1.3, 1, 1.55), Vector3(1.2, 1, 1.2), 1.12, 1.16, 1.08, 0.99],
	PlayerData.Build.SLIM: [Vector3(0.9, 1, 0.9), Vector3(0.9, 1, 0.88), Vector3(1.0, 1, 0.95), 0.86, 0.88, 0.88, 1.02],
	PlayerData.Build.TALL: [Vector3(1, 1, 1), Vector3(1, 1, 1), Vector3(1.1, 1, 1.08), 0.97, 0.97, 0.97, 1.08],
	PlayerData.Build.SHORT: [Vector3(1, 1, 1), Vector3(1.02, 1, 1.02), Vector3(1.12, 1, 1.1), 1.0, 1.03, 1.02, 0.91],
	PlayerData.Build.STOCKY: [Vector3(1.1, 1, 1.12), Vector3(1.14, 1, 1.14), Vector3(1.26, 1, 1.2), 1.12, 1.16, 1.1, 0.95],
	PlayerData.Build.MUSCULAR: [Vector3(1, 1, 1), Vector3(1.06, 1, 1.06), Vector3(1.3, 1, 1.22), 1.22, 1.14, 1.1, 1.0],
}
const BOOTS := Vector3(1.2, 1.15, 1.15)
var body_build: int = PlayerData.Build.NORMAL
var _height := 1.0
var _build_scales := {}
## Peinado (HairBuilder.Style) y su malla.
var hair_style: int = -1
var hair_node: MeshInstance3D
var recover_left := 0.0
var side_speed := 0.0
## Velocidad hacia adelante (negativa = retrocede); la fija el Footballer.
var forward_speed := 0.0
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
	for n in ["pelvis", "spine_01", "spine_03", "neck_01", "thigh_l", "thigh_r", "calf_l", "calf_r",
			"hand_l", "hand_r",
			"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "Head"]:
		_bones[n] = _skel.find_bone(n)
	_bake_stands()

	_foot_l = _skel.find_bone("foot_l")
	_foot_r = _skel.find_bone("foot_r")
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
		# Peinado con volumen (malla aparte pegada a la cabeza). Debajo, el cuero
		# cabelludo va del color del pelo, salvo si arriba no hay pelo.
		var hair_color: Color = HAIR_TONES[rng.randi() % HAIR_TONES.size()]
		hair_style = int(colors.get("hair_style", rng.randi() % HairBuilder.Style.size()))
		set_build(int(colors.get("build", PlayerData.Build.NORMAL)))
		var scalp := hair_color
		if hair_style in [HairBuilder.Style.SHAVED, HairBuilder.Style.HORSESHOE]:
			scalp = skin.darkened(0.08)
		mat.set_shader_parameter("hair", scalp)
		_add_hair(hair_style, hair_color, colors.get("shirt", Color.WHITE))
		mat.set_shader_parameter("hands", colors.get("gloves", skin))
		mat.set_shader_parameter("trim", _trim_for(shirt, colors.get("shorts", Color.WHITE)))
		body.material_override = mat
		_body_mat = mat
	# Modo retro (beta): el modelo de pocos polígonos sobre el mismo esqueleto.
	if GameSettings.player_style == 1 and RetroBody.available() and body != null:
		_retro_colors = {"skin": SKIN_TONES[rng.randi() % SKIN_TONES.size()], "hair": HAIR_TONES[rng.randi() % HAIR_TONES.size()]}
		var rc := colors.duplicate()
		rc.merge(_retro_colors)
		_retro = RetroBody.build(_skel, rc)
		if _retro != null:
			body.visible = false
			if hair_node != null:
				hair_node.visible = false
			for extra in ["Eyebrows", "Eyes"]:
				var em := _skel.find_child(extra, false, false) as Node3D
				if em != null:
					em.visible = false
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


## Vivos de la camiseta: el color del short, o la camiseta más oscura si se
## confunden.
static func _trim_for(shirt: Color, shorts: Color) -> Color:
	if shorts.is_equal_approx(shirt) or absf(shorts.get_luminance() - shirt.get_luminance()) < 0.08:
		return shirt.darkened(0.35)
	return shorts


## Cambia la ropa (un jugador de campo que va al arco: camiseta y guantes de
## arquero, con su número).
func recolor(colors: Dictionary) -> void:
	if _retro != null:
		var rc := colors.duplicate()
		rc.merge(_retro_colors)
		RetroBody.recolor(_retro, rc)
	if _body_mat != null:
		var shirt: Color = colors.get("shirt", Color.WHITE)
		_body_mat.set_shader_parameter("shirt", shirt)
		_body_mat.set_shader_parameter("socks", colors.get("socks", shirt))
		if colors.has("shorts"):
			_body_mat.set_shader_parameter("shorts", colors["shorts"])
		if colors.has("gloves"):
			_body_mat.set_shader_parameter("hands", colors["gloves"])
		_body_mat.set_shader_parameter("trim", _trim_for(shirt, colors.get("shorts", Color.WHITE)))
	if _number_label != null:
		_color_number(_number_label, colors.get("shirt", Color.WHITE))
		if colors.has("number"):
			_number_label.text = str(colors["number"])


## Fija el físico: calcula la escala de cada hueso. Escalar un hueso escala a
## sus hijos, así que cada hijo se compensa (en sus ejes, según su rotación de
## reposo) para que, por ejemplo, el pecho ancho no ensanche la cabeza.
func set_build(b: int) -> void:
	body_build = b if BUILDS.has(b) else PlayerData.Build.NORMAL
	var d: Array = BUILDS[body_build]
	_height = PlayerData.BUILD_HEIGHT.get(body_build, d[6])
	_build_scales.clear()
	var arm := Vector3(d[3], 1.0, d[3])
	var low := Vector3(lerpf(1.0, d[3], 0.7), 1.0, lerpf(1.0, d[3], 0.7))
	var thigh := Vector3(d[4], 1.0, d[4])
	var calf := Vector3(d[5], 1.0, d[5])
	_chain("spine_01", Vector3.ONE, d[0])
	_chain("spine_02", d[0], d[1])
	_chain("spine_03", d[1], d[2])
	_chain("neck_01", d[2], Vector3.ONE)
	for side in ["l", "r"]:
		_chain("clavicle_" + side, d[2], Vector3.ONE)
		_chain("upperarm_" + side, Vector3.ONE, arm)
		_chain("lowerarm_" + side, arm, low)
		_chain("hand_" + side, low, Vector3.ONE)
		_chain("thigh_" + side, Vector3.ONE, thigh)
		_chain("calf_" + side, thigh, calf)
		_chain("foot_" + side, calf, BOOTS)


## Escala de `bone` para que se vea `visible` aunque el padre esté escalado
## `parent_visible` (aproximada: se toma la diagonal del cambio de ejes).
func _chain(bone: String, parent_visible: Vector3, visible: Vector3) -> void:
	var b := _skel.find_bone(bone)
	if b < 0:
		return
	var r := _skel.get_bone_rest(b).basis.orthonormalized()
	var m := r.transposed() * Basis.from_scale(Vector3.ONE / parent_visible) * r
	var sc := Vector3(absf(m.x.x), absf(m.y.y), absf(m.z.z)) * visible
	if not sc.is_equal_approx(Vector3.ONE):
		_build_scales[b] = sc


## Pelo: la malla de HairBuilder sigue al hueso de la cabeza. Está armada en el
## espacio de reposo del esqueleto, así que se compensa la pose de reposo.
func _add_hair(style: int, color: Color, band_color: Color) -> void:
	var m := HairBuilder.mesh(style)
	if m == null:
		return
	var head := _skel.find_bone("Head")
	var att := BoneAttachment3D.new()
	att.name = "Hair"
	att.bone_idx = head
	_skel.add_child(att)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.transform = _skel.get_bone_global_rest(head).affine_inverse()
	mi.set_surface_override_material(0, HairBuilder.material(color))
	if m.get_surface_count() > 1:
		var b := band_color if band_color.get_luminance() > 0.2 else Color(0.95, 0.95, 0.95)
		mi.set_surface_override_material(1, _mat(b))
	att.add_child(mi)
	hair_node = mi


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
	_color_number(label, shirt)
	_number_label = label
	label.double_sided = false
	label.shaded = true
	attach.add_child(label)
	# Pose deseada en el espacio del modelo (espalda = -Z, mirando hacia atrás),
	# pasada al espacio del hueso en reposo.
	var rest := _skel.get_bone_global_rest(bone)
	var desired := Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, rest.origin.y + 0.02, -0.16))
	label.transform = rest.affine_inverse() * desired


## Número oscuro sobre camiseta clara y claro sobre oscura.
static func _color_number(label: Label3D, shirt: Color) -> void:
	var light_shirt := shirt.get_luminance() > 0.55
	label.modulate = Color(0.08, 0.08, 0.1) if light_shirt else Color(0.97, 0.97, 0.97)
	label.outline_modulate = Color(0.97, 0.97, 0.97, 0.6) if light_shirt else Color(0.05, 0.05, 0.08, 0.6)


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
		_model.transform = Transform3D(Basis.from_scale(Vector3.ONE * _height), Vector3.ZERO)


## Gestos: con animación de Mixamo si está disponible; si no, por código.
func play(event: int, side: float = 1.0) -> void:
	played.emit(event, side)
	if _clip.begins_with("gk_dive") and event != Event.DIVE_LEFT and event != Event.DIVE_RIGHT:
		return # ya está volando: la estirada termina (atrapa o rechaza en el aire)
	if _clip in UNINTERRUPTIBLE:
		return
	super.play(event, side)
	var clip := ""
	match event:
		Event.KICK:
			# Remate (la patada vieja queda de respaldo).
			clip = "gk_kick" if keeper else ("shot" if _mx != null and _mx.has_animation("shot") else "kick")
		Event.PASS:
			clip = "gk_kick" if keeper else "pass"
		Event.HEADER:
			# `side` trae la altura de la pelota: sin salto, normal o con saltito.
			clip = "header"
			if side < 1.85 and _mx != null and _mx.has_animation("header_stand"):
				clip = "header_stand"
			elif side > 2.15 and _mx != null and _mx.has_animation("header_jump"):
				clip = "header_jump"
		Event.THROW:
			clip = "gk_throw" if keeper else "throw_in"
		Event.CATCH:
			clip = "gk_catch"
		Event.CATCH_HIGH:
			# `side` trae la altura: muy alta es cortar un centro.
			clip = "gk_catch_high"
			if side > 2.3 and _mx != null and _mx.has_animation("gk_catch_cross"):
				clip = "gk_catch_cross"
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
			# Uno de los festejos disponibles, al azar.
			var options := []
			for c in ["celebrate", "celebrate2"]:
				if _mx != null and _mx.has_animation(c):
					options.append(c)
			clip = options[randi() % options.size()] if not options.is_empty() else "celebrate"
		Event.CHEST:
			clip = "chest"
		Event.DEJECTED:
			clip = "gk_miss" if keeper else ""
		Event.ROULETTE:
			if _mx != null and _mx.has_animation("spin"):
				var m: Dictionary = MixamoLibrary.marks["spin"]
				if _play_clip("spin", (m["end"] - m["start"]) / MatchController.ROULETTE_TIME):
					_event = -1
			return
		Event.FEINT:
			# Amague (X + Cuadrado): el clip propio si está.
			if _mx != null and _mx.has_animation("feint") and _play_clip("feint"):
				_event = -1
				return
			# Si no, la carga de la patada, cortada antes del golpe.
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


## Entre las dos manos, sin adelantarla (lateral: la pelota atrás de la nuca).
func throw_point() -> Vector3:
	var l := _skel.find_bone("hand_l")
	var r := _skel.find_bone("hand_r")
	if l < 0 or r < 0:
		return global_position + Vector3(0, 2.0, 0)
	var mid := (_skel.get_bone_global_pose(l).origin + _skel.get_bone_global_pose(r).origin) * 0.5
	return _skel.global_transform * mid + Vector3(0, 0.06, 0)


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
	# Parado (jugador de campo): de pie y derecho, no en guardia como el Idle
	# de la librería; los brazos los acomoda _apply_stance.
	# El arquero también, si está en la formación (postura elegida).
	var formal := keeper and stance != Stance.AUTO
	var stand := "Stand_%d" % (stance if stance != Stance.AUTO else Stance.RELAXED)
	if anim_name == "Idle" and (not keeper or formal) and _anim_lib.has_animation(stand):
		pick = [stand, 0.0, 0.0]
		anim_name = stand
	if _mx != null:
		# Arquero quieto: postura de espera. Conduciendo al trote: conducción.
		if keeper and not formal and anim_name == "Idle" and _mx.has_animation("gk_idle"):
			pick = ["mx/gk_idle", 0.0, 0.0]
		elif carrying and anim_name == "Jog_Fwd" and _mx.has_animation("dribble"):
			pick = ["mx/dribble", 2.4, 2.8]
		elif not keeper and forward_speed < -1.0 and speed > 1.0 and _mx.has_animation("jog_back"):
			# Retrocede mirando la jugada: trote hacia atrás.
			pick = ["mx/jog_back", 1.0, MixamoLibrary.nominal.get("jog_back", 2.0)]
		elif anim_name == "Jog_Fwd" and _mx.has_animation("jog"):
			pick = ["mx/jog", 2.4, MixamoLibrary.nominal.get("jog", 3.5)]
		elif anim_name == "Sprint" and _mx.has_animation("sprint"):
			pick = ["mx/sprint", 6.6, MixamoLibrary.nominal.get("sprint", 7.0)]
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
	var h := Basis.from_scale(Vector3.ONE * _height)
	_model.transform = Transform3D(basis * h, pivot * _height - basis * (pivot * _height) + offset)


## Gestos que la librería no trae, aplicados sobre la pose ya animada.
func _apply_gestures() -> void:
	# Deshace lo del cuadro anterior en los huesos que la animación no volvió
	# a escribir (si no, el gesto se acumularía cuadro a cuadro).
	for b in _last_set:
		if _skel.get_bone_pose_rotation(b).is_equal_approx(_last_set[b]):
			_skel.set_bone_pose_rotation(b, _clean[b])
	_last_set.clear()
	# Físico: escala por hueso (pecho, panza, brazos, piernas, botines).
	for b in _build_scales:
		_skel.set_bone_pose_scale(b, _build_scales[b])
	if _clip != "":
		return # la animación de Mixamo manda
	# Inclinación del torso al acelerar / correr (esfuerzo en el sprint).
	_rotate_bone("spine_01", Vector3.RIGHT, _lean)
	if _current.begins_with("Stand_") and not holding:
		_apply_stance()
	if throw_hold and _event < 0 and not holding:
		# Lateral: brazos arriba con los codos doblados, la pelota atrás de la
		# nuca (sobre los brazos al costado de la postura de parado).
		for side in ["l", "r"]:
			var sgn := 1.0 if side == "l" else -1.0
			_rotate_bone("upperarm_" + side, Vector3.RIGHT, throw_pose.x)
			_rotate_bone("upperarm_" + side, Vector3.FORWARD, sgn * throw_pose.y)
			_rotate_bone("lowerarm_" + side, Vector3.RIGHT, throw_pose.z)
	if holding and _event < 0:
		# Pelota contra el pecho: brazos adelante, hacia el centro, y los
		# antebrazos doblados hacia arriba.
		_rotate_bone("upperarm_l", Vector3.RIGHT, -0.95)
		_rotate_bone("upperarm_r", Vector3.RIGHT, -0.95)
		_rotate_bone("upperarm_l", Vector3.UP, -0.45)
		_rotate_bone("upperarm_r", Vector3.UP, 0.45)
		_rotate_bone("lowerarm_l", Vector3.RIGHT, -0.7)
		_rotate_bone("lowerarm_r", Vector3.RIGHT, -0.7)
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
		Event.HANDSHAKE:
			# Apretón de manos del saludo: el que espera estira la derecha hacia
			# adelante (side > 0); el que pasa caminando, hacia su derecha.
			var reach := smoothstep(0.0, 0.3, k) * (1.0 - smoothstep(0.75, 1.0, k))
			if _event_side > 0.0:
				_rotate_bone("upperarm_r", Vector3.RIGHT, -0.95 * reach)
				_rotate_bone("lowerarm_r", Vector3.RIGHT, -0.35 * reach)
			else:
				_rotate_bone("upperarm_r", Vector3.FORWARD, 0.6 * reach)
				_rotate_bone("upperarm_r", Vector3.RIGHT, -0.45 * reach)
				_rotate_bone("lowerarm_r", Vector3.RIGHT, -0.3 * reach)
		Event.HIGH_FIVE:
			# Choque de manos: la derecha sube adelante, a la altura de la
			# cabeza, y vuelve (sobre los brazos al costado de la postura o
			# de la caminata).
			var up := smoothstep(0.0, 0.3, k) * (1.0 - smoothstep(0.7, 1.0, k))
			_rotate_bone("upperarm_r", Vector3.RIGHT, -1.85 * up)
			_rotate_bone("upperarm_r", Vector3.UP, 0.2 * up)
			_rotate_bone("lowerarm_r", Vector3.RIGHT, -0.55 * up)
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
		Event.CHEER:
			# Brazos arriba festejando desde donde está (los puños suben y bajan).
			var up := minf(k * 6.0, 1.0) * minf((1.0 - k) * 6.0, 1.0)
			var pump := 0.15 * sin(k * 18.0)
			_rotate_bone("upperarm_l", Vector3.RIGHT, (-2.7 + pump) * up)
			_rotate_bone("upperarm_r", Vector3.RIGHT, (-2.7 - pump) * up)
			_rotate_bone("lowerarm_l", Vector3.RIGHT, -0.4 * up)
			_rotate_bone("lowerarm_r", Vector3.RIGHT, -0.4 * up)
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


## Parado: respiración leve y la cabeza girada `look_yaw` (los brazos ya
## vienen en la animación "Stand_<postura>", ver _bake_stands).
func _apply_stance() -> void:
	_breath += get_process_delta_time() * 1.6
	var b := sin(_breath) * 0.02
	_rotate_bone("spine_01", Vector3.RIGHT, 0.03 + b)
	if absf(look_yaw) > 0.01:
		_rotate_bone("neck_01", Vector3.UP, look_yaw * 0.6)
		_rotate_bone("Head", Vector3.UP, look_yaw * 0.4)


## Brazos de cada postura, sobre la pose en T de la librería.
func _stance_arms(st: int) -> void:
	match st:
		Stance.HEART:
			_arm_down("l", 0.12)
			# Mano derecha sobre el pecho (lado izquierdo del cuerpo).
			_rotate_bone("upperarm_r", Vector3.FORWARD, -(ARM_DOWN - 0.3))
			_rotate_bone("upperarm_r", Vector3.RIGHT, -0.15)
			_rotate_bone("lowerarm_r", Vector3.RIGHT, -1.6)
			_rotate_bone("lowerarm_r", Vector3.UP, 1.75)
		Stance.BEHIND:
			for side in ["l", "r"]:
				var sgn := 1.0 if side == "l" else -1.0
				_rotate_bone("upperarm_" + side, Vector3.FORWARD, sgn * (ARM_DOWN - 0.1))
				_rotate_bone("upperarm_" + side, Vector3.RIGHT, 0.22)
				_rotate_bone("lowerarm_" + side, Vector3.UP, sgn * 1.75)
		Stance.HIPS:
			for side in ["l", "r"]:
				var sgn := 1.0 if side == "l" else -1.0
				_rotate_bone("upperarm_" + side, Vector3.FORWARD, sgn * (ARM_DOWN - 0.6))
				_rotate_bone("lowerarm_" + side, Vector3.FORWARD, sgn * 1.7)
		_:
			_arm_down("l", 0.1)
			_arm_down("r", 0.1)


## Animaciones de parado (una por postura): la pose en T de la librería con
## los brazos ya acomodados. Al mezclar parado <-> caminar nunca aparecen los
## brazos extendidos (antes se bajaban por código sólo con la pose en T
## activa, y en la mezcla o con un gesto se veía la T).
const ARM_BONES := ["clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r"]
static var _stands_baked := false

func _bake_stands() -> void:
	if _stands_baked or not _anim_lib.has_animation("A_TPose"):
		return
	var src: Animation = _anim_lib.get_animation("A_TPose")
	var prefix := ""
	for ti in src.get_track_count():
		var path := src.track_get_path(ti)
		if path.get_subname_count() > 0:
			prefix = String(path.get_concatenated_names())
			break
	for st in [Stance.RELAXED, Stance.HEART, Stance.BEHIND, Stance.HIPS]:
		_skel.reset_bone_poses()
		for ti in src.get_track_count():
			var path := src.track_get_path(ti)
			if path.get_subname_count() == 0:
				continue
			var bone := _skel.find_bone(String(path.get_subname(0)))
			if bone < 0:
				continue
			match src.track_get_type(ti):
				Animation.TYPE_ROTATION_3D:
					_skel.set_bone_pose_rotation(bone, src.rotation_track_interpolate(ti, 0.0))
				Animation.TYPE_POSITION_3D:
					_skel.set_bone_pose_position(bone, src.position_track_interpolate(ti, 0.0))
		_clean.clear()
		_last_set.clear()
		_stance_arms(st)
		var anim := src.duplicate(true) as Animation
		for bone_name in ARM_BONES:
			var bone := _skel.find_bone(bone_name)
			if bone < 0:
				continue
			var q := _skel.get_bone_pose_rotation(bone)
			var tpath := NodePath(prefix + ":" + bone_name)
			var ti := anim.find_track(tpath, Animation.TYPE_ROTATION_3D)
			if ti < 0:
				ti = anim.add_track(Animation.TYPE_ROTATION_3D)
				anim.track_set_path(ti, tpath)
				anim.rotation_track_insert_key(ti, 0.0, q)
			else:
				for k in anim.track_get_key_count(ti):
					anim.track_set_key_value(ti, k, q)
		_anim_lib.add_animation("Stand_%d" % st, anim)
	_clean.clear()
	_last_set.clear()
	_skel.reset_bone_poses()
	_stands_baked = true


## Brazos de la pose en T llevados al costado del cuerpo (codo apenas doblado).
const ARM_DOWN := 1.42
func _arm_down(side: String, elbow: float) -> void:
	var sgn := 1.0 if side == "l" else -1.0
	_rotate_bone("upperarm_" + side, Vector3.FORWARD, sgn * ARM_DOWN)
	_rotate_bone("lowerarm_" + side, Vector3.RIGHT, -elbow)


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
			var v := verts[i]
			var r := _region(v)
			colors[i] = Color(r / 10.0, 1.0 if (r == 0 and absf(v.x) < 0.26) else 0.0, 1.0 if _is_trim(v, r) else 0.0)
		arrays[Mesh.ARRAY_COLOR] = colors
		var flags: int = src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return out


## Ribetes de la ropa: cuello, puños de las mangas, ruedo de la camiseta y
## del short (se pintan con el color secundario).
static func _is_trim(v: Vector3, region: int) -> bool:
	var ax := absf(v.x)
	if region == 0:
		return (v.y > 1.47 and ax < 0.13) or (ax > 0.42 and ax < 0.46) or v.y < 1.01
	if region == 1:
		return v.y < 0.61
	return false


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
