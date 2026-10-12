class_name WeBody
extends RefCounted
## Diseño Definitivo WE: el jugador de pocos polígonos hecho en Blender
## (estilo ForeverEleven / WE2002), sobre el esqueleto del juego.
## El modelo sale de tools/blender/we_definitivo.py (o del .blend editado a
## mano) y se exporta a assets/models/players/we_definitivo.glb con los
## mismos huesos que el cuerpo detallado: usa todas las animaciones.
##
## Cada material del modelo es una ZONA de la ropa; acá se pasa al color de
## vértice que lee player_body.gdshader (camiseta, short, medias, piel,
## botines, pelo, manos), así los colores, el diseño de la camiseta y el
## número son los del club. La posición de reposo va en CUSTOM0 (el diseño y
## el número se pintan en la tela).

const GLB_PATH := "res://assets/models/players/we_definitivo.glb"

## Material del .glb -> [zona del shader, torso (diseño y número), ribete].
const ZONES := {
	"camiseta": [0, true, false],
	"manga": [0, false, false],
	"ribete_camiseta": [0, false, true],
	"short": [1, false, false],
	"ribete_short": [1, false, true],
	"medias": [2, false, false],
	"piel": [3, false, false],
	"botines": [4, false, false],
	"pelo": [5, false, false],
	"manos": [6, false, false],
}
const DEFAULT_ZONE := [3, false, false]

static var _cache := {}


static func available() -> bool:
	return ResourceLoader.exists(GLB_PATH)


## Malla (una superficie, con zonas) y piel para el esqueleto `sk`; se arma
## una vez. {"arrays": arrays, "skin": Skin, "flags": formato}
static func prepare(sk: Skeleton3D) -> Dictionary:
	if _cache.has("data"):
		return _cache["data"]
	var scene: PackedScene = load(GLB_PATH) if available() else null
	if scene == null:
		return {}
	var root := scene.instantiate()
	var mi: MeshInstance3D = _find_mesh(root)
	if mi == null or mi.mesh == null or mi.skin == null:
		root.free()
		return {}
	var src_skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	# Piel: mismos índices que el .glb, apuntando a los huesos del juego por
	# nombre (el modelo se arma sobre ese mismo esqueleto).
	var skin := Skin.new()
	for i in mi.skin.get_bind_count():
		var bone_name := String(mi.skin.get_bind_name(i))
		if bone_name == "" and src_skel != null:
			bone_name = src_skel.get_bone_name(mi.skin.get_bind_bone(i))
		var bone := sk.find_bone(bone_name)
		if bone < 0:
			push_warning("WeBody: el hueso %s no está en el esqueleto del juego" % bone_name)
			bone = 0
		skin.add_bind(bone, mi.skin.get_bind_pose(i))
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var rest := PackedFloat32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var idx := PackedInt32Array()
	var mesh := mi.mesh
	var flags := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var mat := mesh.surface_get_material(s)
		var zname := mat.resource_name if mat != null else ""
		var z: Array = ZONES.get(zname, DEFAULT_ZONE)
		var col := Color(float(z[0]) / 10.0, 1.0 if z[1] else 0.0, 1.0 if z[2] else 0.0)
		var sv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var sb: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var sw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		flags |= mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		var base := v.size()
		for i in sv.size():
			v.append(sv[i])
			n.append(sn[i])
			c.append(col)
			rest.append_array([sv[i].x, sv[i].y, sv[i].z, 0.0])
		bones.append_array(sb)
		weights.append_array(sw)
		var si: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(sv.size()))
		for k in si:
			idx.append(base + k)
	root.free()
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = v
	out[Mesh.ARRAY_NORMAL] = n
	out[Mesh.ARRAY_COLOR] = c
	out[Mesh.ARRAY_CUSTOM0] = rest
	out[Mesh.ARRAY_BONES] = bones
	out[Mesh.ARRAY_WEIGHTS] = weights
	out[Mesh.ARRAY_INDEX] = idx
	flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	var data := {"arrays": out, "skin": skin, "flags": flags}
	_cache["data"] = data
	return data


static func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).skin != null:
		return n
	for ch in n.get_children():
		var r := _find_mesh(ch)
		if r != null:
			return r
	return null


## Arma el cuerpo sobre el esqueleto con el material de la ropa (o null si
## falta el modelo).
static func build(sk: Skeleton3D, material: Material) -> MeshInstance3D:
	var data := prepare(sk)
	if data.is_empty():
		return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data["arrays"], [], {}, data["flags"])
	var mi := MeshInstance3D.new()
	mi.name = "WeBody"
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = data["skin"]
	mi.mesh = mesh
	mi.material_override = material
	return mi
