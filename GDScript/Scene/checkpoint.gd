extends StaticBody3D

@export var checkpoint_id := "checkpoint"

var _prompt: Label3D


func _ready() -> void:
	add_to_group("checkpoint")
	_prompt = Label3D.new()
	_prompt.name = "SavePrompt"
	_prompt.text = "可存檔"
	_prompt.font_size = 48
	_prompt.position = Vector3(0, 1.3, 0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.visible = false
	add_child(_prompt)


func _process(_delta: float) -> void:
	_prompt.visible = Engine.time_scale > 0.0 and _dog_within_range()


func _dog_within_range() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var dog := scene.find_child("dog_alex", true, false) as Node3D
	if dog == null:
		return false
	var offset := global_position - dog.global_position
	offset.y = 0.0
	return offset.length() <= SaveGame.CHECKPOINT_RANGE
