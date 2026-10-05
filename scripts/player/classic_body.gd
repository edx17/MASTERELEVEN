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


## Mapeo UV de la ropa (para camisetas con textura: ver docs/KIT_UV.md).
## [u0, v0, u1, v1] de cada parte en la textura del uniforme; u = vuelta
## alrededor del tubo, v = a lo largo (de arriba hacia abajo).
const UV_TORSO := [0.0, 0.0, 0.5, 0.5]
const UV_SLEEVE_L := [0.5, 0.0, 0.75, 0.25]
const UV_SLEEVE_R := [0.75, 0.0, 1.0, 0.25]
const UV_SHORTS_L := [0.0, 0.5, 0.25, 0.75]
const UV_SHORTS_R := [0.25, 0.5, 0.5, 0.75]
const UV_SOCK_L := [0.5, 0.5, 0.75, 0.75]
const UV_SOCK_R := [0.75, 0.5, 1.0, 0.75]
## Piel, botines y pelo: un punto fuera de la ropa.
const UV_NONE := [0.9, 0.9, 0.9, 0.9]


## Arma (y guarda) los arrays de la malla para el esqueleto dado. Más fina
## que la primera versión (B2): más lados por tubo y siluetas de verdad
## (pecho, trapecio, glúteo, rodilla, pantorrilla, antebrazo), orejas y
## nariz; sigue con caras planas, como un WE "remasterizado".
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
	# Torso (de la cadera a los hombros): cintura, pecho marcado adelante y
	# trapecio que baja hacia el cuello.
	parts.append([Y, 12, [
		_ring(Vector3(0, 0.93, -0.025), 0.175, 0.108, [[pelvis, 1.0]], Zone.SHIRT, true, true),
		_ring(Vector3(0, 1.02, -0.02), 0.166, 0.104, [[pelvis, 0.5], [sp1, 0.5]], Zone.SHIRT, true),
		_ring(Vector3(0, 1.13, -0.015), 0.162, 0.104, [[sp1, 0.5], [sp2, 0.5]], Zone.SHIRT, true),
		_ring(Vector3(0, 1.25, -0.008), 0.182, 0.114, [[sp2, 0.5], [sp3, 0.5]], Zone.SHIRT, true),
		_ring(Vector3(0, 1.34, -0.004), 0.202, 0.121, [[sp3, 1.0]], Zone.SHIRT, true),
		_ring(Vector3(0, 1.42, -0.015), 0.206, 0.108, [[sp3, 1.0]], Zone.SHIRT, true),
		_ring(Vector3(0, 1.475, -0.022), 0.15, 0.09, [[sp3, 1.0]], Zone.SHIRT, true),
		_ring(Vector3(0, 1.495, -0.022), 0.105, 0.075, [[sp3, 1.0]], Zone.SHIRT, true, true),
		# Cierra el cuello de la camiseta contra el cuello.
		_ring(Vector3(0, 1.505, -0.02), 0.068, 0.062, [[sp3, 0.6], [neck, 0.4]], Zone.SHIRT, true, true),
	], UV_TORSO])
	# Cuello (un poco más ancho en la base).
	parts.append([Y, 8, [
		_ring(Vector3(0, 1.47, -0.02), 0.064, 0.06, [[neck, 1.0]], Zone.SKIN),
		_ring(Vector3(0, 1.55, -0.018), 0.056, 0.054, [[neck, 1.0]], Zone.SKIN),
		_ring(Vector3(0, 1.6, -0.015), 0.054, 0.054, [[neck, 0.5], [head, 0.5]], Zone.SKIN),
	], UV_NONE])
	# Cabeza: mentón, mandíbula, pómulos, frente y coronilla (pelo arriba y
	# atrás). La cara la dibuja el shader (ojos, cejas, boca, barba).
	parts.append([Y, 10, [
		_ring(Vector3(0, 1.575, 0.03), 0.028, 0.025, [[head, 1.0]], Zone.SKIN),
		_ring(Vector3(0, 1.6, 0.012), 0.066, 0.078, [[head, 1.0]], Zone.SKIN),
		_ring(Vector3(0, 1.635, 0.004), 0.083, 0.095, [[head, 1.0]], Zone.SKIN),
		_ring(Vector3(0, 1.675, 0.0), 0.091, 0.102, [[head, 1.0]], Zone.SKIN),
		_ring(Vector3(0, 1.715, -0.004), 0.094, 0.106, [[head, 1.0]], Zone.SKIN),
		_ring(Vector3(0, 1.75, -0.008), 0.09, 0.104, [[head, 1.0]], Zone.HAIR),
		_ring(Vector3(0, 1.795, -0.012), 0.07, 0.085, [[head, 1.0]], Zone.HAIR),
		_ring(Vector3(0, 1.825, -0.012), 0.032, 0.04, [[head, 1.0]], Zone.HAIR),
	], UV_NONE])
	# Nariz (una cuña hacia adelante) y orejas.
	parts.append([Vector3.BACK, 4, [
		_ring(Vector3(0, 1.664, 0.093), 0.014, 0.018, [[head, 1.0]], Zone.SKIN),
		_ring(Vector3(0, 1.655, 0.118), 0.006, 0.008, [[head, 1.0]], Zone.SKIN),
	], UV_NONE])
	for ex: float in [1.0, -1.0]:
		parts.append([X * ex, 5, [
			_ring(Vector3(ex * 0.086, 1.672, -0.012), 0.022, 0.012, [[head, 1.0]], Zone.SKIN),
			_ring(Vector3(ex * 0.103, 1.676, -0.016), 0.02, 0.01, [[head, 1.0]], Zone.SKIN),
		], UV_NONE])
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
		var sleeve_uv := UV_SLEEVE_L if side > 0.0 else UV_SLEEVE_R
		# Hombro (deltoides) pegado a la clavícula: tapa la articulación.
		parts.append([ax, 8, [
			_ring(Vector3(side * 0.1, 1.43, -0.03), 0.02, 0.02, [[clav, 1.0]], Zone.SHIRT),
			_ring(Vector3(side * 0.14, 1.435, -0.03), 0.072, 0.074, [[clav, 1.0]], Zone.SHIRT),
			_ring(Vector3(side * 0.205, 1.44, -0.035), 0.07, 0.072, [[clav, 0.6], [upper, 0.4]], Zone.SHIRT),
			_ring(Vector3(side * 0.25, 1.44, -0.04), 0.02, 0.02, [[upper, 1.0]], Zone.SHIRT),
		], sleeve_uv])
		# Manga corta (camiseta).
		parts.append([ax, 8, [
			_ring(Vector3(side * 0.12, 1.425, -0.03), 0.025, 0.03, [[clav, 1.0]], Zone.SHIRT),
			_ring(Vector3(side * 0.17, 1.425, -0.03), 0.06, 0.07, [[clav, 0.5], [upper, 0.5]], Zone.SHIRT),
			_ring(Vector3(side * 0.24, 1.44, -0.04), 0.07, 0.07, [[upper, 1.0]], Zone.SHIRT),
			_ring(Vector3(side * 0.34, 1.445, -0.05), 0.063, 0.063, [[upper, 1.0]], Zone.SHIRT, false, true),
			_ring(Vector3(side * 0.345, 1.445, -0.05), 0.05, 0.05, [[upper, 1.0]], Zone.SHIRT, false, true),
		], sleeve_uv])
		# Brazo: bíceps, codo, antebrazo y muñeca (con manga larga, la pinta
		# el shader del color de la camiseta).
		parts.append([ax, 8, [
			_ring(Vector3(side * 0.335, 1.445, -0.05), 0.055, 0.055, [[upper, 1.0]], Zone.SKIN),
			_ring(Vector3(side * 0.4, 1.445, -0.055), 0.052, 0.05, [[upper, 1.0]], Zone.SKIN),
			_ring(Vector3(side * 0.46, 1.445, -0.06), 0.043, 0.043, [[upper, 0.5], [lower, 0.5]], Zone.SKIN),
			_ring(Vector3(side * 0.54, 1.445, -0.06), 0.046, 0.042, [[lower, 1.0]], Zone.SKIN),
			_ring(Vector3(side * 0.67, 1.445, -0.06), 0.031, 0.027, [[lower, 1.0]], Zone.SKIN),
		], UV_NONE])
		# Mano: palma, dedos juntos y pulgar.
		parts.append([ax, 6, [
			_ring(Vector3(side * 0.675, 1.445, -0.06), 0.032, 0.026, [[hand, 1.0]], Zone.HANDS),
			_ring(Vector3(side * 0.74, 1.445, -0.058), 0.022, 0.045, [[hand, 1.0]], Zone.HANDS),
			_ring(Vector3(side * 0.82, 1.443, -0.058), 0.016, 0.04, [[hand, 1.0]], Zone.HANDS),
			_ring(Vector3(side * 0.86, 1.44, -0.058), 0.009, 0.025, [[hand, 1.0]], Zone.HANDS),
		], UV_NONE])
		parts.append([(ax + Vector3.BACK * 0.8).normalized(), 4, [
			_ring(Vector3(side * 0.71, 1.43, -0.03), 0.012, 0.012, [[hand, 1.0]], Zone.HANDS),
			_ring(Vector3(side * 0.75, 1.425, 0.0), 0.008, 0.008, [[hand, 1.0]], Zone.HANDS),
		], UV_NONE])
		# Short (con glúteo atrás), muslo, rodilla, pantorrilla y media.
		var lx := side * 0.105
		parts.append([-Y, 10, [
			_ring(Vector3(lx * 0.8, 0.97, -0.03), 0.118, 0.118, [[pelvis, 0.5], [thigh, 0.5]], Zone.SHORTS),
			_ring(Vector3(lx * 0.95, 0.88, -0.04), 0.108, 0.112, [[pelvis, 0.3], [thigh, 0.7]], Zone.SHORTS),
			_ring(Vector3(lx, 0.79, -0.034), 0.098, 0.098, [[thigh, 1.0]], Zone.SHORTS),
			_ring(Vector3(lx, 0.7, -0.035), 0.09, 0.09, [[thigh, 1.0]], Zone.SHORTS, false, true),
		], UV_SHORTS_L if side > 0.0 else UV_SHORTS_R])
		parts.append([-Y, 8, [
			_ring(Vector3(lx, 0.71, -0.035), 0.07, 0.07, [[thigh, 1.0]], Zone.SKIN),
			_ring(Vector3(lx, 0.62, -0.032), 0.062, 0.06, [[thigh, 1.0]], Zone.SKIN),
			_ring(Vector3(lx, 0.55, -0.03), 0.05, 0.052, [[thigh, 0.5], [calf, 0.5]], Zone.SKIN),
			_ring(Vector3(lx, 0.49, -0.035), 0.052, 0.054, [[calf, 1.0]], Zone.SKIN),
		], UV_NONE])
		parts.append([-Y, 8, [
			_ring(Vector3(lx, 0.49, -0.035), 0.055, 0.057, [[calf, 1.0]], Zone.SOCKS),
			_ring(Vector3(lx, 0.41, -0.05), 0.058, 0.064, [[calf, 1.0]], Zone.SOCKS),
			_ring(Vector3(lx, 0.3, -0.05), 0.048, 0.05, [[calf, 1.0]], Zone.SOCKS),
			_ring(Vector3(lx, 0.14, -0.06), 0.036, 0.038, [[calf, 0.5], [foot, 0.5]], Zone.SOCKS),
		], UV_SOCK_L if side > 0.0 else UV_SOCK_R])
		# Botín (del talón a la punta).
		parts.append([Vector3.BACK, 8, [
			_ring(Vector3(lx, 0.06, -0.11), 0.04, 0.05, [[foot, 1.0]], Zone.BOOTS),
			_ring(Vector3(lx, 0.07, -0.03), 0.048, 0.06, [[foot, 1.0]], Zone.BOOTS),
			_ring(Vector3(lx, 0.045, 0.08), 0.045, 0.04, [[foot, 0.5], [toe, 0.5]], Zone.BOOTS),
			_ring(Vector3(lx, 0.03, 0.15), 0.025, 0.022, [[toe, 1.0]], Zone.BOOTS),
		], UV_NONE])
	var st := {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(),
		"rest": PackedFloat32Array(), "uv": PackedVector2Array(), "b": PackedInt32Array(), "w": PackedFloat32Array()}
	var used := {}
	for part in parts:
		_tube(st, part[0], part[1], part[2], used, part[3] if part.size() > 3 else UV_NONE)
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
	arr[Mesh.ARRAY_TEX_UV] = st["uv"]
	arr[Mesh.ARRAY_CUSTOM0] = st["rest"]
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = st["w"]
	var data := {"arrays": arr, "skin": skin}
	_cache["data"] = data
	return data


## Tubo entre anillos (con tapas en las puntas), caras planas. `uvr`: región
## de la textura del uniforme (u = vuelta, v = a lo largo).
static func _tube(st: Dictionary, axis: Vector3, sides: int, rings: Array, used: Dictionary,
		uvr: Array = UV_NONE) -> void:
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
	var n_r := rings.size()
	var uvat := func(kk: float, i: float) -> Vector2:
		return Vector2(lerpf(float(uvr[0]), float(uvr[2]), kk / sides), lerpf(float(uvr[1]), float(uvr[3]), i / maxf(n_r - 1, 1)))
	for i in n_r - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			var a: Vector3 = pts[i][k]
			var b: Vector3 = pts[i][k2]
			var c: Vector3 = pts[i + 1][k2]
			var d: Vector3 = pts[i + 1][k]
			var ua: Vector2 = uvat.call(float(k), float(i))
			var ub: Vector2 = uvat.call(float(k + 1), float(i))
			var uc: Vector2 = uvat.call(float(k + 1), float(i + 1))
			var ud: Vector2 = uvat.call(float(k), float(i + 1))
			_tri(st, [a, b, c], [rings[i], rings[i], rings[i + 1]], used, [ua, ub, uc])
			_tri(st, [a, c, d], [rings[i], rings[i + 1], rings[i + 1]], used, [ua, uc, ud])
	# Tapas.
	for end in [0, n_r - 1]:
		var ring_pts: Array = pts[end]
		var center: Vector3 = rings[end]["c"]
		var uc2: Vector2 = uvat.call(sides * 0.5, float(end))
		for k in sides:
			var k2 := (k + 1) % sides
			_tri(st, [center, ring_pts[k], ring_pts[k2]], [rings[end], rings[end], rings[end]], used,
				[uc2, uvat.call(float(k), float(end)), uvat.call(float(k + 1), float(end))])


## Triángulo de caras planas (normal hacia afuera del centro de la parte).
static func _tri(st: Dictionary, p: Array, r: Array, used: Dictionary, uv: Array = []) -> void:
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
	# Franja entre piel y pelo (la línea del pelo): una sola zona por triángulo
	# (pelo atrás, piel adelante); si no, el borde sale en dientes de sierra.
	var mixed_hair := -1
	var zs := [int(r[0]["zone"]), int(r[1]["zone"]), int(r[2]["zone"])]
	if Zone.HAIR in zs and Zone.SKIN in zs:
		mixed_hair = Zone.HAIR if mid.z < 0.0 else Zone.SKIN
	for i in order:
		var ring: Dictionary = r[i]
		var v: Vector3 = p[i]
		st["v"].append(v)
		st["n"].append(n)
		st["uv"].append(uv[i] if uv.size() > i else Vector2(0.9, 0.9))
		var zone: int = ring["zone"]
		if mixed_hair >= 0:
			zone = mixed_hair
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
