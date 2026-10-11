class_name GymBuilder
extends RefCounted
## Estadios de futsal (techados). Tres estilos (GameSettings.gym_style):
##   0 Microestadio (Argentina): el gimnasio del club. Paredes de ladrillo con
##     zócalo del color del club, tribuna de cemento enfrente, techo de chapa
##     sobre cerchas, marcador de pared y banderas colgadas de la baranda.
##   1 Pabellón (España): arena moderna, oscura. Butacas de plástico en los
##     colores del club en tres lados (con el nombre escrito en las butacas
##     vacías), carteles LED, videomarcador colgado sobre la mitad de la
##     cancha y anillos de luz en un techo negro con parrilla.
##   2 Ginásio (Brasil): olla de cemento empinada, gradas pintadas a franjas
##     con los colores del club, alambrado, bandeirões colgados, la torcida
##     detrás de un arco, techo en arco con lucernarios y ventanales
##     basculantes en las cabeceras.
## Sin reflectores de verdad: todas las luces son paneles que emiten (liviano
## también en el celular). La cancha (piso y líneas) la arma PitchBuilder.
## Del lado de la cámara sólo hay bancos, mesa y una pared baja.

enum Style { MICRO, PABELLON, GINASIO }
const NAMES := ["Microestadio", "Pabellón (España)", "Ginásio (Brasil)"]

## Lugar entre la cancha y la pared / la tribuna (m).
const SIDE_GAP := 4.5
const END_GAP := 5.0
const WALL_H := 9.0
## Altura del techo (las cámaras más altas no lo dibujan).
const ROOF_Y := 10.5
const ROWS := 8
const ROW_DEPTH := 0.8
const ROW_RISE := 0.42


static func _mat(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _glow(c: Color, energy: float = 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
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


static func _label(parent: Node3D, text: String, pos: Vector3, size: int, pixel: float, color: Color,
		yaw: float = 0.0, outline: int = 0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = outline
	l.position = pos
	l.rotation.y = yaw
	parent.add_child(l)
	return l


static func style_name(i: int) -> String:
	return NAMES[clampi(i, 0, NAMES.size() - 1)]


static func build(home: TeamData = null, style: int = Style.MICRO) -> Node3D:
	var root := Node3D.new()
	root.name = "Gym"
	root.set_meta("style", style)
	var main := home.color if home != null else Color(0.12, 0.2, 0.5)
	var second := home.secondary_color if home != null else Color(0.95, 0.85, 0.3)
	if main.is_equal_approx(second):
		second = Color.WHITE if main.get_luminance() < 0.5 else Color(0.1, 0.1, 0.12)
	# Los jugadores salen por el costado de la cámara (la presentación).
	StadiumBuilder.tunnel_z = Pitch.HALF_WIDTH + SIDE_GAP - 0.5
	var roof := Node3D.new()
	roof.name = "Roof"
	match style:
		Style.PABELLON:
			_pabellon(root, roof, home, main, second)
		Style.GINASIO:
			_ginasio(root, roof, home, main, second)
		_:
			_micro(root, roof, home, main, second)
	root.add_child(roof)
	_benches(root, Pitch.HALF_WIDTH)
	return root


## Las cámaras altas (Amplia, dron) quedan arriba del techo: ahí no se dibuja.
static func set_camera_height(stadium: Node3D, y: float) -> void:
	var roof := stadium.get_node_or_null("Roof") as Node3D
	if roof != null:
		roof.visible = y < ROOF_Y - 0.5


# --- Microestadio (Argentina) ---------------------------------------------------------

static func _micro(root: Node3D, roof: Node3D, home: TeamData, main: Color, second: Color) -> void:
	var hl := Pitch.HALF_LENGTH
	var hw := Pitch.HALF_WIDTH
	var stand_z := -(hw + SIDE_GAP)
	var wall_x := hl + END_GAP
	var back_z := stand_z - ROWS * ROW_DEPTH - 1.5
	var front_z := hw + SIDE_GAP + 3.0
	_walls(root, wall_x, back_z, front_z, main)
	var crowd := Crowd.new()
	var rng := _rng(home, 23)
	var fans := [main, second, Color(0.92, 0.92, 0.9), Color(0.2, 0.2, 0.22), Color(0.45, 0.5, 0.6)]
	var concrete := _mat(Color(0.6, 0.6, 0.58), 0.95)
	# Lleno de a ratos: los gimnasios no se llenan parejo.
	_seating(root, Vector3(0.0, 0.0, stand_z), Vector3.BACK, hl + 2.0, ROWS, ROW_DEPTH, ROW_RISE, 0.0,
		[concrete], 0.72, fans, rng, crowd)
	crowd.commit(root, "StandGym")
	var rail := _mat(Color(0.25, 0.27, 0.3), 0.5)
	_box(root, Vector3(0.0, 1.0, stand_z + 0.05), Vector3((hl + 2.0) * 2.0, 0.05, 0.05), rail, false)
	_boards(root, hl, hw, [main, second.darkened(0.1), Color(0.1, 0.12, 0.16), Color(0.9, 0.9, 0.88)], home, false)
	# Trapos colgados de la baranda y marcador de pared.
	_rag_banners(root, stand_z + 0.08, hl, main, second, home, rng)
	_wall_scoreboard(root, Vector3(0.0, WALL_H - 1.6, back_z + 0.22), main)
	_tin_roof(roof, wall_x, back_z, front_z)


## Paredes de ladrillo pintado (abajo el color del club) en los cuatro lados.
static func _walls(root: Node3D, wall_x: float, back_z: float, front_z: float, main: Color) -> void:
	var brick := _mat(Color(0.78, 0.74, 0.68), 0.95)
	var paint := _mat(main.darkened(0.15), 0.8)
	var len_x := wall_x * 2.0
	var len_z := front_z - back_z
	var mid_z := (front_z + back_z) * 0.5
	# Las paredes llegan hasta la chapa (no se ve el cielo por arriba).
	var top := ROOF_Y + 0.65
	for xs: int in [-1, 1]:
		_box(root, Vector3(xs * wall_x, top * 0.5, mid_z), Vector3(0.4, top, len_z), brick)
		_box(root, Vector3(xs * (wall_x - 0.21), 1.1, mid_z), Vector3(0.02, 2.2, len_z), paint)
		# Ventanitas altas (entra la luz de la tarde).
		var z := back_z + 2.0
		var glass := _glow(Color(0.85, 0.9, 0.95), 1.2)
		while z < front_z - 2.0:
			_box(root, Vector3(xs * (wall_x - 0.21), WALL_H - 1.4, z), Vector3(0.03, 1.0, 1.6), glass, false)
			z += 3.0
	_box(root, Vector3(0.0, top * 0.5, back_z), Vector3(len_x, top, 0.4), brick)
	# Del lado de la cámara la pared es baja (no tapa la vista de TV).
	_box(root, Vector3(0.0, 1.2, front_z), Vector3(len_x, 2.4, 0.4), brick)
	_box(root, Vector3(0.0, 1.1, front_z - 0.21), Vector3(len_x, 2.2, 0.02), paint)


## Trapos de la hinchada colgados de la baranda (tela con los colores del club).
static func _rag_banners(root: Node3D, z: float, hl: float, main: Color, second: Color, home: TeamData,
		rng: RandomNumberGenerator) -> void:
	var name := home.team_name.to_upper() if home != null else "LOCAL"
	var texts := ["LA BANDA DE " + name, "SIEMPRE CON VOS", name + " DE MI VIDA", "AGUANTE " + name]
	var x := -hl + 3.0
	var i := 0
	while x < hl - 3.0:
		var w := rng.randf_range(3.0, 5.0)
		var c := main if i % 2 == 0 else second
		_box(root, Vector3(x + w * 0.5, 0.55, z + 0.03), Vector3(w, 0.9, 0.02), _mat(c, 0.95), false)
		_label(root, texts[i % texts.size()], Vector3(x + w * 0.5, 0.55, z + 0.05), 48, 0.006,
			second if i % 2 == 0 else main)
		x += w + rng.randf_range(1.5, 3.5)
		i += 1


## Techo de chapa sobre cerchas, con paneles de luz (emiten; no son luces).
static func _tin_roof(root: Node3D, wall_x: float, back_z: float, front_z: float) -> void:
	var steel := _mat(Color(0.35, 0.37, 0.4), 0.6)
	var sheet := _mat(Color(0.62, 0.64, 0.66), 0.7)
	sheet.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lamp := _glow(Color(1.0, 0.97, 0.9), 4.0)
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


# --- Pabellón (España) ------------------------------------------------------------------

const PAB_SIDE_ROWS := 14
const PAB_END_ROWS := 11
const PAB_ROW_DEPTH := 0.82
const PAB_ROW_RISE := 0.5
## Primera fila: arriba de un muro (el foso de los carteles).
const PAB_PODIUM := 1.3


static func _pabellon(root: Node3D, roof: Node3D, home: TeamData, main: Color, second: Color) -> void:
	var hl := Pitch.HALF_LENGTH
	var hw := Pitch.HALF_WIDTH
	var stand_z := -(hw + SIDE_GAP)
	var end_x := hl + END_GAP
	var back_z := stand_z - PAB_SIDE_ROWS * PAB_ROW_DEPTH - 1.0
	var front_z := hw + SIDE_GAP + 3.0
	var wall_x := end_x + PAB_END_ROWS * PAB_ROW_DEPTH + 1.0
	var dark := _mat(Color(0.07, 0.08, 0.11), 0.6)
	var podium := _mat(Color(0.12, 0.13, 0.17), 0.5)
	# Caja negra: paredes, y abajo del lado de la cámara una pared baja con el color del club.
	var len_x := wall_x * 2.0
	var len_z := front_z - back_z
	var mid_z := (front_z + back_z) * 0.5
	var top := ROOF_Y + 2.6
	_box(root, Vector3(0.0, top * 0.5, back_z), Vector3(len_x, top, 0.4), dark)
	for xs: int in [-1, 1]:
		_box(root, Vector3(xs * wall_x, top * 0.5, mid_z), Vector3(0.4, top, len_z), dark)
	_box(root, Vector3(0.0, 0.6, front_z), Vector3(len_x, 1.2, 0.4), _mat(main.darkened(0.3), 0.5))
	# Butacas: el color del club, con el segundo color formando el nombre.
	var seats := [_seat_color(main), _seat_color(second)]
	var crowd := Crowd.new()
	var rng := _rng(home, 41)
	var fans := [main, main, second, Color(0.92, 0.92, 0.9), Color(0.15, 0.15, 0.18)]
	var away := GameSettings.away_team()
	var away_fans := [away.color, away.secondary_color] if away != null else fans
	# En las butacas entra el nombre si es corto; si no, la sigla.
	var name := "LOCAL"
	if home != null:
		name = home.team_name.to_upper() if home.team_name.length() <= 8 else home.short_name.to_upper()
	# Tribuna principal (enfrente) y las dos cabeceras; los visitantes, en una esquina.
	_seating(root, Vector3(0.0, PAB_PODIUM, stand_z), Vector3.BACK, end_x, PAB_SIDE_ROWS, PAB_ROW_DEPTH,
		PAB_ROW_RISE, PAB_PODIUM, [podium], 0.82, fans, rng, crowd, seats, name)
	for xs: int in [-1, 1]:
		var f: Array = away_fans if xs == 1 else fans
		_seating(root, Vector3(xs * end_x, PAB_PODIUM, 0.0), Vector3(-xs, 0, 0), hw + SIDE_GAP - 0.3,
			PAB_END_ROWS, PAB_ROW_DEPTH, PAB_ROW_RISE, PAB_PODIUM, [podium], 0.7 if xs == 1 else 0.85, f, rng,
			crowd, seats, "" if xs == 1 else name)
	crowd.commit(root, "StandPabellon")
	# Muro del foso y carteles LED a ras de piso.
	_box(root, Vector3(0.0, PAB_PODIUM * 0.5, stand_z + 0.1), Vector3(end_x * 2.0, PAB_PODIUM, 0.2), podium)
	for xs: int in [-1, 1]:
		_box(root, Vector3(xs * (end_x - 0.1), PAB_PODIUM * 0.5, 0.0), Vector3(0.2, PAB_PODIUM, (hw + SIDE_GAP) * 2.0), podium)
	_led_ribbon(root, Vector3(0.0, PAB_PODIUM - 0.3, stand_z + 0.22), Vector3.BACK, end_x * 2.0 - 0.6, main, home)
	for xs: int in [-1, 1]:
		_led_ribbon(root, Vector3(xs * (end_x - 0.22), PAB_PODIUM - 0.3, 0.0), Vector3(-xs, 0, 0),
			(hw + SIDE_GAP) * 2.0 - 0.6, main, home)
	_boards(root, hl, hw, [Color(0.05, 0.06, 0.09)], home, true)
	# Pantallas gigantes en las cabeceras y el nombre del club arriba de la principal.
	_label(root, (home.team_name if home != null else "VIRTUAL ELEVEN").to_upper(),
		Vector3(0.0, PAB_PODIUM + PAB_SIDE_ROWS * PAB_ROW_RISE + 1.6, back_z + 0.25), 160, 0.012, main.lightened(0.25))
	for xs: int in [-1, 1]:
		var screen := _box(root, Vector3(xs * (wall_x - 0.25), WALL_H - 1.2, 0.0), Vector3(0.1, 2.6, 5.0),
			_glow(Color(0.05, 0.08, 0.14), 1.0), false)
		screen.name = "EndScreen"
		var sb := Scoreboard.new()
		sb.position = Vector3(xs * (wall_x - 0.32), WALL_H - 1.2, 0.0)
		sb.rotation.y = -xs * PI * 0.5
		sb.accent = main
		root.add_child(sb)
	_arena_roof(roof, wall_x, back_z, front_z, main)


## Color de butaca de plástico (un poco más apagado que el de la camiseta).
static func _seat_color(c: Color) -> Color:
	return c.darkened(0.12).lerp(Color(0.5, 0.5, 0.52), 0.08)


## Cinta LED: una franja oscura con el nombre del local que brilla.
static func _led_ribbon(root: Node3D, center: Vector3, facing: Vector3, length: float, main: Color,
		home: TeamData) -> void:
	var b := Basis.looking_at(-facing)
	var mi := _box(root, center, Vector3(length, 0.55, 0.06), _glow(Color(0.02, 0.03, 0.06), 0.4), false)
	mi.basis = b
	var text := (home.team_name if home != null else "VIRTUAL ELEVEN").to_upper()
	var n := maxi(1, int(length / 9.0))
	var right := b.x
	for i in n:
		var off := (float(i) + 0.5) / n - 0.5
		var l := _label(root, text + "   ·   FUTSAL", center + right * off * length + facing * 0.04, 56, 0.006,
			main.lightened(0.45))
		l.basis = b


## Techo de arena: negro, con parrilla de luces y anillo de luz sobre la cancha.
static func _arena_roof(root: Node3D, wall_x: float, back_z: float, front_z: float, main: Color) -> void:
	var black := _mat(Color(0.03, 0.03, 0.04), 0.9)
	black.cull_mode = BaseMaterial3D.CULL_DISABLED
	var steel := _mat(Color(0.18, 0.19, 0.22), 0.5)
	var lamp := _glow(Color(1.0, 0.99, 0.96), 5.0)
	var len_z := front_z - back_z
	var mid_z := (front_z + back_z) * 0.5
	var top := ROOF_Y + 2.5
	_box(root, Vector3(0.0, top, mid_z), Vector3(wall_x * 2.0, 0.1, len_z), black, false).name = "RoofSheet"
	# Parrilla (rejilla de vigas).
	var x := -wall_x + 2.0
	while x <= wall_x - 1.9:
		_box(root, Vector3(x, top - 0.6, mid_z), Vector3(0.18, 0.18, len_z), steel, false)
		x += 4.0
	var z := back_z + 2.0
	while z <= front_z - 1.9:
		_box(root, Vector3(0.0, top - 0.8, z), Vector3(wall_x * 2.0, 0.14, 0.14), steel, false)
		z += 4.0
	# Anillo de luces (rectángulo) sobre la cancha.
	var hl := Pitch.HALF_LENGTH + 1.0
	var hw := Pitch.HALF_WIDTH + 1.0
	for zs: int in [-1, 1]:
		_box(root, Vector3(0.0, ROOF_Y, zs * hw), Vector3(hl * 2.0, 0.12, 0.5), lamp, false)
	for xs: int in [-1, 1]:
		_box(root, Vector3(xs * hl, ROOF_Y, 0.0), Vector3(0.5, 0.12, hw * 2.0), lamp, false)
	# Un borde del color del club alrededor del anillo.
	var trim := _glow(main, 1.5)
	for zs: int in [-1, 1]:
		_box(root, Vector3(0.0, ROOF_Y + 0.12, zs * (hw + 0.35)), Vector3(hl * 2.0 + 0.7, 0.12, 0.12), trim, false)
	for xs: int in [-1, 1]:
		_box(root, Vector3(xs * (hl + 0.35), ROOF_Y + 0.12, 0.0), Vector3(0.12, 0.12, hw * 2.0 + 0.7), trim, false)


# --- Ginásio (Brasil) -------------------------------------------------------------------

const GIN_SIDE_ROWS := 16
const GIN_END_ROWS := 13
const GIN_ROW_DEPTH := 0.7
const GIN_ROW_RISE := 0.55
const GIN_PODIUM := 0.9


static func _ginasio(root: Node3D, roof: Node3D, home: TeamData, main: Color, second: Color) -> void:
	var hl := Pitch.HALF_LENGTH
	var hw := Pitch.HALF_WIDTH
	var stand_z := -(hw + SIDE_GAP)
	var end_x := hl + END_GAP
	var back_z := stand_z - GIN_SIDE_ROWS * GIN_ROW_DEPTH - 0.8
	var front_z := hw + SIDE_GAP + 3.0
	var wall_x := end_x + GIN_END_ROWS * GIN_ROW_DEPTH + 0.8
	var concrete := _mat(Color(0.66, 0.65, 0.62), 0.95)
	var painted := [_mat(main.darkened(0.05), 0.9), _mat(second.darkened(0.05), 0.9)]
	# Paredes de concreto, pintadas abajo; ventanales basculantes en las cabeceras.
	var len_x := wall_x * 2.0
	var len_z := front_z - back_z
	var mid_z := (front_z + back_z) * 0.5
	# Hasta el arranque de la bóveda.
	var high := ROOF_Y + 1.05
	_box(root, Vector3(0.0, high * 0.5, back_z), Vector3(len_x, high, 0.4), concrete)
	var glass := _glow(Color(0.9, 0.93, 0.9), 1.4)
	var frame := _mat(Color(0.3, 0.32, 0.3), 0.6)
	for xs: int in [-1, 1]:
		_box(root, Vector3(xs * wall_x, high * 0.5, mid_z), Vector3(0.4, high, len_z), concrete)
		var z := back_z + 1.5
		while z < front_z - 1.5:
			_box(root, Vector3(xs * (wall_x - 0.22), high - 2.2, z), Vector3(0.04, 1.6, 1.3), glass, false)
			_box(root, Vector3(xs * (wall_x - 0.25), high - 2.2, z), Vector3(0.05, 0.08, 1.3), frame, false)
			z += 1.6
	_box(root, Vector3(0.0, 1.2, front_z), Vector3(len_x, 2.4, 0.4), concrete)
	_box(root, Vector3(0.0, 1.1, front_z - 0.21), Vector3(len_x, 2.2, 0.02), painted[0])
	# Gradas a franjas (los colores del club, fila por medio), llenas.
	var crowd := Crowd.new()
	var rng := _rng(home, 77)
	var fans := [main, main, second, second, Color(0.95, 0.95, 0.93), Color(0.15, 0.15, 0.17)]
	var away := GameSettings.away_team()
	var away_fans := [away.color, away.secondary_color, Color(0.9, 0.9, 0.9)] if away != null else fans
	_seating(root, Vector3(0.0, GIN_PODIUM, stand_z), Vector3.BACK, end_x, GIN_SIDE_ROWS, GIN_ROW_DEPTH,
		GIN_ROW_RISE, GIN_PODIUM, painted, 0.93, fans, rng, crowd)
	for xs: int in [-1, 1]:
		# Detrás del arco izquierdo, la torcida (repleta); a la derecha, los visitantes y un pulmón.
		var f: Array = fans if xs == -1 else away_fans
		_seating(root, Vector3(xs * end_x, GIN_PODIUM, 0.0), Vector3(-xs, 0, 0), hw + SIDE_GAP - 0.3,
			GIN_END_ROWS, GIN_ROW_DEPTH, GIN_ROW_RISE, GIN_PODIUM, painted, 0.98 if xs == -1 else 0.55, f, rng, crowd)
	crowd.commit(root, "StandGinasio")
	_box(root, Vector3(0.0, GIN_PODIUM * 0.5, stand_z + 0.1), Vector3(end_x * 2.0, GIN_PODIUM, 0.2), concrete)
	for xs: int in [-1, 1]:
		_box(root, Vector3(xs * (end_x - 0.1), GIN_PODIUM * 0.5, 0.0), Vector3(0.2, GIN_PODIUM, (hw + SIDE_GAP) * 2.0), concrete)
	# Alambrado adelante de las gradas.
	_fence(root, Vector3(0.0, 0.0, stand_z + 0.25), Vector3.BACK, end_x * 2.0)
	for xs: int in [-1, 1]:
		_fence(root, Vector3(xs * (end_x - 0.25), 0.0, 0.0), Vector3(-xs, 0, 0), (hw + SIDE_GAP) * 2.0)
	# Bandeirões de la torcida colgados sobre las gradas y banderas en mástil.
	_bandeiroes(root, home, main, second, stand_z, end_x, rng)
	_boards(root, hl, hw, [main, second, Color(0.98, 0.98, 0.96), main.darkened(0.35)], home, false)
	_wall_scoreboard(root, Vector3(0.0, high - 2.0, back_z + 0.22), main)
	_arch_roof(roof, wall_x, back_z, front_z)


## Alambrado: postes y una malla que deja ver (semitransparente).
static func _fence(root: Node3D, center: Vector3, facing: Vector3, length: float) -> void:
	var b := Basis.looking_at(-facing)
	var mesh := StandardMaterial3D.new()
	mesh.albedo_color = Color(0.75, 0.78, 0.8, 0.18)
	mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var h := 3.2
	var net := _box(root, center + Vector3(0.0, h * 0.5, 0.0), Vector3(length, h, 0.01), mesh, false)
	net.basis = b
	var post := _mat(Color(0.55, 0.57, 0.6), 0.4)
	var n := int(length / 2.5)
	for i in n + 1:
		var off := (float(i) / n - 0.5) * length
		_box(root, center + b.x * off + Vector3(0.0, h * 0.5, 0.0), Vector3(0.06, h, 0.06), post, false)
	var top := _box(root, center + Vector3(0.0, h, 0.0), Vector3(length, 0.05, 0.05), post, false)
	top.basis = b


## Bandeirões: telas grandes colgadas sobre las gradas, con los colores y el
## nombre del club; y banderas en mástil en la torcida.
static func _bandeiroes(root: Node3D, home: TeamData, main: Color, second: Color, stand_z: float,
		end_x: float, rng: RandomNumberGenerator) -> void:
	var name := home.team_name.to_upper() if home != null else "LOCAL"
	var texts := ["TORCIDA " + name, "FORÇA " + name, "AMOR ETERNO", "NOSSA PAIXÃO"]
	var y0 := GIN_PODIUM + 2.2
	var i := 0
	for x in [-11.0, -3.5, 4.0, 11.5]:
		var w := 5.5
		var c := main if i % 2 == 0 else second
		var z := stand_z - 2.0 - i % 2 * 1.4
		var y := y0 + (i % 2) * 1.4 * GIN_ROW_RISE / GIN_ROW_DEPTH
		var cloth := _mat(c, 0.95)
		cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
		_box(root, Vector3(x, y, z), Vector3(w, 1.6, 0.03), cloth, false)
		var band := _mat(second if i % 2 == 0 else main, 0.95)
		_box(root, Vector3(x, y - 0.55, z + 0.02), Vector3(w, 0.25, 0.02), band, false)
		_label(root, texts[i % texts.size()], Vector3(x, y + 0.1, z + 0.04), 72, 0.009,
			second if i % 2 == 0 else main, 0.0, 6)
		i += 1
	# Mástiles en la torcida (cabecera izquierda).
	var spots: Array[Vector3] = []
	for k in 9:
		var r := rng.randi_range(1, GIN_END_ROWS - 2)
		var zz := rng.randf_range(-Pitch.HALF_WIDTH, Pitch.HALF_WIDTH)
		spots.append(Vector3(-(end_x + GIN_ROW_DEPTH * (r + 0.5)), GIN_PODIUM + GIN_ROW_RISE * (r + 1), zz))
	var fans := {"home": main, "home2": second, "away": main, "away2": second,
		"home_crest": home.crest if home != null else null}
	StadiumBuilder._flags(root, spots, fans, false, rng)


## Techo en arco (bóveda de chapa sobre arcos de acero) con lucernarios.
static func _arch_roof(root: Node3D, wall_x: float, back_z: float, front_z: float) -> void:
	var steel := _mat(Color(0.42, 0.44, 0.47), 0.5)
	var sheet := _mat(Color(0.7, 0.71, 0.72), 0.75)
	sheet.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sky := _glow(Color(0.92, 0.95, 1.0), 2.2)
	var len_z := front_z - back_z
	var mid_z := (front_z + back_z) * 0.5
	var span := wall_x * 2.0
	var rise := 4.0
	var segs := 12
	var base_y := ROOF_Y + 1.0
	for s in segs:
		var t0 := float(s) / segs
		var t1 := float(s + 1) / segs
		var x0 := (t0 - 0.5) * span
		var x1 := (t1 - 0.5) * span
		var y0 := base_y + rise * (1.0 - pow(2.0 * t0 - 1.0, 2.0))
		var y1 := base_y + rise * (1.0 - pow(2.0 * t1 - 1.0, 2.0))
		var mid := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, mid_z)
		var seg_len := Vector2(x1 - x0, y1 - y0).length()
		var ang := atan2(y1 - y0, x1 - x0)
		# Franjas de lucernario (cada tanto la chapa es traslúcida).
		var m: Material = sky if s % 4 == 1 else sheet
		var panel := _box(root, mid, Vector3(seg_len + 0.05, 0.08, len_z), m, false)
		panel.rotation.z = ang
		if s == segs / 2:
			panel.name = "RoofSheet"
		# Arcos de acero cada 5 m.
		var z := back_z + 1.0
		while z <= front_z - 0.9:
			var rib := _box(root, Vector3(mid.x, mid.y - 0.25, z), Vector3(seg_len + 0.05, 0.3, 0.2), steel, false)
			rib.rotation.z = ang
			z += 5.0
	# Paneles de luz colgados sobre la cancha.
	var lamp := _glow(Color(1.0, 0.98, 0.9), 4.5)
	for x in [-12.0, -6.0, 0.0, 6.0, 12.0]:
		for z in [-6.0, 0.0, 6.0]:
			_box(root, Vector3(x, ROOF_Y - 0.2, z), Vector3(1.4, 0.1, 0.7), lamp, false)


# --- Comunes --------------------------------------------------------------------------

static func _rng(home: TeamData, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = salt + (hash(home.id) if home != null else 0)
	return rng


## Tribuna escalonada. `origin` es el borde de adelante (al centro), `facing`
## mira a la cancha; las filas suben y se alejan. `steps` son los materiales
## de las gradas (se alternan fila por fila). Con `seats`, butacas de colores
## (MultiMesh) y, si hay `text`, las butacas vacías escriben el nombre.
static func _seating(root: Node3D, origin: Vector3, facing: Vector3, half_len: float, rows: int,
		depth: float, rise: float, base_y: float, steps: Array, fill: float, fans: Array,
		rng: RandomNumberGenerator, crowd: Crowd, seats: Array = [], text := "") -> void:
	var look := Basis.looking_at(facing)
	var right := look.x
	var letters := _text_mask(text, rows) if text != "" else []
	for r in rows:
		var y := base_y + rise * (r + 1)
		var c := origin - facing * depth * (r + 0.5)
		c.y = 0.0
		var step := _box(root, c + Vector3(0.0, y * 0.5, 0.0), Vector3(half_len * 2.0, y, depth), steps[r % steps.size()])
		step.basis = look
		step.position = c + Vector3(0.0, y * 0.5, 0.0)
		var cols := int((half_len * 2.0 - 0.7) / 0.55)
		for k in cols:
			var x := -half_len + 0.4 + k * 0.55
			var p := c + right * x + Vector3(0.0, y, 0.0) + facing * 0.1
			var lettered := not letters.is_empty() and _mask_at(letters, k, cols, rows - 1 - r)
			if not seats.is_empty():
				var sc: Color = seats[1] if lettered else seats[0]
				crowd.seat(Transform3D(look, p + Vector3(0.0, 0.2, 0.0) - facing * 0.15), sc)
			# Donde va el nombre, las butacas quedan vacías (se lee desde la tele).
			if lettered:
				continue
			if rng.randf() < fill * GameSettings.crowd_factor():
				var b := look.rotated(Vector3.UP, rng.randf_range(-0.15, 0.15))
				var fc: Color = fans[rng.randi() % fans.size()]
				crowd.person(Transform3D(b, p), Color(fc.r, fc.g, fc.b, rng.randf()))


## Máscara de letras de 5 filas (fuente de 3 x 5) para escribir en las butacas.
const FONT := {
	"A": ["111", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
	"C": ["111", "100", "100", "100", "111"], "D": ["110", "101", "101", "101", "110"],
	"E": ["111", "100", "110", "100", "111"], "F": ["111", "100", "110", "100", "100"],
	"G": ["111", "100", "101", "101", "111"], "H": ["101", "101", "111", "101", "101"],
	"I": ["111", "010", "010", "010", "111"], "J": ["001", "001", "001", "101", "111"],
	"K": ["101", "101", "110", "101", "101"], "L": ["100", "100", "100", "100", "111"],
	"M": ["101", "111", "111", "101", "101"], "N": ["111", "101", "101", "101", "101"],
	"O": ["111", "101", "101", "101", "111"], "P": ["111", "101", "111", "100", "100"],
	"Q": ["111", "101", "101", "111", "001"], "R": ["111", "101", "110", "101", "101"],
	"S": ["111", "100", "111", "001", "111"], "T": ["111", "010", "010", "010", "010"],
	"U": ["101", "101", "101", "101", "111"], "V": ["101", "101", "101", "101", "010"],
	"W": ["101", "101", "111", "111", "101"], "X": ["101", "101", "010", "101", "101"],
	"Y": ["101", "101", "010", "010", "010"], "Z": ["111", "001", "010", "100", "111"],
	" ": ["000", "000", "000", "000", "000"],
}


## Columnas de la palabra (cada columna: 5 bits de arriba a abajo).
static func _text_mask(text: String, rows: int) -> Array:
	if rows < 7:
		return []
	var cols: Array = []
	for ch in text.substr(0, 8):
		var g: Array = FONT.get(ch, FONT[" "])
		for cx in 3:
			var col := []
			for cy in 5:
				col.append(String(g[cy])[cx] == "1")
			cols.append(col)
		cols.append([false, false, false, false, false])
	return cols


## ¿La butaca (columna k de `cols`, fila contada desde arriba) es parte de una letra?
## Las letras ocupan dos butacas de ancho por cada píxel (una si no entra),
## centradas, en las filas 2 a 6 desde arriba.
static func _mask_at(mask: Array, k: int, cols: int, row_from_top: int) -> bool:
	var cy := row_from_top - 2
	if cy < 0 or cy > 4:
		return false
	var px := 2 if mask.size() * 2 <= cols else 1
	var w := mask.size() * px
	var start := (cols - w) / 2
	var cx := k - start
	if cx < 0 or cx >= w:
		return false
	return bool(mask[cx / px][cy])


## Carteles bajos alrededor de la cancha (detrás de los arcos y del lado de
## la tribuna). `led`: carteles que brillan (pabellón).
static func _boards(root: Node3D, hl: float, hw: float, colors: Array, home: TeamData, led: bool) -> void:
	var text := home.team_name.to_upper() if home != null else "VIRTUAL ELEVEN"
	var accent := home.color.lightened(0.4) if home != null else Color(0.9, 0.8, 0.3)
	var i := 0
	for side: int in [-1, 1]:
		var x: float = side * (hl + 2.2)
		var z := -hw + 1.0
		while z < hw - 1.0:
			_board(root, Vector3(x, 0.4, z + 1.5), Vector3(0.12, 0.8, 3.0), colors[i % colors.size()], text, side, led, accent)
			z += 3.2
			i += 1
	var x2 := -hl + 1.0
	while x2 < hl - 1.0:
		_board(root, Vector3(x2 + 2.0, 0.4, -hw - 1.6), Vector3(4.0, 0.8, 0.12), colors[i % colors.size()], text, 0, led, accent)
		x2 += 4.2
		i += 1


static func _board(root: Node3D, pos: Vector3, size: Vector3, c: Color, text: String, side: int,
		led := false, accent := Color.WHITE) -> void:
	_box(root, pos, size, _glow(c, 0.5) if led else _mat(c, 0.5), false)
	var col := accent if led else (Color.WHITE if c.get_luminance() < 0.55 else Color(0.08, 0.1, 0.14))
	var l := _label(root, text, pos, 64, 0.004, col)
	if side == 0:
		l.position = pos + Vector3(0.0, 0.0, size.z * 0.5 + 0.01)
	else:
		l.position = pos + Vector3(-side * (size.x * 0.5 + 0.01), 0.0, 0.0)
		l.rotation.y = -side * PI * 0.5


## Bancos de suplentes y mesa del cronometrista, del lado de la cámara.
static func _benches(root: Node3D, hw: float) -> void:
	var seat := _mat(Color(0.2, 0.22, 0.26), 0.6)
	var table := _mat(Color(0.85, 0.85, 0.82), 0.6)
	var z := hw + 2.6
	for xs: int in [-1, 1]:
		_box(root, Vector3(xs * 7.5, 0.25, z), Vector3(5.0, 0.5, 0.6), seat)
		_box(root, Vector3(xs * 7.5, 0.75, z + 0.32), Vector3(5.0, 1.0, 0.08), seat)
	_box(root, Vector3(0.0, 0.4, z - 0.4), Vector3(3.0, 0.8, 0.8), table)


## Marcador de pared (caja con números que brillan), mirando a la cancha.
static func _wall_scoreboard(root: Node3D, pos: Vector3, main: Color) -> void:
	_box(root, pos, Vector3(7.0, 2.4, 0.3), _mat(Color(0.06, 0.06, 0.07), 0.4), false)
	_box(root, pos + Vector3(0.0, 1.25, 0.0), Vector3(7.2, 0.12, 0.34), _mat(main, 0.5), false)
	var sb := Scoreboard.new()
	sb.position = pos + Vector3(0.0, 0.0, 0.17)
	sb.accent = main
	root.add_child(sb)


## Gente y butacas de una tribuna, juntadas en dos MultiMesh.
class Crowd:
	var people: Array[Transform3D] = []
	var custom: Array[Color] = []
	var seats: Array[Transform3D] = []
	var seat_colors: Array[Color] = []

	func person(t: Transform3D, c: Color) -> void:
		people.append(t)
		custom.append(c)

	func seat(t: Transform3D, c: Color) -> void:
		seats.append(t)
		seat_colors.append(c)

	func commit(root: Node3D, node_name: String) -> void:
		var node := Node3D.new()
		node.name = node_name
		root.add_child(node)
		if not seats.is_empty():
			var bm := BoxMesh.new()
			bm.size = Vector3(0.46, 0.4, 0.42)
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			sm.roughness = 0.45
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = bm
			mm.instance_count = seats.size()
			for i in seats.size():
				mm.set_instance_transform(i, seats[i])
				mm.set_instance_color(i, seat_colors[i])
			var mi := MultiMeshInstance3D.new()
			mi.name = "Seats"
			mi.multimesh = mm
			mi.material_override = sm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(mi)
		if people.is_empty():
			return
		if StadiumBuilder.crowd_material == null:
			StadiumBuilder.crowd_material = ShaderMaterial.new()
			StadiumBuilder.crowd_material.shader = preload("res://scripts/stadium/crowd.gdshader")
		var pm := MultiMesh.new()
		pm.transform_format = MultiMesh.TRANSFORM_3D
		pm.use_custom_data = true
		pm.mesh = StadiumBuilder._person_mesh()
		pm.instance_count = people.size()
		for i in people.size():
			pm.set_instance_transform(i, people[i])
			pm.set_instance_custom_data(i, custom[i])
		var crowd := MultiMeshInstance3D.new()
		crowd.name = "Crowd"
		crowd.multimesh = pm
		crowd.material_override = StadiumBuilder.crowd_material
		crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(crowd)


## Marcador vivo: siglas, goles, reloj y faltas acumuladas del partido.
## Busca el MatchController hacia arriba; sin partido muestra 0-0.
class Scoreboard:
	extends Node3D
	var accent := Color(0.9, 0.8, 0.3)
	var _names: Array[Label3D] = []
	var _score: Label3D
	var _clock: Label3D
	var _fouls: Label3D
	var _match: Node

	func _ready() -> void:
		var amber := Color(1.0, 0.72, 0.2)
		for i in 2:
			_names.append(GymBuilder._label(self, "LOC" if i == 0 else "VIS", Vector3(-2.4 if i == 0 else 2.4, 0.6, 0.0),
				96, 0.006, accent.lightened(0.5)))
		_score = GymBuilder._label(self, "0 - 0", Vector3(0.0, 0.45, 0.0), 160, 0.008, amber)
		_clock = GymBuilder._label(self, "00:00", Vector3(0.0, -0.55, 0.0), 110, 0.007, Color(1.0, 0.35, 0.25))
		_fouls = GymBuilder._label(self, "", Vector3(0.0, -0.95, 0.0), 56, 0.006, Color(0.85, 0.85, 0.85))
		var n := get_parent()
		while n != null and not n is MatchController:
			n = n.get_parent()
		_match = n

	func _process(_dt: float) -> void:
		if _match == null or _match.clock == null:
			return
		var t: Array = _match.teams
		if t.size() < 2:
			return
		if _names[0].text == "LOC":
			for i in 2:
				_names[i].text = String(t[i].short_name).to_upper()
		_score.text = "%d - %d" % [t[0].score, t[1].score]
		_clock.text = _match.clock.display()
		if _match.stats.has("acc_fouls"):
			var acc: Array = _match.stats["acc_fouls"]
			_fouls.text = "FALTAS  %d  ·  %d" % [acc[0], acc[1]]
