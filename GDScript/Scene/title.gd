extends Control

const STORY_SCENE := "res://Scene/Scene/story.tscn"


func _ready() -> void:
	$Center/Menu/New.pressed.connect(_on_new)
	$Center/Menu/Continue.pressed.connect(_on_continue)
	$Center/Menu/Load.pressed.connect(_on_load)
	$Center/Menu/Quit.pressed.connect(_on_quit)
	$Center/Menu/Continue.disabled = not SaveGame.has_slot(SaveGame.AUTO_SLOT)


func _on_new() -> void:
	SaveGame.begin_new_run()
	get_tree().change_scene_to_file(STORY_SCENE)


func _on_continue() -> void:
	if SaveGame.has_slot(SaveGame.AUTO_SLOT):
		SaveGame.load_slot(SaveGame.AUTO_SLOT)


func _on_load() -> void:
	var save_ui := get_node_or_null("/root/SaveUI")
	if save_ui != null:
		save_ui.open_for_load()


func _on_quit() -> void:
	get_tree().quit()
