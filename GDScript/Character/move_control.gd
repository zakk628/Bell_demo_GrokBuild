extends Node
## 共用跟隨。友善時朝狗的 CollisionShape3D 移動。模型面朝本地 +Z。
## 碰到雙方碰撞就 idle；狗遠離超過 2 m 才再走。走 3 m 內、跑到 6 m、更遠衝刺。

const _Anime := preload("res://GDScript/Character/anime_control.gd")

const BASE_SPEED := 2.0
const WALK_DISTANCE := 3.0
const SPRINT_DISTANCE := 6.0
const RESUME_DISTANCE := 2.0
const TURN_SPEED := 8.0
const CONTACT_SLOP := 0.05

var _body: CharacterBody3D
var _anime: Node
var _status: Node
var _dog: Node3D
var _waiting := false
var _reported_missing_collision := false
var _reported_missing_body_shape := false


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if _body == null:
		push_error("Move_Control 的父節點必須是 CharacterBody3D")
		return
	_anime = get_node_or_null("../Anime_Control")
	_status = get_node_or_null("../Status_Control")
	if _anime == null:
		push_error("角色缺少 Anime_Control")
	if _status == null:
		push_error("角色缺少 Status_Control")


func _physics_process(delta: float) -> void:
	if _body == null or _anime == null or _status == null:
		return
	if Engine.time_scale == 0.0:
		_body.velocity.x = 0.0
		_body.velocity.z = 0.0
		return
	var dog := _find_dog()
	var following := false
	if dog != null and _status.has_method("is_following"):
		following = bool(_status.call("is_following"))
	if not following:
		_waiting = false
		_anime.set_idle()
		_body.velocity.x = 0.0
		_body.velocity.z = 0.0
		_apply_vertical(delta)
		return
	var to_dog := _offset_to_dog_collision(dog)
	var dist := to_dog.length()
	if dist > 0.1:
		var target_yaw := atan2(to_dog.x, to_dog.z)
		_body.rotation.y = rotate_toward(_body.rotation.y, target_yaw, TURN_SPEED * delta)
	if _hold_for_contact(dist, _contact_distance(dog)):
		_anime.set_idle()
		_body.velocity.x = 0.0
		_body.velocity.z = 0.0
		_apply_vertical(delta)
		return
	var gait: int = _gait_for_distance(dist)
	var wish := Vector3.ZERO
	if dist > 0.15:
		wish = to_dog / dist
	var speed := BASE_SPEED * float(_anime.move_scale(gait))
	_anime.set_move_state(gait)
	_body.velocity.x = wish.x * speed
	_body.velocity.z = wish.z * speed
	_apply_vertical(delta)


## 碰到狗的碰撞就停在 idle。水平距離超過 2 m 才解除，避免貼在碰撞上來回踏步。
func _hold_for_contact(dist: float, touch: float) -> bool:
	if not _waiting and dist <= touch:
		_waiting = true
	elif _waiting and dist > RESUME_DISTANCE:
		_waiting = false
	return _waiting


func _contact_distance(dog: Node3D) -> float:
	return _collision_radius(dog) + _body_collision_radius() + CONTACT_SLOP


func _body_collision_radius() -> float:
	for child in _body.get_children():
		if child is CollisionShape3D:
			var radius := _horizontal_radius(child as CollisionShape3D)
			if radius > 0.0:
				return radius
	if not _reported_missing_body_shape:
		_reported_missing_body_shape = true
		push_error("角色沒有可用的 CollisionShape3D，接觸距離改用 0.35 m")
	return 0.35


func _collision_radius(dog: Node3D) -> float:
	var shape_node: CollisionShape3D = dog.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		return 0.0
	return _horizontal_radius(shape_node)


func _horizontal_radius(shape_node: CollisionShape3D) -> float:
	if shape_node == null or shape_node.shape == null:
		return 0.0
	var scale_v := shape_node.global_transform.basis.get_scale()
	var flat := maxf(absf(scale_v.x), absf(scale_v.z))
	var shape: Shape3D = shape_node.shape
	if shape is CylinderShape3D:
		var cylinder: CylinderShape3D = shape as CylinderShape3D
		return cylinder.radius * flat
	if shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = shape as CapsuleShape3D
		return capsule.radius * flat
	if shape is SphereShape3D:
		var sphere: SphereShape3D = shape as SphereShape3D
		return sphere.radius * flat
	if shape is BoxShape3D:
		var box: BoxShape3D = shape as BoxShape3D
		return 0.5 * maxf(box.size.x * absf(scale_v.x), box.size.z * absf(scale_v.z))
	return 0.0


func _gait_for_distance(dist: float) -> int:
	if dist > SPRINT_DISTANCE:
		return _Anime.MoveState.SPRINT
	if dist <= WALK_DISTANCE:
		return _Anime.MoveState.WALK
	return _Anime.MoveState.RUN


func _apply_vertical(delta: float) -> void:
	if not _body.is_on_floor():
		_body.velocity += _body.get_gravity() * delta
	else:
		_body.velocity.y = 0.0
	_body.move_and_slide()


func _offset_to_dog_collision(dog: Node3D) -> Vector3:
	var center := dog.global_position
	var shape_node: CollisionShape3D = dog.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null:
		center = shape_node.global_position
	elif not _reported_missing_collision:
		_reported_missing_collision = true
		push_error("狗沒有 CollisionShape3D，距離改用狗的原點")
	var to_dog := center - _body.global_position
	to_dog.y = 0.0
	return to_dog


func _find_dog() -> Node3D:
	if _dog != null and is_instance_valid(_dog):
		return _dog
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	var found: Node3D = scene.find_child("dog_alex", true, false) as Node3D
	_dog = found
	return _dog
