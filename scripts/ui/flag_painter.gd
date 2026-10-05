class_name FlagPainter
extends RefCounted
## Banderas de las selecciones dibujadas por código a partir de una
## descripción simple (data/db/nations.json, campo "flag"):
##   {"t": "h", "c": [colores]}           franjas horizontales iguales
##   {"t": "v", "c": [...]}                franjas verticales iguales
##   {"t": "hw"/"vw", "c": [...], "w": [pesos]}  franjas de distinto ancho
##   {"t": "plain", "c": [color]}          lisa
##   {"t": "nordic", "c": [fondo, cruz, cruz interior]}
##   {"t": "cross", "c": [fondo, cruz]}    cruz centrada (San Jorge)
##   {"t": "saltire", "c": [fondo, aspa]}
##   {"t": "disc", "c": [fondo, círculo]}
##   especiales: usa, brazil, uruguay, chile, korea, qatar, jordan, china,
##   algeria, rsa, panama, jamaica, swiss, ensign (Australia / N. Zelanda).
## y un emblema opcional "e": {k: sun|star|crescent|cstar|disc|ring|bar|
## checks|cdisc|sash, c: color, x, y, r}.
## Es una versión simplificada (sin escudos), reconocible a la distancia.

const W := 96
const H := 64

static var _cache := {}


static func texture(spec: Dictionary) -> Texture2D:
	var key := JSON.stringify(spec)
	if _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(image(spec))
	_cache[key] = tex
	return tex


static func image(spec: Dictionary, w: int = W, h: int = H) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var cols: Array = spec.get("c", ["ffffff"])
	var c := func(i: int) -> Color: return Color.html(String(cols[mini(i, cols.size() - 1)]))
	var t := String(spec.get("t", "plain"))
	for y in h:
		for x in w:
			var u := (x + 0.5) / w
			var v := (y + 0.5) / h
			img.set_pixel(x, y, _pixel(t, spec, cols, c, u, v))
	if spec.has("e"):
		_emblem(img, spec["e"])
	return img


static func _band(weights: Array, f: float) -> int:
	var total := 0.0
	for wv in weights:
		total += float(wv)
	var acc := 0.0
	for i in weights.size():
		acc += float(weights[i]) / total
		if f < acc:
			return i
	return weights.size() - 1


static func _pixel(t: String, spec: Dictionary, cols: Array, c: Callable, u: float, v: float) -> Color:
	match t:
		"h":
			return c.call(mini(int(v * cols.size()), cols.size() - 1))
		"v":
			return c.call(mini(int(u * cols.size()), cols.size() - 1))
		"hw":
			return c.call(_band(spec.get("w", []), v))
		"vw":
			return c.call(_band(spec.get("w", []), u))
		"nordic":
			var cx := 0.375
			if absf(u - cx) < 0.09 or absf(v - 0.5) < 0.12:
				if cols.size() > 2 and (absf(u - cx) < 0.045 or absf(v - 0.5) < 0.06):
					return c.call(2)
				return c.call(1)
			return c.call(0)
		"cross":
			return c.call(1) if absf(u - 0.5) < 0.08 or absf(v - 0.5) < 0.11 else c.call(0)
		"saltire":
			var d1 := absf((u - 0.5) * 0.667 - (v - 0.5))
			var d2 := absf((u - 0.5) * 0.667 + (v - 0.5))
			return c.call(1) if minf(d1, d2) < 0.07 else c.call(0)
		"disc":
			return c.call(1) if Vector2((u - 0.5) * 1.5, v - 0.5).length() < 0.3 else c.call(0)
		"usa":
			if u < 0.4 and v < 0.54:
				var star := fmod(u * 15.0, 1.0) < 0.35 and fmod(v * 17.0, 1.0) < 0.4
				return Color.WHITE if star else Color.html("3c3b6e")
			return Color.html("b22234") if int(v * 13.0) % 2 == 0 else Color.WHITE
		"brazil":
			var dd := absf(u - 0.5) / 0.42 + absf(v - 0.5) / 0.4
			if Vector2((u - 0.5) * 1.5, v - 0.5).length() < 0.2:
				return Color.html("002776")
			if dd < 1.0:
				return Color.html("ffdf00")
			return Color.html("009c3b")
		"uruguay":
			if u < 0.38 and v < 0.55:
				return Color.html("fcd116") if Vector2((u - 0.19) * 1.5, v - 0.27).length() < 0.12 else Color.WHITE
			return Color.WHITE if int(v * 9.0) % 2 == 0 else Color.html("0038a8")
		"chile":
			if v >= 0.5:
				return Color.html("d52b1e")
			if u < 0.33:
				return Color.WHITE if _star(Vector2((u - 0.165) * 1.5, v - 0.25), 0.11) else Color.html("0039a6")
			return Color.WHITE
		"korea":
			var p := Vector2((u - 0.5) * 1.5, v - 0.5)
			if p.length() < 0.2:
				return Color.html("cd2e3a") if p.y < 0.0 else Color.html("0047a0")
			var q := Vector2(absf(p.x), absf(p.y))
			if q.x > 0.36 and q.x < 0.5 and q.y > 0.24 and q.y < 0.36:
				return Color.BLACK
			return Color.WHITE
		"qatar":
			var edge := 0.3 + 0.04 * absf(fmod(v * 9.0, 2.0) - 1.0)
			return Color.WHITE if u < edge else Color.html("8a1538")
		"jordan":
			if u < 0.45 * (1.0 - absf(v - 0.5) * 2.0):
				return Color.WHITE if Vector2(u - 0.13, v - 0.5).length() < 0.04 else Color.html("ce1126")
			return [Color.BLACK, Color.WHITE, Color.html("007a3d")][mini(int(v * 3.0), 2)]
		"china":
			if _star(Vector2((u - 0.16) * 1.5, v - 0.25), 0.13):
				return Color.html("ffde00")
			for s in [Vector2(0.33, 0.1), Vector2(0.4, 0.2), Vector2(0.4, 0.33), Vector2(0.33, 0.43)]:
				if _star(Vector2((u - s.x) * 1.5, v - s.y), 0.045):
					return Color.html("ffde00")
			return Color.html("de2910")
		"algeria":
			var pc := Vector2((u - 0.5) * 1.5, v - 0.5)
			if pc.length() < 0.25 and Vector2(pc.x - 0.06, pc.y).length() > 0.2:
				return Color.html("d21034")
			if _star(Vector2(pc.x - 0.12, pc.y), 0.08):
				return Color.html("d21034")
			return Color.html("006233") if u < 0.5 else Color.WHITE
		"rsa":
			var y2 := absf(v - 0.5)
			var arm := u * 0.667
			if y2 < 0.5 - arm and u < 0.45:
				return Color.html("ffb612") if y2 > 0.42 - arm else Color.BLACK
			if y2 < 0.1 + maxf(0.0, 0.25 - u * 0.5):
				return Color.html("007749")
			if y2 < 0.17 + maxf(0.0, 0.25 - u * 0.5):
				return Color.WHITE
			return Color.html("e03c31") if v < 0.5 else Color.html("001489")
		"panama":
			if u < 0.5 and v < 0.5:
				return Color.html("005293") if _star(Vector2((u - 0.25) * 1.5, v - 0.25), 0.1) else Color.WHITE
			if u >= 0.5 and v >= 0.5:
				return Color.html("d21034") if _star(Vector2((u - 0.75) * 1.5, v - 0.75), 0.1) else Color.WHITE
			return Color.html("d21034") if u >= 0.5 else Color.html("005293")
		"jamaica":
			var d1 := absf((u - 0.5) * 0.667 - (v - 0.5))
			var d2 := absf((u - 0.5) * 0.667 + (v - 0.5))
			if minf(d1, d2) < 0.07:
				return Color.html("fed100")
			return Color.html("009b3a") if absf(v - 0.5) > absf(u - 0.5) * 0.667 else Color.BLACK
		"swiss":
			var a := absf(u - 0.5) * 1.5
			var b := absf(v - 0.5)
			if (a < 0.07 and b < 0.25) or (b < 0.07 and a < 0.25):
				return Color.WHITE
			return Color.html("da291c")
		"ensign":
			if u < 0.5 and v < 0.5:
				var uu := u * 2.0
				var vv := v * 2.0
				if absf(uu - 0.5) < 0.1 or absf(vv - 0.5) < 0.12:
					return Color.html("c8102e")
				var e1 := absf((uu - 0.5) - (vv - 0.5))
				var e2 := absf((uu - 0.5) + (vv - 0.5))
				if absf(uu - 0.5) < 0.17 or absf(vv - 0.5) < 0.2 or minf(e1, e2) < 0.1:
					return Color.WHITE
				return Color.html("012169")
			if u < 0.5 and _star(Vector2((u - 0.25) * 1.5, v - 0.75), 0.1):
				return Color.WHITE
			return c.call(0)
	return c.call(0)


## Punto dentro de una estrella de 5 puntas de radio `r` (p centrado).
static func _star(p: Vector2, r: float) -> bool:
	var ang := atan2(p.x, -p.y)
	var k := fmod(ang + TAU, TAU / 5.0) - TAU / 10.0
	var rr := lerpf(r, r * 0.42, absf(k) / (TAU / 10.0))
	return p.length() < rr


static func _emblem(img: Image, e: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var col := Color.html(String(e.get("c", "ffffff")))
	var cx := float(e.get("x", 0.5))
	var cy := float(e.get("y", 0.5))
	var r := float(e.get("r", 0.2))
	var k := String(e.get("k", "disc"))
	for y in h:
		for x in w:
			var u := (x + 0.5) / w
			var v := (y + 0.5) / h
			var p := Vector2((u - cx) * float(w) / h, v - cy)
			var on := false
			match k:
				"disc":
					on = p.length() < r
				"ring":
					on = p.length() < r and p.length() > r * 0.62
				"sun":
					var ang := atan2(p.y, p.x)
					on = p.length() < r * (0.62 + 0.38 * absf(sin(ang * 8.0)))
				"star":
					on = _star(p, r)
				"crescent":
					on = p.length() < r and Vector2(p.x - r * 0.35, p.y).length() > r * 0.8
				"cstar":
					on = (p.length() < r and Vector2(p.x - r * 0.28, p.y).length() > r * 0.8) \
						or _star(Vector2(p.x - r * 0.95, p.y), r * 0.4)
				"cdisc":
					# Disco blanco con la media luna y la estrella rojas (Túnez).
					on = p.length() < r
					var moon := Vector2(p.x + r * 0.12, p.y).length() < r * 0.72 \
						and Vector2(p.x - r * 0.08, p.y).length() > r * 0.58
					if on and (moon or _star(Vector2(p.x - r * 0.28, p.y), r * 0.3)):
						img.set_pixel(x, y, Color.html("e70013"))
						continue
				"bar":
					on = absf(p.x) < r * 1.6 and absf(p.y) < r * 0.18
				"checks":
					on = absf(p.x) < r and p.y > -r and p.y < r * 1.2
					if on:
						var ch := (int(floor((p.x + r) / (r * 0.4))) + int(floor((p.y + r) / (r * 0.4)))) % 2 == 0
						img.set_pixel(x, y, col if ch else Color.WHITE)
						continue
				"sash":
					on = absf((1.0 - u) - v) < 0.1
					if on and absf((1.0 - u) - v) > 0.07:
						img.set_pixel(x, y, Color.html("f7d618"))
						continue
					if not on and _star(Vector2((u - 0.15) * float(w) / h, v - 0.2), 0.12):
						img.set_pixel(x, y, Color.html("f7d618"))
						continue
			if on:
				img.set_pixel(x, y, col)
