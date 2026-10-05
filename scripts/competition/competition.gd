class_name Competition
extends RefCounted
## Liga o Copa con los equipos del juego (Fase 7, versión inicial).
##   Liga: todos contra todos (una o dos ruedas), 3 puntos por partido ganado;
##         tabla por puntos, diferencia de gol y goles a favor.
##   Copa: eliminación directa por sorteo (cuartos, semis y final); si el
##         partido termina empatado se define por penales.
## El partido del jugador se juega; los demás se simulan con los puntajes de
## los equipos (TeamData.ratings). Se guarda en user:// entre sesiones.

enum Kind { LEAGUE, CUP }
const SAVE_PATH := "user://competition.json"
const KIND_NAMES := ["Liga", "Copa"]
const CUP_ROUND_NAMES := {8: "Cuartos de final", 4: "Semifinales", 2: "Final"}

var kind: int = Kind.LEAGUE
var team_paths: Array[String] = []
var user_team := 0
var double_round := false
## Fechas: cada una, lista de partidos {"home", "away", "result": [] o [gl, gv, pl, pv]}.
var rounds: Array = []
var current := 0
var champion := -1


static func create_league(paths: Array[String], user: int, two_legs: bool, seed: int = 0) -> Competition:
	var c := Competition.new()
	c.kind = Kind.LEAGUE
	c.team_paths = paths.duplicate()
	c.user_team = user
	c.double_round = two_legs
	c.rounds = round_robin(paths.size(), two_legs, seed)
	return c


static func create_cup(paths: Array[String], user: int, seed: int = 0) -> Competition:
	var c := Competition.new()
	c.kind = Kind.CUP
	c.team_paths = paths.duplicate()
	c.user_team = user
	var order: Array = range(paths.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else randi()
	_shuffle(order, rng)
	var r := []
	for i in range(0, order.size(), 2):
		r.append({"home": order[i], "away": order[i + 1], "result": []})
	c.rounds = [r]
	return c


## Fixture todos contra todos (método del círculo): n-1 fechas; con dos ruedas
## la segunda invierte las localías.
static func round_robin(n: int, two_legs: bool, seed: int = 0) -> Array:
	var ids: Array = range(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else randi()
	_shuffle(ids, rng)
	if n % 2 == 1:
		ids.append(-1)
	var m := ids.size()
	var out := []
	for r in m - 1:
		var games := []
		for i in m / 2:
			var a: int = ids[i]
			var b: int = ids[m - 1 - i]
			if a < 0 or b < 0:
				continue
			# Alterna la localía para que nadie juegue siempre de local.
			if (r + i) % 2 == 0:
				games.append({"home": a, "away": b, "result": []})
			else:
				games.append({"home": b, "away": a, "result": []})
		out.append(games)
		# Rota todos menos el primero.
		ids.insert(1, ids.pop_back())
	if two_legs:
		var back := []
		for games in out:
			var g2 := []
			for g in games:
				g2.append({"home": g["away"], "away": g["home"], "result": []})
			back.append(g2)
		out.append_array(back)
	return out


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func finished() -> bool:
	return champion >= 0 or current >= rounds.size()


func team(i: int) -> TeamData:
	return TeamDB.load_team(team_paths[i])


func round_name(i: int = -1) -> String:
	if i < 0:
		i = current
	if kind == Kind.CUP:
		var teams_left := (rounds[i] as Array).size() * 2
		return CUP_ROUND_NAMES.get(teams_left, "Ronda %d" % (i + 1))
	return "Fecha %d de %d" % [i + 1, rounds.size()]


## Partido del jugador en la fecha actual (o {} si no juega / terminó).
func user_match() -> Dictionary:
	if finished():
		return {}
	for g in rounds[current]:
		if g["home"] == user_team or g["away"] == user_team:
			return g
	return {}


## Simula un partido entre dos equipos: goles por Poisson según el ataque de
## uno contra la defensa del otro (con algo de ventaja para el local).
static func simulate_score(home: TeamData, away: TeamData, rng: RandomNumberGenerator) -> Array[int]:
	var h := home.ratings()
	var a := away.ratings()
	var lh := clampf(1.35 + 2.2 * (h[0] - a[1]) + 0.8 * (h[4] - a[4]) * 0.5 + 0.25, 0.3, 3.6)
	var la := clampf(1.1 + 2.2 * (a[0] - h[1]) + 0.8 * (a[4] - h[4]) * 0.5, 0.25, 3.4)
	return [_poisson(lh, rng), _poisson(la, rng)]


static func _poisson(lambda: float, rng: RandomNumberGenerator) -> int:
	var l := exp(-lambda)
	var k := 0
	var p := 1.0
	while true:
		p *= rng.randf()
		if p <= l:
			return k
		k += 1
		if k > 9:
			return k
	return k


## Penales (copa): tanda de 5 y después muerte súbita.
static func penalty_shootout(rng: RandomNumberGenerator) -> Array[int]:
	var h := 0
	var a := 0
	for i in 5:
		h += 1 if rng.randf() < 0.76 else 0
		a += 1 if rng.randf() < 0.76 else 0
	while h == a:
		h += 1 if rng.randf() < 0.76 else 0
		a += 1 if rng.randf() < 0.76 else 0
	return [h, a]


## Termina la fecha: anota el resultado del jugador (si jugó) y simula el
## resto. En copa arma la ronda siguiente con los ganadores.
func complete_round(user_result: Array = [], seed: int = 0) -> void:
	if finished():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else randi()
	for g in rounds[current]:
		if not (g["result"] as Array).is_empty():
			continue
		var res: Array = []
		if (g["home"] == user_team or g["away"] == user_team) and not user_result.is_empty():
			res = user_result.duplicate()
		else:
			res = Array(simulate_score(team(g["home"]), team(g["away"]), rng))
		if kind == Kind.CUP and res.size() == 2 and res[0] == res[1]:
			res.append_array(penalty_shootout(rng))
		g["result"] = res
	current += 1
	if kind == Kind.CUP:
		var winners := []
		for g in rounds[current - 1]:
			winners.append(winner(g))
		if winners.size() == 1:
			champion = winners[0]
			return
		var r := []
		for i in range(0, winners.size(), 2):
			r.append({"home": winners[i], "away": winners[i + 1], "result": []})
		rounds.append(r)
	elif current >= rounds.size():
		champion = int(standings()[0]["team"])


## Ganador de un partido de copa (con penales si hizo falta).
static func winner(g: Dictionary) -> int:
	var r: Array = g["result"]
	if r.size() < 2:
		return -1
	if r[0] != r[1]:
		return g["home"] if r[0] > r[1] else g["away"]
	if r.size() >= 4:
		return g["home"] if r[2] > r[3] else g["away"]
	return -1


## Tabla de la liga: [{team, pj, g, e, p, gf, gc, dg, pts}] ordenada.
func standings() -> Array:
	var rows := {}
	for i in team_paths.size():
		rows[i] = {"team": i, "pj": 0, "g": 0, "e": 0, "p": 0, "gf": 0, "gc": 0, "dg": 0, "pts": 0}
	for r in rounds:
		for g in r:
			var res: Array = g["result"]
			if res.size() < 2:
				continue
			var h: Dictionary = rows[g["home"]]
			var a: Dictionary = rows[g["away"]]
			_add(h, res[0], res[1])
			_add(a, res[1], res[0])
	var out := rows.values()
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if x["pts"] != y["pts"]:
			return x["pts"] > y["pts"]
		if x["dg"] != y["dg"]:
			return x["dg"] > y["dg"]
		return x["gf"] > y["gf"])
	return out


static func _add(row: Dictionary, gf: int, gc: int) -> void:
	row["pj"] += 1
	row["gf"] += gf
	row["gc"] += gc
	row["dg"] = row["gf"] - row["gc"]
	if gf > gc:
		row["g"] += 1
		row["pts"] += 3
	elif gf == gc:
		row["e"] += 1
		row["pts"] += 1
	else:
		row["p"] += 1


# --- Guardado ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"kind": kind, "team_paths": team_paths, "user_team": user_team, "double_round": double_round,
		"rounds": rounds, "current": current, "champion": champion}


static func from_dict(d: Dictionary) -> Competition:
	var c := Competition.new()
	c.kind = int(d.get("kind", 0))
	c.team_paths.assign(d.get("team_paths", []))
	c.user_team = int(d.get("user_team", 0))
	c.double_round = bool(d.get("double_round", false))
	c.current = int(d.get("current", 0))
	c.champion = int(d.get("champion", -1))
	# JSON guarda los números como float: se pasan a int.
	for r in d.get("rounds", []):
		var games := []
		for g in r:
			var res := []
			for v in g.get("result", []):
				res.append(int(v))
			games.append({"home": int(g["home"]), "away": int(g["away"]), "result": res})
		c.rounds.append(games)
	return c


func save(path: String = SAVE_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(to_dict()))


static func load_saved(path: String = SAVE_PATH) -> Competition:
	if not FileAccess.file_exists(path):
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return from_dict(d) if d is Dictionary else null


static func delete_saved(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
