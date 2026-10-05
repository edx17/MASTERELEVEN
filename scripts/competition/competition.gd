class_name Competition
extends RefCounted
## Liga o Copa con los equipos del juego (Fase 7, versión inicial).
##   Liga: todos contra todos (una o dos ruedas), 3 puntos por partido ganado;
##         tabla por puntos, diferencia de gol y goles a favor.
##   Copa: eliminación directa por sorteo (cuartos, semis y final); si el
##         partido termina empatado se define por penales.
## El partido del jugador se juega; los demás se simulan con los puntajes de
## los equipos (TeamData.ratings). Se guarda en user:// entre sesiones.

enum Kind { LEAGUE, CUP, WORLD_CUP }
## Partida suelta de versiones anteriores (las nuevas van en
## Documentos/MasterEleven/saves/ligas o saves/copas, un archivo cada una).
const SAVE_PATH := "user://competition.json"
const KIND_NAMES := ["Liga", "Copa", "Mundial"]
const CUP_ROUND_NAMES := {64: "32avos de final", 32: "16avos de final", 16: "Octavos de final", 8: "Cuartos de final", 4: "Semifinales",
	2: "Final"}
## Mundial (formato 2026): 48 selecciones en 12 grupos de 4 (3 fechas); pasan
## los dos primeros y los 8 mejores terceros a 16avos y de ahí eliminación
## directa.
const WC_GROUP_ROUNDS := 3
const WC_GROUP_LETTERS := "ABCDEFGHIJKL"

var kind: int = Kind.LEAGUE
var team_paths: Array[String] = []
var user_team := 0
var double_round := false
## Fechas: cada una, lista de partidos {"home", "away", "result": [] o [gl, gv, pl, pv]}.
var rounds: Array = []
var current := 0
var champion := -1
## Mundial: los 12 grupos (índices de equipos).
var groups: Array = []
## Archivo de esta partida, nombre para el menú CONTINUAR, Option File con
## el que se creó y fechas.
var file := ""
var title := ""
var option_file := ""
var created := ""
var updated := ""


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


## Mundial con 48 selecciones: bombos por nivel (el primero con los
## anfitriones al frente) y un equipo de cada bombo por grupo.
static func create_world_cup(paths: Array[String], user: int, seed: int = 0, hosts: Array[String] = []) -> Competition:
	var c := Competition.new()
	c.kind = Kind.WORLD_CUP
	c.team_paths = paths.duplicate()
	c.user_team = user
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else randi()
	var order: Array = range(paths.size())
	var level := {}
	for i in order:
		var r := TeamDB.load_team(paths[i]).ratings()
		var lv := 0.0
		for v in r:
			lv += v
		level[i] = lv + (100.0 if hosts.has(paths[i]) else 0.0)
	order.sort_custom(func(a: int, b: int) -> bool: return level[a] > level[b])
	var n_groups := paths.size() / 4
	for gi in n_groups:
		c.groups.append([])
	for pot in 4:
		var pot_teams: Array = order.slice(pot * n_groups, (pot + 1) * n_groups)
		if pot > 0:
			_shuffle(pot_teams, rng)
		for gi in n_groups:
			c.groups[gi].append(pot_teams[gi])
	for md in WC_GROUP_ROUNDS:
		var games := []
		for g in c.groups:
			var pairs: Array = [[[0, 1], [2, 3]], [[0, 2], [3, 1]], [[3, 0], [1, 2]]][md]
			for pr in pairs:
				games.append({"home": g[pr[0]], "away": g[pr[1]], "result": []})
		c.rounds.append(games)
	return c


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


## Tabla de un grupo del Mundial (sólo la fase de grupos).
func group_table(gi: int) -> Array:
	var rows := {}
	for t in groups[gi]:
		rows[t] = {"team": t, "pj": 0, "g": 0, "e": 0, "p": 0, "gf": 0, "gc": 0, "dg": 0, "pts": 0}
	for ri in mini(WC_GROUP_ROUNDS, rounds.size()):
		for g in rounds[ri]:
			if not rows.has(g["home"]):
				continue
			var res: Array = g["result"]
			if res.size() < 2:
				continue
			_add(rows[g["home"]], res[0], res[1])
			_add(rows[g["away"]], res[1], res[0])
	var out := rows.values()
	out.sort_custom(_better)
	return out


static func _better(x: Dictionary, y: Dictionary) -> bool:
	if x["pts"] != y["pts"]:
		return x["pts"] > y["pts"]
	if x["dg"] != y["dg"]:
		return x["dg"] > y["dg"]
	if x["gf"] != y["gf"]:
		return x["gf"] > y["gf"]
	return x["team"] < y["team"]


## Grupo de un equipo (o -1).
func group_of(team_i: int) -> int:
	for gi in groups.size():
		if (groups[gi] as Array).has(team_i):
			return gi
	return -1


## Después de los grupos. Con 12 grupos (Mundial), 16avos: primeros contra
## los 8 mejores terceros y contra segundos; los segundos restantes entre sí.
## Con otra cantidad (copa continental de 4 u 8 grupos): pasan los dos
## primeros, cruzados (1.º A contra 2.º B...).
func _round_of_32() -> Array:
	if groups.size() != 12:
		var out := []
		for gi in range(0, groups.size(), 2):
			var a := group_table(gi)
			var b := group_table(gi + 1)
			out.append({"home": a[0]["team"], "away": b[1]["team"], "result": []})
			out.append({"home": b[0]["team"], "away": a[1]["team"], "result": []})
		return out
	var firsts := []
	var seconds := []
	var thirds := []
	for gi in groups.size():
		var t := group_table(gi)
		firsts.append(t[0])
		seconds.append(t[1])
		thirds.append(t[2])
	thirds.sort_custom(_better)
	thirds = thirds.slice(0, 8)
	var games := []
	for i in 8:
		games.append({"home": firsts[i]["team"], "away": thirds[7 - i]["team"], "result": []})
	for i in range(8, 12):
		games.append({"home": firsts[i]["team"], "away": seconds[19 - i]["team"], "result": []})
	for i in 4:
		games.append({"home": seconds[i]["team"], "away": seconds[7 - i]["team"], "result": []})
	return games


## ¿El equipo sigue en carrera (Mundial / Copa)?
func alive(team_i: int) -> bool:
	if kind == Kind.LEAGUE or finished():
		return kind == Kind.LEAGUE or champion == team_i
	if kind == Kind.WORLD_CUP and current < WC_GROUP_ROUNDS:
		return true
	for g in rounds[current]:
		if g["home"] == team_i or g["away"] == team_i:
			return true
	return false


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
			# Localía como en las tablas de Berger: el fijo alterna fecha a fecha
			# y el resto según su lugar, así nadie juega más de dos seguidas de
			# local o de visitante.
			if (r % 2 == 0) if i == 0 else (i % 2 == 1):
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
	if kind == Kind.WORLD_CUP and i < WC_GROUP_ROUNDS:
		return "Fase de grupos · fecha %d de %d" % [i + 1, WC_GROUP_ROUNDS]
	if kind == Kind.CUP or kind == Kind.WORLD_CUP:
		if i >= rounds.size():
			return "Final"
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
		var knockout := kind == Kind.CUP or (kind == Kind.WORLD_CUP and current >= WC_GROUP_ROUNDS)
		if knockout and res.size() == 2 and res[0] == res[1]:
			res.append_array(penalty_shootout(rng))
		g["result"] = res
	current += 1
	if kind == Kind.WORLD_CUP and current <= WC_GROUP_ROUNDS:
		if current == WC_GROUP_ROUNDS:
			rounds.append(_round_of_32())
		return
	if kind == Kind.CUP or kind == Kind.WORLD_CUP:
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
	return {"format": "MasterEleven Partida", "version": 1, "kind": kind, "title": title,
		"option_file": option_file, "created": created, "updated": updated,
		"team_paths": team_paths, "user_team": user_team, "double_round": double_round,
		"rounds": rounds, "current": current, "champion": champion, "groups": groups}


static func from_dict(d: Dictionary) -> Competition:
	var c := Competition.new()
	c.kind = int(d.get("kind", 0))
	c.team_paths.assign(d.get("team_paths", []))
	c.user_team = int(d.get("user_team", 0))
	c.double_round = bool(d.get("double_round", false))
	c.current = int(d.get("current", 0))
	c.champion = int(d.get("champion", -1))
	c.title = String(d.get("title", ""))
	c.option_file = String(d.get("option_file", ""))
	c.created = String(d.get("created", ""))
	c.updated = String(d.get("updated", ""))
	for g in d.get("groups", []):
		var ids := []
		for v in g:
			ids.append(int(v))
		c.groups.append(ids)
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


## Carpeta de partidas de cada tipo: ligas o copas (Copa y Mundial).
static func saves_kind_dir(k: int) -> String:
	return UserData.saves_dir("ligas" if k == Kind.LEAGUE else "copas")


## Guarda la partida en su archivo (la primera vez le busca uno nuevo en la
## carpeta del jugador) o en `path` si se pasa.
func save(path: String = "") -> void:
	if path == "":
		if file == "":
			file = saves_kind_dir(kind).path_join("%s_%s.json" % [["liga", "copa", "mundial"][kind],
				Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "").replace("T", "_")])
			while FileAccess.file_exists(file):
				file = file.get_basename() + "b.json"
		path = file
	var now := Time.get_datetime_string_from_system(false, true)
	if created == "":
		created = now
	updated = now
	if title == "":
		title = default_title()
	UserData.write_text(path, JSON.stringify(to_dict()))


static func load_saved(path: String = SAVE_PATH) -> Competition:
	if not FileAccess.file_exists(path):
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		return null
	var c := from_dict(d)
	c.file = path
	return c


static func delete_saved(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func delete_file() -> void:
	if file != "":
		delete_saved(file)


## "Liga · Boca Juniors", "Mundial 2026 · Argentina"...
func default_title() -> String:
	var who := team(user_team).team_name if user_team < team_paths.size() else ""
	var what: String = "Mundial" if kind == Kind.WORLD_CUP else KIND_NAMES[kind]
	return "%s · %s" % [what, who] if who != "" else what


## Dónde va: "Fecha 7 de 29", "Cuartos de final", "Terminada (campeón: ...)".
func progress_text() -> String:
	if finished():
		var champ := champion if champion >= 0 else (int(standings()[0]["team"]) if kind == Kind.LEAGUE else -1)
		return "Terminada · campeón: %s" % team(champ).team_name if champ >= 0 else "Terminada"
	return round_name()


## Partidas guardadas (ligas y copas), las más nuevas primero:
## [{file, kind, title, progress, updated, finished, option_file}].
static func list_saves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for dir in [UserData.saves_dir("ligas"), UserData.saves_dir("copas")]:
		for f in UserData.files_in(dir, "json"):
			var c := load_saved(f)
			if c == null or c.team_paths.is_empty():
				continue
			out.append({"file": f, "kind": c.kind, "title": c.title if c.title != "" else c.default_title(),
				"progress": c.progress_text(), "updated": c.updated, "finished": c.finished(),
				"option_file": c.option_file})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["updated"]) > String(b["updated"]))
	return out
