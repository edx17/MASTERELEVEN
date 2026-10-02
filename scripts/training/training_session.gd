class_name TrainingSession
extends Node
## Entrenamiento en el Club House (como en el WE). El partido corre igual
## (MatchController, IA, física), pero sin reloj, ni tarjetas, ni offside, y
## cada vez que la jugada termina (gol, afuera, atajada, falta) se vuelve a
## armar sola desde el punto de origen. SELECT reinicia al instante y START
## abre el menú de práctica (PauseMenu).
##
## Qué se practica (Kind):
##   - Práctica libre: ataque contra defensa con la cantidad de jugadores que
##     elijas (1 a 10 de campo por lado, con o sin arquero rival).
##   - Tiros libres (distancia y ángulo, con o sin barrera), córners (de cada
##     lado) y penales, con el pateador que elijas.
##   - Desafíos con récord: slalom con pelota entre banderas (tiempo), precisión
##     de pase a la estación marcada (pases en 60 s), rondo contra dos marcas
##     (pases seguidos) y puntería de tiro libre a los ángulos (puntos en 10
##     tiros).

enum Kind { FREE, FREE_KICK, CORNER, PENALTY, SLALOM, PASSING, RONDO, TARGETS }

const KIND_NAMES := ["Práctica libre", "Tiros libres", "Córners", "Penales",
	"Desafío: slalom", "Desafío: precisión de pase", "Desafío: rondo", "Desafío: puntería"]
const KIND_HELP := [
	"Ataque contra defensa. Elegí cuántos de cada lado en el menú (START).",
	"Tiro libre desde donde quieras (distancia y ángulo), con o sin barrera.",
	"Córners de uno y otro lado: centro, cabezazo y remate.",
	"Penales contra el arquero.",
	"Pasá con la pelota por cada par de banderas lo más rápido que puedas. Saltear una: +2 s.",
	"Pasala al compañero marcado (aro amarillo). 60 segundos: cuantos más pases, mejor.",
	"Mantené la pelota dentro del círculo contra dos marcas. Contá pases seguidos.",
	"10 tiros libres: ángulo marcado 3 puntos, resto del arco 1.",
]
const SAVE_PATH := "user://training.json"
## Espera antes de rearmar la jugada (s) y tope de una pelota parada después
## del remate.
const RESET_DELAY := 1.6
const SET_PIECE_TIMEOUT := 7.0
## Slalom: banderas (pares de postes) cada SLALOM_SPACING m, corridas a los
## costados; ancho de la puerta.
const SLALOM_GATES := 7
const SLALOM_SPACING := 7.0
const SLALOM_OFFSET := 3.0
const SLALOM_GATE_WIDTH := 3.2
const SLALOM_MISS_PENALTY := 2.0
## Pase: estaciones alrededor del centro y duración.
const PASS_TIME := 60.0
const PASS_RADIUS := 17.0
const PASS_STATION_SIZE := 3.0
## Rondo: radio del círculo.
const RONDO_RADIUS := 9.0
## Puntería: tiros, aros en los ángulos y su radio.
const TARGET_SHOTS := 10
const TARGET_RING := 0.62
const TARGET_SPOTS := [[22.0, 0.0], [24.0, -14.0], [20.0, 16.0], [26.0, 6.0], [23.0, -6.0],
	[25.0, 12.0], [21.0, -18.0], [27.0, 0.0], [22.0, 10.0], [24.0, -10.0]]

var m: MatchController
var kind: int = Kind.FREE
## Jugadores de campo de cada lado (el arquero aparte).
var attackers := 4
var defenders := 3
var rival_keeper := true
var wall := true
var fk_distance := 22.0
## Grados respecto del centro del arco (- = izquierda del arco visto desde el
## pateador).
var fk_angle := 0.0
var corner_side := 1
## Pateador elegido (índice entre los de campo de tu equipo; -1 = el del equipo).
var taker_index := -1

## Métricas de la práctica en curso.
var attempts := 0
var goals := 0
var score := 0
var timer := 0.0
var running := false
var finished := false
var best := {}
var message := ""
var _msg_t := 0.0
var _reset_t := -1.0
var _kick_t := -1.0
var _prev_phase := -1

var _props: Node3D
var _gates: Array = []
var _gate_i := 0
var _penalty := 0.0
var _start_x := 0.0
var _stations: Array[Vector3] = []
var _station_players: Array[Footballer] = []
var _target: Footballer
var _target_ring: MeshInstance3D
var _holder: Footballer
var _loose_t := 0.0
var _passes := 0
var _rondo_center := Vector3.ZERO
var _rings: Array[Vector3] = []
var _hud: CanvasLayer
var _title: Label
var _stats: Label
var _center: Label


func setup(p_match: MatchController) -> void:
	m = p_match
	kind = GameSettings.training_kind
	_load_best()
	_build_hud()
	_props = Node3D.new()
	_props.name = "TrainingProps"
	m.add_child(_props)


func my_team() -> Team:
	return m.teams[0]


func rival() -> Team:
	return m.teams[1]


func human() -> HumanController:
	return m.humans[0] if not m.humans.is_empty() else null


## Arma la práctica elegida desde cero (jugadores, elementos y jugada).
func start(new_kind: int = -1) -> void:
	if new_kind >= 0:
		kind = new_kind
	attempts = 0
	goals = 0
	score = 0
	timer = 0.0
	running = false
	finished = false
	_apply_squads()
	_build_props()
	reset_play()


# --- Jugadores ----------------------------------------------------------------------

## Cuántos de campo y si hay arquero, por lado, según la práctica.
func squad_sizes() -> Array:
	match kind:
		Kind.SLALOM:
			return [1, false, 0, false]
		Kind.PASSING:
			return [5, false, 0, false]
		Kind.RONDO:
			return [5, false, 2, false]
		Kind.TARGETS:
			return [1, false, 4, true]
		Kind.PENALTY:
			return [maxi(1, attackers), false, defenders, true]
	return [maxi(1, attackers), attackers >= 10, defenders, rival_keeper]


func _apply_squads() -> void:
	var sz := squad_sizes()
	_squad(my_team(), sz[0], sz[1], true)
	_squad(rival(), sz[2], sz[3], false)
	var h := human()
	if h != null:
		h.select(_striker())


## Deja en la cancha `outfield` jugadores (los de ataque primero, o los de
## defensa) y el arquero si `keeper`; los demás, afuera y ocultos.
func _squad(t: Team, outfield: int, keeper: bool, attack_first: bool) -> void:
	var field: Array[Footballer] = []
	var gk: Footballer = null
	for p in t.roster:
		if p.sent_off:
			continue
		if p.base_data != null and p.base_data.position == PlayerData.Position.GK:
			gk = p
		else:
			field.append(p)
	field.sort_custom(func(a: Footballer, b: Footballer) -> bool:
		var pa: int = a.base_data.position if a.base_data else 2
		var pb: int = b.base_data.position if b.base_data else 2
		return pa > pb if attack_first else pa < pb)
	t.players.clear()
	if keeper and gk != null:
		t.players.append(gk)
	for i in mini(outfield, field.size()):
		t.players.append(field[i])
	var n := 0
	for p in t.roster:
		var on := t.players.has(p)
		p.visible = on
		if not on:
			p.teleport(Vector3(-20.0 + n * 1.2 + t.index * 30.0, 0.0, Pitch.HALF_WIDTH + 5.0), Vector3.FORWARD)
			n += 1
	t.players.sort_custom(func(a: Footballer, b: Footballer) -> bool: return t.roster.find(a) < t.roster.find(b))


## El de más adelante de tu equipo (el que arranca con la pelota).
func _striker() -> Footballer:
	var t := my_team()
	for i in range(t.players.size() - 1, -1, -1):
		if not t.players[i].is_keeper():
			return t.players[i]
	return t.players[0] if not t.players.is_empty() else null


func outfield(t: Team) -> Array[Footballer]:
	var out: Array[Footballer] = []
	for p in t.players:
		if not p.is_keeper():
			out.append(p)
	return out


## El que patea las pelotas paradas.
func taker() -> Footballer:
	var f := outfield(my_team())
	if f.is_empty():
		return null
	if taker_index >= 0:
		return f[taker_index % f.size()]
	return _striker()


# --- Reinicio de la jugada ------------------------------------------------------

## Vuelve a armar la jugada desde el origen (SELECT, o sola al terminar).
func reset_play() -> void:
	_reset_t = -1.0
	_kick_t = -1.0
	m.card_scene = {}
	m.replay_request = {}
	m.save_plan = {}
	m.banner_text = ""
	m.wall_targets = {}
	if m.camera() != null and m.camera().cinematic:
		m.set_piece_cam = false
		m.camera().end_cinematic()
	for p in m.all_players():
		p.locked = false
		p.speed_override = 0.0
		p.clear_pass_target()
		p.set_presenting(false)
	m.ball.frozen = false
	m.ball.in_hands = false
	var dir := float(my_team().attack_dir)
	var goal := my_team().target_goal()
	match kind:
		Kind.FREE:
			_place_free(dir, goal)
		Kind.FREE_KICK, Kind.TARGETS:
			var spot := fk_spot()
			if kind == Kind.TARGETS:
				var s: Array = TARGET_SPOTS[attempts % TARGET_SPOTS.size()]
				spot = spot_at(float(s[0]), float(s[1]))
			_place_set_piece(MatchRules.Restart.FREE_KICK, spot)
		Kind.CORNER:
			var corner := Vector3(dir * (Pitch.HALF_LENGTH - 0.4), 0.0, corner_side * (Pitch.HALF_WIDTH - 0.4))
			_place_set_piece(MatchRules.Restart.CORNER, corner)
		Kind.PENALTY:
			_place_set_piece(MatchRules.Restart.PENALTY, m.penalty_spot(rival()))
		Kind.SLALOM:
			_place_slalom(dir)
		Kind.PASSING:
			_place_passing()
		Kind.RONDO:
			_place_rondo()
	_prev_phase = m.phase


## Punto del tiro libre: a `dist` m del centro del arco, con `angle` grados.
func spot_at(dist: float, angle: float) -> Vector3:
	var t := my_team()
	var out := Vector3(-t.attack_dir, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(angle) * t.attack_dir)
	var p := t.target_goal() + out * dist
	return Pitch.clamp_to_field(Vector3(p.x, 0.0, p.z), 1.0)


func fk_spot() -> Vector3:
	return spot_at(fk_distance, fk_angle)


func _give_ball(p: Footballer) -> void:
	m.ball.place(p.flat_pos() + p.facing * 0.6 + Vector3(0, 0.11, 0))
	m.ball.state.vel = Vector3.ZERO
	m.ball.give_to(p)
	var h := human()
	if h != null and p.team == h.team:
		h.select(p)


func _play() -> void:
	m.restart_taker = null
	m.restart_type = MatchRules.Restart.NONE
	m._set_phase(MatchController.Phase.PLAYING)


## Libre: el delantero con la pelota a 32 m del arco, sus compañeros abiertos
## adelante y la defensa entre la pelota y el arco.
func _place_free(dir: float, goal: Vector3) -> void:
	var origin := goal - Vector3(dir * 32.0, 0.0, 0.0)
	var mine := outfield(my_team())
	var striker := _striker()
	striker.teleport(origin, Vector3(dir, 0, 0))
	var others := mine.filter(func(p: Footballer) -> bool: return p != striker)
	for i in others.size():
		var k := float(i) / maxf(others.size() - 1, 1) - 0.5
		var p: Footballer = others[i]
		var row := i % 2
		p.teleport(origin + Vector3(dir * (3.0 + row * 7.0), 0.0, k * 34.0 + (5.0 if others.size() == 1 else 0.0)), Vector3(dir, 0, 0))
	var my_gk := my_team().keeper()
	if my_gk != null:
		my_gk.teleport(my_team().own_goal() + Vector3(dir * 1.5, 0, 0), Vector3(dir, 0, 0))
	var defs := outfield(rival())
	for i in defs.size():
		var k := float(i) / maxf(defs.size() - 1, 1) - 0.5
		var row := i / 5
		defs[i].teleport(goal - Vector3(dir * (15.0 + row * 9.0), 0.0, -k * 30.0 * (1.0 if defs.size() > 1 else 0.0)), Vector3(-dir, 0, 0))
	var gk := rival().keeper()
	if gk != null:
		gk.teleport(goal - Vector3(dir * 1.0, 0, 0), Vector3(-dir, 0, 0))
	_give_ball(striker)
	_play()


## Pelota parada: los demás en el área (atacantes y marcas al lado), el
## arquero en el arco y la pelota con el pateador elegido.
func _place_set_piece(type: int, spot: Vector3) -> void:
	var t := my_team()
	var dir := float(t.attack_dir)
	var goal := t.target_goal()
	var tk := taker()
	if tk != null:
		t.fk_taker = tk.base_data
		t.ck_taker = tk.base_data
		t.pk_taker = tk.base_data
	var mine := outfield(t).filter(func(p: Footballer) -> bool: return p != tk)
	var marks := outfield(rival())
	var box := Pitch.PENALTY_AREA_DEPTH
	for i in mine.size():
		var k := float(i) / maxf(mine.size() - 1, 1) - 0.5
		var pos := goal - Vector3(dir * (box - 4.0 + (i % 2) * 3.0), 0.0, k * 22.0)
		if type == MatchRules.Restart.PENALTY:
			pos = goal - Vector3(dir * (box + 2.0), 0.0, k * 20.0)
		mine[i].teleport(pos, Vector3(dir, 0, 0))
		if i < marks.size():
			marks[i].teleport(pos + Vector3(dir * 1.0, 0.0, 0.6), Vector3(-dir, 0, 0))
	for i in range(mine.size(), marks.size()):
		var k2 := float(i) / maxf(marks.size() - 1, 1) - 0.5
		var mpos := goal - Vector3(dir * 8.0, 0.0, k2 * 14.0)
		if type == MatchRules.Restart.PENALTY:
			mpos = goal - Vector3(dir * (box + 3.0), 0.0, k2 * 24.0)
		marks[i].teleport(mpos, Vector3(-dir, 0, 0))
	var gk := rival().keeper()
	if gk != null:
		gk.teleport(goal - Vector3(dir * 0.5, 0, 0), Vector3(-dir, 0, 0))
	m._setup_restart(MatchRules.Outcome.new(type, t.index, spot + Vector3(0, m.tuning.ball_radius, 0)))
	if type == MatchRules.Restart.FREE_KICK and not wall:
		# Sin barrera: los que iban a la barrera vuelven a marcar.
		var i := 0
		for p: Footballer in m.wall_targets.keys():
			p.teleport(goal - Vector3(dir * 9.0, 0.0, (i - 1.5) * 4.0), Vector3(-dir, 0, 0))
			i += 1
		m.wall_targets = {}
	var h := human()
	if h != null and m.restart_taker != null:
		h.select(m.restart_taker)


# --- Desafíos: armado -------------------------------------------------------------

func _place_slalom(dir: float) -> void:
	var p := _striker()
	_start_x = -dir * 20.0
	p.teleport(Vector3(_start_x - dir * 2.0, 0, 0), Vector3(dir, 0, 0))
	_gate_i = 0
	_penalty = 0.0
	timer = 0.0
	running = false
	finished = false
	_give_ball(p)
	_play()


func _place_passing() -> void:
	var f := outfield(my_team())
	_station_players.clear()
	for i in f.size():
		var pos: Vector3 = _stations[i] if i < _stations.size() else Vector3.ZERO
		f[i].teleport(pos, (Vector3.ZERO - pos).normalized() if pos.length() > 0.1 else Vector3(my_team().attack_dir, 0, 0))
		_station_players.append(f[i])
	timer = PASS_TIME
	running = false
	finished = false
	score = 0
	_holder = _station_players[0]
	_give_ball(_holder)
	_pick_target()
	_play()


func _place_rondo() -> void:
	var f := outfield(my_team())
	_station_players.clear()
	for i in f.size():
		var pos: Vector3 = _stations[i]
		f[i].teleport(pos, (_rondo_center - pos).normalized() if pos.distance_to(_rondo_center) > 0.1 else Vector3.RIGHT)
		_station_players.append(f[i])
	var defs := outfield(rival())
	for i in defs.size():
		defs[i].teleport(_rondo_center + Vector3(0, 0, (i - 0.5) * 3.0), Vector3.RIGHT)
	_passes = 0
	finished = false
	_holder = _station_players[0]
	_give_ball(_holder)
	_play()


## Conos, banderas, estaciones y aros de cada desafío.
func _build_props() -> void:
	for c in _props.get_children():
		c.queue_free()
	_gates.clear()
	_stations.clear()
	_rings.clear()
	_target_ring = null
	var dir := float(my_team().attack_dir)
	match kind:
		Kind.SLALOM:
			var x0 := -dir * 20.0
			_line(Vector3(x0, 0, 0), 10.0, Color.WHITE)
			for i in SLALOM_GATES:
				var gx := x0 + dir * SLALOM_SPACING * (i + 1)
				var gz := SLALOM_OFFSET * (1.0 if i % 2 == 0 else -1.0)
				_gates.append([gx, gz])
				var col := Color(0.9, 0.15, 0.12) if i % 2 == 0 else Color(0.15, 0.35, 0.9)
				_pole(Vector3(gx, 0, gz - SLALOM_GATE_WIDTH * 0.5), col)
				_pole(Vector3(gx, 0, gz + SLALOM_GATE_WIDTH * 0.5), col)
			_line(Vector3(x0 + dir * SLALOM_SPACING * (SLALOM_GATES + 1), 0, 0), 10.0, Color(1.0, 0.85, 0.2))
		Kind.PASSING:
			_stations.append(Vector3.ZERO)
			for i in 4:
				var a := TAU * i / 4.0 + PI * 0.25
				_stations.append(Vector3(cos(a), 0, sin(a)) * PASS_RADIUS * (1.0 if i % 2 == 0 else 1.3))
			for s in _stations:
				for k in 4:
					var a2 := TAU * k / 4.0 + PI * 0.25
					_cone(s + Vector3(cos(a2), 0, sin(a2)) * PASS_STATION_SIZE * 0.7)
			_target_ring = _ring(Vector3.ZERO, 1.6, Color(1.0, 0.85, 0.15), true)
		Kind.RONDO:
			_rondo_center = Vector3(-dir * 8.0, 0, 0)
			_ring(_rondo_center, RONDO_RADIUS, Color.WHITE, true)
			for i in 5:
				var a := TAU * i / 5.0
				_stations.append(_rondo_center + Vector3(cos(a), 0, sin(a)) * (RONDO_RADIUS - 1.2))
		Kind.TARGETS:
			var goal := my_team().target_goal()
			for sz: float in [-1.0, 1.0]:
				for top: bool in [true, false]:
					var c := Vector3(goal.x, (Pitch.GOAL_HEIGHT - TARGET_RING - 0.05) if top else (TARGET_RING + 0.05),
						sz * (Pitch.GOAL_HALF_WIDTH - TARGET_RING - 0.05))
					_rings.append(c)
					var r := _ring(c, TARGET_RING, Color(1.0, 0.85, 0.15), false)
					r.rotation = Vector3(0, 0, PI * 0.5)


func _mat(c: Color, glow := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	if glow:
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 0.6
	return mat


func _cone(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.16
	cm.height = 0.35
	mi.mesh = cm
	mi.material_override = _mat(Color(1.0, 0.45, 0.05))
	mi.position = pos + Vector3(0, 0.175, 0)
	_props.add_child(mi)


func _pole(pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.03
	cm.height = 1.7
	mi.mesh = cm
	mi.material_override = _mat(Color(0.95, 0.95, 0.95))
	mi.position = pos + Vector3(0, 0.85, 0)
	_props.add_child(mi)
	var flag := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.02, 0.45, 0.55)
	flag.mesh = bm
	flag.material_override = _mat(col)
	flag.position = pos + Vector3(0, 1.45, 0.28 * signf(pos.z) if absf(pos.z) > 0.01 else 0.28)
	_props.add_child(flag)


func _line(center: Vector3, length: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.15, 0.01, length)
	mi.mesh = bm
	mi.material_override = _mat(col, true)
	mi.position = center + Vector3(0, 0.015, 0)
	_props.add_child(mi)


func _ring(center: Vector3, radius: float, col: Color, flat: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - (0.08 if flat else 0.05)
	tm.outer_radius = radius
	tm.rings = 48
	mi.mesh = tm
	mi.material_override = _mat(col, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = center + (Vector3(0, 0.02, 0) if flat else Vector3.ZERO)
	_props.add_child(mi)
	return mi


# --- Juego -------------------------------------------------------------------------

## El partido avisa que la pelota salió o entró (no hay festejo ni saque).
## La jugada la maneja el entrenamiento: cuenta el intento y la rearma.
func on_outcome(outcome: MatchRules.Outcome) -> void:
	var ball := m.ball.state.pos
	match outcome.type:
		MatchRules.Restart.GOAL:
			if outcome.team == my_team().index:
				goals += 1
				if kind == Kind.TARGETS:
					var pts := target_points(ball)
					score += pts
					_say("¡AL ÁNGULO! +3" if pts == 3 else "GOL +1")
				else:
					_say("¡GOL!")
			else:
				_say("GOL EN CONTRA")
		_:
			if kind in [Kind.PASSING, Kind.RONDO, Kind.SLALOM]:
				_say("AFUERA")
			else:
				_say("AFUERA" if outcome.type != MatchRules.Restart.CORNER else "CÓRNER")
	_end_attempt()


## Puntos de un remate que entró: 3 adentro de un aro, si no 1.
func target_points(pos: Vector3) -> int:
	for c in _rings:
		if Vector2(pos.y - c.y, pos.z - c.z).length() <= TARGET_RING + 0.15:
			return 3
	return 1


## Terminó un intento (gol, afuera, atajada, se cortó): cuenta y rearma.
func _end_attempt() -> void:
	m.ball.state.vel = Vector3.ZERO
	m.ball.owner_player = null
	m._set_phase(MatchController.Phase.STOPPED)
	m._phase_timer = INF
	if kind in [Kind.FREE_KICK, Kind.CORNER, Kind.PENALTY, Kind.TARGETS, Kind.FREE]:
		attempts += 1
	if kind == Kind.TARGETS and attempts >= TARGET_SHOTS:
		_finish("%d puntos" % score, score, true)
	if kind == Kind.RONDO:
		_finish("%d pases seguidos" % _passes, _passes, true)
	_reset_t = RESET_DELAY


## Falta o fuera de juego (el partido ya paró): se rearma la jugada.
func on_stopped() -> void:
	if _reset_t < 0.0:
		_say("FALTA")
		_reset_t = RESET_DELAY


## Récord de un desafío (más alto es mejor, salvo el tiempo del slalom).
func _finish(text: String, value: float, higher_better: bool) -> void:
	finished = true
	running = false
	var key: String = KIND_NAMES[kind]
	var prev: float = best.get(key, -1.0)
	var record := prev < 0.0 or (value > prev if higher_better else value < prev)
	if record:
		best[key] = value
		_save_best()
	_say(("¡RÉCORD!  " if record and prev >= 0.0 else "") + text, 3.0)


func _say(text: String, seconds: float = 1.8) -> void:
	message = text
	_msg_t = seconds


## Pasos del entrenamiento (después de las reglas del partido).
func tick(dt: float) -> void:
	_msg_t = maxf(0.0, _msg_t - dt)
	if _msg_t <= 0.0:
		message = ""
	if not get_tree().paused and Input.is_action_just_pressed(&"camera_cycle"):
		reset_play()
		_say("REINICIO", 0.8)
		_refresh_hud()
		return
	if _reset_t >= 0.0:
		_reset_t -= dt
		if _reset_t < 0.0:
			if finished and kind in [Kind.TARGETS, Kind.RONDO, Kind.PASSING, Kind.SLALOM]:
				start()
			else:
				reset_play()
		_refresh_hud()
		return
	match kind:
		Kind.FREE_KICK, Kind.CORNER, Kind.PENALTY, Kind.TARGETS:
			_watch_set_piece(dt)
		Kind.FREE:
			_watch_free()
		Kind.SLALOM:
			_tick_slalom(dt)
		Kind.PASSING:
			_tick_passing(dt)
		Kind.RONDO:
			_tick_rondo(dt)
	_prev_phase = m.phase
	_refresh_hud()


## Pelota parada: después del remate, el arquero que la agarra o el tiempo
## terminan el intento.
func _watch_set_piece(dt: float) -> void:
	if m.phase == MatchController.Phase.PLAYING and _prev_phase == MatchController.Phase.RESTART:
		_kick_t = 0.0
	if _kick_t < 0.0 or m.phase != MatchController.Phase.PLAYING:
		return
	_kick_t += dt
	var gk := rival().keeper()
	if gk != null and m.ball.owner_player == gk:
		_say("¡ATAJÓ!")
		_end_attempt()
	elif m.ball.owner_player != null and m.ball.owner_player.team == rival() and _kick_t > 0.5:
		_say("DESPEJADA")
		_end_attempt()
	elif _kick_t > SET_PIECE_TIMEOUT:
		_end_attempt()


## Libre: si el arquero rival la agarra, se rearma.
func _watch_free() -> void:
	var gk := rival().keeper()
	if gk != null and m.ball.owner_player == gk and m.phase == MatchController.Phase.PLAYING:
		_say("¡ATAJÓ!")
		_end_attempt()


func _tick_slalom(dt: float) -> void:
	if finished:
		return
	var p := _striker()
	var dir := float(my_team().attack_dir)
	var x := p.global_position.x
	if not running and (x - _start_x) * dir > 0.0:
		running = true
	if running:
		timer += dt
	# Se escapó la pelota: a empezar de nuevo.
	if m.ball.owner_player != p and m.ball.flat_pos().distance_to(p.flat_pos()) > 6.0:
		_say("SE TE ESCAPÓ")
		_reset_t = RESET_DELAY
		return
	if _gate_i < _gates.size():
		var g: Array = _gates[_gate_i]
		if (x - float(g[0])) * dir >= 0.0:
			if absf(p.global_position.z - float(g[1])) > SLALOM_GATE_WIDTH * 0.5:
				_penalty += SLALOM_MISS_PENALTY
				_say("+%d s" % int(SLALOM_MISS_PENALTY), 0.8)
			_gate_i += 1
	else:
		var finish_x := _start_x + dir * SLALOM_SPACING * (SLALOM_GATES + 1)
		if (x - finish_x) * dir >= 0.0:
			var total := timer + _penalty
			_finish("%.2f s" % total, total, false)
			_reset_t = RESET_DELAY * 2.0


func _tick_passing(dt: float) -> void:
	if finished:
		return
	var owner := m.ball.owner_player
	if running:
		timer -= dt
		if timer <= 0.0:
			timer = 0.0
			_finish("%d pases" % score, score, true)
			_reset_t = RESET_DELAY * 2.0
			return
	if owner != null and owner.team == my_team() and owner != _holder:
		if not running:
			running = true
		if owner == _target:
			score += 1
			_say("+1", 0.6)
			_holder = owner
			_pick_target()
		else:
			_holder = owner
		_loose_t = 0.0
	elif owner == null:
		_loose_t += dt
		if _loose_t > 3.0 or m.ball.flat_pos().length() > PASS_RADIUS * 2.2:
			_loose_t = 0.0
			_give_ball(_holder)


## Próxima estación (no la del que la tiene).
func _pick_target() -> void:
	var options := _station_players.filter(func(p: Footballer) -> bool: return p != _holder)
	if options.is_empty():
		return
	_target = options[randi() % options.size()]
	if _target_ring != null:
		var idx := _station_players.find(_target)
		_target_ring.position = _stations[idx] + Vector3(0, 0.02, 0)


func _tick_rondo(dt: float) -> void:
	if finished:
		return
	var owner := m.ball.owner_player
	if owner != null and owner.team == rival():
		_say("¡TE LA SACARON!")
		_end_attempt()
		return
	if m.ball.flat_pos().distance_to(_rondo_center) > RONDO_RADIUS + 2.0:
		_say("SE FUE DEL CÍRCULO")
		_end_attempt()
		return
	if owner != null and owner.team == my_team() and owner != _holder:
		_passes += 1
		_holder = owner


## Después de la IA: los de las estaciones se quedan en su lugar (van a la
## pelota sólo si les llega cerca) y las marcas del rondo presionan.
func after_ai(_dt: float) -> void:
	if m.phase != MatchController.Phase.PLAYING:
		return
	var h := human()
	match kind:
		Kind.PASSING, Kind.RONDO:
			for i in _station_players.size():
				var p := _station_players[i]
				if h != null and h.controlled == p:
					continue
				var home: Vector3 = _stations[i]
				var to_ball := m.ball.flat_pos() - p.flat_pos()
				if m.ball.owner_player == null and to_ball.length() < 4.0 and (m.ball.intended_receiver == p or to_ball.length() < 2.5):
					p.desired_move = to_ball.normalized()
				else:
					var back := home - p.flat_pos()
					p.desired_move = back.normalized() * clampf(back.length() / 2.0, 0.0, 1.0) if back.length() > 0.4 else Vector3.ZERO
				p.wants_sprint = false
				if p.desired_move.length_squared() < 0.01:
					p.look_at_point(m.ball.flat_pos())
			if kind == Kind.RONDO:
				for d in outfield(rival()):
					var target := m.ball.flat_pos()
					var to := target - d.flat_pos()
					d.desired_move = to.normalized() if to.length() > 0.5 else Vector3.ZERO
					d.wants_sprint = to.length() > 3.0
					d.wants_tackle = m.ball.owner_player != null and to.length() < 1.8
		Kind.SLALOM:
			pass


# --- HUD ----------------------------------------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 6
	add_child(_hud)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.12, 0.8)
	sb.border_color = Color(1.0, 0.85, 0.3, 0.9)
	sb.border_width_bottom = 3
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = 14
	_hud.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	_title = WEStyle.label("", 24, Color(1.0, 0.9, 0.35))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_stats = WEStyle.label("", 20)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_stats)
	var hint := WEStyle.label("SELECT: reiniciar la jugada    START: menú de práctica", 15, Color(0.75, 0.8, 0.9))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_center = WEStyle.label("", 46, Color.WHITE)
	_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center.grow_vertical = Control.GROW_DIRECTION_BOTH
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.position.y -= 120
	_hud.add_child(_center)


func _refresh_hud() -> void:
	if _title == null:
		return
	_title.text = "ENTRENAMIENTO  ·  " + String(KIND_NAMES[kind]).to_upper() + _detail()
	_stats.text = stats_line()
	_center.text = message


func _detail() -> String:
	match kind:
		Kind.FREE:
			return "  %d vs %d%s" % [outfield(my_team()).size(), outfield(rival()).size(), " + ARQ" if rival().keeper() != null else ""]
		Kind.FREE_KICK:
			return "  %d m" % int(round(fk_distance))
	return ""


func stats_line() -> String:
	var key: String = KIND_NAMES[kind]
	var rec: float = best.get(key, -1.0)
	match kind:
		Kind.SLALOM:
			return "Tiempo %.2f s   Banderas %d/%d   Récord %s" % [timer + _penalty, _gate_i, _gates.size(), ("%.2f s" % rec) if rec >= 0.0 else "-"]
		Kind.PASSING:
			return "Pases %d   Quedan %d s   Récord %s" % [score, int(ceil(timer)), str(int(rec)) if rec >= 0.0 else "-"]
		Kind.RONDO:
			return "Pases seguidos %d   Récord %s" % [_passes, str(int(rec)) if rec >= 0.0 else "-"]
		Kind.TARGETS:
			return "Tiro %d/%d   Puntos %d   Récord %s" % [mini(attempts + 1, TARGET_SHOTS), TARGET_SHOTS, score, str(int(rec)) if rec >= 0.0 else "-"]
	return "Goles %d / %d intentos" % [goals, attempts]


# --- Récords --------------------------------------------------------------------------

func _load_best() -> void:
	best = {}
	if not GameSettings.persist or not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		best = data


func _save_best() -> void:
	if not GameSettings.persist:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(best))
