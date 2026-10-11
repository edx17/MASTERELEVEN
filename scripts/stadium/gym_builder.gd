class_name GymBuilder
extends RefCounted
## Gimnasio de futsal (estadio de barrio techado): piso alrededor de la
## cancha, carteles bajos, bancos de suplentes del lado de la cámara, tribuna
## de cemento con público enfrente, paredes de ladrillo, techo de chapa sobre
## cerchas y paneles de luz (sin reflectores: liviano también en el celular).
## La cancha (piso y líneas) la arma PitchBuilder.

## Lugar entre la cancha y la pared / la tribuna (m).
const SIDE_GAP := 4.5
const END_GAP := 5.0
const WALL_H := 9.0
const ROOF_Y := 10.5
const ROWS := 8
const ROW_DEPTH := 0.8
const ROW_RISE := 0.42


static func _mat(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func build(home: TeamData = null) -> Node3D:
	var root := Node3D.new()
	root.name = "Gym"
	var hl := Pitch.HALF_LENGTH
	var hw := Pitch.HALF_WIDTH
	var main := home.color if home != null else Color(0.12, 0.2, 0.5)
	var second := home.secondary_color if home != null else Color(0.95, 0.85, 0.3)
	# Los jugadores salen por el costado de la cámara (la presentación).
	StadiumBuilder.tunnel_z = hw + SIDE_GAP - 0.5
	var stand_z := -(hw + SIDE_GAP)
	var wall_x := hl + END_GAP
	var back_z := stand_z - ROWS * ROW_DEPTH - 1.5
	var front_z := hw + SIDE_GAP + 3.0
	_walls(root, wall_x, back_z, front_z, main)
	_stand(root, stand_z, hl + 2.0, main, second)
	_boards(root, hl, hw, main, second, home)
	_benches(root, hw)
	var roof := Node3D.new()
	roof.name = "Roof"
	root.add_child(roof)
	_roof(roof, wall_x, back_z, front_z)
	return root


## Las cámaras altas (Amplia, dron) quedan arriba del techo: ahí no se dibuja.
static func set_camera_height(stadium: Node3D, y: float) -> void:
	var roof := stadium.get_node_or_null("Roof") as Node3D
	if roof != null:
		roof.visible = y < ROOF_Y - 0.5


## Paredes de ladrillo pintado (abajo el color del club) en los cuatro lados.
static func _walls(root: Node3D, wall_x: float, back_z: float, front_z: float, main: Color) -> void:
	var brick := _mat(Color(0.78, 0.74, 0.68), 0.95)
	var paint := _mat(main.darkened(0.15), 0.8)
	var len_x := wall_x * 2.0
	var len_z := front_z - back_z
	var mid_z := (front_z + back_z) * 0.5
	for xs: int in [-1, 1]:
		_box(root, Vector3(xs * wall_x, WALL_H * 0.5, mid_z), Vector3(0.4, WALL_H, len_z), brick)
		_box(root, Vector3(xs * (wall_x - 0.21), 1.1, mid_z), Vector3(0.02, 2.2, len_z), paint)
	_box(root, Vector3(0.0, WALL_H * 0.5, back_z), Vector3(len_x, WALL_H, 0.4), brick)
	# Del lado de la cámara la pared es baja (no tapa la vista de TV).
	_box(root, Vector3(0.0, 1.2, front_z), Vector3(len_x, 2.4, 0.4), brick)
	_box(root, Vector3(0.0, 1.1, front_z - 0.21), Vector3(len_x, 2.2, 0.02), paint)


## Tribuna de cemento enfrente de la cámara, con el público.
static func _stand(root: Node3D, stand_z: float, half_len: float, main: Color, second: Color) -> void:
	var node := Node3D.new()
	node.name = "StandGym"
	root.add_child(node)
	var concrete := _mat(Color(0.6, 0.6, 0.58), 0.95)
	var rail := _mat(Color(0.25, 0.27, 0.3), 0.5)
	var people: Array[Transform3D] = []
	var custom: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var fans := [main, second, Color(0.92, 0.92, 0.9), Color(0.2, 0.2, 0.22), Color(0.45, 0.5, 0.6)]
	for r in ROWS:
		var y := ROW_RISE * (r + 1)
		var z := stand_z - ROW_DEPTH * (r + 0.5)
		_box(node, Vector3(0.0, y * 0.5, z), Vector3(half_len * 2.0, y, ROW_DEPTH), concrete)
		var x := -half_len + 0.4
		while x < half_len - 0.3:
			# Lleno de a ratos: los gimnasios no se llenan parejo.
			if rng.randf() < 0.72 * GameSettings.crowd_factor():
				var b := Basis(Vector3.UP, PI + rng.randf_range(-0.15, 0.15))
				people.append(Transform3D(b, Vector3(x, y, z + 0.1)))
				var c: Color = fans[rng.randi() % fans.size()]
				custom.append(Color(c.r, c.g, c.b, rng.randf()))
			x += 0.55
	# Baranda adelante.
	_box(node, Vector3(0.0, 1.0, stand_z + 0.05), Vector3(half_len * 2.0, 0.05, 0.05), rail, false)
	if people.is_empty():
		return
	if StadiumBuilder.crowd_material == null:
		StadiumBuilder.crowd_material = ShaderMaterial.new()
		StadiumBuilder.crowd_material.shader = preload("res://scripts/stadium/crowd.gdshader")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = StadiumBuilder._person_mesh()
	mm.instance_count = people.size()
	for i in people.size():
		mm.set_instance_transform(i, people[i])
		mm.set_instance_custom_data(i, custom[i])
	var crowd := MultiMeshInstance3D.new()
	crowd.name = "Crowd"
	crowd.multimesh = mm
	crowd.material_override = StadiumBuilder.crowd_material
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(crowd)


## Carteles bajos alrededor de la cancha (colores del local y neutros).
static func _boards(root: Node3D, hl: float, hw: float, main: Color, second: Color, home: TeamData) -> void:
	var colors := [main, second.darkened(0.1), Color(0.1, 0.12, 0.16), Color(0.9, 0.9, 0.88)]
	var text := home.team_name.to_upper() if home != null else "VIRTUAL ELEVEN"
	var i := 0
	# Detrás de los arcos y del lado de la tribuna (del de la cámara no: tapan).
	for side: int in [-1, 1]:
		var x: float = side * (hl + 2.2)
		var z := -hw + 1.0
		while z < hw - 1.0:
			_board(root, Vector3(x, 0.4, z + 1.5), Vector3(0.12, 0.8, 3.0), colors[i % colors.size()], text, side)
			z += 3.2
			i += 1
	var x2 := -hl + 1.0
	while x2 < hl - 1.0:
		_board(root, Vector3(x2 + 2.0, 0.4, -hw - 1.6), Vector3(4.0, 0.8, 0.12), colors[i % colors.size()], text, 0)
		x2 += 4.2
		i += 1


static func _board(root: Node3D, pos: Vector3, size: Vector3, c: Color, text: String, side: int) -> void:
	_box(root, pos, size, _mat(c, 0.5), false)
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.004
	l.modulate = Color.WHITE if c.get_luminance() < 0.55 else Color(0.08, 0.1, 0.14)
	l.outline_size = 0
	if side == 0:
		l.position = pos + Vector3(0.0, 0.0, size.z * 0.5 + 0.01)
	else:
		l.position = pos + Vector3(-side * (size.x * 0.5 + 0.01), 0.0, 0.0)
		l.rotation.y = -side * PI * 0.5
	root.add_child(l)


## Bancos de suplentes y mesa del cronometrista, del lado de la cámara.
static func _benches(root: Node3D, hw: float) -> void:
	var seat := _mat(Color(0.2, 0.22, 0.26), 0.6)
	var table := _mat(Color(0.85, 0.85, 0.82), 0.6)
	var z := hw + 2.6
	for xs: int in [-1, 1]:
		_box(root, Vector3(xs * 7.5, 0.25, z), Vector3(5.0, 0.5, 0.6), seat)
		_box(root, Vector3(xs * 7.5, 0.75, z + 0.32), Vector3(5.0, 1.0, 0.08), seat)
	_box(root, Vector3(0.0, 0.4, z - 0.4), Vector3(3.0, 0.8, 0.8), table)


## Techo de chapa sobre cerchas, con paneles de luz (emiten; no son luces).
static func _roof(root: Node3D, wall_x: float, back_z: float, front_z: float) -> void:
	var steel := _mat(Color(0.35, 0.37, 0.4), 0.6)
	var sheet := _mat(Color(0.62, 0.64, 0.66), 0.7)
	sheet.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1.0, 0.98, 0.92)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.97, 0.9)
	lamp.emission_energy_multiplier = 4.0
	var len_z := front_z - back_z
	var mid_z := (front_z + back_z) * 0.5
	# Chapa: no hace sombra (el sol entra "por los ventanales" y la cancha se ve pareja).
	var roof := _box(root, Vector3(0.0, ROOF_Y + 0.6, mid_z), Vector3(wall_x * 2.0, 0.08, len_z), sheet, false)
	roof.name = "RoofSheet"
	var x := -wall_x + 3.0
	while x <= wall_x - 2.9:
		# Cercha: cordón inferior y superior.
		_box(root, Vector3(x, ROOF_Y, mid_z), Vector3(0.2, 0.2, len_z), steel, false)
		_box(root, Vector3(x, ROOF_Y + 0.5, mid_z), Vector3(0.15, 0.15, len_z), steel, false)
		# Paneles de luz entre cerchas, sobre la cancha.
		for z in [-6.0, 0.0, 6.0]:
			_box(root, Vector3(x + 2.0, ROOF_Y - 0.25, z), Vector3(1.2, 0.08, 0.6), lamp, false)
		x += 4.0
