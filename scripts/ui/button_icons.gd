class_name ButtonIcons
extends RefCounted
## Íconos de los botones del mando dibujados en el juego (genéricos, sin
## marcas): cruz, círculo, cuadrado y triángulo de colores, y los gatillos
## L1/R1/L2/R2. En los textos se escriben como {X} {O} {SQ} {TRI} {L1} {R1}
## {L2} {R2} y `fill()` los pone como imágenes dentro de un RichTextLabel.

const IDS := ["X", "O", "SQ", "TRI", "L1", "R1", "L2", "R2"]
const NAMES := {"X": "Cruz", "O": "Círculo", "SQ": "Cuadrado", "TRI": "Triángulo",
	"L1": "L1", "R1": "R1", "L2": "L2", "R2": "R2"}
const COLORS := {"X": Color(0.5, 0.65, 1.0), "O": Color(1.0, 0.42, 0.42),
	"SQ": Color(0.95, 0.55, 0.85), "TRI": Color(0.3, 0.88, 0.72)}
## Letras de 5x7 para los gatillos.
const GLYPHS := {
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
}
const S := 64 # se dibuja grande y se achica (bordes suaves)

static var _cache := {}


## Textura del botón `id` (una de IDS), con `height` píxeles de alto.
static func texture(id: String, height: int = 24) -> Texture2D:
	var key := "%s_%d" % [id, height]
	if _cache.has(key):
		return _cache[key]
	var img := _draw(id)
	img.resize(int(img.get_width() * height / float(S)), height, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Combinación (p. ej. ["L2", "X"]) en una sola textura, con un "+" entre medio.
static func combo(ids: Array, height: int = 22) -> Texture2D:
	var key := "+".join(ids) + "_%d" % height
	if _cache.has(key):
		return _cache[key]
	var parts: Array[Image] = []
	var w := 0
	for i in ids.size():
		var im := (texture(ids[i], height) as ImageTexture).get_image()
		parts.append(im)
		w += im.get_width() + (8 if i > 0 else 0)
	var out := Image.create(w, height, false, Image.FORMAT_RGBA8)
	var x := 0
	for i in parts.size():
		if i > 0:
			# Signo +.
			var cy := height / 2
			for k in range(1, 6):
				out.set_pixel(x + k, cy, Color.WHITE)
			for k in range(-2, 3):
				out.set_pixel(x + 3, cy + k, Color.WHITE)
			x += 8
		out.blit_rect(parts[i], Rect2i(Vector2i.ZERO, parts[i].get_size()), Vector2i(x, 0))
		x += parts[i].get_width()
	var tex := ImageTexture.create_from_image(out)
	_cache[key] = tex
	return tex


static func _draw(id: String) -> Image:
	var shoulder := id.length() == 2 and (id[0] == "L" or id[0] == "R")
	var w := int(S * 1.5) if shoulder else S
	var img := Image.create(w, S, false, Image.FORMAT_RGBA8)
	var bg := Color(0.1, 0.11, 0.16)
	var rim := Color(0.85, 0.88, 0.95)
	for y in S:
		for x in w:
			var c := Color(0, 0, 0, 0)
			if shoulder:
				# Píldora redondeada.
				var r := S * 0.42
				var cx := clampf(x, r + 2.0, w - r - 2.0)
				var d := Vector2(x - cx, y - S * 0.5).length()
				if d < r:
					c = rim if d > r - 4.0 else bg
			else:
				var d := Vector2(x - S * 0.5, y - S * 0.5).length()
				if d < S * 0.48:
					c = rim if d > S * 0.48 - 4.0 else bg
					var sym := _symbol(id, Vector2(x, y) / S)
					if sym:
						c = COLORS[id]
			img.set_pixel(x, y, c)
	if shoulder:
		# Letras en píxeles grandes, centradas.
		var cell := 5
		var text_w := (5 * 2 + 1) * cell
		var ox := (w - text_w) / 2
		var oy := (S - 7 * cell) / 2
		for gi in 2:
			var rows: Array = GLYPHS[id[gi]]
			for ry in 7:
				for rx in 5:
					if rows[ry][rx] == "1":
						img.fill_rect(Rect2i(ox + (gi * 6 + rx) * cell, oy + ry * cell, cell, cell), Color.WHITE)
	return img


## Si el punto (0..1) pertenece al símbolo del botón.
static func _symbol(id: String, p: Vector2) -> bool:
	var q := p - Vector2(0.5, 0.5)
	const T := 0.055 # medio grosor del trazo
	match id:
		"X":
			if absf(q.x) > 0.2 or absf(q.y) > 0.2:
				return false
			return absf(q.x - q.y) < T * 1.41 or absf(q.x + q.y) < T * 1.41
		"O":
			return absf(q.length() - 0.18) < T
		"SQ":
			var m := maxf(absf(q.x), absf(q.y))
			return absf(m - 0.17) < T
		"TRI":
			# Triángulo con la punta arriba: distancia a cada lado.
			var a := Vector2(0.0, -0.21)
			var b := Vector2(0.2, 0.14)
			var c := Vector2(-0.2, 0.14)
			var d := minf(_seg(q, a, b), minf(_seg(q, b, c), _seg(q, c, a)))
			return d < T
	return false


static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Escribe `text` en `rtl` reemplazando {X}, {O}, {SQ}, ... por los íconos.
static func fill(rtl: RichTextLabel, text: String, height: int = 22, center: bool = false) -> void:
	rtl.clear()
	if center:
		rtl.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	var rest := text
	while true:
		var i := rest.find("{")
		var j := rest.find("}", i) if i >= 0 else -1
		if i < 0 or j < 0:
			break
		var id := rest.substr(i + 1, j - i - 1)
		if not id in IDS:
			rtl.add_text(rest.substr(0, j + 1))
			rest = rest.substr(j + 1)
			continue
		rtl.add_text(rest.substr(0, i))
		rtl.add_image(texture(id, height), 0, height, Color.WHITE, INLINE_ALIGNMENT_CENTER)
		rest = rest.substr(j + 1)
	rtl.add_text(rest)
	if center:
		rtl.pop()


## Texto sin íconos (para logs y tests): {SQ} -> "Cuadrado".
static func plain(text: String) -> String:
	for id in IDS:
		text = text.replace("{%s}" % id, NAMES[id])
	return text


## Espejo con íconos de un Label: el Label queda oculto (el código sigue
## escribiendo su `text`) y esta etiqueta lo muestra con los íconos.
class Mirror:
	extends IconLabel
	var source: Label

	func _process(_dt: float) -> void:
		if source != null:
			show_text(source.text)


## Etiqueta con íconos: como un Label, pero con `show_text()`.
class IconLabel:
	extends RichTextLabel
	var font_px := 18
	var centered := false
	var raw := ""

	func _init(p_font: int = 18, p_center: bool = false, color: Color = Color.WHITE) -> void:
		font_px = p_font
		centered = p_center
		bbcode_enabled = false
		fit_content = true
		scroll_active = false
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_font_size_override("normal_font_size", font_px)
		add_theme_color_override("default_color", color)

	func show_text(t: String) -> void:
		if t == raw:
			return
		raw = t
		ButtonIcons.fill(self, t, int(font_px * 1.25), centered)
