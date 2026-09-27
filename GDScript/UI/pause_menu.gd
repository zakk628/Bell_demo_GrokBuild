extends CanvasLayer

const YARD_SCENE := "res://Scene/Scene/test_yard.tscn"
const TITLE_SCENE := "res://Scene/Scene/title.tscn"

var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	$Root.visible = false
	$Root/Center/Menu/Resume.pressed.connect(_resume)
	$Root/Center/Menu/Save.pressed.connect(_save)
	$Root/Center/Menu/Restart.pressed.connect(_restart)
	$Root/Center/Menu/Title.pressed.connect(_title)
	$Root/Center/Menu/Quit.pressed.connect(_quit)


func _process(_delta: float) -> void:
	if _open and not _in_yard():
		_set_open(false)


func _input(event: InputEvent) -> void:
	if not _in_yard():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE):
			var save_ui := get_node_or_null("/root/SaveUI")
			if save_ui != null and save_ui.is_open():
				save_ui.close()
				get_viewport().set_input_as_handled()
				return
			_set_open(not _open)
			get_viewport().set_input_as_handled()
			return
		if _open and _blocks_key(key):
			get_viewport().set_input_as_handled()


func _blocks_key(key: InputEventKey) -> bool:
	match key.physical_keycode:
		KEY_W, KEY_A, KEY_S, KEY_D, KEY_1, KEY_2, KEY_3, KEY_4, KEY_Q, KEY_E, KEY_ALT, KEY_SHIFT:
			return true
	return false


func _in_yard() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == YARD_SCENE


func _set_open(open_menu: bool) -> void:
	_open = open_menu
	$Root.visible = open_menu
	if not open_menu:
		var save_ui := get_node_or_null("/root/SaveUI")
		if save_ui != null:
			save_ui.close()
	Engine.time_scale = 0.0 if open_menu else 1.0


func _resume() -> void:
	_set_open(false)


func _save() -> void:
	var save_ui := get_node_or_null("/root/SaveUI")
	if save_ui != null:
		save_ui.open_for_save()


func _restart() -> void:
	var save_ui := get_node_or_null("/root/SaveUI")
	if save_ui != null:
		save_ui.close()
	_set_open(false)
	Engine.time_scale = 1.0
	SaveGame.restart_from_last_manual()


func _title() -> void:
	SaveGame.write_auto_save()
	_set_open(false)
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(TITLE_SCENE)


func _quit() -> void:
	if _in_yard():
		SaveGame.write_auto_save()
	Engine.time_scale = 1.0
	get_tree().quit()
