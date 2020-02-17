extends Node


signal version_installed(version)
signal version_changed(version)
signal download_progress(version, downloaded, total)
signal install_failed(version)
signal versions_updated()

const VERSIONS_STORE = "user://versions.cfg"
const VERSIONS_TEMPLATE = "res://data/versions.cfg"

var active_downloads := 0

var _versions_store: ConfigFile
var _installed_cache := {}


func _ready() -> void:
	_versions_store = ConfigFile.new()
	_versions_store.load(VERSIONS_STORE)

	var updater := VersionsUpdater.new()
	updater.connect("versions_updated", self, "_on_versions_updated")
	add_child(updater)

	_merge_versions(VERSIONS_TEMPLATE)

	self.connect("version_installed", self, "_invalidate_installed_cache")
	self.connect("version_changed", self, "_invalidate_installed_cache")


func get_versions() -> PoolStringArray:
	return _versions_store.get_sections()


func sort_versions(version_a: String, version_b: String) -> bool:
	var a_custom := is_custom(version_a)
	var b_custom := is_custom(version_b)

	# Always sort custom versions first
	if a_custom and !b_custom:
		return true
	if !a_custom and b_custom:
		return false

	var name_a := get_version_name(version_a)
	var name_b := get_version_name(version_b)

	# Sort custom versions alphabetically, official versions
	# by version number
	if a_custom:
		return name_a.casecmp_to(name_b) == -1
	else:
		return _compare_semver(name_a, name_b)


func exists(version: String) -> bool:
	return _versions_store.has_section(version)


func get_version_name(version: String) -> String:
	return _versions_store.get_value(version, "name", version)


func set_version_name(version: String, new_name: String) -> void:
	_versions_store.set_value(version, "name", new_name)
	emit_signal("version_changed", version)
	_save()


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
	if _installed_cache.has(version):
		return _installed_cache[version]

	var file := File.new()
	var result := file.file_exists(get_executable(version))
	_installed_cache[version] = result
	return result


func get_directory(version: String) -> String:
	return OS.get_user_data_dir().plus_file("versions").plus_file(version)


func get_executable(version: String) -> String:
	if _versions_store.has_section_key(version, "executable"):
		return _versions_store.get_value(version, "executable", null)

	var exec_name := "godot.exe" if OS.get_name() == "Windows" else "godot"
	return get_directory(version).plus_file(exec_name)


func set_custom_executable(version: String, path: String) -> void:
	_versions_store.set_value(version, "executable", path)
	emit_signal("version_changed", version)
	_save()


func is_executable_set(version: String) -> bool:
	return _versions_store.has_section_key(version, "executable")


func get_config_version(version: String) -> int:
	return _versions_store.get_value(version, "config_version", 0)


func launch(version: String, args: PoolStringArray=[]) -> int:
	if not is_installed(version):
		return ERR_DOES_NOT_EXIST

	print("executing: ", get_executable(version), " ", args)
	OS.execute(get_executable(version), args, false)
	return OK


func run_scene(version: String, scene: String) -> void:
	launch(version, [scene])


func install(version: String) -> void:
	var download = Downloader.new(version)
	add_child(download)
	download.download()


func uninstall(version: String) -> void:
	if not is_installed(version):
		return

	var path := get_directory(version)
	var dir := Directory.new()

	# read the manifest and delete files listed there
	var manifest := ConfigFile.new()
	var manifest_path := path.plus_file("manifest.cfg")
	manifest.load(manifest_path)

	var to_delete := []

	to_delete += manifest.get_value("files", "GodotSharp")
	if manifest.has_section_key("files", "macOS"):
		to_delete += manifest.get_value("files", "macOS")

	# delete in reverse order, so that directories are deleted after their
	# contents
	to_delete.invert()
	for file in to_delete:
		dir.remove(path.plus_file(file))

	# delete the executable
	dir.remove(get_executable(version))
	# delete the manifest
	dir.remove(manifest_path)
	# delete the directory
	dir.remove(path)

	emit_signal("version_changed", version)


func add_custom() -> String:
	var version := Utils.uuid()
	_versions_store.set_value(version, "is_custom", true)
	_versions_store.set_value(version, "name", tr("New Custom Version"))
	emit_signal("version_installed", version)
	_save()
	return version


func is_custom(version: String) -> bool:
	return _versions_store.get_value(version, "is_custom", false)


func remove_custom_version(version: String) -> void:
	if not is_custom(version):
		return

	_versions_store.erase_section(version)
	emit_signal("version_changed", version)
	_save()


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


func _invalidate_installed_cache(version: String) -> void:
	_installed_cache.erase(version)


func _save() -> void:
	_versions_store.save(VERSIONS_STORE)


# Returns true if version_a is newer than version_b
func _compare_semver(version_a: String, version_b: String) -> bool:
	# cast to Array so we can use has()
	var parts_a := Array(version_a.split("-"))
	var parts_b := Array(version_b.split("-"))

	var ver_a: Array = parts_a[0].split(".")
	var ver_b: Array = parts_b[0].split(".")

	# check if the version numbers differ
	for i in range(min(ver_a.size(), ver_b.size())):
		if int(ver_a[i]) < int(ver_b[i]):
			return false
		elif int(ver_a[i]) > int(ver_b[i]):
			return true

	# if the versions start the same but one is longer, then
	# the longer one is newer
	if ver_a.size() < ver_b.size():
		return false
	elif ver_a.size() > ver_b.size():
		return true

	# If the version numbers are the same, check the modifiers
	# (rc, mono, etc.)
	var rc_a = _get_rc_num(version_a)
	var rc_b = _get_rc_num(version_b)
	if rc_a == 0 and rc_b > 0:
		return true
	elif rc_a > 0 and rc_b == 0:
		return false
	elif rc_a < rc_b:
		return false
	elif rc_a > rc_b:
		return true

	# sort mono versions as older than regular versions
	if parts_a.has("mono") and !parts_b.has("mono"):
		return false
	elif !parts_a.has("mono") and parts_b.has("mono"):
		return true

	# guess we'll call them equal then
	return true


# Gets the RC number of a version, or 0 if it is not an RC version.
func _get_rc_num(version: String) -> int:
	for part in version.split("-"):
		if part.begins_with("rc"):
			return int(part.rstrip("rc"))
	return 0
