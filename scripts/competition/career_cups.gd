class_name CareerCups
extends RefCounted
## Copas de la Liga Master: qué se juega en cada país y confederación, con qué
## formato y quién clasifica (todo con los resultados de la temporada
## anterior de la carrera; en la primera, por nivel).
##   - Copa nacional con entrada escalonada (los de abajo arrancan antes).
##     Copa Argentina: los de Primera y los 15 mejores de la Primera Nacional
##     directo a 32avos; la B y la C juegan la fase preliminar (los cupos del
##     Federal A, que no está en la base, también salen de ahí).
##   - Copa de la liga (EFL Cup, Taça da Liga) y supercopas nacionales.
##   - Copas continentales: Champions, Europa League y Conference (fase liga
##     de 36), Libertadores y Sudamericana (8 grupos de 4 de ida y vuelta; los
##     3.º de la Libertadores juegan el playoff de la Sudamericana) y
##     Concachampions (16, llaves de ida y vuelta).
##   - Recopa Sudamericana, Supercopa de Europa, Copa Intercontinental (todos
##     los años) y Mundial de Clubes (cada 4 años desde 2029).
## Con sólo algunas ligas en la base, los cupos que en la realidad son de
## otros países los ocupan los mejores que no clasificaron (si se agrega una
## liga en el editor, sus clubes entran solos).

## Copa nacional: cuadro principal, cuántos entran directo y cupos por
## división (-1 = todos).
const NATIONAL := {
	"arg": {"name": "Copa Argentina", "bracket": 64, "direct": 45, "quota": [-1, 15, -1, -1],
		"prelim": "Fase preliminar · %d.ª ronda"},
	"eng": {"name": "FA Cup", "bracket": 64, "direct": 44, "prelim": "%d.ª ronda"},
	"esp": {"name": "Copa del Rey", "bracket": 32, "direct": 4, "prelim": "%d.ª ronda"},
	"ita": {"name": "Coppa Italia", "bracket": 16, "direct": 8, "prelim": "%d.ª ronda"},
	"ger": {"name": "DFB-Pokal", "bracket": 32, "direct": 0, "prelim": "%d.ª ronda"},
	"por": {"name": "Taça de Portugal", "bracket": 16, "direct": 0, "prelim": "%d.ª eliminatoria"},
	"ned": {"name": "KNVB Beker", "bracket": 16, "direct": 0, "prelim": "%d.ª ronda"},
	"bra": {"name": "Copa do Brasil", "bracket": 16, "direct": 0, "prelim": "%d.ª fase"},
}
## Copa de la liga.
const LEAGUE_CUPS := {
	"eng": {"name": "EFL Cup", "bracket": 32, "direct": 8, "prelim": "%d.ª ronda"},
	"por": {"name": "Taça da Liga", "bracket": 8, "direct": 0, "prelim": "%d.ª ronda"},
}
## Supercopas nacionales (con la temporada anterior):
##   "final": campeón de liga contra campeón de copa.
##   "four": campeón y subcampeón de liga y finalistas de la copa (semis y final).
##   "halves": campeón de la primera rueda (Apertura) contra el de la segunda (Clausura).
const SUPERS := {
	"arg": [{"id": "trofeo", "name": "Trofeo de Campeones", "kind": "halves"}],
	"eng": [{"id": "super", "name": "Community Shield", "kind": "final"}],
	"esp": [{"id": "super", "name": "Supercopa de España", "kind": "four"}],
	"ita": [{"id": "super", "name": "Supercoppa Italiana", "kind": "four"}],
	"ger": [{"id": "super", "name": "DFL-Supercup", "kind": "final"}],
	"por": [{"id": "super", "name": "Supertaça", "kind": "final"}],
	"ned": [{"id": "super", "name": "Johan Cruijff Schaal", "kind": "final"}],
	"bra": [{"id": "super", "name": "Supercopa do Brasil", "kind": "final"}],
	"mex": [{"id": "super", "name": "Campeón de Campeones", "kind": "halves"}],
}
## Países con Apertura y Clausura (las dos ruedas de la liga).
const HALVES := ["arg", "mex"]

const CONFED := {
	"uefa": ["eng", "esp", "ita", "ger", "por", "ned", "fra", "bel", "sco", "tur", "gre", "sui", "aut", "den", "swe",
		"nor", "rus", "ukr", "cro", "srb", "pol", "cze"],
	"conmebol": ["arg", "bra", "uru", "col", "chi", "par", "per", "ecu", "bol", "ven"],
	"concacaf": ["mex", "usa", "can", "crc", "hon", "gua", "pan", "jam", "slv"],
}
## Copas de cada confederación (la primera es la principal).
const CONTINENTAL := {
	"uefa": [{"id": "ucl", "name": "UEFA Champions League", "size": 36, "format": "swiss"},
		{"id": "uel", "name": "UEFA Europa League", "size": 36, "format": "swiss"},
		{"id": "uecl", "name": "UEFA Conference League", "size": 36, "format": "swiss"}],
	"conmebol": [{"id": "lib", "name": "Copa Libertadores", "size": 32, "format": "draw"},
		{"id": "sud", "name": "Copa Sudamericana", "size": 32, "format": "sud"}],
	"concacaf": [{"id": "cca", "name": "Concacaf Champions Cup", "size": 16, "format": "knockout"}],
}
## Cupos por posición en la liga para cada copa de la confederación (en
## orden). `cup`: a qué copa va el campeón de la copa nacional (si ya
## clasificó o no se jugó, el lugar pasa al siguiente de la tabla).
const SLOTS := {
	"eng": {"by_table": [4, 1, 1], "cup": 1, "league_cup": 2},
	"esp": {"by_table": [4, 1, 1], "cup": 1},
	"ita": {"by_table": [4, 1, 1], "cup": 1},
	"ger": {"by_table": [4, 1, 1], "cup": 1},
	"fra": {"by_table": [3, 1, 1], "cup": 1},
	"por": {"by_table": [2, 1, 1], "cup": 1},
	"ned": {"by_table": [2, 1, 2], "cup": 1},
	"arg": {"by_table": [5, 6], "cup": 0},
	"bra": {"by_table": [6, 6], "cup": 0},
	"uru": {"by_table": [2, 2]},
	"par": {"by_table": [2, 2]},
	"chi": {"by_table": [2, 2]},
	"col": {"by_table": [2, 2]},
	"ecu": {"by_table": [2, 2]},
	"per": {"by_table": [2, 2]},
	"bol": {"by_table": [2, 2]},
	"ven": {"by_table": [2, 2]},
	"mex": {"by_table": [9]},
}
const DEFAULT_SLOTS := {"by_table": [1, 1, 1]}
## Campeones que vuelven a jugar: id de la copa ganada → copa a la que entra.
const HOLDERS := {"ucl": "ucl", "uel": "ucl", "uecl": "uel", "lib": "lib", "sud": "lib", "cca": "cca"}
## Supercopa continental: campeones de las dos primeras copas.
const CONT_SUPER := {
	"uefa": {"id": "uefa_super", "name": "Supercopa de Europa", "from": ["ucl", "uel"], "legs": 1},
	"conmebol": {"id": "recopa", "name": "Recopa Sudamericana", "from": ["lib", "sud"], "legs": 2},
}
const CLUB_WORLD_CUP_FIRST := 2029
## Mundial de Clubes: 32 (8 grupos de 4); cupos por confederación.
const CWC_QUOTA := {"uefa": 16, "conmebol": 10, "concacaf": 6}

## Puntos WE por ganar cada copa.
const POINTS := {"national": 3000, "league_cup": 2000, "super": 1500, "ucl": 8000, "uel": 5000, "uecl": 3500,
	"lib": 8000, "sud": 5000, "cca": 5000, "uefa_super": 2500, "recopa": 2500, "intercontinental": 6000,
	"cwc": 10000}


static func confed_of(country_id: String) -> String:
	for k in CONFED:
		if (CONFED[k] as Array).has(country_id):
			return k
	return ""


## Países de la base (o del Option File) que son de esa confederación.
static func confed_countries(confed: String) -> Array:
	var out: Array = []
	for c in TeamDB.countries():
		if confed_of(String(c["id"])) == confed:
			out.append(String(c["id"]))
	return out


## Rondas de entrada para `n` equipos ordenados del mejor al peor: los
## `direct` primeros entran al cuadro principal de `bracket`; el resto juega
## rondas previas (los peores arrancan antes) hasta que quedan los lugares
## justos. Devuelve la ronda de cada uno (-1 = no entra).
static func plan_stages(n: int, direct: int, bracket: int) -> Array:
	direct = mini(direct, mini(n, bracket))
	var pool := n - direct
	var r := bracket - direct
	var out: Array = []
	if r <= 0 or pool <= r:
		for i in n:
			out.append(0 if i < direct + mini(pool, maxi(r, 0)) else -1)
		return out
	# Partidos de cada ronda previa, de la última hacia atrás.
	var left := pool - r
	var ms: Array = []
	var cap := r
	while left > 0:
		var m := mini(cap, left)
		ms.push_front(m)
		left -= m
		cap = 2 * m
	var main := ms.size()
	# Cuántos entran en cada ronda: al cuadro, r - (ganadores de la última
	# previa); en la previa s, 2·m(s) - ganadores de la anterior.
	var enter: Array = []
	for s in main + 1:
		if s == main:
			enter.append(r - int(ms[main - 1]))
		elif s == 0:
			enter.append(2 * int(ms[0]))
		else:
			enter.append(2 * int(ms[s]) - int(ms[s - 1]))
	for i in direct:
		out.append(main)
	for s in range(main, -1, -1):
		for k in int(enter[s]):
			out.append(s)
	return out


## Nombres de las rondas: las previas con el patrón; el cuadro, los de siempre.
static func stage_names(stage_of: Array, pattern: String) -> Array:
	var n := 0
	for s in stage_of:
		n = maxi(n, int(s) + 1)
	var out: Array = []
	var prelims := n - 1
	for s in n:
		out.append(pattern % (s + 1) if s < prelims and pattern != "" else "")
	return out


## Copa por entrada escalonada con equipos ordenados (mejor a peor).
static func staged_cup(ordered: Array[String], spec: Dictionary, user_path: String, seed: int) -> Competition:
	var n := ordered.size()
	if n < 2:
		return null
	var bracket := 2
	while bracket * 2 <= mini(n, int(spec.get("bracket", 32))):
		bracket *= 2
	var st := plan_stages(n, int(spec.get("direct", 0)), bracket)
	var paths: Array[String] = []
	var stages: Array = []
	for i in n:
		if int(st[i]) >= 0:
			paths.append(ordered[i])
			stages.append(st[i])
	return Competition.create_staged_cup(paths, paths.find(user_path), stages, seed, int(spec.get("legs", 1)),
		stage_names(stages, String(spec.get("prelim", ""))))


## Partido único (o semis y final con 4) entre equipos fijos.
static func fixed_cup(paths: Array[String], user_path: String, seed: int, legs: int = 1, names: Array = []) -> Competition:
	var stage_of: Array = []
	for p in paths:
		stage_of.append(0)
	var c := Competition.create_staged_cup(paths, paths.find(user_path), stage_of, seed, legs, names)
	# Cruces en el orden dado (1 contra 4 y 2 contra 3... ya ordenados).
	var games: Array = c.rounds[0]
	for k in games.size():
		games[k]["home"] = 2 * k
		games[k]["away"] = 2 * k + 1
	return c


## Suma de los puntajes del equipo (para ordenar por nivel).
static func strength(path: String, cache: Dictionary) -> float:
	if cache.has(path):
		return cache[path]
	var total := 0.0
	var t := TeamDB.load_team(path)
	if t != null:
		for v in t.ratings():
			total += v
	cache[path] = total
	return total


## Clubes de una división de un país (rutas).
static func division_clubs(country_id: String, index: int) -> Array[String]:
	var out: Array[String] = []
	var divs: Array = TeamDB.country(country_id).get("divisions", [])
	if index < divs.size():
		for cl in divs[index]["clubs"]:
			out.append(TeamDB.club_path(country_id, String(cl["id"])))
	return out


## Tabla "de la temporada pasada" de un país que no es el de la carrera: por
## nivel con algo de azar.
static func guessed_table(country_id: String, index: int, rng: RandomNumberGenerator, cache: Dictionary) -> Array[String]:
	var clubs := division_clubs(country_id, index)
	var score := {}
	for p in clubs:
		score[p] = strength(p, cache) * rng.randf_range(0.93, 1.07)
	clubs.sort_custom(func(a: String, b: String) -> bool: return score[a] > score[b])
	return clubs


## Clasificados a las copas de una confederación:
## {id_copa: [rutas]} con `tables` = {país: [rutas de primera en orden]},
## `cup_winners` = {país: {"national": ruta, "league_cup": ruta}} y
## `holders` = {id_copa_ganada: ruta}.
static func qualify(confed: String, tables: Dictionary, cup_winners: Dictionary, holders: Dictionary,
		cache: Dictionary) -> Dictionary:
	var comps: Array = CONTINENTAL.get(confed, [])
	var out := {}
	var taken := {}
	for spec in comps:
		out[spec["id"]] = []
	var put := func(cid: String, path: String) -> bool:
		if path == "" or taken.has(path) or not out.has(cid):
			return false
		if (out[cid] as Array).size() >= int(_spec(confed, cid).get("size", 0)):
			return false
		out[cid].append(path)
		taken[path] = true
		return true
	# Copa por copa (de la más importante a la menor): los campeones que
	# vuelven, el campeón de copa nacional y los de la tabla. Un club que ya
	# entró a una copa mayor deja su lugar al siguiente de la tabla.
	var pos := {}
	for ci in comps.size():
		var cid := String(comps[ci]["id"])
		for won in HOLDERS:
			if holders.has(won) and String(HOLDERS[won]) == cid:
				put.call(cid, String(holders[won]))
		for country_id in tables:
			var table: Array = tables[country_id]
			var sl: Dictionary = SLOTS.get(country_id, DEFAULT_SLOTS)
			var by_table: Array = sl["by_table"]
			var wins: Dictionary = cup_winners.get(country_id, {})
			var want := int(by_table[ci]) if ci < by_table.size() else 0
			for key in ["cup", "league_cup"]:
				if sl.has(key) and int(sl[key]) == ci:
					var key_win: String = "national" if key == "cup" else key
					if not put.call(cid, String(wins.get(key_win, ""))):
						want += 1
			var at := int(pos.get(country_id, 0))
			while want > 0 and at < table.size():
				if put.call(cid, String(table[at])):
					want -= 1
				at += 1
			pos[country_id] = at
	# Los lugares que faltan (en la realidad, los que pasan las fases previas
	# o los de países que no están en la base): los mejores de primera
	# división que no clasificaron. Nunca clubes del ascenso.
	var pool: Array[String] = []
	for country_id in confed_countries(confed):
		for p in division_clubs(country_id, 0):
			if not taken.has(p):
				pool.append(p)
	pool.sort_custom(func(a: String, b: String) -> bool: return strength(a, cache) > strength(b, cache))
	for ci in comps.size():
		var cid := String(comps[ci]["id"])
		for p in pool:
			if (out[cid] as Array).size() >= int(comps[ci]["size"]):
				break
			put.call(cid, p)
	return out


static func _spec(confed: String, cid: String) -> Dictionary:
	for spec in CONTINENTAL.get(confed, []):
		if spec["id"] == cid:
			return spec
	return {}


## Arma una copa continental con sus clasificados.
static func continental_comp(spec: Dictionary, paths: Array[String], user_path: String, seed: int) -> Competition:
	if paths.size() != int(spec["size"]):
		return null
	var me := paths.find(user_path)
	match String(spec["format"]):
		"swiss":
			return Competition.create_swiss(paths, me, seed)
		"draw", "sud":
			return Competition.create_groups(paths, me, seed, true, String(spec["format"]), 2)
		_:
			# Llaves de ida y vuelta, los mejores separados.
			var order := Competition._by_level(paths)
			var ordered: Array[String] = []
			for i in order:
				ordered.append(paths[i])
			var bracket: Array[String] = []
			var n := ordered.size()
			for k in n / 2:
				bracket.append(ordered[n - 1 - k])
				bracket.append(ordered[k])
			return fixed_cup(bracket, user_path, seed, 2)


## Cantidad de fechas que va a tener una copa (para repartirlas en la temporada).
static func total_rounds(c: Competition) -> int:
	var matches: Array = []
	if c.kind == Competition.Kind.WORLD_CUP:
		match c.ko:
			"swiss", "sud":
				matches = [8, 8, 4, 2, 1]
			"draw":
				matches = _halving(c.groups.size())
			_:
				matches = _halving(16 if c.groups.size() == 12 else c.groups.size())
	else:
		var alive := 0
		for s in c.entries.size():
			alive += (c.entries[s] as Array).size()
			matches.append(alive / 2)
			alive /= 2
		var last: int = matches[matches.size() - 1] if not matches.is_empty() else 1
		matches.append_array(_halving(last / 2))
	var total := c.group_rounds if c.kind == Competition.Kind.WORLD_CUP else 0
	for m in matches:
		total += 2 if c.legs == 2 and int(m) > 1 else 1
	return total


static func _halving(m: int) -> Array:
	var out: Array = []
	while m >= 1:
		out.append(m)
		m /= 2
	return out
