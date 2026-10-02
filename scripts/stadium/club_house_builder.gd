class_name ClubHouseBuilder
extends RefCounted
## Cancha de entrenamiento ("Club House", como la del WE): sin tribunas ni
## público ni carteles. Pasto alrededor, un alambrado bajo, una hilera de
## árboles, el edificio del club con los vestuarios de fondo, bancos y unos
## pocos reflectores en mástiles. Liviano a propósito: la atención va a los
## jugadores y a la pelota.

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


static func build(home: TeamData = null) -> Node3D:
	var root := Node3D.new()
	root.name = "Stadium"
	_ground(root)
	_fence(root)
	_trees(root)
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
	plane.size = Vector2(Pitch.HALF_LENGTH * 2.0 + 120.0, Pitch.HALF_WIDTH * 2.0 + 120.0)
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


## Árboles alrededor (copas redondeadas y algunos pinos), salvo del lado de la
## cámara, donde quedan más lejos y bajos para no tapar.
static func _trees(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2002
	var round_tf: Array[Transform3D] = []
	var pine_tf: Array[Transform3D] = []
	var trunk_tf: Array[Transform3D] = []
	var hl := Pitch.HALF_LENGTH + TREES
	var hw := Pitch.HALF_WIDTH + TREES
	var spots: Array[Vector3] = []
	var x := -hl
	while x <= hl:
		spots.append(Vector3(x + rng.randf_range(-2, 2), 0, -hw - rng.randf_range(0, 6)))
		spots.append(Vector3(x + rng.randf_range(-2, 2), 0, hw + 14.0 + rng.randf_range(0, 6)))
		x += rng.randf_range(6.0, 9.0)
	var z := -hw
	while z <= hw:
		spots.append(Vector3(-hl - rng.randf_range(0, 6), 0, z + rng.randf_range(-2, 2)))
		spots.append(Vector3(hl + rng.randf_range(0, 6), 0, z + rng.randf_range(-2, 2)))
		z += rng.randf_range(6.0, 9.0)
	for p in spots:
		# Detrás del edificio no van árboles adelante.
		if absf(p.x) < 22.0 and p.z < -Pitch.HALF_WIDTH:
			p.z -= BUILDING_Z * 0.6
		var h := rng.randf_range(7.0, 12.0)
		var pine := rng.randf() < 0.3
		trunk_tf.append(Transform3D(Basis.from_scale(Vector3(1, h * 0.45, 1)), p + Vector3(0, h * 0.225, 0)))
		if pine:
			pine_tf.append(Transform3D(Basis.from_scale(Vector3(1, h * 0.85, 1) * Vector3(rng.randf_range(2.2, 3.0), 1, rng.randf_range(2.2, 3.0))), p + Vector3(0, h * 0.62, 0)))
		else:
			var r := rng.randf_range(2.6, 4.0)
			round_tf.append(Transform3D(Basis.from_scale(Vector3(r, r * 0.9, r)), p + Vector3(0, h * 0.62, 0)))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.28
	trunk.height = 1.0
	_multi(root, trunk, trunk_tf, _mat(Color(0.3, 0.22, 0.14)))
	var crown := SphereMesh.new()
	crown.radius = 1.0
	crown.height = 2.0
	crown.radial_segments = 10
	crown.rings = 6
	_multi(root, crown, round_tf, _mat(Color(0.16, 0.3, 0.12)))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 8
	_multi(root, cone, pine_tf, _mat(Color(0.1, 0.22, 0.12)))


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
