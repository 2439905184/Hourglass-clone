class_name ProjectCreator
extends Reference


var PROJECT_GODOT_3: String = _read_file("res://data/template/3/project.godot")
var PROJECT_GODOT_4: String = _read_file("res://data/template/4/project.godot")
var GLES_2 : String = _read_file("res://data/template/4/gles2.txt")

var project_id: String


func create_project(path: String, name: String, version: String, gles2: bool) -> int:
	var directory := Directory.new()
	directory.make_dir_recursive(path)

	var config_version := Versions.get_config_version(version)
	var ret: int
	match config_version:
		0, 3:
			# 0 is for custom versions. Just use the same template as 3.
			ret = _create_project_3(path, name)
		4:
			ret = _create_project_4(path, name, gles2)
		_:
			return ERR_DOES_NOT_EXIST

	if ret != OK: return ret

	project_id = Projects.create_project(path, version)

	return OK


func _create_project_3(path: String, name: String) -> int:
	var pg := File.new()
	pg.open(path.plus_file("project.godot"), File.WRITE)
	pg.store_string(PROJECT_GODOT_3.format({ "name": name }))
	pg.close()

	var dir := Directory.new()
	dir.copy("res://data/template/3/default_env.tres", path.plus_file("default_env.tres"))
	dir.copy("res://data/template/3/icon.png", path.plus_file("icon.png"))

	return OK

func _create_project_4(path: String, name: String, gles2: bool) -> int:
	var pg := File.new()
	pg.open(path.plus_file("project.godot"), File.WRITE)
	var gles = GLES_2 if gles2 else ""
	pg.store_string(PROJECT_GODOT_4.format({ "name": name, "gles": gles }))
	pg.close()

	var dir := Directory.new()
	dir.copy("res://data/template/4/default_env.tres", path.plus_file("default_env.tres"))
	dir.copy("res://data/template/4/icon.png", path.plus_file("icon.png"))

	return OK

static func _read_file(path: String) -> String:
	var file := File.new()
	file.open(path, File.READ)
	return file.get_as_text()
