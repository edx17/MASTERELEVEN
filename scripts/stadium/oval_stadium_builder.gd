class_name OvalStadiumBuilder
extends RefCounted
## Estadio ovalado gigante (ficticio, "Coloso del Sur"): un solo cuenco
## superelíptico de cuatro bandejas con butacas grises alrededor de una cancha
## hundida. Entre la 1.ª y la 2.ª, un anillo LED continuo; entre la 2.ª y la
## 3.ª, el anillo VIP vidriado (con las cabinas de TV sobre la tribuna
## principal); en el frente de la 3.ª, una cinta LED. Arriba, un techo
## traslúcido tipo PTFE con una pasarela (skywalk) y una línea de luz roja en
## el borde, sostenido por ~50 columnas de hormigón en V. Pantallas anchas en
## las cabeceras, bancos de suplentes embutidos y un único túnel central.
## Afuera: edificio de estacionamiento con puentes, el museo y las
## instalaciones del club.
##
## Las cuatro partes del cuenco se llaman StandNorth/South/West/East (como
## las tribunas de StadiumBuilder): la cámara oculta la de su lado.

## Borde interno del óvalo (primera fila) y forma (2 = elipse; más = más
## rectangular).
## Con esta forma las esquinas de la cancha quedan adentro con ~2,5 m de
## margen (lugar para patear el córner).
const A0 := Pitch.HALF_LENGTH + 12.0
const B0 := Pitch.HALF_WIDTH + 11.0
const SHAPE := 4.5
## Bandejas: [filas, subida por fila].
const TIERS := [[12, 0.42], [10, 0.5], [12, 0.56], [10, 0.64]]
## Entre bandejas: [corrimiento hacia afuera, subida] antes de la bandeja i.
const TIER_GAPS := [[0.0, 0.0], [1.4, 2.4], [3.2, 4.4], [1.4, 2.8]]
const ROW_DEPTH := 0.85
const SEAT_PITCH := 0.6
## Cancha hundida: la primera fila arranca a esta altura, sobre un muro.
const FIRST_ROW_Y := 2.6
## Nivel de la calle afuera (la cancha queda abajo).
const GROUND_Y := 7.0
const CROWD_DENSITY := 0.72
const SEAT_GREYS := [Color(0.62, 0.63, 0.66), Color(0.52, 0.53, 0.56)]
## Muestras del contorno por fila (forma) y columnas del techo.
const SAMPLES := 360
const COLUMNS := 50
const ROOF_DEPTH := 30.0
const ROOF_RISE := 9.0
const SECTORS := ["North", "South", "West", "East"]


## Punto del óvalo a `offset` m hacia afuera del borde interno, en el ángulo `t`.
static func ring_point(t: float, offset: float) -> Vector3:
	var c := cos(t)
	var s := sin(t)
	var e := 2.0 / SHAPE
	return Vector3(signf(c) * pow(absf(c), e) * (A0 + offset), 0.0, signf(s) * pow(absf(s), e) * (B0 + offset))


## Sector (StandNorth...) de un punto del cuenco.
static func sector_of(p: Vector3) -> int:
	var nx := p.x / A0
	var nz := p.z / B0
	if absf(nz) >= absf(nx):
		return 0 if nz < 0.0 else 1
	return 2 if nx < 0.0 else 3


static func build(home: TeamData, away: TeamData, style: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Stadium"
	StadiumBuilder.crowd_material = ShaderMaterial.new()
	StadiumBuilder.crowd_material.shader = preload("res://scripts/stadium/crowd.gdshader")
	var fans := {
		"home": home.color if home != null else Color(0.8, 0.15, 0.15),
		"home2": home.secondary_color if home != null else Color.WHITE,
		"away": away.color if away != null else Color(0.2, 0.3, 0.8),
	}
	var sectors: Array[Node3D] = []
	for n in SECTORS:
		var s := Node3D.new()
		s.name = "Stand" + n
		root.add_child(s)
		sectors.append(s)
	var top := _bowl(sectors, fans)
	_fascias(root, sectors, home)
	_roof(root, top)
	_screens(root, top, home, away)
	_tunnel(root, sectors[1])
	_surroundings(root, top)
	StadiumBuilder.tunnel_z = Pitch.HALF_WIDTH + float(style["gap"])
	StadiumBuilder._perimeter(root, style)
	StadiumBuilder._technical_area(root, style)
	return root


## Cuenco: escalones de hormigón, butacas y público, por sector. Devuelve
## {offset, y} de la última fila (para el techo y la fachada).
static func _bowl(sectors: Array[Node3D], fans: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9090
	var steps: Array[SurfaceTool] = []
	var seats: Array = [[], [], [], []] # [Transform3D, Color]
	var people: Array = [[], [], [], []]
	for i in 4:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		steps.append(st)
	var offset := 0.0
	var y := FIRST_ROW_Y
	# Muro de la cancha hundida (del césped a la primera fila).
	_ring_band(steps, 0.0, -0.3, 0.0, FIRST_ROW_Y + 1.0, 0.3, false, StadiumBuilder.TUNNEL_HALF + 0.4)
	var hole := StadiumBuilder.TUNNEL_HALF + 0.4
	# Bocas de salida (en la mitad de cada bandeja, una escalera sí y otra no)
	# y dónde están, para que el público salga por ahí (crowd.gdshader).
	var dark: Array[SurfaceTool] = []
	for i in 4:
		var dst := SurfaceTool.new()
		dst.begin(Mesh.PRIMITIVE_TRIANGLES)
		dark.append(dst)
	var tier_o := [1e5, 1e5, 1e5, 1e5]
	var vom_o := [1e5, 1e5, 1e5, 1e5]
	var vom_y := [0.0, 0.0, 0.0, 0.0]
	for ti in TIERS.size():
		var rows: int = TIERS[ti][0]
		var rise: float = TIERS[ti][1]
		offset += float(TIER_GAPS[ti][0])
		y += float(TIER_GAPS[ti][1])
		var vom_r := StadiumBuilder.vomitory_row(rows)
		tier_o[ti] = offset
		if vom_r >= 0:
			vom_o[ti] = offset + vom_r * ROW_DEPTH
			vom_y[ti] = y + vom_r * rise - rise
		for r in rows:
			var pts := _row_points(offset)
			var in_vom := vom_r >= 0 and r >= vom_r and r < vom_r + StadiumBuilder.VOM_ROWS
			if in_vom and r == vom_r:
				for j in STAIRS / 2:
					var phi := (2 * j + 1) * TAU / STAIRS
					if not _near_tunnel(polar_point(phi, offset), ti, y, hole):
						_vomitory(dark, phi, offset, y - rise, rise)
			# Escalón: pisada y contrahuella.
			for k in pts.size():
				var a: Vector3 = pts[k]
				var b: Vector3 = pts[(k + 1) % pts.size()]
				var mid := (a + b) * 0.5
				# Boca del túnel: sin escalones en la primera bandeja.
				if ti == 0 and mid.z > 0.0 and absf(mid.x) < hole and y < StadiumBuilder.TUNNEL_H + 0.4:
					continue
				if in_vom and _in_vomitory(mid, offset, ti, y, hole):
					continue
				var na := _normal_at(offset, a)
				var nb := _normal_at(offset, b)
				var sec := sector_of(mid)
				var st := steps[sec]
				var a2 := a + na * ROW_DEPTH
				var b2 := b + nb * ROW_DEPTH
				var up := Vector3.UP * y
				var down := Vector3.UP * (y - rise)
				_quad(st, a + up, b + up, b2 + up, a2 + up)
				_quad(st, a + down, b + down, b + up, a + up)
			# Butacas a paso fijo sobre el contorno.
			var acc := 0.0
			var grey: Color = SEAT_GREYS[ti % 2]
			for k in pts.size():
				var a: Vector3 = pts[k]
				var b: Vector3 = pts[(k + 1) % pts.size()]
				var seg := a.distance_to(b)
				while acc < seg:
					var p := a.lerp(b, acc / seg)
					acc += SEAT_PITCH
					if ti == 0 and p.z > 0.0 and absf(p.x) < hole and y < StadiumBuilder.TUNNEL_H + 0.4:
						continue
					if in_vom and _in_vomitory(p, offset, ti, y, hole):
						continue
					var n := _normal_at(offset, p)
					var pos := p + n * (ROW_DEPTH * 0.5) + Vector3.UP * y
					var basis := Basis.looking_at(-n, Vector3.UP)
					var sec := sector_of(p)
					# Escaleras radiales (alineadas fila a fila): sin butaca.
					if _stair_distance(p, offset) < SEAT_PITCH * 0.55:
						continue
					(seats[sec] as Array).append([Transform3D(basis, pos), grey])
					if rng.randf() < CROWD_DENSITY:
						var sc := rng.randf_range(0.92, 1.08)
						var away_end := p.x > A0 * 0.6
						(people[sec] as Array).append([Transform3D(basis.rotated(Vector3.UP, rng.randf_range(-0.3, 0.3)).scaled(Vector3.ONE * sc), pos),
							StadiumBuilder._fan_color(rng, fans, away_end)])
				acc -= seg
			offset += ROW_DEPTH
			y += rise
	var dark_mat := StadiumBuilder._mat(Color(0.015, 0.015, 0.02), 1.0)
	dark_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 4:
		var st := steps[i]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "Steps"
		mi.mesh = st.commit()
		mi.material_override = StadiumBuilder._concrete_mat()
		sectors[i].add_child(mi)
		var dst := dark[i]
		dst.generate_normals()
		var vm := MeshInstance3D.new()
		vm.name = "Vomitories"
		vm.mesh = dst.commit()
		vm.material_override = dark_mat
		vm.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		sectors[i].add_child(vm)
		_seats(sectors[i], seats[i])
		var crowd := _people(sectors[i], people[i])
		if crowd != null:
			crowd.set_instance_shader_parameter("layout_on", 2.0)
			crowd.set_instance_shader_parameter("tier_z", Vector4(tier_o[0], tier_o[1], tier_o[2], tier_o[3]))
			crowd.set_instance_shader_parameter("vom_z", Vector4(vom_o[0], vom_o[1], vom_o[2], vom_o[3]))
			crowd.set_instance_shader_parameter("vom_y", Vector4(vom_y[0], vom_y[1], vom_y[2], vom_y[3]))
			crowd.set_instance_shader_parameter("vom_step", TAU / STAIRS)
			crowd.set_instance_shader_parameter("oval", Vector3(A0, B0, SHAPE))
	# Fachada: del borde de atrás hasta la calle y más arriba (cierra el cuenco).
	var back := MeshInstance3D.new()
	back.name = "Facade"
	var fst: Array[SurfaceTool] = [SurfaceTool.new()]
	fst[0].begin(Mesh.PRIMITIVE_TRIANGLES)
	_ring_band(fst, offset, offset + 0.6, 0.0, y + 3.0, 0.0, true)
	fst[0].generate_normals()
	back.mesh = fst[0].commit()
	var facade_mat := StadiumBuilder._mat(Color(0.58, 0.58, 0.57), 0.9)
	facade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED # se ve de los dos lados
	back.material_override = facade_mat
	sectors[0].add_child(back)
	return {"offset": offset, "y": y}


const CONCRETE_LIGHT := Color(0.66, 0.66, 0.66)


static func _row_points(offset: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in SAMPLES:
		out.append(ring_point(TAU * k / SAMPLES, offset))
	return out


## Normal hacia afuera del óvalo cerca de `p` (por diferencias del contorno).
static func _normal_at(offset: float, p: Vector3) -> Vector3:
	var t := atan2(signf(p.z) * pow(absf(p.z) / (B0 + offset), SHAPE * 0.5),
		signf(p.x) * pow(absf(p.x) / (A0 + offset), SHAPE * 0.5))
	var a := ring_point(t - 0.002, offset)
	var b := ring_point(t + 0.002, offset)
	var tangent := (b - a).normalized()
	return Vector3(tangent.z, 0.0, -tangent.x)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		st.add_vertex(v)


## Banda vertical a lo largo del óvalo entre `off0` y `off1`, de `y0` a `y1`
## (muros, frentes). Con `single`, todo va al primer SurfaceTool.
static func _ring_band(sts: Array[SurfaceTool], off0: float, off1: float, y0: float, y1: float,
		_pad: float = 0.0, single: bool = false, tunnel_hole: float = 0.0) -> void:
	var n := 180
	for k in n:
		var t0 := TAU * k / n
		var t1 := TAU * (k + 1) / n
		var a0 := ring_point(t0, off0)
		var b0 := ring_point(t1, off0)
		var a1 := ring_point(t0, off1)
		var b1 := ring_point(t1, off1)
		var st := sts[0] if single else sts[sector_of((a0 + b0) * 0.5)]
		# Boca del túnel: el segmento (cerca del eje mide ~10 m por la forma del
		# óvalo) se corta en los bordes del túnel; adentro queda sólo el dintel.
		var cuts: Array[float] = [0.0, 1.0]
		if tunnel_hole > 0.0 and a0.z > 0.0 and b0.z > 0.0 and absf(b0.x - a0.x) > 0.001:
			for edge: float in [-tunnel_hole, tunnel_hole]:
				var u := (edge - a0.x) / (b0.x - a0.x)
				if u > 0.0 and u < 1.0:
					cuts.append(u)
			cuts.sort()
		for c in cuts.size() - 1:
			var u0 := cuts[c]
			var u1 := cuts[c + 1]
			var pa0 := a0.lerp(b0, u0)
			var pb0 := a0.lerp(b0, u1)
			var pa1 := a1.lerp(b1, u0)
			var pb1 := a1.lerp(b1, u1)
			var low := y0
			if tunnel_hole > 0.0 and pa0.z > 0.0 and absf((pa0.x + pb0.x) * 0.5) < tunnel_hole:
				if y1 <= StadiumBuilder.TUNNEL_H:
					continue
				low = maxf(y0, StadiumBuilder.TUNNEL_H)
			var lo := Vector3.UP * low
			var hi := Vector3.UP * y1
			_quad(st, pa0 + lo, pb0 + lo, pb0 + hi, pa0 + hi) # cara hacia la cancha
			_quad(st, pa1 + hi, pb1 + hi, pb1 + lo, pa1 + lo) # cara de atrás
			_quad(st, pa0 + hi, pb0 + hi, pb1 + hi, pa1 + hi) # tapa


static func _seats(parent: Node3D, list: Array) -> void:
	if list.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = StadiumBuilder._seat_mesh()
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i][0])
		mm.set_instance_color(i, list[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Seats"
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var m := StadiumBuilder._mat(Color.WHITE, 0.6)
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	parent.add_child(mi)


static func _people(parent: Node3D, list: Array) -> MultiMeshInstance3D:
	if list.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = StadiumBuilder._person_mesh()
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i][0])
		mm.set_instance_custom_data(i, list[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Crowd"
	mi.multimesh = mm
	mi.material_override = StadiumBuilder.crowd_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mi)
	return mi


## Escaleras radiales alrededor del cuenco (en las impares, bocas de salida).
const STAIRS := 48


## Punto de la fila a `offset` en el ángulo polar `phi` (desde el centro de
## la cancha). Las escaleras van a ángulos polares fijos: así quedan parejas
## alrededor del óvalo (el parámetro de ring_point amontona en las esquinas).
static func polar_point(phi: float, offset: float) -> Vector3:
	var a := A0 + offset
	var b := B0 + offset
	var c := cos(phi)
	var s := sin(phi)
	# tan(t) = (tan(phi)·a/b)^(S/2), con el cuadrante de phi.
	var r := pow(absf(s) * a / maxf(absf(c) * b, 1e-6), SHAPE * 0.5)
	var t := atan(r)
	return ring_point(atan2(signf(s) * sin(t), signf(c) * cos(t)) if absf(c) > 1e-6 else signf(s) * PI * 0.5, offset)


## Distancia (m) de un punto de la fila a la escalera más cercana.
static func _stair_distance(p: Vector3, offset: float) -> float:
	var ds := TAU / STAIRS
	var c := polar_point(roundf(atan2(p.z, p.x) / ds) * ds, offset)
	return Vector2(p.x, p.z).distance_to(Vector2(c.x, c.z))


## ¿El punto cae en el hueco de una boca de salida?
static func _in_vomitory(p: Vector3, offset: float, ti: int, y: float, hole: float) -> bool:
	var ds := TAU / STAIRS
	var k := roundf(atan2(p.z, p.x) / ds)
	if int(absf(k)) % 2 == 0:
		return false
	var c := polar_point(k * ds, offset)
	if _near_tunnel(c, ti, y, hole):
		return false
	return Vector2(p.x, p.z).distance_to(Vector2(c.x, c.z)) < StadiumBuilder.VOM_HALF


static func _near_tunnel(c: Vector3, ti: int, y: float, hole: float) -> bool:
	return ti == 0 and c.z > 0.0 and absf(c.x) < hole + StadiumBuilder.VOM_HALF + 1.0 and y < StadiumBuilder.TUNNEL_H + 3.0


## Boca de salida oscura en el ángulo polar `phi`: VOM_ROWS filas de fondo y de alto.
static func _vomitory(sts: Array[SurfaceTool], phi: float, offset: float, y0: float, rise: float) -> void:
	var c := polar_point(phi, offset)
	var n := _normal_at(offset, c)
	var tg := Vector3(-n.z, 0.0, n.x)
	var hw := StadiumBuilder.VOM_HALF
	var d := StadiumBuilder.VOM_ROWS * ROW_DEPTH
	var h := StadiumBuilder.VOM_ROWS * rise + 0.4
	var st := sts[sector_of(c)]
	var base := c + Vector3.UP * y0
	var p := [base - tg * hw + n * 0.05, base + tg * hw + n * 0.05, base + tg * hw + n * d, base - tg * hw + n * d]
	var up := Vector3.UP * h
	# Fondo, laterales, techo y piso (la boca queda abierta hacia la cancha).
	_quad(st, p[3], p[2], p[2] + up, p[3] + up)
	_quad(st, p[0], p[3], p[3] + up, p[0] + up)
	_quad(st, p[2], p[1], p[1] + up, p[2] + up)
	_quad(st, p[0] + up, p[3] + up, p[2] + up, p[1] + up)
	_quad(st, p[0], p[1], p[2], p[3])


## Offset y altura del frente de la bandeja `ti` (antes de su primera fila).
static func tier_front(ti: int) -> Vector2:
	var offset := 0.0
	var y := FIRST_ROW_Y
	for i in ti + 1:
		offset += float(TIER_GAPS[i][0])
		y += float(TIER_GAPS[i][1])
		if i < ti:
			offset += int(TIERS[i][0]) * ROW_DEPTH
			y += int(TIERS[i][0]) * float(TIERS[i][1])
	return Vector2(offset, y)


## Frentes entre bandejas: anillo LED (2.ª), anillo VIP vidriado con las
## cabinas de TV (3.ª) y cinta LED (4.ª).
static func _fascias(root: Node3D, sectors: Array[Node3D], home: TeamData) -> void:
	var c1 := home.color if home != null else Color(0.2, 0.5, 1.0)
	var c2 := home.secondary_color if home != null else Color(1.0, 1.0, 1.0)
	var led := ShaderMaterial.new()
	led.shader = preload("res://scripts/stadium/led_ring.gdshader")
	led.set_shader_parameter("color_a", c1)
	led.set_shader_parameter("color_b", c2)
	var ribbon := led.duplicate() as ShaderMaterial
	ribbon.set_shader_parameter("speed", -0.6)
	ribbon.set_shader_parameter("stripes", 140.0)
	var dark := StadiumBuilder._mat(Color(0.14, 0.15, 0.18), 0.6)
	var glass := StadiumBuilder._mat(Color(0.12, 0.16, 0.2), 0.08)
	glass.metallic = 0.6
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.82, 0.55)
	glass.emission_energy_multiplier = 0.12
	var specs := [
		# [bandeja, alto del frente, material del frente, material de la franja]
		[1, 2.4, dark, led],
		[2, 4.4, glass, null],
		[3, 2.8, dark, ribbon],
	]
	for spec: Array in specs:
		var f := tier_front(spec[0])
		var y_top: float = f.y - float(TIERS[spec[0]][1])
		var y_bot: float = y_top - float(spec[1])
		var off: float = f.x - 0.2
		var sts: Array[SurfaceTool] = []
		for i in 4:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			sts.append(st)
		_ring_band(sts, off, off + 0.3, y_bot, y_top)
		for i in 4:
			sts[i].generate_normals()
			var mi := MeshInstance3D.new()
			mi.name = "Fascia%d" % spec[0]
			mi.mesh = sts[i].commit()
			mi.material_override = spec[2]
			sectors[i].add_child(mi)
		if spec[3] != null:
			# Franja LED continua (con UV a lo largo para el shader).
			var band: Array[SurfaceTool] = []
			for i in 4:
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				band.append(st)
			# Arriba del frente: más abajo la tapan las cabezas de la última
			# fila de la bandeja de abajo.
			_led_band(band, off - 0.06, y_top - 1.1, y_top - 0.15)
			for i in 4:
				var mi := MeshInstance3D.new()
				mi.name = "Led%d" % spec[0]
				mi.mesh = band[i].commit()
				mi.material_override = spec[3]
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				sectors[i].add_child(mi)
	# Cabinas de TV sobre el anillo VIP, en el medio de la tribuna principal.
	var f2 := tier_front(2)
	var booth_mat := StadiumBuilder._mat(Color(0.22, 0.24, 0.28), 0.5)
	for k in 7:
		var x := -9.0 + k * 3.0
		var p := ring_point(-PI * 0.5 + x / (B0 * 2.0), f2.x - 0.4)
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.6, 1.8, 2.0)
		box.mesh = bm
		box.material_override = booth_mat
		box.position = Vector3(x, f2.y + 0.6, p.z - 0.6)
		sectors[0].add_child(box)
		var win := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(2.2, 0.8, 0.05)
		win.mesh = wm
		win.material_override = glass
		win.position = box.position + Vector3(0, 0.2, 1.02)
		sectors[0].add_child(win)


## Franja LED a lo largo del óvalo, mirando a la cancha, con UV.x = recorrido.
static func _led_band(sts: Array[SurfaceTool], off: float, y0: float, y1: float) -> void:
	var n := 240
	var length := 0.0
	for k in n:
		var t0 := TAU * k / n
		var t1 := TAU * (k + 1) / n
		var a := ring_point(t0, off)
		var b := ring_point(t1, off)
		var seg := a.distance_to(b)
		var st := sts[sector_of((a + b) * 0.5)]
		var u0 := length / 10.0
		var u1 := (length + seg) / 10.0
		var verts := [[a + Vector3.UP * y0, Vector2(u0, 1)], [b + Vector3.UP * y0, Vector2(u1, 1)],
			[b + Vector3.UP * y1, Vector2(u1, 0)], [a + Vector3.UP * y1, Vector2(u0, 0)]]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(verts[i][1])
			st.set_normal(-_normal_at(off, a))
			st.add_vertex(verts[i][0])
		length += seg


## Techo traslúcido (PTFE) en anillo, con la pasarela arriba, la línea roja en
## el borde interno y las columnas en V por fuera.
static func _roof(root: Node3D, top: Dictionary) -> void:
	var off_out: float = top["offset"] + 2.0
	var off_in: float = off_out - ROOF_DEPTH
	var y_out: float = top["y"] + ROOF_RISE
	var y_in: float = y_out - 3.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var red := SurfaceTool.new()
	red.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walk := SurfaceTool.new()
	walk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 200
	var mid_off := (off_in + off_out) * 0.55
	var mid_y := lerpf(y_in, y_out, 0.55)
	for k in n:
		var t0 := TAU * k / n
		var t1 := TAU * (k + 1) / n
		var ai := ring_point(t0, off_in) + Vector3.UP * y_in
		var bi := ring_point(t1, off_in) + Vector3.UP * y_in
		var ao := ring_point(t0, off_out) + Vector3.UP * y_out
		var bo := ring_point(t1, off_out) + Vector3.UP * y_out
		_quad(st, ai, bi, bo, ao)
		_quad(st, ao, bo, bi, ai)
		# Línea roja: canto del borde interno.
		_quad(red, ai, bi, bi + Vector3.DOWN * 0.45, ai + Vector3.DOWN * 0.45)
		_quad(red, ai + Vector3.DOWN * 0.45, bi + Vector3.DOWN * 0.45, bi, ai)
		# Pasarela sobre el techo.
		var wa := ring_point(t0, mid_off) + Vector3.UP * (mid_y + 0.35)
		var wb := ring_point(t1, mid_off) + Vector3.UP * (mid_y + 0.35)
		var wa2 := ring_point(t0, mid_off + 2.2) + Vector3.UP * (mid_y + 0.55)
		var wb2 := ring_point(t1, mid_off + 2.2) + Vector3.UP * (mid_y + 0.55)
		_quad(walk, wa, wb, wb2, wa2)
		_quad(walk, wa2, wb2, wb, wa)
		_quad(walk, wa, wb, wb + Vector3.UP * 1.1, wa + Vector3.UP * 1.1)
	st.generate_normals()
	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	roof.mesh = st.commit()
	var ptfe := StandardMaterial3D.new()
	ptfe.albedo_color = Color(0.94, 0.94, 0.92, 0.72)
	ptfe.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ptfe.roughness = 0.7
	ptfe.cull_mode = BaseMaterial3D.CULL_DISABLED
	ptfe.emission_enabled = true
	ptfe.emission = Color(1, 1, 1)
	ptfe.emission_energy_multiplier = 0.12
	roof.material_override = ptfe
	root.add_child(roof)
	var red_mi := MeshInstance3D.new()
	red_mi.name = "RoofRedLine"
	red_mi.mesh = red.commit()
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.9, 0.05, 0.05)
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.08, 0.05)
	rm.emission_energy_multiplier = 3.0
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	red_mi.material_override = rm
	red_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(red_mi)
	walk.generate_normals()
	var walk_mi := MeshInstance3D.new()
	walk_mi.name = "Skywalk"
	walk_mi.mesh = walk.commit()
	walk_mi.material_override = StadiumBuilder._mat(Color(0.3, 0.32, 0.36), 0.6)
	root.add_child(walk_mi)
	# Columnas en V: dos patas desde un mismo pie en la calle hasta el borde
	# exterior del techo.
	var cols := SurfaceTool.new()
	cols.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in COLUMNS:
		var t := TAU * (k + 0.5) / COLUMNS
		var foot := ring_point(t, off_out + 4.0) + Vector3.UP * GROUND_Y
		for side: float in [-1.0, 1.0]:
			var head := ring_point(t + side * TAU / COLUMNS * 0.45, off_out) + Vector3.UP * y_out
			var axis := head - foot
			var basis := Basis()
			basis.y = axis.normalized()
			basis.x = basis.y.cross(Vector3.UP).normalized()
			if basis.x.length() < 0.5:
				basis.x = Vector3.RIGHT
			basis.z = basis.x.cross(basis.y).normalized()
			StadiumBuilder._obox(cols, Transform3D(basis, (foot + head) * 0.5), Vector3(1.2, axis.length(), 1.2))
	cols.generate_normals()
	var cols_mi := MeshInstance3D.new()
	cols_mi.name = "VColumns"
	cols_mi.mesh = cols.commit()
	cols_mi.material_override = StadiumBuilder._concrete_mat()
	root.add_child(cols_mi)


## Pantallas anchas colgadas en las dos cabeceras.
static func _screens(root: Node3D, top: Dictionary, home: TeamData, away: TeamData) -> void:
	var frame := StadiumBuilder._mat(Color(0.08, 0.08, 0.1), 0.4)
	var screen := StandardMaterial3D.new()
	screen.albedo_color = Color(0.05, 0.12, 0.3)
	screen.emission_enabled = true
	screen.emission = Color(0.1, 0.25, 0.6)
	screen.emission_energy_multiplier = 1.2
	var text := "%s  vs  %s" % [home.short_name if home != null else "LOCAL", away.short_name if away != null else "VISITA"]
	for sx: int in [-1, 1]:
		var p := ring_point(0.0 if sx > 0 else PI, float(top["offset"]) - 12.0)
		var node := Node3D.new()
		node.name = "Screen_%s" % ("E" if sx > 0 else "W")
		node.position = Vector3(p.x, float(top["y"]) + 2.5, 0.0)
		node.rotation.y = -sx * PI * 0.5
		root.add_child(node)
		var f := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(26.0, 10.0, 0.8)
		f.mesh = fb
		f.material_override = frame
		node.add_child(f)
		var s := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(24.6, 8.8, 0.1)
		s.mesh = sb
		s.material_override = screen
		s.position.z = 0.42
		node.add_child(s)
		var l := Label3D.new()
		l.text = text
		l.font_size = 220
		l.pixel_size = 0.02
		l.modulate = Color(1, 1, 1)
		l.outline_size = 0
		l.position = Vector3(0, 0, 0.5)
		node.add_child(l)


## Único túnel central, bajo la tribuna sur (la de la cámara).
static func _tunnel(_root: Node3D, south: Node3D) -> void:
	var t := Node3D.new()
	t.name = "Tunnel"
	t.basis = Basis.looking_at(Vector3(0, 0, -1), Vector3.UP)
	t.position = Vector3(0.0, 0.0, B0)
	south.add_child(t)
	StadiumBuilder._tunnel(t)


## Alrededores a nivel de la calle: explanada, estacionamiento con puentes al
## estadio, el museo y las instalaciones del club.
static func _surroundings(root: Node3D, top: Dictionary) -> void:
	var node := Node3D.new()
	node.name = "Surroundings"
	root.add_child(node)
	var outer: float = top["offset"]
	# Explanada a nivel de la calle: un anillo alrededor del estadio (adentro
	# queda el pozo con la cancha hundida).
	var pst := SurfaceTool.new()
	pst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 120
	for k in n:
		var t0 := TAU * k / n
		var t1 := TAU * (k + 1) / n
		var a := ring_point(t0, outer) + Vector3.UP * (GROUND_Y - 0.02)
		var b := ring_point(t1, outer) + Vector3.UP * (GROUND_Y - 0.02)
		var a2 := ring_point(t0, outer + 260.0) + Vector3.UP * (GROUND_Y - 0.02)
		var b2 := ring_point(t1, outer + 260.0) + Vector3.UP * (GROUND_Y - 0.02)
		_quad(pst, a, a2, b2, b)
	pst.generate_normals()
	var plaza := MeshInstance3D.new()
	plaza.name = "Plaza"
	plaza.mesh = pst.commit()
	var pmat := StadiumBuilder._mat(Color(0.5, 0.5, 0.48), 0.95)
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	plaza.material_override = pmat
	node.add_child(plaza)
	var concrete := StadiumBuilder._mat(Color(0.6, 0.6, 0.58), 0.9)
	var deck := StadiumBuilder._mat(Color(0.35, 0.36, 0.38), 0.9)
	# Estacionamiento de 5 pisos (losas y columnas) con dos puentes.
	var park := Vector3(-A0 - outer - 70.0, GROUND_Y, -60.0)
	for lvl in 5:
		_box(node, park + Vector3(0, lvl * 3.4 + 0.2, 0), Vector3(70, 0.4, 46), deck)
		_box(node, park + Vector3(0, lvl * 3.4 + 1.0, 23.0), Vector3(70, 1.0, 0.3), concrete)
	for cx in 6:
		for cz in 4:
			_box(node, park + Vector3(-30 + cx * 12, 7.0, -18 + cz * 12), Vector3(0.6, 14.0, 0.6), concrete)
	for bz: float in [-12.0, 12.0]:
		var start := park + Vector3(35.0, 10.4, bz)
		var end := ring_point(PI + bz / 60.0, outer + 2.0) + Vector3.UP * (GROUND_Y + 10.4)
		var mid := (start + end) * 0.5
		var len := Vector2(end.x - start.x, end.z - start.z).length()
		var bridge := _box(node, mid, Vector3(len, 0.5, 4.0), concrete)
		bridge.rotation.y = -atan2(end.z - start.z, end.x - start.x)
	# Museo: cilindro vidriado sobre un basamento, detrás de la tribuna principal.
	var museum := Vector3(40.0, GROUND_Y, -B0 - outer - 60.0)
	_box(node, museum + Vector3(0, 2.0, 0), Vector3(46, 4, 30), concrete)
	var cyl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 12.0
	cm.bottom_radius = 12.0
	cm.height = 14.0
	cyl.mesh = cm
	var glass := StadiumBuilder._mat(Color(0.25, 0.35, 0.42), 0.1)
	glass.metallic = 0.5
	cyl.material_override = glass
	cyl.position = museum + Vector3(-8, 11.0, 0)
	node.add_child(cyl)
	# Instalaciones del club: edificios bajos y una cancha auxiliar.
	var club := Vector3(A0 + outer + 60.0, GROUND_Y, 40.0)
	_box(node, club + Vector3(0, 4, -30), Vector3(40, 8, 16), StadiumBuilder._mat(Color(0.82, 0.8, 0.75)))
	_box(node, club + Vector3(30, 3, -30), Vector3(18, 6, 16), StadiumBuilder._mat(Color(0.75, 0.73, 0.7)))
	var aux := MeshInstance3D.new()
	var am := PlaneMesh.new()
	am.size = Vector2(60, 40)
	aux.mesh = am
	aux.material_override = StadiumBuilder._mat(Color(0.22, 0.4, 0.17))
	aux.position = club + Vector3(0, 0.02, 15)
	node.add_child(aux)


static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
