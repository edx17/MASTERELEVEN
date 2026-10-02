extends Control
## Menú principal al estilo del WE2002: barras a la izquierda (Partido, Liga,
## Copa, Liga Master, Entrenamiento, Editor, Opciones), el logo con la pelota
## a la derecha y una caja de ayuda abajo. Partido -> modo (vs CPU, 2
## jugadores, CPU vs CPU) -> elección de equipos -> configuración del partido
## -> la previa en el estadio.
## Navegable con teclado (flechas + Enter, Esc vuelve) o mando (cruceta, X,
## Círculo vuelve).

const MATCH_SCENE := "res://scenes/match/match.tscn"

var _pages := {}
var _help: Label
var _mode_two: Button
var _teams: TeamSelect
var _setup: MatchSetup
var _history: Array[String] = []
var _focus_memory := {}


func _ready() -> void:
	# Se puede llegar desde un partido o la prueba de rendimiento con el juego
	# pausado (Start también abre la pausa): el menú siempre arranca andando.
	get_tree().paused = false
	Engine.time_scale = 1.0
	WEStyle.background(self)
	_help = WEStyle.help_box(self)
	_build_home()
	_build_modes()
	_build_options()
	_build_controls()
	_teams = TeamSelect.new()
	add_child(_teams)
	_teams.chosen.connect(_on_teams_chosen)
	_teams.cancelled.connect(go_back)
	_pages["teams"] = _teams
	_setup = MatchSetup.new()
	add_child(_setup)
	_setup.play.connect(_start)
	_setup.back.connect(go_back)
	_pages["setup"] = _setup
	Input.joy_connection_changed.connect(func(_d: int, _c: bool) -> void: _refresh_modes())
	show_page("home")


# --- Navegación -------------------------------------------------------------------

func show_page(page: String, remember := true) -> void:
	var current := _current()
	if remember and current != "" and current != page:
		_history.append(current)
		var f := get_viewport().gui_get_focus_owner()
		if f != null:
			_focus_memory[current] = f
	for k in _pages:
		(_pages[k] as Control).visible = k == page
	# Las pantallas de equipos y partido traen su propia ayuda.
	_help.get_parent().visible = page in ["home", "modes", "options", "controls"]
	match page:
		"teams":
			_teams.open()
		"setup":
			_setup.open()
		_:
			var back_focus: Control = _focus_memory.get(page)
			if not remember and back_focus != null and is_instance_valid(back_focus):
				back_focus.grab_focus()
			else:
				_first_focus(_pages[page])


func go_back() -> void:
	if _history.is_empty():
		return
	show_page(_history.pop_back(), false)


func _current() -> String:
	for k in _pages:
		if (_pages[k] as Control).visible:
			return k
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _current() in ["modes", "options", "controls"]:
		go_back()
		get_viewport().set_input_as_handled()


func _first_focus(node: Node) -> void:
	for c in node.get_children():
		if c is Button and not (c as Button).disabled and (c as Button).visible:
			(c as Button).grab_focus()
			return
		_first_focus(c)
		if get_viewport().gui_get_focus_owner() != null and node.is_ancestor_of(get_viewport().gui_get_focus_owner()):
			return


func _page(name: String) -> Control:
	var p := Control.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	move_child(p, 1)
	_pages[name] = p
	return p


func _column(parent: Control, pos: Vector2) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.position = pos
	col.add_theme_constant_override("separation", 8)
	parent.add_child(col)
	return col


func _item(col: VBoxContainer, text: String, help: String, cb: Callable, enabled := true, width := 360.0) -> Button:
	var b := WEStyle.bar(text, cb, width)
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_ALL
	b.focus_entered.connect(func() -> void: _help.text = help)
	b.mouse_entered.connect(func() -> void: _help.text = help)
	col.add_child(b)
	return b


# --- Inicio ---------------------------------------------------------------------

func _build_home() -> void:
	var p := _page("home")
	var col := _column(p, Vector2(80, 80))
	_item(col, "PARTIDO", "Jugá un partido amistoso: contra la CPU, de a dos o mirá CPU contra CPU.", show_page.bind("modes"))
	_item(col, "LIGA", "Próximamente (Fase 7): un campeonato todos contra todos.", Callable(), false)
	_item(col, "COPA", "Próximamente (Fase 7): copas por grupos y eliminación.", Callable(), false)
	_item(col, "LIGA MASTER", "Próximamente (Fase 6): armá tu equipo, con mercado de pases, y llevalo a la cima.", Callable(), false)
	_item(col, "ENTRENAMIENTO", "Próximamente: práctica libre, tiros libres y penales.", Callable(), false)
	_item(col, "EDITOR", "Próximamente: crear y editar jugadores y equipos.", Callable(), false)
	_item(col, "OPCIONES", "Controles, velocidad del juego, ayudas y prueba de rendimiento.", show_page.bind("options"))
	_item(col, "SALIR", "Cerrar el juego.", get_tree().quit)
	var logo := Logo.new()
	logo.position = Vector2(700, 60)
	logo.size = Vector2(520, 520)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(logo)


# --- Modo -----------------------------------------------------------------------

func _build_modes() -> void:
	var p := _page("modes")
	var title := WEStyle.label("PARTIDO AMISTOSO", 30, Color(1.0, 0.9, 0.35))
	title.position = Vector2(80, 40)
	p.add_child(title)
	var col := _column(p, Vector2(80, 100))
	_item(col, "1 JUGADOR vs CPU", "Vos contra la computadora.", _choose_mode.bind(GameSettings.Mode.VS_CPU), true, 460.0)
	_mode_two = _item(col, "2 JUGADORES", "Uno contra otro (hace falta un mando para el segundo).",
		_choose_mode.bind(GameSettings.Mode.TWO_PLAYERS), true, 460.0)
	_item(col, "CPU vs CPU", "Mirá un partido entre la computadora y la computadora.",
		_choose_mode.bind(GameSettings.Mode.CPU_VS_CPU), true, 460.0)
	_item(col, "VOLVER", "Volver al menú principal.", go_back, true, 460.0)
	_refresh_modes()


func _refresh_modes() -> void:
	if _mode_two != null:
		_mode_two.disabled = not InputRouter.can_play_two_players()


func _choose_mode(mode: int) -> void:
	GameSettings.set_mode(mode)
	show_page("teams")


func _on_teams_chosen(home: String, away: String) -> void:
	GameSettings.home_team_path = home
	GameSettings.away_team_path = away
	show_page("setup")


func _start() -> void:
	GameSettings.save_settings()
	GameSettings.play_intro = true
	get_tree().change_scene_to_file(MATCH_SCENE)


# --- Opciones -------------------------------------------------------------------

func _build_options() -> void:
	var p := _page("options")
	var title := WEStyle.label("OPCIONES", 30, Color(1.0, 0.9, 0.35))
	title.position = Vector2(80, 40)
	p.add_child(title)
	var col := _column(p, Vector2(80, 100))
	col.add_theme_constant_override("separation", 6)
	_item(col, "CONTROLES", "Qué hace cada botón al atacar y al defender.", show_page.bind("controls"), true, 640.0)
	var rows := [
		["Velocidad del juego", func() -> String: return "%+d" % GameSettings.game_speed,
			func(d: int) -> void: GameSettings.game_speed = clampi(GameSettings.game_speed + d, -2, 2),
			"Más lento o más rápido (el reloj del partido no cambia)."],
		["Movimiento", func() -> String: return ("%d direcciones" % GameSettings.stick_directions) if GameSettings.stick_directions > 0 else "libre",
			func(d: int) -> void:
				var o := GameSettings.STICK_OPTIONS
				GameSettings.stick_directions = o[posmod(o.find(GameSettings.stick_directions) + d, o.size())],
			"8 o 16 rumbos como en el WE, o libre."],
		["Sobre los jugadores", func() -> String: return GameSettings.PLAYER_LABEL_NAMES[GameSettings.player_label],
			func(d: int) -> void: GameSettings.player_label = posmod(GameSettings.player_label + d, GameSettings.PLAYER_LABEL_NAMES.size()),
			"Qué se ve arriba de los jugadores."],
		["Arquero a los 6 s", func() -> String: return GameSettings.KEEPER_AUTO_NAMES[GameSettings.keeper_auto_action],
			func(_d: int) -> void: GameSettings.keeper_auto_action = 1 - GameSettings.keeper_auto_action,
			"Qué hace tu arquero si no la soltaste a tiempo."],
	]
	for r in rows:
		var row := WEStyle.OptionRow.new(r[0], r[1], func(d: int) -> void:
			(r[2] as Callable).call(d)
			GameSettings.save_settings(), r[3], 640.0)
		var help: String = r[3]
		row.focus_entered.connect(func() -> void: _help.text = help)
		col.add_child(row)
	_item(col, "PRUEBA DE RENDIMIENTO (30 s)", "Mide los cuadros por segundo de tu máquina con un partido CPU vs CPU.",
		GameSettings.start_benchmark, true, 640.0)
	_item(col, "VOLVER", "Volver al menú principal.", go_back, true, 640.0)


# --- Controles ------------------------------------------------------------------

## [ataque, botón del mando, tecla, defensa]
const CONTROLS := [
	["Pase corto", "X", "J", "Entrada"],
	["Remate (2 toques: raso)", "Cuadrado", "K", "Presión de un compañero"],
	["Centro / pase largo", "Círculo", "L", "Barrida"],
	["Pase al hueco", "Triángulo", "I", "Sale el arquero"],
	["Gambetas y combinaciones", "L1", "Q", "Cambio de jugador"],
	["Correr", "R1", "Shift", "Correr"],
	["Frenar / tiro colocado", "R2", "E", "-"],
	["Estrategia (L2 + botón)", "L2", "R", "Estrategia (L2 + botón)"],
	["Cámara", "Select", "C", "Cámara"],
	["Pausa", "Start", "Esc", "Pausa"],
]


func _build_controls() -> void:
	var p := _page("controls")
	var title := WEStyle.label("CONFIGURAR CONTROLES", 30, Color(1.0, 0.9, 0.35))
	title.position = Vector2(80, 40)
	p.add_child(title)
	var pc := WEStyle.panel(Vector2(1120, 0))
	pc.position = Vector2(80, 90)
	p.add_child(pc)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 6)
	pc.add_child(grid)
	for h in ["ATAQUE", "MANDO", "TECLADO", "DEFENSA"]:
		grid.add_child(WEStyle.label(h, 20, Color(1.0, 0.9, 0.35)))
	for row in CONTROLS:
		for i in 4:
			var l := WEStyle.label(row[i], 19, Color(0.6, 0.85, 1.0) if i in [1, 2] else Color.WHITE)
			if i == 0 or i == 3:
				l.custom_minimum_size = Vector2(360, 0)
			grid.add_child(l)
	var col := _column(p, Vector2(80, 520))
	_item(col, "VOLVER", "Mover: stick izquierdo o cruceta (WASD con teclado). Stick derecho: comba en la pelota parada y marsellesa. Cambiar los botones: próximamente.", go_back)


## Logo del menú: el nombre y una pelota (dibujada, sin marcas).
class Logo:
	extends Control
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		var c := Vector2(size.x * 0.5, size.y * 0.52)
		var r := size.x * 0.3
		draw_circle(c, r * 1.25, Color(0.6, 0.55, 1.0, 0.12))
		draw_circle(c, r, Color(0.92, 0.93, 0.98))
		# Gajos de la pelota que giran despacio.
		for i in 5:
			var a := _t * 0.4 + TAU * i / 5.0
			var p := c + Vector2(cos(a), sin(a)) * r * 0.55
			var pts := PackedVector2Array()
			for k in 5:
				var b := a + TAU * k / 5.0
				pts.append(p + Vector2(cos(b), sin(b)) * r * 0.2)
			draw_colored_polygon(pts, Color(0.2, 0.2, 0.42))
		var pts2 := PackedVector2Array()
		for k in 5:
			var b := -_t * 0.4 + TAU * k / 5.0 - PI * 0.5
			pts2.append(c + Vector2(cos(b), sin(b)) * r * 0.22)
		draw_colored_polygon(pts2, Color(0.2, 0.2, 0.42))
		draw_arc(c, r, 0, TAU, 64, Color(0.4, 0.4, 0.8), 3.0)
		var title := "MASTER ELEVEN"
		draw_string_outline(font, Vector2(0, 54), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 50, 10, Color(0.1, 0.1, 0.35))
		draw_string(font, Vector2(0, 54), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 50, Color(1.0, 0.88, 0.3))
		draw_string(font, Vector2(0, size.y - 10), "fútbol de los de antes", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(0.8, 0.85, 1.0))


## Miniatura del estadio `i` (-1 = al azar: un recuadro neutro).
static func stadium_thumbnail(i: int) -> Texture2D:
	var path := "res://assets/ui/stadiums/%d.png" % i
	if i >= 0 and ResourceLoader.exists(path):
		return load(path)
	var img := Image.create(16, 9, false, Image.FORMAT_RGB8)
	img.fill(Color(0.18, 0.2, 0.24))
	return ImageTexture.create_from_image(img)
