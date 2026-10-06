class_name WEStyle
extends RefCounted
## Fuente única de estilo de la interfaz.
##
## Rediseño "estadio de noche" (ver sección TOKENS): paleta, tipografías,
## tamaños, medidas y constructores de estilos (make_*). Las pantallas nuevas
## usan sólo estos tokens; no escriben colores ni tamaños propios.
##
## Lo de abajo de TOKENS es el estilo anterior (WE2002: barras violetas,
## caja de ayuda verde); queda hasta que cada pantalla pase al rediseño.

# --- TOKENS (rediseño "estadio de noche") ---------------------------------------
# Las medidas están pensadas para 1920×1080. El juego se arma en 1280×720 y se
# escala a la pantalla: px() pasa una medida de 1080p a la base del juego, así
# a 1920×1080 se ve exactamente como en la guía.

const DESIGN_HEIGHT := 1080.0
const BASE_HEIGHT := 720.0
const UI_SCALE := BASE_HEIGHT / DESIGN_HEIGHT

# Paleta.
const BG_NIGHT := Color("#0B1220")      ## fondo general
const BG_PANEL := Color("#111A2E")      ## paneles y tarjetas
const BG_PANEL_ALT := Color("#16223A")  ## filas alternas, hover, foco
const ACCENT := Color("#E8C547")        ## dorado: foco, selección, datos clave
const ACCENT_GREEN := Color("#3FB96B")  ## victoria, confirmación
const TEXT_MAIN := Color("#EDF1F7")     ## texto principal
const TEXT_DIM := Color("#8B96AB")      ## texto secundario, etiquetas
const LINE := Color("#24304A")          ## bordes y separadores de 1 px
const DANGER := Color("#D95555")        ## derrota, alertas
const PITCH_DARK := Color("#24432F")    ## césped de la mini cancha
const PITCH_LIGHT := Color("#2B4D36")   ## franjas del césped

# Tipografías (res://assets/fonts/, licencia OFL).
enum Typeface { TITLE, BODY, SEMIBOLD, ITALIC }
const FONT_PATHS := {
	Typeface.TITLE: "res://assets/fonts/BebasNeue-Regular.ttf",
	Typeface.BODY: "res://assets/fonts/Barlow-Regular.ttf",
	Typeface.SEMIBOLD: "res://assets/fonts/Barlow-SemiBold.ttf",
	Typeface.ITALIC: "res://assets/fonts/Barlow-Italic.ttf",
}

# Tamaños de letra (en px de 1080p).
const TITLE_XL := 64  ## títulos de pantalla, marcadores
const TITLE_L := 48
const TITLE_M := 32   ## ítems del menú lateral
const BODY_L := 18
const BODY_M := 16    ## cuerpo y tablas
const BODY_S := 14    ## etiquetas, keycaps

# Medidas (en px de 1080p).
const MARGIN_X := 64        ## margen lateral de pantalla
const MARGIN_Y := 48        ## margen vertical de pantalla
const RADIUS_CARD := 8
const RADIUS_BUTTON := 4
const BORDER := 1
const FOCUS_BORDER := 2
const ROW_H := 44           ## fila de tabla
const HEADER_ROW_H := 36    ## encabezado de tabla
const FOOTER_H := 56        ## pie con las indicaciones de control
const HINT_SIZE := 28       ## círculo de botón / alto de tecla
const SIDE_MENU_W := 420    ## menú lateral (diseño 01)
const SIDE_ITEM_H := 72
const CARD_PADDING := 24
const BUTTON_PADDING_X := 20
const FADE_TIME := 0.15     ## transiciones (s), nunca más largas

static var _fonts := {}


## Una medida de 1080p en la base del juego (1280×720).
static func px(v: float) -> float:
	return v * UI_SCALE


## Tamaño de letra de 1080p en la base del juego (entero, mínimo 8).
static func font_px(size: int) -> int:
	return maxi(8, roundi(size * UI_SCALE))


## La tipografía pedida (cargada una vez). Si el archivo no está, la del tema.
static func font(face: Typeface) -> Font:
	if not _fonts.has(face):
		var f: Font = null
		var path := String(FONT_PATHS[face])
		if ResourceLoader.exists(path):
			f = load(path) as Font
		_fonts[face] = f if f != null else ThemeDB.fallback_font
	return _fonts[face]


## Tarjeta / panel: fondo bg_panel (o bg_panel_alt), borde de 1 px, radio 8.
static func make_panel_style(alt: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_PANEL_ALT if alt else BG_PANEL
	sb.border_color = LINE
	sb.set_border_width_all(BORDER)
	sb.set_corner_radius_all(int(px(RADIUS_CARD)))
	sb.set_content_margin_all(px(CARD_PADDING))
	sb.anti_aliasing = true
	return sb


## Estado con foco: borde accent de 2 px + fondo bg_panel_alt (nunca sólo el
## color del texto). `radius`: RADIUS_BUTTON o RADIUS_CARD.
static func make_focus_style(radius: int = RADIUS_BUTTON) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_PANEL_ALT
	sb.border_color = ACCENT
	sb.set_border_width_all(FOCUS_BORDER)
	sb.set_corner_radius_all(int(px(radius)))
	sb.set_content_margin_all(px(BUTTON_PADDING_X) * 0.5)
	sb.content_margin_left = px(BUTTON_PADDING_X)
	sb.content_margin_right = px(BUTTON_PADDING_X)
	sb.anti_aliasing = true
	return sb


## Botón en reposo ("normal"), apretado ("pressed") o deshabilitado
## ("disabled"); "focus" y "hover" usan make_focus_style().
static func make_button_style(state: String = "normal") -> StyleBoxFlat:
	if state in ["focus", "hover"]:
		return make_focus_style(RADIUS_BUTTON)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_PANEL_ALT if state == "pressed" else BG_PANEL
	if state == "disabled":
		sb.bg_color = Color(BG_PANEL, 0.6)
	sb.border_color = LINE
	sb.set_border_width_all(BORDER)
	sb.set_corner_radius_all(int(px(RADIUS_BUTTON)))
	sb.set_content_margin_all(px(BUTTON_PADDING_X) * 0.5)
	sb.content_margin_left = px(BUTTON_PADDING_X)
	sb.content_margin_right = px(BUTTON_PADDING_X)
	sb.anti_aliasing = true
	return sb


## Aplica el estilo nuevo a un botón (estados, Barlow SemiBold, colores).
static func style_button(b: Button, size: int = BODY_L) -> void:
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, make_button_style(st))
	b.add_theme_font_override("font", font(Typeface.SEMIBOLD))
	b.add_theme_font_size_override("font_size", font_px(size))
	b.add_theme_color_override("font_color", TEXT_MAIN)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_focus_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM)


## Botón principal de la pantalla (p. ej. "Continuar"): en reposo, fondo
## bg_panel_alt con borde y texto dorados; con foco, relleno dorado y borde
## claro de 2 px (se distingue por el fondo, no sólo por el texto).
static func style_primary_button(b: Button, size: int = BODY_L) -> void:
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		var sb := make_button_style("normal")
		sb.border_color = ACCENT
		if st in ["hover", "focus", "pressed"]:
			sb.bg_color = ACCENT
			sb.border_color = TEXT_MAIN
			sb.set_border_width_all(FOCUS_BORDER)
		else:
			sb.bg_color = BG_PANEL_ALT
		if st == "disabled":
			sb.border_color = LINE
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", font(Typeface.SEMIBOLD))
	b.add_theme_font_size_override("font_size", font_px(size))
	b.add_theme_color_override("font_color", ACCENT)
	for k in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, BG_NIGHT)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM)


## Ítem de menú lateral (diseño 01): texto en Bebas, sin fondo en reposo; con
## foco, el estilo de foco (borde dorado + bg_panel_alt).
static func style_menu_item(b: Button, size: int = TITLE_M) -> void:
	for st in ["normal", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(BG_PANEL_ALT, 0.0)
		sb.content_margin_left = px(BUTTON_PADDING_X)
		sb.content_margin_right = px(BUTTON_PADDING_X)
		b.add_theme_stylebox_override(st, sb)
	for st in ["hover", "focus"]:
		b.add_theme_stylebox_override(st, make_focus_style(RADIUS_BUTTON))
	b.add_theme_font_override("font", font(Typeface.TITLE))
	b.add_theme_font_size_override("font_size", font_px(size))
	b.add_theme_color_override("font_color", TEXT_MAIN)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_focus_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT


## Título en Bebas Neue (64 / 48 / 32).
static func make_title_label(text: String, size: int = TITLE_L, color: Color = TEXT_MAIN) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(Typeface.TITLE))
	l.add_theme_font_size_override("font_size", font_px(size))
	l.add_theme_color_override("font_color", color)
	return l


## Texto en Barlow (18 / 16 / 14); `italic` para notas secundarias.
static func make_body_label(text: String, size: int = BODY_M, color: Color = TEXT_MAIN, italic: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(Typeface.ITALIC if italic else Typeface.BODY))
	l.add_theme_font_size_override("font_size", font_px(size))
	l.add_theme_color_override("font_color", color)
	return l


## Etiqueta chica en mayúsculas, con letras separadas (encabezados de tabla).
static func make_caption_label(text: String, color: Color = TEXT_DIM) -> Label:
	var l := make_body_label(text.to_upper(), BODY_S, color)
	var spaced := FontVariation.new()
	spaced.base_font = font(Typeface.SEMIBOLD)
	spaced.spacing_glyph = 1
	l.add_theme_font_override("font", spaced)
	return l


## Separador horizontal de 1 px (color line).
static func make_separator() -> ColorRect:
	var r := ColorRect.new()
	r.color = LINE
	r.custom_minimum_size = Vector2(0, BORDER)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Número con separador de miles: 54000 -> "54.000".
static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Fundido de entrada (FADE_TIME); no bloquea la entrada.
static func fade_in(c: Control) -> void:
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, FADE_TIME)


## Pie de pantalla (56 px): a la izquierda "01 / NOMBRE DE LA PANTALLA" y a la
## derecha las indicaciones de control [[acción, texto]]. Cambia los íconos
## al vuelo cuando se pasa de teclado a mando o se reasigna un control
## (InputRouter.events()), sin mover nada de lugar ni tocar el foco.
##
## Uso en cualquier pantalla:
##   var foot := WEStyle.HintFooter.new("02  /  Liga Master",
##       [[&"ui_accept", "Aceptar"], [&"ui_cancel", "Volver"], [&"ui_tabs", "Sección"]])
##   foot.set_hints(...)  # cuando cambian las acciones disponibles
## Acciones: ui_accept, ui_cancel, ui_options, ui_tabs, ui_navigate (ver
## ButtonIcons.get_hint).
class HintFooter:
	extends PanelContainer
	var screen := ""
	var hints: Array = []
	var _row: HBoxContainer

	func _init(p_screen: String = "", p_hints: Array = []) -> void:
		screen = p_screen
		hints = p_hints
		custom_minimum_size = Vector2(0, WEStyle.px(WEStyle.FOOTER_H))
		var sb := StyleBoxFlat.new()
		sb.bg_color = WEStyle.BG_PANEL
		sb.border_color = WEStyle.LINE
		sb.border_width_top = WEStyle.BORDER
		sb.content_margin_left = WEStyle.px(WEStyle.MARGIN_X)
		sb.content_margin_right = WEStyle.px(WEStyle.MARGIN_X)
		add_theme_stylebox_override("panel", sb)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row = HBoxContainer.new()
		_row.add_theme_constant_override("separation", int(WEStyle.px(12)))
		_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		add_child(_row)
		rebuild()

	func _enter_tree() -> void:
		var ev := InputRouter.events()
		if not ev.source_changed.is_connected(_on_input_changed):
			ev.source_changed.connect(_on_input_changed)
			ev.bindings_changed.connect(_on_input_changed.bind(-1))
		rebuild()

	func _exit_tree() -> void:
		var ev := InputRouter.events()
		if ev.source_changed.is_connected(_on_input_changed):
			ev.source_changed.disconnect(_on_input_changed)
		for c in ev.bindings_changed.get_connections():
			if c["callable"].get_object() == self:
				ev.bindings_changed.disconnect(c["callable"])

	func _on_input_changed(_source: int) -> void:
		rebuild()

	func set_hints(p_hints: Array) -> void:
		hints = p_hints
		rebuild()

	func rebuild() -> void:
		for c in _row.get_children():
			_row.remove_child(c)
			c.queue_free()
		var name := WEStyle.make_body_label(screen.to_upper(), WEStyle.BODY_L, WEStyle.TEXT_DIM)
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_row.add_child(name)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_row.add_child(gap)
		for h in hints:
			var icon := ButtonIcons.get_hint(StringName(h[0]))
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_row.add_child(icon)
			var t := WEStyle.make_body_label(String(h[1]), WEStyle.BODY_L)
			t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_row.add_child(t)
			var sp := Control.new()
			sp.custom_minimum_size.x = WEStyle.px(24)
			_row.add_child(sp)


## Mini cancha con la formación (Dirección del club): césped a franjas,
## líneas finas y una ficha dorada por puesto (FormationLibrary.DEFINITIONS).
class FormationBoard:
	extends Control
	var formation := "4-4-2"

	func set_formation(name: String) -> void:
		formation = name
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var stripes := 8
		for i in stripes:
			draw_rect(Rect2(r.size.x * i / stripes, 0, r.size.x / stripes + 1, r.size.y),
				WEStyle.PITCH_DARK if i % 2 == 0 else WEStyle.PITCH_LIGHT)
		var m := Vector2(r.size.x * 0.05, r.size.y * 0.1)
		var f := Rect2(m, r.size - m * 2.0)
		var lc := Color(WEStyle.TEXT_MAIN, 0.55)
		draw_rect(f, lc, false, 1.0)
		draw_line(Vector2(f.get_center().x, f.position.y), Vector2(f.get_center().x, f.end.y), lc, 1.0)
		draw_arc(f.get_center(), f.size.y * 0.22, 0, TAU, 32, lc, 1.0)
		var bw := f.size.x * 0.1
		var bh := f.size.y * 0.56
		draw_rect(Rect2(f.position.x, f.get_center().y - bh * 0.5, bw, bh), lc, false, 1.0)
		draw_rect(Rect2(f.end.x - bw, f.get_center().y - bh * 0.5, bw, bh), lc, false, 1.0)
		var spots: Array = FormationLibrary.DEFINITIONS.get(formation, FormationLibrary.DEFINITIONS["4-4-2"])
		var min_x := INF
		var max_x := -INF
		for k in range(1, spots.size()):
			min_x = minf(min_x, float(spots[k][0]))
			max_x = maxf(max_x, float(spots[k][0]))
		var rad := maxf(3.0, f.size.y * 0.045)
		for k in spots.size():
			var x := 0.06 if k == 0 else lerpf(0.24, 0.84, (float(spots[k][0]) - min_x) / maxf(max_x - min_x, 0.001))
			var y := 0.5 + float(spots[k][1]) * 0.42
			var c := f.position + Vector2(f.size.x * x, f.size.y * y)
			draw_circle(c, rad, WEStyle.ACCENT)
			draw_arc(c, rad, 0, TAU, 16, WEStyle.BG_NIGHT, 1.0)


## Barra de secciones (pestañas) que se cambian con L1/R1 o Q/E: la elegida
## en dorado con una línea abajo.
class SectionTabs:
	extends HBoxContainer
	var tabs: Array = []
	var current := 0

	func _init(p_tabs: Array = [], p_current: int = 0) -> void:
		tabs = p_tabs
		current = p_current
		add_theme_constant_override("separation", int(WEStyle.px(28)))
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		rebuild()

	func select(i: int) -> void:
		current = i
		rebuild()

	func rebuild() -> void:
		for c in get_children():
			remove_child(c)
			c.queue_free()
		for i in tabs.size():
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", int(WEStyle.px(6)))
			var l := WEStyle.make_caption_label(String(tabs[i]), WEStyle.ACCENT if i == current else WEStyle.TEXT_DIM)
			v.add_child(l)
			var line := ColorRect.new()
			line.color = WEStyle.ACCENT if i == current else Color(0, 0, 0, 0)
			line.custom_minimum_size.y = WEStyle.FOCUS_BORDER
			v.add_child(line)
			add_child(v)


## Armazón de las pantallas del rediseño: fondo, encabezado (MASTER ELEVEN y
## la miga), título grande con un dato a la derecha, el cuerpo (body) y el pie
## de ayuda. Sin título (with_title = false) el cuerpo empieza bajo el encabezado.
class ScreenFrame:
	extends Control
	var body: VBoxContainer
	var crumb: Label
	var title: Label
	var title_info: Label
	var footer: HintFooter

	func _init(screen: String = "", hints: Array = [], with_title: bool = true) -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := ColorRect.new()
		bg.color = WEStyle.BG_NIGHT
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		var outer := VBoxContainer.new()
		outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		outer.add_theme_constant_override("separation", 0)
		add_child(outer)
		var margin := MarginContainer.new()
		margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_theme_constant_override("margin_left", int(WEStyle.px(WEStyle.MARGIN_X)))
		margin.add_theme_constant_override("margin_right", int(WEStyle.px(WEStyle.MARGIN_X)))
		margin.add_theme_constant_override("margin_top", int(WEStyle.px(WEStyle.MARGIN_Y)))
		margin.add_theme_constant_override("margin_bottom", int(WEStyle.px(24)))
		outer.add_child(margin)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", int(WEStyle.px(20)))
		margin.add_child(col)
		# Encabezado (como el menú principal).
		var head := HBoxContainer.new()
		head.add_child(WEStyle.make_title_label("MASTER ELEVEN", WEStyle.TITLE_L))
		head.add_child(WEStyle.make_gap())
		crumb = WEStyle.make_body_label("", WEStyle.BODY_L, WEStyle.TEXT_DIM)
		crumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(crumb)
		col.add_child(head)
		col.add_child(WEStyle.make_separator())
		var trow := HBoxContainer.new()
		title = WEStyle.make_title_label("", WEStyle.TITLE_XL)
		trow.add_child(title)
		trow.add_child(WEStyle.make_gap())
		title_info = WEStyle.make_body_label("", WEStyle.BODY_L, WEStyle.TEXT_DIM)
		title_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		trow.add_child(title_info)
		col.add_child(trow)
		var sep := WEStyle.make_separator()
		col.add_child(sep)
		trow.visible = with_title
		sep.visible = with_title
		body = VBoxContainer.new()
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", int(WEStyle.px(20)))
		col.add_child(body)
		footer = WEStyle.HintFooter.new(screen, hints)
		outer.add_child(footer)


## Armazón del diseño 03 "Mesa táctica": el de ScreenFrame con tres columnas
## separadas por líneas finas. Las pantallas llenan left/center/right.
class MesaFrame:
	extends ScreenFrame
	var left: VBoxContainer
	var center: VBoxContainer
	var right: VBoxContainer

	func _init(screen: String = "", hints: Array = [], left_w: float = 470.0, right_w: float = 380.0) -> void:
		super(screen, hints)
		var row := HBoxContainer.new()
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", int(WEStyle.px(40)))
		body.add_child(row)
		left = _column(WEStyle.px(left_w))
		row.add_child(left)
		row.add_child(WEStyle.make_vline())
		center = _column(0)
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(center)
		row.add_child(WEStyle.make_vline())
		right = _column(WEStyle.px(right_w))
		row.add_child(right)

	func _column(w: float) -> VBoxContainer:
		var v := VBoxContainer.new()
		v.custom_minimum_size.x = w
		v.add_theme_constant_override("separation", int(WEStyle.px(12)))
		return v

	## Vacía las tres columnas (para rearmar la pantalla).
	func clear_columns() -> void:
		for box in [left, center, right]:
			WEStyle.clear_children(box)


## Espacio que empuja lo que sigue al otro extremo de la fila.
static func make_gap() -> Control:
	var g := Control.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


## Línea vertical de 1 px (separa columnas).
static func make_vline() -> ColorRect:
	var r := ColorRect.new()
	r.color = LINE
	r.custom_minimum_size.x = BORDER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func clear_children(box: Node) -> void:
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()


## Botón de acción de las columnas ("Jugar el partido  ›"): el principal
## relleno de dorado al enfocarlo, el resto como los botones comunes.
static func make_action_button(text: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = "%s  ›" % text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = px(60)
	if primary:
		style_primary_button(b, BODY_L)
	else:
		style_button(b, BODY_L)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## Celdas de una fila de tabla con anchos fijos (en px de 1080; 0 = se
## estira) y alineación por columna en `align` ("L", "R" o "C"; los números
## a la derecha). En el encabezado van en caption.
static func make_cells(texts: Array, widths: Array, align: String = "", header: bool = false,
		color: Color = TEXT_MAIN, size: int = BODY_L) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", int(px(12)))
	for k in texts.size():
		var l: Label
		if header:
			l = make_caption_label(String(texts[k]), TEXT_DIM)
		else:
			l = make_body_label(String(texts[k]), size, color)
		l.clip_text = true
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var w: float = float(widths[k]) if k < widths.size() else 0.0
		if w <= 0.0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size.x = px(w)
		var a := align[k] if k < align.length() else "L"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if a == "R" else (HORIZONTAL_ALIGNMENT_CENTER if a == "C" else HORIZONTAL_ALIGNMENT_LEFT)
		h.add_child(l)
	return h


## Fila de tabla que toma el foco (plantel, mercado, Dirección): sin fondo y
## con una línea de 1 px abajo en reposo; con foco, el estilo de foco (borde
## dorado de 2 px + bg_panel_alt). `marked`: elegida (fondo alt y borde
## dorado fino), p. ej. el primer jugador de un intercambio.
static func make_row_button(cells: Control, marked: bool = false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size.y = px(ROW_H)
	for st in ["normal", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = BG_PANEL_ALT if marked else Color(0, 0, 0, 0)
		sb.border_color = ACCENT if marked else LINE
		if marked:
			sb.set_border_width_all(BORDER)
			sb.set_corner_radius_all(int(px(RADIUS_BUTTON)))
		else:
			sb.border_width_bottom = BORDER
		b.add_theme_stylebox_override(st, sb)
	for st in ["hover", "focus"]:
		b.add_theme_stylebox_override(st, make_focus_style(RADIUS_BUTTON))
	cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cells.offset_left = px(12)
	cells.offset_right = -px(12)
	b.add_child(cells)
	return b


## Tarjeta (panel con el padding de las tarjetas) para columnas laterales.
static func make_card(alt: bool = false) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", make_panel_style(alt))
	return pc


## Fila de tabla (o su encabezado): la primera celda fija, la segunda se
## estira (el equipo) y el resto son números alineados a la derecha. A la
## izquierda, una marca de color (ascenso, descenso, clasificados); tu club
## resaltado en dorado. Filas de ROW_H, encabezado de HEADER_ROW_H.
static func make_table_row(cells: Array, header: bool = false, me: bool = false,
		zone: Color = Color(0, 0, 0, 0), size: int = BODY_L) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_PANEL_ALT if me else Color(0, 0, 0, 0)
	sb.border_color = LINE
	sb.border_width_bottom = BORDER
	sb.content_margin_left = px(12)
	sb.content_margin_right = px(12)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size.y = px(HEADER_ROW_H if header else ROW_H)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(px(8)))
	pc.add_child(h)
	var mark := ColorRect.new()
	mark.color = zone
	mark.custom_minimum_size = Vector2(px(4), 0)
	h.add_child(mark)
	var color := ACCENT if me else (TEXT_DIM if header else TEXT_MAIN)
	for k in cells.size():
		var l: Label
		if header:
			l = make_caption_label(String(cells[k]), TEXT_DIM)
		else:
			l = make_body_label(String(cells[k]), size, color)
			if me:
				l.add_theme_font_override("font", font(Typeface.SEMIBOLD))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.clip_text = true
		if k == 0:
			l.custom_minimum_size.x = px(56)
		elif k == 1:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size.x = px(48)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	return pc


# --- Estilo anterior (WE2002), hasta que cada pantalla pase al rediseño ---------

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
## Si el valor no entra al lado del nombre, corre dentro de su lugar (como
## un cartel) en vez de pisar el nombre.
class OptionRow:
	extends Button
	const FS := 21
	const SCROLL_SPEED := 45.0
	const HOLD := 1.2
	var caption := ""
	var get_value: Callable
	var step: Callable
	var help := ""
	var _clip: Control
	var _val: Label
	var _overflow := 0.0
	var _t := 0.0
	## Con el estilo del rediseño (tokens) en vez de la barra violeta.
	var modern := false

	func _init(p_caption: String, p_get: Callable, p_step: Callable, p_help: String = "", width: float = 560.0) -> void:
		caption = p_caption
		get_value = p_get
		step = p_step
		help = p_help
		custom_minimum_size = Vector2(width, 38)
		add_theme_font_size_override("font_size", FS)
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		WEStyle.style_bar(self)
		_clip = Control.new()
		_clip.clip_contents = true
		_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_clip)
		_val = Label.new()
		_val.add_theme_font_size_override("font_size", FS)
		_val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clip.add_child(_val)
		pressed.connect(func() -> void: change(1))
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		refresh()

	## Pasa la fila al estilo del rediseño.
	func use_modern_style() -> void:
		modern = true
		WEStyle.style_button(self, WEStyle.BODY_L)
		_val.add_theme_font_override("font", WEStyle.font(WEStyle.Typeface.SEMIBOLD))
		_val.add_theme_font_size_override("font_size", WEStyle.font_px(WEStyle.BODY_L))
		custom_minimum_size.y = WEStyle.px(WEStyle.ROW_H)
		refresh()

	func _fs() -> int:
		return WEStyle.font_px(WEStyle.BODY_L) if modern else FS

	func change(dir: int) -> void:
		step.call(dir)
		refresh()

	func refresh() -> void:
		text = "%s" % caption
		var v := String(get_value.call())
		if v != _val.text:
			_val.text = v
			_t = 0.0
		_layout()
		queue_redraw()

	## El valor va pegado a la derecha; si no entra entre el nombre y la flecha,
	## se recorta y se mueve.
	func _layout() -> void:
		var font := WEStyle.font(WEStyle.Typeface.SEMIBOLD) if modern else get_theme_default_font()
		var cap_w := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs()).x + 18.0
		var end := size.x - 44.0
		var w := font.get_string_size(_val.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs()).x
		var avail := maxf(end - (cap_w + 40.0), 40.0)
		var vw := minf(w, avail)
		_overflow = maxf(w - vw, 0.0)
		_clip.position = Vector2(end - vw, 0.0)
		_clip.size = Vector2(vw, size.y)
		_val.size = Vector2(w, size.y)
		_val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_val.position = Vector2(-_scroll_offset(), 0.0)
		set_process(_overflow > 0.0)

	func _scroll_offset() -> float:
		if _overflow <= 0.0:
			return 0.0
		var move := _overflow / SCROLL_SPEED
		var cycle := HOLD + move + HOLD
		var t := fmod(_t, cycle)
		return clampf((t - HOLD) / move, 0.0, 1.0) * _overflow

	func _process(dt: float) -> void:
		_t += dt
		_val.position.x = -_scroll_offset()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and _clip != null:
			_layout()

	func _gui_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"ui_left"):
			change(-1)
			accept_event()
		elif event.is_action_pressed(&"ui_right"):
			change(1)
			accept_event()

	func _draw() -> void:
		var c := WEStyle.BAR_TEXT_FOCUS if has_focus() else Color.WHITE
		if modern:
			c = WEStyle.ACCENT if has_focus() else WEStyle.TEXT_MAIN
		_val.add_theme_color_override("font_color", c)
		var right := size.x - 22.0
		var cy := size.y * 0.5
		# Flechas ◀ ▶ a los costados del valor.
		draw_colored_polygon(PackedVector2Array([Vector2(right, cy), Vector2(right - 10, cy - 7), Vector2(right - 10, cy + 7)]), c)
		var lx := _clip.position.x - 14.0
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
		# De costado (la llave de las copas), si la caja se mueve en horizontal.
		if s.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			var hx := 0.0
			for dev in Input.get_connected_joypads():
				var a := Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X)
				if absf(a) > 0.25:
					hx = a
			if Input.is_key_pressed(KEY_END):
				hx = 1.0
			elif Input.is_key_pressed(KEY_HOME):
				hx = -1.0
			if hx != 0.0:
				s.scroll_horizontal += int(hx * SPEED * dt)


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
	## Fuente de la sigla (si no, la del tema).
	var label_font: Font = null

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
		var font := label_font if label_font != null else get_theme_default_font()
		var fs := int(h * (0.34 if label_font != null else 0.26))
		while fs > 8 and font.get_string_size(team.short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w * 0.62:
			fs -= 1
		var ink := Color.BLACK if team.color.get_luminance() > 0.5 else Color.WHITE
		if label_font != null:
			# Contorno para que las siglas se lean sobre las dos mitades del escudo.
			var halo := Color(Color.WHITE if ink == Color.BLACK else WEStyle.BG_NIGHT, 0.7)
			draw_string_outline(font, Vector2(0, h * 0.45), team.short_name, HORIZONTAL_ALIGNMENT_CENTER, w, fs,
				maxi(2, fs / 8), halo)
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

	## Con los tokens del rediseño (Barlow, barras doradas sobre la pista).
	var modern := false

	func _draw() -> void:
		if modern:
			_draw_modern()
			return
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

	func _draw_modern() -> void:
		var font := WEStyle.font(WEStyle.Typeface.SEMIBOLD)
		var fs := WEStyle.font_px(WEStyle.BODY_M)
		var row := size.y / NAMES.size()
		var bar_w := size.x * 0.32
		var bh := WEStyle.px(10)
		for i in NAMES.size():
			var y := row * i + row * 0.5
			draw_string(font, Vector2(0, y + fs * 0.35), String(NAMES[i]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, WEStyle.TEXT_DIM)
			draw_rect(Rect2(0, y - bh * 0.5, bar_w, bh), WEStyle.LINE)
			draw_rect(Rect2(size.x - bar_w, y - bh * 0.5, bar_w, bh), WEStyle.LINE)
			if i < home.size():
				var w := bar_w * home[i]
				draw_rect(Rect2(bar_w - w, y - bh * 0.5, w, bh), WEStyle.ACCENT)
			if i < away.size():
				draw_rect(Rect2(size.x - bar_w, y - bh * 0.5, bar_w * away[i], bh), WEStyle.ACCENT)
