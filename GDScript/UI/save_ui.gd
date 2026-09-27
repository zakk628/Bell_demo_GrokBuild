extends CanvasLayer

var _mode := "save"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	$Root.visible = false
	$Root/Panel/Back.pressed.connect(close)
	var list := $Root/Panel/List
	for index in SaveGame.slot_count():
		var button := Button.new()
		button.custom_minimum_size = Vector2(460, 46)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_on_slot.bind(index))
		list.add_child(button)


func is_open() -> bool:
	return $Root.visible


func open_for_save() -> void:
	_mode = "save"
	_show()


func open_for_load() -> void:
	_mode = "load"
	_show()


func close() -> void:
	$Root.visible = false


func _show() -> void:
	_refresh()
	$Root.visible = true


func _refresh() -> void:
	var title := $Root/Panel/Title as Label
	title.text = "存檔" if _mode == "save" else "讀檔"
	var list := $Root/Panel/List
	var index := 0
	for child in list.get_children():
		if child is Button:
			(child as Button).text = "%s    %s" % [SaveGame.slot_label(index), SaveGame.slot_summary(index)]
			index += 1
	var hint := $Root/Panel/Hint as Label
	if _mode == "save":
		hint.text = "點 Save01–Save05 寫入。靠近紀錄點才能寫入手動檔。自動存檔在離開時寫入。"
	else:
		hint.text = "手動欄只回到該紀錄點。自動存檔含離開時的位置。"


func _on_slot(index: int) -> void:
	var hint := $Root/Panel/Hint as Label
	if _mode == "save":
		if index == SaveGame.AUTO_SLOT:
			hint.text = "自動存檔會在回標題或離開時寫入，不能在這裡手動寫。"
			return
		var error := SaveGame.write_manual_slot(index)
		if error != "":
			hint.text = error
			return
		hint.text = "已寫入 %s" % SaveGame.slot_label(index)
		_refresh_buttons()
		return
	if not SaveGame.has_slot(index):
		hint.text = "這一欄是空的"
		return
	close()
	var pause := get_node_or_null("/root/PauseMenu")
	if pause != null and pause._open:
		pause._set_open(false)
	SaveGame.load_slot(index)


func _refresh_buttons() -> void:
	var list := $Root/Panel/List
	var index := 0
	for child in list.get_children():
		if child is Button:
			(child as Button).text = "%s    %s" % [SaveGame.slot_label(index), SaveGame.slot_summary(index)]
			index += 1


func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()
