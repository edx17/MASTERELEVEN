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
	"cape verde islands": "cpv", "congo dr": "cod", "dr congo": "cod", "rd del congo": "cod", "congo": "cod",
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


## Importa todos los CSV de una carpeta al Option File `of` (y lo guarda).
func import_folder(dir: String, of: OptionFile) -> Dictionary:
	var rows: Array[Dictionary] = []
	var files: Array[String] = []
	for f in UserData.files_in(dir, "csv"):
		var r := read_csv(f)
		if ClubImporter.is_club_list(r):
			continue # listas de clubes: van por ClubImporter
		files.append(f)
		rows.append_array(r)
	if rows.is_empty():
		report.clear()
		return {"files": 0, "rows": 0, "players": 0, "clubs": 0, "nations": 0, "unmatched": 0, "unmatched_clubs": 0}
	var res := import_rows(rows, of)
	res["files"] = files.size()
	of.save()
	return res


static func _save_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo escribir " + path)
		return
	f.store_string(JSON.stringify(data, " ", false))
