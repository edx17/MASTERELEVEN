class_name SeasonAwards
extends RefCounted
## Premios de fin de temporada de la Liga Master: Balón de Oro, mejor jugador
## de América, Europa, África, Asia y Oceanía, Premio Puskás, Bota de Oro,
## Guante de Oro y Golden Boy.
##
## Candidatos: los jugadores de la carrera (con sus goles reales de la
## temporada) y los de los mejores clubes de los otros países (con goles
## estimados por puesto y nivel). África, Asia y Oceanía se eligen por
## nacionalidad, entre los planteles de sus selecciones. Suman los títulos:
## copa continental principal, liga, Mundial de Clubes / Intercontinental y
## el Mundial de selecciones.

## Copas que más pesan (las principales de cada confederación y las mundiales).
const TOP_CUPS := ["ucl", "lib", "cca", "cwc", "intercontinental"]
const SECOND_CUPS := ["uel", "uecl", "sud", "recopa", "super_uefa"]
const FOREIGN_CLUBS_PER_COUNTRY := 3
const YOUNG_AGE := 21

const AWARDS := ["Balón de Oro", "Mejor jugador de América", "Mejor jugador de Europa", "Mejor jugador de África",
	"Mejor jugador de Asia", "Mejor jugador de Oceanía", "Premio Puskás", "Bota de Oro", "Guante de Oro", "Golden Boy"]


## [{award, n, club, nat, detail, club_id}] de la temporada que terminó.
static func compute(m: MasterCareer, summary: Dictionary, rng: RandomNumberGenerator) -> Array:
	var bonus := _title_bonus(m, summary)
	var clubs := _club_candidates(m, bonus)
	var out: Array = []
	var best := _best(clubs, func(_c: Dictionary) -> bool: return true)
	_add(out, "Balón de Oro", best, "%d goles" % int(best.get("goals", 0)) if not best.is_empty() else "")
	for pair in [["Mejor jugador de América", ["conmebol", "concacaf"]], ["Mejor jugador de Europa", ["uefa"]]]:
		var confeds: Array = pair[1]
		var b := _best(clubs, func(c: Dictionary) -> bool: return confeds.has(c["confed"]))
		_add(out, pair[0], b, "")
	for pair in [["Mejor jugador de África", "CAF"], ["Mejor jugador de Asia", "AFC"], ["Mejor jugador de Oceanía", "OFC"]]:
		var b := _best(_nation_candidates(String(pair[1]), summary), func(_c: Dictionary) -> bool: return true)
		_add(out, pair[0], b, "")
	# Puskás: un golazo de la temporada (más chances para los que más
	# hicieron y los más técnicos).
	var scorers: Array = clubs.filter(func(c: Dictionary) -> bool: return c["real_goals"] and int(c["goals"]) > 0)
	if not scorers.is_empty():
		var total := 0.0
		for c in scorers:
			total += _goal_weight(c)
		var x := rng.randf() * total
		for c in scorers:
			x -= _goal_weight(c)
			if x <= 0.0:
				_add(out, "Premio Puskás", c, "por un golazo")
				break
	var top := m.top_scorers(-1, 1)
	if not top.is_empty():
		var row: Dictionary = top[0]
		out.append({"award": "Bota de Oro", "n": row["n"], "club": m._club_name(String(row["club"])), "club_id": String(row["club"]),
			"nat": "", "detail": "%d goles" % int(row["goals"])})
	_add(out, "Guante de Oro", _best(clubs, func(c: Dictionary) -> bool: return c["gk"]), "")
	_add(out, "Golden Boy", _best(clubs, func(c: Dictionary) -> bool: return int(c["age"]) <= YOUNG_AGE),
		"sub-%d" % (YOUNG_AGE + 1))
	return out


static func _add(out: Array, award: String, c: Dictionary, detail: String) -> void:
	if c.is_empty():
		return
	out.append({"award": award, "n": c["n"], "club": c["club"], "club_id": c.get("club_id", ""), "nat": c.get("nat", ""),
		"detail": detail})


static func _best(list: Array, ok: Callable) -> Dictionary:
	var best := {}
	for c in list:
		if ok.call(c) and (best.is_empty() or float(c["score"]) > float(best["score"])):
			best = c
	return best


static func _goal_weight(c: Dictionary) -> float:
	var a: Dictionary = c["d"].get("a", {})
	return float(c["goals"]) * pow(float(a.get("technique", 60)) / 60.0, 3.0)


## Puntos extra por club (ruta) según lo que ganó en la temporada.
static func _title_bonus(m: MasterCareer, summary: Dictionary) -> Dictionary:
	var bonus := {}
	var cups: Dictionary = summary.get("cups", {})
	for id in cups:
		var path := String(cups[id].get("champion_path", ""))
		if String(cups[id].get("type", "")) == "youth" or path == "":
			continue
		var b := 8.0 if TOP_CUPS.has(id) else (4.0 if SECOND_CUPS.has(id) else 2.0)
		bonus[path] = float(bonus.get(path, 0.0)) + b
	var divs: Array = summary.get("divisions", [])
	if not divs.is_empty():
		var path := TeamDB.club_path(m.country, String(divs[0]["champion"]))
		bonus[path] = float(bonus.get(path, 0.0)) + 5.0
	return bonus


static func _entry(d: Dictionary, club: String, club_id: String, confed: String, goals: int, real: bool, extra: float) -> Dictionary:
	var ovr := MasterCareer.dict_overall(d)
	var gk := String(d.get("pos", "")) == "GK"
	return {"d": d, "n": String(d.get("n", "?")), "club": club, "club_id": club_id, "nat": String(d.get("nat", "")),
		"confed": confed, "goals": goals, "real_goals": real, "age": int(d.get("age", 25)), "gk": gk,
		"score": float(ovr) + goals * (0.35 if not gk else 0.0) + extra}


## Jugadores de los clubes de la carrera y de los mejores clubes de afuera.
static func _club_candidates(m: MasterCareer, bonus: Dictionary) -> Array:
	var out: Array = []
	var own := CareerCups.confed_of(m.country)
	for key in m.world.clubs:
		var club := String(key).get_slice(":", 1)
		if String(key).get_slice(":", 0) != m.country or club == MasterCareer.FREE_CLUB:
			continue
		var path := TeamDB.club_path(m.country, club)
		var extra := float(bonus.get(path, 0.0))
		for d in m.world.clubs[key].get("players", []):
			var goals := int((m.scorers.get(str(int(d.get("pid", 0))), {}) as Dictionary).get("goals", 0))
			out.append(_entry(d, m._club_name(club), club, own, goals, true, extra))
	for c in TeamDB.countries():
		var cid := String(c["id"])
		if cid == m.country or (c["divisions"] as Array).is_empty():
			continue
		var top: Array = (c["divisions"][0]["clubs"] as Array).duplicate()
		top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("r", 0)) > int(b.get("r", 0)))
		for cl in top.slice(0, FOREIGN_CLUBS_PER_COUNTRY):
			var path := TeamDB.club_path(cid, String(cl["id"]))
			var t := TeamDB.load_team(path)
			if t == null:
				continue
			for p in t.players:
				var d := TeamDB.player_to_dict(p)
				out.append(_entry(d, t.team_name, "", CareerCups.confed_of(cid), _estimated_goals(d), false,
					float(bonus.get(path, 0.0))))
	return out


## Goles de una temporada de un jugador de afuera, por puesto y nivel.
static func _estimated_goals(d: Dictionary) -> int:
	var ovr := MasterCareer.dict_overall(d)
	var share: float = {"CF": 0.7, "WG": 0.4, "AMF": 0.35, "LMF": 0.2, "RMF": 0.2, "CMF": 0.15}.get(String(d.get("pos", "")), 0.05)
	return maxi(0, roundi((ovr - 55) * share))


## Jugadores de las selecciones de una confederación (por nacionalidad).
static func _nation_candidates(conf: String, summary: Dictionary) -> Array:
	var out: Array = []
	var wc: Dictionary = summary.get("world_cup", {})
	for n in TeamDB.nations():
		if String(n.get("conf", "")) != conf:
			continue
		var t := TeamDB.load_team(TeamDB.nation_path(String(n["id"])))
		if t == null:
			continue
		var extra := 6.0 if String(wc.get("champion", "")) == t.team_name else 0.0
		for p in t.players:
			var d := TeamDB.player_to_dict(p)
			d["nat"] = t.team_name
			out.append(_entry(d, t.team_name, "", conf, _estimated_goals(d), false, extra))
	return out
