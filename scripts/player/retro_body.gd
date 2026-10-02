class_name RetroBody
extends RefCounted
## Modo visual "retro" (estilo PlayStation 1, beta): el modelo base de pocos
## polígonos (assets/models/players/retro/, libre) vestido sobre el esqueleto
## de nuestros jugadores, así usa todas
## las animaciones y los físicos.
##   - Se escala a la altura del esqueleto y los brazos (en pose A) se suben a
##     la pose T de reposo.
##   - Cada vértice queda pegado entero al hueso más cercano (sin mezclas,
##     como los muñecos de PS1).
##   - Se pinta por zonas con colores planos (camiseta, short, medias,
##     botines, piel, pelo, guantes) y sombreado por vértice.

const OBJ_PATH := "res://assets/models/players/retro/psx_male_base_mesh.obj"
## Altura a la que se escala (punta de la cabeza) y apertura de los brazos del
## modelo (grados por debajo de la horizontal).
const TARGET_HEIGHT := 1.78
const ARM_DROP_DEG := 56.0

enum Region { SKIN, HAIR, SHIRT, SHORTS, SOCKS, BOOTS, GLOVES }

## Huesos con su punta (segmento al que se acerca cada vértice).
const SEGMENTS := [
	["pelvis", "spine_01"], ["spine_01", "spine_02"], ["spine_02", "spine_03"], ["spine_03", "neck_01"],
	["neck_01", "Head"], ["Head", ""],
	["clavicle_l", "upperarm_l"], ["upperarm_l", "lowerarm_l"], ["lowerarm_l", "hand_l"], ["hand_l", ""],
	["clavicle_r", "upperarm_r"], ["upperarm_r", "lowerarm_r"], ["lowerarm_r", "hand_r"], ["hand_r", ""],
	["thigh_l", "calf_l"], ["calf_l", "foot_l"], ["foot_l", "ball_l"], ["ball_l", ""],
	["thigh_r", "calf_r"], ["calf_r", "foot_r"], ["foot_r", "ball_r"], ["ball_r", ""],
]

static var _cache := {}


static func available() -> bool:
	return ResourceLoader.exists(OBJ_PATH)


## Malla con piel y zonas para un esqueleto (se calcula una vez).
## {"arrays": arrays de la superficie, "skin": Skin, "regions": PackedInt32Array}
static func prepare(sk: Skeleton3D) -> Dictionary:
	if _cache.has("data"):
		return _cache["data"]
	var src: Mesh = load(OBJ_PATH)
	if src == null:
		return {}
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	# Altura del modelo y escala.
	var lo := INF
	var hi := -INF
	for v in verts:
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
	var s := TARGET_HEIGHT / maxf(hi - lo, 0.01)
	var rest := {}
	for i in sk.get_bone_count():
		rest[sk.get_bone_name(i)] = sk.get_bone_global_rest(i).origin
	var shoulder_y: float = rest["upperarm_l"].y
	var shoulder_x: float = absf(rest["upperarm_l"].x)
	var a := deg_to_rad(ARM_DROP_DEG)
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	out_v.resize(verts.size())
	out_n.resize(verts.size())
	for i in verts.size():
		var v := Vector3(verts[i].x, verts[i].y - lo, verts[i].z) * s
		var n := normals[i] if i < normals.size() else Vector3.UP
		# Brazos: de la pose A a la T (giro alrededor del hombro).
		if absf(v.x) > shoulder_x * 0.9 and v.y > shoulder_y - 0.62:
			var side := signf(v.x)
			var pivot := Vector3(side * shoulder_x, shoulder_y, v.z)
			var rot := Basis(Vector3.FORWARD, -side * a)
			v = pivot + rot * (v - pivot)
			n = rot * n
		out_v[i] = v
		out_n[i] = n
	# Hueso más cercano (rígido) y zona de color.
	var used := {}
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var regions := PackedInt32Array()
	bones.resize(out_v.size() * 4)
	weights.resize(out_v.size() * 4)
	regions.resize(out_v.size())
	var tips := {"Head": Vector3(0, 0.17, 0), "hand_l": Vector3(0.14, 0, 0), "hand_r": Vector3(-0.14, 0, 0),
		"ball_l": Vector3(0, 0, 0.08), "ball_r": Vector3(0, 0, 0.08)}
	for i in out_v.size():
		var v := out_v[i]
		var best := ""
		var best_d := INF
		var best_t := 0.0
		for seg in SEGMENTS:
			if not rest.has(seg[0]):
				continue
			var p0: Vector3 = rest[seg[0]]
			var p1: Vector3 = rest[seg[1]] if seg[1] != "" and rest.has(seg[1]) else p0 + tips.get(seg[0], Vector3(0, 0.1, 0))
			var ab := p1 - p0
			var t := clampf((v - p0).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
			var d := v.distance_to(p0 + ab * t)
			if d < best_d:
				best_d = d
				best = seg[0]
				best_t = t
		var bone := sk.find_bone(best)
		if not used.has(bone):
			used[bone] = used.size()
		bones[i * 4] = used[bone]
		weights[i * 4] = 1.0
		regions[i] = _region(best, best_t, v, rest)
	var skin := Skin.new()
	for bone in used:
		skin.add_bind(bone, sk.get_bone_global_rest(bone).affine_inverse())
	# Triángulos sueltos (sin vértices compartidos): cada cara de un solo
	# color y con su propia normal, como los modelos de PS1.
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(out_v.size()))
	var fv := PackedVector3Array()
	var fn := PackedVector3Array()
	var fb := PackedInt32Array()
	var fw := PackedFloat32Array()
	var fr := PackedInt32Array()
	for f in range(0, idx.size() - 2, 3):
		var tri := [idx[f], idx[f + 1], idx[f + 2]]
		var c := (out_v[tri[0]] + out_v[tri[1]] + out_v[tri[2]]) / 3.0
		var face_n := (out_v[tri[1]] - out_v[tri[0]]).cross(out_v[tri[2]] - out_v[tri[0]]).normalized()
		if face_n.dot(out_n[tri[0]] + out_n[tri[1]] + out_n[tri[2]]) < 0.0:
			face_n = -face_n
		var region := _face_region(c, rest, sk)
		for k in tri:
			fv.append(out_v[k])
			fn.append(face_n)
			for j in 4:
				fb.append(bones[k * 4 + j])
				fw.append(weights[k * 4 + j])
			fr.append(region)
	regions = fr
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = fv
	arr[Mesh.ARRAY_NORMAL] = fn
	arr[Mesh.ARRAY_BONES] = fb
	arr[Mesh.ARRAY_WEIGHTS] = fw
	var data := {"arrays": arr, "skin": skin, "regions": regions}
	_cache["data"] = data
	return data


## Zona de color de una cara (por su centro): el hueso más cercano y dónde cae.
static func _face_region(c: Vector3, rest: Dictionary, sk: Skeleton3D) -> int:
	var tips := {"Head": Vector3(0, 0.17, 0), "hand_l": Vector3(0.14, 0, 0), "hand_r": Vector3(-0.14, 0, 0),
		"ball_l": Vector3(0, 0, 0.08), "ball_r": Vector3(0, 0, 0.08)}
	var best := ""
	var best_d := INF
	var best_t := 0.0
	for seg in SEGMENTS:
		if not rest.has(seg[0]):
			continue
		var p0: Vector3 = rest[seg[0]]
		var p1: Vector3 = rest[seg[1]] if seg[1] != "" and rest.has(seg[1]) else p0 + tips.get(seg[0], Vector3(0, 0.1, 0))
		var ab := p1 - p0
		var t := clampf((c - p0).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var d := c.distance_to(p0 + ab * t)
		if d < best_d:
			best_d = d
			best = seg[0]
			best_t = t
	return _region(best, best_t, c, rest)


## Zona de color de un vértice según su hueso y dónde cae sobre él.
static func _region(bone: String, t: float, v: Vector3, rest: Dictionary) -> int:
	match bone:
		"Head":
			return Region.HAIR if v.y > float(rest["Head"].y) + 0.1 or (v.z < float(rest["Head"].z) - 0.06 and v.y > float(rest["Head"].y) + 0.02) else Region.SKIN
		"neck_01":
			return Region.SKIN
		"spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r":
			return Region.SHIRT
		"pelvis":
			return Region.SHIRT if v.y > float(rest["pelvis"].y) + 0.08 else Region.SHORTS
		"upperarm_l", "upperarm_r":
			return Region.SHIRT if t < 0.55 else Region.SKIN
		"lowerarm_l", "lowerarm_r":
			return Region.SKIN
		"hand_l", "hand_r":
			return Region.GLOVES
		"thigh_l", "thigh_r", "calf_l", "calf_r":
			# Piernas: por la altura respecto de la rodilla (las caras son
			# largas y cruzan de un hueso al otro).
			var knee: float = rest["calf_l"].y
			if v.y > knee + 0.03:
				return Region.SHORTS
			return Region.SKIN if v.y > knee - 0.1 else Region.SOCKS
	return Region.BOOTS


## Arma el cuerpo retro sobre el esqueleto: devuelve el MeshInstance3D.
static func build(sk: Skeleton3D, colors: Dictionary) -> MeshInstance3D:
	var data := prepare(sk)
	if data.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.name = "RetroBody"
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = data["skin"]
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.roughness = 1.0
	mi.material_override = mat
	recolor(mi, colors)
	return mi


## Pinta las zonas con los colores del jugador (rehace la malla: son pocos
## vértices).
static func recolor(mi: MeshInstance3D, colors: Dictionary) -> void:
	var data: Dictionary = _cache.get("data", {})
	if data.is_empty() or mi == null:
		return
	var regions: PackedInt32Array = data["regions"]
	var shirt: Color = colors.get("shirt", Color.WHITE)
	var skin: Color = colors.get("skin", Color(0.87, 0.67, 0.5))
	var palette := {
		Region.SKIN: skin,
		Region.HAIR: colors.get("hair", Color(0.08, 0.06, 0.05)),
		Region.SHIRT: shirt,
		Region.SHORTS: colors.get("shorts", Color.BLACK),
		Region.SOCKS: colors.get("socks", shirt),
		Region.BOOTS: colors.get("boots", Color(0.06, 0.06, 0.06)),
		Region.GLOVES: colors.get("gloves", skin),
	}
	var cols := PackedColorArray()
	cols.resize(regions.size())
	for i in regions.size():
		cols[i] = palette[regions[i]]
	var arr: Array = (data["arrays"] as Array).duplicate()
	arr[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mi.mesh = mesh
