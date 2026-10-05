class_name WEStyle
extends RefCounted
## Estilo de los menús, a la manera del WE2002 (sin copiar logos ni marcas):
## fondo azul oscuro con líneas finas y un brillo, barras violetas que se
## iluminan al elegirlas, filas "◀ valor ▶" y una caja de ayuda verde abajo.

const BAR := Color(0.16, 0.13, 0.42, 0.92)
const BAR_FOCUS := Color(0.42, 0.36, 0.9, 0.97)
const BAR_TEXT := Color(0.88, 0.9, 1.0)
const BAR_TEXT_FOCUS := Color(1.0, 0.92, 0.35)
const PANEL := Color(0.05, 0.08, 0.22, 0.9)
const PANEL_BORDER := Color(0.3, 0.45, 0.95, 0.9)


## Fondo: degradé azul, líneas finas arriba y abajo, y un brillo a la derecha.
static func background(parent: Control) -> void:
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)


## Barra de menú (botón) violeta.
static func bar(text: String, cb: Callable, width: float = 360.0, font_size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(width, 40)
	b.add_theme_font_size_override("font_size", font_size)
	style_bar(b)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func style_bar(b: Button) -> void:
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = BAR_FOCUS if st in ["hover", "focus"] else BAR
		if st == "disabled":
			sb.bg_color = Color(BAR, 0.55)
		sb.border_color = Color(0.55, 0.5, 1.0, 0.8)
		sb.border_width_bottom = 2
		sb.border_width_left = 4 if st == "focus" else 0
		sb.content_margin_left = 18
		sb.content_margin_right = 12
		sb.skew = Vector2(-0.12, 0.0)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", BAR_TEXT)
	b.add_theme_color_override("font_hover_color", BAR_TEXT_FOCUS)
	b.add_theme_color_override("font_focus_color", BAR_TEXT_FOCUS)
	b.add_theme_color_override("font_disabled_color", Color(BAR_TEXT, 0.45))


## Caja de ayuda verde con borde dorado (abajo de la pantalla).
static func help_box(parent: Control) -> Label:
	var pc := PanelContainer.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	pc.offset_left = 40
	pc.offset_right = -40
	pc.offset_top = -96
	pc.offset_bottom = -18
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.2, 0.12, 0.94)
	sb.border_color = Color(0.78, 0.62, 0.25)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(12)
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.92, 0.96, 0.92))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.visible = false
	pc.add_child(l)
	# Lo que se ve: el mismo texto con los íconos de los botones ({X}, {SQ}...).
	var m := ButtonIcons.Mirror.new(22, false, Color(0.92, 0.96, 0.92))
	m.source = l
	pc.add_child(m)
	return l


static func panel(min_size: Vector2) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = min_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(2)
	sb.set_content_margin_all(12)
	pc.add_theme_stylebox_override("panel", sb)
	return pc


static func label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	return l


## Fila de opción "Nombre   ◀ valor ▶": izquierda / derecha cambian el valor;
## X también avanza. `get_value` devuelve el texto; `step(dir)` lo cambia.
class OptionRow:
	extends Button
	var caption := ""
	var get_value: Callable
	var step: Callable
	var help := ""

	func _init(p_caption: String, p_get: Callable, p_step: Callable, p_help: String = "", width: float = 560.0) -> void:
		caption = p_caption
		get_value = p_get
		step = p_step
		help = p_help
		custom_minimum_size = Vector2(width, 38)
		add_theme_font_size_override("font_size", 21)
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		WEStyle.style_bar(self)
		pressed.connect(func() -> void: change(1))
		refresh()

	func change(dir: int) -> void:
		step.call(dir)
		refresh()

	func refresh() -> void:
		text = "%s" % caption
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"ui_left"):
			change(-1)
			accept_event()
		elif event.is_action_pressed(&"ui_right"):
			change(1)
			accept_event()

	func _draw() -> void:
		var font := get_theme_default_font()
		var v := String(get_value.call())
		var fs := 21
		var w := font.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var c := WEStyle.BAR_TEXT_FOCUS if has_focus() else Color.WHITE
		var right := size.x - 22.0
		var cy := size.y * 0.5
		# Flechas ◀ ▶ a los costados del valor.
		draw_colored_polygon(PackedVector2Array([Vector2(right, cy), Vector2(right - 10, cy - 7), Vector2(right - 10, cy + 7)]), c)
		var x := right - 22.0 - w
		draw_string(font, Vector2(x, cy + fs * 0.35), v, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
		var lx := x - 14.0
		draw_colored_polygon(PackedVector2Array([Vector2(lx - 10, cy), Vector2(lx, cy - 7), Vector2(lx, cy + 7)]), c)


## Desplaza un ScrollContainer con el stick derecho del mando o con
## RePág / AvPág (las tablas largas de las ligas y del Mundial, sin mouse).
## Se agrega como hijo: `WEStyle.pad_scroll(scroll)`.
class PadScroll:
	extends Node
	const SPEED := 900.0

	func _process(dt: float) -> void:
		var s := get_parent() as ScrollContainer
		if s == null or not s.is_visible_in_tree():
			return
		var v := 0.0
		for dev in Input.get_connected_joypads():
			var a := Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y)
			if absf(a) > 0.25:
				v = a
		if Input.is_key_pressed(KEY_PAGEDOWN):
			v = 1.0
		elif Input.is_key_pressed(KEY_PAGEUP):
			v = -1.0
		if v != 0.0:
			s.scroll_vertical += int(v * SPEED * dt)


static func pad_scroll(scroll: ScrollContainer) -> void:
	scroll.add_child(PadScroll.new())


## Fondo animado (un brillo que late, como el del WE).
class Backdrop:
	extends Control
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var steps := 24
		for i in steps:
			var k := float(i) / steps
			draw_rect(Rect2(0, r.size.y * k, r.size.x, r.size.y / steps + 1.0),
				Color(0.02, 0.03, 0.12).lerp(Color(0.08, 0.06, 0.3), k))
		# Brillo a la derecha.
		var c := Vector2(r.size.x * 0.78, r.size.y * 0.42)
		var pulse := 0.9 + 0.1 * sin(_t * 1.5)
		for i in 14:
			var rad := r.size.y * (0.42 - i * 0.026) * pulse
			draw_circle(c, rad, Color(0.55, 0.5, 1.0, 0.035 + i * 0.006))
		# Líneas finas (verde arriba, azul abajo).
		draw_line(Vector2(0, 26), Vector2(r.size.x, 26), Color(0.2, 0.75, 0.4, 0.8), 2.0)
		draw_line(Vector2(0, r.size.y - 12), Vector2(r.size.x, r.size.y - 12), Color(0.3, 0.45, 1.0, 0.7), 2.0)
		draw_line(Vector2(48, 0), Vector2(48, r.size.y), Color(0.3, 0.45, 1.0, 0.35), 1.0)


## Escudo de un equipo: los dos colores en diagonal y la sigla.
class Crest:
	extends Control
	var team: TeamData

	func _draw() -> void:
		if team == null:
			return
		var w := size.x
		var h := size.y
		# Escudo importado: entero y centrado, sin deformarlo.
		if team.crest != null:
			var ts := team.crest.get_size()
			var k := minf(w / ts.x, h / ts.y)
			var sz := ts * k
			draw_texture_rect(team.crest, Rect2((Vector2(w, h) - sz) * 0.5, sz), false)
			return
		# Selección: su bandera, con un borde dorado.
		if team.flag != null:
			var fh := minf(h * 0.8, w * 0.667)
			var r := Rect2(Vector2(0.0, (h - fh) * 0.5), Vector2(w, fh))
			draw_texture_rect(team.flag, r, false)
			draw_rect(r, Color(0.95, 0.85, 0.4), false, 2.0)
			return
		var shield := PackedVector2Array([Vector2(w * 0.1, h * 0.06), Vector2(w * 0.9, h * 0.06),
			Vector2(w * 0.9, h * 0.55), Vector2(w * 0.5, h * 0.95), Vector2(w * 0.1, h * 0.55)])
		draw_colored_polygon(shield, team.color)
		var half := PackedVector2Array([Vector2(w * 0.9, h * 0.06), Vector2(w * 0.9, h * 0.55),
			Vector2(w * 0.5, h * 0.95), Vector2(w * 0.35, h * 0.8)])
		# La otra mitad: el segundo color del diseño de la camiseta, o el del
		# pantalón si es lisa (o si son iguales a la camiseta).
		var second := team.pattern_color if team.pattern > 0 else team.secondary_color
		if second.is_equal_approx(team.color):
			second = team.secondary_color if not team.secondary_color.is_equal_approx(team.color) else Color.WHITE
		draw_colored_polygon(half, second)
		shield.append(shield[0])
		draw_polyline(shield, Color(0.95, 0.85, 0.4), 2.0)
		var font := get_theme_default_font()
		var fs := int(h * 0.26)
		while fs > 8 and font.get_string_size(team.short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w * 0.62:
			fs -= 1
		var ink := Color.BLACK if team.color.get_luminance() > 0.5 else Color.WHITE
		draw_string(font, Vector2(0, h * 0.45), team.short_name, HORIZONTAL_ALIGNMENT_CENTER, w, fs, ink)


## Camiseta y pantalón dibujados (para elegir uniforme).
class KitIcon:
	extends Control
	var shirt := Color.WHITE
	var shorts := Color.BLACK
	## Diseño de la camiseta (TeamData.pattern) y su segundo color.
	var pattern := 0
	var shirt2 := Color.BLACK

	## Uniforme `i` (0 titular, 1 suplente) de un equipo.
	func set_kit(team: TeamData, i: int) -> void:
		var k := team.kit(i)
		shirt = k[0]
		shorts = k[1]
		var p := team.kit_pattern(i)
		pattern = int(p[0])
		shirt2 = p[1]
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var body := PackedVector2Array([Vector2(w * 0.3, h * 0.05), Vector2(w * 0.42, h * 0.1), Vector2(w * 0.58, h * 0.1),
			Vector2(w * 0.7, h * 0.05), Vector2(w * 0.95, h * 0.2), Vector2(w * 0.85, h * 0.36), Vector2(w * 0.74, h * 0.3),
			Vector2(w * 0.74, h * 0.62), Vector2(w * 0.26, h * 0.62), Vector2(w * 0.26, h * 0.3), Vector2(w * 0.15, h * 0.36),
			Vector2(w * 0.05, h * 0.2)])
		draw_colored_polygon(body, shirt)
		_draw_pattern(w, h)
		body.append(body[0])
		draw_polyline(body, Color(0, 0, 0, 0.6), 2.0)
		var pants := PackedVector2Array([Vector2(w * 0.26, h * 0.64), Vector2(w * 0.74, h * 0.64), Vector2(w * 0.78, h * 0.92),
			Vector2(w * 0.54, h * 0.92), Vector2(w * 0.5, h * 0.8), Vector2(w * 0.46, h * 0.92), Vector2(w * 0.22, h * 0.92)])
		draw_colored_polygon(pants, shorts)
		pants.append(pants[0])
		draw_polyline(pants, Color(0, 0, 0, 0.6), 2.0)

	## El diseño sobre el torso (rectángulo entre las mangas).
	func _draw_pattern(w: float, h: float) -> void:
		var x0 := w * 0.26
		var x1 := w * 0.74
		var y0 := h * 0.1
		var y1 := h * 0.62
		match pattern:
			1, 2:
				var n := 5 if pattern == 1 else 9
				var bw := (x1 - x0) / n
				for k in range(1, n, 2):
					draw_rect(Rect2(x0 + k * bw, y0, bw * (1.0 if pattern == 1 else 0.45), y1 - y0), shirt2)
			3:
				var bh := (y1 - y0) / 5.0
				for k in range(1, 5, 2):
					draw_rect(Rect2(x0, y0 + k * bh, x1 - x0, bh), shirt2)
			4:
				draw_rect(Rect2((x0 + x1) * 0.5, y0, (x1 - x0) * 0.5, y1 - y0), shirt2)
			5:
				draw_colored_polygon(PackedVector2Array([Vector2(x1 - w * 0.1, y0), Vector2(x1, y0), Vector2(x1, y0 + h * 0.08),
					Vector2(x0 + w * 0.1, y1), Vector2(x0, y1), Vector2(x0, y1 - h * 0.08)]), shirt2)
			6:
				draw_rect(Rect2(x0, y0 + (y1 - y0) * 0.3, x1 - x0, (y1 - y0) * 0.2), shirt2)
			7:
				var cx := (x0 + x1) * 0.5
				draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + w * 0.08, y0), Vector2(cx, y0 + h * 0.2),
					Vector2(x1 - w * 0.08, y0), Vector2(x1, y0), Vector2(cx, y0 + h * 0.28)]), shirt2)
			8:
				var cs := (x1 - x0) / 6.0
				for gy in int((y1 - y0) / cs):
					for gx in 6:
						if (gx + gy) % 2 == 1:
							draw_rect(Rect2(x0 + gx * cs, y0 + gy * cs, cs, cs), shirt2)


## Barras de puntaje (ataque, defensa, ...) de 0 a 1.
class RatingBars:
	extends Control
	const NAMES := ["Ataque", "Defensa", "Fuerza", "Velocidad", "Técnica"]
	var home: Array[float] = []
	var away: Array[float] = []

	func _draw() -> void:
		var font := get_theme_default_font()
		var row := size.y / NAMES.size()
		var bar_w := size.x * 0.3
		for i in NAMES.size():
			var y := row * i + row * 0.5
			draw_string(font, Vector2(0, y + 7), NAMES[i], HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color.WHITE)
			if i < home.size():
				var w := bar_w * home[i]
				draw_rect(Rect2(bar_w - w, y - 6, w, 12), Color(1.0, 0.6, 0.1).lerp(Color(1.0, 0.9, 0.2), home[i]))
			if i < away.size():
				draw_rect(Rect2(size.x - bar_w, y - 6, bar_w * away[i], 12), Color(1.0, 0.6, 0.1).lerp(Color(1.0, 0.9, 0.2), away[i]))
