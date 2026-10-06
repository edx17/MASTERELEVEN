class_name EditorModel
extends RefCounted
## Lógica del Editor (sin interfaz): lee equipos y jugadores como datos
## editables (el formato de data/db), aplica los cambios al Option File y
## permite deshacer. La base del juego no se toca nunca.
##
## Un equipo se identifica con su ruta de TeamDB (db:club:arg:boca,
## db:nat:arg). Los Equipos WE (.tres) son de sólo lectura.
## Un jugador se identifica con [ruta del equipo, índice en el plantel].
## Las Sub-20 (inferiores) de un club se editan con su ruta de TeamDB
## (db:u20:club:arg:boca): su plantel es el "youth" de la entrada del club.

signal changed

## Tope por plantel: 40 en los clubes, 23 en las selecciones.
const MAX_SQUAD := TeamDB.CLUB_SQUAD_MAX
const MAX_NATION := TeamDB.MATCH_SQUAD


static func squad_cap(path: String) -> int:
	return MAX_NATION if path.begins_with("db:nat:") else MAX_SQUAD
const UNDO_LIMIT := 50

var option_file: OptionFile
var dirty := false
var _undo: Array = []
## Planteles ya convertidos a datos (ruta -> entrada del equipo con "players").
var _entries: Dictionary = {}


func _init(of: OptionFile = null) -> void:
	option_file = of if of != null else OptionFile.new()
	TeamDB.use_option_file(option_file)


static func editable(path: String) -> bool:
	return path.begins_with("db:")


## Entrada del equipo (copia editable) con el plantel en datos: si el equipo
## no tenía plantel cargado (generado), se fija el generado.
func entry(path: String) -> Dictionary:
	if TeamDB.is_u20(path):
		return _u20_entry(path)
	if _entries.has(path):
		return _entries[path]
	var parts := path.split(":")
	var e: Dictionary = {}
	if parts.size() == 3:
		e = TeamDB.nation(parts[2]).duplicate(true)
	elif parts.size() == 4:
		var c := TeamDB.club(parts[2], parts[3])
		if not c.is_empty():
			e = (c[0] as Dictionary).duplicate(true)
	if e.is_empty():
		return {}
	if not e.has("players") or (e["players"] as Array).is_empty():
		var t := TeamDB.load_team(path)
		var list: Array = []
		for p in t.players:
			list.append(TeamDB.player_to_dict(p))
		e["players"] = list
	_entries[path] = e
	return e


## Sub-20 de un club: {name, players} donde players es el "youth" de la
## entrada del club (el mismo Array: lo que se edita acá queda en el club).
## Si el club no tenía inferiores cargadas, se fijan las generadas.
func _u20_entry(path: String) -> Dictionary:
	var senior := "db:" + path.trim_prefix("db:u20:")
	if not senior.begins_with("db:club:"):
		return {}
	var e := entry(senior)
	if e.is_empty():
		return {}
	if (e.get("youth", []) as Array).is_empty():
		var list: Array = []
		var t := TeamDB.load_team(path)
		if t != null:
			for p in t.players:
				list.append(TeamDB.player_to_dict(p))
		e["youth"] = list
	var w: Dictionary = _entries.get_or_add(path, {})
	w["name"] = String(e.get("name", "")) + " Sub-20"
	w["players"] = e["youth"]
	w["senior"] = senior
	return w


func players(path: String) -> Array:
	var e := entry(path)
	return e.get("players", [])


func player(ref: Array) -> Dictionary:
	var list := players(ref[0])
	var i: int = ref[1]
	return list[i] if i >= 0 and i < list.size() else {}


## Valoración general de un jugador en datos (para la tabla).
static func overall(d: Dictionary) -> int:
	var a: Dictionary = d.get("a", {})
	if a.is_empty():
		return int(d.get("ovr", 0))
	if String(d.get("pos", "")) == "GK":
		return roundi((float(a.get("goalkeeping", 50)) * 2.0 + float(a.get("reaction", 50))) / 3.0)
	var keys := ["speed", "passing", "shooting", "technique", "ball_control", "defense", "stamina", "attack"]
	var total := 0.0
	for k in keys:
		total += float(a.get(k, 50))
	return roundi(total / keys.size())


# --- Cambios -----------------------------------------------------------------------

func _snapshot() -> void:
	_undo.append({"of": option_file.to_dict().duplicate(true), "entries": _entries.duplicate(true)})
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()


func can_undo() -> bool:
	return not _undo.is_empty()


func undo() -> void:
	if _undo.is_empty():
		return
	var s: Dictionary = _undo.pop_back()
	var keep_name := option_file.name
	option_file = OptionFile.from_dict(s["of"])
	option_file.name = keep_name
	_entries = s["entries"]
	TeamDB.use_option_file(option_file)
	dirty = true
	changed.emit()


## Pasa la entrada editada del equipo al Option File.
func _commit(path: String) -> void:
	if TeamDB.is_u20(path):
		_commit(String(_u20_entry(path)["senior"]))
		return
	var e: Dictionary = _entries[path]
	var parts := path.split(":")
	if parts.size() == 3:
		option_file.set_nation(e)
	else:
		option_file.set_club(parts[2], e)
	TeamDB.use_option_file(option_file)
	dirty = true


## Cambia campos de un jugador: {"n": ..., "num": ..., "a": {"speed": 80}, ...}.
func set_player(ref: Array, fields: Dictionary) -> void:
	if not editable(ref[0]):
		return
	_snapshot()
	_apply_fields(player(ref), fields)
	_commit(ref[0])
	changed.emit()


static func _apply_fields(d: Dictionary, fields: Dictionary) -> void:
	for k in fields:
		if k == "a":
			var a: Dictionary = d.get_or_add("a", {})
			for attr in fields["a"]:
				a[attr] = clampi(int(fields["a"][attr]), 1, 99)
		elif fields[k] == null:
			d.erase(k)
		else:
			d[k] = fields[k]


## Edición masiva: a cada jugador de `refs` le suma (op "+"), resta ("-") o
## fija ("=") `value` en el atributo `field` (o fija un campo del aspecto:
## boots, skin, ...; "pos", "ft", "nat").
func mass_edit(refs: Array, field: String, op: String, value: Variant) -> int:
	var touched := {}
	_snapshot()
	var n := 0
	for ref in refs:
		if not editable(ref[0]):
			continue
		var d := player(ref)
		if d.is_empty():
			continue
		if field in PlayerData.ATTRIBUTES:
			var a: Dictionary = d.get_or_add("a", {})
			var cur := int(a.get(field, 50))
			var v := int(value)
			a[field] = clampi(cur + v if op == "+" else (cur - v if op == "-" else v), 1, 99)
		else:
			d[field] = value
		touched[ref[0]] = true
		n += 1
	for path in touched:
		_commit(path)
	if n == 0:
		_undo.pop_back()
	changed.emit()
	return n


## Alta: un jugador nuevo al final del plantel (si hay lugar). Devuelve su ref.
func add_player(path: String, d: Dictionary = {}) -> Array:
	if not editable(path) or players(path).size() >= squad_cap(path):
		return []
	_snapshot()
	var list := players(path)
	var used := {}
	for p in list:
		used[int(p.get("num", 0))] = true
	var num := 1
	while used.has(num):
		num += 1
	var nd := {"n": "Jugador Nuevo", "num": num, "pos": "CMF", "ft": "R", "h": 178, "age": 22, "nat": "",
		"a": {}}
	for attr in PlayerData.ATTRIBUTES:
		nd["a"][attr] = 25 if attr == "goalkeeping" else 60
	nd.merge(d, true)
	list.append(nd)
	_commit(path)
	changed.emit()
	return [path, list.size() - 1]


## Baja: lo saca del plantel (devuelve sus datos).
func remove_player(ref: Array) -> Dictionary:
	if not editable(ref[0]):
		return {}
	var list := players(ref[0])
	var i: int = ref[1]
	if i < 0 or i >= list.size():
		return {}
	_snapshot()
	var d: Dictionary = list[i]
	list.remove_at(i)
	_commit(ref[0])
	changed.emit()
	return d


## Pase: lo lleva de un equipo a otro (con otro dorsal si el suyo está
## ocupado). Devuelve la ref nueva o [] si no hay lugar.
func transfer(ref: Array, dest: String) -> Array:
	if not editable(ref[0]) or not editable(dest) or ref[0] == dest or players(dest).size() >= squad_cap(dest):
		return []
	_snapshot()
	var src := players(ref[0])
	var d: Dictionary = src[ref[1]]
	src.remove_at(ref[1])
	var list := players(dest)
	var used := {}
	for p in list:
		used[int(p.get("num", 0))] = true
	var num := int(d.get("num", 1))
	while used.has(num):
		num = num % 99 + 1
	d["num"] = num
	list.append(d)
	_commit(ref[0])
	_commit(dest)
	changed.emit()
	return [dest, list.size() - 1]


## Cambia el orden del plantel (los 11 primeros son los titulares).
func move_player(ref: Array, delta: int) -> Array:
	var list := players(ref[0])
	var j: int = ref[1] + delta
	if not editable(ref[0]) or j < 0 or j >= list.size():
		return ref
	_snapshot()
	var tmp = list[ref[1]]
	list[ref[1]] = list[j]
	list[j] = tmp
	_commit(ref[0])
	changed.emit()
	return [ref[0], j]


## Datos del equipo (nombre, sigla, estadio, formación, camisetas...).
func set_team(path: String, fields: Dictionary) -> void:
	if not editable(path):
		return
	_snapshot()
	var e := entry(path)
	for k in fields:
		e[k] = fields[k]
	_commit(path)
	changed.emit()


func save() -> bool:
	var ok := option_file.save()
	if ok:
		dirty = false
	return ok


## Busca jugadores en una lista de equipos: [{ref, d, team}] filtrados por
## texto (nombre), puesto general (-1 = todos) y nacionalidad ("" = todas).
func search(paths: Array, text: String = "", line: int = -1, nat: String = "") -> Array:
	var out: Array = []
	var q := SquadImporter.normalize(text)
	for path in paths:
		var e := entry(path)
		if e.is_empty():
			continue
		var list: Array = e.get("players", [])
		for i in list.size():
			var d: Dictionary = list[i]
			if q != "" and not SquadImporter.normalize(String(d.get("n", ""))).contains(q):
				continue
			if line >= 0 and TeamDB.position_of_code(String(d.get("pos", "CMF"))) != line:
				continue
			if nat != "" and SquadImporter.normalize(String(d.get("nat", ""))) != SquadImporter.normalize(nat):
				continue
			out.append({"ref": [path, i], "d": d, "team": String(e.get("name", ""))})
	return out


# --- Selecciones (E3) -------------------------------------------------------------

## Convoca a un jugador (copia de sus datos) a una selección.
func call_up(nation_path: String, d: Dictionary) -> Array:
	if not nation_path.begins_with("db:nat:") or players(nation_path).size() >= MAX_NATION:
		return []
	_snapshot()
	var list := players(nation_path)
	var nd := d.duplicate(true)
	var used := {}
	for p in list:
		used[int(p.get("num", 0))] = true
	var num := int(nd.get("num", 1))
	while used.has(num):
		num = num % 99 + 1
	nd["num"] = num
	list.append(nd)
	_commit(nation_path)
	changed.emit()
	return [nation_path, list.size() - 1]


## Selección nueva (con un plantel generado de nivel medio). Devuelve su ruta.
func new_nation(name: String, short: String) -> String:
	var id := _free_id(_slug(short if short != "" else name), func(x: String) -> bool: return not TeamDB.nation(x).is_empty())
	_snapshot()
	var e := {"id": id, "name": name, "short": short.to_upper().substr(0, 3), "conf": "", "wc": "", "level": 65,
		"names": "en", "skin": [40, 30, 18, 12], "formation": "4-4-2", "flag": {"t": "h", "c": ["ffffff", "1a3e8f", "ffffff"]},
		"home": "ffffff/1a3e8f/ffffff", "away": "1a3e8f/1a3e8f/1a3e8f", "keeper": "1a1a1a"}
	option_file.set_nation(e)
	TeamDB.use_option_file(option_file)
	_entries.erase(TeamDB.nation_path(id))
	dirty = true
	changed.emit()
	return TeamDB.nation_path(id)


func delete_nation(path: String) -> void:
	var id := path.get_slice(":", 2)
	if id == "":
		return
	_snapshot()
	option_file.nations.erase(id)
	if not option_file.deleted_nations.has(id):
		option_file.deleted_nations.append(id)
	_entries.erase(path)
	TeamDB.use_option_file(option_file)
	dirty = true
	changed.emit()


# --- Ligas (E3) ---------------------------------------------------------------------

## Ids de clubes de una división (con los cambios del Option File).
func division_ids(country_id: String, division_id: String) -> Array:
	var out: Array = []
	for p in TeamDB.division_paths(country_id, division_id):
		out.append(p.get_slice(":", 3))
	return out


## Pasa un club de una división a otra del mismo país.
func move_club(country_id: String, from_div: String, to_div: String, club_id: String) -> void:
	if from_div == to_div:
		return
	_snapshot()
	var a := division_ids(country_id, from_div)
	var b := division_ids(country_id, to_div)
	a.erase(club_id)
	if not b.has(club_id):
		b.append(club_id)
	option_file.set_division(country_id, from_div, a)
	option_file.set_division(country_id, to_div, b)
	TeamDB.use_option_file(option_file)
	dirty = true
	changed.emit()


## Club nuevo en una división (colores lisos, estadio vacío; plantel
## generado según la división). Devuelve su ruta.
func new_club(country_id: String, division_id: String, name: String, short: String) -> String:
	var all := {}
	for d in TeamDB.country(country_id).get("divisions", []):
		for cl in d["clubs"]:
			all[String(cl["id"])] = true
	for key in option_file.clubs:
		all[String(key).get_slice(":", 1)] = true
	var id := _free_id(_slug(name), func(x: String) -> bool: return all.has(x))
	_snapshot()
	var e := {"id": id, "name": name, "short": short.to_upper().substr(0, 3) if short != "" else name.substr(0, 3).to_upper(),
		"home": "ffffff/101820/ffffff", "away": "101820/101820/101820", "stadium": "", "cap": 0}
	option_file.set_club(country_id, e)
	var ids := division_ids(country_id, division_id)
	ids.append(id)
	option_file.set_division(country_id, division_id, ids)
	TeamDB.use_option_file(option_file)
	dirty = true
	changed.emit()
	return TeamDB.club_path(country_id, id)


## Saca un club de su división (deja de jugar en esa liga; sus datos quedan).
func remove_club(country_id: String, division_id: String, club_id: String) -> void:
	_snapshot()
	var ids := division_ids(country_id, division_id)
	ids.erase(club_id)
	option_file.set_division(country_id, division_id, ids)
	TeamDB.use_option_file(option_file)
	dirty = true
	changed.emit()


## Cuántos clubes bajan de esa división a la de abajo (y suben de la de
## abajo) en la Liga Master.
func set_relegation(country_id: String, division_id: String, n: int) -> void:
	_snapshot()
	option_file.set_relegation(country_id, division_id, n)
	TeamDB.use_option_file(option_file)
	dirty = true
	changed.emit()


## Aplica una lista de clubes revisada (ClubImporter.analyze); se puede deshacer.
func import_clubs(plan: Array, stadiums: bool = true) -> Dictionary:
	_snapshot()
	var res := ClubImporter.apply(plan, option_file, stadiums)
	dirty = true
	changed.emit()
	return res


## Importa planteles con la propuesta revisada (SquadImporter.plan_rows); se
## puede deshacer.
func import_squads(plan: Array, rows: Array[Dictionary], imp: SquadImporter) -> Dictionary:
	_snapshot()
	var res := imp.apply_plan(plan, rows, option_file)
	_entries.clear()
	TeamDB.use_option_file(option_file)
	dirty = true
	changed.emit()
	return res


# --- Copas propias (E3) -------------------------------------------------------------

## Copa nueva: format "knockout" (8 o 16 equipos) o "league" (todos contra
## todos). Devuelve su índice.
func add_cup(name: String, format: String, teams: Array) -> int:
	_snapshot()
	var ids := {}
	for c in option_file.cups:
		ids[String(c.get("id", ""))] = true
	var id := _free_id(_slug(name), func(x: String) -> bool: return ids.has(x))
	option_file.cups.append({"id": id, "name": name, "format": format, "teams": teams.duplicate()})
	dirty = true
	changed.emit()
	return option_file.cups.size() - 1


func set_cup(i: int, fields: Dictionary) -> void:
	if i < 0 or i >= option_file.cups.size():
		return
	_snapshot()
	(option_file.cups[i] as Dictionary).merge(fields, true)
	dirty = true
	changed.emit()


func remove_cup(i: int) -> void:
	if i < 0 or i >= option_file.cups.size():
		return
	_snapshot()
	option_file.cups.remove_at(i)
	dirty = true
	changed.emit()


## ¿La copa se puede jugar? (eliminación: 4, 8, 16 o 32 equipos; liga: 3 a 40).
static func cup_valid(c: Dictionary) -> String:
	var n := (c.get("teams", []) as Array).size()
	if String(c.get("format", "knockout")) == "knockout":
		return "" if n in [4, 8, 16, 32] else "La eliminación directa necesita 4, 8, 16 o 32 equipos (hay %d)." % n
	return "" if n >= 3 and n <= 40 else "La liga necesita entre 3 y 40 equipos (hay %d)." % n


static func _slug(s: String) -> String:
	var t := SquadImporter.normalize(s)
	var out := ""
	for ch in t:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out.substr(0, 16) if out != "" else "nuevo"


static func _free_id(base: String, taken: Callable) -> String:
	var id := base
	var n := 2
	while taken.call(id):
		id = "%s%d" % [base, n]
		n += 1
	return id
