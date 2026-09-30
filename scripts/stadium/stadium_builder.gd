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


## `home` define los colores de las butacas y el nombre en la tribuna.
static func build(home: TeamData) -> Node3D:
	var root := Node3D.new()
	root.name = "Stadium"
	var seat_color := home.color if home != null else Color(0.8, 0.15, 0.15)
	var text_color := home.secondary_color if home != null else Color.WHITE
	if text_color.get_luminance() < 0.25:
		text_color = Color(0.95, 0.95, 0.95)
	var name := home.team_name.to_upper() if home != null else "MASTER ELEVEN"

	# Tribuna principal (frente a la cámara): dos bandejas y el nombre del club.
	_stand(root, "North", Vector3(0, 0, -1), Pitch.HALF_LENGTH * 2.0 + 20.0, [26, 20], seat_color, text_color, name)
	# Cabeceras.
	_stand(root, "West", Vector3(-1, 0, 0), Pitch.HALF_WIDTH * 2.0 + 14.0, [22, 16], seat_color, text_color, "")
	_stand(root, "East", Vector3(1, 0, 0), Pitch.HALF_WIDTH * 2.0 + 14.0, [22, 16], seat_color, text_color, "")
	# Tribuna detrás de la cámara (casi no se ve; da sombra y cierre).
	_stand(root, "South", Vector3(0, 0, 1), Pitch.HALF_LENGTH * 2.0 + 20.0, [18], seat_color, text_color, "")
	_perimeter(root)
	_technical_area(root)
	return root


static func _mat(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## Una tribuna mirando hacia el centro. `outward` apunta desde la cancha hacia
## la tribuna. Cada elemento de `tiers` es la cantidad de filas de una bandeja.
static func _stand(root: Node3D, stand_name: String, outward: Vector3, length: float, tiers: Array,
		seat_color: Color, text_color: Color, text: String) -> void:
	var stand := Node3D.new()
	stand.name = "Stand" + stand_name
	root.add_child(stand)
	# Distancia desde el centro hasta la línea de este lado.
	var edge := Pitch.HALF_WIDTH if absf(outward.z) > 0.5 else Pitch.HALF_LENGTH
	# Base de la tribuna orientada: X local = a lo largo, Z local = hacia afuera.
	stand.basis = Basis.looking_at(-outward, Vector3.UP)
	stand.position = outward * (edge + STAND_GAP)

	var seats_per_row := int(length / SEAT_PITCH)
	var total_rows := 0
	for t in tiers:
		total_rows += int(t)
	var seat_mesh := _seat_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = seat_mesh
	mm.instance_count = seats_per_row * total_rows
	var steps := SurfaceTool.new()
	steps.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fascia := SurfaceTool.new()
	fascia.begin(Mesh.PRIMITIVE_TRIANGLES)

	var letters := PixelFont.layout(text, seats_per_row, tiers[0] if tiers.size() > 0 else 0)
	var idx := 0
	var row_global := 0
	var y := 0.0
	var z := 0.0
	for tier_i in tiers.size():
		var rows: int = tiers[tier_i]
		if tier_i > 0:
			# Pasillo y voladizo entre bandejas: frente oscuro de la bandeja
			# superior (como en los estadios modernos).
			z += 2.5
			y += 3.2
			_box(fascia, Vector3(-length * 0.5, y - ROW_RISE - 2.2, z - 0.4), Vector3(length * 0.5, y - ROW_RISE + 0.3, z))
		# Baranda al frente de cada bandeja.
		_railing(stand, length, y - ROW_RISE, z - 0.1)
		for r in rows:
			# Escalón de hormigón.
			_box(steps, Vector3(-length * 0.5, y - ROW_RISE, z), Vector3(length * 0.5, y, z + ROW_DEPTH))
			for s in seats_per_row:
				var x := -length * 0.5 + (s + 0.5) * SEAT_PITCH
				var c := seat_color
				# Escaleras cada 24 butacas.
				if s % 24 == 0:
					c = CONCRETE.lightened(0.2)
				# El eje X local de la tribuna mira al revés que la cámara: se invierte.
				elif tier_i == 0 and letters.has(Vector2i(seats_per_row - 1 - s, rows - 1 - r)):
					c = text_color
				mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY, Vector3(x, y, z + ROW_DEPTH * 0.5)))
				mm.set_instance_color(idx, c)
				idx += 1
			y += ROW_RISE
			z += ROW_DEPTH
			row_global += 1
	steps.generate_normals()
	var steps_mi := MeshInstance3D.new()
	steps_mi.mesh = steps.commit()
	steps_mi.material_override = _mat(CONCRETE)
	stand.add_child(steps_mi)

	if tiers.size() > 1:
		fascia.generate_normals()
		var fascia_mi := MeshInstance3D.new()
		fascia_mi.mesh = fascia.commit()
		fascia_mi.material_override = _mat(Color(0.07, 0.07, 0.08), 0.5)
		stand.add_child(fascia_mi)

	var seats := MultiMeshInstance3D.new()
	seats.multimesh = mm
	var seat_mat := _mat(Color.WHITE, 0.6)
	seat_mat.vertex_color_use_as_albedo = true
	seats.material_override = seat_mat
	stand.add_child(seats)

	# Pared trasera y techo con vigas (las vigas dejan franjas de sombra).
	var back := MeshInstance3D.new()
	var back_box := BoxMesh.new()
	back_box.size = Vector3(length, y + 6.0, 0.6)
	back.mesh = back_box
	back.material_override = _mat(Color(0.2, 0.2, 0.23))
	back.position = Vector3(0, (y + 6.0) * 0.5 - 1.0, z + 0.5)
	stand.add_child(back)
	var roof_y := y + 5.0
	var roof_depth := z + 8.0
	var beam_mat := _mat(Color(0.25, 0.25, 0.28))
	var beams := int(length / 9.0)
	for b in beams + 1:
		var beam := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.35, 0.6, roof_depth)
		beam.mesh = bb
		beam.material_override = beam_mat
		beam.position = Vector3(-length * 0.5 + b * (length / beams), roof_y, z + 0.5 - roof_depth * 0.5)
		stand.add_child(beam)
	var roof := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(length, 0.3, roof_depth * 0.55)
	roof.mesh = rb
	roof.material_override = _mat(Color(0.3, 0.3, 0.33))
	roof.position = Vector3(0, roof_y + 0.6, z + 0.5 - roof_depth * 0.275)
	stand.add_child(roof)


## Butaca: asiento y respaldo (una sola malla, instanciada por MultiMesh).
static func _seat_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := SEAT_PITCH * 0.4
	_box(st, Vector3(-w, 0.36, -0.2), Vector3(w, 0.44, 0.2))
	_box(st, Vector3(-w, 0.36, 0.16), Vector3(w, 0.82, 0.24))
	st.generate_normals()
	return st.commit()


## Baranda metálica (pasamanos y parantes) al frente de una bandeja.
static func _railing(stand: Node3D, length: float, y: float, z: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(-length * 0.5, y + 0.95, z - 0.03), Vector3(length * 0.5, y + 1.0, z + 0.03))
	_box(st, Vector3(-length * 0.5, y + 0.5, z - 0.02), Vector3(length * 0.5, y + 0.53, z + 0.02))
	var posts := int(length / 2.5)
	for i in posts + 1:
		var x := -length * 0.5 + i * (length / posts)
		_box(st, Vector3(x - 0.025, y, z - 0.025), Vector3(x + 0.025, y + 1.0, z + 0.025))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(Color(0.55, 0.56, 0.6), 0.3)
	stand.add_child(mi)


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
			if child is GeometryInstance3D:
				(child as GeometryInstance3D).cast_shadow = mode


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
static func _perimeter(root: Node3D) -> void:
	var wall_mat := _mat(Color(0.08, 0.08, 0.09))
	var hl := Pitch.HALF_LENGTH + WALL_GAP
	var hw := Pitch.HALF_WIDTH + WALL_GAP
	var sides := [
		[Vector3(0, 0.6, -hw), Vector3(hl * 2.0, 1.2, 0.3)],
		[Vector3(0, 0.6, hw), Vector3(hl * 2.0, 1.2, 0.3)],
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


## Bancos de suplentes, túnel y marcas del área técnica (lado de la cámara).
static func _technical_area(parent: Node3D) -> void:
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
		# Banco con techito.
		var bench := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(9.0, 2.2, 1.6)
		bench.mesh = bb
		bench.material_override = _mat(Color(0.15, 0.17, 0.2))
		bench.position = Vector3(cx, 1.1, Pitch.HALF_WIDTH + WALL_GAP - 1.2)
		root.add_child(bench)
	# Túnel.
	var tunnel := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(4.0, 2.8, 4.0)
	tunnel.mesh = tb
	tunnel.material_override = _mat(Color(0.1, 0.1, 0.12))
	tunnel.position = Vector3(0, 1.4, Pitch.HALF_WIDTH + WALL_GAP + 1.5)
	root.add_child(tunnel)


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
