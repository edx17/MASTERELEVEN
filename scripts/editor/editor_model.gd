class_name EditorModel
extends RefCounted
## Lógica del Editor (sin interfaz): lee equipos y jugadores como datos
## editables (el formato de data/db), aplica los cambios al Option File y
## permite deshacer. La base del juego no se toca nunca.
##
## Un equipo se identifica con su ruta de TeamDB (db:club:arg:boca,
## db:nat:arg). Los Equipos WE (.tres) son de sólo lectura.
## Un jugador se identifica con [ruta del equipo, índice en el plantel].

signal changed

const MAX_SQUAD := 23
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
	if not editable(path) or players(path).size() >= MAX_SQUAD:
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
	if not editable(ref[0]) or not editable(dest) or ref[0] == dest or players(dest).size() >= MAX_SQUAD:
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
