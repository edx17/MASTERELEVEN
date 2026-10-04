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
var _hub: CompetitionHub
## Eligiendo el equipo para una Liga / Copa nueva (Competition.Kind) o -1.
var _new_competition := -1
var _history: Array[String] = []
var _focus_memory := {}


func _ready() -> void:
	# Se puede llegar desde un partido o la prueba de rendimiento con el juego
	# pausado (Start también abre la pausa): el menú siempre arranca andando.
	get_tree().paused = false
	Engine.time_scale = 1.0
	WEStyle.background(self)
	_start_music()
	_help = WEStyle.help_box(self)
	_build_home()
	_build_modes()
	_build_training()
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
	_hub = CompetitionHub.new()
	add_child(_hub)
	_hub.play_match.connect(_on_competition_match)
	_hub.back.connect(func() -> void:
		_history.clear()
		show_page("home", false))
	_pages["hub"] = _hub
	Input.joy_connection_changed.connect(func(_d: int, _c: bool) -> void: _refresh_modes())
	show_page("home")
	# Volviendo de un partido de Liga / Copa: se anota el resultado.
	if GameSettings.competition_match:
		GameSettings.competition_match = false
		var c := Competition.load_saved()
		if c != null:
			if not GameSettings.last_result.is_empty():
				c.complete_round(GameSettings.last_result)
				c.save()
			GameSettings.last_result = []
			show_page("hub")


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
	_help.get_parent().visible = page in ["home", "modes", "training", "options", "controls"]
	match page:
		"teams":
			_teams.open()
		"setup":
			_setup.open()
		"hub":
			_hub.open(Competition.load_saved())
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
		if _current() == "controls" and _controls_capturing():
			return
		go_back()
		get_viewport().set_input_as_handled()


func _controls_capturing() -> bool:
	var page: Control = _pages.get("controls")
	if page == null:
		return false
	for c in page.get_children():
		if c is ControlsPage and (c as ControlsPage).is_capturing():
			return true
	return false


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
	_item(col, "LIGA", "Campeonato todos contra todos con los 8 equipos. Se guarda entre partidos.",
		_open_competition.bind(Competition.Kind.LEAGUE))
	_item(col, "COPA", "Eliminación directa: cuartos, semis y final (con penales si empatan). Se guarda entre partidos.",
		_open_competition.bind(Competition.Kind.CUP))
	_item(col, "LIGA MASTER", "Próximamente (Fase 6): armá tu equipo, con mercado de pases, y llevalo a la cima.", Callable(), false)
	_item(col, "ENTRENAMIENTO", "Club House: práctica libre, pelota parada y desafíos con récord.", show_page.bind("training"))
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
	GameSettings.training = false
	GameSettings.set_mode(mode)
	GameSettings.human_side = 0
	GameSettings.competition_match = false
	_new_competition = -1
	_teams.single = false
	show_page("teams")


# --- Liga / Copa -----------------------------------------------------------------

## Sigue la competición guardada de ese tipo; si no hay, elegís tu equipo.
func _open_competition(kind: int) -> void:
	var saved := Competition.load_saved()
	if saved != null and saved.kind == kind and not saved.finished():
		show_page("hub")
		return
	_new_competition = kind
	_teams.single = true
	show_page("teams")


func _start_competition(kind: int, my_team: String) -> void:
	var paths := GameSettings.team_paths()
	var me := maxi(paths.find(my_team), 0)
	var c := Competition.create_league(paths, me, false) if kind == Competition.Kind.LEAGUE else Competition.create_cup(paths, me)
	c.save()
	_history.clear()
	_history.append("home")
	show_page("hub", false)


## Jugar el partido de la fecha: pasa por la configuración del partido.
func _on_competition_match(home: String, away: String, side: int) -> void:
	GameSettings.home_team_path = home
	GameSettings.away_team_path = away
	GameSettings.human_side = side
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	GameSettings.training = false
	GameSettings.competition_match = true
	show_page("setup")


func _on_teams_chosen(home: String, away: String) -> void:
	if _new_competition >= 0:
		var kind := _new_competition
		_new_competition = -1
		_teams.single = false
		_start_competition(kind, home)
		return
	GameSettings.home_team_path = home
	GameSettings.away_team_path = away
	if GameSettings.training:
		# Al Club House directo (sin configuración del partido ni presentación).
		GameSettings.save_settings()
		GameSettings.play_intro = false
		get_tree().change_scene_to_file(MATCH_SCENE)
		return
	show_page("setup")


# --- Entrenamiento -----------------------------------------------------------------

func _build_training() -> void:
	var p := _page("training")
	var title := WEStyle.label("ENTRENAMIENTO  ·  CLUB HOUSE", 30, Color(1.0, 0.9, 0.35))
	title.position = Vector2(80, 40)
	p.add_child(title)
	var col := _column(p, Vector2(80, 100))
	for k in TrainingSession.KIND_NAMES.size():
		_item(col, String(TrainingSession.KIND_NAMES[k]).to_upper(), TrainingSession.KIND_HELP[k],
			_choose_training.bind(k), true, 520.0)
	_item(col, "VOLVER", "Volver al menú principal.", go_back, true, 520.0)


## Elegís qué practicar; después, tu equipo y el rival.
func _choose_training(kind: int) -> void:
	GameSettings.training = true
	GameSettings.training_kind = kind
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	GameSettings.human_side = 0
	GameSettings.competition_match = false
	_new_competition = -1
	_teams.single = false
	show_page("teams")


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
		["Volumen de efectos", func() -> String: return str(GameSettings.sfx_volume),
			func(d: int) -> void: GameSettings.sfx_volume = clampi(GameSettings.sfx_volume + d, 0, 10),
			"Silbato del árbitro, patadas, piques, palo y red."],
		["Volumen del público", func() -> String: return str(GameSettings.crowd_volume),
			func(d: int) -> void: GameSettings.crowd_volume = clampi(GameSettings.crowd_volume + d, 0, 10),
			"El murmullo de la tribuna, los cánticos, los silbidos, los aplausos y los \"uhh\"."],
		["Volumen de la música", func() -> String: return str(GameSettings.music_volume),
			func(d: int) -> void:
				GameSettings.music_volume = clampi(GameSettings.music_volume + d, 0, 10)
				_update_music(),
			"La música de los menúes."],
		["Repeticiones", func() -> String:
				if not GameSettings.show_replays:
					return "no"
				return "goles y jugadas" if GameSettings.replay_chances else "sólo goles",
			func(d: int) -> void:
				# Goles y jugadas -> sólo goles -> no -> ...
				var v := (2 if GameSettings.replay_chances else 1) if GameSettings.show_replays else 0
				v = posmod(v - d, 3)
				GameSettings.show_replays = v > 0
				GameSettings.replay_chances = v == 2,
			"Repetición de los goles y de las jugadas peligrosas (remates cerca, atajadas, faltas). X / Start la saltea."],
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

func _build_controls() -> void:
	var p := _page("controls")
	var cp := ControlsPage.new()
	cp.help = _help
	cp.back_pressed.connect(go_back)
	p.add_child(cp)


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


# --- Música del menú (generada por código, MatchAudio.sound("menu_music")) ---

var _music: AudioStreamPlayer


func _start_music() -> void:
	_music = AudioStreamPlayer.new()
	_music.stream = MatchAudio.sound("menu_music")
	add_child(_music)
	_update_music()
	_music.play()


func _update_music() -> void:
	if _music != null:
		_music.volume_db = linear_to_db(maxf(0.0001, GameSettings.music_volume / 10.0 * 0.5))
