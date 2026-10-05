class_name PenaltyShootout
extends TrainingSession
## Tanda de penales sola (Partido > Tanda de penales, como en el WE2002).
## Usa la maqueta del entrenamiento (sin reloj, ni tarjetas, ni offside) en el
## estadio del partido: cinco penales por equipo alternados y, si siguen
## empatados, muerte súbita. Los que no patean esperan en el círculo central.

const ROUNDS := 5
## Espera entre un penal y el siguiente, y cuánto se muestra el final.
const NEXT_DELAY := 2.2
const KICK_TIMEOUT := 4.0

## Resultados de cada equipo (true = gol), en orden.
var kicks: Array = [[], []]
## Equipo que patea ahora.
var shooter := 0
var winner := -1
var _order: Array = [[], []]


func setup(p_match: MatchController) -> void:
	m = p_match
	kind = Kind.PENALTY
	_build_hud()
	_props = Node3D.new()
	m.add_child(_props)
	for t in m.teams:
		_order[t.index] = kick_order(t)


func start(_new_kind: int = -1) -> void:
	kicks = [[], []]
	shooter = 0
	winner = -1
	finished = false
	reset_play()


## Orden de pateadores: los cinco mejores definidores primero (el elegido
## para los penales encabeza), después el resto; el arquero, último.
static func kick_order(t: Team) -> Array[PlayerData]:
	var field: Array[PlayerData] = []
	var gk: Array[PlayerData] = []
	for p in t.players:
		if p.base_data == null:
			continue
		if p.is_keeper():
			gk.append(p.base_data)
		else:
			field.append(p.base_data)
	field.sort_custom(func(a: PlayerData, b: PlayerData) -> bool:
		return a.shooting * 2 + a.technique > b.shooting * 2 + b.technique)
	if t.pk_taker != null and field.has(t.pk_taker):
		field.erase(t.pk_taker)
		field.push_front(t.pk_taker)
	field.append_array(gk)
	return field


func goals_of(team: int) -> int:
	return kicks[team].count(true)


## ¿Ya está decidida? (Con los cinco de cada uno, o en la muerte súbita
## después de que patearon los dos.)
static func decided(a: Array, b: Array, rounds: int = ROUNDS) -> int:
	var ga := a.count(true)
	var gb := b.count(true)
	if a.size() <= rounds and b.size() <= rounds:
		if ga + (rounds - a.size()) < gb:
			return 1
		if gb + (rounds - b.size()) < ga:
			return 0
		return -1
	if a.size() == b.size() and ga != gb:
		return 0 if ga > gb else 1
	return -1


func reset_play() -> void:
	_reset_t = -1.0
	_kick_t = -1.0
	if winner >= 0:
		return
	var t := m.teams[shooter]
	var def := m.teams[1 - shooter]
	var order: Array = _order[shooter]
	var taker_data: PlayerData = order[kicks[shooter].size() % order.size()]
	t.pk_taker = taker_data
	# Los demás, en fila en el círculo central; el arquero que ataja, en el arco.
	var n := 0
	for team in m.teams:
		for p in team.players:
			if p.base_data == taker_data or (team == def and p.is_keeper()):
				continue
			var x := -1.2 if team.index == 0 else 1.2
			p.teleport(Vector3(x, 0.0, -6.0 + (n % 11) * 1.2), Vector3(t.attack_dir, 0, 0))
			n += 1
		n = 0
	var gk := def.keeper()
	if gk != null:
		gk.teleport(t.target_goal() - Vector3(t.attack_dir * 0.5, 0, 0), Vector3(-t.attack_dir, 0, 0))
	m._setup_restart(MatchRules.Outcome.new(MatchRules.Restart.PENALTY, t.index,
		m.penalty_spot(def) + Vector3(0, m.tuning.ball_radius, 0)))
	for h in m.humans:
		if h.team == t and m.restart_taker != null:
			h.select(m.restart_taker)
	_refresh_hud()


func on_outcome(outcome: MatchRules.Outcome) -> void:
	if winner >= 0 or _reset_t >= 0.0:
		return
	var goal := outcome.type == MatchRules.Restart.GOAL and outcome.team == shooter
	_say("¡GOL!" if goal else "¡AFUERA!")
	_record(goal)


func on_stopped() -> void:
	if winner < 0 and _reset_t < 0.0:
		_record(false)


func _record(goal: bool) -> void:
	kicks[shooter].append(goal)
	m.ball.state.vel = Vector3.ZERO
	m.ball.owner_player = null
	m._set_phase(MatchController.Phase.STOPPED)
	m._phase_timer = INF
	winner = decided(kicks[0], kicks[1])
	if winner < 0:
		shooter = 1 - shooter
	else:
		finished = true
		m.teams[0].score = goals_of(0)
		m.teams[1].score = goals_of(1)
		_say("GANÓ %s" % m.teams[winner].team_name.to_upper(), 600.0)
		if m.audio != null:
			m.audio.cheer("goal")
	_reset_t = NEXT_DELAY


func tick(dt: float) -> void:
	_msg_t = maxf(0.0, _msg_t - dt)
	if _msg_t <= 0.0:
		message = ""
	if finished:
		if not get_tree().paused and (Input.is_action_just_pressed(&"ui_accept") or Input.is_action_just_pressed(&"pause")) \
				and _reset_t < 0.0:
			m.exit_to_menu()
		_reset_t = maxf(-1.0, _reset_t - dt) if _reset_t >= 0.0 else -1.0
		_refresh_hud()
		return
	if _reset_t >= 0.0:
		_reset_t -= dt
		if _reset_t < 0.0:
			reset_play()
		_refresh_hud()
		return
	# Después del remate: atajada (el arquero la tiene o la despejó) o se
	# frenó sin entrar.
	if m.phase == MatchController.Phase.PLAYING and _prev_phase == MatchController.Phase.RESTART:
		_kick_t = 0.0
	if _kick_t >= 0.0 and m.phase == MatchController.Phase.PLAYING:
		_kick_t += dt
		var gk := m.teams[1 - shooter].keeper()
		if (gk != null and m.ball.owner_player == gk) or _kick_t > KICK_TIMEOUT \
				or (_kick_t > 1.0 and m.ball.state.vel.length() < 1.0):
			_say("¡ATAJÓ!" if gk != null and m.ball.owner_player == gk else "¡AFUERA!")
			_record(false)
	_prev_phase = m.phase
	_refresh_hud()


func after_ai(_dt: float) -> void:
	# Los que esperan no se mueven de la mitad de la cancha.
	var gk := m.teams[1 - shooter].keeper()
	for t in m.teams:
		for p in t.players:
			if p != m.restart_taker and p != gk:
				p.desired_move = Vector3.ZERO
				p.wants_sprint = false
				p.look_at_point(m.teams[shooter].target_goal())


func _refresh_hud() -> void:
	if _title == null:
		return
	_title.text = "TANDA DE PENALES"
	_stats.text = stats_line()
	_center.text = message
	var hint := _title.get_parent().get_child(2) as Label
	if hint != null:
		hint.text = "Aceptar / START: volver al menú" if finished else "START: pausa"


## "ARG ●●○ 2  -  1 ●○○ BRA" con un círculo por penal.
func stats_line() -> String:
	var parts := []
	for i in 2:
		var marks := ""
		for k in kicks[i]:
			marks += "●" if k else "○"
		parts.append(marks)
	return "%s %s  %d - %d  %s %s" % [m.teams[0].short_name, parts[0], goals_of(0), goals_of(1), parts[1], m.teams[1].short_name]
