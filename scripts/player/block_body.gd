class_name BlockBody
extends RefCounted
## Cuerpo "de bloques" (tipo Minecraft, con la base del WE2002): cada parte es
## una caja rígida pegada a su hueso (cabeza cúbica, torso, brazo, antebrazo,
## mano, muslo, pierna, botín), así las rodillas y los codos se doblan con
## las mismas animaciones de siempre. Usa el armado de ClassicBody (tubos de 4
## lados = cajas) y lleva lo mismo para el shader de la ropa (zonas, posición
## de reposo y UV del uniforme), así la camiseta, el número y el escudo se
## pintan igual.

const Zone := ClassicBody.Zone
const R2 := 1.41421356

static var _cache := {}


## Anillo cuadrado: `hx`, `hz` son medio ancho y medio fondo de la caja.
static func _sq(center: Vector3, hx: float, hz: float, bone: int, zone: int, torso := false, trim := false) -> Dictionary:
	return ClassicBody._ring(center, hx * R2, hz * R2, [[bone, 1.0]], zone, torso, trim)


## Igual, con el peso repartido entre dos huesos (cintura).
static func _sq2(center: Vector3, hx: float, hz: float, a: int, b: int, zone: int, torso := false) -> Dictionary:
	return ClassicBody._ring(center, hx * R2, hz * R2, [[a, 0.5], [b, 0.5]], zone, torso)


static func prepare(sk: Skeleton3D) -> Dictionary:
	if _cache.has("data"):
		return _cache["data"]
	var b := func(n: String) -> int: return sk.find_bone(n)
	var parts: Array = []
	var Y := Vector3.UP
	var X := Vector3.RIGHT
	var pelvis := b.call("pelvis") as int
	var sp1 := b.call("spine_01") as int
	var sp2 := b.call("spine_02") as int
	var sp3 := b.call("spine_03") as int
	var neck := b.call("neck_01") as int
	var head := b.call("Head") as int
	# Torso: dos cajas (cadera y pecho) para que se doble en la cintura.
	parts.append([Y, 4, [
		_sq(Vector3(0, 0.92, -0.02), 0.165, 0.1, pelvis, Zone.SHIRT, true, true),
		_sq(Vector3(0, 0.945, -0.02), 0.165, 0.1, pelvis, Zone.SHIRT, true),
		_sq2(Vector3(0, 1.12, -0.02), 0.165, 0.1, sp1, sp2, Zone.SHIRT, true),
		_sq(Vector3(0, 1.3, -0.02), 0.18, 0.105, sp3, Zone.SHIRT, true),
		_sq(Vector3(0, 1.465, -0.02), 0.18, 0.105, sp3, Zone.SHIRT, true),
		_sq(Vector3(0, 1.49, -0.02), 0.18, 0.105, sp3, Zone.SHIRT, true, true),
	], ClassicBody.UV_TORSO])
	# Cuello.
	parts.append([Y, 4, [
		_sq(Vector3(0, 1.47, -0.02), 0.05, 0.05, neck, Zone.SKIN),
		_sq(Vector3(0, 1.585, -0.02), 0.05, 0.05, neck, Zone.SKIN),
	], ClassicBody.UV_NONE])
	# Cabeza cúbica; arriba y atrás, el pelo (lo pinta el shader). La cara la
	# dibuja el shader en el frente.
	parts.append([Y, 4, [
		_sq(Vector3(0, 1.575, 0.0), 0.105, 0.11, head, Zone.SKIN),
		_sq(Vector3(0, 1.745, 0.0), 0.105, 0.11, head, Zone.SKIN),
		_sq(Vector3(0, 1.75, 0.0), 0.107, 0.112, head, Zone.HAIR),
		_sq(Vector3(0, 1.8, 0.0), 0.107, 0.112, head, Zone.HAIR),
	], ClassicBody.UV_NONE])
	for side: float in [1.0, -1.0]:
		var sfx := "_l" if side > 0.0 else "_r"
		var clav := b.call("clavicle" + sfx) as int
		var upper := b.call("upperarm" + sfx) as int
		var lower := b.call("lowerarm" + sfx) as int
		var hand := b.call("hand" + sfx) as int
		var thigh := b.call("thigh" + sfx) as int
		var calf := b.call("calf" + sfx) as int
		var foot := b.call("foot" + sfx) as int
		var ax := X * side
		var sleeve_uv := ClassicBody.UV_SLEEVE_L if side > 0.0 else ClassicBody.UV_SLEEVE_R
		# Hombro y manga (camiseta), brazo, antebrazo y mano: cajas separadas,
		# el codo se dobla entre brazo y antebrazo.
		parts.append([ax, 4, [
			_sq(Vector3(side * 0.15, 1.44, -0.035), 0.06, 0.06, clav, Zone.SHIRT),
			_sq(Vector3(side * 0.25, 1.44, -0.04), 0.062, 0.062, upper, Zone.SHIRT),
			_sq(Vector3(side * 0.325, 1.445, -0.05), 0.062, 0.062, upper, Zone.SHIRT),
			_sq(Vector3(side * 0.34, 1.445, -0.05), 0.062, 0.062, upper, Zone.SHIRT, false, true),
		], sleeve_uv])
		parts.append([ax, 4, [
			_sq(Vector3(side * 0.335, 1.445, -0.05), 0.05, 0.05, upper, Zone.SKIN),
			_sq(Vector3(side * 0.47, 1.445, -0.055), 0.05, 0.05, upper, Zone.SKIN),
		], ClassicBody.UV_NONE])
		parts.append([ax, 4, [
			_sq(Vector3(side * 0.465, 1.445, -0.058), 0.046, 0.046, lower, Zone.SKIN),
			_sq(Vector3(side * 0.67, 1.445, -0.06), 0.042, 0.042, lower, Zone.SKIN),
		], ClassicBody.UV_NONE])
		parts.append([ax, 4, [
			_sq(Vector3(side * 0.67, 1.445, -0.06), 0.04, 0.03, hand, Zone.HANDS),
			_sq(Vector3(side * 0.79, 1.445, -0.06), 0.04, 0.03, hand, Zone.HANDS),
		], ClassicBody.UV_NONE])
		# Short y muslo; la rodilla se dobla entre muslo y pierna.
		var lx := side * 0.095
		parts.append([-Y, 4, [
			_sq2(Vector3(lx, 0.98, -0.025), 0.085, 0.09, pelvis, thigh, Zone.SHORTS),
			_sq(Vector3(lx, 0.82, -0.03), 0.085, 0.09, thigh, Zone.SHORTS),
			_sq(Vector3(lx, 0.715, -0.03), 0.085, 0.09, thigh, Zone.SHORTS),
			_sq(Vector3(lx, 0.7, -0.03), 0.085, 0.09, thigh, Zone.SHORTS, false, true),
		], ClassicBody.UV_SHORTS_L if side > 0.0 else ClassicBody.UV_SHORTS_R])
		parts.append([-Y, 4, [
			_sq(Vector3(lx, 0.705, -0.03), 0.065, 0.07, thigh, Zone.SKIN),
			_sq(Vector3(lx, 0.5, -0.03), 0.065, 0.07, thigh, Zone.SKIN),
		], ClassicBody.UV_NONE])
		parts.append([-Y, 4, [
			_sq(Vector3(lx, 0.505, -0.035), 0.06, 0.065, calf, Zone.SOCKS),
			_sq(Vector3(lx, 0.09, -0.05), 0.055, 0.06, calf, Zone.SOCKS),
		], ClassicBody.UV_SOCK_L if side > 0.0 else ClassicBody.UV_SOCK_R])
		# Botín: caja larga del talón a la punta.
		parts.append([Vector3.BACK, 4, [
			_sq(Vector3(lx, 0.04, -0.08), 0.05, 0.04, foot, Zone.BOOTS),
			_sq(Vector3(lx, 0.04, 0.13), 0.05, 0.04, foot, Zone.BOOTS),
		], ClassicBody.UV_NONE])
	var st := {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(),
		"rest": PackedFloat32Array(), "uv": PackedVector2Array(), "b": PackedInt32Array(), "w": PackedFloat32Array()}
	var used := {}
	for part in parts:
		ClassicBody._tube(st, part[0], part[1], part[2], used, part[3])
	var skin := Skin.new()
	var order: Array = used.keys()
	for bi in order:
		skin.add_bind(bi, sk.get_bone_global_rest(bi).affine_inverse())
	var remap := {}
	for i in order.size():
		remap[order[i]] = i
	var bones: PackedInt32Array = st["b"]
	for i in bones.size():
		bones[i] = remap.get(bones[i], 0)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = st["v"]
	arr[Mesh.ARRAY_NORMAL] = st["n"]
	arr[Mesh.ARRAY_COLOR] = st["c"]
	arr[Mesh.ARRAY_TEX_UV] = st["uv"]
	arr[Mesh.ARRAY_CUSTOM0] = st["rest"]
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = st["w"]
	var data := {"arrays": arr, "skin": skin}
	_cache["data"] = data
	return data


static func build(sk: Skeleton3D, material: Material) -> MeshInstance3D:
	var data := prepare(sk)
	var mesh := ArrayMesh.new()
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data["arrays"], [], {}, flags)
	var mi := MeshInstance3D.new()
	mi.name = "BlockBody"
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = data["skin"]
	mi.mesh = mesh
	mi.material_override = material
	return mi


## Peinado de bloques (en el espacio de reposo; se pega al hueso Head como
## los otros): cajas sobre la cabeza cúbica. null = pelado o corto (lo pinta
## el shader sobre la cabeza).
static func hair_mesh(style: int) -> ArrayMesh:
	var key := "hair_%d" % style
	if _cache.has(key):
		return _cache[key]
	var boxes: Array = [] # [centro, medio tamaño]
	var top := 1.8
	var S := HairBuilder.Style
	match style:
		S.SHAVED, S.HORSESHOE, S.FADE, S.CORNROWS:
			boxes = []
		S.HELMET, S.SIDE_PART:
			boxes = [[Vector3(0, top + 0.012, -0.005), Vector3(0.115, 0.014, 0.12)]]
		S.MOHAWK:
			boxes = [[Vector3(0, top + 0.035, -0.01), Vector3(0.025, 0.035, 0.11)]]
		S.QUIFF:
			boxes = [[Vector3(0, top + 0.015, -0.01), Vector3(0.112, 0.016, 0.117)],
				[Vector3(0, top + 0.04, 0.07), Vector3(0.08, 0.025, 0.045)]]
		S.FRINGE:
			boxes = [[Vector3(0, top + 0.012, 0.0), Vector3(0.113, 0.014, 0.118)],
				[Vector3(0, 1.755, 0.112), Vector3(0.1, 0.03, 0.01)]]
		S.AFRO:
			boxes = [[Vector3(0, top + 0.03, -0.01), Vector3(0.14, 0.05, 0.14)]]
		S.PONYTAIL:
			boxes = [[Vector3(0, top + 0.01, 0.0), Vector3(0.112, 0.012, 0.117)],
				[Vector3(0, 1.7, -0.14), Vector3(0.03, 0.08, 0.03)]]
		S.CURLY_BAND, S.LONG_PARTED, S.DREADS:
			boxes = [[Vector3(0, top + 0.015, 0.0), Vector3(0.118, 0.018, 0.12)],
				[Vector3(0, 1.62, -0.105), Vector3(0.118, 0.17, 0.018)],
				[Vector3(0.112, 1.68, -0.02), Vector3(0.012, 0.11, 0.1)],
				[Vector3(-0.112, 1.68, -0.02), Vector3(0.012, 0.11, 0.1)]]
	if style == S.CURLY_BAND:
		boxes.append([Vector3(0, 1.745, 0.0), Vector3(0.121, 0.016, 0.124), "band"])
	if boxes.is_empty():
		_cache[key] = null
		return null
	var mesh := ArrayMesh.new()
	for surf in ["hair", "band"]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 0
		for bx in boxes:
			var is_band: bool = bx.size() > 2
			if is_band != (surf == "band"):
				continue
			_box(st, bx[0], bx[1])
			n += 1
		if n == 0:
			continue
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, surf)
	_cache[key] = mesh
	return mesh


static func _box(st: SurfaceTool, c: Vector3, h: Vector3) -> void:
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		var o := c + n * h
		var ha := a * h
		var hb := b * h
		var q := [o - ha - hb, o + ha - hb, o + ha + hb, o - ha + hb]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_uv(Vector2((idx % 2) * 0.5, (idx / 2) * 0.5))
			st.add_vertex(q[idx])
