class_name HairBuilder
extends RefCounted
## Peinados con volumen, armados por código sobre la cabeza del modelo (en el
## espacio de reposo del esqueleto; ModelVisual los pega al hueso Head).
## Inspirados en peinados típicos del fútbol, sin copiar a nadie en particular.

enum Style { FADE, SHAVED, HELMET, MOHAWK, PONYTAIL, CURLY_BAND, DREADS, HORSESHOE, LONG_PARTED,
	AFRO, CORNROWS, FRINGE, QUIFF, SIDE_PART }
const NAMES := ["corto degradé", "pelado", "casco", "mohicano", "coleta", "rulos con vincha",
	"rastas", "pelado arriba", "largo con raya", "afro", "trenzas pegadas", "flequillo", "copete",
	"corto con raya al costado"]

## Cráneo (elipsoide) medido sobre la malla del cuerpo en reposo.
const CENTER := Vector3(0.0, 1.70, -0.008)
const RADII := Vector3(0.094, 0.112, 0.104)

static var _cache := {}


## Malla del peinado (null para el pelado: la cabeza queda con la piel).
## Superficies por nombre: "hair" (la base, opaca), "cards" (mechones con
## transparencia, B3) y "band" (vincha).
static func mesh(style: int) -> ArrayMesh:
	if style == Style.SHAVED:
		return null
	if _cache.has(style):
		return _cache[style]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var band: SurfaceTool = null
	var cards := SurfaceTool.new()
	cards.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_cards := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + style
	# Hacia dónde caen los mechones: hacia atrás y abajo (peinado natural).
	var back := func(d: Vector3) -> Vector3: return Vector3(d.x * 0.3, -0.35, -1.0)
	match style:
		Style.FADE:
			# Arriba algo de volumen; a los costados y atrás, casi al ras.
			_cap(st, func(d: Vector3) -> float: return lerpf(0.006, 0.018, clampf(d.y * 2.0, 0.0, 1.0)),
					func(d: Vector3) -> bool: return d.y > _hairline(d, -0.05, -0.55) + maxf(0.0, d.z) * 0.45)
			n_cards += _cards(cards, rng, 70, func(d: Vector3) -> bool: return d.y > 0.35,
					back, Vector2(0.03, 0.05), 0.022, 0.016)
		Style.HELMET:
			# Casco redondo y abultado que baja hasta las orejas.
			_cap(st, func(d: Vector3) -> float: return 0.026 + 0.01 * maxf(0.0, d.y),
					func(d: Vector3) -> bool: return d.y > _hairline(d, -0.25, -0.55) + maxf(0.0, d.z) * 0.75)
			n_cards += _cards(cards, rng, 150, func(d: Vector3) -> bool: return d.y > -0.2 + maxf(0.0, d.z) * 0.75,
					func(d: Vector3) -> Vector3: return Vector3(d.x, -1.0, d.z * 0.6), Vector2(0.05, 0.08), 0.03, 0.03)
		Style.AFRO:
			# Afro: volumen grande y redondo con textura de rulos.
			_cap(st, func(d: Vector3) -> float: return 0.06 + 0.012 * sin(d.x * 31.0) * sin(d.y * 27.0) * sin(d.z * 23.0) + 0.02 * maxf(0.0, d.y),
					func(d: Vector3) -> bool: return d.y > -0.2 + maxf(0.0, d.z) * 0.75)
		Style.CORNROWS:
			# Trenzas pegadas: surcos de la frente a la nuca.
			_cap(st, func(_d: Vector3) -> float: return 0.004,
					func(d: Vector3) -> bool: return d.y > _hairline(d, -0.15, -0.5) + maxf(0.0, d.z) * 0.8)
			for row in 9:
				var x := lerpf(-0.75, 0.75, row / 8.0)
				var pts: Array = []
				var radii: Array = []
				for i in 9:
					var a := lerpf(-0.55, 2.2, i / 8.0)
					var d := Vector3(x * cos(a) * 0.9, cos(a), -sin(a)).normalized()
					pts.append(_surface(d) + d * 0.006)
					radii.append(0.009)
				_tube(st, pts, radii, 4)
		Style.FRINGE:
			# Flequillo: cae sobre la frente; arriba y atrás, corto.
			_cap(st, func(_d: Vector3) -> float: return 0.014,
					func(d: Vector3) -> bool: return d.y > _hairline(d, -0.12, -0.55) + maxf(0.0, d.z) * 0.35)
			n_cards += _cards(cards, rng, 60, func(d: Vector3) -> bool: return d.z > 0.35 and d.y > 0.15,
					func(_d: Vector3) -> Vector3: return Vector3(0.0, -1.0, 0.6), Vector2(0.06, 0.085), 0.026, 0.02)
			n_cards += _cards(cards, rng, 80, func(d: Vector3) -> bool: return d.y > 0.2 and d.z <= 0.35,
					back, Vector2(0.04, 0.06), 0.024, 0.02)
		Style.QUIFF:
			# Copete: adelante para arriba y hacia atrás; costados cortos.
			_cap(st, func(d: Vector3) -> float: return lerpf(0.006, 0.016, clampf(d.y * 2.0, 0.0, 1.0)),
					func(d: Vector3) -> bool: return d.y > _hairline(d, -0.05, -0.55) + maxf(0.0, d.z) * 0.45)
			n_cards += _cards(cards, rng, 90, func(d: Vector3) -> bool: return d.y > 0.45 and absf(d.x) < 0.55,
					func(d: Vector3) -> Vector3: return Vector3(0.0, 0.9 * maxf(d.z, 0.0) + 0.15, -1.0), Vector2(0.06, 0.09), 0.026, 0.026)
		Style.SIDE_PART:
			# Corto con raya al costado: peinado hacia el otro lado.
			_cap(st, func(_d: Vector3) -> float: return 0.013,
					func(d: Vector3) -> bool: return d.y > _hairline(d, -0.1, -0.55) + maxf(0.0, d.z) * 0.4 and not (absf(d.x - 0.35) < 0.04 and d.y > 0.3 and d.z > -0.1))
			n_cards += _cards(cards, rng, 110, func(d: Vector3) -> bool: return d.y > 0.15 and d.x < 0.33,
					func(d: Vector3) -> Vector3: return Vector3(-1.0, -0.4, -0.4), Vector2(0.05, 0.07), 0.026, 0.02)
		Style.MOHAWK:
			_cap(st, func(_d: Vector3) -> float: return 0.004,
					func(d: Vector3) -> bool: return d.y > 0.0 and absf(d.x) < 0.75)
			# Cresta en el medio: de la frente a la nuca.
			for i in 13:
				# Ángulo desde la vertical: negativo hacia la frente (+Z), positivo
				# hacia la nuca.
				var a := lerpf(-0.4, 2.0, i / 12.0)
				var d := Vector3(0.0, cos(a), -sin(a))
				var h := 0.05 * (1.0 - absf(i - 4.0) / 14.0)
				_tile(st, _surface(d), d, Vector3.RIGHT, Vector3(0.026, h, 0.03))
		Style.PONYTAIL:
			_cap(st, func(_d: Vector3) -> float: return 0.012,
					func(d: Vector3) -> bool: return d.y > -0.2 + maxf(0.0, d.z) * 0.7)
			# Cola atada atrás que cae sobre la nuca.
			var top := CENTER + Vector3(0.0, 0.02, -RADII.z - 0.01)
			_tube(st, [top, top + Vector3(0, -0.07, -0.05), top + Vector3(0, -0.17, -0.06), top + Vector3(0, -0.25, -0.04)],
					[0.026, 0.03, 0.024, 0.012], 7)
		Style.CURLY_BAND:
			# Rulos largos y abundantes hasta los hombros, con vincha.
			_cap(st, func(d: Vector3) -> float: return 0.04 + 0.015 * sin(d.x * 23.0) * sin(d.z * 19.0),
					func(d: Vector3) -> bool: return d.y > -0.3 + maxf(0.0, d.z) * 0.9)
			_curtain(st, 0.07, 1.5, 0.05, rng)
			band = SurfaceTool.new()
			band.begin(Mesh.PRIMITIVE_TRIANGLES)
			_ring(band, 0.012, 0.03, 0.0)
		Style.DREADS:
			_cap(st, func(_d: Vector3) -> float: return 0.014,
					func(d: Vector3) -> bool: return d.y > -0.15 + maxf(0.0, d.z) * 0.8)
			# Rastas: cordones que salen del cuero cabelludo y caen.
			for i in 26:
				var ang := lerpf(-2.3, 2.3, rng.randf()) + PI # atrás y costados
				var lift := rng.randf_range(-0.1, 0.55)
				var d := Vector3(sin(ang) * cos(lift), sin(lift), cos(ang) * cos(lift)).normalized()
				var start := _surface(d) + d * 0.01
				var fall := rng.randf_range(0.2, 0.3)
				var out := Vector3(d.x, 0.0, d.z).normalized() * 0.04
				_tube(st, [start, start + out + Vector3(0, -0.06, 0), start + out * 1.4 + Vector3(0, -fall, 0)],
						[0.013, 0.012, 0.009], 5)
		Style.HORSESHOE:
			# Pelado arriba: sólo una corona corta a los costados y atrás.
			_cap(st, func(_d: Vector3) -> float: return 0.007,
					func(d: Vector3) -> bool: return d.y > -0.25 and d.y < 0.3 and d.z < 0.35)
		Style.LONG_PARTED:
			# Largo y lacio, con raya al medio, hasta los hombros.
			_cap(st, func(d: Vector3) -> float: return 0.016 + 0.01 * absf(d.x),
					func(d: Vector3) -> bool: return d.y > -0.3 + maxf(0.0, d.z) * 0.9 and not (absf(d.x) < 0.05 and d.y > 0.3 and d.z > -0.2))
			_curtain(st, 0.025, 1.47, 0.0, rng)
			n_cards += _cards(cards, rng, 160, func(d: Vector3) -> bool: return d.y > -0.1 and not (d.z > 0.35 and d.y < 0.75),
					func(d: Vector3) -> Vector3: return Vector3(signf(d.x) * 0.6 if absf(d.x) > 0.05 else 0.0, -1.0, -0.25), Vector2(0.14, 0.2), 0.03, 0.022)
	if style == Style.PONYTAIL:
		n_cards += _cards(cards, rng, 90, func(d: Vector3) -> bool: return d.y > 0.0 and not (d.z > 0.3 and d.y < 0.7),
				func(d: Vector3) -> Vector3: return Vector3(-d.x * 0.6, -0.2, -1.0), Vector2(0.06, 0.1), 0.026, 0.016)
	st.generate_normals()
	var out_mesh := st.commit()
	out_mesh.surface_set_name(0, "hair")
	if n_cards > 0:
		cards.generate_normals()
		cards.commit(out_mesh)
		out_mesh.surface_set_name(out_mesh.get_surface_count() - 1, "cards")
	if band != null:
		band.generate_normals()
		band.commit(out_mesh)
		out_mesh.surface_set_name(out_mesh.get_surface_count() - 1, "band")
	_cache[style] = out_mesh
	return out_mesh


## Mechones: tiras finas (dos tramos, la punta curvada hacia la cabeza) que
## salen del cuero cabelludo donde `keep(d)` y van hacia `flow(d)`. Usan la
## textura de hebras con transparencia (material de "cards"). Devuelve cuántos.
static func _cards(st: SurfaceTool, rng: RandomNumberGenerator, count: int, keep: Callable, flow: Callable,
		length: Vector2, width: float, lift: float) -> int:
	var made := 0
	var tries := 0
	while made < count and tries < count * 12:
		tries += 1
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if d.length() < 0.2 or d.length() > 1.0:
			continue
		d = d.normalized()
		if not keep.call(d):
			continue
		var n := (d / RADII).normalized()
		var root := _surface(d) + n * lift
		var f: Vector3 = flow.call(d)
		f = (f - n * f.dot(n)).normalized()
		if f.length_squared() < 0.01:
			continue
		var side := f.cross(n).normalized()
		var l := rng.randf_range(length.x, length.y)
		var w := width * rng.randf_range(0.8, 1.2)
		var mid := root + f * l * 0.55 + n * 0.006
		var tip := mid + (f * 0.8 - n * 0.25).normalized() * l * 0.45
		var u0 := float(rng.randi() % 4) / 4.0
		var pts := [[root, w], [mid, w * 0.85], [tip, w * 0.35]]
		for i in 2:
			var a: Vector3 = pts[i][0]
			var b: Vector3 = pts[i + 1][0]
			var wa: float = pts[i][1]
			var wb: float = pts[i + 1][1]
			var q := [a - side * wa * 0.5, a + side * wa * 0.5, b + side * wb * 0.5, b - side * wb * 0.5]
			var uv := [Vector2(u0, i * 0.5), Vector2(u0 + 0.25, i * 0.5), Vector2(u0 + 0.25, i * 0.5 + 0.5), Vector2(u0, i * 0.5 + 0.5)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(n)
				st.set_uv(uv[idx])
				st.add_vertex(q[idx])
		made += 1
	return made


## Altura mínima del pelo (en la dirección `d`): `front` a los costados y
## adelante, `back` en la nuca (el pelo corto baja atrás hasta el cuello).
static func _hairline(d: Vector3, front: float, back: float) -> float:
	return lerpf(back, front, clampf(d.z + 0.7, 0.0, 1.0))


## Punto de la superficie del cráneo en la dirección `d` (desde el centro).
static func _surface(d: Vector3) -> Vector3:
	return CENTER + d * RADII


## Casquete sobre el cráneo: grilla latitud/longitud con espesor `thick(d)`
## donde `keep(d)` es verdadero. Coordenadas UV a lo largo de los mechones.
static func _cap(st: SurfaceTool, thick: Callable, keep: Callable) -> void:
	var lat := 14
	var lon := 24
	for i in lat:
		for j in lon:
			var quad := []
			var ok := true
			for k in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var th := lerpf(PI * 0.5, -PI * 0.5, float(k[0]) / lat) # de arriba a abajo
				var ph := float(k[1]) / lon * TAU
				var d := Vector3(cos(th) * sin(ph), sin(th), cos(th) * cos(ph))
				if not keep.call(d):
					ok = false
				quad.append([CENTER + d * (RADII + Vector3.ONE * float(thick.call(d))), Vector2(float(k[1]) / lon * 6.0, float(k[0]) / lat)])
			if not ok:
				continue
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_uv(quad[idx][1])
				st.add_vertex(quad[idx][0])


## Melena que cae de la cabeza a la altura `bottom` por atrás y los costados
## (abierta adelante, para la cara). `puff` la ensancha (rulos).
static func _curtain(st: SurfaceTool, puff: float, bottom: float, wave: float, rng: RandomNumberGenerator) -> void:
	var segs := 18
	var rows := 6
	var top := CENTER.y - 0.01
	for i in rows:
		for j in segs:
			var quad := []
			for k in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var t := float(k[0]) / rows
				var ph := lerpf(1.15, TAU - 1.15, float(k[1]) / segs) # sin el frente (la cara)
				var r := 1.0 + puff * 8.0 * t + wave * sin(ph * 9.0 + t * 6.0)
				var y := lerpf(top, bottom, t)
				var p := CENTER + Vector3(sin(ph) * (RADII.x + 0.02) * r, 0.0, cos(ph) * (RADII.z + 0.015) * r)
				p.y = y
				quad.append([p, Vector2(float(k[1]) / segs * 4.0, t)])
			for idx in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]: # doble cara
				st.set_uv(quad[idx][1])
				st.add_vertex(quad[idx][0])


## Tubo facetado por una lista de puntos (radios por punto).
static func _tube(st: SurfaceTool, pts: Array, radii: Array, sides: int) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var axis := (b - a).normalized()
		var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
		var up := axis.cross(side).normalized()
		for s in sides:
			var a0 := TAU * s / sides
			var a1 := TAU * (s + 1) / sides
			var o0 := side * cos(a0) + up * sin(a0)
			var o1 := side * cos(a1) + up * sin(a1)
			var q := [a + o0 * float(radii[i]), b + o0 * float(radii[i + 1]), b + o1 * float(radii[i + 1]), a + o1 * float(radii[i])]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_uv(Vector2(float(s) / sides, float(i)))
				st.add_vertex(q[idx])


## Mechón en forma de caja apoyado en `p`, parado en la dirección `n`.
static func _tile(st: SurfaceTool, p: Vector3, n: Vector3, along: Vector3, size: Vector3) -> void:
	var y := n.normalized()
	var x := along.normalized()
	var z := x.cross(y).normalized()
	var c := p + y * size.y * 0.5
	var h := size * 0.5
	var v := []
	for k in 8:
		v.append(c + x * (h.x if k & 1 else -h.x) + y * (h.y if k & 2 else -h.y) + z * (h.z if k & 4 else -h.z))
	for f in [[0, 1, 3, 2], [5, 4, 6, 7], [4, 0, 2, 6], [1, 5, 7, 3], [2, 3, 7, 6], [4, 5, 1, 0]]:
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(v[f[i]])


## Vincha: anillo alrededor de la cabeza a la altura de la frente.
static func _ring(st: SurfaceTool, dy: float, height: float, out: float) -> void:
	var segs := 24
	for j in segs:
		var p0 := TAU * j / segs
		var p1 := TAU * (j + 1) / segs
		var r := RADII + Vector3.ONE * (0.046 + out)
		var a := CENTER + Vector3(sin(p0) * r.x, dy, cos(p0) * r.z)
		var b := CENTER + Vector3(sin(p1) * r.x, dy, cos(p1) * r.z)
		var q := [a, a + Vector3(0, height, 0), b + Vector3(0, height, 0), b]
		for idx in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
			st.set_uv(Vector2.ZERO)
			st.add_vertex(q[idx])


## Material del pelo: color mate con mechones (ruido estirado a lo largo).
static func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = _strands()
	m.uv1_scale = Vector3(6.0, 1.0, 1.0)
	return m


## Material de los mechones: hebras con transparencia recortada (sin
## problemas de orden), un brillo suave de pelo y de los dos lados.
static func cards_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _card_strands()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.45
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.55
	m.metallic_specular = 0.35
	return m


static var _card_tex: Texture2D
## Hebras: columnas finas de distinto largo y brillo, con las puntas que se
## afinan (alfa) hacia abajo.
static func _card_strands() -> Texture2D:
	if _card_tex != null:
		return _card_tex
	var w := 64
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for x in w:
		var bright := rng.randf_range(0.65, 1.0)
		var ends := rng.randf_range(0.65, 1.0)
		var gap := rng.randf() < 0.25
		for y in h:
			var t := float(y) / h
			var a := 0.0 if gap or t > ends else 1.0 - smoothstep(ends - 0.15, ends, t)
			var v := clampf(bright + rng.randf_range(-0.05, 0.05), 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, a))
	img.generate_mipmaps()
	_card_tex = ImageTexture.create_from_image(img)
	return _card_tex


static var _strand_tex: Texture2D
static func _strands() -> Texture2D:
	if _strand_tex != null:
		return _strand_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for x in 64:
		var base := rng.randf_range(0.7, 1.0)
		for y in 64:
			var v := clampf(base + rng.randf_range(-0.06, 0.06), 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	_strand_tex = ImageTexture.create_from_image(img)
	return _strand_tex
