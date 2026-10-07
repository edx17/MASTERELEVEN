class_name UserData
extends RefCounted
## Carpeta de datos del jugador, fácil de encontrar: Documentos/VirtualEleven
## (si no hay carpeta Documentos, la de datos de la aplicación).
##
##   config.cfg          opciones del juego
##   controles.cfg       botones
##   records.json        récords del entrenamiento
##   planes.cfg          estrategias guardadas (Copiar estrategia)
##   optionfiles/        Option Files (*.veof): cambios sobre la base
##   saves/ligas/        cada Liga en curso
##   saves/copas/        cada Copa / Mundial en curso
##   saves/master/       Liga Virtual (ranuras)
##   importar/           donde se dejan los CSV de planteles
##   plantillas/         plantillas PNG de camisetas para pintar
##
## Los tests y las herramientas usan una carpeta aparte (sandbox) para no
## tocar los datos del jugador.

const FOLDER := "VirtualEleven"
## Nombres anteriores del juego (Master Eleven): sus datos se pasan solos a la
## carpeta nueva la primera vez que se abre.
const OLD_FOLDER := "MasterEleven"
const OLD_APP_NAME := "Master Eleven"
const SUBDIRS := ["optionfiles", "saves/ligas", "saves/copas", "saves/master", "importar", "plantillas"]

## Raíz forzada (tests); "" = la de siempre.
static var root_override := ""
## Corre un test o una herramienta: todo va a user://sandbox.
static var sandbox := false
static var _root := ""


static func root() -> String:
	if root_override != "":
		return root_override
	if sandbox:
		return ProjectSettings.globalize_path("user://sandbox")
	if _root == "":
		var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		# En Android / iOS, Documentos no se puede escribir sin permisos: se usa
		# la carpeta propia de la app.
		if OS.has_feature("mobile"):
			docs = ""
		if docs != "" and DirAccess.dir_exists_absolute(docs):
			_root = docs.path_join(FOLDER)
		else:
			_root = OS.get_user_data_dir().path_join(FOLDER)
	return _root


static func path(rel: String) -> String:
	return root().path_join(rel)


static func config_path() -> String:
	return path("config.cfg")


static func controls_path() -> String:
	return path("controles.cfg")


static func records_path() -> String:
	return path("records.json")


static func plans_path() -> String:
	return path("planes.cfg")


static func optionfiles_dir() -> String:
	return path("optionfiles")


static func templates_dir() -> String:
	return path("plantillas")


static func import_dir() -> String:
	return path("importar")


## Carpeta de partidas de un tipo ("ligas", "copas", "master").
static func saves_dir(kind: String) -> String:
	return path("saves".path_join(kind))


## Crea las carpetas que falten (y un LEEME en la de importar).
static func ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(root())
	for d in SUBDIRS:
		DirAccess.make_dir_recursive_absolute(path(d))
	var readme := import_dir().path_join("LEEME.txt")
	if not FileAccess.file_exists(readme):
		var f := FileAccess.open(readme, FileAccess.WRITE)
		if f != null:
			f.store_string("Dejá acá los archivos CSV de planteles (EA FC / SoFIFA, Transfermarkt o una planilla\n" +
				"propia) y en el juego entrá a OPCIONES > DATOS > IMPORTAR PLANTELES.\n" +
				"Columnas reconocidas y fuentes recomendadas: docs/BASE_DE_DATOS.md\n")


## Carpetas donde pudo quedar la de datos con el nombre anterior del juego:
## al lado de la nueva (Documentos/MasterEleven) y en los datos de la
## aplicación vieja (app_userdata/Master Eleven/MasterEleven).
static func old_roots(new_root: String) -> Array[String]:
	return [new_root.get_base_dir().path_join(OLD_FOLDER),
		old_user_dir().path_join(OLD_FOLDER)]


## user:// de cuando el juego se llamaba Master Eleven.
static func old_user_dir() -> String:
	return OS.get_user_data_dir().get_base_dir().path_join(OLD_APP_NAME)


## Master Eleven → Virtual Eleven: si todavía no hay carpeta nueva y existe la
## vieja, se renombra (configuración, Option Files y partidas siguen igual).
## Los Option Files .meof pasan a .veof. Devuelve si movió la carpeta.
static func migrate_rename(new_root: String = "") -> bool:
	if new_root == "":
		new_root = root()
	var moved := false
	if not DirAccess.dir_exists_absolute(new_root):
		for old in old_roots(new_root):
			if old != new_root and DirAccess.dir_exists_absolute(old):
				DirAccess.make_dir_recursive_absolute(new_root.get_base_dir())
				if DirAccess.rename_absolute(old, new_root) == OK:
					moved = true
					break
	var ofs := new_root.path_join("optionfiles")
	for f in files_in(ofs, OptionFile.OLD_EXT):
		var dst := f.get_basename() + "." + OptionFile.EXT
		if not FileAccess.file_exists(dst):
			DirAccess.rename_absolute(f, dst)
	return moved


## Pasa los archivos de versiones anteriores (en user://) a la carpeta nueva,
## sin pisar nada que ya exista.
static func migrate_old() -> void:
	migrate_rename()
	var moves := {
		"user://settings.cfg": config_path(),
		"user://controls.cfg": controls_path(),
		"user://training.json": records_path(),
		"user://plans.cfg": plans_path(),
		"user://competition.json": saves_dir("ligas").path_join("partida_anterior.json"),
	}
	for old in moves:
		var dst: String = moves[old]
		# En user:// del nombre nuevo o en el del anterior (Master Eleven).
		for src in [ProjectSettings.globalize_path(old), old_user_dir().path_join(String(old).get_file())]:
			if FileAccess.file_exists(src) and not FileAccess.file_exists(dst):
				DirAccess.copy_absolute(src, dst)
				DirAccess.remove_absolute(src)


## Archivos de una carpeta con esa extensión (rutas completas), los más
## nuevos primero.
static func files_in(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.get_extension().to_lower() == ext:
			out.append(dir.path_join(f))
	out.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(a) > FileAccess.get_modified_time(b))
	return out


static func open_folder(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	OS.shell_open(dir)


## Guarda texto de forma segura: primero a un temporal y después lo
## reemplaza (si se corta la luz no queda un archivo a medias).
static func write_text(file: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var tmp := file + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	return DirAccess.rename_absolute(tmp, file) == OK


static func read_json(file: String) -> Variant:
	if not FileAccess.file_exists(file):
		return null
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())
