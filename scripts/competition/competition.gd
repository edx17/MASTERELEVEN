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
## Fechas de la primera fase (grupos o fase liga): 3 en el Mundial, 6 en
## grupos de ida y vuelta (Libertadores), 8 en la fase liga de 36 (Champions).
var group_rounds := WC_GROUP_ROUNDS
## Cómo se arma la llave después de la primera fase: "" (Mundial: 16avos con
## terceros; otros: 1.º contra 2.º del grupo vecino), "draw" (1.º contra 2.º
## por sorteo), "sud" (playoff de los 2.º contra los que llegan de otra copa,
## y los 1.º esperan en octavos) o "swiss" (fase liga: 1–8 a octavos, 9–24
## al playoff).
var ko := ""
## 2: llaves de ida y vuelta (la final, a partido único).
var legs := 1
## Copa con entrada escalonada: entries[ronda] = equipos que se suman en esa
## ronda (los de abajo arrancan antes). `stage` es la ronda de llave actual.
var entries: Array = []
var stage_names: Array = []
var stage := 0
## Equipos que esperan al ganador del playoff (fase liga o Sudamericana).
var seeds: Array = []
## Equipos que llegan de otra copa (los 3.º de la Libertadores).
var extra: Array = []
## Nombre especial de una fecha ({"índice": "Playoffs"}).
var labels: Dictionary = {}
var draw_seed := 0
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
	return create_groups(paths, user, seed, false, "", 1, hosts)


## Grupos de 4 (bombos por nivel, un equipo de cada bombo por grupo), de una
## rueda (3 fechas) o de ida y vuelta (6), y después llaves (ver `ko`).
static func create_groups(paths: Array[String], user: int, seed: int = 0, two_legs_groups: bool = false,
		ko_mode: String = "", ko_legs: int = 1, hosts: Array[String] = []) -> Competition:
	var c := Competition.new()
	c.kind = Kind.WORLD_CUP
	c.team_paths = paths.duplicate()
	c.user_team = user
	c.ko = ko_mode
	c.legs = ko_legs
	c.group_rounds = WC_GROUP_ROUNDS * (2 if two_legs_groups else 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else randi()
	c.draw_seed = rng.randi()
	var order := _by_level(paths, hosts)
	var n_groups := paths.size() / 4
	for gi in n_groups:
		c.groups.append([])
	for pot in 4:
		var pot_teams: Array = order.slice(pot * n_groups, (pot + 1) * n_groups)
		if pot > 0:
			_shuffle(pot_teams, rng)
		for gi in n_groups:
			c.groups[gi].append(pot_teams[gi])
	var days: Array = [[[0, 1], [2, 3]], [[0, 2], [3, 1]], [[3, 0], [1, 2]]]
	if two_legs_groups:
		for d in days.duplicate():
			days.append(d.map(func(pr: Array) -> Array: return [pr[1], pr[0]]))
	for md in days:
		var games := []
		for g in c.groups:
			for pr in md:
				games.append({"home": g[pr[0]], "away": g[pr[1]], "result": []})
		c.rounds.append(games)
	return c


## Índices de los equipos del más fuerte al más débil (los anfitriones primero).
static func _by_level(paths: Array[String], hosts: Array[String] = []) -> Array:
	var order: Array = range(paths.size())
	var level := {}
	for i in order:
		var lv := 0.0
		for v in TeamDB.load_team(paths[i]).ratings():
			lv += v
		level[i] = lv + (100.0 if hosts.has(paths[i]) else 0.0)
	order.sort_custom(func(a: int, b: int) -> bool: return level[a] > level[b])
	return order


## Copa por eliminación con entrada escalonada: `stage_of[i]` es la ronda en
## la que entra el equipo i (0 = la primera). En cada ronda se sortean los
## ganadores de la anterior junto con los que se suman. `names`: nombre de
## cada ronda ("" = el de siempre: Octavos, Cuartos...).
static func create_staged_cup(paths: Array[String], user: int, stage_of: Array, seed: int = 0, ko_legs: int = 1,
		names: Array = []) -> Competition:
	var c := Competition.new()
	c.kind = Kind.CUP
	c.team_paths = paths.duplicate()
	c.user_team = user
	c.legs = ko_legs
	c.stage_names = names.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else randi()
	c.draw_seed = rng.randi()
	var n_stages := 0
	for s in stage_of:
		n_stages = maxi(n_stages, int(s) + 1)
	for s in n_stages:
		c.entries.append([])
	for i in stage_of.size():
		c.entries[int(stage_of[i])].append(i)
	var first: Array = c.entries[0].duplicate()
	_shuffle(first, rng)
	var pairs: Array = []
	for i in range(0, first.size() - 1, 2):
		pairs.append([first[i], first[i + 1]])
	c._push_ko(pairs)
	return c


## Fase liga (Champions desde 2024): 36 equipos en 4 bombos de 9; cada uno
## juega 8 partidos (2 rivales de cada bombo, uno de local y otro de
## visitante), evitando cruces del mismo país si se puede. Del 1.º al 8.º a
## octavos, del 9.º al 24.º al playoff; llaves de ida y vuelta.
static func create_swiss(paths: Array[String], user: int, seed: int = 0) -> Competition:
	var c := Competition.new()
	c.kind = Kind.WORLD_CUP
	c.team_paths = paths.duplicate()
	c.user_team = user
	c.ko = "swiss"
	c.legs = 2
	c.group_rounds = 8
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else randi()
	c.draw_seed = rng.randi()
	var order := _by_level(paths)
	var n := paths.size()
	var per := n / 4
	var country := func(i: int) -> String: return paths[i].get_slice(":", 2)
	for attempt in 40:
		var pots: Array = []
		for p in 4:
			pots.append(order.slice(p * per, (p + 1) * per))
		var edges: Array = []
		for p in 4:
			for q in range(p, 4):
				var best: Array = []
				var best_bad := 1 << 20
				for t in 30:
					var a: Array = (pots[p] as Array).duplicate()
					var b: Array = (pots[q] as Array).duplicate()
					_shuffle(a, rng)
					_shuffle(b, rng)
					var es: Array = []
					for k in per:
						if p == q:
							es.append([a[k], a[(k + 1) % per]])
						else:
							es.append([a[k], b[k]])
							es.append([b[(k + 1) % per], a[k]])
					var bad := 0
					for e in es:
						if country.call(e[0]) == country.call(e[1]):
							bad += 1
					if bad < best_bad:
						best = es
						best_bad = bad
					if bad == 0:
						break
				edges.append_array(best)
		var days := _matchdays(n, edges, c.group_rounds, rng)
		if not days.is_empty():
			for d in days:
				c.rounds.append(d.map(func(e: Array) -> Dictionary: return {"home": e[0], "away": e[1], "result": []}))
			return c
	# Si no se pudo repartir (no debería pasar): fechas de un todos contra todos.
	var rr := round_robin(n, false, rng.randi())
	for r in c.group_rounds:
		c.rounds.append(rr[r])
	return c


## Reparte los partidos (aristas [local, visitante]) en `days` fechas donde
## cada equipo juega una vez: busca un emparejamiento perfecto por fecha (con
## vuelta atrás) y si se traba vuelve a empezar.
static func _matchdays(n: int, edges: Array, days: int, rng: RandomNumberGenerator) -> Array:
	for attempt in 60:
		var left: Array = edges.duplicate()
		_shuffle(left, rng)
		var out: Array = []
		var ok := true
		for d in days:
			var m := _perfect_matching(n, left)
			if m.is_empty():
				ok = false
				break
			out.append(m)
			for e in m:
				left.erase(e)
		if ok:
			return out
	return []


static func _perfect_matching(n: int, edges: Array) -> Array:
	var adj: Array = []
	for i in n:
		adj.append([])
	for e in edges:
		adj[e[0]].append(e)
		adj[e[1]].append(e)
	var used := PackedByteArray()
	used.resize(n)
	var chosen: Array = []
	var budget := [20000]
	if _match_rec(n, adj, used, chosen, budget):
		return chosen
	return []


static func _match_rec(n: int, adj: Array, used: PackedByteArray, chosen: Array, budget: Array) -> bool:
	budget[0] -= 1
	if budget[0] < 0:
		return false
	# El equipo libre con menos rivales posibles.
	var best := -1
	var best_c := 1 << 20
	for v in n:
		if used[v] == 1:
			continue
		var cnt := 0
		for e in adj[v]:
			if used[e[0]] == 0 and used[e[1]] == 0:
				cnt += 1
		if cnt < best_c:
			best_c = cnt
			best = v
	if best < 0:
		return true
	if best_c == 0:
		return false
	for e in adj[best]:
		if used[e[0]] == 1 or used[e[1]] == 1:
			continue
		used[e[0]] = 1
		used[e[1]] = 1
		chosen.append(e)
		if _match_rec(n, adj, used, chosen, budget):
			return true
		chosen.pop_back()
		used[e[0]] = 0
		used[e[1]] = 0
	return false


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
	for ri in mini(group_rounds, rounds.size()):
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
	if kind == Kind.WORLD_CUP and current < group_rounds:
		return true
	if seeds.has(team_i):
		return true
	for s in range(stage + 1, entries.size()):
		if (entries[s] as Array).has(team_i):
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
	if kind == Kind.WORLD_CUP and i < group_rounds:
		return "%s · fecha %d de %d" % ["Fase liga" if ko == "swiss" else "Fase de grupos", i + 1, group_rounds]
	if kind == Kind.CUP or kind == Kind.WORLD_CUP:
		if i >= rounds.size() or (rounds[i] as Array).is_empty():
			return "Final"
		var teams_left := (rounds[i] as Array).size() * 2
		var base: String = labels.get(str(i), CUP_ROUND_NAMES.get(teams_left, "Ronda %d" % (i + 1)))
		match int((rounds[i][0] as Dictionary).get("leg", 0)):
			1:
				return base + " · ida"
			2:
				return base + " · vuelta"
		return base
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
		var knockout := kind == Kind.CUP or (kind == Kind.WORLD_CUP and current >= group_rounds)
		if knockout and int(g.get("leg", 0)) != 1 and res.size() == 2:
			var agg: Array = g.get("agg", [0, 0])
			if res[0] + int(agg[0]) == res[1] + int(agg[1]):
				res.append_array(penalty_shootout(rng))
		g["result"] = res
	current += 1
	if kind == Kind.WORLD_CUP and current <= group_rounds:
		if current == group_rounds:
			_after_groups()
		return
	if kind == Kind.CUP or kind == Kind.WORLD_CUP:
		_next_ko()
	elif current >= rounds.size():
		champion = int(standings()[0]["team"])


## Arma la ronda siguiente de la llave: la vuelta (si se jugó la ida) o el
## cruce de los ganadores (con los que se suman en esa ronda).
func _next_ko() -> void:
	var last: Array = rounds[current - 1]
	if not last.is_empty() and int(last[0].get("leg", 0)) == 1:
		var back := []
		for g in last:
			var r: Array = g["result"]
			back.append({"home": g["away"], "away": g["home"], "result": [], "leg": 2, "agg": [r[1], r[0]]})
		rounds.append(back)
		if labels.has(str(current - 1)):
			labels[str(current)] = labels[str(current - 1)]
		return
	var winners := []
	for g in last:
		winners.append(winner(g))
	stage += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = draw_seed + stage
	if not seeds.is_empty():
		_push_ko(_seed_pairs(winners, rng))
		return
	if stage < entries.size():
		winners.append_array(entries[stage])
		_shuffle(winners, rng)
	if winners.size() == 1:
		champion = winners[0]
		return
	var pairs := []
	for i in range(0, winners.size() - 1, 2):
		pairs.append([winners[i], winners[i + 1]])
	_push_ko(pairs)


## Agrega una ronda de llave con los cruces [local, visitante] (de ida y
## vuelta si corresponde; la final, siempre a partido único).
func _push_ko(pairs: Array, label: String = "") -> void:
	var two := legs == 2 and pairs.size() > 1
	var games := []
	for pr in pairs:
		var g := {"home": pr[0], "away": pr[1], "result": []}
		if two:
			g["leg"] = 1
		games.append(g)
	rounds.append(games)
	if label == "" and stage < stage_names.size():
		label = String(stage_names[stage])
	if label != "":
		labels[str(rounds.size() - 1)] = label


## Después de la primera fase (grupos o fase liga).
func _after_groups() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = draw_seed
	match ko:
		"swiss":
			var table := standings(0, group_rounds)
			seeds = table.slice(0, 8).map(func(r: Dictionary) -> int: return r["team"])
			var pairs := []
			for k in 8:
				pairs.append([table[23 - k]["team"], table[8 + k]["team"]])
			_push_ko(pairs, "Playoffs")
		"thirds":
			# 6 grupos: pasan los dos primeros y los 4 mejores terceros (octavos).
			var firsts := []
			var seconds := []
			var thirds := []
			for gi in groups.size():
				var t := group_table(gi)
				firsts.append(t[0])
				seconds.append(t[1])
				thirds.append(t[2])
			thirds.sort_custom(_better)
			var q3: Array = thirds.slice(0, 4).map(func(r: Dictionary) -> int: return r["team"])
			var f: Array = firsts.map(func(r: Dictionary) -> int: return r["team"])
			var sec: Array = seconds.map(func(r: Dictionary) -> int: return r["team"])
			var pairs := []
			for k in 4:
				# El 1.º no repite rival de su grupo.
				var opp: int = q3[3 - k]
				if group_of(opp) == k:
					var j := (3 - k + 1) % 4
					var tmp: int = q3[j]
					q3[j] = opp
					q3[3 - k] = tmp
					opp = tmp
				pairs.append([opp, f[k]])
			pairs.append([sec[5], f[4]])
			pairs.append([sec[4], f[5]])
			pairs.append([sec[1], sec[0]])
			pairs.append([sec[3], sec[2]])
			_push_ko(pairs)
		"draw", "sud":
			var firsts := []
			var seconds := []
			var thirds := []
			for gi in groups.size():
				var t := group_table(gi)
				firsts.append(t[0]["team"])
				seconds.append(t[1]["team"])
				thirds.append(t[2]["team"])
			if ko == "sud" and extra.size() == seconds.size():
				var others: Array = extra.duplicate()
				_shuffle(others, rng)
				seeds = firsts
				var pairs := []
				for k in seconds.size():
					pairs.append([others[k], seconds[k]])
				_push_ko(pairs, "Playoffs")
				return
			# 1.º contra 2.º de otro grupo, por sorteo (el 1.º define de local).
			var best: Array = seconds.duplicate()
			for t in 50:
				var sh: Array = seconds.duplicate()
				_shuffle(sh, rng)
				var clash := false
				for k in firsts.size():
					if group_of(sh[k]) == k:
						clash = true
				best = sh
				if not clash:
					break
			var pairs := []
			for k in firsts.size():
				pairs.append([best[k], firsts[k]])
			_push_ko(pairs)
		_:
			var games := _round_of_32()
			_push_ko(games.map(func(g: Dictionary) -> Array: return [g["home"], g["away"]]))


## Cruces de los que esperaban (seeds) con los ganadores del playoff. Fase
## liga: el 1.º contra el ganador de 16.º/17.º... y el 8.º contra el de
## 9.º/24.º, en un cuadro donde el 1.º y el 2.º sólo se cruzan en la final.
func _seed_pairs(winners: Array, rng: RandomNumberGenerator) -> Array:
	var s: Array = seeds.duplicate()
	seeds = []
	if ko == "swiss" and s.size() == 8 and winners.size() == 8:
		var pairs := []
		for i in [0, 7, 3, 4, 1, 6, 2, 5]:
			pairs.append([winners[7 - i], s[i]])
		return pairs
	var w: Array = winners.duplicate()
	_shuffle(s, rng)
	_shuffle(w, rng)
	var pairs := []
	for k in mini(s.size(), w.size()):
		pairs.append([w[k], s[k]])
	return pairs


## Suma equipos que llegan de otra copa (los 3.º de la Libertadores a la
## Sudamericana); devuelve sus índices.
func add_teams(paths: Array[String], user_path: String = "") -> Array:
	var out := []
	for p in paths:
		team_paths.append(p)
		out.append(team_paths.size() - 1)
		if p == user_path and user_path != "":
			user_team = team_paths.size() - 1
	extra = out
	return out


## ¿La ronda `i` es de la primera fase (grupos o fase liga)?
func in_first_phase(i: int = -1) -> bool:
	if i < 0:
		i = current
	return kind == Kind.WORLD_CUP and i < group_rounds


## Ganador de un partido de copa (con penales si hizo falta).
static func winner(g: Dictionary) -> int:
	var r: Array = g["result"]
	if r.size() < 2:
		return -1
	var agg: Array = g.get("agg", [0, 0])
	var h: int = r[0] + int(agg[0])
	var a: int = r[1] + int(agg[1])
	if h != a:
		return g["home"] if h > a else g["away"]
	if r.size() >= 4:
		return g["home"] if r[2] > r[3] else g["away"]
	return -1


## Tabla de la liga: [{team, pj, g, e, p, gf, gc, dg, pts}] ordenada. Con
## `from`/`to`, sólo esas fechas (la primera rueda, la fase liga...).
func standings(from: int = 0, to: int = -1) -> Array:
	var rows := {}
	for i in team_paths.size():
		rows[i] = {"team": i, "pj": 0, "g": 0, "e": 0, "p": 0, "gf": 0, "gc": 0, "dg": 0, "pts": 0}
	if to < 0 or to > rounds.size():
		to = rounds.size()
	for ri in range(from, to):
		for g in rounds[ri]:
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
		"rounds": rounds, "current": current, "champion": champion, "groups": groups,
		"group_rounds": group_rounds, "ko": ko, "legs": legs, "entries": entries, "stage_names": stage_names,
		"stage": stage, "seeds": seeds, "extra": extra, "labels": labels, "draw_seed": draw_seed}


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
	# JSON guarda los números como float: se pasan a int.
	var ints := func(a: Array) -> Array: return a.map(func(v: Variant) -> int: return int(v))
	for g in d.get("groups", []):
		c.groups.append(ints.call(g))
	c.group_rounds = int(d.get("group_rounds", WC_GROUP_ROUNDS))
	c.ko = String(d.get("ko", ""))
	c.legs = int(d.get("legs", 1))
	for e in d.get("entries", []):
		c.entries.append(ints.call(e))
	c.stage_names = d.get("stage_names", [])
	c.stage = int(d.get("stage", 0))
	c.seeds = ints.call(d.get("seeds", []))
	c.extra = ints.call(d.get("extra", []))
	c.labels = d.get("labels", {})
	c.draw_seed = int(d.get("draw_seed", 0))
	for r in d.get("rounds", []):
		var games := []
		for g in r:
			var gm := {"home": int(g["home"]), "away": int(g["away"]), "result": ints.call(g.get("result", []))}
			if g.has("leg"):
				gm["leg"] = int(g["leg"])
			if g.has("agg"):
				gm["agg"] = ints.call(g["agg"])
			games.append(gm)
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
