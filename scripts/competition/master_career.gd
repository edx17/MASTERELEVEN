class_name MasterCareer
extends RefCounted
## Liga Master (Paso D1): una carrera de club en un país.
##   - Se elige país y club. Se arranca en la división de abajo (Argentina e
##     Inglaterra) o en la 2.ª (el resto); si el club es de más arriba, baja
##     a esa división y sube un club de cada división de por medio.
##   - Plantel real o Equipo WE (plantel genérico con el nombre y la camiseta
##     del club elegido); con un club de primera, el Equipo WE es obligatorio.
##   - Cada carrera tiene su propio "mundo": un Option File con todos los
##     clubes del país y sus planteles fijados (cada jugador con su pid), que
##     TeamDB usa mientras se juega la carrera. Así los ascensos no cambian
##     los planteles y las fases siguientes (lesiones, pases, evolución) los
##     pueden modificar.
##   - Temporada: todas las divisiones a la vez, ida y vuelta, una fecha de
##     cada una por vez. Goleadores. Al terminar, ascensos y descensos
##     (TeamDB.relegation_count) y la temporada siguiente.
##   - Puntos WE: se ganan con los resultados (se gastan en el mercado, D3).
## Se guarda en Documentos/MasterEleven/saves/master, un archivo por carrera.

const FORMAT := "MasterEleven Liga Master"
const VERSION := 1
const START_POINTS := 3000
const POINTS := {"win": 400, "draw": 200, "loss": 100, "goal": 50, "title": 3000, "promotion": 2000}
## Países donde se arranca en la división más baja (en el resto, en la 2.ª).
const START_AT_BOTTOM := ["arg", "eng"]
## Equipo WE: un poco por debajo del nivel de la división donde arranca.
const WE_LEVEL_PENALTY := 4

var file := ""
var title := ""
## Option File con el que se creó (sus plantillas de camisetas se siguen usando).
var option_file := ""
var created := ""
var updated := ""
var country := ""
var season := 1
var first_year := 2026
var user_club := ""
## "real" (plantel del club) o "we" (Equipo WE).
var squad_mode := "real"
var points := START_POINTS
## Mundo de la carrera (clubes del país con planteles y divisiones).
var world := OptionFile.new()
## Una liga por división, en orden: [{"division": id, "comp": Competition}].
var leagues: Array = []
## Goleadores de la temporada: {"pid": {"n", "club", "div", "goals"}}.
var scorers: Dictionary = {}
## Resumen de cada temporada terminada (ver _end_season).
var history: Array = []
## La temporada terminó y se está mostrando el resumen.
var season_over := false
var next_pid := 1
## Atributos de tus jugadores al empezar la temporada ({pid: {attr: valor}}),
## para mostrar cuánto crecieron.
var season_start: Dictionary = {}
## Pases de la carrera: [{season, n, from, to, price, kind ("compra",
## "préstamo", "venta", "libre", "ia", "vuelta")}].
var transfers: Array = []
## Noticias de la carrera (las más nuevas al final): [{season, round, text, kind}].
var news: Array = []
## Copas de la temporada (Fase 7): la nacional y la continental, con la
## fecha de la liga después de la que se juega cada ronda.
var national_cup: Competition = null
var cup_after: Array = []
var continental: Competition = null
var cont_after: Array = []
var cont_name := ""
const NEWS_MAX := 120
## Pase "bombazo" (noticia aunque no sea de tu club): desde este valor.
const BIG_TRANSFER := 12000


# --- Creación -----------------------------------------------------------------------

## Países con más de una división.
static func eligible_countries() -> Array:
	return TeamDB.countries().filter(func(c: Dictionary) -> bool: return (c["divisions"] as Array).size() >= 2)


## Índice de la división donde se arranca en ese país.
static func start_division(country_id: String) -> int:
	var n := (TeamDB.country(country_id).get("divisions", []) as Array).size()
	return n - 1 if START_AT_BOTTOM.has(country_id) else mini(1, n - 1)


## Índice de la división del club en el país (o -1).
static func division_of(country_id: String, club_id: String) -> int:
	var divs: Array = TeamDB.country(country_id).get("divisions", [])
	for i in divs.size():
		for cl in divs[i]["clubs"]:
			if String(cl["id"]) == club_id:
				return i
	return -1


## ¿Con este club sólo se puede ir con el Equipo WE? (los de primera).
static func we_forced(country_id: String, club_id: String) -> bool:
	return division_of(country_id, club_id) == 0


## Carrera nueva (con los datos que TeamDB tenga activos: base + Option File).
static func create(country_id: String, club_id: String, mode: String, seed: int = 0) -> MasterCareer:
	var m := MasterCareer.new()
	m.country = country_id
	m.user_club = club_id
	m.squad_mode = "we" if we_forced(country_id, club_id) else mode
	m.option_file = GameSettings.active_optionfile
	m.world.name = m.option_file
	if TeamDB.option_file != null:
		m.world.rules = TeamDB.option_file.rules.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else randi()
	var c := TeamDB.country(country_id)
	var divs: Array = c["divisions"]
	var start := start_division(country_id)
	# Divisiones y planteles fijados (con un pid por jugador).
	var lists: Array = []
	for d in divs:
		var ids: Array = []
		for cl in d["clubs"]:
			var id := String(cl["id"])
			var e: Dictionary = (cl as Dictionary).duplicate(true)
			if not e.has("players") or (e["players"] as Array).is_empty():
				var list: Array = []
				for p in TeamDB.load_team(TeamDB.club_path(country_id, id)).players:
					list.append(TeamDB.player_to_dict(p))
				e["players"] = list
			for p in e["players"]:
				p["pid"] = m.next_pid
				m.next_pid += 1
			m.world.set_club(country_id, e)
			ids.append(id)
		lists.append(ids)
	# El club del jugador baja a la división de inicio; para que no cambien
	# los tamaños, sube un club de cada división de por medio (de a una).
	var from := division_of(country_id, club_id)
	if from >= 0 and from < start:
		lists[from].erase(club_id)
		for d in range(start, from, -1):
			var pool: Array = lists[d]
			var other: String = pool[rng.randi_range(0, pool.size() - 1)]
			pool.erase(other)
			lists[d - 1].append(other)
		lists[start].append(club_id)
	for i in divs.size():
		m.world.set_division(country_id, String(divs[i]["id"]), lists[i])
	if m.squad_mode == "we":
		m._make_we_squad(int(divs[start].get("level", start + 1)), String(divs[start]["id"]), rng.randi())
	m._new_season_leagues(rng.randi())
	m._snapshot_season()
	return m


## Plantel genérico del Equipo WE (con la camiseta y el nombre del club).
func _make_we_squad(level_index: int, division_id: String, seed: int) -> void:
	var key := "%s:%s" % [country, user_club]
	var e: Dictionary = world.clubs[key]
	var co := TeamDB.country(country)
	var t := TeamData.new()
	var fname := String(e.get("formation", "4-4-2"))
	var fpath := "res://data/formations/f_%s.tres" % fname
	t.formation = load(fpath) if ResourceLoader.exists(fpath) else load("res://data/formations/f_4-4-2.tres")
	t.id = "%s_%s_we" % [country, user_club]
	var level := int(TeamDB.DIVISION_LEVEL.get(level_index, 56)) + int(TeamDB.LEAGUE_BONUS.get(division_id, 0)) - WE_LEVEL_PENALTY
	TeamDB.generate_roster(t, level, String(co.get("names", "en")), co.get("skin", [40, 30, 18, 12]),
		String(co.get("nationality", "")), seed)
	var list: Array = []
	for p in t.players:
		var d := TeamDB.player_to_dict(p)
		d["pid"] = next_pid
		next_pid += 1
		list.append(d)
	e["players"] = list


## Una liga de ida y vuelta por división, con la composición actual del mundo.
func _new_season_leagues(seed: int) -> void:
	leagues.clear()
	activate()
	var divs: Array = TeamDB.country(country)["divisions"]
	for i in divs.size():
		var paths: Array[String] = []
		for cl in divs[i]["clubs"]:
			paths.append(TeamDB.club_path(country, String(cl["id"])))
		var me := paths.find(TeamDB.club_path(country, user_club))
		var comp := Competition.create_league(paths, me, true, seed + i)
		leagues.append({"division": String(divs[i]["id"]), "comp": comp})
	_new_season_cups(seed + 100)


# --- Mundo activo ---------------------------------------------------------------------

## TeamDB pasa a usar los clubes de la carrera.
func activate() -> void:
	if TeamDB.option_file != world:
		TeamDB.use_option_file(world)


## Vuelve al Option File del juego.
static func deactivate() -> void:
	GameSettings.apply_option_file()


func user_path() -> String:
	return TeamDB.club_path(country, user_club)


func user_team() -> TeamData:
	activate()
	return TeamDB.load_team(user_path())


## Índice de la liga (división) donde juega el club del jugador.
func user_league_index() -> int:
	for i in leagues.size():
		if (leagues[i]["comp"] as Competition).user_team >= 0:
			return i
	return 0


func user_league() -> Competition:
	return leagues[user_league_index()]["comp"]


func division_name(i: int) -> String:
	var divs: Array = TeamDB.country(country).get("divisions", [])
	return String(divs[i]["name"]) if i < divs.size() else ""


func year_label() -> String:
	return str(first_year + season - 1)


## Partido del jugador en la fecha (o {} si ya terminó su liga).
func user_match() -> Dictionary:
	if season_over:
		return {}
	return current_comp().user_match()


## La competición de la próxima fecha: la liga o una fecha de copa.
func current_comp() -> Competition:
	var ev := pending_event()
	return event_comp(ev) if ev != "" else user_league()


## Nombre de la competición de la próxima fecha.
func current_comp_name() -> String:
	match pending_event():
		"cup":
			return national_cup_name()
		"cont":
			return cont_name
	return division_name(user_league_index())


## Fecha de la carrera: la más avanzada de las divisiones que siguen.
func round_text() -> String:
	var ev := pending_event()
	if ev != "":
		return event_comp(ev).round_name()
	var comp := user_league()
	if comp.finished():
		return "Tu liga terminó · esperando a las otras divisiones"
	return comp.round_name()


# --- Fechas ------------------------------------------------------------------------------

## Juega una fecha en todas las divisiones que no terminaron. `user_result`
## (si el jugador jugó su partido): [goles local, goles visitante];
## `user_scorers`: [[lado, pid]] de GameSettings.last_scorers;
## `user_events`: tarjetas y lesiones (GameSettings.last_events).
func play_round(user_result: Array = [], user_scorers: Array = [], seed: int = 0, user_events: Array = []) -> void:
	if season_over:
		return
	activate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else randi()
	# Fecha de copa (se juega entre fechas de la liga).
	var ev := pending_event()
	if ev != "":
		_play_cup_round(ev, user_result, rng)
		return
	var mine := user_league_index()
	# Los que no podían jugar esta fecha cumplen una (después de jugarla).
	var serving: Array[Dictionary] = []
	_dirty.clear()
	var absent_before := _absence_snapshot()
	for li in leagues.size():
		var comp: Competition = leagues[li]["comp"]
		if comp.finished():
			continue
		for g in comp.rounds[comp.current]:
			for side in ["home", "away"]:
				var club: String = comp.team_paths[g[side]].get_slice(":", 3)
				for d in club_players(club):
					if int(d.get("inj", 0)) > 0 or int(d.get("susp", 0)) > 0:
						serving.append({"d": d, "club": club})
	for li in leagues.size():
		var comp: Competition = leagues[li]["comp"]
		if comp.finished():
			continue
		var r := comp.current
		var um := comp.user_match()
		comp.complete_round(user_result if li == mine and not um.is_empty() else [], rng.randi())
		for g in comp.rounds[r]:
			var is_user: bool = li == mine and (g["home"] == comp.user_team or g["away"] == comp.user_team)
			var played: bool = is_user and not user_result.is_empty()
			_add_scorers(comp, li, g, user_scorers if played else [], rng)
			_add_events(comp, g, user_events if played else [], played, rng)
			if is_user:
				_add_points(g, comp.user_team)
	for sv in serving:
		var d: Dictionary = sv["d"]
		if int(d.get("inj", 0)) > 0:
			d["inj"] = int(d["inj"]) - 1
		elif int(d.get("susp", 0)) > 0:
			d["susp"] = int(d["susp"]) - 1
		# Vuelve a estar disponible: el club se rearma.
		if int(d.get("inj", 0)) == 0 and int(d.get("susp", 0)) == 0:
			_dirty[sv["club"]] = true
	_news_absences(absent_before)
	# Los planteles con altas o bajas nuevas se rearman.
	for club in _dirty:
		TeamDB.refresh_club(country, club, world.clubs["%s:%s" % [country, club]])
	# Mitad de temporada: mercado de invierno de los otros clubes.
	var uc := user_league()
	if uc.current == uc.rounds.size() / 2:
		var lists: Array = []
		for l in leagues:
			lists.append((l["comp"] as Competition).team_paths.map(func(pth: String) -> String: return pth.get_slice(":", 3)))
		_ai_window(rng, lists, TeamDB.country(country)["divisions"])
	if leagues.all(func(l: Dictionary) -> bool: return (l["comp"] as Competition).finished()):
		_end_season()


## Simula hasta que termine la temporada (cuando la liga del jugador ya
## terminó, o si elige simular todo).
func simulate_to_end(seed: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else randi()
	var guard := 0
	while not season_over and guard < 200:
		play_round([], [], rng.randi())
		guard += 1


func _add_points(g: Dictionary, me: int) -> void:
	var res: Array = g["result"]
	if res.size() < 2:
		return
	var mine: int = res[0] if g["home"] == me else res[1]
	var theirs: int = res[1] if g["home"] == me else res[0]
	points += int(POINTS["win" if mine > theirs else ("draw" if mine == theirs else "loss")]) + mine * int(POINTS["goal"])


## Anota los goles de un partido: los del partido jugado con sus autores
## reales; el resto, repartidos entre los titulares según puesto y remate.
func _add_scorers(comp: Competition, li: int, g: Dictionary, known: Array, rng: RandomNumberGenerator) -> void:
	var res: Array = g["result"]
	if res.size() < 2:
		return
	for side in 2:
		var path: String = comp.team_paths[g["home"] if side == 0 else g["away"]]
		var t := TeamDB.load_team(path)
		var goals: int = res[side]
		var named := 0
		for k in known:
			if int(k[0]) == side and int(k[1]) > 0 and named < goals:
				var p := _player_by_pid(t, int(k[1]))
				if p != null:
					_credit(p, path, li)
					named += 1
		if not known.is_empty():
			continue # partido jugado: los que faltan son goles en contra
		for i in goals:
			var p := pick_scorer(t, rng)
			if p != null:
				_credit(p, path, li)


# --- Tarjetas, suspensiones y lesiones (D2) ---------------------------------------------

## Clubes cuyo plantel cambió en la fecha (se rearman en TeamDB).
var _dirty := {}

## Amarillas para una fecha de suspensión.
const YELLOW_LIMIT := 5
## Por equipo y partido simulado: amarillas en promedio, chance de roja y de
## lesión.
const SIM_YELLOWS := 1.9
const SIM_RED := 0.05
const SIM_INJURY := 0.07
## Quién se hace amonestar más (simulación).
const CARD_WEIGHT := {"CB": 1.5, "DMF": 1.6, "LB": 1.3, "RB": 1.3, "CMF": 1.1, "GK": 0.2}


## Jugadores (datos del mundo) de un club de la carrera.
func club_players(club_id: String) -> Array:
	var e: Dictionary = world.clubs.get("%s:%s" % [country, club_id], {})
	return e.get("players", [])


func _player_dict(club_id: String, pid: int) -> Dictionary:
	for d in club_players(club_id):
		if int(d.get("pid", 0)) == pid:
			return d
	return {}


## Tarjetas y lesiones de un partido: las reales en el partido jugado; si no,
## simuladas entre los titulares.
func _add_events(comp: Competition, g: Dictionary, known: Array, played: bool, rng: RandomNumberGenerator) -> void:
	for side in 2:
		var path: String = comp.team_paths[g["home"] if side == 0 else g["away"]]
		var club := path.get_slice(":", 3)
		if played:
			for ev in known:
				if int(ev[0]) != side:
					continue
				var d := _player_dict(club, int(ev[1]))
				if not d.is_empty():
					_apply_event(d, String(ev[2]), rng)
					_dirty[club] = true
			continue
		var xi := TeamDB.load_team(path).starters()
		if xi.is_empty():
			continue
		var weights: Array[float] = []
		for p in xi:
			weights.append(float(CARD_WEIGHT.get(p.role_code, 0.8)))
		for i in Competition._poisson(SIM_YELLOWS, rng):
			var d := _player_dict(club, _weighted(xi, weights, rng).pid)
			_apply_event(d, "y", rng)
			if int(d.get("susp", 0)) > 0:
				_dirty[club] = true
		if rng.randf() < SIM_RED:
			_apply_event(_player_dict(club, _weighted(xi, weights, rng).pid), "r", rng)
			_dirty[club] = true
		if rng.randf() < SIM_INJURY:
			_apply_event(_player_dict(club, xi[rng.randi_range(0, xi.size() - 1)].pid), "i2", rng)
			_dirty[club] = true


static func _weighted(list: Array, weights: Array[float], rng: RandomNumberGenerator) -> PlayerData:
	var total := 0.0
	for w in weights:
		total += w
	var x := rng.randf() * total
	for i in list.size():
		x -= weights[i]
		if x <= 0.0:
			return list[i]
	return list[list.size() - 1]


## Anota una tarjeta o lesión: 5 amarillas = 1 fecha; roja = 1 (a veces 2);
## golpe = a veces 1 fecha; lesión = 1 a 3 fechas casi siempre, a veces
## hasta 8 o, rara vez, hasta 20.
static func _apply_event(d: Dictionary, kind: String, rng: RandomNumberGenerator) -> void:
	if d.is_empty():
		return
	match kind:
		"y":
			d["yc"] = int(d.get("yc", 0)) + 1
			if int(d["yc"]) >= YELLOW_LIMIT:
				d["yc"] = 0
				d["susp"] = int(d.get("susp", 0)) + 1
		"r":
			d["susp"] = int(d.get("susp", 0)) + (2 if rng.randf() < 0.25 else 1)
		"i1":
			if rng.randf() < 0.4:
				d["inj"] = maxi(int(d.get("inj", 0)), 1)
		"i2":
			var x := rng.randf()
			var n := rng.randi_range(1, 3) if x < 0.75 else (rng.randi_range(4, 8) if x < 0.95 else rng.randi_range(9, 20))
			d["inj"] = maxi(int(d.get("inj", 0)), n)


## Bajas del club del jugador: [{n, why}] ("Lesión 3", "Susp. 1").
func user_absences() -> Array:
	var out: Array = []
	for d in club_players(user_club):
		if int(d.get("inj", 0)) > 0:
			out.append({"n": d["n"], "why": "lesionado, %d fecha%s" % [d["inj"], "" if int(d["inj"]) == 1 else "s"]})
		elif int(d.get("susp", 0)) > 0:
			out.append({"n": d["n"], "why": "suspendido, %d fecha%s" % [d["susp"], "" if int(d["susp"]) == 1 else "s"]})
	return out


func _credit(p: PlayerData, path: String, li: int) -> void:
	var key := str(p.pid)
	var row: Dictionary = scorers.get_or_add(key, {"n": p.player_name, "club": path.get_slice(":", 3), "div": li, "goals": 0})
	row["goals"] = int(row["goals"]) + 1
	row["club"] = path.get_slice(":", 3)
	row["div"] = li


static func _player_by_pid(t: TeamData, pid: int) -> PlayerData:
	for p in t.players:
		if p.pid == pid:
			return p
	return null


## Peso de cada puesto para meter goles (simulación).
const SCORER_WEIGHT := {"CF": 4.5, "SS": 4.0, "WG": 3.5, "AMF": 3.5, "LMF": 2.5, "RMF": 2.5, "CMF": 2.0, "DMF": 1.0,
	"LB": 0.8, "RB": 0.8, "CB": 0.7, "GK": 0.0}


## Autor de un gol simulado: entre los titulares, según puesto y remate.
static func pick_scorer(t: TeamData, rng: RandomNumberGenerator) -> PlayerData:
	var xi := t.players.slice(0, mini(11, t.players.size()))
	var total := 0.0
	var weights: Array[float] = []
	for p in xi:
		var code: String = p.role_code if p.role_code != "" else ["GK", "CB", "CMF", "CF"][p.position]
		var w := float(SCORER_WEIGHT.get(code, 1.5)) * (0.4 + float(p.shooting) / 100.0)
		weights.append(w)
		total += w
	if total <= 0.0:
		return null
	var x := rng.randf() * total
	for i in xi.size():
		x -= weights[i]
		if x <= 0.0:
			return xi[i]
	return xi[xi.size() - 1]


## Goleadores ordenados (de una división o de todas con -1).
func top_scorers(division: int = -1, n: int = 20) -> Array:
	var out: Array = []
	for k in scorers:
		var row: Dictionary = scorers[k]
		if division < 0 or int(row["div"]) == division:
			out.append(row)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["goals"]) > int(b["goals"]))
	return out.slice(0, n)


# --- Fin de temporada --------------------------------------------------------------------

## Campeones, goleadores, ascensos y descensos; deja armadas las divisiones
## de la temporada siguiente (empieza con start_next_season).
func _end_season() -> void:
	activate()
	_finish_cups()
	var divs: Array = TeamDB.country(country)["divisions"]
	var ranks: Array = [] # por división: ids en el orden de la tabla
	var summary := {"season": season, "year": year_label(), "divisions": [], "user": {}}
	for li in leagues.size():
		var comp: Competition = leagues[li]["comp"]
		var ids: Array = []
		for row in comp.standings():
			ids.append(comp.team_paths[row["team"]].get_slice(":", 3))
		ranks.append(ids)
		var top := top_scorers(li, 1)
		summary["divisions"].append({"id": leagues[li]["division"], "name": division_name(li), "champion": ids[0],
			"top_scorer": top[0] if not top.is_empty() else {}, "up": [], "down": []})
	var lists: Array = []
	for ids in ranks:
		lists.append((ids as Array).duplicate())
	for i in ranks.size() - 1:
		var k := mini(TeamDB.relegation_count(country, i), mini((ranks[i] as Array).size(), (ranks[i + 1] as Array).size()))
		if k <= 0:
			continue
		var down: Array = (ranks[i] as Array).slice((ranks[i] as Array).size() - k)
		var up: Array = (ranks[i + 1] as Array).slice(0, k)
		for id in down:
			lists[i].erase(id)
			lists[i + 1].append(id)
		for id in up:
			lists[i + 1].erase(id)
			lists[i].append(id)
		summary["divisions"][i]["down"] = down
		summary["divisions"][i + 1]["up"] = up
	var mine := user_league_index()
	var pos: int = (ranks[mine] as Array).find(user_club) + 1
	var went := "stay"
	if (summary["divisions"][mine]["up"] as Array).has(user_club):
		went = "up"
		points += int(POINTS["promotion"])
	elif (summary["divisions"][mine]["down"] as Array).has(user_club):
		went = "down"
	if pos == 1:
		points += int(POINTS["title"])
	summary["user"] = {"division": mine, "division_name": division_name(mine), "pos": pos, "went": went}
	# Copas de la temporada, clasificados a la continental y Mundial.
	summary["qualified"] = (ranks[0] as Array).slice(0, CONT_SLOTS_OWN)
	_cups_summary(summary)
	if world_cup_year():
		_play_world_cup(summary)
	# Cambio de año: edad, evolución, retiros y juveniles (con las divisiones
	# de la temporada que viene).
	var report := _new_year(lists, divs)
	summary["user"]["retired"] = report["retired"]
	summary["user"]["youth"] = report["youth"]
	summary["user"]["risers"] = report["risers"]
	var my_top: Array = top_scorers(-1, 200).filter(func(r: Dictionary) -> bool: return String(r["club"]) == user_club)
	summary["user"]["scorer"] = my_top[0] if not my_top.is_empty() else {}
	# Noticias de fin de temporada.
	for d in summary["divisions"]:
		add_news("%s %s: campeón %s." % [d["name"], year_label(), _club_name(String(d["champion"]))], "temporada")
	var verdict := "Terminaste %d.º en %s." % [pos, division_name(mine)]
	if pos == 1:
		verdict = "¡Campeones de %s %s!" % [division_name(mine), year_label()]
	if went == "up":
		verdict += " ¡Ascenso!"
	elif went == "down":
		verdict += " Descenso."
	add_news(verdict, "temporada")
	for n in report["retired"]:
		add_news("Se retiró %s." % n, "club")
	if not (report["youth"] as Array).is_empty():
		add_news("Suben de las inferiores: %s." % ", ".join(report["youth"]), "club")
	for i in divs.size():
		world.set_division(country, String(divs[i]["id"]), lists[i])
	history.append(summary)
	season_over = true
	TeamDB.use_option_file(world)


# --- Cambio de año (D2) -----------------------------------------------------------------

## Cambio de atributos por edad (antes de cumplir el año): los jóvenes
## crecen, el pico es entre los 27 y los 29 y después declinan.
static func growth_for_age(age: int) -> int:
	if age <= 20:
		return 3
	if age <= 23:
		return 2
	if age <= 26:
		return 1
	if age <= 29:
		return 0
	if age <= 31:
		return -1
	if age <= 33:
		return -2
	return -3


## Chance de retirarse al terminar la temporada (los arqueros, dos años más).
static func retire_chance(age: int, keeper: bool) -> float:
	var a := age - (2 if keeper else 0)
	if a < 33:
		return 0.0
	if a >= 39:
		return 1.0
	return [0.15, 0.3, 0.5, 0.7, 0.85, 0.95][a - 33]


## Mínimo por puesto al reponer con juveniles: [arqueros, defensores,
## volantes, delanteros] (23 en total).
const SQUAD_LINES := [3, 8, 7, 5]


## Todos cumplen un año: evolucionan, algunos se retiran y cada club repone
## con juveniles (17 a 19 años) hasta 23. Devuelve lo del club del jugador:
## {retired: [nombres], youth: [nombres], risers: [[nombre, +n]]}.
func _new_year(lists: Array, divs: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%d_%d" % [country, season, next_pid])
	var report := {"retired": [], "youth": [], "risers": []}
	var co := TeamDB.country(country)
	_return_loans()
	for di in lists.size():
		var div: Dictionary = divs[di]
		var level := int(TeamDB.DIVISION_LEVEL.get(int(div.get("level", di + 1)), 56)) + int(TeamDB.LEAGUE_BONUS.get(String(div["id"]), 0))
		for club in lists[di]:
			var mine: bool = club == user_club
			var e: Dictionary = world.clubs["%s:%s" % [country, club]]
			var kept: Array = []
			for d in e["players"]:
				var age := int(d.get("age", 25))
				var keeper := String(d.get("pos", "")) == "GK"
				if rng.randf() < retire_chance(age, keeper):
					if mine:
						report["retired"].append(d["n"])
					continue
				var before := _avg(d)
				_evolve(d, age, rng)
				d["age"] = age + 1
				d["yc"] = 0
				d["susp"] = 0
				d["inj"] = maxi(0, int(d.get("inj", 0)) - 4)
				if mine and _avg(d) - before >= 2:
					report["risers"].append([d["n"], _avg(d) - before])
				kept.append(d)
			e["players"] = kept
			for n in _add_youth(e, level - 10, String(co.get("names", "en")), co.get("skin", [40, 30, 18, 12]),
					String(co.get("nationality", "")), rng):
				if mine:
					report["youth"].append(n)
	(report["risers"] as Array).sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	report["risers"] = (report["risers"] as Array).slice(0, 5)
	# Pretemporada: los otros clubes también se refuerzan.
	_ai_window(rng, lists, divs)
	return report


static func _avg(d: Dictionary) -> int:
	var a: Dictionary = d.get("a", {})
	var total := 0
	for k in a:
		if k != "goalkeeping" or String(d.get("pos", "")) == "GK":
			total += int(a[k])
	return roundi(float(total) / maxf(a.size() - (0 if String(d.get("pos", "")) == "GK" else 1), 1.0))


## Un año más de un jugador: todos sus atributos se mueven según la edad
## (con algo de azar); los físicos caen un poco más desde los 30.
static func _evolve(d: Dictionary, age: int, rng: RandomNumberGenerator) -> void:
	var a: Dictionary = d.get("a", {})
	var base := growth_for_age(age)
	for k in a:
		var delta := base + rng.randi_range(-1, 1)
		if age >= 30 and k in ["speed", "acceleration", "stamina"]:
			delta -= 1
		a[k] = clampi(int(a[k]) + delta, 20, 99)


## Repone el plantel hasta 23 con juveniles de los puestos que faltan.
## Devuelve sus nombres.
func _add_youth(e: Dictionary, level: int, names_group: String, skin: Array, nationality: String,
		rng: RandomNumberGenerator, target: int = 23) -> Array:
	var players: Array = e["players"]
	var need := target - players.size()
	if need <= 0:
		return []
	var count := [0, 0, 0, 0]
	var numbers := {}
	for d in players:
		count[TeamDB.position_of_code(String(d.get("pos", "CMF")))] += 1
		numbers[int(d.get("num", 0))] = true
	var t := TeamData.new()
	t.id = "youth_%d" % next_pid
	t.formation = load("res://data/formations/f_4-4-2.tres")
	TeamDB.generate_roster(t, level, names_group, skin, nationality, rng.randi())
	var pool := t.players.duplicate()
	var out: Array = []
	while need > 0 and not pool.is_empty():
		# El puesto más corto respecto del mínimo (si no falta ninguno, el que haya).
		var line := 0
		var worst := -99
		for l in 4:
			var gap: int = SQUAD_LINES[l] - count[l]
			if gap > worst:
				worst = gap
				line = l
		var pick: PlayerData = null
		for p in pool:
			if p.position == line:
				pick = p
				break
		if pick == null:
			pick = pool[0]
		pool.erase(pick)
		var d := TeamDB.player_to_dict(pick)
		d["pid"] = next_pid
		next_pid += 1
		d["age"] = rng.randi_range(17, 19)
		var num := 2
		while numbers.has(num) and num < 99:
			num += 1
		d["num"] = num
		numbers[num] = true
		players.append(d)
		out.append(d["n"])
		count[pick.position] += 1
		need -= 1
	return out


# --- Plantel y Dirección del equipo (D3) ---------------------------------------------------

const FORMATIONS := ["4-4-2", "4-3-3", "4-2-3-1", "3-5-2", "5-3-2"]


func _user_entry() -> Dictionary:
	return world.clubs["%s:%s" % [country, user_club]]


func _refresh_user() -> void:
	TeamDB.refresh_club(country, user_club, _user_entry())


func formation_name() -> String:
	return String(_user_entry().get("formation", "4-4-2"))


## Cambia la formación (los titulares se vuelven a elegir solos).
func set_formation(name: String) -> void:
	var e := _user_entry()
	e["formation"] = name
	e.erase("lineup")
	_refresh_user()


## Intercambia dos jugadores del plantel (titular con titular: cambian de
## puesto; titular con suplente: entra el suplente). Queda guardado para los
## partidos que vienen.
func swap_players(pid_a: int, pid_b: int) -> void:
	activate()
	var order: Array = user_team().players.map(func(p: PlayerData) -> int: return p.pid)
	var ia := order.find(pid_a)
	var ib := order.find(pid_b)
	if ia < 0 or ib < 0 or ia == ib:
		return
	order[ia] = pid_b
	order[ib] = pid_a
	_user_entry()["lineup"] = order.slice(0, 11)
	_refresh_user()


## Vuelve a la alineación automática (los mejores de cada puesto).
func auto_lineup() -> void:
	_user_entry().erase("lineup")
	_refresh_user()


func has_custom_lineup() -> bool:
	return _user_entry().has("lineup")


## Guarda los atributos de tus jugadores al empezar la temporada.
func _snapshot_season() -> void:
	season_start = {}
	for d in club_players(user_club):
		season_start[str(d["pid"])] = (d.get("a", {}) as Dictionary).duplicate()


## Cuánto cambió un atributo desde que empezó la temporada.
func attr_delta(pid: int, attr: String, now: int) -> int:
	var a: Dictionary = season_start.get(str(pid), {})
	return now - int(a[attr]) if a.has(attr) else 0


## Goles del jugador en la temporada.
func goals_of(pid: int) -> int:
	return int((scorers.get(str(pid), {}) as Dictionary).get("goals", 0))


## Datos del mundo de un jugador de tu club (estado, amarillas...).
func user_player_dict(pid: int) -> Dictionary:
	return _player_dict(user_club, pid)


## Calendario de tu liga: [{round, home (bool), rival, result: [gf, gc] o [], current}].
func calendar() -> Array:
	var comp := user_league()
	var out: Array = []
	for r in comp.rounds.size():
		for g in comp.rounds[r]:
			var home: bool = g["home"] == comp.user_team
			if not home and g["away"] != comp.user_team:
				continue
			var res: Array = g["result"]
			var mine: Array = []
			if res.size() >= 2:
				mine = [res[0], res[1]] if home else [res[1], res[0]]
			out.append({"round": r + 1, "home": home, "rival": comp.team(g["away"] if home else g["home"]).team_name,
				"result": mine, "current": r == comp.current})
	return out


# --- Mercado de pases (D4) ---------------------------------------------------------------

## Plantel máximo del jugador y mínimo de un club que vende.
const MAX_SQUAD := 30
const MIN_SQUAD := 18
## Préstamo: una parte del valor, por lo que queda de la temporada.
const LOAN_SHARE := 0.25
## Ofertar por debajo del precio: chance de que acepten.
const LOWBALL_SHARE := 0.8
const LOWBALL_CHANCE := 0.45


## Media de un jugador en datos (igual que TeamDB.overall).
static func dict_overall(d: Dictionary) -> int:
	var a: Dictionary = d.get("a", {})
	var g := func(k: String) -> float: return float(a.get(k, 50))
	if String(d.get("pos", "")) == "GK":
		return roundi((g.call("goalkeeping") * 2 + g.call("reaction")) / 3.0)
	return roundi((g.call("speed") + g.call("passing") + g.call("shooting") + g.call("technique") + g.call("ball_control")
		+ g.call("defense") * 0.6 + g.call("stamina") * 0.4) / 6.0)


## Valor en puntos WE según la media y la edad (los jóvenes valen más).
static func player_value(d: Dictionary) -> int:
	var ovr := dict_overall(d)
	var age := int(d.get("age", 25))
	var base := pow(maxf(ovr - 40, 1), 2) * 5.0
	var k := 1.3 if age <= 23 else (1.0 if age <= 28 else (0.7 if age <= 31 else 0.4))
	return maxi(100, int(round(base * k / 50.0)) * 50)


## Ventanas de pases: las primeras 4 fechas, 4 alrededor de la mitad y al
## terminar la temporada.
func market_open() -> bool:
	if season_over:
		return true
	var comp := user_league()
	var half := comp.rounds.size() / 2
	return comp.current < 4 or absi(comp.current - half) <= 2


func market_text() -> String:
	if market_open():
		return "Mercado ABIERTO"
	var comp := user_league()
	var half := comp.rounds.size() / 2
	var next := half - 2 if comp.current < half - 2 else -1
	return "Mercado cerrado (abre en la fecha %d)" % (next + 1) if next >= 0 else "Mercado cerrado (abre al terminar la temporada)"


## Club de cada jugador del país: [{d, club, div}], con filtros. `line`:
## -1 todos, 0 arqueros... 3 delanteros; `division` -1 todas; orden "ovr",
## "age" o "value".
func market_list(line: int = -1, division: int = -1, sort: String = "ovr", limit: int = 80) -> Array:
	var out: Array = []
	for li in leagues.size():
		if division >= 0 and li != division:
			continue
		for pth in (leagues[li]["comp"] as Competition).team_paths:
			var club := String(pth).get_slice(":", 3)
			if club == user_club:
				continue
			for d in club_players(club):
				if d.has("loan_from"):
					continue
				if line >= 0 and TeamDB.position_of_code(String(d.get("pos", "CMF"))) != line:
					continue
				out.append({"d": d, "club": club, "div": li})
	match sort:
		"age":
			out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["d"].get("age", 0)) < int(y["d"].get("age", 0)))
		"value":
			out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return player_value(x["d"]) < player_value(y["d"]))
		_:
			out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return dict_overall(x["d"]) > dict_overall(y["d"]))
	return out.slice(0, limit)


## Lo que pide el club: el valor, o 50 % más si es de sus tres mejores.
func asking_price(club: String, d: Dictionary) -> int:
	var best: Array = club_players(club).map(func(x: Dictionary) -> int: return dict_overall(x))
	best.sort()
	best.reverse()
	var star := best.size() >= 3 and dict_overall(d) >= int(best[2])
	return int(player_value(d) * (1.5 if star else 1.0) / 50.0) * 50


## Por qué no se puede comprar (o "" si se puede).
func cannot_buy(club: String, cost: int) -> String:
	if not market_open():
		return "El mercado está cerrado."
	if club_players(user_club).size() >= MAX_SQUAD:
		return "Tu plantel ya tiene %d jugadores." % MAX_SQUAD
	if club_players(club).size() <= MIN_SQUAD:
		return "No lo venden: les quedaría el plantel corto."
	if cost > points:
		return "No te alcanzan los puntos (faltan %d)." % (cost - points)
	return ""


## Compra al precio pedido. Devuelve "" o el motivo.
func buy(club: String, pid: int) -> String:
	var d := _player_dict(club, pid)
	if d.is_empty():
		return "Ese jugador ya no está."
	var price := asking_price(club, d)
	var why := cannot_buy(club, price)
	if why != "":
		return why
	points -= price
	_move_player(club, user_club, d)
	_log_transfer({"season": season, "n": d["n"], "from": club, "to": user_club, "price": price, "kind": "compra"})
	return ""


## Oferta por debajo del precio (80 %): a veces aceptan. Devuelve
## "aceptada", "rechazada" o el motivo por el que no se puede.
func lowball(club: String, pid: int, rng: RandomNumberGenerator = null) -> String:
	var d := _player_dict(club, pid)
	if d.is_empty():
		return "Ese jugador ya no está."
	var price := int(asking_price(club, d) * LOWBALL_SHARE)
	var why := cannot_buy(club, price)
	if why != "":
		return why
	var r := rng.randf() if rng != null else randf()
	if r >= LOWBALL_CHANCE:
		return "rechazada"
	points -= price
	_move_player(club, user_club, d)
	_log_transfer({"season": season, "n": d["n"], "from": club, "to": user_club, "price": price, "kind": "compra"})
	return "aceptada"


func loan_price(d: Dictionary) -> int:
	return maxi(50, int(player_value(d) * LOAN_SHARE / 50.0) * 50)


## Préstamo hasta fin de temporada (vuelve a su club en el cambio de año).
func loan_in(club: String, pid: int) -> String:
	var d := _player_dict(club, pid)
	if d.is_empty():
		return "Ese jugador ya no está."
	var price := loan_price(d)
	var why := cannot_buy(club, price)
	if why != "":
		return why
	points -= price
	d["loan_from"] = club
	_move_player(club, user_club, d)
	_log_transfer({"season": season, "n": d["n"], "from": club, "to": user_club, "price": price, "kind": "préstamo"})
	return ""


## Oferta de otro club por un jugador tuyo: {club, price} (o {} si nadie
## lo quiere): un club al que le falta ese puesto paga entre 70 y 110 % del valor.
func sell_offer(pid: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var d := _player_dict(user_club, pid)
	if d.is_empty() or d.has("loan_from"):
		return {}
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var line := TeamDB.position_of_code(String(d.get("pos", "CMF")))
	var best := ""
	var best_need := -99.0
	for l in leagues:
		for pth in (l["comp"] as Competition).team_paths:
			var club := String(pth).get_slice(":", 3)
			if club == user_club or club_players(club).size() >= MAX_SQUAD:
				continue
			var have := club_players(club).filter(func(x: Dictionary) -> bool:
				return TeamDB.position_of_code(String(x.get("pos", "CMF"))) == line).size()
			var need: float = SQUAD_LINES[line] - have + r.randf() * 2.0
			if need > best_need:
				best_need = need
				best = club
	if best == "":
		return {}
	return {"club": best, "price": int(player_value(d) * r.randf_range(0.7, 1.1) / 50.0) * 50}


func sell(pid: int, club: String, price: int) -> String:
	if not market_open():
		return "El mercado está cerrado."
	var d := _player_dict(user_club, pid)
	if d.is_empty():
		return "Ese jugador ya no está."
	if club_players(user_club).size() <= 16:
		return "No podés quedarte con menos de 16 jugadores."
	points += price
	_move_player(user_club, club, d)
	_log_transfer({"season": season, "n": d["n"], "from": user_club, "to": club, "price": price, "kind": "venta"})
	return ""


## Deja libre a un jugador (se va del país; un préstamo vuelve a su club).
func release(pid: int) -> String:
	var d := _player_dict(user_club, pid)
	if d.is_empty():
		return "Ese jugador ya no está."
	if club_players(user_club).size() <= 16:
		return "No podés quedarte con menos de 16 jugadores."
	if d.has("loan_from"):
		var back := String(d["loan_from"])
		d.erase("loan_from")
		_move_player(user_club, back, d)
		_log_transfer({"season": season, "n": d["n"], "from": user_club, "to": back, "price": 0, "kind": "vuelta"})
		return ""
	club_players(user_club).erase(d)
	_refresh_user()
	_log_transfer({"season": season, "n": d["n"], "from": user_club, "to": "", "price": 0, "kind": "libre"})
	return ""


## Pasa un jugador de un club a otro (con un número libre) y rearma los dos.
func _move_player(from: String, to: String, d: Dictionary) -> void:
	club_players(from).erase(d)
	var dest: Array = club_players(to)
	var used := {}
	for x in dest:
		used[int(x.get("num", 0))] = true
	if used.has(int(d.get("num", 0))):
		var n := 2
		while used.has(n) and n < 99:
			n += 1
		d["num"] = n
	dest.append(d)
	for c in [from, to]:
		TeamDB.refresh_club(country, c, world.clubs["%s:%s" % [country, c]])


## Los préstamos vuelven a su club.
func _return_loans() -> void:
	for key in world.clubs:
		var club := String(key).get_slice(":", 1)
		for d in (world.clubs[key]["players"] as Array).duplicate():
			if d.has("loan_from"):
				var back := String(d["loan_from"])
				d.erase("loan_from")
				if world.clubs.has("%s:%s" % [country, back]):
					_move_player(club, back, d)
					_log_transfer({"season": season, "n": d["n"], "from": club, "to": back, "price": 0, "kind": "vuelta"})


## Mercado de los otros clubes: algunos compran a un jugador mejor que el
## peor titular de su puesto más flojo, de un club de su misma división o de
## una más abajo (el vendedor repone con un juvenil si queda corto).
func _ai_window(rng: RandomNumberGenerator, lists: Array, divs: Array) -> void:
	var co := TeamDB.country(country)
	var moved := {} # cada jugador cambia de club una sola vez por ventana
	var big: Array = []
	for di in lists.size():
		for club in lists[di]:
			if club == user_club or rng.randf() > 0.25:
				continue
			var mine: Array = club_players(club)
			if mine.size() >= MAX_SQUAD:
				continue
			var line := rng.randi_range(0, 3)
			var same: Array = mine.filter(func(x: Dictionary) -> bool: return TeamDB.position_of_code(String(x.get("pos", "CMF"))) == line)
			var floor_ovr := 99
			for x in same:
				floor_ovr = mini(floor_ovr, dict_overall(x))
			if same.is_empty():
				floor_ovr = 0
			var pick: Dictionary = {}
			var from := ""
			for dj in range(di, mini(di + 2, lists.size())):
				for other in lists[dj]:
					if other == club or other == user_club or club_players(other).size() <= MIN_SQUAD:
						continue
					for x in club_players(other):
						if x.has("loan_from") or moved.has(int(x["pid"])) or TeamDB.position_of_code(String(x.get("pos", "CMF"))) != line:
							continue
						if dict_overall(x) > floor_ovr + 2 and (pick.is_empty() or dict_overall(x) > dict_overall(pick)) and rng.randf() < 0.5:
							pick = x
							from = other
				if not pick.is_empty():
					break
			if pick.is_empty():
				continue
			_move_player(from, club, pick)
			moved[int(pick["pid"])] = true
			var t := {"season": season, "n": pick["n"], "from": from, "to": club, "price": player_value(pick), "kind": "ia"}
			_log_transfer(t)
			if int(t["price"]) >= BIG_TRANSFER:
				big.append(t)
			var e: Dictionary = world.clubs["%s:%s" % [country, from]]
			var div: Dictionary = divs[mini(dj_of(lists, from), divs.size() - 1)]
			var level := int(TeamDB.DIVISION_LEVEL.get(int(div.get("level", 1)), 56)) - 10
			_add_youth(e, level, String(co.get("names", "en")), co.get("skin", [40, 30, 18, 12]),
				String(co.get("nationality", "")), rng, MIN_SQUAD + 2)
	big.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["price"]) > int(b["price"]))
	for t in big.slice(0, 3):
		add_news("Bombazo: %s pasa de %s a %s." % [t["n"], _club_name(t["from"]), _club_name(t["to"])], "bombazo")


static func dj_of(lists: Array, club: String) -> int:
	for i in lists.size():
		if (lists[i] as Array).has(club):
			return i
	return 0


## Pases de esta temporada (los más nuevos primero).
func season_transfers() -> Array:
	var out := transfers.filter(func(t: Dictionary) -> bool: return int(t["season"]) == season)
	out.reverse()
	return out


# --- Copas y Mundial (Fase 7) -------------------------------------------------------------

## Nombre de la copa nacional de cada país.
const NATIONAL_CUPS := {"arg": "Copa Argentina", "eng": "FA Cup", "esp": "Copa del Rey", "ita": "Coppa Italia",
	"ger": "DFB-Pokal", "por": "Taça de Portugal", "ned": "KNVB Beker", "mex": "Copa MX", "bra": "Copa do Brasil"}
## Copa continental: con qué países se juega.
const CONTINENT := {"arg": ["bra"], "bra": ["arg"], "mex": [],
	"eng": ["esp", "ita", "ger", "por", "ned"], "esp": ["eng", "ita", "ger", "por", "ned"],
	"ita": ["eng", "esp", "ger", "por", "ned"], "ger": ["eng", "esp", "ita", "por", "ned"],
	"por": ["eng", "esp", "ita", "ger", "ned"], "ned": ["eng", "esp", "ita", "ger", "por"]}
## Copa continental: 16 equipos (4 grupos de 4, cuartos, semis y final);
## los 4 primeros de la primera división del país de la carrera.
const CONT_TEAMS := 16
const CONT_SLOTS_OWN := 4
const CUP_POINTS := {"national": 3000, "continental": 5000}
## Primer Mundial de la carrera (después, cada 4 años).
const WORLD_CUP_FIRST := 2030


func national_cup_name() -> String:
	return String(NATIONAL_CUPS.get(country, "Copa Nacional"))


func event_comp(ev: String) -> Competition:
	return national_cup if ev == "cup" else (continental if ev == "cont" else null)


## ¿Toca una fecha de copa? "cup" (nacional), "cont" (continental) o "".
func pending_event() -> String:
	if leagues.is_empty() or season_over:
		return ""
	var at := user_league().current
	if national_cup != null and not national_cup.finished() and national_cup.current < cup_after.size() \
			and at >= int(cup_after[national_cup.current]):
		return "cup"
	if continental != null and not continental.finished() and continental.current < cont_after.size() \
			and at >= int(cont_after[continental.current]):
		return "cont"
	return ""


## Rondas repartidas entre las fechas de la liga (todas antes de las dos últimas).
static func spread(rounds: int, league_rounds: int, offset: int = 0) -> Array:
	var out: Array = []
	var span := maxi(league_rounds - 2, rounds + 1)
	for r in rounds:
		out.append(clampi(int(float(r + 1) * span / (rounds + 1)) + offset, 1, maxi(1, league_rounds - 2)))
	return out


func _strength(path: String) -> float:
	var t := TeamDB.load_team(path)
	var total := 0.0
	for v in t.ratings():
		total += v
	return total


## Copa nacional (todos los de primera y el resto por sorteo, en un cuadro de
## 16, 32 o 64; tu club siempre está) y copa continental (si el país tiene).
func _new_season_cups(seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var first: Array[String] = []
	first.assign((leagues[0]["comp"] as Competition).team_paths)
	var rest: Array[String] = []
	for li in range(1, leagues.size()):
		rest.append_array((leagues[li]["comp"] as Competition).team_paths)
	Competition._shuffle(rest, rng)
	var total := first.size() + rest.size()
	var size := 64 if total >= 64 else (32 if total >= 32 else 16)
	var pool: Array[String] = []
	pool.append_array(first)
	pool.append_array(rest)
	pool = pool.slice(0, size)
	if not pool.has(user_path()):
		pool[pool.size() - 1] = user_path()
	national_cup = Competition.create_cup(pool, pool.find(user_path()), rng.randi())
	var league_rounds := user_league().rounds.size()
	cup_after = spread(int(round(log(size) / log(2))), league_rounds)
	# Continental: los 4 primeros de primera (la temporada pasada; en la
	# primera, los 4 más fuertes) y los mejores de los otros países.
	continental = null
	cont_after = []
	cont_name = ""
	var others: Array = CONTINENT.get(country, [])
	if others.is_empty():
		return
	var own: Array[String] = []
	var last := last_summary()
	if last.has("qualified"):
		for id in last["qualified"]:
			own.append(TeamDB.club_path(country, String(id)))
	else:
		var ranked := first.duplicate()
		ranked.sort_custom(func(a: String, b: String) -> bool: return _strength(a) > _strength(b))
		own.assign(ranked.slice(0, CONT_SLOTS_OWN))
	var paths: Array[String] = own.duplicate()
	var need := CONT_TEAMS - paths.size()
	for k in others.size():
		var take := need / others.size() + (1 if k < need % others.size() else 0)
		var c := TeamDB.country(String(others[k]))
		if c.is_empty():
			continue
		var ids: Array[String] = []
		for cl in c["divisions"][0]["clubs"]:
			ids.append(TeamDB.club_path(String(others[k]), String(cl["id"])))
		ids.sort_custom(func(a: String, b: String) -> bool: return _strength(a) > _strength(b))
		paths.append_array(ids.slice(0, take))
	if paths.size() != CONT_TEAMS:
		return
	cont_name = "Copa Continental de Clubes (%s)" % ("Europa" if country in ["eng", "esp", "ita", "ger", "por", "ned"] else "América")
	continental = Competition.create_world_cup(paths, paths.find(user_path()), rng.randi())
	cont_after = spread(Competition.WC_GROUP_ROUNDS + 3, league_rounds, 1)


## Juega una fecha de copa (tu partido con `user_result`, si jugás).
func _play_cup_round(ev: String, user_result: Array, rng: RandomNumberGenerator) -> void:
	var comp := event_comp(ev)
	var um := comp.user_match()
	var r := comp.current
	comp.complete_round(user_result if not um.is_empty() else [], rng.randi())
	if not um.is_empty() and r < comp.rounds.size():
		for g in comp.rounds[r]:
			if g["home"] == comp.user_team or g["away"] == comp.user_team:
				_add_points(g, comp.user_team)
				var won := Competition.winner(g) == comp.user_team
				var knockout := comp.kind == Competition.Kind.CUP or r >= Competition.WC_GROUP_ROUNDS
				if knockout and not won:
					add_news("Quedaste afuera de la %s (%s)." % [national_cup_name() if ev == "cup" else cont_name, comp.round_name(r)], "club")
	if comp.finished():
		var champ := comp.team(comp.champion).team_name
		var name := national_cup_name() if ev == "cup" else cont_name
		add_news("%s %s: campeón %s." % [name, year_label(), champ], "temporada")
		if comp.champion == comp.user_team:
			points += int(CUP_POINTS["national" if ev == "cup" else "continental"])
			add_news("¡Ganaste la %s!" % name, "temporada")


## Si quedó alguna ronda de copa sin jugar, se simula.
func _finish_cups() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_cups_%d" % [country, season])
	for comp in [national_cup, continental]:
		var guard := 0
		while comp != null and not comp.finished() and guard < 12:
			_play_cup_round("cup" if comp == national_cup else "cont", [], rng)
			guard += 1


## Hasta dónde llegó un equipo en una copa: "Campeón", "Final", "Semifinales"...
static func cup_reach(comp: Competition, team_i: int) -> String:
	if comp == null or team_i < 0:
		return ""
	if comp.champion == team_i:
		return "Campeón"
	var reach := ""
	for i in comp.rounds.size():
		for g in comp.rounds[i]:
			if g["home"] == team_i or g["away"] == team_i:
				reach = comp.round_name(i)
	if comp.kind == Competition.Kind.WORLD_CUP and reach.begins_with("Fase de grupos"):
		return "Fase de grupos"
	return reach


func _cups_summary(summary: Dictionary) -> void:
	var cups := {}
	if national_cup != null and national_cup.champion >= 0:
		cups["national"] = {"name": national_cup_name(), "champion": national_cup.team(national_cup.champion).team_name,
			"user": cup_reach(national_cup, national_cup.user_team)}
	if continental != null and continental.champion >= 0:
		cups["continental"] = {"name": cont_name, "champion": continental.team(continental.champion).team_name,
			"user": cup_reach(continental, continental.user_team)}
	summary["cups"] = cups


func world_cup_year() -> bool:
	var y := first_year + season - 1
	return y >= WORLD_CUP_FIRST and (y - WORLD_CUP_FIRST) % 4 == 0


## Mundial (simulado): la selección del país de la carrera convoca a los
## mejores 23 entre los de su plantel y los de la carrera de esa nacionalidad.
func _play_world_cup(summary: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_wc_%d" % [country, season])
	var nat := TeamDB.nation(country)
	var called_mine: Array = []
	if not nat.is_empty():
		var nat_name := SquadImporter.normalize(String(nat["name"]))
		var pool: Array = []
		for p in TeamDB.load_team(TeamDB.nation_path(country)).players:
			pool.append(TeamDB.player_to_dict(p))
		var origin := {}
		for key in world.clubs:
			for d in world.clubs[key]["players"]:
				var pn := SquadImporter.normalize(String(d.get("nat", "")))
				if pn == country or pn == nat_name or pn == "":
					var c: Dictionary = d.duplicate(true)
					pool.append(c)
					origin[c] = String(key).get_slice(":", 1)
		var squad := SquadImporter.pick_squad(pool, 23, [3, 8, 7, 5])
		for d in squad:
			if origin.get(d, "") == user_club:
				called_mine.append(d["n"])
		var entry: Dictionary = nat.duplicate(true)
		entry["players"] = squad.map(func(d: Dictionary) -> Dictionary:
			var c := d.duplicate(true)
			c.erase("pid")
			return c)
		world.set_nation(entry)
		TeamDB.use_option_file(world)
	var paths := Competition.world_cup_paths(GameSettings.wc_playoff)
	var wc := Competition.create_world_cup(paths, -1, rng.randi())
	var guard := 0
	while not wc.finished() and guard < 12:
		wc.complete_round([], rng.randi())
		guard += 1
	var champ := wc.team(wc.champion).team_name if wc.champion >= 0 else ""
	var mine := paths.find(TeamDB.nation_path(country))
	var reach := cup_reach(wc, mine) if mine >= 0 else "no clasificó"
	summary["world_cup"] = {"year": year_label(), "champion": champ, "nation": String(nat.get("name", "")),
		"reach": reach, "called": called_mine}
	add_news("Mundial %s: campeón %s." % [year_label(), champ], "temporada")
	if not nat.is_empty():
		add_news("%s en el Mundial: %s." % [nat["name"], reach], "temporada")
	if not called_mine.is_empty():
		add_news("Convocados de tu club al Mundial: %s." % ", ".join(called_mine), "club")


## Récord de goles en una temporada (de la carrera): {n, club, goals, year} o {}.
func goal_record() -> Dictionary:
	var best := {}
	for s in history:
		for d in s.get("divisions", []):
			var ts: Dictionary = d.get("top_scorer", {})
			if not ts.is_empty() and (best.is_empty() or int(ts["goals"]) > int(best["goals"])):
				best = {"n": ts["n"], "club": ts["club"], "goals": int(ts["goals"]), "year": s.get("year", "")}
	return best


# --- Noticias, historial y palmarés (D5) ---------------------------------------------------

## Agrega una noticia (kind: "lesion", "susp", "pase", "bombazo", "temporada", "club").
func add_news(text: String, kind: String = "club") -> void:
	var r := 0
	if not leagues.is_empty():
		r = user_league().current
	news.append({"season": season, "round": r, "text": text, "kind": kind})
	if news.size() > NEWS_MAX:
		news = news.slice(news.size() - NEWS_MAX)


## Las noticias, de la más nueva a la más vieja.
func latest_news(n: int = 40) -> Array:
	var out := news.slice(maxi(0, news.size() - n))
	out.reverse()
	return out


func _club_name(club: String) -> String:
	if club == "":
		return "ningún club"
	var t := TeamDB.load_team(TeamDB.club_path(country, club))
	return t.team_name if t != null else club


## Anota un pase y, si es de tu club o un bombazo, la noticia.
func _log_transfer(t: Dictionary) -> void:
	transfers.append(t)
	var mine: bool = t["from"] == user_club or t["to"] == user_club
	var n: String = t["n"]
	match String(t["kind"]):
		"compra":
			add_news("Fichaste a %s (%s) por %d puntos." % [n, _club_name(t["from"]), int(t["price"])], "pase")
		"préstamo":
			add_news("%s llega a préstamo desde %s." % [n, _club_name(t["from"])], "pase")
		"venta":
			add_news("Vendiste a %s a %s por %d puntos." % [n, _club_name(t["to"]), int(t["price"])], "pase")
		"libre":
			add_news("%s quedó libre." % n, "pase")
		"vuelta":
			if mine:
				add_news("%s volvió a %s al terminar el préstamo." % [n, _club_name(t["to"])], "pase")
		"ia":
			pass # los bombazos los anuncia _ai_window (los tres más caros)


## Lesiones y suspensiones nuevas de tu plantel (comparando con antes de la fecha).
func _news_absences(before: Dictionary) -> void:
	for d in club_players(user_club):
		var b: Array = before.get(int(d["pid"]), [0, 0])
		var inj := int(d.get("inj", 0))
		var susp := int(d.get("susp", 0))
		if inj > int(b[0]) and inj > 0:
			add_news("Lesión: %s, %d fecha%s afuera." % [d["n"], inj, "" if inj == 1 else "s"], "lesion")
		if susp > int(b[1]) and susp > 0:
			add_news("Suspendido: %s, %d fecha%s." % [d["n"], susp, "" if susp == 1 else "s"], "susp")


func _absence_snapshot() -> Dictionary:
	var out := {}
	for d in club_players(user_club):
		out[int(d["pid"])] = [int(d.get("inj", 0)), int(d.get("susp", 0))]
	return out


## Tu historial: una fila por temporada terminada
## [{season, year, division, pos, went, champion (bool), scorer}].
func club_history() -> Array:
	var out: Array = []
	for s in history:
		var u: Dictionary = s.get("user", {})
		var cups: Dictionary = s.get("cups", {})
		out.append({"season": s["season"], "year": s.get("year", ""), "division": u.get("division_name", ""),
			"pos": int(u.get("pos", 0)), "went": String(u.get("went", "stay")), "champion": int(u.get("pos", 0)) == 1,
			"scorer": u.get("scorer", {}),
			"cup": String((cups.get("national", {}) as Dictionary).get("user", "")),
			"cont": String((cups.get("continental", {}) as Dictionary).get("user", ""))})
	return out


## Palmarés de tu club: {titles: ["Primera C 2026", ...], promotions, relegations, best: "1.º en ..."}.
func club_honours() -> Dictionary:
	var titles: Array = []
	var ups := 0
	var downs := 0
	for h in club_history():
		if h["champion"]:
			titles.append("%s %s" % [h["division"], h["year"]])
		if h["cup"] == "Campeón":
			titles.append("%s %s" % [national_cup_name(), h["year"]])
		if h["cont"] == "Campeón":
			titles.append("Copa Continental %s" % h["year"])
		if h["went"] == "up":
			ups += 1
		elif h["went"] == "down":
			downs += 1
	return {"titles": titles, "promotions": ups, "relegations": downs}


## Clubes con más títulos en la carrera: [[club, títulos]] ordenado.
func most_titles(n: int = 10) -> Array:
	var count := {}
	for s in history:
		for d in s.get("divisions", []):
			var c := String(d["champion"])
			count[c] = int(count.get(c, 0)) + 1
	var out: Array = []
	for c in count:
		out.append([c, count[c]])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return out.slice(0, n)


func last_summary() -> Dictionary:
	return history[history.size() - 1] if not history.is_empty() else {}


func start_next_season(seed: int = 0) -> void:
	if not season_over:
		return
	season += 1
	season_over = false
	scorers = {}
	_new_season_leagues(seed if seed != 0 else randi())
	_snapshot_season()


# --- Guardado ------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var ls: Array = []
	for l in leagues:
		ls.append({"division": l["division"], "comp": (l["comp"] as Competition).to_dict()})
	return {"format": FORMAT, "version": VERSION, "title": title, "option_file": option_file, "created": created,
		"updated": updated, "country": country, "season": season, "first_year": first_year, "user_club": user_club,
		"squad_mode": squad_mode, "points": points, "world": world.to_dict(), "leagues": ls, "scorers": scorers,
		"history": history, "season_over": season_over, "next_pid": next_pid,
		"season_start": season_start, "transfers": transfers, "news": news,
		"national_cup": national_cup.to_dict() if national_cup != null else {}, "cup_after": cup_after,
		"continental": continental.to_dict() if continental != null else {}, "cont_after": cont_after,
		"cont_name": cont_name}


static func from_dict(d: Dictionary) -> MasterCareer:
	var m := MasterCareer.new()
	m.title = String(d.get("title", ""))
	m.option_file = String(d.get("option_file", ""))
	m.created = String(d.get("created", ""))
	m.updated = String(d.get("updated", ""))
	m.country = String(d.get("country", ""))
	m.season = int(d.get("season", 1))
	m.first_year = int(d.get("first_year", 2026))
	m.user_club = String(d.get("user_club", ""))
	m.squad_mode = String(d.get("squad_mode", "real"))
	m.points = int(d.get("points", START_POINTS))
	m.world = OptionFile.from_dict(d.get("world", {}))
	m.world.name = m.option_file
	for l in d.get("leagues", []):
		m.leagues.append({"division": String(l["division"]), "comp": Competition.from_dict(l["comp"])})
	m.scorers = d.get("scorers", {})
	m.history = d.get("history", [])
	m.season_over = bool(d.get("season_over", false))
	m.next_pid = int(d.get("next_pid", 1))
	m.season_start = d.get("season_start", {})
	m.transfers = d.get("transfers", [])
	m.news = d.get("news", [])
	if not (d.get("national_cup", {}) as Dictionary).is_empty():
		m.national_cup = Competition.from_dict(d["national_cup"])
	m.cup_after = d.get("cup_after", []).map(func(x: Variant) -> int: return int(x))
	if not (d.get("continental", {}) as Dictionary).is_empty():
		m.continental = Competition.from_dict(d["continental"])
	m.cont_after = d.get("cont_after", []).map(func(x: Variant) -> int: return int(x))
	m.cont_name = String(d.get("cont_name", ""))
	return m


static func is_career_file(path: String) -> bool:
	return path.begins_with(UserData.saves_dir("master"))


func save() -> void:
	if file == "":
		file = UserData.saves_dir("master").path_join("master_%s.json" %
			Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "").replace("T", "_"))
		while FileAccess.file_exists(file):
			file = file.get_basename() + "b.json"
	var now := Time.get_datetime_string_from_system(false, true)
	if created == "":
		created = now
	updated = now
	if title == "":
		title = "Liga Master · %s" % user_team().team_name
	UserData.write_text(file, JSON.stringify(to_dict()))


static func load_saved(path: String) -> MasterCareer:
	var d: Variant = UserData.read_json(path)
	if not d is Dictionary or d.get("format", "") != FORMAT:
		return null
	var m := from_dict(d)
	m.file = path
	return m


func delete_file() -> void:
	if file != "" and FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)


## "Temporada 2026 · Primera C · Fecha 7 de 46".
func progress_text() -> String:
	if season_over:
		return "Temporada %s terminada" % year_label()
	return "Temporada %s · %s · %s" % [year_label(), division_name(user_league_index()), user_league().round_name()]


static func has_saves() -> bool:
	return not UserData.files_in(UserData.saves_dir("master"), "json").is_empty()


## Carreras guardadas: [{file, title, progress, updated, option_file}].
static func list_saves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in UserData.files_in(UserData.saves_dir("master"), "json"):
		var d: Variant = UserData.read_json(f)
		if not d is Dictionary or d.get("format", "") != FORMAT:
			continue
		var m := from_dict(d)
		m.file = f
		# El texto de progreso necesita los nombres de las divisiones del mundo.
		var prev := TeamDB.option_file
		m.activate()
		out.append({"file": f, "title": m.title, "progress": m.progress_text(), "updated": m.updated,
			"option_file": m.option_file, "master": true})
		TeamDB.use_option_file(prev)
	return out
