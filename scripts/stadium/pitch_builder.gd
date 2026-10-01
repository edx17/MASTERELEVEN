class_name PitchBuilder
extends RefCounted
## Genera por código la cancha reglamentaria: césped (shader), líneas, áreas,
## círculo central, medialunas, arcos con postes y red y banderines. El
## estadio alrededor lo arma StadiumBuilder.

const LINE_Y := 0.012


## `grass`: parámetros del césped según el clima (wetness, snow).
static func build(grass: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	root.name = "Pitch"
	_build_grass(root, grass)
	_build_lines(root)
	for side: int in [-1, 1]:
		_build_goal(root, side)
	_build_corner_flags(root)
	return root


static func _flat_material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _build_grass(root: Node3D, params: Dictionary = {}) -> void:
	# Un solo plano con shader: franjas de corte + variación natural.
	var grass := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(Pitch.HALF_LENGTH * 2.0 + 10.0, Pitch.HALF_WIDTH * 2.0 + 10.0)
	grass.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/stadium/grass.gdshader")
	for k in params:
		mat.set_shader_parameter(k, params[k])
	GrassTextures.apply(mat)
	grass.material_override = mat
	root.add_child(grass)


static func _build_lines(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hl := Pitch.HALF_LENGTH
	var hw := Pitch.HALF_WIDTH
	# Perímetro y línea media.
	_seg(st, Vector2(-hl, -hw), Vector2(hl, -hw))
	_seg(st, Vector2(-hl, hw), Vector2(hl, hw))
	_seg(st, Vector2(-hl, -hw), Vector2(-hl, hw))
	_seg(st, Vector2(hl, -hw), Vector2(hl, hw))
	_seg(st, Vector2(0.0, -hw), Vector2(0.0, hw))
	_arc(st, Vector2.ZERO, Pitch.CENTER_CIRCLE_RADIUS, 0.0, TAU, 64)
	_arc(st, Vector2.ZERO, 0.2, 0.0, TAU, 12, 0.4)
	for side: int in [-1, 1]:
		var gx: float = side * hl
		# Área grande.
		var pa := gx - side * Pitch.PENALTY_AREA_DEPTH
		_seg(st, Vector2(gx, -Pitch.PENALTY_AREA_HALF_WIDTH), Vector2(pa, -Pitch.PENALTY_AREA_HALF_WIDTH))
		_seg(st, Vector2(gx, Pitch.PENALTY_AREA_HALF_WIDTH), Vector2(pa, Pitch.PENALTY_AREA_HALF_WIDTH))
		_seg(st, Vector2(pa, -Pitch.PENALTY_AREA_HALF_WIDTH), Vector2(pa, Pitch.PENALTY_AREA_HALF_WIDTH))
		# Área chica.
		var ga := gx - side * Pitch.GOAL_AREA_DEPTH
		_seg(st, Vector2(gx, -Pitch.GOAL_AREA_HALF_WIDTH), Vector2(ga, -Pitch.GOAL_AREA_HALF_WIDTH))
		_seg(st, Vector2(gx, Pitch.GOAL_AREA_HALF_WIDTH), Vector2(ga, Pitch.GOAL_AREA_HALF_WIDTH))
		_seg(st, Vector2(ga, -Pitch.GOAL_AREA_HALF_WIDTH), Vector2(ga, Pitch.GOAL_AREA_HALF_WIDTH))
		# Punto penal y medialuna (sólo la parte fuera del área).
		var spot := Vector2(gx - side * Pitch.PENALTY_SPOT_DISTANCE, 0.0)
		_arc(st, spot, 0.15, 0.0, TAU, 10, 0.3)
		var half_angle := acos((Pitch.PENALTY_AREA_DEPTH - Pitch.PENALTY_SPOT_DISTANCE) / Pitch.CENTER_CIRCLE_RADIUS)
		var facing := 0.0 if side == -1 else PI
		_arc(st, spot, Pitch.CENTER_CIRCLE_RADIUS, facing - half_angle, facing + half_angle, 24)
		# Arcos de córner.
		for zs: int in [-1, 1]:
			var corner := Vector2(gx, zs * hw)
			var start := atan2(-zs, -side)
			_arc(st, corner, 1.0, start - PI / 4.0, start + PI / 4.0, 8)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := _flat_material(Color(0.95, 0.95, 0.95))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Rectángulo fino sobre el pasto entre dos puntos (x, z).
static func _seg(st: SurfaceTool, a: Vector2, b: Vector2, width: float = Pitch.LINE_WIDTH) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * width * 0.5
	var p1 := Vector3(a.x + n.x, LINE_Y, a.y + n.y)
	var p2 := Vector3(b.x + n.x, LINE_Y, b.y + n.y)
	var p3 := Vector3(b.x - n.x, LINE_Y, b.y - n.y)
	var p4 := Vector3(a.x - n.x, LINE_Y, a.y - n.y)
	for v: Vector3 in [p1, p2, p3, p1, p3, p4]:
		st.add_vertex(v)


## Arco (o círculo) de radio r como tira de segmentos. `width` > r => disco.
static func _arc(st: SurfaceTool, c: Vector2, r: float, a0: float, a1: float, segments: int, width: float = Pitch.LINE_WIDTH) -> void:
	var inner := maxf(r - width * 0.5, 0.0)
	var outer := r + width * 0.5
	for i in segments:
		var t0 := lerpf(a0, a1, float(i) / segments)
		var t1 := lerpf(a0, a1, float(i + 1) / segments)
		var o0 := Vector3(c.x + cos(t0) * outer, LINE_Y, c.y + sin(t0) * outer)
		var o1 := Vector3(c.x + cos(t1) * outer, LINE_Y, c.y + sin(t1) * outer)
		var i0 := Vector3(c.x + cos(t0) * inner, LINE_Y, c.y + sin(t0) * inner)
		var i1 := Vector3(c.x + cos(t1) * inner, LINE_Y, c.y + sin(t1) * inner)
		for v: Vector3 in [o0, o1, i1, o0, i1, i0]:
			st.add_vertex(v)


static func _build_goal(root: Node3D, side: int) -> void:
	var goal := Node3D.new()
	goal.name = "Goal_%s" % ("R" if side > 0 else "L")
	root.add_child(goal)
	var gx := side * Pitch.HALF_LENGTH
	var white := _flat_material(Color(0.97, 0.97, 0.97))
	var pr := Pitch.POST_RADIUS
	# Postes.
	for zs: int in [-1, 1]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = pr
		cyl.bottom_radius = pr
		cyl.height = Pitch.GOAL_HEIGHT + pr
		post.mesh = cyl
		post.material_override = white
		post.position = Vector3(gx, (Pitch.GOAL_HEIGHT + pr) * 0.5, zs * Pitch.GOAL_HALF_WIDTH)
		goal.add_child(post)
	# Travesaño.
	var bar := MeshInstance3D.new()
	var bcyl := CylinderMesh.new()
	bcyl.top_radius = pr
	bcyl.bottom_radius = pr
	bcyl.height = Pitch.GOAL_HALF_WIDTH * 2.0 + pr * 2.0
	bar.mesh = bcyl
	bar.material_override = white
	bar.position = Vector3(gx, Pitch.GOAL_HEIGHT, 0.0)
	bar.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	goal.add_child(bar)
	# Red: grilla de líneas en fondo, costados y techo.
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var back := gx + side * Pitch.GOAL_DEPTH
	var h := Pitch.GOAL_HEIGHT
	var w := Pitch.GOAL_HALF_WIDTH
	var step := 0.2
	# Fondo.
	var z := -w
	while z <= w + 0.001:
		im.surface_add_vertex(Vector3(back, 0.0, z))
		im.surface_add_vertex(Vector3(back, h, z))
		z += step
	var y := 0.0
	while y <= h + 0.001:
		im.surface_add_vertex(Vector3(back, y, -w))
		im.surface_add_vertex(Vector3(back, y, w))
		# Costados.
		im.surface_add_vertex(Vector3(gx, y, -w))
		im.surface_add_vertex(Vector3(back, y, -w))
		im.surface_add_vertex(Vector3(gx, y, w))
		im.surface_add_vertex(Vector3(back, y, w))
		y += step
	var x := 0.0
	while x <= Pitch.GOAL_DEPTH + 0.001:
		var px := gx + side * x
		# Verticales de los costados.
		im.surface_add_vertex(Vector3(px, 0.0, -w))
		im.surface_add_vertex(Vector3(px, h, -w))
		im.surface_add_vertex(Vector3(px, 0.0, w))
		im.surface_add_vertex(Vector3(px, h, w))
		# Techo a lo ancho.
		im.surface_add_vertex(Vector3(px, h, -w))
		im.surface_add_vertex(Vector3(px, h, w))
		x += step
	z = -w
	while z <= w + 0.001:
		im.surface_add_vertex(Vector3(gx, h, z))
		im.surface_add_vertex(Vector3(back, h, z))
		z += step
	im.surface_end()
	var net := MeshInstance3D.new()
	net.mesh = im
	var nm := StandardMaterial3D.new()
	nm.albedo_color = Color(1, 1, 1, 0.55)
	nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	net.material_override = nm
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	goal.add_child(net)


static func _build_corner_flags(root: Node3D) -> void:
	var pole_mat := _flat_material(Color(0.95, 0.95, 0.95))
	var flag_mat := _flat_material(Color(1.0, 0.8, 0.1))
	flag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for xs: int in [-1, 1]:
		for zs: int in [-1, 1]:
			var pole := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.02
			cyl.bottom_radius = 0.02
			cyl.height = 1.5
			pole.mesh = cyl
			pole.material_override = pole_mat
			pole.position = Vector3(xs * Pitch.HALF_LENGTH, 0.75, zs * Pitch.HALF_WIDTH)
			root.add_child(pole)
			# El banderín gira alrededor del palo (lo mueve el viento: Atmosphere).
			var pivot := Node3D.new()
			pivot.name = "CornerFlag%d%d" % [xs + 1, zs + 1]
			pivot.position = pole.position + Vector3(0.0, 0.6, 0.0)
			root.add_child(pivot)
			var flag := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.4, 0.3)
			flag.mesh = q
			flag.material_override = flag_mat
			flag.position = Vector3(0.2, 0.0, 0.0)
			pivot.add_child(flag)
