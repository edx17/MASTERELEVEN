class_name MixamoLibrary
extends RefCounted
## Animaciones de fútbol de Mixamo pasadas (retarget) al esqueleto de nuestros
## jugadores. Los FBX NO van en el repositorio (licencia de Mixamo: se pueden
## usar en el juego, no redistribuir sueltos): se leen de
## res://assets/animations/mixamo/ si están en la copia local. Sin ellos, el
## juego usa los gestos armados por código.
##
## Retarget: para cada hueso mapeado se toma cuánto giró (en el espacio del
## modelo) respecto de su pose de reposo en Mixamo y se aplica ese mismo giro
## sobre la pose de reposo de nuestro hueso (los dos esqueletos en T-pose,
## mirando a +Z). El desplazamiento horizontal de la cadera se descarta (al
## jugador lo mueve la simulación); la altura se escala a nuestro modelo.

const DIR := "res://assets/animations/mixamo/"
const FPS := 30.0
const PREFIX := "mixamorig_"

## Hueso de Mixamo -> hueso nuestro (Quaternius / estilo UE).
const BONE_MAP := {
	"Hips": "pelvis", "Spine": "spine_01", "Spine1": "spine_02", "Spine2": "spine_03",
	"Neck": "neck_01", "Head": "Head",
	"LeftShoulder": "clavicle_l", "LeftArm": "upperarm_l", "LeftForeArm": "lowerarm_l", "LeftHand": "hand_l",
	"RightShoulder": "clavicle_r", "RightArm": "upperarm_r", "RightForeArm": "lowerarm_r", "RightHand": "hand_r",
	"LeftUpLeg": "thigh_l", "LeftLeg": "calf_l", "LeftFoot": "foot_l", "LeftToeBase": "ball_l",
	"RightUpLeg": "thigh_r", "RightLeg": "calf_r", "RightFoot": "foot_r", "RightToeBase": "ball_r",
}

## Clips que usa el juego: nombre -> opciones.
##   file: archivo (sin .fbx). mirror: espejado (el otro lado). loop: en bucle.
##   lateral: cuánto del vuelo de costado de la cadera se conserva (estiradas).
##   face: se descarta el giro del cuerpo que trae el clip (el rumbo lo manda
##     la simulación; p. ej. el control que en Mixamo termina mirando atrás).
##   range: [inicio, golpe, fin] en segundos (si no, se buscan en el clip).
##   full: se reproduce entero (festejos).
const CLIPS := {
	"kick": {"file": "Kick_Soccerball"},
	"shot": {"file": "remate"},
	"pass": {"file": "Soccer Pass"},
	"header": {"file": "Soccer Header"},
	# Carrera: trote, sprint y trote hacia atrás. La velocidad natural de cada
	# uno sale de cuánto avanza la cadera en un ciclo.
	"jog": {"file": "Jog Forward", "loop": true},
	"sprint": {"file": "Sprint", "loop": true},
	"jog_back": {"file": "Jog Backward", "loop": true},
	# Chilena: el salto de espaldas arranca un poco antes del golpe.
	"chilena": {"file": "Scissor chilena Kick", "face": true, "range": [0.45, 0.75, 2.75]},
	# Arranque desde parado (R1) y giro brusco en carrera (el rumbo lo manda la
	# simulación; el clip pone el apoyo y la inclinación; espejado, al otro lado).
	"sprint_start": {"file": "Idle To Sprint", "range": [0.0, 0.0, 0.8]},
	"sprint_turn": {"file": "Sprint Turn", "face": true, "range": [0.0, 0.3, 0.8]},
	"sprint_turn_m": {"file": "Sprint Turn", "face": true, "mirror": true, "range": [0.0, 0.3, 0.8]},
	# Lesionado: trote rengo; tirado en el piso tras una falta.
	"injured_jog": {"file": "Lesionado andando Injured Jog", "loop": true},
	"fallen_idle": {"file": "Fallen Idle", "loop": true},
	# Cabezazo sin salto (pelota a la altura de la cabeza) y con un saltito;
	# amague X + Cuadrado; control de pecho; lateral.
	"header_stand": {"file": "No jump Header"},
	"header_jump": {"file": "Soccer Header little jump"},
	"feint": {"file": "XCuadrado Chip", "face": true},
	"chest": {"file": "Receive pecho", "face": true},
	"throw_in": {"file": "Throw In", "face": true},
	"slide": {"file": "Soccer Tackle"},
	"dribble": {"file": "Dribble", "loop": true},
	# Entrada de pie (X): sólo la estocada con la pierna, sin la caída.
	"tackle": {"file": "Soccer_Tackle_1", "face": true, "range": [0.45, 0.72, 0.9]},
	# Control con la suela al recibir un pase.
	"receive": {"file": "Receive_Soccerball", "face": true, "range": [0.75, 1.0, 1.6]},
	# Caída tras una barrida y cómo se levanta.
	"trip": {"file": "foul", "face": true, "range": [0.0, 0.5, 1.6]},
	"get_up": {"file": "Standing Up", "face": true},
	# Falta de atrás: cae de espaldas y queda sentado.
	"trip_back": {"file": "caida de atras Hit On Legs", "face": true, "range": [0.0, 0.4, 4.06]},
	# Festejos (ver Celebrations: el preferido del jugador o uno al azar).
	"celebrate": {"file": "Festejo1 Catwheel", "face": true, "full": true},
	"celebrate2": {"file": "Festejo2 Golf Putt", "face": true, "full": true},
	"cel_backflip": {"file": "Festejo Backflip", "face": true, "full": true},
	"cel_capoeira": {"file": "Festejo Capoeira", "face": true, "full": true},
	"cel_turn": {"file": "Festejo Final Running To Turn", "face": true, "full": true},
	"cel_rifle": {"file": "Festejo Rifle Start Run", "face": true, "full": true, "loop": true},
	"cel_crawl": {"file": "Festejo Running Crawl", "face": true, "full": true, "loop": true},
	"cel_spider": {"file": "Festejo Spider Low Crawl", "face": true, "full": true, "loop": true},
	"cel_flair": {"file": "festejo Flair", "face": true, "full": true, "loop": true},
	"cel_horse": {"file": "festejo Gangnam Style", "face": true, "full": true},
	"cel_moonwalk": {"file": "festejo Moonwalk", "face": true, "full": true, "loop": true},
	"cel_robot": {"file": "festejo Robot Hip Hop Dance", "face": true, "full": true},
	# Marsellesa: el giro de 360° lo pone el clip (el rumbo del jugador no gira).
	"spin": {"file": "Soccer Spin", "range": [0.0, 0.6, 1.27]},
	"gk_idle": {"file": "Goalkeeper Idle", "loop": true},
	# Ordena a la defensa: con la pelota lejos o mientras la tiene en las manos.
	"gk_directing": {"file": "Goalkeeper Directing", "loop": true},
	# Salta, la agarra y se tira encima (para hacer tiempo; pelota dividida).
	"gk_smother": {"file": "GoalkeeperReceiver Catch", "face": true, "range": [0.7, 1.0, 3.45]},
	"gk_catch": {"file": "Goalkeeper Catch stay"},
	"gk_catch_high": {"file": "Goalkeeper Catch jump"},
	"gk_catch_low": {"file": "Goalkeeper Scoop"},
	"gk_catch_cross": {"file": "Goalkeeper Catch corta centro", "face": true},
	"gk_block": {"file": "Goalkeeper_Body_Block", "face": true, "range": [0.2, 0.75, 1.9]},
	"gk_miss": {"file": "Goalkeeper Miss", "face": true},
	"gk_throw": {"file": "Goalkeeper sque rapido"},
	"gk_roll": {"file": "Goalkeeper hand short Pass"},
	"gk_kick": {"file": "Goalkeeper Drop Kick"},
	"gk_side_a": {"file": "Goalkeeper Sidestep achique", "loop": true, "face": true},
	"gk_side_b": {"file": "Goalkeeper Sidestep achique", "loop": true, "face": true, "mirror": true},
	# La estirada va hacia -X del modelo (su derecha); hacia +X es la misma,
	# espejada.
	"gk_dive_px": {"file": "Goalkeeper Diving Save", "mirror": true, "lateral": 0.6},
	"gk_dive_nx": {"file": "Goalkeeper Diving Save", "lateral": 0.6},
}

static var _lib: AnimationLibrary
## Por clip: {start, contact, end} en segundos (tramo que se reproduce y
## momento del golpe, para que el gesto coincida con la pelota).
static var marks := {}
static var _checked := false
static var _dive_contact := 1.0
## Sentido (+1/-1 en X del modelo) hacia el que se desplaza el paso lateral
## del arquero sin espejar ("gk_side_a"); el espejado va al revés.
static var side_sign := 1.0
## Velocidad de costado (m/s) a la que ese paso se ve natural.
static var side_nominal := 1.5
## Clips en bucle: velocidad (m/s) a la que se ven naturales.
static var nominal := {}
## Desplazamiento de la cadera de Mixamo en el último clip adaptado.
static var _last_travel := Vector3.ZERO
static var _last_height_ratio := 1.0
## Giro propio (radianes, + = hacia su izquierda) al final del último clip con
## `face`, y el del giro en carrera sin espejar.
static var _last_yaw := 0.0
static var turn_sign := 1.0


## Construye (una vez) la librería con los clips disponibles. `body` es un
## modelo nuestro instanciado (para leer su esqueleto en reposo).
static func library(body_scene: PackedScene) -> AnimationLibrary:
	if _checked:
		return _lib
	_checked = true
	if not DirAccess.dir_exists_absolute(DIR):
		return null
	var body := body_scene.instantiate()
	var target := body.find_child("Skeleton3D", true, false) as Skeleton3D
	var lib := AnimationLibrary.new()
	for clip_name in CLIPS:
		var spec: Dictionary = CLIPS[clip_name]
		var path := file_path(spec["file"])
		if path == "":
			continue
		var anim := _retarget(path, target, spec)
		if anim != null:
			lib.add_animation(clip_name, anim)
			if spec.get("loop", false):
				# Velocidad a la que el clip se ve natural (m/s del jugador).
				nominal[clip_name] = clampf(Vector2(_last_travel.x, _last_travel.z).length() * _last_height_ratio / maxf(anim.length, 0.01), 0.5, 9.0)
			if clip_name == "sprint_turn":
				turn_sign = 1.0 if _last_yaw >= 0.0 else -1.0
			if clip_name == "gk_side_a":
				side_sign = 1.0 if _last_travel.x >= 0.0 else -1.0
				side_nominal = clampf(absf(_last_travel.x) * _last_height_ratio / anim.length, 0.8, 3.0)
			if spec.get("full", false):
				marks[clip_name] = {"start": 0.0, "contact": 0.0, "end": anim.length}
			elif spec.has("range"):
				var r: Array = spec["range"]
				marks[clip_name] = {"start": r[0], "contact": r[1], "end": minf(r[2], anim.length)}
			else:
				marks[clip_name] = _marks(clip_name, anim, target)
	body.free()
	if lib.get_animation_list().is_empty():
		return null
	_lib = lib
	return _lib


## Ruta del FBX en la copia local. Acepta el nombre con guiones bajos
## ("Goalkeeper_Catch_1"), con espacios ("Goalkeeper Catch 1") o como lo
## numera Windows al bajar varias versiones ("Goalkeeper Catch (1)").
## Vacío si no está.
static func file_path(file: String) -> String:
	for candidate in file_candidates(file):
		var path: String = DIR + candidate + ".fbx"
		if ResourceLoader.exists(path):
			return path
	return ""


static func file_candidates(file: String) -> Array[String]:
	var spaced := file.replace("_", " ")
	var out: Array[String] = [file, spaced]
	# Variante numerada: "Nombre_1" -> "Nombre (1)".
	var parts := file.rsplit("_", true, 1)
	if parts.size() == 2 and parts[1].is_valid_int():
		out.append("%s (%s)" % [parts[0].replace("_", " "), parts[1]])
	return out


static func _retarget(path: String, target: Skeleton3D, spec: Dictionary) -> Animation:
	var mirror: bool = spec.get("mirror", false)
	var loop: bool = spec.get("loop", false)
	var lateral: float = spec.get("lateral", 0.0)
	var face: bool = spec.get("face", false)
	var src_scene := (load(path) as PackedScene).instantiate()
	var src := src_scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := src_scene.find_children("*", "AnimationPlayer", true, false)
	if src == null or player.is_empty():
		src_scene.free()
		return null
	var ap := player[0] as AnimationPlayer
	var src_anim := ap.get_animation(ap.get_animation_list()[0])

	# Pistas de la animación de origen por hueso.
	var rot_track := {}
	var hips_pos_track := -1
	for t in src_anim.get_track_count():
		var bone := String(src_anim.track_get_path(t).get_concatenated_subnames())
		match src_anim.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				rot_track[bone] = t
			Animation.TYPE_POSITION_3D:
				if bone == PREFIX + "Hips":
					hips_pos_track = t

	var src_rest_g := _global_rest_rotations(src)
	var tgt_rest_g := _global_rest_rotations(target)
	var src_hips := src.find_bone(PREFIX + "Hips")
	var tgt_pelvis := target.find_bone("pelvis")
	var height_ratio := target.get_bone_global_rest(tgt_pelvis).origin.y / maxf(src.get_bone_global_rest(src_hips).origin.y, 0.01)

	# Hueso nuestro -> hueso de Mixamo (con espejo: el del otro lado).
	var tgt_to_src := {}
	for mx in BONE_MAP:
		var ours: String = BONE_MAP[mx]
		var from: String = mx
		if mirror:
			from = mx.replace("Left", "#").replace("Right", "Left").replace("#", "Right")
		var sb := src.find_bone(PREFIX + from)
		var tb := target.find_bone(ours)
		if sb >= 0 and tb >= 0:
			tgt_to_src[tb] = sb

	var out := Animation.new()
	out.length = src_anim.length
	out.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var out_track := {}
	for tb in tgt_to_src:
		var tr := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(tr, NodePath("Armature/Skeleton3D:" + target.get_bone_name(tb)))
		out_track[tb] = tr
	var pos_tr := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(pos_tr, NodePath("Armature/Skeleton3D:pelvis"))
	var pelvis_parent := target.get_bone_parent(tgt_pelvis)
	var parent_rest := target.get_bone_global_rest(pelvis_parent) if pelvis_parent >= 0 else Transform3D.IDENTITY
	var pelvis_rest_g := target.get_bone_global_rest(tgt_pelvis).origin

	# Estiradas: el vuelo lateral se mide desde el inicio del tramo que se
	# reproduce (0,2 s antes del momento de vuelo más rápido).
	var base_x := 0.0
	if lateral > 0.0 and hips_pos_track >= 0:
		_dive_contact = _fastest_x_time(src_anim, hips_pos_track)
		base_x = (src_anim.position_track_interpolate(hips_pos_track, maxf(0.0, _dive_contact - 0.2)) as Vector3).x
	_last_travel = Vector3.ZERO
	_last_height_ratio = height_ratio
	if hips_pos_track >= 0:
		_last_travel = src_anim.position_track_interpolate(hips_pos_track, src_anim.length) - src_anim.position_track_interpolate(hips_pos_track, 0.0)
	var frames := int(ceil(src_anim.length * FPS))
	for f in frames + 1:
		var time := minf(f / FPS, src_anim.length)
		# Rotaciones globales de Mixamo en este instante.
		var src_g := {}
		for b in src.get_bone_count():
			var local: Quaternion = src.get_bone_rest(b).basis.get_rotation_quaternion()
			var bname := src.get_bone_name(b)
			if rot_track.has(bname):
				local = src_anim.rotation_track_interpolate(rot_track[bname], time)
			var p := src.get_bone_parent(b)
			src_g[b] = (src_g[p] * local) if p >= 0 else local
		# Giro propio del clip (alrededor del eje vertical) a descartar.
		var unturn := Quaternion.IDENTITY
		if face and src_hips >= 0:
			var hd: Quaternion = src_g[src_hips] * (src_rest_g[src_hips] as Quaternion).inverse()
			if mirror:
				hd = Quaternion(hd.x, -hd.y, -hd.z, hd.w)
			var yaw_q := Quaternion(0.0, hd.y, 0.0, hd.w).normalized()
			unturn = yaw_q.inverse()
			_last_yaw = yaw_q.get_euler().y
		# Rotaciones globales nuestras y paso a locales.
		var tgt_g := {}
		for tb in target.get_bone_count():
			var p := target.get_bone_parent(tb)
			var parent_g: Quaternion = tgt_g[p] if p >= 0 else Quaternion.IDENTITY
			if tgt_to_src.has(tb):
				var sb: int = tgt_to_src[tb]
				var delta: Quaternion = src_g[sb] * (src_rest_g[sb] as Quaternion).inverse()
				if mirror:
					delta = Quaternion(delta.x, -delta.y, -delta.z, delta.w)
				var g: Quaternion = (unturn * delta * tgt_rest_g[tb]).normalized()
				tgt_g[tb] = g
				out.rotation_track_insert_key(out_track[tb], time, (parent_g.inverse() * g).normalized())
			else:
				tgt_g[tb] = parent_g * target.get_bone_rest(tb).basis.get_rotation_quaternion()
		# Altura de la cadera (sin desplazamiento horizontal).
		var y := pelvis_rest_g.y
		var x := pelvis_rest_g.x
		if hips_pos_track >= 0:
			var hp: Vector3 = src_anim.position_track_interpolate(hips_pos_track, time)
			y = hp.y * height_ratio
			x += (hp.x - base_x) * height_ratio * lateral * (-1.0 if mirror else 1.0)
		var world := Vector3(x, y, pelvis_rest_g.z)
		out.position_track_insert_key(pos_tr, time, parent_rest.affine_inverse() * world)
	src_scene.free()
	return out


static func _global_rest_rotations(sk: Skeleton3D) -> Dictionary:
	var g := {}
	for b in sk.get_bone_count():
		var local := sk.get_bone_rest(b).basis.get_rotation_quaternion()
		var p := sk.get_bone_parent(b)
		g[b] = (g[p] * local) if p >= 0 else local
	return g


## Momento del golpe de cada clip (buscado en la animación) y tramo a usar.
static func _marks(clip_name: String, anim: Animation, target: Skeleton3D) -> Dictionary:
	var contact := anim.length * 0.4
	match clip_name:
		"kick", "shot", "pass", "gk_kick":
			contact = _fastest_time(anim, target, "foot_r")
		"gk_throw":
			contact = _fastest_time(anim, target, "hand_r")
		"header":
			contact = _highest_hips_time(anim, target)
		"gk_dive_px", "gk_dive_nx":
			contact = _dive_contact
		"slide":
			contact = anim.length * 0.35
		"gk_catch", "receive":
			contact = anim.length * 0.3
	# Los golpes se disparan en el instante del contacto: el clip arranca
	# apenas antes (el pie ya viene bajando). Atajadas y saques, con algo de
	# anticipación.
	# La pelota sale en el instante de la orden (como en WE): el clip arranca
	# justo en el golpe para que el pie (o la cabeza) esté en la pelota.
	var lead := 0.03 if clip_name in ["kick", "shot", "pass", "gk_kick", "header"] else 0.3
	if clip_name.begins_with("gk_dive"):
		lead = 0.2 # el remate ya salió: el vuelo arranca enseguida
	var start := maxf(0.0, contact - lead)
	var end := minf(anim.length, contact + 0.6)
	if clip_name.begins_with("gk_dive"):
		end = minf(anim.length, contact + 1.1)
	return {"start": start, "contact": contact, "end": end}


## Momento del golpe: cuando el hueso (pie/mano) llega al 80 % de su punto
## más adelantado (el contacto con la pelota, un poco antes del final del gesto).
static func _fastest_time(anim: Animation, target: Skeleton3D, bone_name: String) -> float:
	var chain: Array[int] = []
	var b := target.find_bone(bone_name)
	while b >= 0:
		chain.push_front(b)
		b = target.get_bone_parent(b)
	var tracks := {}
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			tracks[target.find_bone(String(anim.track_get_path(t).get_concatenated_subnames()))] = t
	var samples: Array[Vector2] = [] # (tiempo, z)
	var step := 1.0 / FPS
	var time := 0.0
	while time <= anim.length:
		var xf := Transform3D.IDENTITY
		for bone in chain:
			var rest := target.get_bone_rest(bone)
			var rot: Quaternion = anim.rotation_track_interpolate(tracks[bone], time) if tracks.has(bone) else rest.basis.get_rotation_quaternion()
			xf = xf * Transform3D(Basis(rot), rest.origin)
		samples.append(Vector2(time, xf.origin.z))
		time += step
	var z0 := samples[0].y
	var zmax := z0
	for smp in samples:
		zmax = maxf(zmax, smp.y)
	for smp in samples:
		if smp.y >= z0 + (zmax - z0) * 0.8:
			return smp.x
	return anim.length * 0.4


## Momento en que la cadera (de Mixamo) se desplaza más rápido de costado.
static func _fastest_x_time(anim: Animation, track: int) -> float:
	var best := anim.length * 0.3
	var best_v := 0.0
	var step := 1.0 / FPS
	var prev: float = (anim.position_track_interpolate(track, 0.0) as Vector3).x
	var time := step
	while time <= anim.length:
		var x: float = (anim.position_track_interpolate(track, time) as Vector3).x
		var v := absf(x - prev) / step
		if v > best_v:
			best_v = v
			best = time
		prev = x
		time += step
	return best


static func _highest_hips_time(anim: Animation, target: Skeleton3D) -> float:
	# La pista guarda la posición local de la cadera (en el espacio de su
	# padre, que está rotado): se pasa a altura real con la pose de reposo.
	var pelvis := target.find_bone("pelvis")
	var parent := target.get_bone_parent(pelvis)
	var parent_rest := target.get_bone_global_rest(parent) if parent >= 0 else Transform3D.IDENTITY
	var tr := -1
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
			tr = t
	if tr < 0:
		return anim.length * 0.5
	var best := 0.0
	var best_y := -INF
	var time := 0.0
	while time <= anim.length:
		var y: float = (parent_rest * (anim.position_track_interpolate(tr, time) as Vector3)).y
		if y > best_y:
			best_y = y
			best = time
		time += 1.0 / FPS
	return best
