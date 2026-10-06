class_name ClubImporter
extends RefCounted
## Importa listas de clubes desde CSV (nombre, división, estadio; opcionales
## país, id, sigla y capacidad). Primero se arma una propuesta para revisar
## (analyze) y después se aplica al Option File (apply):
##   - "match":  el club se encontró en la base (por id, por nombre o, si hay
##               varios parecidos, por el estadio).
##   - "doubt":  hay varios clubes posibles (o dos filas con el mismo club):
##               lo elige el usuario.
##   - "new":    no hay ninguno parecido: se crea un club nuevo.
##   - "skip":   la división no existe en el juego.
## Al aplicar, cada división que aparece en el CSV queda formada sólo por sus
## clubes, en el orden del archivo. Las demás divisiones no se tocan (salvo
## que pierdan un club que el CSV puso en otra).

const NEW := "+"
const SKIP := "-"

const ALIASES := {
	"name": ["nombre_completo", "nombre", "club", "equipo", "name", "club_name", "team", "team_name"],
	"division": ["division", "liga", "league", "categoria", "torneo", "league_name"],
	"stadium": ["estadio", "stadium", "cancha", "stadium_name"],
	"country": ["pais", "country", "league_country"],
	"id": ["id", "club_id", "id_club"],
	"short": ["sigla", "short", "abreviatura", "short_name"],
	"capacity": ["capacidad", "capacity"],
}

## Otros nombres de las divisiones (además del de la base).
const DIVISION_ALIASES := {
	"arg1": ["primera division", "primera", "liga profesional", "lpf", "liga profesional de futbol", "superliga"],
	"arg2": ["primera nacional", "nacional b", "b nacional", "primera b nacional"],
	"arg3": ["primera b", "b metro", "primera b metropolitana", "b metropolitana"],
	"arg4": ["primera c", "primera c metropolitana"],
	"bra1": ["brasileirao", "serie a brasil", "campeonato brasileiro"],
	"eng1": ["premier league", "premier"],
	"eng2": ["championship", "efl championship"],
	"eng3": ["league one", "efl league one"],
	"eng4": ["league two", "efl league two"],
	"esp1": ["laliga", "la liga", "laliga ea sports", "primera division de espana"],
	"esp2": ["laliga 2", "la liga 2", "segunda division", "laliga hypermotion"],
	"ger1": ["bundesliga"],
	"ger2": ["2. bundesliga", "2 bundesliga", "segunda bundesliga"],
	"ita1": ["serie a"],
	"ita2": ["serie b"],
	"mex1": ["liga mx"],
	"ned1": ["eredivisie"],
	"por1": ["liga portugal", "primeira liga"],
}

## Palabras que no cuentan para comparar estadios.
const STOP := ["de", "del", "la", "el", "los", "las", "y", "estadio", "club", "dr", "dr.", "presidente", "the",
	"stadium", "ciudad", "municipal", "nuevo", "don"]


static func norm(s: String) -> String:
	return SquadImporter.normalize(s).replace("´", "'").replace("`", "'").replace("’", "'").replace("\"", "")


static func field(row: Dictionary, key: String) -> String:
	for k in ALIASES[key]:
		if row.has(k) and String(row[k]).strip_edges() != "":
			return String(row[k]).strip_edges()
	return ""


## ¿El CSV es una lista de clubes? (tiene división y no tiene puestos).
static func is_club_list(rows: Array[Dictionary]) -> bool:
	if rows.is_empty():
		return false
	var r: Dictionary = rows[0]
	for k in SquadImporter.ALIASES["positions"]:
		if r.has(k):
			return false
	for k in ALIASES["division"]:
		if r.has(k):
			return true
	return false


## División por nombre: [país, división] o [] si no existe.
static func find_division(name: String, country_hint: String = "") -> Array:
	var n := norm(name).trim_prefix("torneo ").strip_edges()
	var found: Array = []
	for c in TeamDB.countries():
		var cid := String(c["id"])
		if country_hint != "" and norm(country_hint) not in [cid, norm(String(c["name"]))]:
			continue
		for d in c["divisions"]:
			var did := String(d["id"])
			if n == norm(String(d["name"])) or n == did or n in DIVISION_ALIASES.get(did, []):
				found.append([cid, did])
	return found[0] if not found.is_empty() else []


static func _words(s: String) -> Array:
	var out := []
	for w in norm(s).replace("-", " ").replace("/", " ").replace("(", " ").replace(")", " ").replace(".", " ").split(" ", false):
		if w.length() >= 2 and not STOP.has(w):
			out.append(w)
	return out


## Cuántas palabras comparten dos nombres de estadio.
static func stadium_score(a: String, b: String) -> int:
	var wb := _words(b)
	var n := 0
	for w in _words(a):
		if wb.has(w):
			n += 1
	return n


## ¿El nombre del CSV se parece al club? ("Velez" ~ "Vélez Sarsfield",
## "Newell´s" ~ "Newell's Old Boys", "Racing" ~ "Racing de Córdoba").
static func name_matches(n: String, club: Dictionary) -> bool:
	var cn := norm(String(club["name"]))
	if n == cn or n == norm(String(club["id"])):
		return true
	var pn := " " + n + " "
	var pc := " " + cn + " "
	if pc.contains(pn) or (cn.length() >= 4 and pn.contains(pc)):
		return true
	# Por palabras, sin "de", "club"...: "Atletico Rafaela" ~ "Atlético de
	# Rafaela", "Atletico Lugano" ~ "Club Lugano".
	var wn := _name_words(n)
	var wc := _name_words(cn)
	return _subset(wn, wc) or _subset(wc, wn)


const NAME_STOP := ["de", "del", "la", "el", "los", "las", "y", "club", "ca", "fc", "cd", "cs", "sc"]


static func _name_words(s: String) -> Array:
	var out := []
	for w in s.replace("(", " ").replace(")", " ").replace(".", " ").split(" ", false):
		if not NAME_STOP.has(w):
			out.append(w)
	return out


static func _subset(a: Array, b: Array) -> bool:
	if a.is_empty():
		return false
	for w in a:
		if b.has(w):
			continue
		# Iniciales: "J. J. Urquiza" ~ "Justo José de Urquiza".
		if w.length() == 1 and b.any(func(x: String) -> bool: return x.begins_with(w)):
			continue
		return false
	return true


## Propuesta para revisar: una entrada por fila.
## {name, division_name, stadium, country, division, status, choice,
##  candidates: [{id, name, stadium, division}], note, short, capacity}
static func analyze(rows: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in rows:
		var name := field(row, "name")
		if name == "":
			continue
		var cap := field(row, "capacity").replace(".", "").replace(",", "")
		var e := {"name": name, "division_name": field(row, "division"), "stadium": field(row, "stadium"),
			"short": field(row, "short"), "capacity": int(cap) if cap.is_valid_int() else 0,
			"country": "", "division": "", "status": "skip", "choice": SKIP, "candidates": [], "note": ""}
		out.append(e)
		var where := find_division(e["division_name"], field(row, "country"))
		if where.is_empty():
			e["note"] = "La división \"%s\" no está en el juego." % e["division_name"]
			continue
		e["country"] = where[0]
		e["division"] = where[1]
		var cands: Array = []
		var exact := {}
		var by_id := field(row, "id")
		var n := norm(name)
		for d in TeamDB.country(where[0]).get("divisions", []):
			for cl in d["clubs"]:
				var c := {"id": String(cl["id"]), "name": String(cl["name"]), "stadium": String(cl.get("stadium", "")),
					"division": String(d["name"])}
				if name_matches(n, cl):
					cands.append(c)
				if by_id != "" and by_id == c["id"]:
					exact = c
		if not exact.is_empty():
			cands = [exact]
		e["candidates"] = cands
		if cands.is_empty():
			e["status"] = "new"
			e["choice"] = NEW
			e["note"] = "Club nuevo."
		elif cands.size() == 1:
			e["status"] = "match"
			e["choice"] = cands[0]["id"]
		else:
			# Varios parecidos: decide el estadio (si uno solo coincide más).
			var best := -1
			var best_score := 0
			var tie := false
			for i in cands.size():
				var s := stadium_score(e["stadium"], cands[i]["stadium"])
				if s > best_score:
					best = i
					best_score = s
					tie = false
				elif s == best_score and s > 0:
					tie = true
			if tie:
				# Empate de estadio: gana el que se llama exactamente así.
				var exacts := cands.filter(func(c: Dictionary) -> bool:
					return stadium_score(e["stadium"], c["stadium"]) == best_score \
						and (norm(c["name"]) == n or c["id"] == n))
				if exacts.size() == 1:
					best = cands.find(exacts[0])
					tie = false
			if best >= 0 and not tie:
				e["status"] = "match"
				e["choice"] = cands[best]["id"]
				e["note"] = "Elegido por el estadio."
			else:
				e["status"] = "doubt"
				e["choice"] = ""
				e["note"] = "Hay %d clubes con ese nombre: elegí cuál." % cands.size()
	# Dos filas con el mismo club: las dos quedan para revisar.
	var seen := {}
	for e in out:
		if e["status"] == "match":
			var key := "%s:%s" % [e["country"], e["choice"]]
			seen.get_or_add(key, []).append(e)
	for key in seen:
		if (seen[key] as Array).size() > 1:
			for e in seen[key]:
				e["status"] = "doubt"
				e["note"] = "Hay otra fila con el mismo club: revisá cuál es."
	return out


## Cuántas filas hay de cada estado.
static func summary(plan: Array) -> Dictionary:
	var s := {"match": 0, "doubt": 0, "new": 0, "skip": 0}
	for e in plan:
		s[e["status"]] = int(s[e["status"]]) + 1
	return s


## Aplica la propuesta al Option File. Las filas en duda sin elegir (choice
## "") y las salteadas no se aplican. Con `stadiums`, el estadio del CSV
## reemplaza al de la base.
static func apply(plan: Array, of: OptionFile, stadiums: bool = true) -> Dictionary:
	var lists := {} # país -> {división -> [ids]}
	var placed := {} # país -> {id: true}
	var created := 0
	var updated := 0
	var taken := {}
	for c in TeamDB.countries():
		for d in c["divisions"]:
			for cl in d["clubs"]:
				taken["%s:%s" % [c["id"], cl["id"]]] = true
	for key in of.clubs:
		taken[String(key)] = true
	for e in plan:
		var choice := String(e.get("choice", ""))
		if choice == "" or choice == SKIP or String(e["division"]) == "":
			continue
		var cid := String(e["country"])
		var id := choice
		if choice == NEW:
			id = EditorModel._free_id(EditorModel._slug(e["name"]), func(x: String) -> bool: return taken.has("%s:%s" % [cid, x]))
			taken["%s:%s" % [cid, id]] = true
			var short := String(e.get("short", ""))
			of.set_club(cid, {"id": id, "name": e["name"],
				"short": short.to_upper().substr(0, 3) if short != "" else String(e["name"]).substr(0, 3).to_upper(),
				"home": "ffffff/101820/ffffff", "away": "101820/101820/101820", "stadium": e["stadium"],
				"cap": int(e.get("capacity", 0))})
			created += 1
		elif stadiums and String(e["stadium"]) != "":
			var found := TeamDB.club(cid, id)
			if not found.is_empty() and String(found[0].get("stadium", "")) != String(e["stadium"]):
				var entry: Dictionary = (found[0] as Dictionary).duplicate(true)
				entry["stadium"] = e["stadium"]
				if int(e.get("capacity", 0)) > 0:
					entry["cap"] = int(e["capacity"])
				of.set_club(cid, entry)
				updated += 1
		e["applied_id"] = id
		var div_list: Array = lists.get_or_add(cid, {}).get_or_add(String(e["division"]), [])
		if not div_list.has(id):
			div_list.append(id)
		placed.get_or_add(cid, {})[id] = true
	var clubs := 0
	for cid in lists:
		for d in TeamDB.country(cid).get("divisions", []):
			var did := String(d["id"])
			if lists[cid].has(did):
				of.set_division(cid, did, lists[cid][did])
				clubs += (lists[cid][did] as Array).size()
			else:
				# Si un club pasó a otra división del CSV, sale de esta.
				var ids: Array = []
				var changed := false
				for cl in d["clubs"]:
					if placed[cid].has(String(cl["id"])):
						changed = true
					else:
						ids.append(String(cl["id"]))
				if changed:
					of.set_division(cid, did, ids)
	TeamDB.use_option_file(of)
	var divisions := 0
	for cid in lists:
		divisions += (lists[cid] as Dictionary).size()
	return {"clubs": clubs, "new": created, "stadiums": updated, "divisions": divisions}


## Lee los CSV de clubes de una carpeta (los de jugadores se ignoran).
static func read_folder(dir: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for f in UserData.files_in(dir, "csv"):
		var r := SquadImporter.read_csv(f)
		if is_club_list(r):
			rows.append_array(r)
	return rows
