extends Node
## Arma la base "Temporada 2026" (data/db2026) con los CSV de
## tools/db_src/2026/ (ligas/*.csv y selecciones/*.csv, formato EA FC):
##   godot --headless -- --build-db
##
##   - Clubes, ligas y países: los de los CSV de ligas. Si el club ya está en
##     la base Ficticia, conserva su id, camisetas y estadio; si no, se crea.
##   - Jugadores: uno por fila de liga, con un id único (pid) que no cambia
##     entre corridas (tools/db_src/2026/ids.json guarda nombre + nacionalidad +
##     año de nacimiento + estatura -> pid).
##   - Selecciones: cada convocado de los CSV de selecciones se busca en su
##     club (mismo nombre, o mismo apellido, estatura y edad parecidas). Si
##     está, la selección guarda su pid: es el mismo jugador. Si su club no
##     está en las ligas, queda como jugador "del exterior" (players_ext.json).
##   - Competencias (competitions.json): las ligas y los torneos de selecciones.
##   - Informe en tools/db_src/2026/informe.txt (lo que se cruzó a mano, lo
##     que no se encontró).

const SRC := "res://tools/db_src/2026/"
const OUT := "res://data/db2026/"
const DB_ID := "t2026"
const SEASON := "2026"
const YEAR := 2026
## Prefijo del archivo de liga -> país de la base ("ITA_1_serie_a.csv": Italia,
## primera). Así "Serie A" no se confunde con la de Ecuador.
const FILE_COUNTRY := {"ALE": "ger", "ARG": "arg", "BOL": "bol", "BRA": "bra", "CHI": "chi", "COL": "col",
	"ECU": "ecu", "ENG": "eng", "ESP": "esp", "FRA": "fra", "HOL": "ned", "ITA": "ita", "MEX": "mex", "MSL": "usa",
	"PAR": "par", "PER": "per", "POR": "por", "URU": "uru", "VEN": "ven"}

var report: Array[String] = []
## Registro de ids: clave del jugador -> pid.
var ids := {}
var next_pid := 1
var _used_keys := {}


func _ready() -> void:
	var menu := get_tree().current_scene
	if menu != null:
		menu.queue_free()
	_run.call_deferred()


func _run() -> void:
	var res := build(ProjectSettings.globalize_path(SRC), ProjectSettings.globalize_path(OUT))
	for line in report:
		print(line)
	get_tree().quit(0 if res else 1)


static func _rows(dir: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var files := UserData.files_in(dir, "csv")
	files.sort()
	for f in files:
		for r in SquadImporter.read_csv(f):
			r["_file"] = f.get_file()
			rows.append(r)
	return rows


## Arma la base de `src` en `out`. Devuelve si salió bien.
func build(src: String, out: String) -> bool:
	report.clear()
	TeamDB.use_db(TeamDB.DEFAULT_DB)
	var league_rows := _rows(src.path_join("ligas"))
	var sel_rows := _rows(src.path_join("selecciones"))
	if league_rows.is_empty():
		report.append("No hay CSV en %s" % src.path_join("ligas"))
		return false
	_load_ids(src.path_join("ids.json"))
	for row in league_rows + sel_rows:
		_clean_row(row)
	for row in league_rows:
		_pin_league(row)
	var club_alias: Variant = UserData.read_json(src.path_join("clubes_alias.json"))
	if not club_alias is Dictionary:
		club_alias = {}
	var of := OptionFile.new()
	TeamDB.use_option_file(of)

	# --- Clubes, ligas y países ------------------------------------------------------
	var plan := SquadImporter.plan_rows(league_rows, of).filter(func(e: Dictionary) -> bool:
		return e["kind"] == "league")
	var taken := {}
	for e in plan:
		# Los que en la base tienen otro nombre (clubes_alias.json).
		var al: Dictionary = (club_alias as Dictionary).get(String(e["country"]), {})
		for k in al:
			if ClubImporter.norm(String(k)) == ClubImporter.norm(String(e["name"])):
				e["choice"] = String(al[k])
				e["status"] = "match"
	for e in plan:
		if e["status"] == "match":
			taken["%s:%s" % [e["country"], e["choice"]]] = true
	for e in plan:
		if String(e["division"]) == "":
			report.append("Liga sin ubicar (no se importa): %s (%s)" % [e["division_name"], e["name"]])
			continue
		if e["status"] == "doubt":
			# El de nombre igual (si nadie lo tomó) o un club nuevo.
			var pick := ""
			for c in e["candidates"]:
				var k := "%s:%s" % [e["country"], c["id"]]
				if c["exact"] and String(c["country"]) == String(e["country"]) and not taken.has(k):
					pick = String(c["id"])
			e["choice"] = pick if pick != "" else ClubImporter.NEW
			if pick != "":
				taken["%s:%s" % [e["country"], pick]] = true
			report.append("Club en duda: %s (%s) -> %s" % [e["name"], e["division_name"],
				pick if pick != "" else "club nuevo"])
		if not (e["new_division"] as Array).is_empty():
			SquadImporter._ensure_division(e["new_division"], of)
	plan = plan.filter(func(e: Dictionary) -> bool: return String(e["division"]) != "")
	var res_clubs := ClubImporter.apply(plan, of, false)
	TeamDB.use_option_file(of)
	var dest := {} # clave del plan -> "pais:id"
	var alias := {} # nombre normalizado del club en los CSV -> ["pais:id", ...]
	for e in plan:
		var id := String(e.get("applied_id", ""))
		if id == "":
			continue
		var where := "%s:%s" % [e["country"], id]
		dest[e["key"]] = where
		var list: Array = alias.get_or_add(ClubImporter.norm(String(e["name"])), [])
		if not list.has(where):
			list.append(where)

	# --- Jugadores de los clubes ---------------------------------------------------
	var per_club := {} # "pais:id" -> [jugadores]
	var seen := {}
	var sel_marks := {} # selección -> [jugador]
	for row in league_rows:
		var p := SquadImporter.to_player(row)
		if String(p["n"]) == "":
			continue
		var club := SquadImporter.field(row, "club")
		var key := SquadImporter._row_key("league", club, SquadImporter.field(row, "league"))
		if not dest.has(key):
			continue
		_fix_nationality(p)
		var where: String = dest[key]
		var dup := "%s|%s|%s|%s" % [where, SquadImporter.normalize(String(p["n"])), p.get("h", 0), p.get("age", 0)]
		if seen.has(dup):
			continue
		seen[dup] = true
		per_club.get_or_add(where, []).append(p)
		var nt := SquadImporter.nation_id_of(SquadImporter.field(row, "national_team"))
		if nt != "":
			sel_marks.get_or_add(nt, []).append(p)
	var dropped := 0
	for where in per_club:
		var parts := String(where).split(":")
		var found := TeamDB.club(parts[0], parts[1])
		if found.is_empty():
			continue
		var entry: Dictionary = (found[0] as Dictionary).duplicate(true)
		var all: Array = per_club[where]
		var first := SquadImporter.pick_squad(all, TeamDB.CLUB_SQUAD_MAX, [2, 6, 6, 3])
		var rest := all.filter(func(p: Dictionary) -> bool: return not first.has(p))
		var young := rest.filter(func(p: Dictionary) -> bool: return int(p.get("age", 99)) <= TeamDB.U20_MAX_AGE + 1)
		dropped += rest.size() - mini(young.size(), TeamDB.CLUB_SQUAD_MAX)
		entry["players"] = first
		entry["youth"] = SquadImporter.pick_squad(young, TeamDB.CLUB_SQUAD_MAX, [0, 0, 0, 0]) if young.size() >= 1 else []
		if (entry["youth"] as Array).is_empty():
			entry.erase("youth")
		of.set_club(parts[0], entry)
	TeamDB.use_option_file(of)
	if dropped > 0:
		report.append("Jugadores que no entraron en el plantel (más de %d, mayores de %d): %d" % [
			TeamDB.CLUB_SQUAD_MAX, TeamDB.U20_MAX_AGE + 1, dropped])

	# --- La base: sólo las divisiones que vinieron en los CSV -----------------------
	var csv_divs := {}
	for e in plan:
		csv_divs["%s:%s" % [e["country"], e["division"]]] = true
	var countries: Array = []
	for c in TeamDB.countries():
		var cc: Dictionary = (c as Dictionary).duplicate(true)
		cc["divisions"] = (cc["divisions"] as Array).filter(func(d: Dictionary) -> bool:
			return csv_divs.has("%s:%s" % [cc["id"], d["id"]]))
		for d in cc["divisions"]:
			d["season"] = SEASON
		if not (cc["divisions"] as Array).is_empty():
			countries.append(cc)
		else:
			report.append("País sin ligas en los CSV (no va en la base): %s" % cc["name"])

	# --- Ids de los jugadores ------------------------------------------------------
	var by_club_name := {} # "pais:id" -> {nombre normalizado: [jugador]}
	for c in countries:
		for d in c["divisions"]:
			for cl in d["clubs"]:
				var where := "%s:%s" % [c["id"], cl["id"]]
				var names := {}
				for key in ["players", "youth"]:
					for p in cl.get(key, []):
						p["pid"] = _pid_for(p)
						p.erase("ovr")
						names.get_or_add(SquadImporter.normalize(String(p["n"])), []).append(p)
				by_club_name[where] = names

	# --- Selecciones ---------------------------------------------------------------
	var external := {} # clave -> jugador
	var squads := {} # selección -> {pid: dorsal}
	var comps := {} # torneo -> {id, name, teams}
	var matched := 0
	var fuzzy: Array[String] = []
	for row in sel_rows:
		var p := SquadImporter.to_player(row)
		if String(p["n"]) == "":
			continue
		_fix_nationality(p)
		var nat := SquadImporter.nation_id_of(SquadImporter.field(row, "national_team"))
		if nat == "":
			nat = String(p.get("_nat", ""))
		if nat == "":
			report.append("Selección desconocida: %s (%s)" % [SquadImporter.field(row, "national_team"), p["n"]])
			continue
		var tour := SquadImporter.field(row, "league")
		if tour != "":
			var comp: Dictionary = comps.get_or_add(tour, {"id": "sel_" + SquadImporter.normalize(tour).replace(" ", "_"), "name": tour,
				"kind": "nations", "teams": []})
			if not (comp["teams"] as Array).has(nat):
				comp["teams"].append(nat)
		var club := SquadImporter.field(row, "club")
		var hit := _find_in_clubs(p, alias.get(ClubImporter.norm(club), []), by_club_name)
		var pid := 0
		if not hit.is_empty():
			pid = int(hit["pid"])
			matched += 1
			if SquadImporter.normalize(String(hit["n"])) != SquadImporter.normalize(String(p["n"])):
				fuzzy.append("%s (%s) = %s (%s)" % [p["n"], club, hit["n"], club])
		else:
			if alias.has(ClubImporter.norm(club)):
				report.append("Convocado que no está en el plantel de su club (queda del exterior): %s (%s, %s)" % [
					p["n"], club, nat.to_upper()])
			var k := _key(p)
			if not external.has(k):
				var ext := p.duplicate(true)
				ext.erase("ovr")
				ext.erase("num")
				ext["club_name"] = club
				ext["pid"] = _pid_for(ext)
				external[k] = ext
			pid = int(external[k]["pid"])
		var s: Dictionary = squads.get_or_add(nat, {})
		if not s.has(pid) or int(s[pid]) == 0:
			s[pid] = int(p.get("num", 0))
	# Los marcados con la columna "seleccion" en los CSV de ligas.
	for nat in sel_marks:
		for p in sel_marks[nat]:
			if int(p.get("pid", 0)) > 0:
				squads.get_or_add(nat, {}).get_or_add(int(p["pid"]), 0)
	report.append("Convocados encontrados en su club: %d (%d por apellido, estatura y edad); del exterior: %d." % [
		matched, fuzzy.size(), external.size()])
	if not fuzzy.is_empty():
		report.append("Cruzados por apellido (revisar):")
		for f in fuzzy:
			report.append("  " + f)

	var all_by_pid := {}
	for c in countries:
		for d in c["divisions"]:
			for cl in d["clubs"]:
				for key in ["players", "youth"]:
					for p in cl.get(key, []):
						all_by_pid[int(p["pid"])] = p
	for k in external:
		all_by_pid[int(external[k]["pid"])] = external[k]
	var nations: Array = []
	var ids_sorted := squads.keys()
	ids_sorted.sort()
	for nat in ids_sorted:
		var base := TeamDB.nation(String(nat))
		if base.is_empty():
			base = NationCatalog.entry(String(nat))
		if base.is_empty():
			report.append("Selección sin datos de bandera y camisetas (no va en la base): %s" % nat)
			continue
		var entry: Dictionary = base.duplicate(true)
		entry.erase("players")
		entry["id"] = String(nat)
		if not entry.has("wc"):
			entry["wc"] = ""
		var list: Array = []
		for pid in squads[nat]:
			list.append(all_by_pid[int(pid)])
		var squad := SquadImporter.pick_squad(list, TeamDB.CLUB_SQUAD_MAX, [3, 8, 7, 5])
		entry["squad"] = squad.map(func(p: Dictionary) -> int: return int(p["pid"]))
		var nums := {}
		for p in squad:
			var num := int(squads[nat][int(p["pid"])])
			if num > 0:
				nums[str(int(p["pid"]))] = num
		entry["nums"] = nums
		entry["level"] = _level_of(squad)
		nations.append(entry)

	# --- Competencias --------------------------------------------------------------
	var competitions: Array = []
	for c in countries:
		for d in c["divisions"]:
			competitions.append({"id": String(d["id"]), "name": String(d["name"]), "kind": "league",
				"country": String(c["id"]), "level": int(d.get("level", 1)),
				"teams": (d["clubs"] as Array).map(func(cl: Dictionary) -> String: return TeamDB.club_path(c["id"], cl["id"]))})
	var tours := comps.keys()
	tours.sort()
	for t in tours:
		var comp: Dictionary = comps[t]
		comp["teams"] = (comp["teams"] as Array).filter(func(n: String) -> bool:
			return nations.any(func(x: Dictionary) -> bool: return x["id"] == n)).map(func(n: String) -> String:
			return TeamDB.nation_path(n))
		competitions.append(comp)

	# --- Escribir -------------------------------------------------------------------
	for pid in all_by_pid:
		(all_by_pid[pid] as Dictionary).erase("_nat")
	TeamDB.use_option_file(null)
	DirAccess.make_dir_recursive_absolute(out.path_join("leagues"))
	var d0 := DirAccess.open(out.path_join("leagues"))
	if d0 != null:
		for f in d0.get_files():
			d0.remove(f)
	for c in countries:
		_save(out.path_join("leagues").path_join(String(c["id"]) + ".json"), c)
	_save(out.path_join("nations.json"), {"season": SEASON, "nations": nations})
	var ext_list := external.values()
	ext_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["pid"]) < int(b["pid"]))
	_save(out.path_join(TeamDB.EXTERNAL_FILE), {"season": SEASON, "players": ext_list})
	_save(out.path_join("competitions.json"), {"season": SEASON, "competitions": competitions})
	_save(out.path_join("meta.json"), {"id": DB_ID, "name": TeamDB.db_name(DB_ID), "season": SEASON,
		"players": all_by_pid.size(), "clubs": by_club_name.size(), "nations": nations.size(),
		"competitions": competitions.size()})
	_save_ids(src.path_join("ids.json"))
	var problems := validate(countries, nations, ext_list, competitions)
	report.push_front("Temporada 2026: %d jugadores (%d en clubes, %d del exterior), %d clubes en %d países, %d selecciones, %d competencias. Clubes nuevos: %d." % [
		all_by_pid.size(), all_by_pid.size() - ext_list.size(), ext_list.size(), by_club_name.size(), countries.size(),
		nations.size(), competitions.size(), int(res_clubs["new"])])
	for pr in problems:
		report.push_front("ERROR: " + pr)
	_write_report(src.path_join("informe.txt"))
	TeamDB.reload()
	return problems.is_empty()


## Saca caracteres invisibles de los nombres ("Eintracht Fráncfort\u200b").
static func _clean_row(row: Dictionary) -> void:
	for k in row:
		if row[k] is String:
			row[k] = String(row[k]).replace("\u200b", "").replace("\ufeff", "").strip_edges()


## Pone en la fila la división de la base que dice el nombre del archivo
## ("Serie A Italia"), si el país ya tiene una de ese nivel; si no, queda el
## nombre del CSV (liga nueva: SquadImporter.NEW_LEAGUES).
static func _pin_league(row: Dictionary) -> void:
	var parts := String(row.get("_file", "")).get_basename().split("_")
	var cid := String(FILE_COUNTRY.get(parts[0].to_upper(), ""))
	if cid == "":
		return
	var level := int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else 1
	var c := TeamDB.country(cid)
	for d in c.get("divisions", []):
		if int(d.get("level", 0)) == level:
			for k in SquadImporter.ALIASES["league"]:
				if row.has(k):
					row[k] = "%s %s" % [d["name"], c["name"]]
			return


## Nacionalidad: el nombre de la selección (castellano) y su id aparte.
static func _fix_nationality(p: Dictionary) -> void:
	var nat_id := SquadImporter.nation_id_of(String(p.get("nat", "")))
	if nat_id != "":
		p["nat"] = SquadImporter.nation_name(nat_id, String(p.get("nat", "")))
		p["_nat"] = nat_id


## El convocado en el plantel de su club: el del mismo nombre (el de
## estatura más parecida si hay dos) o, si no, el del mismo apellido con
## estatura y edad parecidas.
static func _find_in_clubs(p: Dictionary, clubs: Array, by_club_name: Dictionary) -> Dictionary:
	var name := SquadImporter.normalize(String(p["n"]))
	var best := {}
	var best_d := 999
	for where in clubs:
		var names: Dictionary = by_club_name.get(where, {})
		for c in names.get(name, []):
			var dd := absi(int(c.get("h", 0)) - int(p.get("h", 0))) + absi(int(c.get("age", 0)) - int(p.get("age", 0)))
			if dd < best_d:
				best = c
				best_d = dd
	if not best.is_empty():
		return best
	var last := _last_word(name)
	for where in clubs:
		var names: Dictionary = by_club_name.get(where, {})
		for k in names:
			if _last_word(String(k)) != last:
				continue
			for c in names[k]:
				var dh := absi(int(c.get("h", 0)) - int(p.get("h", 0)))
				var da := absi(int(c.get("age", 0)) - int(p.get("age", 0)))
				if dh <= 2 and da <= 1 and String(c.get("_nat", "")) == String(p.get("_nat", "")) and dh + da < best_d:
					best = c
					best_d = dh + da
	return best


static func _last_word(s: String) -> String:
	var w := s.replace(".", " ").split(" ", false)
	return w[w.size() - 1] if not w.is_empty() else s


## Clave estable de un jugador para el registro de ids.
static func _key(p: Dictionary) -> String:
	var born := YEAR - int(p.get("age", 0)) if int(p.get("age", 0)) > 0 else 0
	return "%s|%s|%d|%d" % [SquadImporter.normalize(String(p["n"])), String(p.get("_nat", p.get("nat", ""))), born,
		int(p.get("h", 0))]


func _pid_for(p: Dictionary) -> int:
	var base := _key(p)
	var k := base
	var n := 2
	while _used_keys.has(k):
		k = "%s#%d" % [base, n]
		n += 1
	_used_keys[k] = true
	if not ids.has(k):
		ids[k] = next_pid
		next_pid += 1
	return int(ids[k])


func _load_ids(file: String) -> void:
	ids = {}
	next_pid = 1
	_used_keys = {}
	var d: Variant = UserData.read_json(file)
	if d is Dictionary:
		ids = d.get("players", {})
		next_pid = int(d.get("next", 1))
		for k in ids:
			next_pid = maxi(next_pid, int(ids[k]) + 1)


func _save_ids(file: String) -> void:
	# Sólo los que siguen en la base (los que se fueron no se reusan: next sigue).
	var keep := {}
	for k in _used_keys:
		keep[k] = ids[k]
	_save(file, {"next": next_pid, "players": keep})


## Nivel de una selección: el promedio de sus 16 mejores.
static func _level_of(squad: Array) -> int:
	var scores: Array = squad.map(func(p: Dictionary) -> float: return TeamDB.overall(TeamDB.player_from_dict(p, "x", 0)))
	scores.sort()
	scores.reverse()
	var top := scores.slice(0, 16)
	var total := 0.0
	for s in top:
		total += float(s)
	return roundi(total / maxf(top.size(), 1.0))


## Problemas de la base armada: ids repetidos o referencias rotas.
static func validate(countries: Array, nations: Array, external: Array, competitions: Array) -> Array[String]:
	var out: Array[String] = []
	var pids := {}
	var clubs := {}
	var divisions := {}
	for c in countries:
		for d in c["divisions"]:
			if divisions.has(String(d["id"])):
				out.append("división repetida: %s" % d["id"])
			divisions[String(d["id"])] = true
			for cl in d["clubs"]:
				var k := "%s:%s" % [c["id"], cl["id"]]
				if clubs.has(k):
					out.append("club repetido: %s" % k)
				clubs[k] = true
				if (cl.get("players", []) as Array).size() < 16:
					out.append("plantel corto (%d): %s" % [(cl.get("players", []) as Array).size(), k])
				for key in ["players", "youth"]:
					for p in cl.get(key, []):
						var pid := int(p.get("pid", 0))
						if pid <= 0:
							out.append("jugador sin id: %s (%s)" % [p.get("n", "?"), k])
						elif pids.has(pid):
							out.append("pid repetido %d: %s y %s" % [pid, pids[pid], k])
						pids[pid] = k
	for p in external:
		var pid := int(p.get("pid", 0))
		if pid <= 0 or pids.has(pid):
			out.append("pid del exterior repetido o vacío: %s" % p.get("n", "?"))
		pids[pid] = "exterior"
	var nat_ids := {}
	for n in nations:
		if nat_ids.has(String(n["id"])):
			out.append("selección repetida: %s" % n["id"])
		nat_ids[String(n["id"])] = true
		for pid in n.get("squad", []):
			if not pids.has(int(pid)):
				out.append("convocado sin jugador: %s en %s" % [pid, n["id"]])
	var comp_ids := {}
	for c in competitions:
		if comp_ids.has(String(c["id"])):
			out.append("competencia repetida: %s" % c["id"])
		comp_ids[String(c["id"])] = true
	return out


func _write_report(file: String) -> void:
	var unique: Array[String] = []
	for line in report:
		if not unique.has(line):
			unique.append(line)
	report = unique
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f != null:
		f.store_string("VIRTUAL ELEVEN · base Temporada 2026\n\n" + "\n".join(report) + "\n")


static func _save(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo escribir " + path)
		return
	f.store_string(JSON.stringify(data, "", false))
