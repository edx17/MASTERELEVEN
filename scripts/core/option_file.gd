class_name OptionFile
extends RefCounted
## Option File (como en el PES): los cambios del jugador sobre la base del
## juego (data/db). La base no se toca nunca; el Option File activo se
## aplica encima al cargar (TeamDB). Se guarda como JSON legible en
## Documentos/VirtualEleven/optionfiles/<nombre>.veof y se puede copiar a
## otra PC o compartir.
##
## Contenido (todo opcional):
##   nations:   {id: entrada completa}         selecciones editadas o nuevas
##   clubs:     {"pais:id": entrada completa}  clubes editados o nuevos
##   divisions: {"pais:division": [ids]}       qué clubes juegan cada división
##   deleted_nations: [ids]                    selecciones borradas
##   rules:     {"pais:division": {"down": n}}  cuántos bajan (Liga Virtual)
##   cups:      [{id, name, format, teams}]    copas propias (format "knockout"
##              o "league"; teams = rutas de TeamDB)
##   countries: {id: {id, name, nationality, names, skin}}  países nuevos
##   new_divisions: {"pais": [{id, name, level}]}  divisiones nuevas (de un
##              país de la base o nuevo); sus clubes van en `divisions`
##   club_alias: {nombre normalizado: "pais:id"}  cómo se llama cada club en
##              los CSV importados (lo que elegiste al revisar)
##   free_agents: [jugadores]                 libres (sin club) importados
##   db:        base del juego sobre la que se hizo (TeamDB.DBS); sólo se
##              usa con esa base
## Las entradas tienen el mismo formato que data/db (ver docs/BASE_DE_DATOS.md).

const FORMAT := "VirtualEleven OptionFile"
## Los de cuando el juego se llamaba Master Eleven se siguen leyendo.
const OLD_FORMATS := ["MasterEleven OptionFile"]
const VERSION := 1
const EXT := "veof"
const OLD_EXT := "meof"

var name := "Mi Option File"
var created := ""
var updated := ""
var nations: Dictionary = {}
var clubs: Dictionary = {}
var divisions: Dictionary = {}
var deleted_nations: Array = []
var cups: Array = []
var rules: Dictionary = {}
var countries: Dictionary = {}
var new_divisions: Dictionary = {}
var club_alias: Dictionary = {}
var free_agents: Array = []
## Base del juego (TeamDB.DBS) de este Option File.
var db := TeamDB.db_id


## Carpeta con las plantillas de camisetas de este Option File.
func kits_dir() -> String:
	return UserData.optionfiles_dir().path_join(sanitize(name) + "_camisetas")


static func file_for(of_name: String) -> String:
	return UserData.optionfiles_dir().path_join(sanitize(of_name) + "." + EXT)


## Nombre apto para archivo (sin barras ni caracteres raros).
static func sanitize(s: String) -> String:
	var out := ""
	for ch in s.strip_edges():
		out += ch if ch.is_valid_identifier() or ch in " -_()áéíóúñÁÉÍÓÚÑüÜ" or ch.is_valid_int() else "_"
	return out if out != "" else "optionfile"


## Option Files guardados: [{name, file, updated, clubs, nations}].
static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in UserData.files_in(UserData.optionfiles_dir(), EXT):
		var d: Variant = UserData.read_json(f)
		if is_format(d) and TeamDB.db_of(d) == TeamDB.db_id:
			out.append({"name": d.get("name", f.get_file().get_basename()), "file": f, "updated": d.get("updated", ""),
				"clubs": (d.get("clubs", {}) as Dictionary).size(), "nations": (d.get("nations", {}) as Dictionary).size()})
	return out


static func load_file(file: String) -> OptionFile:
	var d: Variant = UserData.read_json(file)
	# Los de otra base no se cargan (sus clubes y jugadores son otros).
	if not is_format(d) or TeamDB.db_of(d) != TeamDB.db_id:
		return null
	return from_dict(d)


## ¿Es un Option File (de este nombre del juego o del anterior)?
static func is_format(d: Variant) -> bool:
	return d is Dictionary and (d.get("format", "") == FORMAT or OLD_FORMATS.has(d.get("format", "")))


static func load_named(of_name: String) -> OptionFile:
	return load_file(file_for(of_name))


static func from_dict(d: Dictionary) -> OptionFile:
	var of := OptionFile.new()
	of.name = String(d.get("name", of.name))
	of.db = TeamDB.db_of(d)
	of.created = String(d.get("created", ""))
	of.updated = String(d.get("updated", ""))
	of.nations = d.get("nations", {})
	of.clubs = d.get("clubs", {})
	of.divisions = d.get("divisions", {})
	of.deleted_nations = d.get("deleted_nations", [])
	of.cups = d.get("cups", [])
	of.rules = d.get("rules", {})
	of.countries = d.get("countries", {})
	of.new_divisions = d.get("new_divisions", {})
	of.club_alias = d.get("club_alias", {})
	of.free_agents = d.get("free_agents", [])
	return of


func to_dict() -> Dictionary:
	return {"format": FORMAT, "version": VERSION, "db": db, "name": name, "created": created, "updated": updated,
		"nations": nations, "clubs": clubs, "divisions": divisions, "deleted_nations": deleted_nations, "cups": cups,
		"rules": rules, "countries": countries, "new_divisions": new_divisions, "club_alias": club_alias,
		"free_agents": free_agents}


func save() -> bool:
	var now := Time.get_datetime_string_from_system(false, true)
	if created == "":
		created = now
	updated = now
	return UserData.write_text(file_for(name), JSON.stringify(to_dict(), " ", false))


func is_empty() -> bool:
	return nations.is_empty() and clubs.is_empty() and divisions.is_empty() and deleted_nations.is_empty() \
		and cups.is_empty() and rules.is_empty() and countries.is_empty() and new_divisions.is_empty() \
		and club_alias.is_empty() and free_agents.is_empty()


## Copia un Option File de afuera (otra PC, un amigo) a la carpeta; devuelve
## su nombre o "" si no es válido. Si ya hay uno con ese nombre, le agrega
## un número.
static func import_from(file: String) -> String:
	var of := load_file(file)
	if of == null:
		return ""
	var base := of.name
	var n := 2
	while FileAccess.file_exists(file_for(of.name)):
		of.name = "%s (%d)" % [base, n]
		n += 1
	of.save()
	return of.name


func export_to(file: String) -> bool:
	return UserData.write_text(file, JSON.stringify(to_dict(), " ", false))


static func delete_named(of_name: String) -> void:
	var f := file_for(of_name)
	if FileAccess.file_exists(f):
		DirAccess.remove_absolute(f)


# --- Aplicar sobre la base ----------------------------------------------------------

## Selecciones de la base con los cambios aplicados.
func apply_nations(base: Array) -> Array:
	var out: Array = []
	var seen := {}
	for n in base:
		var id := String(n["id"])
		seen[id] = true
		if deleted_nations.has(id):
			continue
		out.append(nations[id] if nations.has(id) else n)
	for id in nations:
		if not seen.has(id) and not deleted_nations.has(id):
			out.append(nations[id])
	return out


## Países (con sus divisiones y clubes) con los cambios aplicados. Una
## división con lista propia en `divisions` se arma con esos ids (clubes de
## la base del mismo país o nuevos del Option File).
func apply_countries(base: Array) -> Array:
	var out: Array = []
	var all := base.duplicate()
	var seen := {}
	for c in base:
		seen[String(c["id"])] = true
	for cid in countries:
		if not seen.has(String(cid)):
			var nc: Dictionary = (countries[cid] as Dictionary).duplicate(true)
			nc["id"] = String(cid)
			nc["divisions"] = []
			all.append(nc)
	for c in all:
		var cc: Dictionary = c.duplicate(true)
		for nd in new_divisions.get(String(cc["id"]), []):
			if not (cc["divisions"] as Array).any(func(d: Dictionary) -> bool: return d["id"] == nd["id"]):
				var d: Dictionary = (nd as Dictionary).duplicate(true)
				d["clubs"] = []
				cc["divisions"].append(d)
		var cid := String(cc["id"])
		var by_id := {}
		for d in cc["divisions"]:
			for cl in d["clubs"]:
				by_id[String(cl["id"])] = cl
		for key in clubs:
			var parts := String(key).split(":")
			if parts.size() == 2 and parts[0] == cid:
				by_id[parts[1]] = clubs[key]
		for d in cc["divisions"]:
			var dkey := "%s:%s" % [cid, d["id"]]
			var ids: Array = []
			if divisions.has(dkey):
				ids = divisions[dkey]
			else:
				for cl in d["clubs"]:
					ids.append(String(cl["id"]))
			var list: Array = []
			for id in ids:
				if by_id.has(String(id)):
					var entry: Dictionary = by_id[String(id)].duplicate(true)
					entry["id"] = String(id)
					list.append(entry)
			d["clubs"] = list
			if rules.has(dkey) and (rules[dkey] as Dictionary).has("down"):
				d["down"] = int(rules[dkey]["down"])
		out.append(cc)
	return out


# --- Cambios -------------------------------------------------------------------------

func set_club(country_id: String, entry: Dictionary) -> void:
	clubs["%s:%s" % [country_id, entry["id"]]] = entry.duplicate(true)


func set_nation(entry: Dictionary) -> void:
	nations[String(entry["id"])] = entry.duplicate(true)
	deleted_nations.erase(String(entry["id"]))


func set_relegation(country_id: String, division_id: String, n: int) -> void:
	rules.get_or_add("%s:%s" % [country_id, division_id], {})["down"] = n


## País nuevo (sin divisiones: se agregan con add_division).
func add_country(entry: Dictionary) -> void:
	countries[String(entry["id"])] = entry.duplicate(true)


func add_division(country_id: String, entry: Dictionary) -> void:
	var list: Array = new_divisions.get_or_add(country_id, [])
	for d in list:
		if d["id"] == entry["id"]:
			return
	list.append(entry.duplicate(true))


func set_division(country_id: String, division_id: String, club_ids: Array) -> void:
	divisions["%s:%s" % [country_id, division_id]] = club_ids.duplicate()
