extends Node
## Arma la base de futsal AFA (data/futsal_afa) desde tools/db_src/futsal_afa/equipos.csv
## (league_name, zona, posicion, equipo, overall, ovr_min_plantel, ovr_max_plantel, perfil):
##   godot --headless -- --build-futsal-db
##
##   - Divisiones: Primera A, B, C y D (Zona 1 y Zona 2), en el orden de la tabla.
##   - Cada club: id único, camisetas de su club de fútbol si está en la base
##     (Boca, River...), si no colores propios; estadio "Microestadio".
##   - Plantel generado de 14 (2 arqueros): titulares cerca del overall del
##     club y el resto entre el mínimo y el máximo del CSV; cada jugador con su
##     pid único (estable: mismo club y dorsal, mismo pid).

const SRC := "res://tools/db_src/futsal_afa/equipos.csv"
const OUT := "res://data/futsal_afa/"
const SEASON := "2026"
## Liga del CSV -> [id de división, nombre, nivel].
const DIVISIONS := {
	"Futsal AFA Primera A": ["futA", "Primera A", 1],
	"Futsal AFA Primera B": ["futB", "Primera B", 2],
	"Futsal AFA Primera C": ["futC", "Primera C", 3],
	"Futsal AFA Primera D|Zona 1": ["futD1", "Primera D · Zona 1", 4],
	"Futsal AFA Primera D|Zona 2": ["futD2", "Primera D · Zona 2", 4],
}
## Colores para los clubes que no están en la base de fútbol.
const PALETTE := ["d71920", "0a2a6e", "00843d", "f5c400", "6a1b9a", "ff6f00", "00838f", "37474f", "c2185b", "1565c0",
	"2e7d32", "8d6e63", "ad1457", "283593", "00695c", "ef6c00"]

var report: Array[String] = []


func _ready() -> void:
	var menu := get_tree().current_scene
	if menu != null:
		menu.queue_free()
	_run.call_deferred()


func _run() -> void:
	var ok := build(ProjectSettings.globalize_path(SRC), ProjectSettings.globalize_path(OUT))
	for line in report:
		print(line)
	get_tree().quit(0 if ok else 1)


func build(src: String, out: String) -> bool:
	report.clear()
	TeamDB.use_db(TeamDB.DEFAULT_DB)
	var football := _football_clubs()
	Discipline.use(Discipline.FUTSAL)
	var rows := SquadImporter.read_csv(src)
	if rows.is_empty():
		report.append("No se pudo leer " + src)
		Discipline.use(Discipline.FOOTBALL)
		return false
	var divisions := {}
	var order: Array = []
	var taken := {}
	for row in rows:
		var key := String(row.get("league_name", ""))
		if String(row.get("zona", "")) != "":
			key += "|" + String(row["zona"])
		if not DIVISIONS.has(key):
			report.append("Liga desconocida: " + key)
			continue
		var dv: Array = DIVISIONS[key]
		if not divisions.has(dv[0]):
			divisions[dv[0]] = {"id": dv[0], "name": dv[1], "level": dv[2], "season": SEASON, "clubs": [],
				"down": {"futA": 2, "futB": 2, "futC": 3}.get(dv[0], 0)}
			order.append(dv[0])
		var name := String(row.get("equipo", ""))
		var id := EditorModel._free_id(EditorModel._slug(name), func(x: String) -> bool: return taken.has(x))
		taken[id] = true
		var club := {"id": id, "name": name, "short": name.substr(0, 3).to_upper(),
			"stadium": "Microestadio " + name, "cap": 800 + int(row.get("overall", 50)) * 25,
			"ovr": int(row.get("overall", 60)), "ovr_min": int(row.get("ovr_min_plantel", 50)),
			"ovr_max": int(row.get("ovr_max_plantel", 70)), "profile": String(row.get("perfil", ""))}
		var fb := _football_club(football, name)
		if not fb.is_empty():
			for k in ["home", "away", "short", "keeper"]:
				if fb.has(k):
					club[k] = fb[k]
		else:
			var c1: String = PALETTE[absi(hash(name)) % PALETTE.size()]
			club["home"] = "%s/ffffff/%s" % [c1, c1]
			club["away"] = "ffffff/%s/ffffff" % c1
		club["formation"] = "1-2-1"
		divisions[dv[0]]["clubs"].append(club)
	# Planteles con pid único.
	var pid := 1
	for did in order:
		for club in divisions[did]["clubs"]:
			club["players"] = _roster(club, pid)
			pid += (club["players"] as Array).size()
			for k in ["ovr", "ovr_min", "ovr_max", "profile"]:
				club.erase(k)
	var country := {"id": "arg", "name": "Argentina", "nationality": "arg", "names": "es_ar", "skin": [55, 40, 4, 1],
		"divisions": order.map(func(d: String) -> Dictionary: return divisions[d])}
	DirAccess.make_dir_recursive_absolute(out.path_join("leagues"))
	_save(out.path_join("leagues/arg.json"), country)
	_save(out.path_join("nations.json"), {"season": SEASON, "nations": []})
	_save(out.path_join(TeamDB.EXTERNAL_FILE), {"season": SEASON, "players": []})
	var comps: Array = order.map(func(d: String) -> Dictionary:
		return {"id": d, "name": divisions[d]["name"], "kind": "league", "country": "arg", "level": divisions[d]["level"]})
	comps.append({"id": "fut_super", "name": "Supercopa", "kind": "supercup"})
	_save(out.path_join("competitions.json"), {"season": SEASON, "competitions": comps})
	var clubs := 0
	for d in order:
		clubs += (divisions[d]["clubs"] as Array).size()
	_save(out.path_join("meta.json"), {"id": "futsal_afa", "name": "AFA Futsal", "discipline": Discipline.FUTSAL,
		"season": SEASON, "players": pid - 1, "clubs": clubs, "nations": 0, "competitions": comps.size()})
	report.push_front("AFA Futsal: %d clubes en %d divisiones, %d jugadores." % [clubs, order.size(), pid - 1])
	Discipline.use(Discipline.FOOTBALL)
	TeamDB.reload()
	return true


## Clubes de la base de fútbol por nombre normalizado (para las camisetas).
static func _football_clubs() -> Dictionary:
	var out := {}
	for c in TeamDB.countries():
		if c["id"] != "arg":
			continue
		for d in c["divisions"]:
			for cl in d["clubs"]:
				out[SquadImporter.normalize(String(cl["name"]))] = cl
	# Nombres del futsal que en fútbol se escriben distinto.
	for pair in [["river plate", "river"], ["velez sarsfield", "velez"], ["gimnasia (lp)", "gimnasia y esgrima la plata"],
			["ferro", "ferro carril oeste"], ["newell's", "newell's old boys"], ["estudiantes (lp)", "estudiantes de la plata"]]:
		for k in out.keys():
			if String(k) == pair[1] or String(k).begins_with(pair[1]):
				out[pair[0]] = out[k]
	return out


## El club de fútbol de un nombre de futsal: igual, o el que empieza con ese
## nombre ("Boca" -> "Boca Juniors", "Lanús" -> "Lanús").
static func _football_club(football: Dictionary, name: String) -> Dictionary:
	var key := SquadImporter.normalize(name)
	if football.has(key):
		return football[key]
	var best := ""
	for k in football.keys():
		if String(k).begins_with(key + " ") and (best == "" or String(k).length() < best.length()):
			best = k
	return football[best] if best != "" else {}


## 14 jugadores (2 arqueros) alrededor del overall del club.
static func _roster(club: Dictionary, first_pid: int) -> Array:
	var t := TeamData.new()
	t.id = "fut_" + String(club["id"])
	t.formation = load(Discipline.formation_path("1-2-1"))
	var lo := int(club["ovr_min"])
	var hi := int(club["ovr_max"])
	TeamDB.generate_roster(t, int(club["ovr"]), "es_ar", [55, 40, 4, 1], "Argentina", hash(t.id))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(t.id) + 3
	var out: Array = []
	for i in t.players.size():
		var p := t.players[i]
		p.age = rng.randi_range(19, 35)
		p.height = rng.randi_range(166, 190) if p.position != PlayerData.Position.GK else rng.randi_range(178, 194)
		var d := TeamDB.player_to_dict(p)
		# Overall pedido: los titulares cerca del del club, el resto entre el
		# mínimo y el máximo del plantel.
		var target := clampi(int(club["ovr"]) + rng.randi_range(-2, 3), lo, hi) if i < 5 else rng.randi_range(lo, hi - 2)
		_shift_to(d, target)
		d["pid"] = first_pid + i
		out.append(d)
	return out


## Corre los atributos para que el promedio quede en `target`.
static func _shift_to(d: Dictionary, target: int) -> void:
	var a: Dictionary = d["a"]
	var now := TeamDB.overall(TeamDB.player_from_dict(d, "x", 0))
	var delta := roundi(target - now)
	for k in a:
		if k == "goalkeeping" and String(d.get("pos", "")) != "GK":
			continue
		a[k] = clampi(int(a[k]) + delta, 20, 97)


static func _save(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo escribir " + path)
		return
	f.store_string(JSON.stringify(data, " ", false))
