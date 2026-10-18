extends Node
## 熱鍵與 UI 都呼叫 request()。單次動作播完才把 locomotion 交回去。

const BELL_CLIP := "alex_func00_bell"
const INTERACT_CLIP := "alex_func05_interact"
const _CLIPS := {
	1: "alex_func01_call",
	2: "alex_func02_nuzzling",
	3: "alex_func03_bark",
	4: "alex_func04_bite",
}
const _LABELS := {
	1: "呼叫",
	2: "磨蹭",
	3: "吠叫",
	4: "撕咬",
}
const CALL_BARK_RANGE := 8.0
const SECTOR_RANGE := CALL_BARK_RANGE * 0.5
const SECTOR_DEGREES := 75.0
const SECTOR_FLASH := 0.65

var _player: AnimationPlayer
var _loco: Node
var _busy := false
var _playing := ""
var _ring: MeshInstance3D
var _sector: MeshInstance3D
var _sector_left := 0.0


func _ready() -> void:
	_player = get_node("../dog_alex_base/AnimationPlayer") as AnimationPlayer
	_loco = get_node("../LocomotionAnim")
	_player.animation_finished.connect(_on_animation_finished)
	_ring = _make_ring()
	_sector = _make_sector()
	call_deferred("_mount_icons")


func _process(delta: float) -> void:
	var dog := get_parent() as Node3D
	var selected := _designated_unit(dog) if dog != null else null
	if _ring != null:
		if selected == null:
			_ring.visible = false
		else:
			_ring.visible = true
			_ring.global_position = selected.global_position + Vector3(0.0, 0.04, 0.0)
	if _sector == null or Engine.time_scale == 0.0:
		return
	if _sector_left > 0.0:
		_sector_left -= delta
		if _sector_left <= 0.0:
			_sector.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if Engine.time_scale == 0.0:
		return
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_Q:
			request("Q")
		KEY_1:
			request(1)
		KEY_2:
			request(2)
		KEY_3:
			request(3)
		KEY_4:
			request(4)
		KEY_E:
			request("E")


func request(action_id: Variant) -> void:
	if Engine.time_scale == 0.0:
		return
	var token := str(action_id)
	if token == "Q":
		var scan := get_node_or_null("../ScanController")
		if scan != null and scan.has_method("start_scan"):
			scan.start_scan()
		_play_clip(BELL_CLIP, "鈴鐺")
		return
	if token == "E":
		for node in get_tree().get_nodes_in_group("unit"):
			var api := _unit_api(node)
			if api != null and api.has_method("try_interact"):
				api.try_interact()
		_play_clip(INTERACT_CLIP, "互動")
		return
	var action := int(action_id)
	var clip: String = str(_CLIPS.get(action, ""))
	if clip == "":
		return
	if action == 1 or action == 3:
		var dog := get_parent() as Node3D
		_show_call_icon(dog)
		if action == 1:
			_hit_units(2)
			_notify_called()
		else:
			_hit_units(-2)
	_play_clip(clip, str(_LABELS.get(action, "")))


func _play_clip(clip: String, label: String) -> void:
	if not _player.has_animation(clip):
		print("ActionController: 沒有 %s（%s），略過動畫" % [clip, label])
		return
	if _busy:
		return
	_busy = true
	_playing = clip
	_loco.set_busy(true)
	_player.speed_scale = 1.0
	_player.play(clip, 0.08, 1.0)


func _hit_units(amount: int) -> void:
	var dog := get_parent() as Node3D
	for unit in _filtered_units(dog):
		var api := _unit_api(unit)
		if api != null and api.has_method("apply_friendship"):
			api.apply_friendship(amount)


func _notify_called() -> void:
	var dog := get_parent() as Node3D
	for unit in _filtered_units(dog):
		var api := _unit_api(unit)
		if api != null and api.has_method("on_dog_call"):
			api.on_dog_call()


## 指定優先，否則 75° 扇形。指定距離用 CALL_BARK_RANGE，扇形直線距離用其一半。判定只放這裡。
func _passes_call_filter(dog: Node3D, unit: Node3D, selected: Node3D) -> bool:
	var offset := unit.global_position - dog.global_position
	offset.y = 0.0
	var dist := offset.length()
	if selected != null:
		return unit == selected and dist <= CALL_BARK_RANGE
	if dist > SECTOR_RANGE or dist <= 0.001:
		return false
	var forward := _flat_facing(dog)
	return offset.normalized().dot(forward) >= cos(deg_to_rad(SECTOR_DEGREES * 0.5))


func _filtered_units(dog: Node3D) -> Array[Node3D]:
	var targets: Array[Node3D] = []
	if dog == null:
		return targets
	var selected := _designated_unit(dog)
	for node in get_tree().get_nodes_in_group("unit"):
		if node == dog or not node is Node3D:
			continue
		var unit := node as Node3D
		if _passes_call_filter(dog, unit, selected):
			targets.append(unit)
	return targets


func _designated_unit(dog: Node) -> Node3D:
	if dog == null:
		return null
	var selected: Variant = dog.get("selected_unit")
	if selected == null or not is_instance_valid(selected) or not selected is Node3D:
		return null
	return selected as Node3D


func _flat_facing(dog: Node3D) -> Vector3:
	var forward := -dog.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	return forward.normalized()


func _unit_api(node: Node) -> Node:
	if node.has_method("apply_friendship") or node.has_method("on_dog_call") or node.has_method("try_interact"):
		return node
	return node.get_node_or_null("FollowAI")


func _show_call_icon(dog: Node3D) -> void:
	if dog == null or _sector == null:
		return
	if _designated_unit(dog) != null:
		_sector.visible = false
		_sector_left = 0.0
		return
	var forward := _flat_facing(dog)
	_sector.visible = true
	_sector.global_position = dog.global_position + Vector3(0.0, 0.03, 0.0)
	_sector.rotation = Vector3(0.0, atan2(-forward.x, -forward.z), 0.0)
	_sector_left = SECTOR_FLASH


func _mount_icons() -> void:
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	if _ring.get_parent() == null:
		host.add_child(_ring)
	if _sector.get_parent() == null:
		host.add_child(_sector)
	_ring.top_level = true
	_sector.top_level = true


func _make_ring() -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.42
	mesh.outer_radius = 0.58
	mesh.rings = 8
	mesh.ring_segments = 24
	var view := MeshInstance3D.new()
	view.name = "CallTargetRing"
	view.mesh = mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	view.visible = false
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.96, 0.82, 0.28, 0.9)
	view.material_override = mat
	return view


func _make_sector() -> MeshInstance3D:
	var steps := 18
	var half := deg_to_rad(SECTOR_DEGREES * 0.5)
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.append(Vector3(0.0, 0.02, 0.0))
	for i in steps + 1:
		var angle := lerpf(-half, half, float(i) / float(steps))
		verts.append(Vector3(sin(angle) * SECTOR_RANGE, 0.02, -cos(angle) * SECTOR_RANGE))
	for i in steps:
		indices.append(0)
		indices.append(i + 1)
		indices.append(i + 2)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var view := MeshInstance3D.new()
	view.name = "CallSectorIcon"
	view.mesh = mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	view.visible = false
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.45, 0.78, 1.0, 0.32)
	view.material_override = mat
	return view


func _on_animation_finished(anim_name: StringName) -> void:
	if not _busy or str(anim_name) != _playing:
		return
	_busy = false
	_playing = ""
	_loco.set_busy(false)
