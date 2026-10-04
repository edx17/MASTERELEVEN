class_name ClassicBody
extends RefCounted
## Cuerpo "clásico" (como los jugadores del WE de PS1): pocos polígonos, caras
## planas y proporciones de un jugador normal (no un físico de superhéroe),
## armado por código sobre el esqueleto del juego, así usa todas las
## animaciones. Cada parte es un "tubo" de pocas caras entre anillos; cada
## anillo va pegado a un hueso (en las articulaciones, mitad y mitad).
##
## La malla lleva lo mismo que el cuerpo detallado para el shader de la
## ropa (player_body.gdshader): la zona en el color de vértice y la posición
## de reposo en CUSTOM0, así el diseño de la camiseta, el número de la espalda
## y el escudo se pintan en la tela.

## Zonas (las del shader): 0 camiseta, 1 short, 2 medias, 3 piel, 4 botines,
## 5 pelo, 6 manos.
enum Zone { SHIRT, SHORTS, SOCKS, SKIN, BOOTS, HAIR, HANDS }

static var _cache := {}

## Un anillo: centro, radios (en sus dos ejes perpendiculares al tubo), hueso
## (o dos con su peso) y zona; "torso" marca la tela lisa del pecho/espalda y
## "trim" un ribete (cuello, ruedo, puño).
static func _ring(center: Vector3, ra: float, rb: float, bones: Array, zone: int, torso := false, trim := false) -> Dictionary:
	return {"c": center, "ra": ra, "rb": rb, "bones": bones, "zone": zone, "torso": torso, "trim": trim}


## Arma (y guarda) los arrays de la malla para el esqueleto dado.
static func prepare(sk: Skeleton3D) -> Dictionary:
	if _cache.has("data"):
		return _cache["data"]
	var b := func(n: String) -> int: return sk.find_bone(n)
	var parts: Array = []
	var Y := Vector3.UP
	var X := Vector3.RIGHT
	# Torso (eje Y, de la cadera a los hombros): sección ovalada, más ancha
	# en el pecho; hombros un poco caídos.
	parts.append([Y, 8, [
		_ring(Vector3(0, 0.93, -0.02), 0.175, 0.105, [[b.call("pelvis"), 1.0]], Zone.SHIRT, true, true),
		_ring(Vector3(0, 1.02, -0.02), 0.17, 0.105, [[b.call("pelvis"), 0.5], [b.call("spine_01"), 0.5]], Zone.SHIRT, true),
		_ring(Vector3(0, 1.14, -0.015), 0.168, 0.105, [[b.call("spine_01"), 0.5], [b.call("spine_02"), 0.5]], Zone.SHIRT, true),
		_ring(Vector3(0, 1.28, -0.01), 0.19, 0.115, [[b.call("spine_02"), 0.5], [b.call("spine_03"), 0.5]], Zone.SHIRT, true),
		_ring(Vector3(0, 1.42, -0.015), 0.205, 0.11, [[b.call("spine_03"), 1.0]], Zone.SHIRT, true),
		_ring(Vector3(0, 1.49, -0.02), 0.14, 0.088, [[b.call("spine_03"), 1.0]], Zone.SHIRT, true, true),
		# Cierra el cuello de la camiseta contra el cuello (antes quedaba un
		# agujero alrededor del cuello).
		_ring(Vector3(0, 1.505, -0.02), 0.068, 0.062, [[b.call("spine_03"), 0.6], [b.call("neck_01"), 0.4]], Zone.SHIRT, true, true),
	]])
	# Cuello.
	parts.append([Y, 6, [
		_ring(Vector3(0, 1.47, -0.02), 0.062, 0.058, [[b.call("neck_01"), 1.0]], Zone.SKIN),
		_ring(Vector3(0, 1.6, -0.02), 0.055, 0.055, [[b.call("neck_01"), 0.5], [b.call("Head"), 0.5]], Zone.SKIN),
	]])
	# Cabeza: ovoide de pocas caras (pelo arriba y atrás).
	var head := b.call("Head") as int
	parts.append([Y, 8, [
		_ring(Vector3(0, 1.57, 0.0), 0.04, 0.04, [[head, 1.0]], Zone.SKIN),
		_ring(Vector3(0, 1.6, 0.005), 0.075, 0.08, [[head, 1.0]], Zone.SKIN),
		_ring(Vector3(0, 1.67, 0.0), 0.09, 0.1, [[head, 1.0]], Zone.SKIN),
		_ring(Vector3(0, 1.74, -0.005), 0.095, 0.105, [[head, 1.0]], Zone.HAIR),
		_ring(Vector3(0, 1.8, -0.01), 0.075, 0.085, [[head, 1.0]], Zone.HAIR),
		_ring(Vector3(0, 1.83, -0.01), 0.03, 0.035, [[head, 1.0]], Zone.HAIR),
	]])
	for side: float in [1.0, -1.0]:
		var sfx := "_l" if side > 0.0 else "_r"
		var upper := b.call("upperarm" + sfx) as int
		var lower := b.call("lowerarm" + sfx) as int
		var hand := b.call("hand" + sfx) as int
		var thigh := b.call("thigh" + sfx) as int
		var calf := b.call("calf" + sfx) as int
		var foot := b.call("foot" + sfx) as int
		var toe := b.call("ball" + sfx) as int
		var clav := b.call("clavicle" + sfx) as int
		var ax := X * side
		# Hombro (deltoides) pegado a la clavícula: tapa la articulación
		# cuando el brazo se mueve (antes se abría entre la manga y el torso).
		parts.append([ax, 6, [
			_ring(Vector3(side * 0.1, 1.43, -0.03), 0.02, 0.02, [[clav, 1.0]], Zone.SHIRT),
			_ring(Vector3(side * 0.14, 1.435, -0.03), 0.07, 0.072, [[clav, 1.0]], Zone.SHIRT),
			_ring(Vector3(side * 0.205, 1.44, -0.035), 0.068, 0.07, [[clav, 0.6], [upper, 0.4]], Zone.SHIRT),
			_ring(Vector3(side * 0.25, 1.44, -0.04), 0.02, 0.02, [[upper, 1.0]], Zone.SHIRT),
		]])
		# Manga corta (camiseta) y brazo (piel), eje X.
		parts.append([ax, 6, [
			_ring(Vector3(side * 0.12, 1.425, -0.03), 0.025, 0.03, [[clav, 1.0]], Zone.SHIRT),
			_ring(Vector3(side * 0.17, 1.425, -0.03), 0.06, 0.07, [[clav, 0.5], [upper, 0.5]], Zone.SHIRT),
			_ring(Vector3(side * 0.24, 1.44, -0.04), 0.068, 0.068, [[upper, 1.0]], Zone.SHIRT),
			_ring(Vector3(side * 0.34, 1.445, -0.05), 0.062, 0.062, [[upper, 1.0]], Zone.SHIRT, false, true),
			# Ruedo de la manga cerrado contra el brazo.
			_ring(Vector3(side * 0.345, 1.445, -0.05), 0.05, 0.05, [[upper, 1.0]], Zone.SHIRT, false, true),
		]])
		parts.append([ax, 6, [
			_ring(Vector3(side * 0.335, 1.445, -0.05), 0.054, 0.054, [[upper, 1.0]], Zone.SKIN),
			_ring(Vector3(side * 0.46, 1.445, -0.06), 0.046, 0.046, [[upper, 0.5], [lower, 0.5]], Zone.SKIN),
			_ring(Vector3(side * 0.69, 1.445, -0.06), 0.036, 0.036, [[lower, 1.0]], Zone.SKIN),
		]])
		parts.append([ax, 4, [
			_ring(Vector3(side * 0.69, 1.445, -0.06), 0.034, 0.04, [[hand, 1.0]], Zone.HANDS),
			_ring(Vector3(side * 0.8, 1.445, -0.06), 0.022, 0.045, [[hand, 1.0]], Zone.HANDS),
			_ring(Vector3(side * 0.86, 1.445, -0.06), 0.012, 0.03, [[hand, 1.0]], Zone.HANDS),
		]])
		# Short, muslo, rodilla, media (eje Y, hacia abajo).
		var lx := side * 0.105
		parts.append([-Y, 7, [
			_ring(Vector3(lx * 0.8, 0.96, -0.025), 0.115, 0.115, [[b.call("pelvis"), 0.5], [thigh, 0.5]], Zone.SHORTS),
			_ring(Vector3(lx, 0.82, -0.03), 0.1, 0.1, [[thigh, 1.0]], Zone.SHORTS),
			_ring(Vector3(lx, 0.7, -0.035), 0.092, 0.092, [[thigh, 1.0]], Zone.SHORTS, false, true),
		]])
		parts.append([-Y, 6, [
			_ring(Vector3(lx, 0.71, -0.035), 0.068, 0.068, [[thigh, 1.0]], Zone.SKIN),
			_ring(Vector3(lx, 0.55, -0.035), 0.055, 0.055, [[thigh, 0.5], [calf, 0.5]], Zone.SKIN),
			_ring(Vector3(lx, 0.49, -0.035), 0.054, 0.054, [[calf, 1.0]], Zone.SKIN),
		]])
		parts.append([-Y, 6, [
			_ring(Vector3(lx, 0.49, -0.035), 0.056, 0.056, [[calf, 1.0]], Zone.SOCKS),
			_ring(Vector3(lx, 0.36, -0.045), 0.055, 0.058, [[calf, 1.0]], Zone.SOCKS),
			_ring(Vector3(lx, 0.14, -0.06), 0.038, 0.04, [[calf, 0.5], [foot, 0.5]], Zone.SOCKS),
		]])
		# Botín (eje Z, del talón a la punta).
		parts.append([Vector3.BACK, 6, [
			_ring(Vector3(lx, 0.06, -0.11), 0.04, 0.05, [[foot, 1.0]], Zone.BOOTS),
			_ring(Vector3(lx, 0.07, -0.03), 0.048, 0.06, [[foot, 1.0]], Zone.BOOTS),
			_ring(Vector3(lx, 0.045, 0.08), 0.045, 0.04, [[foot, 0.5], [toe, 0.5]], Zone.BOOTS),
			_ring(Vector3(lx, 0.03, 0.15), 0.025, 0.022, [[toe, 1.0]], Zone.BOOTS),
		]])
	var st := {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(),
		"rest": PackedFloat32Array(), "b": PackedInt32Array(), "w": PackedFloat32Array()}
	var used := {}
	for part in parts:
		_tube(st, part[0], part[1], part[2], used)
	_face(st, head, used)
	# Pasa los huesos del esqueleto a los índices de la piel.
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
	arr[Mesh.ARRAY_CUSTOM0] = st["rest"]
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = st["w"]
	var data := {"arrays": arr, "skin": skin}
	_cache["data"] = data
	return data


## Tubo entre anillos (con tapas en las puntas), caras planas.
static func _tube(st: Dictionary, axis: Vector3, sides: int, rings: Array, used: Dictionary) -> void:
	axis = axis.normalized()
	var u := Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.UP
	u = (u - axis * u.dot(axis)).normalized()
	var w := axis.cross(u).normalized()
	var pts: Array = []
	for r: Dictionary in rings:
		var ring: Array = []
		for k in sides:
			var a := TAU * (k + 0.5) / sides
			# u: adelante/atrás (radio b), w: el otro eje (radio a).
			ring.append((r["c"] as Vector3) + w * cos(a) * float(r["ra"]) + u * sin(a) * float(r["rb"]))
		pts.append(ring)
	for i in rings.size() - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			var a: Vector3 = pts[i][k]
			var b: Vector3 = pts[i][k2]
			var c: Vector3 = pts[i + 1][k2]
			var d: Vector3 = pts[i + 1][k]
			_tri(st, [a, b, c], [rings[i], rings[i], rings[i + 1]], used)
			_tri(st, [a, c, d], [rings[i], rings[i + 1], rings[i + 1]], used)
	# Tapas.
	for end in [0, rings.size() - 1]:
		var ring_pts: Array = pts[end]
		var center: Vector3 = rings[end]["c"]
		for k in sides:
			var k2 := (k + 1) % sides
			_tri(st, [center, ring_pts[k], ring_pts[k2]], [rings[end], rings[end], rings[end]], used)


## Triángulo de caras planas (normal hacia afuera del centro de la parte).
static func _tri(st: Dictionary, p: Array, r: Array, used: Dictionary) -> void:
	var n := ((p[1] as Vector3) - (p[0] as Vector3)).cross((p[2] as Vector3) - (p[0] as Vector3))
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	# Que mire hacia afuera del eje del anillo (centro de los anillos).
	var mid := ((p[0] as Vector3) + (p[1] as Vector3) + (p[2] as Vector3)) / 3.0
	var core := ((r[0]["c"] as Vector3) + (r[1]["c"] as Vector3) + (r[2]["c"] as Vector3)) / 3.0
	# Godot toma como cara de adelante el orden horario visto desde afuera.
	var order := [0, 2, 1]
	if n.dot(mid - core) < 0.0:
		n = -n
		order = [0, 1, 2]
	for i in order:
		var ring: Dictionary = r[i]
		var v: Vector3 = p[i]
		st["v"].append(v)
		st["n"].append(n)
		var zone: int = ring["zone"]
		# El pelo: también la nuca (atrás y abajo de la coronilla).
		if zone == Zone.SKIN and ring["bones"][0][0] == r[0]["bones"][0][0] and v.y > 1.62 and v.z < -0.035:
			zone = Zone.HAIR
		st["c"].append(Color(zone / 10.0, 1.0 if ring["torso"] else 0.0, 1.0 if ring["trim"] else 0.0))
		st["rest"].append_array([v.x, v.y, v.z, 0.0])
		var bw: Array = ring["bones"]
		for j in 4:
			if j < bw.size():
				st["b"].append(int(bw[j][0]))
				st["w"].append(float(bw[j][1]))
				used[int(bw[j][0])] = true
			else:
				st["b"].append(int(bw[0][0]))
				st["w"].append(0.0)


## Ojos y cejas: plaquitas oscuras sobre la cara (zona pelo = color oscuro).
static func _face(st: Dictionary, head: int, used: Dictionary) -> void:
	var r := _ring(Vector3(0, 1.67, 0.0), 0.0, 0.0, [[head, 1.0]], Zone.HAIR)
	for sx: float in [-1.0, 1.0]:
		for q in [[1.68, 0.012, 0.022], [1.705, 0.007, 0.03]]:
			var y: float = q[0]
			var h: float = q[1]
			var wdt: float = q[2]
			var z := 0.104
			var x0 := sx * 0.038 - wdt * 0.5
			var a := Vector3(x0, y - h, z)
			var b := Vector3(x0 + wdt, y - h, z)
			var c := Vector3(x0 + wdt, y + h, z)
			var d := Vector3(x0, y + h, z)
			_tri(st, [a, b, c], [r, r, r], used)
			_tri(st, [a, c, d], [r, r, r], used)


## Arma el cuerpo clásico sobre el esqueleto con el material de la ropa.
static func build(sk: Skeleton3D, material: Material) -> MeshInstance3D:
	var data := prepare(sk)
	var mesh := ArrayMesh.new()
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data["arrays"], [], {}, flags)
	var mi := MeshInstance3D.new()
	mi.name = "ClassicBody"
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = data["skin"]
	mi.mesh = mesh
	mi.material_override = material
	return mi
