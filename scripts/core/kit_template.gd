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


## Carga una plantilla (PNG o JPG) como textura, o null.
static func load_texture(file: String) -> Texture2D:
	if not FileAccess.file_exists(file):
		return null
	var img := Image.load_from_file(file)
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
