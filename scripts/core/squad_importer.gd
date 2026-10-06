class_name SquadImporter
extends RefCounted
## Importa planteles reales desde uno o más CSV (EA FC / SoFIFA,
## Transfermarkt o una planilla propia). Desde el juego (OPCIONES > DATOS)
## los guarda en el Option File activo; desde la consola
## (tools/import_players.gd) en la base del juego.
##
## Los nombres de columna se reconocen en inglés o en castellano (ver
## ALIASES); lo que no se reconoce se ignora. Lo mínimo por fila: club (o
## selección) y nombre. Con atributos de FC se convierten a los del juego
## (to_attributes); sin atributos se estiman por la valoración ("overall") o
## el nivel del equipo.
##   - Cada jugador va a su club si el nombre coincide con uno de la base;
##     todos los del listado por club, hasta 40 (con al menos 2 arqueros).
##   - Las selecciones se arman con los mejores 23 de cada nacionalidad
##     (3 arqueros, 8 defensores, 7 volantes, 5 delanteros), salvo que el CSV
##     traiga la columna "seleccion"/"national_team" con jugadores marcados.
##   - report: los clubes que no se encontraron, para corregir el nombre.

const ALIASES := {
	"name": ["short_name", "nombre_corto", "name", "nombre", "player", "jugador", "player_name", "long_name", "nombre_completo"],
	"club": ["club_name", "club", "team", "equipo", "team_name"],
	"country": ["league_country", "pais", "country"],
	"nationality": ["nationality_name", "nationality", "nacionalidad", "nation", "citizenship"],
	"number": ["club_jersey_number", "dorsal", "number", "shirt_number", "jersey_number", "numero"],
	"positions": ["player_positions", "puesto", "position", "posicion", "positions", "main_position"],
	"alt_positions": ["puestos_alt", "other_positions", "alt_positions"],
	"foot": ["preferred_foot", "pie", "foot"],
	"height": ["height_cm", "estatura_cm", "height", "estatura", "altura"],
	"age": ["age", "edad"],
	"dob": ["dob", "nacimiento", "date_of_birth", "birth_date", "fecha_nacimiento"],
	"overall": ["overall", "ovr", "valoracion", "media", "rating"],
	"national_team": ["seleccion", "national_team", "nation_team_name"],
	"league": ["league_name", "liga", "league", "competicion", "competition", "torneo", "division"],
}

## Nombres en inglés (FC / Transfermarkt) -> id de la base.
const NATION_ALIASES := {
	"united states": "usa", "usa": "usa", "estados unidos": "usa", "mexico": "mex", "canada": "can",
	"argentina": "arg", "brazil": "bra", "brasil": "bra", "uruguay": "uru", "colombia": "col",
	"ecuador": "ecu", "paraguay": "par", "bolivia": "bol", "peru": "per", "chile": "chi",
	"japan": "jpn", "japon": "jpn", "korea republic": "kor", "south korea": "kor", "corea del sur": "kor",
	"iran": "irn", "ir iran": "irn", "australia": "aus", "saudi arabia": "ksa", "arabia saudita": "ksa",
	"qatar": "qat", "uzbekistan": "uzb", "jordan": "jor", "jordania": "jor", "iraq": "irq", "irak": "irq",
	"china pr": "chn", "china": "chn", "morocco": "mar", "marruecos": "mar", "senegal": "sen",
	"tunisia": "tun", "tunez": "tun", "egypt": "egy", "egipto": "egy", "algeria": "alg", "argelia": "alg",
	"ghana": "gha", "cote d'ivoire": "civ", "ivory coast": "civ", "costa de marfil": "civ",
	"south africa": "rsa", "sudafrica": "rsa", "cape verde": "cpv", "cabo verde": "cpv",
	"cape verde islands": "cpv", "congo dr": "cod", "dr congo": "cod", "rd del congo": "cod", "rd congo": "cod", "republica democratica del congo": "cod",
	"nigeria": "nga", "cameroon": "cmr", "camerun": "cmr", "new zealand": "nzl", "nueva zelanda": "nzl",
	"new caledonia": "ncl", "nueva caledonia": "ncl", "panama": "pan", "haiti": "hai", "curacao": "cuw",
	"curazao": "cuw", "jamaica": "jam", "suriname": "sur", "surinam": "sur", "england": "eng",
	"inglaterra": "eng", "france": "fra", "francia": "fra", "spain": "esp", "espana": "esp",
	"germany": "ger", "alemania": "ger", "portugal": "por", "netherlands": "ned", "holland": "ned",
	"paises bajos": "ned", "belgium": "bel", "belgica": "bel", "croatia": "cro", "croacia": "cro",
	"switzerland": "sui", "suiza": "sui", "austria": "aut", "norway": "nor", "noruega": "nor",
	"scotland": "sco", "escocia": "sco", "italy": "ita", "italia": "ita", "poland": "pol", "polonia": "pol",
	"kosovo": "kos", "denmark": "den", "dinamarca": "den", "russia": "rus", "rusia": "rus",
	"turkey": "tur", "turkiye": "tur", "turquia": "tur",
	"arabia saudi": "ksa", "catar": "qat", "holanda": "ned", "korea, south": "kor", "republica de corea": "kor",
	"emiratos": "uae", "irlanda": "irl", "czech republic": "cze", "bosnia-herzegovina": "bih",
}

## Puestos de FC / Transfermarkt -> siglas del WE.
const POSITION_MAP := {
	"GK": "GK", "CB": "CB", "LB": "LB", "RB": "RB", "LWB": "LB", "RWB": "RB", "CDM": "DMF", "CM": "CMF",
	"CAM": "AMF", "LM": "LMF", "RM": "RMF", "LW": "WG", "RW": "WG", "ST": "CF", "CF": "CF",
	"GOALKEEPER": "GK", "CENTRE-BACK": "CB", "LEFT-BACK": "LB", "RIGHT-BACK": "RB",
	"DEFENSIVE MIDFIELD": "DMF", "CENTRAL MIDFIELD": "CMF", "ATTACKING MIDFIELD": "AMF",
	"LEFT MIDFIELD": "LMF", "RIGHT MIDFIELD": "RMF", "LEFT WINGER": "WG", "RIGHT WINGER": "WG",
	"CENTRE-FORWARD": "CF", "SECOND STRIKER": "CF",
	"ARQ": "GK", "ARQUERO": "GK", "DFC": "CB", "LI": "LB", "LD": "RB", "MCD": "DMF", "MC": "CMF",
	"MCO": "AMF", "MI": "LMF", "MD": "RMF", "EXT": "WG", "DC": "CF", "DEL": "CF",
	"DMF": "DMF", "CMF": "CMF", "AMF": "AMF", "LMF": "LMF", "RMF": "RMF", "WG": "WG", "SS": "CF",
}

## Informe de la última importación (líneas de texto).
var report: Array[String] = []


# --- Lectura -----------------------------------------------------------------------

static func normalize(s: String) -> String:
	var t := s.strip_edges().to_lower()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"], ["ç", "c"],
			["ã", "a"], ["õ", "o"], ["â", "a"], ["ê", "e"], ["ô", "o"], ["à", "a"], ["è", "e"], ["ö", "o"], ["ä", "a"],
			["ı", "i"], ["ş", "s"], ["ğ", "g"], ["ø", "o"], ["å", "a"], ["ł", "l"], ["ś", "s"], ["ž", "z"], ["č", "c"], ["ć", "c"]]:
		t = t.replace(pair[0], pair[1])
	return t


## Filas del CSV como diccionarios con las columnas normalizadas
## (minúsculas, sin acentos, "_" en lugar de espacios). Detecta "," o ";".
static func read_csv(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir " + path)
		return out
	var first := f.get_line()
	var delim := ";" if first.count(";") > first.count(",") else ","
	f.seek(0)
	var header := f.get_csv_line(delim)
	var keys: Array[String] = []
	for h in header:
		keys.append(normalize(h).replace(" ", "_").replace("-", "_"))
	while not f.eof_reached():
		var line := f.get_csv_line(delim)
		if line.size() < 2:
			continue
		var row := {}
		for i in mini(line.size(), keys.size()):
			row[keys[i]] = line[i].strip_edges()
		out.append(row)
	return out


static func field(row: Dictionary, key: String) -> String:
	for k in ALIASES.get(key, [key]):
		if row.has(k) and String(row[k]) != "":
			return String(row[k])
	return ""


static func num(row: Dictionary, keys: Array) -> int:
	for k in keys:
		if row.has(k) and String(row[k]).strip_edges() != "":
			var v := String(row[k]).split("+")[0].split("-")[0].strip_edges()
			if v.is_valid_float():
				return int(float(v))
	return 0


## Atributos del juego a partir de los de FC (los que falten quedan en 0 y
## los completa TeamDB / PlayerData).
static func to_attributes(row: Dictionary) -> Dictionary:
	var avg := func(keys: Array) -> int:
		var total := 0
		var n := 0
		for k in keys:
			var v := num(row, [k])
			if v > 0:
				total += v
				n += 1
		return roundi(float(total) / n) if n > 0 else 0
	var a := {
		"speed": avg.call(["movement_sprint_speed", "pace", "velocidad"]),
		"acceleration": avg.call(["movement_acceleration", "pace", "aceleracion"]),
		"stamina": avg.call(["power_stamina", "resistencia"]),
		"strength": avg.call(["power_strength", "fuerza", "physic"]),
		"passing": avg.call(["attacking_short_passing", "skill_long_passing", "passing", "pase"]),
		"shooting": avg.call(["attacking_finishing", "power_long_shots", "shooting", "tiro", "definicion"]),
		"technique": avg.call(["skill_dribbling", "skill_curve", "skill_fk_accuracy", "dribbling", "tecnica"]),
		"ball_control": avg.call(["skill_ball_control", "dribbling", "control"]),
		"heading": avg.call(["attacking_heading_accuracy", "cabezazo"]),
		"defense": avg.call(["defending_standing_tackle", "defending_marking_awareness", "mentality_interceptions", "defending", "defensa"]),
		"reaction": avg.call(["movement_reactions", "reaccion"]),
		"balance": avg.call(["movement_balance", "equilibrio"]),
		"goalkeeping": avg.call(["goalkeeping_diving", "goalkeeping_handling", "goalkeeping_positioning", "goalkeeping_reflexes", "arquero"]),
		"attack": avg.call(["mentality_positioning", "ataque"]),
		"jump": avg.call(["power_jumping", "salto"]),
		"shot_power": avg.call(["power_shot_power", "potencia"]),
		"curve": avg.call(["skill_curve", "efecto"]),
	}
	var out := {}
	for k in a:
		if int(a[k]) > 0:
			out[k] = clampi(int(a[k]), 1, 99)
	return out


## Fila -> jugador en el formato de la base ({n, num, pos, alt, ft, h, age, nat, ovr, a}).
static func to_player(row: Dictionary) -> Dictionary:
	var d := {"n": field(row, "name")}
	var number := num(row, ALIASES["number"])
	if number > 0:
		d["num"] = number
	var positions := field(row, "positions").to_upper().replace(";", ",").split(",", false)
	var codes: Array[String] = []
	for ps in positions:
		var c := String(POSITION_MAP.get(ps.strip_edges(), ""))
		if c != "" and not codes.has(c):
			codes.append(c)
	d["pos"] = codes[0] if not codes.is_empty() else "CMF"
	if codes.size() > 1:
		d["alt"] = ",".join(codes.slice(1))
	var foot := normalize(field(row, "foot"))
	d["ft"] = "L" if foot.begins_with("l") or foot.begins_with("z") or foot.begins_with("izq") else \
		("B" if foot.begins_with("b") or foot.begins_with("amb") else "R")
	var h := num(row, ALIASES["height"])
	if h > 0 and h < 3:
		h = roundi(h * 100.0) # en metros
	if h > 0:
		d["h"] = h
	var age := num(row, ALIASES["age"])
	if age > 0:
		d["age"] = age
	var nat := field(row, "nationality")
	if nat != "":
		d["nat"] = nat
	var ovr := num(row, ALIASES["overall"])
	if ovr > 0:
		d["ovr"] = ovr
	var a := to_attributes(row)
	if a.size() >= 6:
		d["a"] = a
	return d


# --- Armado ------------------------------------------------------------------------

static func player_score(d: Dictionary) -> float:
	if d.has("ovr"):
		return float(d["ovr"])
	var a: Dictionary = d.get("a", {})
	var total := 0.0
	for v in a.values():
		total += float(v)
	return total / maxf(a.size(), 1.0) if not a.is_empty() else 50.0


static func line_of(d: Dictionary) -> int:
	return TeamDB.position_of_code(String(d.get("pos", "CMF")))


## Los mejores `n` con un mínimo por puesto general ([GK, DF, MF, FW]).
static func pick_squad(players: Array, n: int, minimum: Array) -> Array:
	var sorted := players.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return player_score(a) > player_score(b))
	var out: Array = []
	for line in 4:
		var need: int = minimum[line]
		for p in sorted:
			if need <= 0:
				break
			if line_of(p) == line and not out.has(p):
				out.append(p)
				need -= 1
	for p in sorted:
		if out.size() >= n:
			break
		if not out.has(p):
			out.append(p)
	return out.slice(0, n)


## Clubes de la base por nombre normalizado -> [país, índice de división, índice de club].
static func club_index() -> Dictionary:
	var idx := {}
	var countries := TeamDB.countries()
	for ci in countries.size():
		var divs: Array = countries[ci]["divisions"]
		for di in divs.size():
			var clubs: Array = divs[di]["clubs"]
			for k in clubs.size():
				idx[normalize(String(clubs[k]["name"]))] = [ci, di, k]
				idx[normalize(String(clubs[k]["id"]))] = [ci, di, k]
	return idx


## Busca el club: igual, o uno contenido en el otro ("Boca Juniors" ~
## "CA Boca Juniors").
static func find_club(idx: Dictionary, name: String) -> Array:
	var n := normalize(name)
	if idx.has(n):
		return idx[n]
	for prefix in ["fc ", "cf ", "ca ", "club ", "club atletico ", "sc ", "ac ", "as ", "ss ", "rc ", "cd ", "ud ", "sd ", "afc "]:
		if n.begins_with(prefix) and idx.has(n.trim_prefix(prefix)):
			return idx[n.trim_prefix(prefix)]
	var best: Array = []
	var best_len := 0
	for k in idx:
		var key := String(k)
		if key.length() >= 5 and (n.contains(key) or key.contains(n)) and key.length() > best_len:
			best = idx[k]
			best_len = key.length()
	return best


## Reparte los jugadores. Con `of`, los cambios van al Option File (no se
## guarda: lo hace quien llama); sin él, a los archivos de la base.
func import_rows(rows: Array[Dictionary], of: OptionFile = null) -> Dictionary:
	report.clear()
	var countries := TeamDB.countries()
	var idx := club_index()
	var by_club := {}
	var by_nation := {}
	var marked_nation := {}
	var unmatched := {}
	for row in rows:
		var p := to_player(row)
		if String(p["n"]) == "":
			continue
		var nat_id := String(NATION_ALIASES.get(normalize(String(p.get("nat", ""))), ""))
		if nat_id != "":
			p["nat"] = TeamDB.nation(nat_id).get("name", p.get("nat", ""))
			by_nation.get_or_add(nat_id, []).append(p)
		var nt := normalize(field(row, "national_team"))
		if nt != "" and NATION_ALIASES.has(nt):
			marked_nation.get_or_add(NATION_ALIASES[nt], []).append(p)
		var club := field(row, "club")
		if club == "":
			continue
		var where := find_club(idx, club)
		if where.is_empty():
			unmatched[club] = int(unmatched.get(club, 0)) + 1
			continue
		by_club.get_or_add(where, []).append(p)
	# Clubes: todos, hasta CLUB_SQUAD_MAX (2 arqueros, 6 defensores, 6 volantes, 3 delanteros como mínimo).
	var touched := {}
	var players_total := 0
	for where in by_club:
		var club: Dictionary = countries[where[0]]["divisions"][where[1]]["clubs"][where[2]]
		club["players"] = pick_squad(by_club[where], TeamDB.CLUB_SQUAD_MAX, [2, 6, 6, 3])
		players_total += (club["players"] as Array).size()
		touched[where[0]] = true
		if of != null:
			of.set_club(String(countries[where[0]]["id"]), club)
	if of == null:
		for ci in touched:
			_save_json(TeamDB.LEAGUES_DIR + String(countries[ci]["id"]) + ".json", countries[ci])
	# Selecciones: las convocatorias marcadas o los mejores 23 de cada país.
	var nations_count := 0
	var ns := TeamDB.nations()
	for n in ns:
		var id := String(n["id"])
		var pool: Array = marked_nation.get(id, by_nation.get(id, []))
		if pool.size() >= 11:
			n["players"] = pick_squad(pool, 23, [3, 8, 7, 5])
			nations_count += 1
			if of != null:
				of.set_nation(n)
	if nations_count > 0 and of == null:
		_save_json(TeamDB.NATIONS_FILE, {"season": "2026", "nations": ns})
	var total_unmatched := 0
	var names := unmatched.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return int(unmatched[a]) > int(unmatched[b]))
	for k in names:
		total_unmatched += int(unmatched[k])
	if not names.is_empty():
		report.append("Clubes del CSV que no están en la base (%d):" % names.size())
		for k in names.slice(0, 200):
			report.append("  %s (%d jugadores)" % [k, unmatched[k]])
	TeamDB.reload()
	return {"rows": rows.size(), "players": players_total, "clubs": by_club.size(), "nations": nations_count,
		"unmatched": total_unmatched, "unmatched_clubs": names.size()}


## Filas de todos los CSV de jugadores de una carpeta (las listas de clubes
## van por ClubImporter).
static func read_folder_rows(dir: String, files: Array[String] = []) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for f in UserData.files_in(dir, "csv"):
		var r := read_csv(f)
		if ClubImporter.is_club_list(r):
			continue
		files.append(f)
		rows.append_array(r)
	return rows


## Importa todos los CSV de una carpeta al Option File `of` (y lo guarda),
## con la propuesta automática: los clubes en duda no se importan.
func import_folder(dir: String, of: OptionFile) -> Dictionary:
	var files: Array[String] = []
	var rows := read_folder_rows(dir, files)
	if rows.is_empty():
		report.clear()
		return {"files": 0, "rows": 0, "players": 0, "clubs": 0, "nations": 0, "unmatched": 0, "unmatched_clubs": 0}
	var prev := TeamDB.option_file
	TeamDB.use_option_file(of)
	var plan := plan_rows(rows, of)
	var res := apply_plan(plan, rows, of)
	TeamDB.use_option_file(prev)
	res["files"] = files.size()
	save_report(plan)
	of.save()
	return res


static func report_path() -> String:
	return UserData.import_dir().path_join("informe_importacion.txt")


## Informe completo (todas las filas de la propuesta) en la carpeta de importar.
func save_report(plan: Array) -> void:
	var lines: Array[String] = ["MASTER ELEVEN · informe de importación", ""]
	lines.append_array(report)
	lines.append("")
	var titles := {"match": "Encontrados", "doubt": "Para revisar", "new": "Clubes nuevos", "skip": "No importados"}
	for st in ["doubt", "new", "skip", "match"]:
		var rows := plan.filter(func(e: Dictionary) -> bool: return e["status"] == st)
		if rows.is_empty():
			continue
		lines.append("%s (%d):" % [titles[st], rows.size()])
		for e in rows:
			var dest := String(e["choice"])
			for o in plan_options(e):
				if o[0] == e["choice"]:
					dest = String(o[1])
			lines.append("  %s [%s, %d jugadores] -> %s%s" % [e["name"], e["division_name"], e["players"], dest,
				("  (" + String(e["note"]) + ")") if String(e["note"]) != "" else ""])
		lines.append("")
	var f := FileAccess.open(report_path(), FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))


# --- Revisión de planteles (editor) -------------------------------------------------
# Antes de importar se arma una propuesta por club y liga del CSV (como la
# lista de clubes): qué club del juego es, si es nuevo o si no se importa. Lo
# que se elige queda en el Option File (club_alias) para la próxima vez.

const FREE := "*"

## Clubes que en realidad son "sin club".
const FREE_CLUBS := ["libre", "libres", "sin club", "sin equipo", "agente libre", "jugador libre", "free agent",
	"free agents", "without club", "retirado", "retired", "desconocido", "unknown", "-", "?", "---"]
## Ligas o copas juveniles: el plantel va a la Sub-20 del club.
const YOUTH_WORDS := ["sub-2", "sub 2", "sub2", "sub-1", "sub 1", "sub1", "u17", "u18", "u19", "u20", "u21", "u23",
	"u-17", "u-18", "u-19", "u-20", "u-21", "u-23", "youth", "primavera", "junioren", "jugend", "proyeccion",
	"reserva", "juvenil", "juniores", "premier league 2", "academy", "reserves"]
## Torneos de selecciones: el club del jugador no dice en qué liga juega.
const NATIONAL_WORDS := ["copa del mundo", "mundial", "world cup", "nations league", "copa america", "eurocopa",
	"euro 20", "copa oro", "gold cup", "copa africana", "africa cup", "asian cup", "copa asiatica", "eliminatorias",
	"qualifiers", "amistosos", "friendlies", "seleccion"]
## País de las ligas juveniles de un solo país.
const YOUTH_COUNTRY := {"proyeccion": "arg", "reserva": "arg", "primavera": "ita", "junioren": "ger",
	"premier league 2": "eng", "u21 premier": "eng", "u18 premier": "eng", "division de honor juvenil": "esp"}
## Ligas que no están en la base y se crean al importar:
## nombre normalizado -> [país, nombre del país, id de división, nombre, nivel].
const NEW_LEAGUES := {
	"ligue 1": ["fra", "Francia", "fra1", "Ligue 1", 1], "ligue 2": ["fra", "Francia", "fra2", "Ligue 2", 2],
	"major league soccer": ["usa", "Estados Unidos", "usa1", "MLS", 1], "mls": ["usa", "Estados Unidos", "usa1", "MLS", 1],
	"usl championship": ["usa", "Estados Unidos", "usa2", "USL Championship", 2],
	"saudi pro league": ["ksa", "Arabia Saudita", "ksa1", "Saudi Pro League", 1],
	"roshn saudi league": ["ksa", "Arabia Saudita", "ksa1", "Saudi Pro League", 1],
	"jupiler pro league": ["bel", "Bélgica", "bel1", "Pro League", 1], "pro league": ["bel", "Bélgica", "bel1", "Pro League", 1],
	"super lig": ["tur", "Turquía", "tur1", "Süper Lig", 1], "trendyol super lig": ["tur", "Turquía", "tur1", "Süper Lig", 1],
	"scottish premiership": ["sco", "Escocia", "sco1", "Premiership", 1], "premiership": ["sco", "Escocia", "sco1", "Premiership", 1],
	"k league 1": ["kor", "Corea del Sur", "kor1", "K League 1", 1], "j1 league": ["jpn", "Japón", "jpn1", "J1 League", 1],
	"a-league men": ["aus", "Australia", "aus1", "A-League", 1], "a-league": ["aus", "Australia", "aus1", "A-League", 1],
	"chinese super league": ["chn", "China", "chn1", "Superliga china", 1],
	"premier liga": ["rus", "Rusia", "rus1", "Premier Liga", 1], "russian premier league": ["rus", "Rusia", "rus1", "Premier Liga", 1],
	"eliteserien": ["nor", "Noruega", "nor1", "Eliteserien", 1], "ekstraklasa": ["pol", "Polonia", "pol1", "Ekstraklasa", 1],
	"pko bp ekstraklasa": ["pol", "Polonia", "pol1", "Ekstraklasa", 1],
	"superliga de dinamarca": ["den", "Dinamarca", "den1", "Superliga", 1], "3f superliga": ["den", "Dinamarca", "den1", "Superliga", 1],
	"admiral bundesliga": ["aut", "Austria", "aut1", "Bundesliga", 1],
	"credit suisse super league": ["sui", "Suiza", "sui1", "Super League", 1], "brack super league": ["sui", "Suiza", "sui1", "Super League", 1],
	"supersport hnl": ["cro", "Croacia", "cro1", "HNL", 1], "hnl": ["cro", "Croacia", "cro1", "HNL", 1],
	"botola pro": ["mar", "Marruecos", "mar1", "Botola Pro", 1], "egyptian premier league": ["egy", "Egipto", "egy1", "Premier League", 1],
	"qatar stars league": ["qat", "Catar", "qat1", "Stars League", 1], "persian gulf pro league": ["irn", "Irán", "irn1", "Pro League", 1],
	"canadian premier league": ["can", "Canadá", "can1", "Canadian Premier League", 1],
	"betway premiership": ["rsa", "Sudáfrica", "rsa1", "Premiership", 1],
	"super league 1": ["gre", "Grecia", "gre1", "Super League", 1], "super league greece": ["gre", "Grecia", "gre1", "Super League", 1],
	"mozzart bet superliga": ["srb", "Serbia", "srb1", "Superliga", 1], "chance liga": ["cze", "Chequia", "cze1", "Chance Liga", 1],
	"allsvenskan": ["swe", "Suecia", "swe1", "Allsvenskan", 1], "ukrainian premier league": ["ukr", "Ucrania", "ukr1", "Premier League", 1],
	"superliga rumania": ["rou", "Rumania", "rou1", "SuperLiga", 1], "nb i": ["hun", "Hungría", "hun1", "NB I", 1],
	"ligat haal": ["isr", "Israel", "isr1", "Ligat ha'Al", 1],
	"liga promerica": ["crc", "Costa Rica", "crc1", "Primera División", 1], "liga nacional de honduras": ["hon", "Honduras", "hon1", "Liga Nacional", 1],
	"liga futve": ["ven", "Venezuela", "ven1", "Liga FUTVE", 1],
	"laliga hypermotion": ["esp", "España", "esp2", "LaLiga 2", 2], "liga portugal 2": ["por", "Portugal", "por2", "Liga Portugal 2", 2],
	"keuken kampioen divisie": ["ned", "Países Bajos", "ned2", "Eerste Divisie", 2], "eerste divisie": ["ned", "Países Bajos", "ned2", "Eerste Divisie", 2],
	"liga de expansion mx": ["mex", "México", "mex2", "Liga de Expansión", 2],
	"brasileirao serie b": ["bra", "Brasil", "bra2", "Série B", 2], "campeonato brasileiro serie b": ["bra", "Brasil", "bra2", "Série B", 2],
	"primera b de chile": ["chi", "Chile", "chi2", "Primera B", 2], "liga de ascenso": ["chi", "Chile", "chi2", "Primera B", 2],
	"torneo federal a": ["arg", "Argentina", "arg5", "Federal A", 5], "federal a": ["arg", "Argentina", "arg5", "Federal A", 5],
	"primera d": ["arg", "Argentina", "arg6", "Primera D", 5],
}


static func _has_word(text: String, words: Array) -> String:
	for w in words:
		if text.contains(String(w)):
			return String(w)
	return ""


## Qué es una fila: "free", "youth", "national", "nation_only" o "league".
static func row_kind(club: String, league: String) -> String:
	var c := normalize(club)
	if c == "" or FREE_CLUBS.has(c):
		return "free"
	var l := normalize(league)
	if _has_word(l, YOUTH_WORDS) != "":
		return "youth"
	if _has_word(l, NATIONAL_WORDS) != "":
		# Sin club conocido el scraper pone el nombre de la selección.
		return "nation_only" if nation_id_of(club) != "" else "national"
	return "league"


static func _row_key(kind: String, club: String, league: String) -> String:
	return "%s|%s|%s" % [kind, normalize(club), "" if kind in ["national", "nation_only"] else normalize(league)]


## Clubes del juego (los de la base aunque hoy no jueguen en ninguna división
## y los nuevos del Option File) que se parecen a `name`, en el país `scope`
## (o en todos). Cada uno: {id, name, stadium, division, division_id, country, exact}.
static func club_candidates(name: String, scope: String = "", of: OptionFile = null) -> Array:
	var n := ClubImporter.norm(name)
	var out: Array = []
	var seen := {}
	for list in [TeamDB.countries(), TeamDB.base_countries()]:
		for c in list:
			var cid := String(c["id"])
			if scope != "" and cid != scope:
				continue
			for d in c["divisions"]:
				for cl in d["clubs"]:
					var key := "%s:%s" % [cid, cl["id"]]
					if seen.has(key) or not ClubImporter.name_matches(n, cl):
						continue
					seen[key] = true
					out.append({"id": String(cl["id"]), "name": String(cl["name"]), "stadium": String(cl.get("stadium", "")),
						"division": String(d["name"]), "division_id": String(d["id"]), "country": cid,
						"exact": ClubImporter.norm(String(cl["name"])) == n})
	if of != null:
		for key in of.clubs:
			var parts := String(key).split(":")
			if parts.size() != 2 or seen.has(String(key)) or (scope != "" and parts[0] != scope):
				continue
			var cl: Dictionary = of.clubs[key]
			if ClubImporter.name_matches(n, cl):
				seen[String(key)] = true
				out.append({"id": parts[1], "name": String(cl.get("name", "")), "stadium": String(cl.get("stadium", "")),
					"division": "", "division_id": "", "country": parts[0],
					"exact": ClubImporter.norm(String(cl.get("name", ""))) == n})
	return out


## Propuesta para revisar: una entrada por club y liga del CSV.
## {key, kind, name, division_name, stadium, players, country, division,
##  new_division, status, choice, candidates, note}. `choice` es el id del
## club (en las de liga, dentro de `country`), "país:id" en las demás,
## ClubImporter.NEW, ClubImporter.SKIP, FREE o "" (sin elegir).
static func plan_rows(rows: Array[Dictionary], of: OptionFile = null) -> Array[Dictionary]:
	var groups := {}
	var order: Array = []
	for row in rows:
		var club := field(row, "club")
		var league := field(row, "league")
		var kind := row_kind(club, league)
		var key := _row_key(kind, club, league)
		if not groups.has(key):
			groups[key] = {"key": key, "kind": kind, "name": club if club != "" else "(sin club)",
				"division_name": league, "stadium": "", "players": 0, "country": "", "division": "", "new_division": [],
				"status": "skip", "choice": ClubImporter.SKIP, "candidates": [], "note": ""}
			order.append(key)
		groups[key]["players"] = int(groups[key]["players"]) + 1
	var out: Array[Dictionary] = []
	for key in order:
		var e: Dictionary = groups[key]
		_plan_entry(e, of)
		out.append(e)
	# Dos clubes del CSV en el mismo club del juego (en ligas): a revisar.
	var seen := {}
	for e in out:
		if e["kind"] == "league" and e["status"] == "match" and String(e["division"]) != "":
			seen.get_or_add("%s:%s" % [e["country"], e["choice"]], []).append(e)
	for k in seen:
		if (seen[k] as Array).size() > 1:
			for e in seen[k]:
				e["status"] = "doubt"
				e["note"] = "Otro club del CSV quedó en el mismo club del juego: revisá cuál es."
	return out


static func _plan_entry(e: Dictionary, of: OptionFile) -> void:
	var kind := String(e["kind"])
	if kind == "free" or kind == "nation_only":
		e["status"] = "match"
		e["choice"] = FREE
		e["note"] = "Sin club: van a la lista de jugadores libres." if kind == "free" \
			else "Convocados sin club: quedan libres (y en su selección)."
		return
	var league := String(e["division_name"])
	var scope := ""
	if kind == "league":
		var where := ClubImporter.find_division(league)
		if where.is_empty():
			var nl: Array = NEW_LEAGUES.get(normalize(league), [])
			if not nl.is_empty():
				where = [nl[0], nl[2]]
				e["new_division"] = nl
		if not where.is_empty():
			e["country"] = where[0]
			e["division"] = where[1]
			scope = where[0]
	elif kind == "youth":
		var w := _has_word(normalize(league), YOUTH_COUNTRY.keys())
		scope = String(YOUTH_COUNTRY.get(w, ""))
	var in_league := kind == "league" and String(e["division"]) != ""
	var cands := club_candidates(String(e["name"]), scope, of)
	# Lo que elegiste en otra importación.
	var alias := String(of.club_alias.get(ClubImporter.norm(String(e["name"])), "")) if of != null else ""
	if alias != "":
		var ap := alias.split(":")
		var chosen := cands.filter(func(c: Dictionary) -> bool: return c["country"] == ap[0] and c["id"] == ap[1])
		if chosen.is_empty() and (scope == "" or ap[0] == scope):
			var found := TeamDB.club(ap[0], ap[1])
			if not found.is_empty():
				chosen = [{"id": ap[1], "name": String(found[0]["name"]), "stadium": "", "division": String(found[1]["name"]),
					"division_id": String(found[1]["id"]), "country": ap[0], "exact": true}]
		if not chosen.is_empty():
			cands = chosen
			e["note"] = "Como la última vez."
	e["candidates"] = cands
	var pick := {}
	if cands.size() == 1:
		pick = cands[0]
	elif cands.size() > 1:
		# Varios parecidos: el que ya jugaba en esa división, o el de nombre exacto.
		var same := cands.filter(func(c: Dictionary) -> bool: return in_league and c["division_id"] == e["division"])
		var exact := cands.filter(func(c: Dictionary) -> bool: return c["exact"])
		if same.size() == 1:
			pick = same[0]
		elif exact.size() == 1:
			pick = exact[0]
	if not pick.is_empty():
		e["status"] = "match"
		e["choice"] = String(pick["id"]) if in_league else "%s:%s" % [pick["country"], pick["id"]]
		return
	if cands.size() > 1:
		e["status"] = "doubt"
		e["choice"] = ""
		e["note"] = "Hay %d clubes parecidos: elegí cuál." % cands.size()
		return
	if in_league:
		var nd: Array = e["new_division"]
		e["status"] = "new"
		e["choice"] = ClubImporter.NEW
		e["note"] = ("Club nuevo en %s. Se crea la liga." % nd[3]) if not nd.is_empty() else "Club nuevo en %s." % league
		return
	e["status"] = "skip"
	e["choice"] = ClubImporter.SKIP
	if kind == "national":
		e["status"] = "match"
		e["choice"] = FREE
		e["note"] = "El club no está en el juego: queda libre (y en su selección)."
		return
	match kind:
		"youth": e["note"] = "El club no está en el juego: su Sub-20 no se importa."
		_: e["note"] = "La liga \"%s\" no está en el juego." % league


## Opciones del desplegable de una entrada: [valor, texto].
static func plan_options(e: Dictionary) -> Array:
	var out: Array = []
	if e["choice"] == "":
		out.append(["", "— Elegí el club —"])
	if e["kind"] in ["free", "nation_only", "national"]:
		out.append([FREE, "Lista de jugadores libres"])
	var in_league: bool = e["kind"] == "league" and String(e["division"]) != ""
	for c in e["candidates"]:
		var where := String(c["division"]) if String(c["division"]) != "" else String(c["country"]).to_upper()
		out.append([String(c["id"]) if in_league else "%s:%s" % [c["country"], c["id"]], "%s (%s)" % [c["name"], where]])
	if in_league:
		out.append([ClubImporter.NEW, "Club nuevo: " + String(e["name"])])
	out.append([ClubImporter.SKIP, "No importar"])
	return out


## Elige un club del juego para una entrada, aunque no estuviera entre los
## candidatos (búsqueda del editor). En las de liga tiene que ser del país de
## la liga.
static func plan_pick(e: Dictionary, country_id: String, club_id: String) -> void:
	var in_league: bool = e["kind"] == "league" and String(e["division"]) != ""
	if in_league and country_id != String(e["country"]):
		return
	var found := TeamDB.club(country_id, club_id)
	var div: Dictionary = found[1] if not found.is_empty() else {}
	var c := {"id": club_id, "name": String(found[0]["name"]) if not found.is_empty() else club_id, "stadium": "",
		"division": String(div.get("name", "")), "division_id": String(div.get("id", "")), "country": country_id,
		"exact": true}
	if not (e["candidates"] as Array).any(func(x: Dictionary) -> bool: return x["country"] == country_id and x["id"] == club_id):
		e["candidates"].append(c)
	e["choice"] = club_id if in_league else "%s:%s" % [country_id, club_id]


static func _ensure_division(nl: Array, of: OptionFile) -> void:
	var cid := String(nl[0])
	if TeamDB.country(cid).is_empty():
		var nat := TeamDB.nation(cid)
		if nat.is_empty():
			nat = NationCatalog.entry(cid)
		of.add_country({"id": cid, "name": nl[1], "nationality": cid, "names": String(nat.get("names", "en")),
			"skin": nat.get("skin", [40, 30, 18, 12])})
	var exists := false
	for d in TeamDB.country(cid).get("divisions", []):
		exists = exists or d["id"] == nl[2]
	if not exists:
		of.add_division(cid, {"id": nl[2], "name": nl[3], "level": int(nl[4]), "season": "2026"})
	TeamDB.use_option_file(of)


## Aplica la propuesta revisada al Option File `of` (no lo guarda): crea
## países, ligas y clubes, arma las divisiones de las ligas del CSV, reparte
## los jugadores (primer equipo, Sub-20, libres) y arma las selecciones.
func apply_plan(plan: Array, rows: Array[Dictionary], of: OptionFile) -> Dictionary:
	report.clear()
	TeamDB.use_option_file(of)
	for e in plan:
		var ch := String(e["choice"])
		if e["kind"] == "league" and not (e["new_division"] as Array).is_empty() and ch != "" and ch != ClubImporter.SKIP:
			_ensure_division(e["new_division"], of)
	var league_entries := plan.filter(func(e: Dictionary) -> bool:
		return e["kind"] == "league" and String(e["division"]) != "")
	var res_clubs := ClubImporter.apply(league_entries, of, false)
	# Destino de cada entrada.
	var dest := {}
	for e in plan:
		var ch := String(e["choice"])
		if ch == "" or ch == ClubImporter.SKIP:
			continue
		if ch == FREE:
			dest[e["key"]] = FREE
			continue
		var where: Array = []
		if e["kind"] == "league" and String(e["division"]) != "":
			where = [String(e["country"]), String(e.get("applied_id", ""))]
		else:
			where = Array(ch.split(":"))
		if where.size() == 2 and String(where[1]) != "":
			dest[e["key"]] = where
			of.club_alias[ClubImporter.norm(String(e["name"]))] = "%s:%s" % where
	TeamDB.use_option_file(of)
	# Jugadores.
	var first := {}
	var youth := {}
	var free: Array = []
	var by_nation := {}
	var marked_nation := {}
	var unmatched := {}
	var full := {} # clubes con su lista completa (no sólo convocados)
	for row in rows:
		var p := to_player(row)
		if String(p["n"]) == "":
			continue
		var club := field(row, "club")
		var kind := row_kind(club, field(row, "league"))
		var nat_id := nation_id_of(String(p.get("nat", "")))
		if nat_id != "":
			p["nat"] = nation_name(nat_id, String(p.get("nat", "")))
			if kind != "youth":
				by_nation.get_or_add(nat_id, []).append(p)
		var nt := nation_id_of(field(row, "national_team"))
		if nt != "":
			marked_nation.get_or_add(nt, []).append(p)
		var key := _row_key(kind, club, field(row, "league"))
		if not dest.has(key):
			unmatched[club] = int(unmatched.get(club, 0)) + 1
			continue
		if dest[key] is String:
			free.append(p)
			continue
		var target: Dictionary = youth if kind == "youth" else first
		if kind == "league":
			full["%s:%s" % dest[key]] = true
		var squad: Dictionary = target.get_or_add("%s:%s" % dest[key], {})
		var pn := normalize(String(p["n"]))
		if not squad.has(pn) or player_score(p) > player_score(squad[pn]):
			squad[pn] = p
	# Planteles: la lista de cada club es la del CSV (hasta 40). Si al club
	# sólo le llegaron convocados, se suman a los que ya tenía.
	var players_total := 0
	var touched := {}
	for k in first.keys() + youth.keys():
		touched[k] = true
	for k in touched:
		var parts := String(k).split(":")
		var found := TeamDB.club(parts[0], parts[1])
		if found.is_empty():
			continue
		var entry: Dictionary = (found[0] as Dictionary).duplicate(true)
		if first.has(k):
			var list: Array = (first[k] as Dictionary).values()
			if full.has(k) or not (entry.get("players", []) as Array).is_empty():
				if not full.has(k):
					list = _merge_into(entry, list, "")
				entry["players"] = pick_squad(list, TeamDB.CLUB_SQUAD_MAX, [2, 6, 6, 3])
			else:
				entry["players"] = _merge_into(entry, list, TeamDB.club_path(parts[0], parts[1]))
			players_total += (entry["players"] as Array).size()
		if youth.has(k):
			entry["youth"] = pick_squad((youth[k] as Dictionary).values(), TeamDB.CLUB_SQUAD_MAX, [2, 4, 4, 2])
		of.set_club(parts[0], entry)
	# Libres (sin repetir nombres).
	var free_names := {}
	for p in of.free_agents:
		free_names[normalize(String(p["n"]))] = true
	for p in free:
		if not free_names.has(normalize(String(p["n"]))):
			free_names[normalize(String(p["n"]))] = true
			of.free_agents.append(p)
	TeamDB.use_option_file(of)
	var nat_res := _apply_nations(by_nation, marked_nation, of)
	TeamDB.use_option_file(of)
	var created_nations: Array = nat_res[1]
	var total_unmatched := 0
	for k in unmatched:
		total_unmatched += int(unmatched[k])
	report.append("Clubes: %d con plantel, %d nuevos; %d divisiones armadas con lo del CSV." % [
		first.size(), res_clubs["new"], res_clubs["divisions"]])
	if not youth.is_empty():
		report.append("Sub-20: %d clubes." % youth.size())
	if not free.is_empty():
		report.append("Libres: %d jugadores (en total %d)." % [free.size(), of.free_agents.size()])
	if not created_nations.is_empty():
		report.append("Selecciones nuevas: %s." % ", ".join(created_nations))
	if total_unmatched > 0:
		report.append("No importados: %d jugadores de %d clubes que quedaron en \"No importar\" (siguen en sus selecciones)." % [
			total_unmatched, unmatched.size()])
	return {"rows": rows.size(), "players": players_total, "clubs": first.size(), "youth": youth.size(),
		"free": free.size(), "nations": int(nat_res[0]), "new_nations": created_nations.size(),
		"new_clubs": int(res_clubs["new"]), "unmatched": total_unmatched, "unmatched_clubs": unmatched.size()}


## Jugadores que llegan a un club sin su lista completa (convocados): se suman
## a los que tenía o, si el plantel era generado (`path`), van primero (los
## mejores adelante) y se completa con generados hasta 23 (primero los puestos
## que falten).
static func _merge_into(entry: Dictionary, incoming: Array, path: String) -> Array:
	var had: Array = entry.get("players", [])
	var generated := had.is_empty()
	if generated:
		for p in TeamDB.load_team(path).players:
			had.append(TeamDB.player_to_dict(p))
	var out: Array = pick_squad(incoming, TeamDB.CLUB_SQUAD_MAX, [0, 0, 0, 0]) if generated else incoming.duplicate()
	var names := {}
	var by_line := [0, 0, 0, 0]
	for p in out:
		names[normalize(String(p["n"]))] = true
		by_line[line_of(p)] += 1
	var rest := had.filter(func(p: Dictionary) -> bool: return not names.has(normalize(String(p["n"]))))
	if not generated:
		return out + rest
	var need := [2, 6, 6, 3]
	for p in rest.duplicate():
		var l := line_of(p)
		if by_line[l] < need[l]:
			by_line[l] += 1
			out.append(p)
			rest.erase(p)
	for p in rest:
		if out.size() >= TeamDB.MATCH_SQUAD:
			break
		out.append(p)
	return out


## Id de selección (base o catálogo) de un nombre de país en castellano o inglés.
static func nation_id_of(name: String) -> String:
	var n := normalize(name)
	if n == "":
		return ""
	if NATION_ALIASES.has(n):
		return String(NATION_ALIASES[n])
	for nat in TeamDB.nations():
		if normalize(String(nat["name"])) == n or String(nat["id"]) == n:
			return String(nat["id"])
	return NationCatalog.id_of(n)


static func nation_name(id: String, fallback: String) -> String:
	var nat := TeamDB.nation(id)
	if nat.is_empty():
		nat = NationCatalog.entry(id)
	return String(nat.get("name", fallback))


## Selecciones: los convocados marcados o los mejores 23 de cada país. Las que
## no están en la base y tienen al menos 16 jugadores se crean del catálogo.
## Devuelve [cuántas se armaron, nombres de las nuevas].
static func _apply_nations(by_nation: Dictionary, marked_nation: Dictionary, of: OptionFile) -> Array:
	var count := 0
	var created: Array = []
	var ids := {}
	for k in by_nation:
		ids[k] = true
	for k in marked_nation:
		ids[k] = true
	for id in ids:
		var pool: Array = marked_nation.get(id, by_nation.get(id, []))
		var n := TeamDB.nation(String(id))
		if n.is_empty():
			if pool.size() < 16:
				continue
			n = NationCatalog.entry(String(id))
			if n.is_empty():
				continue
			created.append(String(n["name"]))
		if pool.size() < 11:
			continue
		var entry := n.duplicate(true)
		entry["players"] = pick_squad(pool, TeamDB.MATCH_SQUAD, [3, 8, 7, 5])
		of.set_nation(entry)
		count += 1
	return [count, created]


static func _save_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo escribir " + path)
		return
	f.store_string(JSON.stringify(data, " ", false))
