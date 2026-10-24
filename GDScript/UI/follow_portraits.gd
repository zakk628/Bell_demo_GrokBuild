extends HBoxContainer
## 跟隨中的人頭像。只在跟隨狀態改變時增刪，不每幀重掃場景。

const SLOT := 48.0
const GAP := 8
const BORDER := 4

var _units: Array[Node] = []
var _buttons: Array[Button] = []


func _ready() -> void:
	add_to_group("follow_portraits")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", GAP)
	var info := get_parent().get_node_or_null("UnitInfo") as Control
	if info != null and not info.resized.is_connected(_place_above_info):
		info.resized.connect(_place_above_info)
	call_deferred("_place_above_info")


## 資訊欄文字變高時會往上長。頭像列改貼在它實際頂端上方，不蓋住底部按鍵。
func _place_above_info() -> void:
	var info := get_parent().get_node_or_null("UnitInfo") as Control
	if info == null:
		return
	var parent_h := position.y - offset_top
	var bottom := info.position.y - 8.0
	offset_bottom = bottom - parent_h
	offset_top = offset_bottom - SLOT


## body 是角色根節點。following 為真時依加入順序接到列尾。
func set_following(body: Node, following: bool) -> void:
	if body == null or not is_instance_valid(body):
		_drop_invalid()
		return
	var index := _units.find(body)
	if following:
		if index >= 0:
			return
		_append(body)
	elif index >= 0:
		_remove_at(index)
	_fit_width()
	_sync_borders()


## 只改外框。選取取消時列還在。
func sync_selection() -> void:
	_sync_borders()


func _append(body: Node) -> void:
	var status := body.get_node_or_null("Status_Control")
	var shown := _display_name(body, status)
	var button := Button.new()
	button.custom_minimum_size = Vector2(SLOT, SLOT)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.clip_text = true
	button.text = _abbreviation(shown)
	button.tooltip_text = shown
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.98, 0.97, 0.94, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	if _apply_portrait(button, status):
		button.text = ""
	_paint(button, shown, false)
	button.pressed.connect(_on_pressed.bind(body))
	add_child(button)
	_units.append(body)
	_buttons.append(button)


func _remove_at(index: int) -> void:
	var button := _buttons[index]
	_buttons.remove_at(index)
	_units.remove_at(index)
	if button != null and is_instance_valid(button):
		if button.get_parent() == self:
			remove_child(button)
		button.queue_free()


func _drop_invalid() -> void:
	var index := _units.size() - 1
	while index >= 0:
		if not is_instance_valid(_units[index]):
			_remove_at(index)
		index -= 1


func _on_pressed(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	var dog := _dog()
	if dog == null or not dog.has_method("select_unit"):
		return
	dog.call("select_unit", body)


func _dog() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("dog_alex", true, false)


func _sync_borders() -> void:
	var selected: Node = null
	var dog := _dog()
	if dog != null:
		var raw: Variant = dog.get("selected_unit")
		if raw is Node and is_instance_valid(raw):
			selected = raw as Node
	var index := 0
	while index < _buttons.size():
		var body := _units[index]
		var shown := _display_name(body, body.get_node_or_null("Status_Control"))
		_paint(_buttons[index], shown, body == selected)
		index += 1


func _fit_width() -> void:
	var count := _buttons.size()
	var width := 0
	if count > 0:
		width = int(SLOT) * count + GAP * (count - 1)
	offset_right = offset_left + float(width)


func _display_name(body: Node, status: Node) -> String:
	if status != null:
		var named: Variant = status.get("display_name")
		if named is String and String(named) != "":
			return String(named)
	if body == null:
		return ""
	return String(body.name)


func _abbreviation(shown: String) -> String:
	var parts := shown.split(" ", false)
	if parts.size() >= 2:
		var left := ""
		var right := ""
		if parts[0].length() > 0:
			left = parts[0].substr(0, 1)
		if parts[1].length() > 0:
			right = parts[1].substr(0, 1)
		return (left + right).to_upper()
	var word := shown.strip_edges()
	if word.length() <= 2:
		return word.to_upper()
	return word.substr(0, 2).to_upper()


func _apply_portrait(button: Button, status: Node) -> bool:
	if status == null:
		return false
	var tex: Texture2D = null
	var portrait_value: Variant = status.get("portrait")
	if portrait_value is Texture2D:
		tex = portrait_value as Texture2D
	if tex == null:
		var path_value: Variant = status.get("portrait_path")
		if path_value is String and String(path_value) != "":
			var loaded: Variant = load(String(path_value))
			if loaded is Texture2D:
				tex = loaded as Texture2D
	if tex == null:
		return false
	button.icon = tex
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return true


func _paint(button: Button, shown: String, selected: bool) -> void:
	var base := _color_for(shown)
	var border := 0
	var border_color := Color(0, 0, 0, 0)
	if selected:
		border = BORDER
		border_color = Color(0.96, 0.82, 0.28, 1)
	var kinds: Array[String] = ["normal", "hover", "pressed", "focus"]
	for kind in kinds:
		var box := StyleBoxFlat.new()
		box.bg_color = base
		if kind == "hover":
			box.bg_color = base.lightened(0.12)
		elif kind == "pressed":
			box.bg_color = base.darkened(0.12)
		box.border_width_left = border
		box.border_width_top = border
		box.border_width_right = border
		box.border_width_bottom = border
		box.border_color = border_color
		box.content_margin_left = 2.0
		box.content_margin_top = 2.0
		box.content_margin_right = 2.0
		box.content_margin_bottom = 2.0
		button.add_theme_stylebox_override(kind, box)


func _color_for(label: String) -> Color:
	var hash_value := absi(label.hash())
	var hue := float(hash_value % 360) / 360.0
	return Color.from_hsv(hue, 0.45, 0.55, 1.0)
