class_name KitTemplate
extends RefCounted
## Plantilla PNG del uniforme (docs/KIT_UV.md): una imagen cuadrada con las
## piezas de la ropa (torso, mangas, short y medias) en sus lugares. El
## Editor la exporta pintada con los colores y el diseño actuales, se edita
## en cualquier programa de dibujo y se vuelve a importar: el juego la usa en
## lugar del diseño por código (el número y el escudo van encima).

const SIZE := 1024
const BORDER := Color(0.2, 0.2, 0.22)


## Imagen del uniforme con los colores y el diseño (TeamData.pattern).
static func render(shirt: Color, shorts: Color, socks: Color, pattern: int, shirt2: Color, size: int = SIZE,
		guides: bool = true) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.85, 0.85))
	var s := float(size)
	for y in size:
		var v := (y + 0.5) / s
		for x in size:
			var u := (x + 0.5) / s
			img.set_pixel(x, y, _pixel(u, v, shirt, shorts, socks, pattern, shirt2))
	if guides:
		for r in [ClassicBody.UV_TORSO, ClassicBody.UV_SLEEVE_L, ClassicBody.UV_SLEEVE_R, ClassicBody.UV_SHORTS_L,
				ClassicBody.UV_SHORTS_R, ClassicBody.UV_SOCK_L, ClassicBody.UV_SOCK_R]:
			_rect(img, r, BORDER)
	return img


static func _in(r: Array, u: float, v: float) -> bool:
	return u >= r[0] and u < r[2] and v >= r[1] and v < r[3]


static func _pixel(u: float, v: float, shirt: Color, shorts: Color, socks: Color, pattern: int, p2: Color) -> Color:
	if _in(ClassicBody.UV_TORSO, u, v):
		# Torso: u 0..0.5 = la vuelta (espalda en 0.125, pecho en 0.375);
		# v 0..0.5 = del cuello a la cintura.
		var tu := u / 0.5
		var tv := v / 0.5
		var k := false
		match pattern:
			1:
				k = int(tu * 16.0) % 2 == 1
			2:
				k = fmod(tu * 32.0, 1.0) < 0.3
			3:
				k = int(tv * 8.0) % 2 == 1
			4:
				k = tu > 0.25 and tu < 0.75
			5:
				var fu := (tu - 0.5) * 4.0 # frente: -1..1
				k = absf(fu) < 1.0 and absf(fu * 0.6 - (tv - 0.5)) < 0.08
			6:
				k = tv > 0.32 and tv < 0.46
			7:
				# V en el pecho: de los hombros (arriba) al centro (más abajo).
				var fu := (tu - 0.75) * 4.0
				k = absf(fu) < 1.0 and absf(tv - (0.35 - absf(fu) * 0.3)) < 0.04
			8:
				k = (int(tu * 20.0) + int(tv * 10.0)) % 2 == 1
		return p2 if k else shirt
	if _in(ClassicBody.UV_SLEEVE_L, u, v) or _in(ClassicBody.UV_SLEEVE_R, u, v):
		if pattern in [1, 2]:
			return p2 if int(u * 64.0) % 2 == 1 else shirt
		if pattern == 3:
			return p2 if int(v * 32.0) % 2 == 1 else shirt
		return shirt
	if _in(ClassicBody.UV_SHORTS_L, u, v) or _in(ClassicBody.UV_SHORTS_R, u, v):
		return shorts
	if _in(ClassicBody.UV_SOCK_L, u, v) or _in(ClassicBody.UV_SOCK_R, u, v):
		# Franja arriba (como las medias del juego).
		var sv := (v - 0.5) / 0.25
		return (p2 if pattern > 0 else shirt.darkened(0.25)) if sv < 0.12 else socks
	return Color(0.85, 0.85, 0.85)


static func _rect(img: Image, r: Array, c: Color) -> void:
	var s := img.get_width()
	var x0 := int(r[0] * s)
	var y0 := int(r[1] * s)
	var x1 := mini(int(r[2] * s), s - 1)
	var y1 := mini(int(r[3] * s), s - 1)
	for x in range(x0, x1 + 1):
		img.set_pixel(x, y0, c)
		img.set_pixel(x, y1, c)
	for y in range(y0, y1 + 1):
		img.set_pixel(x0, y, c)
		img.set_pixel(x1, y, c)


# --- Kits de Dream League Soccer -------------------------------------------------------------

## Piezas de la plantilla de DLS (512×512; otras medidas se escalan):
## [región nuestra (UV), rectángulo en DLS (x0, y0, x1, y1), modo, tramos].
## Modos: "flat" (u = x, v = y), "mirror" (u = x al revés), "sleeve_l" /
## "sleeve_r" (la manga va a lo ancho: del hombro al puño en x).
## Tramos (torso): [[t, y en DLS], ...] para repartir la altura: el torso del
## modelo va de la cintura (t = 0) a la línea de los hombros (t ≈ 0.62, lo
## que se ve de frente) y de ahí al cuello (t = 1, la parte de arriba).
## Lo que DLS tiene de más (costados, segunda pieza de manga, logos) no se usa.
const DLS_PIECES := [
	[[0.25, 0.0, 0.5, 0.5], [184, 162, 328, 376], "mirror", [[0.0, 376], [0.62, 186], [1.0, 140]]], # pecho
	[[0.0, 0.0, 0.25, 0.5], [184, 2, 328, 116], "flat", [[0.0, 2], [0.62, 100], [1.0, 128]]], # espalda
	[[0.5, 0.0, 0.75, 0.25], [8, 12, 152, 118], "sleeve_l", []],
	[[0.75, 0.0, 1.0, 0.25], [360, 12, 504, 118], "sleeve_r", []],
	[[0.0, 0.5, 0.25, 0.75], [12, 388, 214, 506], "flat", []], # short izquierdo
	[[0.25, 0.5, 0.5, 0.75], [298, 388, 500, 506], "flat", []], # short derecho
	[[0.5, 0.5, 0.75, 0.75], [14, 276, 150, 374], "flat", []], # media izquierda
	[[0.75, 0.5, 1.0, 0.75], [362, 276, 498, 374], "flat", []], # media derecha
]


## y en DLS para la altura t (0..1) de una pieza con tramos.
static func _dls_y(spans: Array, t: float) -> float:
	for i in range(1, spans.size()):
		if t <= float(spans[i][0]) or i == spans.size() - 1:
			var a: Array = spans[i - 1]
			var b: Array = spans[i]
			return lerpf(float(a[1]), float(b[1]), clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0))
	return float(spans[0][1])


## Convierte una plantilla de kit de Dream League Soccer (512×512, también
## las de First Touch Soccer con la misma forma) a la plantilla del juego.
static func from_dls(src: Image, size: int = SIZE) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.85, 0.85))
	var s := src.duplicate() as Image
	if s.is_compressed():
		s.decompress()
	s.convert(Image.FORMAT_RGBA8)
	var kx := s.get_width() / 512.0
	var ky := s.get_height() / 512.0
	for piece in DLS_PIECES:
		var dst: Array = piece[0]
		var r: Array = piece[1]
		var mode: String = piece[2]
		var spans: Array = piece[3]
		var x0 := int(dst[0] * size)
		var y0 := int(dst[1] * size)
		var x1 := int(dst[2] * size)
		var y1 := int(dst[3] * size)
		for y in range(y0, y1):
			var t := (y - y0 + 0.5) / float(y1 - y0) # v dentro de la pieza
			for x in range(x0, x1):
				var q := (x - x0 + 0.5) / float(x1 - x0) # u dentro de la pieza
				var sx := 0.0
				var sy := 0.0
				match mode:
					"mirror":
						sx = lerpf(r[2], r[0], q)
						sy = _dls_y(spans, t) if not spans.is_empty() else lerpf(r[1], r[3], t)
					"sleeve_l":
						sx = lerpf(r[2], r[0], t)
						sy = lerpf(r[1], r[3], q)
					"sleeve_r":
						sx = lerpf(r[0], r[2], t)
						sy = lerpf(r[1], r[3], q)
					_:
						sx = lerpf(r[0], r[2], q)
						sy = _dls_y(spans, t) if not spans.is_empty() else lerpf(r[1], r[3], t)
				var c := s.get_pixel(clampi(int(sx * kx), 0, s.get_width() - 1), clampi(int(sy * ky), 0, s.get_height() - 1))
				c.a = 1.0
				img.set_pixel(x, y, c)
	return img


## Carga una plantilla (PNG o JPG) como textura, o null.
static func load_texture(file: String) -> Texture2D:
	if not FileAccess.file_exists(file):
		return null
	var img := Image.load_from_file(file)
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	tex.resource_name = file.get_file()
	return tex
