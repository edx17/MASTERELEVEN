class_name ClubHouseBuilder
extends RefCounted
## Predio de entrenamiento del club ("Club House"): la cancha principal con
## un alambrado bajo, una mini tribuna con techo, el edificio de los
## vestuarios, canchas paralelas sin usar a los costados, el vallado alto del
## predio con el nombre y el escudo del club (o MASTER ELEVEN) y árboles
## frondosos alrededor, con una línea de bosque de fondo. Sin público.

## Estilo para las luces de la noche (Atmosphere lee los reflectores de acá).
const STYLE := {
	"name": "Club House",
	"gap": 6.0, "wall": 6.0,
	"stands": {"North": [], "West": [], "East": [], "South": []},
	"corners": [],
	"tier_step": [0.0, 0.0],
	"roof": {},
	"seat": null, "tier_colors": [],
	"club_text": false, "track": false, "towers": false,
	"flood": [6.0, 10.0, 22.0, true],
}
## Cuánto pasto hay alrededor de la cancha y dónde van el alambrado y los
## árboles (m desde las líneas).
const FENCE := 7.0
const TREES := 11.0
const BUILDING_Z := 30.0
## Canchas paralelas: centro en x = +-SIDE_PITCH_X.
const SIDE_PITCH_X := 125.0
## Vallado alto del predio (m desde el centro) y su altura.
const WALL_X := 185.0
const WALL_Z_FAR := 82.0
const WALL_Z_NEAR := 62.0
const WALL_H := 4.0
## Mini tribuna (lado lejano, frente a la cámara).
const STAND_Z := Pitch.HALF_WIDTH + FENCE + 2.5


static func build(home: TeamData = null) -> Node3D:
	var root := Node3D.new()
	root.name = "Stadium"
	_ground(root)
	_fence(root)
	for sx: int in [-1, 1]:
		_side_pitch(root, sx)
	_mini_stand(root)
	_club_wall(root, home)
	_trees(root)
	_horizon(root)
	_building(root, home)
	_benches(root)
	_masts(root)
	return root


static func _mat(c: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## Pasto alrededor (más apagado que la cancha) y un camino de tierra hasta el
## edificio.
static func _ground(root: Node3D) -> void:
	var g := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(WALL_X * 2.0 + 160.0, WALL_Z_FAR + WALL_Z_NEAR + 160.0)
	g.mesh = plane
	g.material_override = _mat(Color(0.2, 0.33, 0.15))
	g.position.y = -0.02
	root.add_child(g)
	var path := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4.0, BUILDING_Z - Pitch.HALF_WIDTH)
	path.mesh = pm
	path.material_override = _mat(Color(0.45, 0.38, 0.28))
	path.position = Vector3(0.0, -0.01, -(Pitch.HALF_WIDTH + BUILDING_Z) * 0.5)
	root.add_child(path)


## Alambrado bajo: postes y una malla semitransparente (no tapa la cámara).
static func _fence(root: Node3D) -> void:
	var hl := Pitch.HALF_LENGTH + FENCE
	var hw := Pitch.HALF_WIDTH + FENCE
	var post_mat := _mat(Color(0.55, 0.57, 0.6), 0.5)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.6, 0.65, 0.7, 0.18)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector3(-hl, 0, -hw), Vector3(hl, 0, -hw), Vector3(hl, 0, hw), Vector3(-hl, 0, hw)]
	var posts := MultiMesh.new()
	posts.transform_format = MultiMesh.TRANSFORM_3D
	var post_list: Array[Vector3] = []
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var n := int(a.distance_to(b) / 4.0)
		for k in n:
			post_list.append(a.lerp(b, float(k) / n))
		# Malla de 1,5 m.
		var h := Vector3(0, 1.5, 0)
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(b + h)
		st.add_vertex(a)
		st.add_vertex(b + h)
		st.add_vertex(a + h)
	var net := MeshInstance3D.new()
	net.mesh = st.commit()
	net.material_override = mesh_mat
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(net)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.04
	cyl.height = 1.6
	posts.mesh = cyl
	posts.instance_count = post_list.size()
	for i in post_list.size():
		posts.set_instance_transform(i, Transform3D(Basis(), post_list[i] + Vector3(0, 0.8, 0)))
	var pmi := MultiMeshInstance3D.new()
	pmi.multimesh = posts
	pmi.material_override = post_mat
	root.add_child(pmi)


## Árboles frondosos: copas armadas con varias esferas (racimos) en tres
## verdes, en doble hilera por fuera del vallado y en grupos entre las
## canchas; del lado de la cámara quedan lejos para no tapar.
static func _trees(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2002
	var spots: Array[Vector3] = []
	# Doble hilera por fuera del vallado (fondo y costados).
	for row in 2:
		var off := 6.0 + row * 9.0
		var x := -WALL_X - off
		while x <= WALL_X + off:
			spots.append(Vector3(x + rng.randf_range(-2.5, 2.5), 0, -WALL_Z_FAR - off - rng.randf_range(0, 4)))
			spots.append(Vector3(x + rng.randf_range(-2.5, 2.5), 0, WALL_Z_NEAR + off + 10.0 + rng.randf_range(0, 4)))
			x += rng.randf_range(7.0, 10.0)
		var z := -WALL_Z_FAR
		while z <= WALL_Z_NEAR:
			spots.append(Vector3(-WALL_X - off - rng.randf_range(0, 4), 0, z + rng.randf_range(-2.5, 2.5)))
			spots.append(Vector3(WALL_X + off + rng.randf_range(0, 4), 0, z + rng.randf_range(-2.5, 2.5)))
			z += rng.randf_range(7.0, 10.0)
	# Grupos entre la cancha principal y las paralelas (lejos de la cámara).
	for sx: int in [-1, 1]:
		for k in 5:
			spots.append(Vector3(sx * rng.randf_range(70.0, 80.0), 0, rng.randf_range(-WALL_Z_FAR + 8.0, -Pitch.HALF_WIDTH - 4.0)))
	var trunk_tf: Array[Transform3D] = []
	var crowns: Array = [[], [], []]
	for p in spots:
		var h := rng.randf_range(8.0, 14.0)
		var r := rng.randf_range(3.0, 4.6)
		trunk_tf.append(Transform3D(Basis.from_scale(Vector3(1.2, h * 0.5, 1.2)), p + Vector3(0, h * 0.25, 0)))
		# Copa en racimo: una grande al centro y 3 a 5 alrededor, más arriba
		# y más abajo (se lee como follaje, no como una pelota).
		var top := p + Vector3(0, h * 0.62, 0)
		var shade := rng.randi() % 3
		(crowns[shade] as Array).append(Transform3D(Basis.from_scale(Vector3(r, r * 0.85, r)), top))
		for k in rng.randi_range(3, 5):
			var a := rng.randf() * TAU
			var rr := r * rng.randf_range(0.55, 0.8)
			var off := Vector3(cos(a), rng.randf_range(-0.3, 0.45), sin(a)) * r * 0.75
			(crowns[(shade + k) % 3] as Array).append(Transform3D(Basis.from_scale(Vector3(rr, rr * 0.9, rr)), top + off))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.2
	trunk.bottom_radius = 0.34
	trunk.height = 1.0
	trunk.radial_segments = 6
	_multi(root, trunk, trunk_tf, _mat(Color(0.3, 0.22, 0.14)))
	var crown := SphereMesh.new()
	crown.radius = 1.0
	crown.height = 2.0
	crown.radial_segments = 9
	crown.rings = 5
	var greens := [Color(0.15, 0.29, 0.11), Color(0.2, 0.34, 0.13), Color(0.12, 0.25, 0.12)]
	for i in 3:
		var tfs: Array[Transform3D] = []
		tfs.assign(crowns[i])
		_multi(root, crown, tfs, _mat(greens[i], 0.95))


## Fondo: una franja continua de bosque lejano todo alrededor (copas en
## lomas suaves), para que el horizonte no quede vacío.
static func _horizon(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 96
	var radius := 290.0
	var prev_h := 18.0
	var heights: Array[float] = []
	for i in n:
		prev_h = clampf(prev_h + rng.randf_range(-4.0, 4.0), 12.0, 30.0)
		heights.append(prev_h)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0) * radius, 0, sin(a0) * radius * 0.75)
		var p1 := Vector3(cos(a1) * radius, 0, sin(a1) * radius * 0.75)
		var h0: float = heights[i]
		var h1: float = heights[(i + 1) % n]
		for v: Vector3 in [p0, p1, p1 + Vector3.UP * h1, p0, p1 + Vector3.UP * h1, p0 + Vector3.UP * h0]:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Horizon"
	mi.mesh = st.commit()
	var m := _mat(Color(0.13, 0.22, 0.13), 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Cancha paralela sin usar: pasto cortado a franjas, líneas y arcos sin red.
static func _side_pitch(root: Node3D, sx: int) -> void:
	var c := Vector3(sx * SIDE_PITCH_X, 0.0, -6.0)
	var node := Node3D.new()
	node.name = "SidePitch_%s" % ("R" if sx > 0 else "L")
	node.position = c
	root.add_child(node)
	var hl := 48.0
	var hw := 31.0
	var light := _mat(Color(0.25, 0.42, 0.18))
	var dark := _mat(Color(0.22, 0.37, 0.16))
	var stripes := 12
	for i in stripes:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(hl * 2.0 / stripes, hw * 2.0)
		mi.mesh = pm
		mi.material_override = light if i % 2 == 0 else dark
		mi.position = Vector3(-hl + (i + 0.5) * hl * 2.0 / stripes, -0.005, 0.0)
		node.add_child(mi)
	# Todas las marcas (área chica, punto penal, medialuna, córners...).
	var lines := PitchBuilder.lines_mesh(hl, hw)
	lines.position.y = 0.005
	node.add_child(lines)
	var white := _mat(Color(0.92, 0.92, 0.9), 0.6)
	# Arcos sin red.
	for side: int in [-1, 1]:
		for z: float in [-3.66, 3.66]:
			_add_box(node, Vector3(side * hl, 1.22, z), Vector3(0.12, 2.44, 0.12), white)
		_add_box(node, Vector3(side * hl, 2.44, 0), Vector3(0.12, 0.12, 7.44), white)


## Mini tribuna frente a la cámara: seis escalones de cemento con butacas
## grises y un techo liviano sobre columnas.
static func _mini_stand(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "MiniStand"
	node.position = Vector3(0.0, 0.0, -STAND_Z)
	root.add_child(node)
	var concrete := _mat(Color(0.62, 0.62, 0.6))
	var seat := _mat(Color(0.55, 0.57, 0.6), 0.6)
	var steel := _mat(Color(0.32, 0.34, 0.38), 0.5)
	var width := 34.0
	var rows := 6
	var seat_tf: Array[Transform3D] = []
	for r in rows:
		var y := 0.45 * (r + 1)
		var z := -0.85 * r
		_add_box(node, Vector3(0, y * 0.5, z), Vector3(width, y, 0.85), concrete)
		var x := -width * 0.5 + 0.5
		while x < width * 0.5 - 0.4:
			seat_tf.append(Transform3D(Basis(), node.position + Vector3(x, y + 0.2, z - 0.1)))
			x += 0.55
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.44, 0.38, 0.42)
	_multi(root, seat_mesh, seat_tf, seat)
	# Techo inclinado sobre seis columnas.
	var back := -0.85 * (rows - 1) - 0.4
	for i in 6:
		var cx := -width * 0.5 + 1.0 + i * (width - 2.0) / 5.0
		_add_box(node, Vector3(cx, 2.6, back), Vector3(0.22, 5.2, 0.22), steel)
	var roof := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(width + 1.0, 0.12, 6.5)
	roof.mesh = rb
	roof.material_override = steel
	roof.position = Vector3(0, 5.3, back + 2.6)
	roof.rotation.x = -0.12
	node.add_child(roof)


## Vallado alto del predio: postes y paños de lona con los colores del club;
## sobre el fondo, el nombre del club (o MASTER ELEVEN) repetido y el escudo.
static func _club_wall(root: Node3D, home: TeamData) -> void:
	var main := home.color if home != null else Color(0.12, 0.16, 0.42)
	var second := home.secondary_color if home != null else Color(0.95, 0.85, 0.3)
	var text := home.team_name.to_upper() if home != null else "MASTER ELEVEN"
	var cloth := _mat(main.darkened(0.15), 0.95)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var band := _mat(second, 0.9)
	band.cull_mode = BaseMaterial3D.CULL_DISABLED
	var post := _mat(Color(0.4, 0.42, 0.45), 0.5)
	var node := Node3D.new()
	node.name = "ClubWall"
	root.add_child(node)
	var corners := [Vector3(-WALL_X, 0, -WALL_Z_FAR), Vector3(WALL_X, 0, -WALL_Z_FAR),
		Vector3(WALL_X, 0, WALL_Z_NEAR), Vector3(-WALL_X, 0, WALL_Z_NEAR)]
	var post_tf: Array[Transform3D] = []
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var mid := (a + b) * 0.5
		var length := a.distance_to(b)
		var along := (b - a).normalized()
		var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP))
		var panel := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(length, WALL_H, 0.08)
		panel.mesh = bm
		panel.material_override = cloth
		panel.transform = Transform3D(basis, mid + Vector3(0, WALL_H * 0.5, 0))
		node.add_child(panel)
		var stripe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(length, 0.35, 0.1)
		stripe.mesh = sm
		stripe.material_override = band
		stripe.transform = Transform3D(basis, mid + Vector3(0, WALL_H - 0.3, 0))
		node.add_child(stripe)
		var n := int(length / 5.0)
		for k in n + 1:
			post_tf.append(Transform3D(Basis.from_scale(Vector3(1, WALL_H + 0.3, 1)), a.lerp(b, float(k) / n) + Vector3(0, (WALL_H + 0.3) * 0.5, 0)))
	var pm := CylinderMesh.new()
	pm.top_radius = 0.07
	pm.bottom_radius = 0.07
	pm.height = 1.0
	pm.radial_segments = 6
	_multi(node, pm, post_tf, post)
	# Nombre y escudo sobre el paño del fondo (el que mira la cámara).
	var x := -WALL_X + 24.0
	var i := 0
	while x < WALL_X - 10.0:
		if i % 3 == 1:
			_crest(node, Vector3(x, WALL_H * 0.48, -WALL_Z_FAR + 0.1), main, second)
		else:
			var l := Label3D.new()
			l.text = text
			l.font_size = 150
			l.pixel_size = 0.014
			l.modulate = second
			l.outline_size = 0
			l.shaded = true
			l.position = Vector3(x, WALL_H * 0.45, -WALL_Z_FAR + 0.1)
			node.add_child(l)
		x += 30.0
		i += 1


## Escudo simple (dos colores) para el vallado.
static func _crest(parent: Node3D, pos: Vector3, main: Color, second: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector2] = [Vector2(-1.1, 1.3), Vector2(1.1, 1.3), Vector2(1.1, 0.0), Vector2(0.0, -1.5), Vector2(-1.1, 0.0)]
	for k in range(1, pts.size() - 1):
		for v: Vector2 in [pts[0], pts[k + 1], pts[k]]:
			st.add_vertex(Vector3(v.x, v.y, 0.0))
	st.generate_normals()
	var outer := MeshInstance3D.new()
	outer.mesh = st.commit()
	outer.material_override = _mat(second, 0.6)
	outer.position = pos
	parent.add_child(outer)
	var inner := MeshInstance3D.new()
	inner.mesh = outer.mesh
	inner.material_override = _mat(main, 0.6)
	inner.position = pos + Vector3(0, 0.02, 0.03)
	inner.scale = Vector3(0.78, 0.8, 1.0)
	parent.add_child(inner)


static func _multi(root: Node3D, mesh: Mesh, tfs: Array[Transform3D], mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = tfs.size()
	for i in tfs.size():
		mm.set_instance_transform(i, tfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	root.add_child(mi)


## Edificio del club (vestuarios): dos plantas, techo a dos aguas, ventanas,
## una galería y el cartel "CLUB HOUSE" con el escudo del local.
static func _building(root: Node3D, home: TeamData) -> void:
	var b := Node3D.new()
	b.name = "ClubHouse"
	b.position = Vector3(0.0, 0.0, -Pitch.HALF_WIDTH - BUILDING_Z)
	root.add_child(b)
	var wall := _mat(Color(0.86, 0.83, 0.76))
	var trim := _mat(Color(0.35, 0.3, 0.26))
	var roof := _mat(Color(0.48, 0.2, 0.16))
	var glass := _mat(Color(0.18, 0.26, 0.32), 0.15)
	_add_box(b, Vector3(0, 3.5, 0), Vector3(36, 7, 12), wall)
	_add_box(b, Vector3(0, 0.15, 7.5), Vector3(38, 0.3, 3.5), trim)
	# Techo a dos aguas.
	for s: int in [-1, 1]:
		var r := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(38, 0.3, 7.6)
		r.mesh = rb
		r.material_override = roof
		r.position = Vector3(0, 8.3, s * 3.2)
		r.rotation.x = s * 0.42
		b.add_child(r)
	# Ventanas (dos filas) y puerta.
	for row in 2:
		for i in 9:
			var wx := -16.0 + i * 4.0
			if row == 0 and absf(wx) < 1.0:
				continue
			_add_box(b, Vector3(wx, 2.0 + row * 3.3, 6.02), Vector3(2.2, 1.5, 0.05), glass)
	_add_box(b, Vector3(0, 1.3, 6.02), Vector3(2.4, 2.6, 0.06), trim)
	# Galería con columnas.
	for i in 7:
		_add_box(b, Vector3(-15.0 + i * 5.0, 1.6, 8.9), Vector3(0.3, 3.2, 0.3), trim)
	_add_box(b, Vector3(0, 3.3, 7.6), Vector3(32, 0.2, 3.2), trim)
	var sign := Label3D.new()
	sign.text = "CLUB HOUSE"
	sign.font_size = 160
	sign.pixel_size = 0.012
	sign.modulate = Color(0.12, 0.14, 0.2)
	sign.outline_size = 0
	sign.position = Vector3(0, 5.95, 6.05)
	b.add_child(sign)
	if home != null:
		var crest := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(1.6, 1.8, 0.1)
		crest.mesh = cm
		crest.material_override = _mat(home.color, 0.5)
		crest.position = Vector3(-8.5, 5.95, 6.05)
		b.add_child(crest)


static func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Bancos de madera junto al alambrado, del lado del edificio.
static func _benches(root: Node3D) -> void:
	var wood := _mat(Color(0.5, 0.36, 0.22))
	for x: float in [-14.0, 14.0]:
		var bench := Node3D.new()
		bench.position = Vector3(x, 0, -Pitch.HALF_WIDTH - FENCE + 2.0)
		root.add_child(bench)
		_add_box(bench, Vector3(0, 0.45, 0), Vector3(5.0, 0.08, 0.5), wood)
		_add_box(bench, Vector3(0, 0.75, -0.25), Vector3(5.0, 0.5, 0.06), wood)
		for sx: float in [-2.2, 2.2]:
			_add_box(bench, Vector3(sx, 0.22, 0), Vector3(0.08, 0.44, 0.45), wood)


## Cuatro mástiles con reflectores en las esquinas (los usa la noche).
static func _masts(root: Node3D) -> void:
	var f: Array = STYLE["flood"]
	var steel := _mat(Color(0.5, 0.52, 0.55), 0.5)
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			var p := Vector3(sx * (Pitch.HALF_LENGTH + float(f[0])), 0, sz * (Pitch.HALF_WIDTH + float(f[1])))
			var mast := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.18
			cyl.bottom_radius = 0.3
			cyl.height = float(f[2])
			mast.mesh = cyl
			mast.material_override = steel
			mast.position = p + Vector3(0, float(f[2]) * 0.5, 0)
			root.add_child(mast)
			_add_box(root, p + Vector3(0, float(f[2]) + 0.6, 0), Vector3(2.6, 1.4, 0.4), steel)
