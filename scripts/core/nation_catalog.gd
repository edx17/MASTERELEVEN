class_name NationCatalog
extends RefCounted
## Catálogo de selecciones que no están en la base (data/db/nation_catalog.json):
## bandera, camisetas titular y suplente, confederación y nombres en
## castellano e inglés. El importador crea una selección del catálogo cuando
## un CSV trae jugadores de ese país.

const FILE := "res://data/db/nation_catalog.json"

static var _entries: Array = []
static var _by_alias: Dictionary = {}


static func entries() -> Array:
	if _entries.is_empty():
		var f := FileAccess.open(FILE, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_entries = d.get("nations", [])
		for n in _entries:
			_by_alias[String(n["id"])] = String(n["id"])
			_by_alias[SquadImporter.normalize(String(n["name"]))] = String(n["id"])
			for a in n.get("aka", []):
				_by_alias[SquadImporter.normalize(String(a))] = String(n["id"])
	return _entries


## Entrada lista para la base (sin "aka"), o {} si no está.
static func entry(id: String) -> Dictionary:
	for n in entries():
		if n["id"] == id:
			var e: Dictionary = (n as Dictionary).duplicate(true)
			e.erase("aka")
			return e
	return {}


## Id por nombre (normalizado) en castellano o inglés, o "".
static func id_of(normalized_name: String) -> String:
	entries()
	return String(_by_alias.get(normalized_name, ""))
