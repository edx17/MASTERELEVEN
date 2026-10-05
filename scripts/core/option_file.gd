class_name OptionFile
extends RefCounted
## Option File (como en el PES): los cambios del jugador sobre la base del
## juego (data/db). La base no se toca nunca; el Option File activo se
## aplica encima al cargar (TeamDB). Se guarda como JSON legible en
## Documentos/MasterEleven/optionfiles/<nombre>.meof y se puede copiar a
## otra PC o compartir.
##
## Contenido (todo opcional):
##   nations:   {id: entrada completa}         selecciones editadas o nuevas
##   clubs:     {"pais:id": entrada completa}  clubes editados o nuevos
##   divisions: {"pais:division": [ids]}       qué clubes juegan cada división
##   deleted_nations: [ids]                    selecciones borradas
## Las entradas tienen el mismo formato que data/db (ver docs/BASE_DE_DATOS.md).

const FORMAT := "MasterEleven OptionFile"
const VERSION := 1
const EXT := "meof"

var name := "Mi Option File"
var created := ""
var updated := ""
var nations: Dictionary = {}
var clubs: Dictionary = {}
var divisions: Dictionary = {}
var deleted_nations: Array = []


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
		if d is Dictionary and d.get("format", "") == FORMAT:
			out.append({"name": d.get("name", f.get_file().get_basename()), "file": f, "updated": d.get("updated", ""),
				"clubs": (d.get("clubs", {}) as Dictionary).size(), "nations": (d.get("nations", {}) as Dictionary).size()})
	return out


static func load_file(file: String) -> OptionFile:
	var d: Variant = UserData.read_json(file)
	if not d is Dictionary or d.get("format", "") != FORMAT:
		return null
	return from_dict(d)


static func load_named(of_name: String) -> OptionFile:
	return load_file(file_for(of_name))


static func from_dict(d: Dictionary) -> OptionFile:
	var of := OptionFile.new()
	of.name = String(d.get("name", of.name))
	of.created = String(d.get("created", ""))
	of.updated = String(d.get("updated", ""))
	of.nations = d.get("nations", {})
	of.clubs = d.get("clubs", {})
	of.divisions = d.get("divisions", {})
	of.deleted_nations = d.get("deleted_nations", [])
	return of


func to_dict() -> Dictionary:
	return {"format": FORMAT, "version": VERSION, "name": name, "created": created, "updated": updated,
		"nations": nations, "clubs": clubs, "divisions": divisions, "deleted_nations": deleted_nations}


func save() -> bool:
	var now := Time.get_datetime_string_from_system(false, true)
	if created == "":
		created = now
	updated = now
	return UserData.write_text(file_for(name), JSON.stringify(to_dict(), " ", false))


func is_empty() -> bool:
	return nations.is_empty() and clubs.is_empty() and divisions.is_empty() and deleted_nations.is_empty()


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
	for c in base:
		var cc: Dictionary = c.duplicate(true)
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
		out.append(cc)
	return out


# --- Cambios -------------------------------------------------------------------------

func set_club(country_id: String, entry: Dictionary) -> void:
	clubs["%s:%s" % [country_id, entry["id"]]] = entry.duplicate(true)


func set_nation(entry: Dictionary) -> void:
	nations[String(entry["id"])] = entry.duplicate(true)
	deleted_nations.erase(String(entry["id"]))


func set_division(country_id: String, division_id: String, club_ids: Array) -> void:
	divisions["%s:%s" % [country_id, division_id]] = club_ids.duplicate()
