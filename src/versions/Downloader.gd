# Downloader.gd -- Downloads Godot versions
#
# The Downloader node downloads and extracts versions of Godot Engine from
# the mirror at downloads.tuxfamily.org. Each download uses a new Downloader
# node; it's not an autoload.

class_name Downloader
extends HTTPRequest


const MIRROR = "https://downloads.tuxfamily.org/godotengine/"

var version: String
var active := false setget ,is_active
var failed := false
var _url: String


func _init(version: String) -> void:
	Versions.active_downloads += 1

	self.version = version
	var url = Versions.get_download_url(version)

	if not url:
		_failed("Hourglass can't find a download for your OS and architecture.")
		return

	_url = MIRROR + url
	download_file = Versions.get_directory(version).plus_file("download.zip")

	connect("request_completed", self, "_on_request_completed")


func _process(_delta: float) -> void:
	Versions.emit_signal("download_progress", version, get_downloaded_bytes(), get_body_size())


func download() -> void:
	active = true
	var dir := Directory.new()
	dir.make_dir_recursive(Versions.get_directory(version))

	print("Downloading ", _url)
	request(_url)


func cancel() -> void:
	cancel_request()
	queue_free()
	Versions.active_downloads -= 1
	active = false


func is_active() -> bool:
	return active


func _on_request_completed(result: int, response: int, _headers, _body) -> void:
	if result != RESULT_SUCCESS:
		printerr("Download failed! Could not connect.")
		printerr("Request URL: " + _url)
		printerr("Connection error: " + str(result) + " (see https://docs.godotengine.org/en/3.1/classes/class_httprequest.html#enumerations)")
		_failed("The download failed to start.")
		return

	if response != 200:
		printerr("Download failed! HTTP status code " + str(response))
		printerr("Request URL: " + _url)
		_failed("The download failed to start.")
		return

	_extract_godot()


func _extract_godot() -> void:
	# open the zip file
	var unzip := ZIPReader.new()
	unzip.open(download_file)
	var files := unzip.get_files()

	# figure out where all the needed files are
	var exec_file: String
	var godot_sharp := []
	var macos_files := []
	var prefix
	if files.size() == 1:
		exec_file = files[0]
		prefix = ""
	else:
		for file in files:
			if file.ends_with(".app/"):
				continue
			prefix = _str_prefix(prefix, file)
		for i in range(files.size()):
			var file = files[i].trim_prefix(prefix)
			files[i] = file

		if OS.get_name() == "OSX":
			# Treat macOS as a special case due to its app bundle structure
			exec_file = "MacOS/Godot"
			for file in files:
				if file == exec_file: continue
				if file.ends_with(".app/"): continue
				macos_files.append(file)
		else:
			for file in files:
				if file.ends_with(".cmd"): continue
				if file.begins_with("GodotSharp/"):
					godot_sharp.append(file)
					continue
				
				if exec_file:
					printerr("Error! Can't tell which file is the Godot executable")
					_failed("The downloaded file seems to be broken.")
					return
				exec_file = file

	if not exec_file:
		printerr("Error! Can't find Godot executable in zip file")
		_failed("The downloaded file seems to be broken.")
		return

	# if there are any files in GodotSharp/ extract them
	var dest_dir: String = Versions.get_directory(version)
	for filename in godot_sharp + macos_files:
		if filename.find("..") != -1:
			printerr("DANGER! POTENTIAL MALICIOUS DOWNLOAD DETECTED. A file in the zip archive contains `..` which can be used to overwrite files outside the destination! Aborting.")
			printerr(filename)
			_failed("The downloaded file seems to be broken.")
			return

		var filepath := dest_dir.plus_file(filename)

		var dir := Directory.new()
		dir.make_dir_recursive(filepath.get_base_dir())

		var file := File.new()
		if file.open(filepath, File.WRITE) == OK:
			var data = unzip.read_file(prefix.plus_file(filename))
			file.store_buffer(data)
			file.close()

	# extract the godot executable
	var exec_path: String = Versions.get_executable(version)
	var godot : PoolByteArray = unzip.read_file(prefix.plus_file(exec_file))
	var out := File.new()
	out.open(exec_path, File.WRITE)
	out.store_buffer(godot)
	out.close()

	var manifest := ConfigFile.new()
	manifest.set_value("files", "GodotSharp", godot_sharp)
	if OS.get_name() == "OSX":
		manifest.set_value("files", "macOS", macos_files)
	manifest.save(dest_dir.plus_file("manifest.cfg"))

	# make the file executable on *nix systems
	if OS.get_name() == "X11" or OS.get_name() == "OSX":
		OS.execute("chmod", ["+x", exec_path], true)

	# remove download.zip
	var directory := Directory.new()
	directory.remove(download_file)

	Versions.emit_signal("versions_updated")
	Versions.active_downloads -= 1
	queue_free()


func _failed(reason) -> void:
	self.failed = true

	if not reason:
		reason = "Check the console for more information."

	Versions.emit_signal("install_failed", version, reason)
	Versions.active_downloads -= 1
	queue_free()


# Returns the longest common path that both strings start with.
# Will just return b if a is null
func _str_prefix(a, b: String) -> String:
	var base : Array = b.get_base_dir().split("/")
	var result := ""
	
	if a == null:
		for i in base.size():
			if base[i].length() == 0:
				break
				
			result += base[i] + "/"
	
	else:
		var a_split : Array = a.split("/")
		for i in base.size():
			if i > a_split.size() || a_split[i] != base[i] || a_split[i].length() == 0:
				break
			
			result += a_split[i] + "/"
	
	return result
