extends CharacterBody3D
## 模組根：移動、點地導航、選取。WASD 讀相機水平前／右。俯仰只在基準俯角上加減，不改場景裡的基準。

const WALK_SPEED := 0.5
const RUN_SPEED := WALK_SPEED * 7.0
const SPRINT_SPEED := WALK_SPEED * 10.0
const ACCEL := 28.0
const DECEL := 48.0
const TURN_SPEED := 12.0
const YAW_PER_PIXEL := 0.005
const DRAG_PX := 6.0
const NAV_STOP := 0.55
const CAMERA_DISTANCE_MIN := 3.0
const CAMERA_DISTANCE_MAX := 50.0
const CAMERA_DISTANCE_FALLBACK := 8.0
const PAN_RETURN_SPEED := 14.0
const PITCH_LIMIT := PI / 6.0
const PITCH_PER_PIXEL := 0.004

const _Loco := preload("res://GDScript/Character/locomotion_anim.gd")

@onready var _loco: Node = $LocomotionAnim
@onready var _camera_rig: Node3D = $CameraRig
@onready var _camera: Camera3D = $CameraRig/Camera3D

var _rig_basis: Basis
var _yaw := 0.0
var _flat_forward := Vector3(0, 0, -1)
var _flat_right := Vector3(1, 0, 0)
var _rmb_down := false
var _rmb_dragged := false
var _rmb_press := Vector2.ZERO
var _mmb_down := false
var _nav_target := Vector3.ZERO
var _has_nav := false
var selected_unit: Node = null
var _camera_base_dir := Vector3(0, 0.6, 0.8)
var _camera_base_basis := Basis.IDENTITY
var _camera_distance := CAMERA_DISTANCE_FALLBACK
var _camera_pan := Vector3.ZERO
var _pitch := 0.0


func _ready() -> void:
	add_to_group("unit")
	_rig_basis = _camera_rig.global_transform.basis
	_camera_base_basis = _camera.transform.basis
	var authored := _camera.position
	var authored_length := authored.length()
	if authored_length < 0.1:
		_camera_base_dir = Vector3(0, 0.6, 0.8).normalized()
		_camera_distance = CAMERA_DISTANCE_FALLBACK
	else:
		_camera_base_dir = authored / authored_length
		_camera_distance = clampf(authored_length, CAMERA_DISTANCE_MIN, CAMERA_DISTANCE_MAX)
	var spawn := SaveGame.take_pending_spawn()
	if not spawn.is_empty():
		global_position = spawn.position
		rotation.y = float(spawn.yaw)
	_apply_camera_pose()


func _physics_process(delta: float) -> void:
	if Engine.time_scale == 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		_rmb_down = false
		return
	if not _mmb_down:
		_camera_pan = _camera_pan.move_toward(Vector3.ZERO, PAN_RETURN_SPEED * delta)
	_apply_camera_pose()
	_read_camera_axes()
	var wasd := _wasd_direction()
	var wish := wasd
	if wasd != Vector3.ZERO:
		_has_nav = false
	elif _has_nav:
		wish = _nav_direction()
	var state: int = _Loco.MoveState.IDLE
	var speed := 0.0
	if wish != Vector3.ZERO:
		if wasd != Vector3.ZERO and Input.is_action_pressed("move_sprint"):
			state = _Loco.MoveState.SPRINT
			speed = SPRINT_SPEED
		elif wasd != Vector3.ZERO and Input.is_action_pressed("move_walk"):
			state = _Loco.MoveState.WALK
			speed = WALK_SPEED
		else:
			state = _Loco.MoveState.RUN
			speed = RUN_SPEED
	_loco.set_move_state(state)

	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var rate := ACCEL if wish != Vector3.ZERO else DECEL
	horiz = horiz.move_toward(wish * speed, rate * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z
	if not is_on_floor():
		velocity += get_gravity() * delta

	if wish != Vector3.ZERO:
		# −Z 為模組前方：yaw = atan2(-dir.x, -dir.z)。
		var target_yaw := atan2(-wish.x, -wish.z)
		rotation.y = rotate_toward(rotation.y, target_yaw, TURN_SPEED * delta)

	move_and_slide()
	_apply_camera_pose()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.time_scale == 0.0:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if _over_ui():
			_rmb_down = false
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and not _over_ui():
			_zoom_camera(-2.5)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and not _over_ui():
			_zoom_camera(2.5)
		elif button.button_index == MOUSE_BUTTON_MIDDLE and not _over_ui():
			_mmb_down = button.pressed
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			if button.pressed:
				_rmb_down = true
				_rmb_dragged = false
				_rmb_press = button.position
			elif _rmb_down:
				if not _rmb_dragged:
					_navigate_click(button.position)
				_rmb_down = false
				_rmb_dragged = false
		elif button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			_select_click(button.position)
	elif event is InputEventMouseMotion and not _over_ui():
		var motion := event as InputEventMouseMotion
		if _mmb_down:
			_zoom_camera(motion.relative.y * 0.16)
			_camera_pan.x = clampf(_camera_pan.x + motion.relative.x * 0.03, -6.0, 6.0)
		elif _rmb_down:
			if motion.position.distance_to(_rmb_press) >= DRAG_PX:
				_rmb_dragged = true
			if _rmb_dragged:
				_yaw -= motion.relative.x * YAW_PER_PIXEL
				_pitch = clampf(_pitch - motion.relative.y * PITCH_PER_PIXEL, -PITCH_LIMIT, PITCH_LIMIT)


func _zoom_camera(delta_distance: float) -> void:
	_camera_distance = clampf(_camera_distance + delta_distance, CAMERA_DISTANCE_MIN, CAMERA_DISTANCE_MAX)


func _apply_camera_pose() -> void:
	var rig_pos := _camera_rig.global_position
	var basis := Basis(Vector3.UP, _yaw) * _rig_basis
	_camera_rig.global_transform = Transform3D(basis, rig_pos)
	var offset := _camera_base_dir * _camera_distance
	var pitched := _camera_base_basis * Basis(Vector3.RIGHT, _pitch)
	_camera.transform = Transform3D(pitched, Vector3(offset.x + _camera_pan.x, offset.y, offset.z + _camera_pan.z))
	if _camera.position.y < 0.4:
		_camera.position.y = 0.4


func _read_camera_axes() -> void:
	var look := -_camera.global_transform.basis.z
	look.y = 0.0
	if look.length_squared() < 0.0001:
		_flat_forward = Vector3(0, 0, -1)
	else:
		_flat_forward = look.normalized()
	# forward × up = right。look (0,0,-1) → right (1,0,0)。
	_flat_right = _flat_forward.cross(Vector3.UP).normalized()


func _wasd_direction() -> Vector3:
	var input_forward := Input.get_axis("move_back", "move_forward")
	var input_right := Input.get_axis("move_left", "move_right")
	var wish := _flat_right * input_right + _flat_forward * input_forward
	if wish.length_squared() > 1.0:
		return wish.normalized()
	if wish.length_squared() < 0.0001:
		return Vector3.ZERO
	return wish


func _nav_direction() -> Vector3:
	var to := _nav_target - global_position
	to.y = 0.0
	if to.length() <= NAV_STOP:
		_has_nav = false
		return Vector3.ZERO
	return to.normalized()


func _over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


func _navigate_click(screen_pos: Vector2) -> void:
	if Engine.time_scale == 0.0 or _wasd_direction() != Vector3.ZERO:
		_has_nav = false
		return
	var hit := _raycast(screen_pos)
	if hit.is_empty():
		return
	var collider := hit.collider as Node
	if _find_grouped(collider, ["unit", "item"]) != null:
		return
	if _find_grouped(collider, ["ground"]) == null:
		return
	_nav_target = hit.position
	_has_nav = true


func _select_click(screen_pos: Vector2) -> void:
	var hit := _raycast(screen_pos)
	var selected: Node = null
	if not hit.is_empty():
		selected = _find_grouped(hit.collider as Node, ["unit", "item"])
	_show_selection(selected)


func _raycast(screen_pos: Vector2) -> Dictionary:
	var origin := _camera.project_ray_origin(screen_pos)
	var normal := _camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + normal * 400.0)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _find_grouped(node: Node, groups: Array) -> Node:
	var current := node
	while current != null:
		for group_name in groups:
			if current.is_in_group(str(group_name)):
				return current
		current = current.get_parent()
	return null


func refresh_selection() -> void:
	if selected_unit != null and is_instance_valid(selected_unit):
		_show_selection(selected_unit)


func _show_selection(node: Node) -> void:
	selected_unit = node
	var label := get_tree().get_first_node_in_group("selection_label") as Label
	if label == null:
		return
	var info_node := node
	if node != null and not node.has_method("selection_info"):
		var ai := node.get_node_or_null("FollowAI")
		if ai != null and ai.has_method("selection_info"):
			info_node = ai
	if node == null:
		label.text = ""
	elif info_node != null and info_node.has_method("selection_info"):
		label.text = info_node.selection_info()
	else:
		label.text = "選取：%s" % node.name
