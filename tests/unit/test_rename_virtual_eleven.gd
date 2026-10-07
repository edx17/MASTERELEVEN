extends GutTest
## Master Eleven → Virtual Eleven: la carpeta de datos, los Option Files y las
## carreras guardadas con el nombre anterior siguen andando.

var _base := ""


func before_each() -> void:
	_base = ProjectSettings.globalize_path("user://test_rename_%d" % randi())
	DirAccess.make_dir_recursive_absolute(_base)


func after_each() -> void:
	_rm(_base)
	UserData.root_override = ""


func _rm(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	for sub in d.get_directories():
		_rm(dir.path_join(sub))
	DirAccess.remove_absolute(dir)


func _write(file: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var f := FileAccess.open(file, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_old_folder_is_renamed_and_option_files_get_new_extension() -> void:
	var old := _base.path_join(UserData.OLD_FOLDER)
	_write(old.path_join("config.cfg"), "[x]\n")
	_write(old.path_join("optionfiles/Mio.meof"), JSON.stringify({"format": "MasterEleven OptionFile", "name": "Mio"}))
	var new_root := _base.path_join(UserData.FOLDER)
	assert_true(UserData.migrate_rename(new_root), "se movió la carpeta vieja")
	assert_false(DirAccess.dir_exists_absolute(old))
	assert_true(FileAccess.file_exists(new_root.path_join("config.cfg")), "la configuración sigue")
	assert_true(FileAccess.file_exists(new_root.path_join("optionfiles/Mio.veof")), ".meof → .veof")
	UserData.root_override = new_root
	var of := OptionFile.load_file(OptionFile.file_for("Mio"))
	assert_not_null(of, "el Option File de Master Eleven se sigue cargando")
	assert_eq(OptionFile.list().size(), 1)


func test_existing_new_folder_is_not_overwritten() -> void:
	_write(_base.path_join(UserData.OLD_FOLDER).path_join("config.cfg"), "viejo")
	var new_root := _base.path_join(UserData.FOLDER)
	_write(new_root.path_join("config.cfg"), "nuevo")
	assert_false(UserData.migrate_rename(new_root))
	assert_eq(FileAccess.get_file_as_string(new_root.path_join("config.cfg")), "nuevo")


func test_old_career_format_still_loads() -> void:
	assert_true(MasterCareer.is_format({"format": "MasterEleven Liga Master"}), "carreras de Master Eleven")
	assert_true(MasterCareer.is_format({"format": MasterCareer.FORMAT}))
	assert_false(MasterCareer.is_format({"format": "otra cosa"}))
	assert_eq(MasterCareer.FORMAT, "VirtualEleven Liga Virtual")
