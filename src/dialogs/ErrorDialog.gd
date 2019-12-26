extends AcceptDialog

func _ready() -> void:
	var label := Label.new()
	label.name = "Label"
	label.autowrap = true
	add_child(label)

	rect_min_size = Vector2(300, 0)

func show_error(title: String, error: String) -> void:
	window_title = tr(title)
	$Label.text = tr(error)

	rect_size = Vector2(0, 0)
	popup_centered()