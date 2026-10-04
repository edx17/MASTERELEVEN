class_name PlayerRatings
extends RefCounted
## Lo que hizo cada jugador en el partido y su puntaje (1 a 10, como los
## puntajes del diario: 6 es "cumplió"). El partido avisa los hechos (pases,
## remates, quites, atajadas, goles, faltas, tarjetas) y mira cada cuadro
## quién recibe la pelota para saber si un pase llegó. Se ve al final del
## partido ("Puntajes de los jugadores").

## Por debajo de estos minutos jugados no se califica ("—").
const MIN_MINUTES := 10.0
## Un pase al goleador cuenta como asistencia si llegó hace menos de esto (s).
const ASSIST_WINDOW := 10.0

## Footballer -> {stat: valor}
var _stats := {}
## Último pase en viaje: {from: Footballer, t: float} (vacío si no hay).
var _pending := {}
## Último pase que llegó: {from, to, t}.
var _last_pass := {}
var _prev_owner: Footballer = null
var _time := 0.0
## Resultado (lo lleva on_goal): suma al que ganó y resta al que perdió.
var final_score: Array[int] = [0, 0]


func of(p: Footballer) -> Dictionary:
	if not _stats.has(p):
		_stats[p] = {"minutes": 0.0, "goals": 0, "own_goals": 0, "assists": 0,
			"passes": 0, "passes_ok": 0, "shots": 0, "tackles": 0, "interceptions": 0,
			"saves": 0, "conceded": 0, "fouls": 0, "yellows": 0, "reds": 0}
	return _stats[p]


func players() -> Array:
	return _stats.keys()


## Cada cuadro con el juego en marcha: minutos jugados y pases que llegan.
func tick(dt: float, game_minutes: float, teams: Array, owner: Footballer) -> void:
	_time += dt
	for t in teams:
		for p in t.players:
			of(p)["minutes"] += game_minutes
	if owner == _prev_owner:
		return
	_prev_owner = owner
	if owner == null or _pending.is_empty():
		return
	var from: Footballer = _pending["from"]
	_pending = {}
	if owner == from:
		return
	if owner.team == from.team:
		of(from)["passes_ok"] += 1
		_last_pass = {"from": from, "to": owner, "t": _time}
	else:
		of(owner)["interceptions"] += 1


func on_pass(p: Footballer) -> void:
	of(p)["passes"] += 1
	_pending = {"from": p}


func on_shot(p: Footballer) -> void:
	of(p)["shots"] += 1
	_pending = {}


func on_tackle_won(p: Footballer) -> void:
	of(p)["tackles"] += 1


func on_save(keeper: Footballer) -> void:
	of(keeper)["saves"] += 1


func on_foul(p: Footballer) -> void:
	of(p)["fouls"] += 1


func on_card(p: Footballer, red: bool) -> void:
	of(p)["reds" if red else "yellows"] += 1


## Gol del equipo `team_index` (con `scorer` el último que la tocó).
func on_goal(scorer: Footballer, team_index: int, teams: Array) -> void:
	final_score[team_index] += 1
	if scorer != null:
		if scorer.team.index == team_index:
			of(scorer)["goals"] += 1
			var from: Footballer = _last_pass.get("from")
			if from != null and _last_pass.get("to") == scorer and from != scorer \
					and _time - float(_last_pass["t"]) < ASSIST_WINDOW:
				of(from)["assists"] += 1
		else:
			of(scorer)["own_goals"] += 1
	var conceding: Team = teams[1 - team_index]
	for p in conceding.players:
		of(p)["conceded"] += 1
	_pending = {}
	_last_pass = {}


## Puntaje de 1 a 10 (con medio punto), o -1 si jugó muy poco.
func rating(p: Footballer) -> float:
	var s := of(p)
	if float(s["minutes"]) < MIN_MINUTES:
		return -1.0
	var r := 6.0
	r += 1.0 * s["goals"] + 0.6 * s["assists"] - 1.0 * s["own_goals"]
	r += minf(0.04 * s["passes_ok"], 0.9)
	r -= minf(0.08 * (s["passes"] - s["passes_ok"]), 0.8)
	r += minf(0.05 * s["shots"], 0.3)
	r += minf(0.22 * (s["tackles"] + s["interceptions"]), 1.2)
	r -= 0.15 * s["fouls"] + 0.5 * s["yellows"] + 1.5 * s["reds"]
	var team_idx: int = p.team.index
	var diff := final_score[team_idx] - final_score[1 - team_idx]
	r += 0.3 * signf(diff)
	if p.is_keeper():
		r += minf(0.35 * s["saves"], 1.8) - 0.35 * s["conceded"]
		if s["conceded"] == 0:
			r += 0.5
	elif TacticalRole.is_defender(p.tactical_role):
		r -= 0.15 * s["conceded"]
		if s["conceded"] == 0:
			r += 0.3
	return clampf(roundf(r * 2.0) / 2.0, 1.0, 10.0)


## La figura del partido (el de mejor puntaje; desempata el que ganó).
func man_of_the_match() -> Footballer:
	var best: Footballer = null
	var best_r := -INF
	for p in _stats:
		var r := rating(p)
		if r < 0.0:
			continue
		var key: float = r + 0.01 * signf(final_score[p.team.index] - final_score[1 - p.team.index]) \
			+ 0.001 * (of(p)["goals"] + of(p)["assists"])
		if key > best_r:
			best_r = key
			best = p
	return best
