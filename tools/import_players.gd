extends Node
## Importa planteles a la BASE del juego (data/db), para quien trabaja en el
## proyecto. Los jugadores importan desde el juego (OPCIONES > DATOS), que
## guarda en su Option File sin tocar la base.
##   godot --headless -- --import-players=archivo1.csv[,archivo2.csv ...]
## Ver SquadImporter y docs/BASE_DE_DATOS.md.

## Archivos a importar (los pone GameSettings desde la línea de comandos).
var files: PackedStringArray = []


func _ready() -> void:
	var menu := get_tree().current_scene
	if menu != null:
		menu.queue_free()
	_run.call_deferred()


func _run() -> void:
	if files.is_empty():
		print("Uso: godot --headless -- --import-players=archivo.csv[,más.csv]")
		get_tree().quit(1)
		return
	var imp := SquadImporter.new()
	var rows: Array[Dictionary] = []
	for f in files:
		rows.append_array(SquadImporter.read_csv(f))
	print("Filas leídas: ", rows.size())
	# La base es de solo lectura para el juego: se lee sin Option File.
	TeamDB.use_option_file(null)
	var result := imp.import_rows(rows)
	for line in imp.report:
		print(line)
	print("Clubes con plantel: %d · selecciones: %d · jugadores sin club en la base: %d" % [result["clubs"], result["nations"], result["unmatched"]])
	get_tree().quit()
