extends Node

const VERSIONS_STORE = "user://versions.cfg"
const VERSIONS_TEMPLATE = "res://data/versions.cfg"

var _versions_store : ConfigFile

signal version_installed(version)
signal download_progress(version, downloaded, total)
signal install_failed(version)
signal versions_updated()

func get_versions() -> PoolStringArray:
	return _versions_store.get_sections()

func get_tags(version: String) -> PoolStringArray:
	return _versions_store.get_value(version, "tags", [])

func has_tag(version: String, tag: String) -> bool:
	for i in get_tags(version):
		if i == tag: return true
	return false

func get_download_url(version: String) -> String:
	var os := OS.get_name() + "." + ("64" if OS.has_feature("64") else "32")
	return _versions_store.get_value(version, os)

func is_installed(version: String) -> bool:
	var file := File.new()
	return file.file_exists(get_executable(version))

func get_directory(version: String) -> String:
	return OS.get_user_data_dir().plus_file("versions").plus_file(version)

func get_executable(version: String) -> String:
	var exec_name := "godot.exe" if OS.get_name() == "Windows" else "godot"
	return get_directory(version).plus_file(exec_name)

func get_config_version(version: String) -> int:
	return _versions_store.get_value(version, "config_version")

func launch(version: String, args: PoolStringArray=[]) -> int:
	if not is_installed(version): return ERR_DOES_NOT_EXIST

	print("executing: ", get_executable(version), " ", args)
	OS.execute(get_executable(version), args, false)
	return OK

func run_scene(version: String, scene: String) -> void:
	launch(version, [scene])

func install(version: String) -> void:
	var download = Downloader.new(version)
	add_child(download)
	download.download()

func _ready() -> void:
	_versions_store = ConfigFile.new()
	_versions_store.load(VERSIONS_STORE)

	var updater := VersionsUpdater.new()
	updater.connect("versions_updated", self, "_on_versions_updated")
	add_child(updater)

	_merge_versions(VERSIONS_TEMPLATE)

func _merge_versions(path: String) -> void:
	var file := ConfigFile.new()
	file.load(path)

	for section in file.get_sections():
		for key in file.get_section_keys(section):
			_versions_store.set_value(section, key, file.get_value(section, key))

	emit_signal("versions_updated")
	_save()

func _on_versions_updated() -> void:
	_merge_versions(VersionsUpdater.DOWNLOAD_PATH)
	var dir := Directory.new()
	dir.remove(VersionsUpdater.DOWNLOAD_PATH)

func _save() -> void:
	_versions_store.save(VERSIONS_STORE)
