extends Panel


onready var side_panel := $VBoxContainer/HBoxContainer/SidePanel
onready var confirm_quit := $ConfirmQuit
onready var content := $VBoxContainer/HBoxContainer/Content
onready var versions := $VBoxContainer/HBoxContainer/Content/Versions


func _ready() -> void:
	_on_SidePanel_tab_changed(side_panel.current_tab)
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		if _should_ask_before_quitting():
			confirm_quit.popup_centered()
		else:
			get_tree().quit()


func show_tab(tab: int) -> void:
	content.current_tab = tab
	side_panel.current_tab = tab


func show_version(version_code: String) -> void:
	show_tab(SidePanel.TABS.VERSIONS)
	versions.select_version(version_code)


func quit() -> void:
	if !_should_ask_before_quitting():
		get_tree().quit()


func _should_ask_before_quitting() -> bool:
	return Versions.active_downloads != 0


func _on_SidePanel_tab_changed(tab) -> void:
	show_tab(tab)


