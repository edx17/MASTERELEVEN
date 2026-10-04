class_name PitchMarkings
extends RefCounted
## Todas las marcas reglamentarias de una cancha, en metros (x = largo,
## y = ancho; centro en el origen): perímetro, línea media, círculo y punto
## central, áreas grande y chica, punto penal, medialuna, arcos de córner y
## los arcos (detrás de la línea). La usan la cancha 3D (PitchBuilder), las
## canchas del Club House, el radar del HUD y la minicancha de la Dirección
## del equipo, así todas las canchas tienen las mismas marcas.
##
## En una cancha más chica que la reglamentaria (`hl`, `hw`), las áreas
## conservan su medida y se achican sólo si no entran.

const CORNER_ARC_RADIUS := 1.0
const SPOT_RADIUS := 0.15


## Segmentos [a, b] (Vector2, en metros).
static func lines(hl: float = Pitch.HALF_LENGTH, hw: float = Pitch.HALF_WIDTH) -> Array:
	var out: Array = [
		[Vector2(-hl, -hw), Vector2(hl, -hw)],
		[Vector2(-hl, hw), Vector2(hl, hw)],
		[Vector2(-hl, -hw), Vector2(-hl, hw)],
		[Vector2(hl, -hw), Vector2(hl, hw)],
		[Vector2(0.0, -hw), Vector2(0.0, hw)],
	]
	var pa_d := minf(Pitch.PENALTY_AREA_DEPTH, hl * 0.33)
	var pa_w := minf(Pitch.PENALTY_AREA_HALF_WIDTH, hw * 0.6)
	var ga_d := minf(Pitch.GOAL_AREA_DEPTH, pa_d * 0.34)
	var ga_w := minf(Pitch.GOAL_AREA_HALF_WIDTH, pa_w * 0.46)
	for side: int in [-1, 1]:
		var gx: float = side * hl
		var pa := gx - side * pa_d
		out.append([Vector2(gx, -pa_w), Vector2(pa, -pa_w)])
		out.append([Vector2(gx, pa_w), Vector2(pa, pa_w)])
		out.append([Vector2(pa, -pa_w), Vector2(pa, pa_w)])
		var ga := gx - side * ga_d
		out.append([Vector2(gx, -ga_w), Vector2(ga, -ga_w)])
		out.append([Vector2(gx, ga_w), Vector2(ga, ga_w)])
		out.append([Vector2(ga, -ga_w), Vector2(ga, ga_w)])
	return out


## Arcos [centro, radio, ángulo desde, ángulo hasta, relleno (punto)].
static func arcs(hl: float = Pitch.HALF_LENGTH, hw: float = Pitch.HALF_WIDTH) -> Array:
	var cc := minf(Pitch.CENTER_CIRCLE_RADIUS, hw * 0.3)
	var out: Array = [
		[Vector2.ZERO, cc, 0.0, TAU, false],
		[Vector2.ZERO, SPOT_RADIUS * 1.3, 0.0, TAU, true],
	]
	var pa_d := minf(Pitch.PENALTY_AREA_DEPTH, hl * 0.33)
	var spot_d := minf(Pitch.PENALTY_SPOT_DISTANCE, pa_d * 0.67)
	for side: int in [-1, 1]:
		var gx: float = side * hl
		var spot := Vector2(gx - side * spot_d, 0.0)
		out.append([spot, SPOT_RADIUS, 0.0, TAU, true])
		# Medialuna: la parte del círculo de 9,15 m que queda fuera del área.
		var ratio := clampf((pa_d - spot_d) / cc, -1.0, 1.0)
		var half_angle := acos(ratio)
		var facing := 0.0 if side == -1 else PI
		out.append([spot, cc, facing - half_angle, facing + half_angle, false])
		for zs: int in [-1, 1]:
			var start := atan2(-zs, -side)
			out.append([Vector2(gx, zs * hw), CORNER_ARC_RADIUS, start - PI / 4.0, start + PI / 4.0, false])
	return out


## Los arcos vistos desde arriba: rectángulo detrás de cada línea de meta.
static func goals(hl: float = Pitch.HALF_LENGTH) -> Array:
	var out: Array = []
	for side: int in [-1, 1]:
		var gx: float = side * hl
		var back: float = gx + side * Pitch.GOAL_DEPTH
		out.append(Rect2(Vector2(minf(gx, back), -Pitch.GOAL_HALF_WIDTH),
			Vector2(Pitch.GOAL_DEPTH, Pitch.GOAL_HALF_WIDTH * 2.0)))
	return out


## Dibuja las marcas en 2D dentro de `rect` (largo en x). `inset` deja lugar
## para los arcos detrás de la línea de meta.
static func draw_2d(ci: CanvasItem, rect: Rect2, color: Color, width: float = 1.0,
		hl: float = Pitch.HALF_LENGTH, hw: float = Pitch.HALF_WIDTH, with_goals: bool = true) -> void:
	var sx := rect.size.x / (hl * 2.0)
	var sy := rect.size.y / (hw * 2.0)
	var c := rect.get_center()
	var to := func(v: Vector2) -> Vector2: return c + Vector2(v.x * sx, v.y * sy)
	for l: Array in lines(hl, hw):
		ci.draw_line(to.call(l[0]), to.call(l[1]), color, width)
	for a: Array in arcs(hl, hw):
		var center: Vector2 = to.call(a[0])
		var r: float = a[1] * (sx + sy) * 0.5
		if a[4]:
			ci.draw_circle(center, maxf(r, width * 0.9), color)
		else:
			var pts := PackedVector2Array()
			var segs := maxi(6, int(absf(a[3] - a[2]) / TAU * 48.0))
			for i in segs + 1:
				var t := lerpf(a[2], a[3], float(i) / segs)
				pts.append(to.call(a[0] + Vector2(cos(t), sin(t)) * a[1]))
			ci.draw_polyline(pts, color, width)
	if with_goals:
		for g: Rect2 in goals(hl):
			var p: Vector2 = to.call(g.position)
			ci.draw_rect(Rect2(p, Vector2(g.size.x * sx, g.size.y * sy)), color, false, width)
