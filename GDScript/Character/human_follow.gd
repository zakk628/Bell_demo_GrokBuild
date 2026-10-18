extends Node
## 待救援人類的跟隨與狀態。移動由根 CharacterBody3D 執行。
## 模型面朝本地 +Z。進入狗碰撞外 2 m 就停下並播閒置；離開才恢復移動。
## 距離門檻有滯後：停下時鎖 walk，到 5 m 才回 run；sprint 在 > 10 m 鎖上、到 7 m 才回 run。

const _Loco := preload("res://GDScript/Character/human_locomotion.gd")
const FRIEND_MIN := -10
const FRIEND_MAX := 10
const STOP_PADDING := 2.0

@export var base_speed := 2.0
@export var walk_enter_distance := 0.5
@export var walk_exit_distance := 5.0
@export var sprint_enter_distance := 10.0
@export var sprint_exit_distance := 7.0
@export var turn_speed := 8.0
@export var age := ""
@export var occupation := ""
@export var mental_state := ""

var friendliness := 0
var _called := false
var _gait: int = _Loco.MoveState.RUN
var _active := false
var _dog: Node3D
var _loco: Node
var _body: CharacterBody3D
var _reported_missing_dog_shape := false


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if _body == null:
		push_error("FollowAI 的父節點必須是 CharacterBody3D")
		return
	if not _body.is_in_group("unit"):
		_body.add_to_group("unit")
	_loco = get_node("../LocomotionAnim")
	call_deferred("_adopt_collision")


func selection_info() -> String:
	var unit_name := _body.name if _body != null else name
	return "姓名：%s\n年齡：%s\n職業：%s\n狀態：%s\n友善值：%d\n心理狀態：%s" % [
		unit_name, age, occupation, mood_name(), friendliness, mental_state
	]


func mood_name() -> String:
	if friendliness <= -6:
		return "恐懼"
	if friendliness >= 6:
		return "親切"
	return "平穩"


func is_following() -> bool:
	return _wants_follow()


func apply_friendship(amount: int) -> void:
	friendliness = clampi(friendliness + amount, FRIEND_MIN, FRIEND_MAX)
	if mood_name() == "恐懼":
		_called = false
	_spawn_delta(amount)
	_refresh_selection()


func on_dog_call() -> void:
	_called = true


func _physics_process(delta: float) -> void:
	if _body == null:
		return
	if Engine.time_scale == 0.0:
		_body.velocity.x = 0.0
		_body.velocity.z = 0.0
		return
	var dog := _find_dog()
	var following := dog != null and _wants_follow()
	if following and not _active:
		_gait = _Loco.MoveState.RUN
	_active = following
	var wish := Vector3.ZERO
	var speed := 0.0
	if following:
		var to_dog := _offset_to_dog_collision(dog)
		var dist := to_dog.length()
		if dist > 0.1:
			# 模型面朝 +Z。
			var target_yaw := atan2(to_dog.x, to_dog.z)
			_body.rotation.y = rotate_toward(_body.rotation.y, target_yaw, turn_speed * delta)
		if dist > _dog_stop_distance(dog):
			var gait := _chase_gait(dist)
			wish = to_dog / dist
			speed = base_speed * float(_loco.move_scale(gait))
			_loco.set_move_state(gait)
		else:
			# 進入狗碰撞外 2 m：鎖上 walk，停下並播跟隨閒置。
			_gait = _Loco.MoveState.WALK
			wish = Vector3.ZERO
			speed = 0.0
			_loco.set_idle(true)
	else:
		_loco.set_idle(false)
	_body.velocity.x = wish.x * speed
	_body.velocity.z = wish.z * speed
	if not _body.is_on_floor():
		_body.velocity += _body.get_gravity() * delta
	else:
		_body.velocity.y = 0.0
	_body.move_and_slide()


func _wants_follow() -> bool:
	if mood_name() == "恐懼":
		_called = false
		return false
	return _called or mood_name() == "親切"


func _chase_gait(dist: float) -> int:
	var gait := _gait
	if dist > sprint_enter_distance:
		gait = _Loco.MoveState.SPRINT
	elif gait == _Loco.MoveState.SPRINT and dist > sprint_exit_distance:
		gait = _Loco.MoveState.SPRINT
	elif gait == _Loco.MoveState.SPRINT:
		gait = _Loco.MoveState.RUN
	elif gait == _Loco.MoveState.WALK and dist < walk_exit_distance:
		gait = _Loco.MoveState.WALK
	elif gait == _Loco.MoveState.WALK:
		gait = _Loco.MoveState.RUN
	elif dist < walk_enter_distance:
		gait = _Loco.MoveState.WALK
	elif gait == _Loco.MoveState.IDLE:
		gait = _Loco.MoveState.RUN
	_gait = gait
	return gait


func _offset_to_dog_collision(dog: Node3D) -> Vector3:
	var center := dog.global_position
	var shape_node := _dog_collision(dog)
	if shape_node != null:
		center = shape_node.global_position
	var to_dog := center - _body.global_position
	to_dog.y = 0.0
	return to_dog


func _dog_stop_distance(dog: Node3D) -> float:
	return _dog_collision_radius(dog) + STOP_PADDING


func _dog_collision(dog: Node3D) -> CollisionShape3D:
	return dog.get_node_or_null("CollisionShape3D") as CollisionShape3D


func _dog_collision_radius(dog: Node3D) -> float:
	var shape_node := _dog_collision(dog)
	if shape_node == null or shape_node.shape == null:
		if not _reported_missing_dog_shape:
			_reported_missing_dog_shape = true
			push_error("狗沒有 CollisionShape3D，停下距離只使用 2 m")
		return 0.0
	var scale := shape_node.global_transform.basis.get_scale()
	var flat_scale := maxf(absf(scale.x), absf(scale.z))
	var shape := shape_node.shape
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).radius * flat_scale
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).radius * flat_scale
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius * flat_scale
	if shape is BoxShape3D:
		var box := shape as BoxShape3D
		return 0.5 * maxf(box.size.x * absf(scale.x), box.size.z * absf(scale.z))
	if not _reported_missing_dog_shape:
		_reported_missing_dog_shape = true
		push_error("狗的碰撞無法換算水平半徑，停下距離只使用 2 m")
	return 0.0


func _adopt_collision() -> void:
	var shape := _find_model_shape()
	if shape == null:
		push_error("實例模型底下沒有 CollisionShape3D")
		return
	var model := shape.get_parent() as CollisionObject3D
	if shape.get_parent() != _body:
		shape.reparent(_body)
	if shape.get_parent() != _body:
		push_error("圓柱碰撞沒有掛上根節點")
		return
	if model != null and model != _body:
		model.collision_layer = 0
		model.collision_mask = 0


func _find_model_shape() -> CollisionShape3D:
	for child in _body.get_children():
		if child == self or child.name == "LocomotionAnim":
			continue
		var shape := child.find_child("CollisionShape3D", true, false) as CollisionShape3D
		if shape != null:
			return shape
	return null


func _find_dog() -> Node3D:
	if _dog != null and is_instance_valid(_dog):
		return _dog
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	_dog = scene.find_child("dog_alex", true, false) as Node3D
	return _dog


func _spawn_delta(amount: int) -> void:
	if _body == null or amount == 0:
		return
	var floater := Label3D.new()
	floater.text = "+2" if amount > 0 else "-2"
	floater.modulate = Color(0.45, 1.0, 0.5) if amount > 0 else Color(1.0, 0.35, 0.35)
	floater.position = Vector3(0, 2.6, 0)
	floater.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floater.font_size = 56
	_body.add_child(floater)
	var rise := _body.create_tween()
	rise.tween_property(floater, "position", Vector3(0, 3.5, 0), 0.8)
	rise.parallel().tween_property(floater, "modulate:a", 0.0, 0.8)
	rise.finished.connect(floater.queue_free)


func _refresh_selection() -> void:
	var dog := _find_dog()
	if dog == null or not dog.has_method("refresh_selection"):
		return
	if dog.get("selected_unit") == _body or dog.get("selected_unit") == self:
		dog.refresh_selection()
