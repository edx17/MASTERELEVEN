class_name PitchBuilder
extends RefCounted
## Genera por código la cancha reglamentaria: césped (shader), líneas, áreas,
## círculo central, medialunas, arcos con postes y red y banderines. El
## estadio alrededor lo arma StadiumBuilder.

const LINE_Y := 0.012


## `grass`: parámetros del césped según el clima (wetness, snow).
## Material del césped (el clima lo actualiza durante el partido).
static var grass_material: ShaderMaterial


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


## Ruido suave (simplex, sin costuras) para las manchas de nieve: bordes
## redondeados y difuminados (el ruido de valor del shader armaba contornos
## con rectas y triángulos).
static var _snow_tex: Texture2D
static func _snow_noise() -> Texture2D:
	if _snow_tex != null:
		return _snow_tex
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 4
	n.seed = 11
	var img := n.get_seamless_image(512, 512)
	img.convert(Image.FORMAT_L8)
	img.generate_mipmaps()
	_snow_tex = ImageTexture.create_from_image(img)
	return _snow_tex


static func _build_grass(root: Node3D, params: Dictionary = {}) -> void:
	# Un solo plano con shader: franjas de corte + variación natural.
	var grass := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(Pitch.HALF_LENGTH * 2.0 + 10.0, Pitch.HALF_WIDTH * 2.0 + 10.0)
	grass.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/stadium/grass.gdshader")
	for k in params:
		if k != "worn":
			mat.set_shader_parameter(k, params[k])
	GrassTextures.apply(mat, bool(params.get("worn", false)))
	if float(params.get("snow", 0.0)) > 0.0:
		mat.set_shader_parameter("snow_noise", _snow_noise())
	grass_material = mat
	grass.material_override = mat
	root.add_child(grass)


static func _build_lines(root: Node3D) -> void:
	root.add_child(lines_mesh())


## Las líneas de una cancha (todas las marcas de PitchMarkings) como malla
## plana sobre el pasto. Sirve también para canchas más chicas (Club House).
static func lines_mesh(hl: float = Pitch.HALF_LENGTH, hw: float = Pitch.HALF_WIDTH) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for l: Array in PitchMarkings.lines(hl, hw):
		_seg(st, l[0], l[1])
	for a: Array in PitchMarkings.arcs(hl, hw):
		var segs := maxi(8, int(absf(a[3] - a[2]) / TAU * 64.0))
		if a[4]:
			_arc(st, a[0], a[1], a[2], a[3], 12, a[1] * 2.0)
		else:
			_arc(st, a[0], a[1], a[2], a[3], segs)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Lines"
	mi.mesh = st.commit()
	var mat := _flat_material(Color(0.95, 0.95, 0.95))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


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
	# Red: grilla de líneas en fondo, costados y techo, en tramos cortos (así
	# se puede inflar donde pega la pelota; ver GoalNet).
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var back := gx + side * Pitch.GOAL_DEPTH
	var h := Pitch.GOAL_HEIGHT
	var w := Pitch.GOAL_HALF_WIDTH
	var step := 0.2
	# Fondo.
	var z := -w
	while z <= w + 0.001:
		_net_line(im, Vector3(back, 0.0, z), Vector3(back, h, z), step)
		z += step
	var y := 0.0
	while y <= h + 0.001:
		_net_line(im, Vector3(back, y, -w), Vector3(back, y, w), step)
		# Costados.
		_net_line(im, Vector3(gx, y, -w), Vector3(back, y, -w), step)
		_net_line(im, Vector3(gx, y, w), Vector3(back, y, w), step)
		y += step
	var x := 0.0
	while x <= Pitch.GOAL_DEPTH + 0.001:
		var px := gx + side * x
		# Verticales de los costados.
		_net_line(im, Vector3(px, 0.0, -w), Vector3(px, h, -w), step)
		_net_line(im, Vector3(px, 0.0, w), Vector3(px, h, w), step)
		# Techo a lo ancho.
		_net_line(im, Vector3(px, h, -w), Vector3(px, h, w), step)
		x += step
	z = -w
	while z <= w + 0.001:
		_net_line(im, Vector3(gx, h, z), Vector3(back, h, z), step)
		z += step
	im.surface_end()
	var net := GoalNet.new()
	net.name = "Net"
	net.side = side
	net.mesh = im
	var nm := ShaderMaterial.new()
	nm.shader = preload("res://scripts/stadium/goal_net.gdshader")
	nm.set_shader_parameter("side", float(side))
	nm.set_shader_parameter("front_x", gx)
	nm.set_shader_parameter("back_x", back)
	nm.set_shader_parameter("half_w", w)
	nm.set_shader_parameter("height", h)
	net.material_override = nm
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# La red se deforma: que no la recorte el AABB del mesh.
	net.extra_cull_margin = 1.0
	goal.add_child(net)


## Línea de la red partida en tramos de `step` (cada vértice puede moverse).
static func _net_line(im: ImmediateMesh, a: Vector3, b: Vector3, step: float) -> void:
	var n := maxi(1, ceili(a.distance_to(b) / step))
	for i in n:
		im.surface_add_vertex(a.lerp(b, float(i) / n))
		im.surface_add_vertex(a.lerp(b, float(i + 1) / n))


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
