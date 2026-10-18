extends CharacterBody3D

const FRIEND_MIN := -10
const FRIEND_MAX := 10
const FEAR_DISTANCE := 5.0
const FOLLOW_DISTANCE := 1.0
const INTERACT_DISTANCE := 3.0
const FEAR_SPEED := 1.4
const FOLLOW_SPEED := 3.0

@export var age := ""
@export var occupation := ""
@export var mental_state := ""

var friendliness := 0
var _eyes: Array[MeshInstance3D] = []
var _prompt: Label3D
var _message: Label
var _message_left := 0.0
var _dog: Node3D


func _ready() -> void:
	add_to_group("unit")
	for node in find_children("eye", "MeshInstance3D", true, false):
		_eyes.append(node)
	_prompt = Label3D.new()
	_prompt.name = "InteractPrompt"
	_prompt.text = "E"
	_prompt.font_size = 64
	_prompt.position = Vector3(0, 2.3, 0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.visible = false
	add_child(_prompt)
	var layer := CanvasLayer.new()
	layer.layer = 20
	_message = Label.new()
	_message.name = "InteractMessage"
	_message.position = Vector2(16, 150)
	_message.add_theme_font_size_override("font_size", 28)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.text = ""
	layer.add_child(_message)
	add_child(layer)
	_apply_eye()


func selection_info() -> String:
	return "姓名：%s\n年齡：%s\n職業：%s\n狀態：%s\n友善值：%d\n心理狀態：%s" % [
		name, age, occupation, mood_name(), friendliness, mental_state
	]


func mood_name() -> String:
	if friendliness <= -6:
		return "恐懼"
	if friendliness >= 6:
		return "親切"
	return "平穩"


func is_following() -> bool:
	return mood_name() == "親切"


func apply_friendship(amount: int) -> void:
	friendliness = clampi(friendliness + amount, FRIEND_MIN, FRIEND_MAX)
	_apply_eye()
	_spawn_delta(amount)
	_refresh_selection()


func try_interact() -> void:
	if Engine.time_scale == 0.0 or not _in_interact_range():
		return
	_message.text = "互動測試成功"
	_message_left = 1.5


func _physics_process(delta: float) -> void:
	if Engine.time_scale == 0.0:
		velocity = Vector3.ZERO
		_prompt.visible = false
		return
	var dog := _find_dog()
	var speed := 0.0
	var desired := 0.0
	var mood := mood_name()
	if dog != null and mood == "恐懼":
		desired = FEAR_DISTANCE
		speed = FEAR_SPEED
	elif dog != null and mood == "親切":
		desired = FOLLOW_DISTANCE
		speed = FOLLOW_SPEED
	var wish := Vector3.ZERO
	if dog != null and speed > 0.0:
		wish = _seek_distance(dog, desired, speed)
		var to_dog := dog.global_position - global_position
		to_dog.y = 0.0
		if to_dog.length() > 0.1:
			# 眼睛在本地 +Z，yaw = atan2(x, z) 讓 +Z 指向狗。
			rotation.y = rotate_toward(rotation.y, atan2(to_dog.x, to_dog.z), 4.0 * delta)
	velocity.x = wish.x
	velocity.z = wish.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.text = ""
	_prompt.visible = _in_interact_range()


func _seek_distance(dog: Node3D, desired: float, speed: float) -> Vector3:
	var offset := global_position - dog.global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance < 0.05:
		offset = Vector3(0, 0, 1)
		distance = 1.0
	if absf(distance - desired) <= 0.25:
		return Vector3.ZERO
	var away := offset / distance
	if distance > desired:
		return -away * speed
	return away * speed


func _in_interact_range() -> bool:
	var dog := _find_dog()
	if dog == null:
		return false
	var offset := global_position - dog.global_position
	offset.y = 0.0
	return offset.length() <= INTERACT_DISTANCE


func _find_dog() -> Node3D:
	if _dog != null and is_instance_valid(_dog):
		return _dog
	var scene := get_tree().current_scene
	if scene == null:
		return null
	_dog = scene.find_child("dog_alex", true, false) as Node3D
	return _dog


func _spawn_delta(amount: int) -> void:
	var floater := Label3D.new()
	floater.text = "+2" if amount > 0 else "-2"
	floater.modulate = Color(0.45, 1.0, 0.5) if amount > 0 else Color(1.0, 0.35, 0.35)
	floater.position = Vector3(0, 2.6, 0)
	floater.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floater.font_size = 56
	add_child(floater)
	var rise := create_tween()
	rise.tween_property(floater, "position", Vector3(0, 3.5, 0), 0.8)
	rise.parallel().tween_property(floater, "modulate:a", 0.0, 0.8)
	rise.finished.connect(floater.queue_free)


func _apply_eye() -> void:
	var color := Color(0.25, 0.55, 1.0)
	if friendliness <= -6:
		color = Color(1.0, 0.12, 0.12)
	elif friendliness >= 6:
		color = Color(0.15, 1.0, 0.25)
	for eye in _eyes:
		var mat := eye.material_override as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			eye.material_override = mat
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.0


func _refresh_selection() -> void:
	var dog := _find_dog()
	if dog != null and dog.get("selected_unit") == self and dog.has_method("refresh_selection"):
		dog.refresh_selection()
