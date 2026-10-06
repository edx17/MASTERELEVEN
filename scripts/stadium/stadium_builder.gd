class_name StadiumBuilder
extends RefCounted
## Estadio modular generado por código (reemplazable por uno modelado en la
## Fase 5): tribunas escalonadas con butacas instanciadas (MultiMesh), el nombre
## del club local "escrito" con butacas, techo con vigas (proyecta franjas de
## sombra sobre el césped), muro perimetral, carteles lisos, bancos y área
## técnica. Sin marcas ni escudos reales.

## Distancia de la línea al muro perimetral y al primer escalón.
const WALL_GAP := 5.0
const STAND_GAP := 7.0
const ROW_DEPTH := 0.85
const ROW_RISE := 0.45
const SEAT_PITCH := 0.55

const SEAT_BASE := Color(0.72, 0.72, 0.74)
const CONCRETE := Color(0.42, 0.42, 0.44)


## Butacas: el color del club más profundo y saturado (con sol pleno un
## celeste o un amarillo claros se lavan a blanco; en la referencia las
## tribunas se ven de un color firme).
static func seat_tone(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(1.0, c.s * 1.25 + 0.1), c.v * 0.72)


## `home` define los colores de las butacas y el nombre en la tribuna.
## Material compartido del público (MatchController lo hace saltar en los goles).
static var crowd_material: ShaderMaterial
## Proporción de butacas ocupadas.
const CROWD_DENSITY := 0.85


## Boca del túnel (z del mundo, del lado de la cámara) del último estadio
## armado; la presentación saca a los equipos por acá.
static var tunnel_z := Pitch.HALF_WIDTH + 7.0
const TUNNEL_HALF := 2.4
const TUNNEL_H := 3.2
const TUNNEL_DEPTH := 16.0


## Arma el estadio `style` (StadiumStyles; por defecto, el del partido).
static func build(home: TeamData, away: TeamData = null, style: Dictionary = {}) -> Node3D:
	if style.is_empty():
		style = StadiumStyles.current
	if style.get("oval", false):
		return OvalStadiumBuilder.build(home, away, style)
	var root := Node3D.new()
	root.name = "Stadium"
	var seat_color := seat_tone(home.color) if home != null else Color(0.8, 0.15, 0.15)
	if style.get("seat") != null:
		seat_color = style["seat"]
	var text_color := home.secondary_color if home != null else Color.WHITE
	if text_color.get_luminance() < 0.25 or text_color.is_equal_approx(seat_color):
		text_color = Color(0.95, 0.95, 0.95)
	var name := home.team_name.to_upper() if home != null else "MASTER ELEVEN"
	crowd_material = ShaderMaterial.new()
	crowd_material.shader = preload("res://scripts/stadium/crowd.gdshader")
	var fans := {
		"home": home.color if home != null else Color(0.8, 0.15, 0.15),
		"home2": home.secondary_color if home != null else Color.WHITE,
		"away": away.color if away != null else Color(0.2, 0.3, 0.8),
	}
	var ctx := {"seat": seat_color, "text_color": text_color, "fans": fans, "style": style}
	var gap: float = style["gap"]
	var hl := Pitch.HALF_LENGTH
	var hw := Pitch.HALF_WIDTH
	var stands: Dictionary = style["stands"]
	var corners: Array = style["corners"]
	var closed := not corners.is_empty()
	# Con esquinas, las tribunas cubren el largo de la cancha y se abren hacia
	# atrás (22,5° por lado) para empalmar en diagonal con las esquinas.
	var widen := 2.0 * tan(PI / 8.0) if closed else 0.0
	var side_len := hl * 2.0 + (0.0 if closed else 20.0)
	var end_len := hw * 2.0 + (0.0 if closed else 14.0)
	# Tribuna principal (frente a la cámara) con el nombre del club.
	var main := _stand(root, "North", Vector3(0, 0, -1), side_len, stands["North"], ctx,
			{"text": name if style["club_text"] else "", "widen": widen})
	_stand(root, "West", Vector3(-1, 0, 0), end_len, stands["West"], ctx, {"widen": widen})
	_stand(root, "East", Vector3(1, 0, 0), end_len, stands["East"], ctx, {"widen": widen, "away_end": true})
	# Detrás de la cámara (casi no se ve; da sombra y cierre); acá está el túnel.
	_stand(root, "South", Vector3(0, 0, 1), side_len, stands["South"], ctx, {"widen": widen, "tunnel": true})
	if closed:
		for sx: int in [-1, 1]:
			for sz: int in [-1, 1]:
				var corner_name := ("North" if sz < 0 else "South") + ("West" if sx < 0 else "East")
				_stand(root, corner_name, Vector3(sx, 0, sz).normalized(), gap * sqrt(2.0), corners, ctx,
						{"widen": widen, "away_end": sx > 0, "roof_key": "Corner",
						"position": Vector3(sx * (hl + gap * 0.5), 0.0, sz * (hw + gap * 0.5))})
	tunnel_z = hw + gap
	_perimeter(root, style)
	_technical_area(root, style)
	if style["track"]:
		_track(root, style)
	if style["towers"]:
		_towers(root, style, main)
	return root


static func _mat(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## Hormigón con manchas y poros (textura de ruido generada, sin archivos).
static var _concrete: StandardMaterial3D
static func _concrete_mat() -> StandardMaterial3D:
	if _concrete != null:
		return _concrete
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 5
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, CONCRETE.darkened(0.25))
	ramp.set_color(1, CONCRETE.lightened(0.15))
	tex.color_ramp = ramp
	var bump := NoiseTexture2D.new()
	bump.width = 256
	bump.height = 256
	bump.seamless = true
	bump.as_normal_map = true
	bump.bump_strength = 4.0
	bump.noise = noise
	_concrete = StandardMaterial3D.new()
	_concrete.albedo_texture = tex
	_concrete.normal_enabled = true
	_concrete.normal_texture = bump
	_concrete.roughness = 0.9
	_concrete.uv1_triplanar = true
	_concrete.uv1_scale = Vector3(0.25, 0.25, 0.25)
	return _concrete


## Una tribuna mirando hacia el centro. `outward` apunta desde la cancha hacia
## la tribuna. Cada elemento de `tiers` es la cantidad de filas de una bandeja.
## opts: text (nombre con butacas), away_end, widen (cuánto se alarga cada fila
## por metro hacia atrás), position (frente, si no es una lateral), tunnel
## (hueco del túnel en el centro), roof_key (tipo de techo a usar).
## Devuelve {"depth", "height", "length"} de la tribuna terminada.
static func _stand(root: Node3D, stand_name: String, outward: Vector3, length: float, tiers: Array,
		ctx: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var style: Dictionary = ctx["style"]
	var fans: Dictionary = ctx["fans"]
	var seat_color: Color = ctx["seat"]
	var text_color: Color = ctx["text_color"]
	var text: String = opts.get("text", "")
	var away_end: bool = opts.get("away_end", false)
	var widen: float = opts.get("widen", 0.0)
	var tunnel: bool = opts.get("tunnel", false)
	var tier_colors: Array = style.get("tier_colors", [])
	var tier_step: Array = style["tier_step"]
	var stand := Node3D.new()
	stand.name = "Stand" + stand_name
	root.add_child(stand)
	# Distancia desde el centro hasta la línea de este lado.
	var edge := Pitch.HALF_WIDTH if absf(outward.z) > 0.5 else Pitch.HALF_LENGTH
	# Base de la tribuna orientada: X local = a lo largo, Z local = hacia afuera.
	stand.basis = Basis.looking_at(-outward, Vector3.UP)
	stand.position = opts.get("position", outward * (edge + float(style["gap"])))

	var base_seats := int(length / SEAT_PITCH)
	# Butacas por fila (las filas se alargan hacia atrás si la tribuna empalma
	# con las esquinas).
	var rows_seats: Array[int] = []
	var zz := 0.0
	for tier_i in tiers.size():
		if tier_i > 0:
			zz += float(tier_step[0])
		for r in int(tiers[tier_i]):
			rows_seats.append(int((length + widen * zz) / SEAT_PITCH))
			zz += ROW_DEPTH
	var total := 0
	for n in rows_seats:
		total += n
	var seat_mesh := _seat_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = seat_mesh
	mm.instance_count = total
	var steps := SurfaceTool.new()
	steps.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fascia := SurfaceTool.new()
	fascia.begin(Mesh.PRIMITIVE_TRIANGLES)

	var letters := PixelFont.layout(text, base_seats, tiers[0] if tiers.size() > 0 else 0)
	# Público: personas en una parte de las butacas (no en las escaleras ni
	# sobre las letras del nombre del club).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(stand_name)
	var people: Array[Transform3D] = []
	var people_custom: Array[Color] = []
	var idx := 0
	var row_global := 0
	var y := 0.0
	var z := 0.0
	# Hueco del túnel: sin escalones ni butacas sobre la boca.
	var hole := TUNNEL_HALF + 0.35
	# Bocas de salida (vomitorios): en la mitad de cada bandeja, en un pasillo
	# sí y otro no. Por ahí se va el público al final.
	var vom := MeshInstance3D.new()
	var vom_st := SurfaceTool.new()
	vom_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tier_z := [1e5, 1e5, 1e5, 1e5]
	var vom_z := [1e5, 1e5, 1e5, 1e5]
	var vom_y := [0.0, 0.0, 0.0, 0.0]
	for tier_i in tiers.size():
		var rows: int = tiers[tier_i]
		var tier_seat := seat_color
		if tier_i < tier_colors.size():
			tier_seat = tier_colors[tier_i]
		if tier_i > 0:
			# Pasillo y voladizo entre bandejas: frente oscuro de la bandeja
			# superior (como en los estadios modernos).
			z += float(tier_step[0])
			y += float(tier_step[1])
			var fl := (length + widen * z) * 0.5
			_box(fascia, Vector3(-fl, y - ROW_RISE - 2.2, z - 0.4), Vector3(fl, y - ROW_RISE + 0.3, z))
		var front_len := length + widen * z
		var cut := hole if tunnel and tier_i == 0 else 0.0
		# Baranda al frente de cada bandeja, con banderas de los hinchas.
		_railing(stand, front_len, y - ROW_RISE, z - 0.1, cut)
		if not fans.is_empty():
			_banners(stand, front_len, y - ROW_RISE, z - 0.15, fans, away_end, rng, cut)
		var vom_r := vomitory_row(rows)
		if tier_i < 4:
			tier_z[tier_i] = z
			if vom_r >= 0:
				vom_z[tier_i] = z + vom_r * ROW_DEPTH
				vom_y[tier_i] = y + vom_r * ROW_RISE - ROW_RISE
		for r in rows:
			var seats_per_row: int = rows_seats[row_global]
			var row_len := seats_per_row * SEAT_PITCH
			var in_hole := tunnel and y - ROW_RISE < TUNNEL_H + 0.3
			var shift := (seats_per_row - base_seats) / 2
			# Huecos de la fila: la boca del túnel y las de salida.
			var holes: Array = []
			if in_hole:
				holes.append([-hole, hole])
			var in_vom := vom_r >= 0 and r >= vom_r and r < vom_r + VOM_ROWS
			if in_vom:
				for vx in vomitory_xs(seats_per_row, shift):
					if not (tunnel and absf(vx) < hole + VOM_HALF + 1.0):
						holes.append([vx - VOM_HALF, vx + VOM_HALF])
						if r == vom_r:
							_vomitory(vom_st, steps, vx, y - ROW_RISE, z)
			# Escalón de hormigón (partido donde hay huecos).
			holes.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			var from := -row_len * 0.5
			for hseg in holes:
				if hseg[0] > from:
					_box(steps, Vector3(from, y - ROW_RISE, z), Vector3(hseg[0], y, z + ROW_DEPTH))
				from = maxf(from, hseg[1])
			if from < row_len * 0.5:
				_box(steps, Vector3(from, y - ROW_RISE, z), Vector3(row_len * 0.5, y, z + ROW_DEPTH))
			for s in seats_per_row:
				var x := -row_len * 0.5 + (s + 0.5) * SEAT_PITCH
				var c := tier_seat
				var stair := (s - shift) % 24 == 0
				# El eje X local de la tribuna mira al revés que la cámara: se invierte.
				if not stair and tier_i == 0 and letters.has(Vector2i(base_seats - 1 - (s - shift), rows - 1 - r)):
					c = text_color
				var in_gap := false
				for hseg in holes:
					in_gap = in_gap or (x > hseg[0] and x < hseg[1])
				if in_gap or stair:
					c = Color(0, 0, 0, 0)
					mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
					# Escalera: medio escalón en el pasillo (sin butaca).
					if stair and not in_gap:
						_box(steps, Vector3(x - SEAT_PITCH * 0.5, y - ROW_RISE * 0.5 - 0.04, z),
							Vector3(x + SEAT_PITCH * 0.5, y - ROW_RISE * 0.5, z + ROW_DEPTH * 0.5))
				else:
					mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY, Vector3(x, y, z + ROW_DEPTH * 0.5)))
				mm.set_instance_color(idx, c)
				idx += 1
				if c == tier_seat and not fans.is_empty() and rng.randf() < CROWD_DENSITY * GameSettings.crowd_factor():
					var scale := rng.randf_range(0.92, 1.08)
					var tf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)).scaled(Vector3(scale, scale, scale)),
						Vector3(x + rng.randf_range(-0.05, 0.05), y, z + ROW_DEPTH * 0.5))
					people.append(tf)
					people_custom.append(_fan_color(rng, fans, away_end))
			y += ROW_RISE
			z += ROW_DEPTH
			row_global += 1
	vom_st.generate_normals()
	vom.mesh = vom_st.commit()
	vom.name = "Vomitories"
	var dark := _mat(Color(0.015, 0.015, 0.02), 1.0)
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	vom.material_override = dark
	vom.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	stand.add_child(vom)
	steps.generate_normals()
	var steps_mi := MeshInstance3D.new()
	steps_mi.mesh = steps.commit()
	steps_mi.material_override = _concrete_mat()
	stand.add_child(steps_mi)

	if tiers.size() > 1:
		fascia.generate_normals()
		var fascia_mi := MeshInstance3D.new()
		fascia_mi.mesh = fascia.commit()
		fascia_mi.material_override = _mat(Color(0.2, 0.21, 0.24), 0.6)
		stand.add_child(fascia_mi)

	if not people.is_empty():
		var crowd_mm := MultiMesh.new()
		crowd_mm.transform_format = MultiMesh.TRANSFORM_3D
		crowd_mm.use_custom_data = true
		crowd_mm.mesh = _person_mesh()
		crowd_mm.instance_count = people.size()
		for i in people.size():
			crowd_mm.set_instance_transform(i, people[i])
			crowd_mm.set_instance_custom_data(i, people_custom[i])
		var crowd := MultiMeshInstance3D.new()
		crowd.name = "Crowd"
		crowd.multimesh = crowd_mm
		crowd.material_override = crowd_material
		crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Fuera de la iluminación global: SDFGI re-voxeliza lo estático cada
		# vez que la cámara cambia de zona (decenas de miles de instancias =
		# tirones). Escalones, paredes y techos alcanzan para el rebote.
		crowd.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		stand.add_child(crowd)
		# Dónde están los pasillos y las bocas de salida (para que el público
		# se vaya caminando por ahí: crowd.gdshader).
		var xf := stand.transform
		crowd.set_instance_shader_parameter("layout_on", 1.0)
		crowd.set_instance_shader_parameter("st_origin", xf.origin)
		crowd.set_instance_shader_parameter("st_x", xf.basis.x.normalized())
		crowd.set_instance_shader_parameter("st_z", xf.basis.z.normalized())
		crowd.set_instance_shader_parameter("tier_z", Vector4(tier_z[0], tier_z[1], tier_z[2], tier_z[3]))
		crowd.set_instance_shader_parameter("vom_z", Vector4(vom_z[0], vom_z[1], vom_z[2], vom_z[3]))
		crowd.set_instance_shader_parameter("vom_y", Vector4(vom_y[0], vom_y[1], vom_y[2], vom_y[3]))
		crowd.set_instance_shader_parameter("vom_x0", vomitory_x0(base_seats))
		crowd.set_instance_shader_parameter("vom_step", VOM_EVERY * SEAT_PITCH)

	var seats := MultiMeshInstance3D.new()
	seats.multimesh = mm
	# Las butacas no proyectan sombra (miles de instancias en cada pasada de
	# sombra; los escalones ya dan la sombra de la tribuna).
	seats.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seats.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var seat_mat := _mat(Color.WHITE, 0.6)
	seat_mat.vertex_color_use_as_albedo = true
	seats.material_override = seat_mat
	stand.add_child(seats)

	# Pared trasera.
	var back_len := length + widen * z
	var back := MeshInstance3D.new()
	var back_box := BoxMesh.new()
	back_box.size = Vector3(back_len, y + 6.0, 0.6)
	back.mesh = back_box
	back.material_override = _mat(Color(0.2, 0.2, 0.23))
	back.position = Vector3(0, (y + 6.0) * 0.5 - 1.0, z + 0.5)
	stand.add_child(back)
	var roofs: Dictionary = style["roof"]
	var roof_type: String = roofs.get(opts.get("roof_key", stand_name), "beams")
	_roof(stand, roof_type, back_len, length, y, z)
	if tunnel:
		_tunnel(stand)
	return {"depth": z, "height": y, "length": back_len}


## Techo de una tribuna terminada (`y`, `z`: arriba y fondo de la última fila).
static func _roof(stand: Node3D, roof_type: String, back_len: float, front_len: float, y: float, z: float) -> void:
	match roof_type:
		"none":
			# Sin techo: un parapeto de hormigón remata la última fila.
			var rim := MeshInstance3D.new()
			var rb := BoxMesh.new()
			rb.size = Vector3(back_len, 1.2, 0.5)
			rim.mesh = rb
			rim.material_override = _concrete_mat()
			rim.position = Vector3(0, y + 0.6, z + 0.2)
			stand.add_child(rim)
		"cantilever":
			# Voladizo liviano que cubre toda la tribuna, sin columnas: chapa
			# clara por debajo, borde blanco al frente y cerchas por arriba.
			var roof_y := y + 4.0
			var depth := z + 3.0
			var plate := MeshInstance3D.new()
			var pb := BoxMesh.new()
			pb.size = Vector3(back_len, 0.3, depth)
			plate.mesh = pb
			plate.material_override = _mat(Color(0.72, 0.73, 0.75), 0.7)
			plate.position = Vector3(0, roof_y, z + 0.5 - depth * 0.5)
			plate.rotation.x = -0.06
			stand.add_child(plate)
			var white := _mat(Color(0.93, 0.93, 0.94), 0.5)
			var edge := MeshInstance3D.new()
			var eb := BoxMesh.new()
			eb.size = Vector3((back_len + front_len) * 0.5, 0.9, 0.5)
			edge.mesh = eb
			edge.material_override = white
			edge.position = Vector3(0, roof_y + 0.35 - depth * 0.06 * 0.5, z + 0.5 - depth)
			stand.add_child(edge)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var trusses := int(back_len / 12.0)
			for i in trusses + 1:
				var x := -back_len * 0.5 + i * (back_len / trusses)
				_box(st, Vector3(x - 0.2, roof_y + 0.2, z + 0.5 - depth), Vector3(x + 0.2, roof_y + 2.4, z + 0.5))
			st.generate_normals()
			var tr := MeshInstance3D.new()
			tr.mesh = st.commit()
			tr.material_override = white
			# Van sobre el techo: no rayan el césped con sombras.
			tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			stand.add_child(tr)
		"truss":
			# Techo oscuro sostenido por vigas rojas enormes: una a lo largo del
			# frente y otras que cruzan por encima.
			var roof_y2 := y + 5.0
			var depth2 := z + 8.0
			var red := _mat(Color(0.62, 0.08, 0.08), 0.55)
			var plate2 := MeshInstance3D.new()
			var pb2 := BoxMesh.new()
			pb2.size = Vector3(back_len, 0.3, depth2)
			plate2.mesh = pb2
			plate2.material_override = _mat(Color(0.32, 0.33, 0.36), 0.6)
			plate2.position = Vector3(0, roof_y2, z + 0.5 - depth2 * 0.5)
			stand.add_child(plate2)
			var st2 := SurfaceTool.new()
			st2.begin(Mesh.PRIMITIVE_TRIANGLES)
			_box(st2, Vector3(-back_len * 0.5, roof_y2 + 0.15, z + 0.5 - depth2), Vector3(back_len * 0.5, roof_y2 + 3.0, z + 0.5 - depth2 + 1.4))
			var girders := int(back_len / 16.0)
			for i in girders + 1:
				var x2 := -back_len * 0.5 + i * (back_len / girders)
				_box(st2, Vector3(x2 - 0.45, roof_y2 + 0.15, z + 0.5 - depth2), Vector3(x2 + 0.45, roof_y2 + 2.2, z + 0.5))
			st2.generate_normals()
			var g := MeshInstance3D.new()
			g.mesh = st2.commit()
			g.material_override = red
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			stand.add_child(g)
		_:
			# Techo con vigas (dejan franjas de sombra sobre el césped).
			var roof_y3 := y + 5.0
			var roof_depth := z + 8.0
			var beam_mat := _mat(Color(0.25, 0.25, 0.28))
			var beams := int(back_len / 9.0)
			for b in beams + 1:
				var beam := MeshInstance3D.new()
				var bb := BoxMesh.new()
				bb.size = Vector3(0.35, 0.6, roof_depth)
				beam.mesh = bb
				beam.material_override = beam_mat
				# Las vigas no rayan el césped (con 4 torres de luz se cruzan y
				# arman triángulos); la sombra del techo la da la chapa.
				beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				beam.position = Vector3(-back_len * 0.5 + b * (back_len / beams), roof_y3, z + 0.5 - roof_depth * 0.5)
				stand.add_child(beam)
			var roof := MeshInstance3D.new()
			var rb3 := BoxMesh.new()
			rb3.size = Vector3(back_len, 0.3, roof_depth * 0.55)
			roof.mesh = rb3
			roof.material_override = _mat(Color(0.3, 0.3, 0.33))
			roof.position = Vector3(0, roof_y3 + 0.6, z + 0.5 - roof_depth * 0.275)
			stand.add_child(roof)


## Túnel bajo la tribuna (coordenadas de la tribuna sur): marco de hormigón en
## la boca y adentro todo negro (paredes, techo y fondo), así se ve el hueco y
## los jugadores salen de la oscuridad.
static func _tunnel(stand: Node3D) -> void:
	# Pasillo iluminado (como en los estadios de verdad): paredes pintadas,
	# piso de goma y paneles de luz en el techo; más adentro, más oscuro.
	var wall := StandardMaterial3D.new()
	# Paredes claras (gris cálido): con las luces del techo el pasillo se ve
	# iluminado, no una cueva.
	wall.albedo_color = Color(0.62, 0.6, 0.56)
	wall.roughness = 0.8
	var h := TUNNEL_HALF
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(-h - 0.4, 0.0, 0.3), Vector3(-h, TUNNEL_H, TUNNEL_DEPTH))
	_box(st, Vector3(h, 0.0, 0.3), Vector3(h + 0.4, TUNNEL_H, TUNNEL_DEPTH))
	_box(st, Vector3(-h - 0.4, TUNNEL_H, 0.3), Vector3(h + 0.4, TUNNEL_H + 0.4, TUNNEL_DEPTH))
	_box(st, Vector3(-h, 0.0, TUNNEL_DEPTH - 0.3), Vector3(h, TUNNEL_H, TUNNEL_DEPTH))
	_box(st, Vector3(-h, -0.05, 0.3), Vector3(h, 0.01, TUNNEL_DEPTH))
	st.generate_normals()
	var inside := MeshInstance3D.new()
	inside.name = "Tunnel"
	inside.mesh = st.commit()
	inside.material_override = wall
	stand.add_child(inside)
	# Paneles de luz en el techo y lámparas (sin sombras: baratas).
	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = Color(1.0, 0.97, 0.9)
	panel_mat.emission_enabled = true
	panel_mat.emission = Color(1.0, 0.95, 0.85)
	panel_mat.emission_energy_multiplier = 3.0
	var n := 4
	for i in n:
		var z := lerpf(0.9, TUNNEL_DEPTH - 1.0, float(i) / maxf(n - 1, 1))
		var lamp := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(h * 1.1, 0.05, 0.6)
		lamp.mesh = bm
		lamp.material_override = panel_mat
		lamp.position = Vector3(0.0, TUNNEL_H - 0.03, z)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stand.add_child(lamp)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.93, 0.82)
		light.light_energy = 2.6 if i == 0 else 2.0
		light.omni_range = TUNNEL_H * 3.0
		light.omni_attenuation = 1.2
		light.shadow_enabled = false
		light.position = Vector3(0.0, TUNNEL_H - 0.35, z)
		stand.add_child(light)
	var fr := SurfaceTool.new()
	fr.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(fr, Vector3(-h - 0.6, 0.0, -0.3), Vector3(-h, TUNNEL_H + 0.6, 0.3))
	_box(fr, Vector3(h, 0.0, -0.3), Vector3(h + 0.6, TUNNEL_H + 0.6, 0.3))
	_box(fr, Vector3(-h - 0.6, TUNNEL_H, -0.3), Vector3(h + 0.6, TUNNEL_H + 0.6, 0.3))
	fr.generate_normals()
	var frame := MeshInstance3D.new()
	frame.name = "TunnelFrame"
	frame.mesh = fr.commit()
	frame.material_override = _concrete_mat()
	stand.add_child(frame)


## Pista de atletismo (rojiza, con andariveles) entre la cancha y el muro.
static func _track(root: Node3D, style: Dictionary) -> void:
	var wall: float = style["wall"]
	var hl := Pitch.HALF_LENGTH + wall
	var hw := Pitch.HALF_WIDTH + wall
	var track := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(hl * 2.0, hw * 2.0)
	track.mesh = plane
	track.material_override = _mat(Color(0.5, 0.2, 0.14), 0.95)
	track.position.y = -0.012
	root.add_child(track)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lane in 6:
		var d := 6.0 + lane * 1.1
		var lx := Pitch.HALF_LENGTH + d
		var lz := Pitch.HALF_WIDTH + d
		if d > wall - 0.3:
			break
		_box(st, Vector3(-lx, -0.008, -lz - 0.03), Vector3(lx, -0.004, -lz + 0.03))
		_box(st, Vector3(-lx, -0.008, lz - 0.03), Vector3(lx, -0.004, lz + 0.03))
		_box(st, Vector3(-lx - 0.03, -0.008, -lz), Vector3(-lx + 0.03, -0.004, lz))
		_box(st, Vector3(lx - 0.03, -0.008, -lz), Vector3(lx + 0.03, -0.004, lz))
	st.generate_normals()
	var lines := MeshInstance3D.new()
	lines.mesh = st.commit()
	lines.material_override = _mat(Color(0.9, 0.88, 0.85), 0.9)
	root.add_child(lines)


## Torres cilíndricas por fuera: cuatro grandes en las esquinas (sostienen el
## techo) y ocho con rampas en espiral a lo largo de las tribunas.
static func _towers(root: Node3D, style: Dictionary, main: Dictionary) -> void:
	var gap: float = style["gap"]
	var depth: float = main["depth"]
	var height: float = main["height"]
	var hl := Pitch.HALF_LENGTH
	var hw := Pitch.HALF_WIDTH
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spots: Array = []
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			spots.append([Vector3(sx * (hl + gap + depth * 0.62 + 5.0), 0, sz * (hw + gap + depth * 0.62 + 5.0)), 6.5, height + 10.0])
			spots.append([Vector3(sx * 32.0, 0, sz * (hw + gap + depth + 5.0)), 4.6, height * 0.92])
			spots.append([Vector3(sx * (hl + gap + depth + 5.0), 0, sz * 14.0), 4.6, height * 0.92])
	var core_mat := _concrete_mat()
	for spot in spots:
		var c: Vector3 = spot[0]
		var radius: float = spot[1]
		var h: float = spot[2]
		var core := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius - 1.6
		cyl.bottom_radius = radius - 1.6
		cyl.height = h
		cyl.radial_segments = 20
		core.mesh = cyl
		core.material_override = core_mat
		core.position = c + Vector3(0, h * 0.5, 0)
		root.add_child(core)
		# Rampa en espiral: tramos inclinados alrededor del núcleo.
		var per_turn := 20
		var turns := int(h / 4.5)
		var seg_len := TAU * (radius - 0.8) / per_turn * 1.08
		for i in per_turn * turns:
			var a := float(i) / per_turn * TAU
			var y := float(i) / per_turn * 4.5
			var p := c + Vector3(cos(a) * (radius - 0.8), y, sin(a) * (radius - 0.8))
			# El eje X del tramo, tangente a la circunferencia.
			var tf := Transform3D(Basis(Vector3.UP, -a - PI * 0.5), p)
			_obox(st, tf, Vector3(seg_len, 0.3, 1.6))
			# Baranda exterior de la rampa.
			_obox(st, Transform3D(tf.basis, c + Vector3(cos(a) * (radius - 0.05), y + 0.6, sin(a) * (radius - 0.05))), Vector3(seg_len, 1.2, 0.12))
	st.generate_normals()
	var ramps := MeshInstance3D.new()
	ramps.name = "Towers"
	ramps.mesh = st.commit()
	ramps.material_override = _mat(Color(0.62, 0.62, 0.64), 0.9)
	root.add_child(ramps)


## Caja orientada (centro y base de `tf`) agregada a un SurfaceTool.
static func _obox(st: SurfaceTool, tf: Transform3D, size: Vector3) -> void:
	var h := size * 0.5
	var v := []
	for k in 8:
		var p := Vector3(h.x if k & 1 else -h.x, h.y if k & 2 else -h.y, h.z if k & 4 else -h.z)
		v.append(tf * p)
	var faces := [[0, 1, 3, 2], [5, 4, 6, 7], [4, 0, 2, 6], [1, 5, 7, 3], [2, 3, 7, 6], [4, 5, 1, 0]]
	for f in faces:
		for i in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(v[f[i]])


## Butaca: asiento y respaldo (una sola malla, instanciada por MultiMesh).
## Ropa de un hincha (rgb) y tono de piel (a): la mayoría con los colores del
## local; en la cabecera visitante, con los del visitante.
static func _fan_color(rng: RandomNumberGenerator, fans: Dictionary, away_end: bool) -> Color:
	# Como en el WE: una masa con mucho blanco y gris claro, algo oscuro y los
	# colores de los equipos salpicados (más en las cabeceras).
	var r := rng.randf()
	var c: Color
	var team_share := 0.55 if away_end else 0.35
	if r < team_share:
		var home_c: Color = fans["home"] if rng.randf() < 0.75 else fans["home2"]
		c = fans["away"] if away_end else home_c
	elif not away_end and r < team_share + 0.05:
		c = fans["away"]
	else:
		var neutral := [Color(0.92, 0.92, 0.9), Color(0.85, 0.85, 0.86), Color(0.7, 0.7, 0.72),
			Color(0.15, 0.15, 0.17), Color(0.3, 0.32, 0.4), Color(0.55, 0.45, 0.35)]
		c = neutral[rng.randi() % neutral.size()]
	c = c.darkened(rng.randf_range(0.0, 0.2))
	return Color(c.r, c.g, c.b, rng.randf())


## Un hincha sentado, muy simple (se ve a 40-60 m): torso y cabeza. El color
## de vértice rojo marca la cabeza (lo usa crowd.gdshader).
static var _person: ArrayMesh
static func _person_mesh() -> Mesh:
	if _person != null:
		return _person
	# Persona sentada, de pocos polígonos (~90 triángulos), mirando a -Z (a la
	# cancha): piernas dobladas, torso con hombros más anchos que la cintura,
	# brazos al costado, cuello y cabeza redondeada con pelo.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cloth := Color(0, 0, 0)
	var skin := Color(1, 0, 0)
	var hair := Color(0, 1, 0)
	var pants := Color(0, 0, 1)
	# Muslos (hacia adelante) y piernas (hacia abajo).
	for sx: float in [-0.1, 0.1]:
		_cbox(st, Vector3(sx, 0.47, -0.12), Vector3(0.13, 0.12, 0.34), pants)
		_cbox(st, Vector3(sx, 0.25, -0.27), Vector3(0.11, 0.38, 0.11), pants)
	# Torso trapecial (cintura 0,3, hombros 0,42).
	_trapezoid(st, 0.55, 0.98, 0.3, 0.42, 0.2, cloth)
	# Brazos: manga y antebrazo, apenas separados del cuerpo.
	for sx: float in [-1.0, 1.0]:
		_cbox(st, Vector3(sx * 0.25, 0.85, 0.0), Vector3(0.1, 0.22, 0.12), cloth)
		_cbox(st, Vector3(sx * 0.26, 0.65, -0.05), Vector3(0.08, 0.22, 0.09), skin)
	# Cuello y cabeza (prisma octogonal con tapas: se lee redonda a distancia).
	_cbox(st, Vector3(0.0, 1.02, 0.0), Vector3(0.09, 0.08, 0.09), skin)
	_head(st, Vector3(0.0, 1.15, 0.0), 0.1, 0.22, skin, hair)
	st.generate_normals()
	_person = st.commit()
	return _person


## Caja centrada en `c` con color de vértice (zona) para el shader del público.
static func _cbox(st: SurfaceTool, c: Vector3, size: Vector3, col: Color) -> void:
	st.set_color(col)
	_box(st, c - size * 0.5, c + size * 0.5)


## Torso: caja más angosta abajo (y0) que arriba (y1).
static func _trapezoid(st: SurfaceTool, y0: float, y1: float, w0: float, w1: float, d: float, col: Color) -> void:
	st.set_color(col)
	var v := [
		Vector3(-w0 * 0.5, y0, -d * 0.5), Vector3(w0 * 0.5, y0, -d * 0.5), Vector3(w1 * 0.5, y1, -d * 0.5), Vector3(-w1 * 0.5, y1, -d * 0.5),
		Vector3(-w0 * 0.5, y0, d * 0.5), Vector3(w0 * 0.5, y0, d * 0.5), Vector3(w1 * 0.5, y1, d * 0.5), Vector3(-w1 * 0.5, y1, d * 0.5),
	]
	var faces := [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]
	for f in faces:
		st.add_vertex(v[f[0]])
		st.add_vertex(v[f[1]])
		st.add_vertex(v[f[2]])
		st.add_vertex(v[f[0]])
		st.add_vertex(v[f[2]])
		st.add_vertex(v[f[3]])


## Cabeza: prisma de 8 lados (cara de piel, parte de arriba y nuca de pelo).
static func _head(st: SurfaceTool, c: Vector3, r: float, h: float, skin: Color, hair: Color) -> void:
	var n := 8
	var y0 := c.y - h * 0.5
	var y1 := c.y + h * 0.5
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(c.x + cos(a0) * r, 0.0, c.z + sin(a0) * r)
		var p1 := Vector3(c.x + cos(a1) * r, 0.0, c.z + sin(a1) * r)
		# Nuca (z > 0: atrás, del lado contrario a la cancha) con pelo.
		var back := sin((a0 + a1) * 0.5) > 0.3
		st.set_color(hair if back else skin)
		st.add_vertex(Vector3(p0.x, y0, p0.z))
		st.add_vertex(Vector3(p0.x, y1, p0.z))
		st.add_vertex(Vector3(p1.x, y1, p1.z))
		st.add_vertex(Vector3(p0.x, y0, p0.z))
		st.add_vertex(Vector3(p1.x, y1, p1.z))
		st.add_vertex(Vector3(p1.x, y0, p1.z))
		# Tapa de arriba (pelo), un poco abombada.
		st.set_color(hair)
		st.add_vertex(Vector3(c.x, y1 + r * 0.45, c.z))
		st.add_vertex(Vector3(p1.x, y1, p1.z))
		st.add_vertex(Vector3(p0.x, y1, p0.z))


static func _seat_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := SEAT_PITCH * 0.4
	_box(st, Vector3(-w, 0.36, -0.2), Vector3(w, 0.44, 0.2))
	_box(st, Vector3(-w, 0.36, 0.16), Vector3(w, 0.82, 0.24))
	st.generate_normals()
	return st.commit()


## Bocas de salida: filas que ocupa el hueco, medio ancho (m) y cada cuántas
## butacas hay una (un pasillo sí y otro no).
const VOM_ROWS := 3
const VOM_HALF := 1.1
const VOM_EVERY := 48


## Fila de la boca de salida en una bandeja de `rows` filas (-1 = sin boca:
## las bandejas chicas salen por arriba).
static func vomitory_row(rows: int) -> int:
	return rows / 2 - 1 if rows >= 8 else -1


## X (local de la tribuna) de las bocas de salida en una fila.
static func vomitory_xs(seats_per_row: int, shift: int) -> Array[float]:
	var out: Array[float] = []
	var row_len := seats_per_row * SEAT_PITCH
	var k := 24
	while shift + k < seats_per_row - 2:
		out.append(-row_len * 0.5 + (shift + k + 0.5) * SEAT_PITCH)
		k += VOM_EVERY
	return out


## X de la primera boca (la misma grilla para todas las filas).
static func vomitory_x0(base_seats: int) -> float:
	return -base_seats * SEAT_PITCH * 0.5 + (24 + 0.5) * SEAT_PITCH


## Boca de salida: abertura oscura con marco de hormigón, del ancho del
## pasillo y de VOM_ROWS filas de alto.
static func _vomitory(dark: SurfaceTool, frame: SurfaceTool, x: float, y0: float, z0: float) -> void:
	var h := VOM_ROWS * ROW_RISE + 0.4
	var d := VOM_ROWS * ROW_DEPTH
	_box(dark, Vector3(x - VOM_HALF, y0 - 0.02, z0 + 0.05), Vector3(x + VOM_HALF, y0 + h, z0 + d))
	# Marco: dos paredes laterales y el dintel.
	_box(frame, Vector3(x - VOM_HALF - 0.15, y0, z0), Vector3(x - VOM_HALF, y0 + h, z0 + d))
	_box(frame, Vector3(x + VOM_HALF, y0, z0), Vector3(x + VOM_HALF + 0.15, y0 + h, z0 + d))
	_box(frame, Vector3(x - VOM_HALF - 0.15, y0 + h, z0), Vector3(x + VOM_HALF + 0.15, y0 + h + 0.15, z0 + d))


## Banderas colgadas de la baranda (dos franjas con los colores del club).
static func _banners(stand: Node3D, length: float, y: float, z: float, fans: Dictionary, away_end: bool,
		rng: RandomNumberGenerator, cut: float = 0.0) -> void:
	var x := -length * 0.5 + rng.randf_range(2.0, 8.0)
	while x < length * 0.5 - 4.0:
		var w := rng.randf_range(3.0, 6.5)
		var over_cut := cut > 0.0 and x < cut + 0.5 and x + w > -cut - 0.5
		if rng.randf() < 0.6 and not over_cut:
			var a: Color = fans["away"] if away_end else (fans["home"] if rng.randf() < 0.8 else fans["away"])
			var b: Color = Color(0.95, 0.95, 0.95) if rng.randf() < 0.6 else (fans["home2"] if not away_end else Color(0.1, 0.1, 0.12))
			for i in 2:
				var mi := MeshInstance3D.new()
				var q := QuadMesh.new()
				q.size = Vector2(w, 0.5)
				mi.mesh = q
				var m := _mat(a if i == 0 else b, 0.9)
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				# Tela (trama de tejido) en los trapos.
				var fabric := ModelVisual.fabric_texture()
				if fabric != null:
					m.normal_enabled = true
					m.normal_texture = fabric
					m.normal_scale = 0.8
					m.uv1_scale = Vector3(w * 1.5, 0.75, 1.0)
				mi.material_override = m
				mi.position = Vector3(x + w * 0.5, y + 0.75 - i * 0.5, z)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				stand.add_child(mi)
		x += w + rng.randf_range(1.5, 7.0)


## Baranda metálica (pasamanos y parantes) al frente de una bandeja.
## `cut` > 0 deja libre el centro (|x| < cut): la boca del túnel.
static func _railing(stand: Node3D, length: float, y: float, z: float, cut: float = 0.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spans := [[-length * 0.5, length * 0.5]] if cut <= 0.0 else [[-length * 0.5, -cut], [cut, length * 0.5]]
	for sp in spans:
		_box(st, Vector3(sp[0], y + 0.95, z - 0.03), Vector3(sp[1], y + 1.0, z + 0.03))
		_box(st, Vector3(sp[0], y + 0.5, z - 0.02), Vector3(sp[1], y + 0.53, z + 0.02))
	var posts := int(length / 2.5)
	for i in posts + 1:
		var x := -length * 0.5 + i * (length / posts)
		if absf(x) < cut:
			continue
		_box(st, Vector3(x - 0.025, y, z - 0.025), Vector3(x + 0.025, y + 1.0, z + 0.025))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(Color(0.55, 0.56, 0.6), 0.3)
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	stand.add_child(mi)


## De noche el estadio no proyecta sombra (con los reflectores, el techo y
## las tribunas dejarían manchas raras en la cancha): sólo los jugadores. Lo
## que no proyecta sombra en la tribuna oculta directamente no se dibuja.
static func disable_shadows(root: Node) -> void:
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		g.set_meta("base_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## La tribuna `stand_name` (entre la cámara y la cancha) pasa a proyectar sólo
## sombra: no tapa la vista pero la cancha conserva su sombra. Las demás se ven.
static func set_camera_side(root: Node3D, stand_name: String) -> void:
	for stand in root.get_children():
		if not stand.name.begins_with("Stand"):
			continue
		var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if stand_name != "" and String(stand.name).begins_with(stand_name):
			mode = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		for child in stand.get_children():
			if not child is GeometryInstance3D:
				continue
			var g := child as GeometryInstance3D
			# Lo que no proyecta sombra (público, butacas, cerchas) sigue sin
			# proyectarla; en la tribuna oculta directamente no se dibuja.
			if not g.has_meta("base_shadow"):
				g.set_meta("base_shadow", g.cast_shadow)
			var casts: bool = g.get_meta("base_shadow") != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if casts:
				g.cast_shadow = mode
				g.visible = true
			else:
				g.visible = mode == GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Caja alineada a los ejes agregada a un SurfaceTool.
static func _box(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var v := [
		Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z),
		Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z),
	]
	var faces := [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]
	for f in faces:
		for i in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(v[f[i]])


## Muro oscuro alrededor de la cancha y carteles lisos (sin marcas).
static func _perimeter(root: Node3D, style: Dictionary) -> void:
	var wall_mat := _mat(Color(0.17, 0.2, 0.27))
	var wall: float = style["wall"]
	var hl := Pitch.HALF_LENGTH + wall
	var hw := Pitch.HALF_WIDTH + wall
	# Del lado del túnel el muro se abre para que pasen los equipos.
	var open := TUNNEL_HALF + 0.8
	var half := (hl - open) * 0.5
	var sides := [
		[Vector3(0, 0.6, -hw), Vector3(hl * 2.0, 1.2, 0.3)],
		[Vector3(-open - half, 0.6, hw), Vector3(half * 2.0, 1.2, 0.3)],
		[Vector3(open + half, 0.6, hw), Vector3(half * 2.0, 1.2, 0.3)],
		[Vector3(-hl, 0.6, 0), Vector3(0.3, 1.2, hw * 2.0)],
		[Vector3(hl, 0.6, 0), Vector3(0.3, 1.2, hw * 2.0)],
	]
	for s in sides:
		var w := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = s[1]
		w.mesh = box
		w.material_override = wall_mat
		w.position = s[0]
		root.add_child(w)
	# Carteles LED negros con el nombre del juego en blanco (como la
	# referencia) en el lateral de enfrente y detrás de los arcos.
	var board_mat := _mat(Color(0.03, 0.03, 0.035), 0.35)
	var runs := [
		# [inicio, fin, eje del recorrido, posición fija, rotación Y]
		[-Pitch.HALF_LENGTH + 2.0, Pitch.HALF_LENGTH - 2.0, "x", -Pitch.HALF_WIDTH - 3.2, 0.0],
		[-Pitch.HALF_WIDTH + 4.0, Pitch.HALF_WIDTH - 4.0, "z", -Pitch.HALF_LENGTH - 3.2, PI * 0.5],
		[-Pitch.HALF_WIDTH + 4.0, Pitch.HALF_WIDTH - 4.0, "z", Pitch.HALF_LENGTH + 3.2, -PI * 0.5],
	]
	for run in runs:
		var length: float = run[1] - run[0]
		var count := maxi(1, int(length / 12.0))
		var seg := length / count
		for k in count:
			var c: float = run[0] + seg * (k + 0.5)
			var holder := Node3D.new()
			holder.position = Vector3(c, 0.0, run[3]) if run[2] == "x" else Vector3(run[3], 0.0, c)
			holder.rotation.y = run[4]
			root.add_child(holder)
			var board := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(seg - 0.2, 0.95, 0.15)
			board.mesh = bb
			board.material_override = board_mat
			board.position.y = 0.55
			holder.add_child(board)
			var text := Label3D.new()
			text.text = "MASTER ELEVEN."
			text.font_size = 96
			text.pixel_size = 0.0062
			text.outline_size = 0
			text.modulate = Color(0.97, 0.97, 0.97)
			text.shaded = false
			text.double_sided = false
			text.position = Vector3(0.0, 0.55, 0.08)
			holder.add_child(text)
	# Pista alrededor de la cancha (tono apagado).
	var track := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(hl * 2.0 + 30.0, hw * 2.0 + 30.0)
	track.mesh = plane
	track.material_override = _mat(Color(0.14, 0.24, 0.12))
	track.position.y = -0.02
	root.add_child(track)


## Bancos de suplentes y marcas del área técnica (lado de la cámara). El túnel
## lo arma la tribuna sur (_tunnel).
static func _technical_area(parent: Node3D, style: Dictionary) -> void:
	# Van en su propio nodo "StandSouthTech": del lado de la cámara de TV, así
	# que se ocultan junto con la tribuna sur (sólo proyectan sombra).
	var root := Node3D.new()
	root.name = "StandSouthTech"
	parent.add_child(root)
	var line := _mat(Color(0.95, 0.95, 0.95))
	for side in [-1, 1]:
		var cx: float = side * 9.0
		var z0 := Pitch.HALF_WIDTH + 1.0
		# Rectángulo punteado del área técnica.
		for seg in [[Vector3(cx - 6, 0.012, z0), Vector3(12, 0.01, 0.12)],
				[Vector3(cx - 6, 0.012, z0 + 1.5), Vector3(0.12, 0.01, 3.0)],
				[Vector3(cx + 6, 0.012, z0 + 1.5), Vector3(0.12, 0.01, 3.0)]]:
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = seg[1]
			m.mesh = b
			m.material_override = line
			m.position = seg[0] + Vector3(seg[1].x * 0.5 if seg[1].x > 1.0 else 0.0, 0, 0)
			# Las líneas están en el césped: siempre visibles.
			parent.add_child(m)
		# Banco de suplentes: abierto hacia la cancha, con pared de fondo,
		# laterales, techo traslúcido y una fila de asientos.
		# Contra el muro (o, si el estadio lo indica, embutido más atrás: en
		# el Coloso del Sur quedaba delante del túnel y tapaba la toma).
		var bz := Pitch.HALF_WIDTH + float(style.get("bench", style["wall"])) - 1.2
		var shell := _mat(Color(0.36, 0.4, 0.48), 0.7)
		var parts := [
			[Vector3(cx, 1.1, bz + 0.72), Vector3(9.0, 2.2, 0.16), shell],
			[Vector3(cx - 4.44, 1.1, bz), Vector3(0.12, 2.2, 1.6), shell],
			[Vector3(cx + 4.44, 1.1, bz), Vector3(0.12, 2.2, 1.6), shell],
			[Vector3(cx, 0.24, bz + 0.38), Vector3(8.6, 0.46, 0.5), _mat(Color(0.55, 0.12, 0.12), 0.5)],
			[Vector3(cx, 0.02, bz), Vector3(8.8, 0.04, 1.6), _mat(Color(0.3, 0.3, 0.32), 0.9)],
		]
		var roof_mat := _mat(Color(0.78, 0.84, 0.9), 0.2)
		roof_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		roof_mat.albedo_color.a = 0.55
		parts.append([Vector3(cx, 2.25, bz - 0.05), Vector3(9.2, 0.08, 1.9), roof_mat])
		for part in parts:
			var piece := MeshInstance3D.new()
			var pb := BoxMesh.new()
			pb.size = part[1]
			piece.mesh = pb
			piece.material_override = part[2]
			piece.position = part[0]
			root.add_child(piece)


## Tipografía de 5x7 "píxeles" para escribir con butacas (cada píxel = 2x2 butacas).
class PixelFont:
	const GLYPHS := {
		"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
		"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
		"C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
		"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
		"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
		"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
		"G": ["01111", "10000", "10000", "10111", "10001", "10001", "01111"],
		"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
		"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
		"J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
		"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
		"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
		"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
		"N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
		"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
		"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
		"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
		"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
		"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
		"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
		"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
		"V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
		"W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
		"X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
		"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
		"Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
		" ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
	}
	const SCALE := 2

	## Devuelve {Vector2i(butaca, fila_desde_arriba): true} para el texto centrado.
	static func layout(text: String, seats: int, rows: int) -> Dictionary:
		var out := {}
		var up := text.to_upper().replace("Á", "A").replace("É", "E").replace("Í", "I").replace("Ó", "O").replace("Ú", "U").replace("Ñ", "N")
		var clean := ""
		for ch in up:
			if GLYPHS.has(ch):
				clean += ch
		if clean.is_empty() or rows < 7 * SCALE + 2:
			return out
		var width := clean.length() * 6 * SCALE
		var x0 := (seats - width) / 2
		var y0 := (rows - 7 * SCALE) / 2
		for i in clean.length():
			var glyph: Array = GLYPHS[clean[i]]
			for gy in 7:
				var row: String = glyph[gy]
				for gx in 5:
					if row[gx] == "1":
						for sy in SCALE:
							for sx in SCALE:
								out[Vector2i(x0 + (i * 6 + gx) * SCALE + sx, y0 + gy * SCALE + sy)] = true
		return out
