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
var _continue_btn: Button
var _continue_col: VBoxContainer
var _history: Array[String] = []
var _focus_memory := {}
## La pantalla de título (Press START) sale sólo al abrir el juego.
static var title_seen := false


func _ready() -> void:
	# Se puede llegar desde un partido o la prueba de rendimiento con el juego
	# pausado (Start también abre la pausa): el menú siempre arranca andando.
	get_tree().paused = false
	Engine.time_scale = 1.0
	WEStyle.background(self)
	_start_music()
	_help = WEStyle.help_box(self)
	_build_title()
	_build_home()
	_build_continue()
	_build_modes()
	_build_training()
	_build_world_cup()
	_build_options()
	_build_data()
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
	if title_seen:
		show_page("home")
	else:
		show_page("title", false)
	# Volviendo de un partido de Liga / Copa: se anota el resultado.
	if GameSettings.competition_match:
		GameSettings.competition_match = false
		var c := Competition.load_saved(GameSettings.active_save)
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
	_help.get_parent().visible = page in ["home", "modes", "training", "options", "controls", "worldcup", "continue", "data"]
	if page == "home" and _continue_btn != null:
		_continue_btn.disabled = Competition.list_saves().is_empty()
	if page == "title":
		return
	match page:
		"teams":
			_teams.open()
		"setup":
			_setup.open()
		"hub":
			_hub.open(Competition.load_saved(GameSettings.active_save))
		"continue":
			_build_continue_list()
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
	if _current() == "title":
		if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_accept") \
				or (event is InputEventMouseButton and event.pressed):
			leave_title()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel") and _current() in ["modes", "options", "controls", "worldcup", "continue", "data"]:
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


# --- Título -----------------------------------------------------------------------

## Pantalla de título como la del WE2002: estadio en alambre azul, el logo
## amarillo y rojo, "Press START Button" titilando y el copyright.
func _build_title() -> void:
	var p := _page("title")
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.01, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bg)
	var t := TitleScreen.new()
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(t)


func leave_title() -> void:
	title_seen = true
	_ui_sound("menu_select")
	show_page("home", false)


# --- Inicio ---------------------------------------------------------------------

func _build_home() -> void:
	var p := _page("home")
	var col := _column(p, Vector2(80, 60))
	col.add_theme_constant_override("separation", 6)
	_continue_btn = _item(col, "CONTINUAR", "Seguir una Liga, Copa o Mundial guardados (cada uno en su archivo).",
		show_page.bind("continue"))
	_item(col, "PARTIDO", "Jugá un partido amistoso: contra la CPU, de a dos o mirá CPU contra CPU.", show_page.bind("modes"))
	_item(col, "LIGA", "Campeonato todos contra todos con los 8 equipos. Se guarda entre partidos.",
		_open_competition.bind(Competition.Kind.LEAGUE))
	_item(col, "COPA", "Eliminación directa: cuartos, semis y final (con penales si empatan). Se guarda entre partidos.",
		_open_competition.bind(Competition.Kind.CUP))
	_item(col, "MUNDIAL 2026", "48 selecciones: 12 grupos de 4, pasan dos por grupo y los 8 mejores terceros, después 16avos hasta la final.",
		_open_world_cup)
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
	_item(col, "TANDA DE PENALES", "Sólo la definición por penales: cinco por equipo y, si siguen iguales, muerte súbita.",
		_choose_mode.bind(GameSettings.Mode.VS_CPU, true), true, 460.0)
	_item(col, "VOLVER", "Volver al menú principal.", go_back, true, 460.0)
	_refresh_modes()


func _refresh_modes() -> void:
	if _mode_two != null:
		_mode_two.disabled = not InputRouter.can_play_two_players()


func _choose_mode(mode: int, shootout := false) -> void:
	GameSettings.training = false
	GameSettings.shootout = shootout
	GameSettings.set_mode(mode)
	GameSettings.human_side = 0
	GameSettings.competition_match = false
	_new_competition = -1
	_teams.single = false
	_teams.only_paths = []
	show_page("teams")


# --- Liga / Copa -----------------------------------------------------------------

## Sigue la competición guardada de ese tipo; si no hay, elegís tu equipo.
## Liga / Copa nueva (las guardadas se siguen desde CONTINUAR).
func _open_competition(kind: int) -> void:
	_new_competition = kind
	_teams.single = true
	_teams.only_paths = []
	show_page("teams")


func _start_competition(kind: int, my_team: String) -> void:
	_teams.only_paths = []
	var c: Competition
	if kind == Competition.Kind.WORLD_CUP:
		var wc := world_cup_paths(GameSettings.wc_playoff)
		c = Competition.create_world_cup(wc, maxi(wc.find(my_team), 0), 0,
			[TeamDB.nation_path("usa"), TeamDB.nation_path("mex"), TeamDB.nation_path("can")])
		c.option_file = GameSettings.active_optionfile
		c.save()
		GameSettings.active_save = c.file
		_history.clear()
		_history.append("home")
		show_page("hub", false)
		return
	var paths := competition_paths(kind, my_team, _teams.group_paths_of(my_team))
	var me := maxi(paths.find(my_team), 0)
	c = Competition.create_league(paths, me, false) if kind == Competition.Kind.LEAGUE else Competition.create_cup(paths, me)
	c.option_file = GameSettings.active_optionfile
	var g := _teams.group_of(my_team)
	if g >= 0 and _teams.groups[g].get("kind", "") == "division":
		c.title = "%s · %s" % [String(_teams.groups[g]["name"]).get_slice("·", 1).strip_edges(), c.team(me).team_name]
	c.save()
	GameSettings.active_save = c.file
	_history.clear()
	_history.append("home")
	show_page("hub", false)


## Equipos de la Liga o la Copa según el equipo elegido: en la Liga, toda
## su división (si es un club real) o los 8 Equipos WE; con una selección,
## ella y 7 más. La Copa siempre es de 8 (el tuyo y 7 de su grupo al azar).
static func competition_paths(kind: int, my_team: String, group: Array[String]) -> Array[String]:
	var out: Array[String] = []
	if group.is_empty() or not group.has(my_team):
		out = GameSettings.team_paths()
		if not out.has(my_team):
			out[0] = my_team
		return out
	if kind == Competition.Kind.LEAGUE and my_team.begins_with("db:club:"):
		return group.duplicate()
	if group.size() <= 8:
		return group.duplicate()
	var others := group.filter(func(p: String) -> bool: return p != my_team)
	others.shuffle()
	out.append(my_team)
	for i in 7:
		out.append(others[i])
	return out


# --- Continuar ------------------------------------------------------------------------

func _build_continue() -> void:
	var p := _page("continue")
	var title := WEStyle.label("CONTINUAR", 30, Color(1.0, 0.9, 0.35))
	title.position = Vector2(80, 40)
	p.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(80, 96)
	scroll.size = Vector2(1000, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	p.add_child(scroll)
	_continue_col = VBoxContainer.new()
	_continue_col.add_theme_constant_override("separation", 6)
	scroll.add_child(_continue_col)


## Lista de partidas guardadas: "Liga Profesional · Boca — Fecha 7 de 29".
func _build_continue_list() -> void:
	for c in _continue_col.get_children():
		_continue_col.remove_child(c)
		c.queue_free()
	var saves := Competition.list_saves()
	for sv in saves:
		var text := "%s   —   %s" % [sv["title"], sv["progress"]]
		var help := "Guardada %s." % String(sv["updated"]).replace("T", " ")
		if String(sv["option_file"]) != "":
			help += " Option File: %s." % sv["option_file"]
		_item(_continue_col, text, help, open_save.bind(String(sv["file"])), true, 960.0)
	_item(_continue_col, "VOLVER", "Volver al menú principal.", go_back, true, 960.0)
	if saves.is_empty():
		_help.text = "No hay partidas guardadas."
	_first_focus(_continue_col)


## Sigue una partida guardada (con el Option File con el que se creó).
func open_save(file: String) -> void:
	var c := Competition.load_saved(file)
	if c == null:
		return
	if c.option_file != GameSettings.active_optionfile and (c.option_file == "" or OptionFile.load_named(c.option_file) != null):
		GameSettings.active_optionfile = c.option_file
		GameSettings.apply_option_file()
		GameSettings.save_settings()
	GameSettings.active_save = file
	_history.clear()
	_history.append("home")
	show_page("hub", false)


# --- Mundial 2026 ------------------------------------------------------------------

## Las 48 del Mundial: las 42 clasificadas y las 6 elegidas del repechaje (si
## la elección no son 6 válidas, las primeras 6 candidatas por nivel).
static func world_cup_paths(picks: Array) -> Array[String]:
	var out: Array[String] = []
	var candidates: Array = []
	for n in TeamDB.nations():
		if n["wc"] == "q":
			out.append(TeamDB.nation_path(n["id"]))
		elif n["wc"] == "po":
			candidates.append(n)
	var chosen := candidates.filter(func(n: Dictionary) -> bool: return picks.has(n["id"]))
	if chosen.size() != GameSettings.WC_PLAYOFF_SLOTS:
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) > int(b["level"]))
		chosen = candidates.slice(0, GameSettings.WC_PLAYOFF_SLOTS)
	for n in chosen:
		out.append(TeamDB.nation_path(n["id"]))
	return out


var _wc_rows: Array[Button] = []
var _wc_count: Label


## Página del Mundial: elegir los 6 cupos del repechaje y después tu selección.
func _build_world_cup() -> void:
	var p := _page("worldcup")
	var title := WEStyle.label("MUNDIAL 2026", 30, Color(1.0, 0.9, 0.35))
	title.position = Vector2(80, 40)
	p.add_child(title)
	_wc_count = WEStyle.label("", 20, Color(0.75, 0.85, 1.0))
	_wc_count.position = Vector2(80, 82)
	p.add_child(_wc_count)
	# Las 12 candidatas en dos columnas y abajo los botones.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(80, 120)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 6)
	p.add_child(grid)
	for n in TeamDB.nations():
		if n["wc"] != "po":
			continue
		var id: String = n["id"]
		var cell := VBoxContainer.new()
		grid.add_child(cell)
		var b := _item(cell, "", "Repechaje: elegí cuáles 6 de estas 12 juegan el Mundial.", func() -> void:
			if GameSettings.wc_playoff.has(id):
				GameSettings.wc_playoff.erase(id)
			elif GameSettings.wc_playoff.size() < GameSettings.WC_PLAYOFF_SLOTS:
				GameSettings.wc_playoff.append(id)
			GameSettings.save_settings()
			_refresh_world_cup(), true, 360.0)
		b.custom_minimum_size.y = 34
		b.add_theme_font_size_override("font_size", 19)
		b.set_meta("nation", id)
		b.set_meta("label", n["name"])
		_wc_rows.append(b)
	var col := _column(p, Vector2(80, 400))
	_item(col, "ELEGIR MI SELECCIÓN", "Las 42 clasificadas más las 6 del repechaje. Después, el sorteo de los grupos.",
		_world_cup_pick_team, true, 460.0)
	_item(col, "VOLVER", "Volver al menú principal.", go_back, true, 460.0)
	_refresh_world_cup()


func _refresh_world_cup() -> void:
	for b in _wc_rows:
		var on := GameSettings.wc_playoff.has(b.get_meta("nation"))
		b.text = "%s  %s" % ["■" if on else "□", b.get_meta("label")]
	_wc_count.text = "Cupos del repechaje: %d de %d elegidos" % [GameSettings.wc_playoff.size(), GameSettings.WC_PLAYOFF_SLOTS]


func _open_world_cup() -> void:
	show_page("worldcup")


func _world_cup_pick_team() -> void:
	if GameSettings.wc_playoff.size() != GameSettings.WC_PLAYOFF_SLOTS:
		_help.text = "Elegí exactamente %d selecciones del repechaje." % GameSettings.WC_PLAYOFF_SLOTS
		return
	_new_competition = Competition.Kind.WORLD_CUP
	_teams.single = true
	_teams.only_paths = world_cup_paths(GameSettings.wc_playoff)
	show_page("teams")


## Jugar el partido de la fecha: pasa por la configuración del partido.
func _on_competition_match(home: String, away: String, side: int) -> void:
	GameSettings.home_team_path = home
	GameSettings.away_team_path = away
	GameSettings.human_side = side
	GameSettings.set_mode(GameSettings.Mode.VS_CPU)
	GameSettings.training = false
	GameSettings.shootout = false
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
	GameSettings.shootout = false
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
	var col := _column(p, Vector2(80, 92))
	col.add_theme_constant_override("separation", 3)
	_item(col, "CONTROLES", "Qué hace cada botón al atacar y al defender.", show_page.bind("controls"), true, 640.0)
	_item(col, "DATOS", "Option File (tus cambios sobre la base), importar planteles y carpetas del juego.",
		show_page.bind("data"), true, 640.0)
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
		row.custom_minimum_size.y = 36
		row.focus_entered.connect(func() -> void: _help.text = help)
		col.add_child(row)
	_item(col, "PRUEBA DE RENDIMIENTO (30 s)", "Mide los cuadros por segundo de tu máquina con un partido CPU vs CPU.",
		GameSettings.start_benchmark, true, 640.0)
	_item(col, "VOLVER", "Volver al menú principal.", go_back, true, 640.0)


# --- Datos: Option File, importar planteles, carpetas ------------------------------

var _data_rows: Array[WEStyle.OptionRow] = []
var _data_status: Label


func _build_data() -> void:
	var p := _page("data")
	var title := WEStyle.label("DATOS", 30, Color(1.0, 0.9, 0.35))
	title.position = Vector2(80, 40)
	p.add_child(title)
	var col := _column(p, Vector2(80, 100))
	col.add_theme_constant_override("separation", 6)
	var of_row := WEStyle.OptionRow.new("Option File activo", func() -> String:
			return GameSettings.active_optionfile if GameSettings.active_optionfile != "" else "ninguno (base del juego)",
		func(d: int) -> void:
			var names := [""]
			for o in OptionFile.list():
				names.append(o["name"])
			var i := names.find(GameSettings.active_optionfile)
			_set_option_file(names[posmod(i + d, names.size())]),
		"Tus cambios (planteles importados, ediciones) van al Option File activo. La base del juego no se toca.", 760.0)
	of_row.focus_entered.connect(func() -> void: _help.text = of_row.help)
	col.add_child(of_row)
	_data_rows.append(of_row)
	_item(col, "IMPORTAR PLANTELES", "Lee todos los CSV de la carpeta \"importar\" (EA FC / SoFIFA, Transfermarkt o tu planilla) y los guarda en el Option File activo (si no hay, crea \"Mi Option File\").",
		_import_squads, true, 760.0)
	_item(col, "ABRIR CARPETA DE IMPORTAR", "Abre la carpeta donde dejás los CSV de planteles.",
		func() -> void: UserData.open_folder(UserData.import_dir()), true, 760.0)
	_item(col, "ABRIR CARPETA DE OPTION FILES", "Para copiar un Option File (.meof) de otra PC o pasarle el tuyo a alguien: aparecen solos en la lista.",
		func() -> void: UserData.open_folder(UserData.optionfiles_dir()), true, 760.0)
	_item(col, "ABRIR CARPETA DEL JUEGO", "Documentos/MasterEleven: configuración, Option Files, partidas guardadas e importar.",
		func() -> void: UserData.open_folder(UserData.root()), true, 760.0)
	_item(col, "VOLVER A LA BASE", "Deja de usar el Option File (no lo borra: lo podés volver a elegir).",
		func() -> void: _set_option_file(""), true, 760.0)
	_item(col, "VOLVER", "Volver a Opciones.", go_back, true, 760.0)
	_data_status = WEStyle.label("", 18, Color(0.75, 0.9, 0.75))
	_data_status.position = Vector2(880, 100)
	_data_status.size = Vector2(360, 480)
	_data_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(_data_status)


func _set_option_file(name: String) -> void:
	GameSettings.active_optionfile = name
	GameSettings.apply_option_file()
	GameSettings.save_settings()
	_teams.groups = TeamSelect.build_groups()
	for r in _data_rows:
		r.refresh()
	_data_status.text = "Usando: %s" % (name if name != "" else "la base del juego")


func _import_squads() -> void:
	var of: OptionFile = null
	if GameSettings.active_optionfile != "":
		of = OptionFile.load_named(GameSettings.active_optionfile)
	if of == null:
		of = OptionFile.new()
		of.name = "Mi Option File"
	_data_status.text = "Importando..."
	var imp := SquadImporter.new()
	# Se reparte sobre la base con lo que ya tenga este Option File.
	TeamDB.use_option_file(of)
	var res := imp.import_folder(UserData.import_dir(), of)
	if int(res["files"]) == 0:
		_data_status.text = "No hay archivos CSV en la carpeta de importar.\n\n%s" % UserData.import_dir()
		GameSettings.apply_option_file()
		return
	_set_option_file(of.name)
	var lines := ["Listo: %d archivo(s), %d filas." % [res["files"], res["rows"]],
		"%d jugadores en %d clubes." % [res["players"], res["clubs"]],
		"%d selecciones armadas." % res["nations"],
		"Guardado en el Option File \"%s\"." % of.name]
	if int(res["unmatched_clubs"]) > 0:
		lines.append("")
		lines.append("%d clubes del archivo no están en la base:" % res["unmatched_clubs"])
		for l in imp.report.slice(1, 13):
			lines.append(l.strip_edges())
	_data_status.text = "\n".join(lines)


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


## Título: estadio de alambre que gira despacio, logo y "Press START".
class TitleScreen:
	extends Control
	var t := 0.0

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	## Punto 3D (x, y, z en m) a pantalla, con la cámara girando alrededor.
	func blink_on() -> bool:
		return fmod(t, 1.4) < 1.0

	func _proj(v: Vector3) -> Vector2:
		var a := t * 0.12
		var x := v.x * cos(a) - v.z * sin(a)
		var z := v.x * sin(a) + v.z * cos(a) + 175.0
		var y := v.y - 95.0
		# Cámara alta mirando al centro de la cancha.
		var pitch := atan2(95.0, 175.0)
		var yy := y * cos(pitch) + z * sin(pitch)
		var zz := -y * sin(pitch) + z * cos(pitch)
		var f := size.y * 1.5
		return Vector2(size.x * 0.5 + x * f / zz, size.y * 0.66 - yy * f / zz)

	func _line(a: Vector3, b: Vector3, c: Color, w: float = 1.0) -> void:
		draw_line(_proj(a), _proj(b), c, w, true)

	func _draw() -> void:
		var blue := Color(0.2, 0.45, 1.0, 0.75)
		var dim := Color(0.15, 0.3, 0.8, 0.4)
		# Cancha.
		var hl := 52.5
		var hw := 34.0
		var corners := [Vector3(-hl, 0, -hw), Vector3(hl, 0, -hw), Vector3(hl, 0, hw), Vector3(-hl, 0, hw)]
		for i in 4:
			_line(corners[i], corners[(i + 1) % 4], blue, 1.5)
		_line(Vector3(0, 0, -hw), Vector3(0, 0, hw), blue)
		var prev := Vector3(9.15, 0, 0)
		for k in range(1, 25):
			var a := TAU * k / 24.0
			var cur := Vector3(cos(a) * 9.15, 0, sin(a) * 9.15)
			_line(prev, cur, blue)
			prev = cur
		for sx in [-1.0, 1.0]:
			var x0: float = sx * hl
			var x1: float = sx * (hl - 16.5)
			_line(Vector3(x0, 0, -20.16), Vector3(x1, 0, -20.16), blue)
			_line(Vector3(x1, 0, -20.16), Vector3(x1, 0, 20.16), blue)
			_line(Vector3(x1, 0, 20.16), Vector3(x0, 0, 20.16), blue)
			_line(Vector3(x0, 0, -3.66), Vector3(x0, 2.44, -3.66), blue, 2.0)
			_line(Vector3(x0, 2.44, -3.66), Vector3(x0, 2.44, 3.66), blue, 2.0)
			_line(Vector3(x0, 2.44, 3.66), Vector3(x0, 0, 3.66), blue, 2.0)
		# Tribunas: anillos escalonados y costillas.
		for ring in 5:
			var e := 8.0 + ring * 7.0
			var h := 2.0 + ring * 5.0
			var pts: Array[Vector3] = []
			for k in 41:
				var a := TAU * k / 40.0
				var c := cos(a)
				var sn := sin(a)
				pts.append(Vector3(signf(c) * pow(absf(c), 0.6) * (hl + e), h, signf(sn) * pow(absf(sn), 0.6) * (hw + e)))
			for k in 40:
				_line(pts[k], pts[k + 1], blue if ring % 2 == 0 else dim)
		for k in 40:
			var a := TAU * k / 40.0
			var c := cos(a)
			var sn := sin(a)
			var lo := Vector3(signf(c) * pow(absf(c), 0.6) * (hl + 8.0), 2.0, signf(sn) * pow(absf(sn), 0.6) * (hw + 8.0))
			var hi := Vector3(signf(c) * pow(absf(c), 0.6) * (hl + 36.0), 22.0, signf(sn) * pow(absf(sn), 0.6) * (hw + 36.0))
			_line(lo, hi, dim)
		# Logo: "MASTER" amarillo y "ELEVEN" rojo, con borde oscuro.
		var font := get_theme_default_font()
		var cx := size.x * 0.5
		var y0 := size.y * 0.24
		draw_string_outline(font, Vector2(0, y0), "MASTER", HORIZONTAL_ALIGNMENT_CENTER, size.x, 96, 18, Color(0.02, 0.02, 0.12))
		draw_string(font, Vector2(0, y0), "MASTER", HORIZONTAL_ALIGNMENT_CENTER, size.x, 96, Color(1.0, 0.86, 0.15))
		draw_string_outline(font, Vector2(0, y0 + 96), "ELEVEN", HORIZONTAL_ALIGNMENT_CENTER, size.x, 96, 18, Color(0.02, 0.02, 0.12))
		draw_string(font, Vector2(0, y0 + 96), "ELEVEN", HORIZONTAL_ALIGNMENT_CENTER, size.x, 96, Color(0.92, 0.12, 0.12))
		draw_line(Vector2(cx - 260, y0 + 120), Vector2(cx + 260, y0 + 120), Color(1.0, 0.86, 0.15), 4.0)
		# "Press START Button" titilando.
		if blink_on():
			draw_string_outline(font, Vector2(0, size.y * 0.8), "Press START Button", HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, 6, Color(0, 0, 0))
			draw_string(font, Vector2(0, size.y * 0.8), "Press START Button", HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color.WHITE)
		draw_string(font, Vector2(0, size.y - 28), "© 2026 VirtualFutsal", HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(0.7, 0.75, 0.9))


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


var _ui_sfx: AudioStreamPlayer


func _start_music() -> void:
	_music = AudioStreamPlayer.new()
	_music.stream = MatchAudio.stream("menu_music")
	add_child(_music)
	_update_music()
	_music.play()
	# Sonidos del menú (tus archivos): moverse entre opciones y elegir.
	_ui_sfx = AudioStreamPlayer.new()
	add_child(_ui_sfx)
	get_viewport().gui_focus_changed.connect(func(_c: Control) -> void: _ui_sound("menu_move"))
	get_tree().node_added.connect(_hook_button)
	for b in find_children("*", "BaseButton", true, false):
		_hook_button(b)


func _hook_button(n: Node) -> void:
	if n is BaseButton and not (n as BaseButton).pressed.is_connected(_ui_sound.bind("menu_select")):
		(n as BaseButton).pressed.connect(_ui_sound.bind("menu_select"))


func _ui_sound(name: String) -> void:
	if _ui_sfx == null or not MatchAudio.has_file(name) or not is_inside_tree():
		return
	_ui_sfx.stream = MatchAudio.stream(name)
	_ui_sfx.volume_db = linear_to_db(maxf(0.0001, GameSettings.sfx_volume / 10.0 * 0.7))
	_ui_sfx.play()


func _update_music() -> void:
	if _music != null:
		_music.volume_db = linear_to_db(maxf(0.0001, GameSettings.music_volume / 10.0 * 0.5))
