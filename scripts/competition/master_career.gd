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
## Copas de la temporada (Fase 7, ver CareerCups): [{id, name, type,
## comp, after}], con la fecha de la liga después de la que se juega cada
## ronda de la copa.
var cups: Array = []
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
	# Libres: los del Option File (importados sin club), con un pid cada uno.
	var free: Array = []
	if TeamDB.option_file != null:
		for p in TeamDB.option_file.free_agents:
			var d: Dictionary = (p as Dictionary).duplicate(true)
			d["pid"] = m.next_pid
			m.next_pid += 1
			free.append(d)
	m.world.clubs["%s:%s" % [country_id, FREE_CLUB]] = {"id": FREE_CLUB, "name": "Jugadores libres", "players": free}
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
	return event_comp(ev) if ev >= 0 else user_league()


## Nombre de la competición de la próxima fecha.
func current_comp_name() -> String:
	var ev := pending_event()
	if ev >= 0:
		return String(cups[ev]["name"])
	return division_name(user_league_index())


## Fecha de la carrera: la más avanzada de las divisiones que siguen.
func round_text() -> String:
	var ev := pending_event()
	if ev >= 0:
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
	if ev >= 0:
		_play_cup_round(ev, user_result, rng)
		_auto_cups(rng)
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
	_auto_cups(rng)
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
	# Tablas finales (para las copas de la temporada que viene), Apertura y
	# Clausura, copas y Mundial.
	summary["ranks"] = ranks
	if CareerCups.HALVES.has(country):
		var top: Competition = leagues[0]["comp"]
		var half := top.rounds.size() / 2
		summary["halves"] = [top.team_paths[top.standings(0, half)[0]["team"]],
			top.team_paths[top.standings(half, top.rounds.size())[0]["team"]]]
	_cups_summary(summary)
	if world_cup_year():
		_play_world_cup(summary)
	_awards(summary)
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


## Premios de la temporada (SeasonAwards): noticias y puntos si son de tu club.
func _awards(summary: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_awards_%d" % [country, season])
	var list := SeasonAwards.compute(self, summary, rng)
	summary["awards"] = list
	for a in list:
		var who := "%s (%s)" % [a["n"], a["club"]]
		if String(a["detail"]) != "":
			who += ", " + String(a["detail"])
		add_news("%s %s: %s." % [a["award"], year_label(), who], "temporada")
		if String(a.get("club_id", "")) == user_club:
			points += AWARD_POINTS
			add_news("¡%s, de tu club, ganó el %s!" % [a["n"], a["award"]], "club")


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
			# Inferiores: crecen un año; los que pasan los 20 suben a primera
			# (si hay lugar) o quedan libres.
			var still: Array = []
			for d in e.get("youth", []):
				var yage := int(d.get("age", 18))
				_evolve(d, yage, rng)
				d["age"] = yage + 1
				if yage + 1 <= TeamDB.U20_MAX_AGE:
					still.append(d)
				elif (e["players"] as Array).size() < MAX_SQUAD:
					_promote(e, d)
					if mine:
						report["youth"].append(d["n"])
				else:
					d["pid"] = int(d.get("pid", 0)) if d.has("pid") else _new_pid()
					free_agents().append(d)
			if e.has("youth"):
				e["youth"] = still
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
	# Primero suben los de las inferiores del club (los mejores del puesto
	# que más falta).
	var promoted: Array = []
	var youth: Array = e.get("youth", [])
	while need > 0 and not youth.is_empty():
		var have := [0, 0, 0, 0]
		for d in players:
			have[TeamDB.position_of_code(String(d.get("pos", "CMF")))] += 1
		var want := 0
		var gap := -99
		for l in 4:
			if SQUAD_LINES[l] - have[l] > gap:
				gap = SQUAD_LINES[l] - have[l]
				want = l
		var best: Dictionary = {}
		for d in youth:
			var fits := TeamDB.position_of_code(String(d.get("pos", "CMF"))) == want
			var best_fits := not best.is_empty() and TeamDB.position_of_code(String(best.get("pos", "CMF"))) == want
			if best.is_empty() or (fits and not best_fits) or (fits == best_fits and _avg(d) > _avg(best)):
				best = d
		youth.erase(best)
		_promote(e, best)
		promoted.append(best["n"])
		need -= 1
	if need <= 0:
		return promoted
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
	return promoted + out


## Sube un juvenil de las inferiores al plantel (con pid y un número libre).
func _promote(e: Dictionary, d: Dictionary) -> void:
	if not d.has("pid"):
		d["pid"] = _new_pid()
	var used := {}
	for x in e["players"]:
		used[int(x.get("num", 0))] = true
	if used.has(int(d.get("num", 0))) or int(d.get("num", 0)) <= 0:
		var num := 2
		while used.has(num) and num < 99:
			num += 1
		d["num"] = num
	(e["players"] as Array).append(d)


func _new_pid() -> int:
	next_pid += 1
	return next_pid - 1


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
const MAX_SQUAD := TeamDB.CLUB_SQUAD_MAX
## "Club" de los jugadores libres (los importados y los que se liberan).
const FREE_CLUB := "_libres"
## Prima por fichar a un libre: una parte de su valor.
const FREE_SIGNING_SHARE := 0.1
## Puntos WE por cada premio individual de un jugador de tu club.
const AWARD_POINTS := 1500
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
	if division < 0:
		for d in club_players(FREE_CLUB):
			if line < 0 or TeamDB.position_of_code(String(d.get("pos", "CMF"))) == line:
				out.append({"d": d, "club": FREE_CLUB, "div": -1})
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
	if club == FREE_CLUB:
		return int(player_value(d) * FREE_SIGNING_SHARE / 50.0) * 50
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
	if club != FREE_CLUB and club_players(club).size() <= MIN_SQUAD:
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
	free_agents().append(d)
	_refresh_user()
	_log_transfer({"season": season, "n": d["n"], "from": user_club, "to": "", "price": 0, "kind": "libre"})
	return ""


## Lista de libres de la carrera (se crea si una partida vieja no la tenía).
func free_agents() -> Array:
	var key := "%s:%s" % [country, FREE_CLUB]
	if not world.clubs.has(key):
		world.clubs[key] = {"id": FREE_CLUB, "name": "Jugadores libres", "players": []}
	return world.clubs[key]["players"]


## Pasa un jugador de un club a otro (con un número libre) y rearma los dos.
func _move_player(from: String, to: String, d: Dictionary) -> void:
	if from == FREE_CLUB:
		free_agents()
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
		if c != FREE_CLUB:
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

## Primer Mundial de la carrera (después, cada 4 años).
const WORLD_CUP_FIRST := 2030


func national_cup_name() -> String:
	return String((CareerCups.NATIONAL.get(country, {}) as Dictionary).get("name", "Copa Nacional"))


## Copa de la temporada por id ("national", "ucl"...) o {}.
func cup(id: String) -> Dictionary:
	for e in cups:
		if e["id"] == id:
			return e
	return {}


func event_comp(i: int) -> Competition:
	return cups[i]["comp"] if i >= 0 and i < cups.size() else null


## ¿Le toca a esa copa jugar su próxima fecha?
func _due(e: Dictionary) -> bool:
	var comp: Competition = e["comp"]
	var after: Array = e["after"]
	if comp == null or comp.finished() or after.is_empty() or leagues.is_empty():
		return false
	return user_league().current >= int(after[mini(comp.current, after.size() - 1)])


## Copa con un partido tuyo en la próxima fecha (índice en `cups`) o -1.
func pending_event() -> int:
	if leagues.is_empty() or season_over:
		return -1
	for i in cups.size():
		if _due(cups[i]) and not (cups[i]["comp"] as Competition).user_match().is_empty():
			return i
	return -1


## Juega las fechas de copa que ya tocan y en las que no jugás (hasta la
## primera tuya, que va antes que las que siguen).
func _auto_cups(rng: RandomNumberGenerator) -> void:
	var guard := 0
	while guard < 500:
		guard += 1
		var played := false
		for i in cups.size():
			if not _due(cups[i]):
				continue
			if not (cups[i]["comp"] as Competition).user_match().is_empty():
				return
			_play_cup_round(i, [], rng)
			played = true
			break
		if not played:
			return


## Rondas repartidas entre las fechas de la liga (todas antes de las dos últimas).
static func spread(rounds: int, league_rounds: int, offset: int = 0) -> Array:
	var out: Array = []
	var span := maxi(league_rounds - 2, rounds + 1)
	for r in rounds:
		out.append(clampi(int(float(r + 1) * span / (rounds + 1)) + offset, 1, maxi(1, league_rounds - 2)))
	return out


func _add_cup(id: String, name: String, type: String, comp: Competition, after: Array) -> void:
	if comp != null:
		cups.append({"id": id, "name": name, "type": type, "comp": comp, "after": after})


## Clubes de cada división en el orden de la temporada pasada (los que
## venían de más arriba primero); en la primera, por nivel.
func _cup_tiers(cache: Dictionary) -> Array:
	var last := last_summary()
	var rank := {}
	if last.has("ranks"):
		var ranks: Array = last["ranks"]
		for di in ranks.size():
			for pi in (ranks[di] as Array).size():
				rank[TeamDB.club_path(country, String(ranks[di][pi]))] = di * 1000 + pi
	var out: Array = []
	for l in leagues:
		var list: Array[String] = []
		list.assign((l["comp"] as Competition).team_paths)
		list.sort_custom(func(x: String, y: String) -> bool:
			if rank.has(x) and rank.has(y):
				return rank[x] < rank[y]
			if rank.has(x) != rank.has(y):
				return rank.has(x)
			return CareerCups.strength(x, cache) > CareerCups.strength(y, cache))
		out.append(list)
	return out


## Tabla de primera de la temporada pasada (rutas); en la primera, por nivel.
func _last_top_table(cache: Dictionary) -> Array[String]:
	var last := last_summary()
	var out: Array[String] = []
	if last.has("ranks"):
		for id in last["ranks"][0]:
			out.append(TeamDB.club_path(country, String(id)))
		return out
	return _cup_tiers(cache)[0]


## Campeón y finalista de una copa de la temporada pasada (rutas).
func _last_cup(id: String) -> Array:
	var c: Dictionary = (last_summary().get("cups", {}) as Dictionary).get(id, {})
	return [String(c.get("champion_path", "")), String(c.get("finalist_path", ""))]


## Primero de `table` que no esté en `used`.
static func _next_free(table: Array, used: Array) -> String:
	for p in table:
		if not used.has(p):
			return p
	return ""


## Supercopa nacional con los resultados de la temporada pasada.
func _national_super(sp: Dictionary, seed: int, cache: Dictionary) -> Competition:
	var last := last_summary()
	if last.is_empty():
		return null
	var table := _last_top_table(cache)
	var cupw := _last_cup("national")
	var paths: Array[String] = []
	match String(sp["kind"]):
		"halves":
			var hv: Array = last.get("halves", [])
			if hv.size() < 2:
				return null
			paths.append(String(hv[0]))
			paths.append(String(hv[1]) if hv[1] != hv[0] else _next_free(table, [hv[0]]))
		"four":
			var order: Array = [table[0] if table.size() > 0 else "", cupw[1], cupw[0], table[1] if table.size() > 1 else ""]
			for k in order.size():
				var p := String(order[k])
				if p == "" or paths.has(p):
					var used: Array = []
					used.append_array(paths)
					used.append_array(order.slice(k + 1))
					p = _next_free(table, used)
				paths.append(p)
		_:
			paths.append(table[0] if not table.is_empty() else "")
			paths.append(cupw[0] if cupw[0] != "" and cupw[0] != paths[0] else _next_free(table, paths))
	if paths.has(""):
		return null
	return CareerCups.fixed_cup(paths, user_path(), seed)


## Copas de la temporada: supercopas, copa nacional, copa de la liga, las de
## la confederación, Intercontinental y (cada 4 años) Mundial de Clubes.
func _new_season_cups(seed: int) -> void:
	cups = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cache := {}
	var last := last_summary()
	var lr := user_league().rounds.size()
	var me := user_path()
	var confed := CareerCups.confed_of(country)
	# Mundial de Clubes (antes de empezar la temporada).
	var y := first_year + season - 1
	if y >= CareerCups.CLUB_WORLD_CUP_FIRST and (y - CareerCups.CLUB_WORLD_CUP_FIRST) % 4 == 0:
		var cwc := _club_world_cup(rng, cache)
		if cwc != null:
			var n := CareerCups.total_rounds(cwc)
			var after: Array = []
			after.resize(n)
			after.fill(0)
			_add_cup("cwc", "Mundial de Clubes FIFA %d" % y, "world", cwc, after)
	# Supercopas nacionales.
	for sp in CareerCups.SUPERS.get(country, []):
		var c := _national_super(sp, rng.randi(), cache)
		var mid := maxi(1, lr / 2)
		_add_cup(String(sp["id"]), String(sp["name"]), "super", c, [0] if c != null and c.rounds[0].size() == 1 else [mid, mid])
	# Supercopa continental e Intercontinental (campeones de la temporada pasada).
	if CareerCups.CONT_SUPER.has(confed):
		var cs: Dictionary = CareerCups.CONT_SUPER[confed]
		var a := String(_last_cup(String(cs["from"][0]))[0])
		var b := String(_last_cup(String(cs["from"][1]))[0])
		if a != "" and b != "" and a != b:
			var two: Array[String] = [a, b]
			var c := CareerCups.fixed_cup(two, me, rng.randi(), int(cs["legs"]))
			_add_cup(String(cs["id"]), String(cs["name"]), "super", c, [1, 2] if int(cs["legs"]) == 2 else [0])
	var champs: Array[String] = []
	for id in ["lib", "cca", "ucl"]:
		var p := String(_last_cup(id)[0])
		if p != "":
			champs.append(p)
	if champs.size() == 3:
		var c := Competition.create_staged_cup(champs, champs.find(me), [0, 0, 1], rng.randi(), 1, ["Derbi de las Américas", ""])
		_add_cup("intercontinental", "Copa Intercontinental FIFA", "world", c, [0, 0])
	# Copa nacional y copa de la liga.
	var tiers := _cup_tiers(cache)
	for kind in ["national", "league_cup"]:
		var spec: Dictionary = (CareerCups.NATIONAL if kind == "national" else CareerCups.LEAGUE_CUPS).get(country, {})
		if spec.is_empty():
			continue
		var ordered: Array[String] = []
		var quota: Array = spec.get("quota", [])
		for i in tiers.size():
			var q := int(quota[i]) if i < quota.size() else -1
			var list: Array = tiers[i]
			ordered.append_array(list if q < 0 else list.slice(0, q))
		var c := CareerCups.staged_cup(ordered, spec, me, rng.randi())
		if c != null:
			_add_cup(kind, String(spec["name"]), kind, c, spread(CareerCups.total_rounds(c), lr, 0 if kind == "national" else 1))
	# Copas de la confederación.
	if CareerCups.CONTINENTAL.has(confed):
		var q := _qualify(confed, rng, cache, true)
		var built: Array = []
		var most := 0
		for spec in CareerCups.CONTINENTAL[confed]:
			var paths: Array[String] = []
			paths.assign(q.get(spec["id"], []))
			var c := CareerCups.continental_comp(spec, paths, me, rng.randi())
			if c != null:
				built.append([spec, c])
				most = maxi(most, CareerCups.total_rounds(c))
		var after := spread(most, lr, 1)
		for item in built:
			var c: Competition = item[1]
			_add_cup(String(item[0]["id"]), String(item[0]["name"]), "continental", c, after.slice(0, CareerCups.total_rounds(c)))
	# Torneos Sub-20 (se simulan; las noticias cuentan cómo le fue a tu Sub-20).
	for yid in CareerCups.youth_ids(country, y):
		var teams := CareerCups.youth_teams(yid, cache)
		if yid == "proyeccion" and not leagues.is_empty():
			teams = CareerCups._u20((leagues[0]["comp"] as Competition).team_paths)
		var c := CareerCups.youth_comp(yid, teams, -1, rng.randi())
		if c != null:
			_add_cup(yid, String(CareerCups.YOUTH[yid]["name"]), "youth", c, spread(CareerCups.total_rounds(c), lr, 1))
			cups[cups.size() - 1]["mine"] = teams.find(TeamDB.u20_path(me))
	_auto_cups(rng)


## Clasificados a las copas de una confederación (con la tabla de la carrera
## si es la del país; las de otros países, por nivel con algo de azar).
func _qualify(confed: String, rng: RandomNumberGenerator, cache: Dictionary, own: bool) -> Dictionary:
	var tables := {}
	var winners := {}
	for cid in CareerCups.confed_countries(confed):
		if cid == country and own:
			tables[cid] = _last_top_table(cache)
			winners[cid] = {"national": _last_cup("national")[0], "league_cup": _last_cup("league_cup")[0]}
		else:
			tables[cid] = CareerCups.guessed_table(cid, 0, rng, cache)
	var holders := {}
	for id in CareerCups.HOLDERS:
		var p := String(_last_cup(id)[0])
		if p != "":
			holders[id] = p
	return CareerCups.qualify(confed, tables, winners, holders, cache)


## Mundial de Clubes: los campeones continentales de las últimas 4
## temporadas y los mejores de cada confederación hasta llenar los cupos.
func _club_world_cup(rng: RandomNumberGenerator, cache: Dictionary) -> Competition:
	var paths: Array[String] = []
	for confed in CareerCups.CWC_QUOTA:
		var quota := int(CareerCups.CWC_QUOTA[confed])
		var mine: Array[String] = []
		var top := String(CareerCups.CONTINENTAL[confed][0]["id"])
		for s in history.slice(maxi(0, history.size() - 4)):
			var p := String(((s.get("cups", {}) as Dictionary).get(top, {}) as Dictionary).get("champion_path", ""))
			if p != "" and not mine.has(p) and mine.size() < quota:
				mine.append(p)
		var pool: Array[String] = []
		for cid in CareerCups.confed_countries(confed):
			pool.append_array(CareerCups.division_clubs(cid, 0))
		pool.sort_custom(func(a: String, b: String) -> bool: return CareerCups.strength(a, cache) > CareerCups.strength(b, cache))
		for p in pool:
			if mine.size() >= quota:
				break
			if not mine.has(p):
				mine.append(p)
		paths.append_array(mine)
	if paths.size() != 32:
		return null
	return Competition.create_groups(paths, paths.find(user_path()), rng.randi())


## Después de cada fecha de copa: los 3.º de la Libertadores pasan a la
## Sudamericana y, con el Trofeo de Campeones jugado, se arma la Supercopa
## Argentina.
func _resolve_links() -> void:
	var lib := cup("lib")
	var sud := cup("sud")
	if not lib.is_empty() and not sud.is_empty():
		var lc: Competition = lib["comp"]
		var sc: Competition = sud["comp"]
		if lc.current >= lc.group_rounds and sc.extra.is_empty() and sc.current < sc.group_rounds:
			var thirds: Array[String] = []
			for gi in lc.groups.size():
				thirds.append(lc.team_paths[lc.group_table(gi)[2]["team"]])
			sc.add_teams(thirds, user_path())
	var trofeo := cup("trofeo")
	if country == "arg" and not trofeo.is_empty() and (trofeo["comp"] as Competition).finished() and cup("supercopa_arg").is_empty():
		var tc: Competition = trofeo["comp"]
		var a := tc.team_paths[tc.champion]
		var cw := _last_cup("national")
		var b := String(cw[0]) if cw[0] != a else String(cw[1])
		if b != "" and b != a:
			var two: Array[String] = [a, b]
			var lr := user_league().rounds.size()
			_add_cup("supercopa_arg", "Supercopa Argentina", "super",
				CareerCups.fixed_cup(two, user_path(), hash("%s_sca_%d" % [country, season])), [maxi(1, lr / 3)])


## Juega una fecha de una copa (tu partido con `user_result`, si jugás).
func _play_cup_round(i: int, user_result: Array, rng: RandomNumberGenerator) -> void:
	var e: Dictionary = cups[i]
	var comp: Competition = e["comp"]
	var me := comp.user_team
	var was_alive := me >= 0 and comp.alive(me)
	var um := comp.user_match()
	var r := comp.current
	comp.complete_round(user_result if not um.is_empty() else [], rng.randi())
	if not um.is_empty() and r < comp.rounds.size():
		for g in comp.rounds[r]:
			if g["home"] == me or g["away"] == me:
				_add_points(g, me)
	var name := String(e["name"])
	var mine := int(e.get("mine", -1))
	if mine >= 0 and comp.kind != Competition.Kind.LEAGUE:
		if r < comp.rounds.size() and comp.alive(mine) == false and _was_alive_u20(comp, mine, r):
			add_news("Tu Sub-20 quedó afuera de la %s (%s)." % [name, cup_reach(comp, mine)], "club")
		if comp.finished() and comp.champion == mine:
			add_news("¡Tu Sub-20 ganó la %s!" % name, "temporada")
	elif mine >= 0 and comp.finished():
		var pos := comp.standings().map(func(row: Dictionary) -> int: return row["team"]).find(mine) + 1
		add_news("%s: tu Sub-20 terminó %d.º." % [name, pos], "club")
	if was_alive and not comp.alive(me):
		add_news("Quedaste afuera de la %s (%s)." % [name, cup_reach(comp, me)], "club")
	if comp.finished() and comp.champion >= 0:
		add_news("%s %s: campeón %s." % [name, year_label(), comp.team(comp.champion).team_name], "temporada")
		if comp.champion == me:
			points += int(CareerCups.POINTS.get(e["id"], CareerCups.POINTS.get(e["type"], 2000)))
			add_news("¡Ganaste la %s!" % name, "temporada")
	_resolve_links()


## ¿El equipo jugó la ronda `r` (seguía en carrera antes de esa ronda)?
static func _was_alive_u20(comp: Competition, team_i: int, r: int) -> bool:
	for g in comp.rounds[r]:
		if g["home"] == team_i or g["away"] == team_i:
			return true
	return false


## Si quedó alguna fecha de copa sin jugar, se simula.
func _finish_cups() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_cups_%d" % [country, season])
	var guard := 0
	var left := true
	while left and guard < 500:
		left = false
		for i in cups.size():
			var comp: Competition = cups[i]["comp"]
			if comp != null and not comp.finished():
				_play_cup_round(i, [], rng)
				left = true
				guard += 1
				break


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
	if comp.in_first_phase(0) and reach.begins_with("Fase "):
		return "Fase liga" if comp.ko == "swiss" else "Fase de grupos"
	return reach.trim_suffix(" · ida").trim_suffix(" · vuelta")


## Finalista (el que perdió la final) o -1.
static func _finalist(comp: Competition) -> int:
	if comp.champion < 0 or comp.rounds.is_empty():
		return -1
	var last: Array = comp.rounds[comp.rounds.size() - 1]
	if last.size() != 1:
		return -1
	var g: Dictionary = last[0]
	return g["away"] if g["home"] == comp.champion else g["home"]


func _cup_record(e: Dictionary, foreign: bool = false) -> Dictionary:
	var comp: Competition = e["comp"]
	var fin := _finalist(comp)
	return {"name": e["name"], "type": e["type"], "champion": comp.team(comp.champion).team_name,
		"champion_path": comp.team_paths[comp.champion], "finalist_path": comp.team_paths[fin] if fin >= 0 else "",
		"user": "" if foreign else cup_reach(comp, comp.user_team), "foreign": foreign}


func _cups_summary(summary: Dictionary) -> void:
	var out := {}
	for e in cups:
		var comp: Competition = e["comp"]
		if comp != null and comp.champion >= 0:
			out[e["id"]] = _cup_record(e)
	summary["cups"] = out
	_foreign_cups(summary)


## Las copas principales de las otras confederaciones (simuladas), para la
## Intercontinental y el Mundial de Clubes.
func _foreign_cups(summary: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_foreign_%d" % [country, season])
	var cache := {}
	var mine := CareerCups.confed_of(country)
	for confed in CareerCups.CONTINENTAL:
		if confed == mine or CareerCups.confed_countries(confed).is_empty():
			continue
		var spec: Dictionary = CareerCups.CONTINENTAL[confed][0]
		var paths: Array[String] = []
		paths.assign(_qualify(confed, rng, cache, false).get(spec["id"], []))
		var c := CareerCups.continental_comp(spec, paths, "", rng.randi())
		if c == null:
			continue
		var guard := 0
		while not c.finished() and guard < 60:
			c.complete_round([], rng.randi())
			guard += 1
		if c.champion >= 0:
			summary["cups"][spec["id"]] = _cup_record({"name": spec["name"], "type": "continental", "comp": c}, true)


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
		var cs: Dictionary = s.get("cups", {})
		out.append({"season": s["season"], "year": s.get("year", ""), "division": u.get("division_name", ""),
			"pos": int(u.get("pos", 0)), "went": String(u.get("went", "stay")), "champion": int(u.get("pos", 0)) == 1,
			"scorer": u.get("scorer", {}),
			"cup": String((cs.get("national", {}) as Dictionary).get("user", "")),
			"cups": _user_cups(cs)})
	return out


## Copas que jugó tu club en una temporada: [[nombre, hasta dónde llegó]].
static func _user_cups(cs: Dictionary) -> Array:
	var out: Array = []
	for id in cs:
		var c: Dictionary = cs[id]
		if String(c.get("user", "")) != "":
			out.append([String(c["name"]), String(c["user"])])
	return out


## Palmarés de tu club: {titles: ["Primera C 2026", ...], promotions, relegations}.
func club_honours() -> Dictionary:
	var titles: Array = []
	var ups := 0
	var downs := 0
	for h in club_history():
		if h["champion"]:
			titles.append("%s %s" % [h["division"], h["year"]])
		for c in h["cups"]:
			if c[1] == "Campeón":
				titles.append("%s %s" % [c[0], h["year"]])
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
		"cups": cups.map(func(e: Dictionary) -> Dictionary:
			return {"id": e["id"], "name": e["name"], "type": e["type"], "after": e["after"],
				"mine": int(e.get("mine", -1)), "comp": (e["comp"] as Competition).to_dict()})}


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
	var ints := func(a: Array) -> Array: return a.map(func(x: Variant) -> int: return int(x))
	for e in d.get("cups", []):
		m.cups.append({"id": String(e["id"]), "name": String(e["name"]), "type": String(e.get("type", "")),
			"after": ints.call(e.get("after", [])), "mine": int(e.get("mine", -1)), "comp": Competition.from_dict(e["comp"])})
	# Partidas de antes: la copa nacional y la continental sueltas.
	if not d.has("cups"):
		if not (d.get("national_cup", {}) as Dictionary).is_empty():
			m.cups.append({"id": "national", "name": m.national_cup_name(), "type": "national",
				"after": ints.call(d.get("cup_after", [])), "comp": Competition.from_dict(d["national_cup"])})
		if not (d.get("continental", {}) as Dictionary).is_empty():
			m.cups.append({"id": "continental", "name": String(d.get("cont_name", "Copa Continental")), "type": "continental",
				"after": ints.call(d.get("cont_after", [])), "comp": Competition.from_dict(d["continental"])})
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
