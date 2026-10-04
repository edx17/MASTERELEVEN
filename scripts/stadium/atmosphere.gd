class_name Atmosphere
extends Node3D
## Luz, cielo y clima del partido según MatchConditions (sólo presentación;
## los efectos en el juego los aplica MatchConditions.apply_to()).
##   Horario: mañana (sol bajo y frío), tarde (sol alto), atardecer (sol
##     naranja rasante y luces del estadio a media potencia), noche (cuatro
##     torres de luz que dan las sombras múltiples de un partido nocturno).
##   Clima: nublado (luz difusa), lluvia (gotas, niebla, césped que brilla),
##     nieve (copos, luz blanca, césped nevado). El viento inclina la lluvia
##     y la nieve y mueve los banderines.

const FLOOD_HEIGHT := 46.0

var conditions: MatchConditions
var environment: Environment
var sun: DirectionalLight3D
var floodlights: Array[SpotLight3D] = []
var precipitation: GPUParticles3D
var _camera: MatchCamera
var _flags: Array[Node3D] = []
var _match: MatchController
## Marcas de barridas en el césped mojado / nevado (las más viejas se borran).
var _marks: Array[Decal] = []
const MAX_MARKS := 30
static var _mark_tex: Texture2D
var _t := 0.0


func setup(p_conditions: MatchConditions) -> void:
	conditions = p_conditions
	_build_environment()
	_build_sun()
	if conditions.time_of_day == MatchConditions.TimeOfDay.NIGHT or conditions.time_of_day == MatchConditions.TimeOfDay.DUSK:
		_build_floodlights()
	match conditions.weather:
		MatchConditions.Weather.RAIN:
			precipitation = _build_precipitation(false)
		MatchConditions.Weather.SNOW:
			precipitation = _build_precipitation(true)


## La cámara (para que la lluvia caiga donde se mira) y los banderines.
func attach(camera: MatchCamera, world: Node) -> void:
	_camera = camera
	_match = world as MatchController
	if _match != null and (conditions.wetness >= 0.3 or conditions.is_snow()):
		for p in _match.all_players():
			p.slide_started.connect(_on_slide.bind(p))
	for n in world.find_children("CornerFlag*", "", true, false):
		_flags.append(n as Node3D)


## Parámetros del césped según el clima (lo mojado brilla; la nieve lo cubre).
func grass_params() -> Dictionary:
	return {
		"wetness": conditions.wetness,
		"snow": SNOW_START if conditions.is_snow() else 0.0,
		# Césped gastado: opción del partido; en el Club House, siempre.
		"worn": GameSettings.pitch_wear == 1 or GameSettings.training,
	}


## Nieve acumulada según el minuto del partido (segundos de juego 0..5400).
const SNOW_START := 0.3
const SNOW_END := 1.0
static func snow_level(total_game_seconds: float) -> float:
	return lerpf(SNOW_START, SNOW_END, clampf(total_game_seconds / (MatchClock.HALF_GAME_SECONDS * 2.0), 0.0, 1.0))


func _process(dt: float) -> void:
	_t += dt
	if not _sliding.is_empty():
		_update_slide_marks(dt)
	if precipitation != null and _camera != null:
		precipitation.global_position = precipitation_origin(_camera)
	# Nieve: los surcos de las líneas se van tapando durante cada tiempo (en el
	# entretiempo se vuelven a limpiar: el reloj del tiempo vuelve a cero).
	# La nieve se acumula durante todo el partido (arranca en manchas y va
	# tapando el verde); en el entretiempo sólo se limpian las líneas.
	if conditions.is_snow() and _match != null and _match.clock != null and PitchBuilder.grass_material != null:
		var progress := clampf(_match.clock.game_seconds / MatchClock.HALF_GAME_SECONDS, 0.0, 1.0)
		PitchBuilder.grass_material.set_shader_parameter("groove_clear", 1.0 - 0.85 * progress)
		PitchBuilder.grass_material.set_shader_parameter("snow", snow_level(_match.clock.total_game_seconds()))
	# Banderines: flamean hacia donde sopla el viento.
	if not _flags.is_empty():
		var w := conditions.wind_vector()
		var strength := clampf(w.length() / 10.0, 0.05, 1.0)
		var yaw := atan2(-w.z, w.x) if w.length() > 0.2 else 0.0
		for i in _flags.size():
			var fl := _flags[i]
			fl.rotation.y = yaw + sin(_t * (3.0 + 6.0 * strength) + i) * (0.15 + 0.35 * strength)


# --- Cielo, ambiente y color --------------------------------------------------

func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	environment = Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	var cloudy := conditions.weather != MatchConditions.Weather.CLEAR
	var top := Color(0.24, 0.42, 0.72)
	var horizon := Color(0.66, 0.72, 0.8)
	var ambient := 0.8
	var exposure := 1.0
	match conditions.time_of_day:
		MatchConditions.TimeOfDay.MORNING:
			top = Color(0.3, 0.48, 0.75)
			horizon = Color(0.78, 0.8, 0.82)
			ambient = 0.75
		MatchConditions.TimeOfDay.DUSK:
			top = Color(0.2, 0.25, 0.45)
			horizon = Color(0.95, 0.55, 0.3)
			ambient = 0.45
			exposure = 1.05
		MatchConditions.TimeOfDay.NIGHT:
			top = Color(0.01, 0.015, 0.04)
			horizon = Color(0.05, 0.06, 0.1)
			ambient = 0.12
			exposure = 1.0
	if cloudy:
		var gray := Color(0.42, 0.44, 0.47) if conditions.time_of_day != MatchConditions.TimeOfDay.NIGHT else Color(0.03, 0.03, 0.04)
		top = top.lerp(gray, 0.75)
		horizon = horizon.lerp(gray.lightened(0.15), 0.7)
		ambient += 0.15
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_bottom_color = top.darkened(0.6)
	sky_mat.ground_horizon_color = horizon.darkened(0.3)
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	# Cielo fotográfico (HDRI) si está en assets/skies/ para estas condiciones.
	var photo := SkyTextures.for_conditions(conditions, randi())
	if photo != null:
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = photo
		pano.energy_multiplier = 1.0 if not cloudy else 0.9
		sky.sky_material = pano
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = ambient
	# Relleno parejo: la parte que no viene del cielo no depende de cuánto
	# cielo "ve" cada punto, así lo que queda bajo un techo o en la sombra de
	# una tribuna no se va al negro (de día rebota mucha luz del césped y de
	# las tribunas).
	environment.ambient_light_sky_contribution = 0.6 if conditions.time_of_day != MatchConditions.TimeOfDay.NIGHT else 0.85
	environment.ambient_light_color = horizon.lerp(Color(0.62, 0.66, 0.6), 0.5)
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = exposure
	environment.tonemap_white = 6.0
	# Oclusión ambiental: asienta a los jugadores y da volumen a las tribunas.
	environment.ssao_enabled = true
	environment.ssao_radius = 1.0
	environment.ssao_intensity = 0.9
	environment.ssao_detail = 0.6
	# Iluminación global (Forward+): la luz rebota en el césped y las tribunas.
	environment.sdfgi_enabled = true
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_energy = 1.25
	environment.sdfgi_bounce_feedback = 0.7
	environment.glow_enabled = true
	environment.glow_intensity = 0.35 if conditions.time_of_day == MatchConditions.TimeOfDay.NIGHT else 0.2
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.1
	# Más contraste y algo de "película" para que no se vea plano.
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.1
	environment.adjustment_saturation = 1.0 if not cloudy else 0.85
	environment.adjustment_brightness = 0.97
	# Bruma de distancia (más con lluvia o nieve): da profundidad al estadio.
	environment.fog_enabled = true
	environment.fog_light_color = horizon.lerp(Color(0.7, 0.72, 0.75), 0.3)
	environment.fog_density = 0.0015
	environment.fog_sky_affect = 0.3
	match conditions.weather:
		MatchConditions.Weather.RAIN:
			environment.fog_density = 0.0028
		MatchConditions.Weather.SNOW:
			environment.fog_density = 0.002
			environment.fog_light_color = Color(0.82, 0.84, 0.88)
	env_node.environment = environment
	add_child(env_node)


func _build_sun() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 170.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.2
	# La sombra deja pasar parte de la luz (la que rebota en el cielo, el
	# césped y las tribunas): sombra marcada pero nunca negra.
	# (Más suave desde B10: la sombra de un techo no oscurece media cancha.)
	sun.shadow_opacity = 0.55
	# Tamaño aparente del sol: la sombra de un techo alto tiene el borde
	# difuso (penumbra) y la de un jugador queda nítida.
	sun.light_angular_distance = 1.6
	# Sol del lado de la cámara (+Z) y algo lateral: los jugadores quedan
	# iluminados de frente; la altura y el color dependen del horario.
	var elev := -45.0
	var yaw := -25.0
	var color := Color(1.0, 0.95, 0.86)
	var energy := 1.25
	match conditions.time_of_day:
		MatchConditions.TimeOfDay.MORNING:
			elev = -28.0
			yaw = 35.0
			color = Color(1.0, 0.92, 0.8)
			energy = 1.1
		MatchConditions.TimeOfDay.DUSK:
			elev = -11.0
			yaw = -55.0
			color = Color(1.0, 0.62, 0.36)
			energy = 1.0
		MatchConditions.TimeOfDay.NIGHT:
			# Luna: apenas un tono frío; la luz la dan las torres.
			elev = -55.0
			color = Color(0.6, 0.7, 1.0)
			energy = 0.06
			sun.shadow_enabled = false
	match conditions.weather:
		MatchConditions.Weather.CLOUDY:
			energy *= 0.45
			sun.light_angular_distance = 4.0
		MatchConditions.Weather.RAIN:
			energy *= 0.3
			sun.light_angular_distance = 6.0
		MatchConditions.Weather.SNOW:
			energy *= 0.4
			sun.light_angular_distance = 5.0
			color = color.lerp(Color(0.85, 0.9, 1.0), 0.5)
		_:
			sun.light_angular_distance = 0.6
	sun.rotation_degrees = Vector3(elev, yaw, 0.0)
	sun.light_color = color
	sun.light_energy = energy
	add_child(sun)


# --- Noche: torres de luz -----------------------------------------------------

## Capa de la cancha y el estadio (la 2); los jugadores y la pelota quedan en
## la 1, la única que proyecta sombras de los reflectores.
const SCENERY_LAYER := 2
const ACTORS_LAYER := 1


static func move_to_scenery_layer(root: Node) -> void:
	for n in root.find_children("*", "VisualInstance3D", true, false):
		(n as VisualInstance3D).layers = SCENERY_LAYER
	if root is VisualInstance3D:
		(root as VisualInstance3D).layers = SCENERY_LAYER


func _build_floodlights() -> void:
	var night := conditions.time_of_day == MatchConditions.TimeOfDay.NIGHT
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1.0, 1.0, 0.95)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.98, 0.9)
	lamp_mat.emission_energy_multiplier = 6.0 if night else 2.5
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.3, 0.31, 0.33)
	pole_mat.metallic = 0.6
	pole_mat.roughness = 0.5
	# Ubicación según el estadio: torres con mástil por fuera, o reflectores
	# colgados del techo en las esquinas.
	var flood: Array = StadiumStyles.flood_layout(StadiumStyles.current)
	var fx: float = flood[0]
	var fz: float = flood[1]
	var height: float = flood[2]
	var has_pole: bool = flood[3]
	var i := 0
	for xs: int in [-1, 1]:
		for zs: int in [-1, 1]:
			var base := Vector3(xs * fx, 0.0, zs * fz)
			# Mástil y panel de reflectores.
			if has_pole:
				var pole := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.6
				cyl.bottom_radius = 1.0
				cyl.height = height
				pole.mesh = cyl
				pole.material_override = pole_mat
				pole.position = base + Vector3(0.0, height * 0.5, 0.0)
				add_child(pole)
			var panel := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(10.0, 6.0, 0.6) if has_pole else Vector3(14.0, 1.6, 0.6)
			panel.mesh = box
			panel.material_override = lamp_mat
			panel.position = base + Vector3(0.0, height + 2.0, 0.0)
			add_child(panel)
			panel.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
			panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Reflector: apunta al cuarto de cancha opuesto (cruzan las luces).
			var spot := SpotLight3D.new()
			spot.position = base + Vector3(0.0, height + 2.0, 0.0)
			spot.spot_range = 240.0
			# Más abierto y parejo: entre las cuatro torres cubren toda la cancha.
			spot.spot_angle = 52.0
			spot.spot_attenuation = 0.25
			spot.light_energy = (3.2 if night else 1.5)
			spot.light_color = Color(1.0, 0.98, 0.92)
			# Sombras sólo en dos torres (costo): igual se ven sombras cruzadas.
			spot.shadow_enabled = night and i < 2
			# Poco brillo especular: si no, el pasto húmedo se vuelve un espejo.
			spot.light_specular = 0.25
			# Sombras de los jugadores tenues (con varias torres casi no se ven).
			spot.shadow_opacity = 0.45
			spot.shadow_caster_mask = ACTORS_LAYER
			add_child(spot)
			spot.look_at(Vector3(-xs * 8.0, 0.0, -zs * 6.0), Vector3.UP)
			floodlights.append(spot)
			i += 1


# --- Marcas de barridas --------------------------------------------------------

## Barrida con el césped mojado o nevado: queda una marca de barro (o de
## pasto a la vista, con nieve) a lo largo del deslizamiento.
## Barrida en curso: la marca nace cuando el cuerpo toca el piso y se va
## alargando detrás del jugador mientras se desliza.
## {jugador: {"decal", "start", "dir", "t"}}
var _sliding := {}
const MARK_TOUCHDOWN := 0.1

func _on_slide(p: Footballer) -> void:
	_sliding[p] = {"decal": null, "start": Vector3.ZERO, "dir": Vector3(p.facing.x, 0.0, p.facing.z).normalized(), "t": 0.0}


func _update_slide_marks(dt: float) -> void:
	for p: Footballer in _sliding.keys():
		var s: Dictionary = _sliding[p]
		s["t"] += dt
		var sliding := p.state == Footballer.State.SLIDING
		if s["decal"] == null:
			if not sliding:
				_sliding.erase(p)
				continue
			if s["t"] < MARK_TOUCHDOWN:
				continue
			var d := Decal.new()
			d.texture_albedo = _mark_texture()
			d.modulate = Color(0.35, 0.27, 0.17, 0.85) if not conditions.is_snow() else Color(0.28, 0.33, 0.2, 0.9)
			d.cull_mask = 1
			add_child(d)
			s["decal"] = d
			s["start"] = p.flat_pos()
			_marks.append(d)
			if _marks.size() > MAX_MARKS:
				var old: Decal = _marks.pop_front()
				for other in _sliding.values():
					if other["decal"] == old:
						other["decal"] = null
				old.queue_free()
		var decal: Decal = s["decal"]
		if decal == null:
			_sliding.erase(p)
			continue
		# Desde donde tocó el piso hasta debajo de la cadera (detrás de los pies).
		var dir: Vector3 = s["dir"]
		var start: Vector3 = s["start"]
		var end := p.flat_pos() - dir * 0.25
		var length := maxf((end - start).dot(dir), 0.05)
		decal.size = Vector3(0.7, 0.6, length)
		decal.global_position = start + dir * length * 0.5 + Vector3.UP * 0.1
		decal.global_basis = Basis.looking_at(dir, Vector3.UP)
		if not sliding:
			_sliding.erase(p)


static func _mark_texture() -> Texture2D:
	if _mark_tex != null:
		return _mark_tex
	var w := 32
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in h:
		for x in w:
			var u := absf(x / float(w - 1) * 2.0 - 1.0)
			var v := y / float(h - 1)
			# Borde suave a los costados y en las puntas, con algo de ruido.
			var a := (1.0 - smoothstep(0.55, 1.0, u)) * smoothstep(0.0, 0.15, v) * (1.0 - smoothstep(0.85, 1.0, v))
			a *= 0.75 + 0.25 * rng.randf()
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_mark_tex = ImageTexture.create_from_image(img)
	return _mark_tex


# --- Lluvia y nieve -----------------------------------------------------------

## Gota: dos tiras finas cruzadas, de 0,5 m a lo largo del eje Y.
static func _rain_streak() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.008
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var a := -axis * w
		var b := axis * w
		var q := [a + Vector3(0, -0.25, 0), b + Vector3(0, -0.25, 0), b + Vector3(0, 0.25, 0), a + Vector3(0, 0.25, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(q[i])
	return st.commit()


## Dónde se emite la lluvia/nieve. En juego, sobre el foco de la cámara y por
## debajo de su altura (si no, pasan pegadas al lente). En las tomas de la
## presentación el foco no se actualiza y la cámara puede estar más alta que
## el emisor (el giro del menú va a 16 m): se emite delante de la cámara y
## siempre por encima de ella, así la lluvia cae frente a la toma.
static func precipitation_origin(cam: MatchCamera) -> Vector3:
	if not cam.cinematic:
		var f := cam._focus
		return Vector3(f.x, 13.0, f.z + 4.0)
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var c := cam.global_position + fwd * 20.0
	return Vector3(c.x, maxf(13.0, cam.global_position.y + 4.0), c.z)

func _build_precipitation(snow: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 7000 if snow else 6000
	# Caen desde 13 m: la lluvia tarda ~0,8 s, la nieve ~4,5 s.
	p.lifetime = 4.5 if snow else 0.9
	p.preprocess = p.lifetime
	p.visibility_aabb = AABB(Vector3(-50, -30, -40), Vector3(100, 40, 80))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(45.0, 1.0, 34.0)
	var wind := conditions.wind_vector()
	if snow:
		# Copos que caen de verdad (~2,5-3,5 m/s) y derivan con el viento,
		# con un vaivén leve (antes caían a 1-2 m/s con mucha turbulencia y
		# parecían quietos frente a la cámara).
		var drift := Vector3(wind.x * 0.6, -3.0, wind.z * 0.6)
		m.direction = drift.normalized()
		m.spread = 6.0
		m.initial_velocity_min = drift.length() * 0.85
		m.initial_velocity_max = drift.length() * 1.15
		m.gravity = Vector3.ZERO
		m.turbulence_enabled = true
		m.turbulence_noise_strength = 0.35
		m.turbulence_noise_scale = 6.0
		m.scale_min = 0.5
		m.scale_max = 1.0
	else:
		# Gotas a ~15 m/s; el viento las corre de costado a su misma velocidad
		# (con viento fuerte caen bien en diagonal). Sin gravedad extra: ya
		# llegan a la velocidad final.
		var fall := Vector3(wind.x, -15.0, wind.z)
		m.direction = fall.normalized()
		m.spread = 2.0
		m.initial_velocity_min = fall.length() * 0.92
		m.initial_velocity_max = fall.length() * 1.08
		m.gravity = Vector3.ZERO
		m.particle_flag_align_y = true
	p.process_material = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh: Mesh
	if snow:
		var flake := SphereMesh.new()
		flake.radius = 0.045
		flake.height = 0.09
		flake.radial_segments = 6
		flake.rings = 3
		mesh = flake
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
	else:
		# Dos planos cruzados a lo largo de la caída (orientados por la
		# velocidad): se ven desde cualquier lado, sin el giro del billboard.
		mesh = _rain_streak()
		mat.albedo_color = Color(0.82, 0.84, 0.88, 0.2)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = mat
	else:
		(mesh as ArrayMesh).surface_set_material(0, mat)
	p.draw_pass_1 = mesh
	add_child(p)
	return p
