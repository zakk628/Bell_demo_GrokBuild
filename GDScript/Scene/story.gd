extends Control

const YARD_SCENE := "res://Scene/Scene/test_yard.tscn"

var _left := false


func _ready() -> void:
	$Skip.pressed.connect(_go_yard)
	$Timer.timeout.connect(_go_yard)
	$Timer.start()


func _unhandled_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func _go_yard() -> void:
	if _left:
		return
	_left = true
	$Timer.stop()
	get_tree().change_scene_to_file(YARD_SCENE)
