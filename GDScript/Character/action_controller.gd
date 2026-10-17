extends Node
## 熱鍵與 UI 都呼叫 request()。單次動作播完才把 locomotion 交回去。

const _CLIPS := {
	1: "alex_func01_call",
	2: "alex_func02_snap",
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

var _player: AnimationPlayer
var _loco: Node
var _busy := false
var _playing := ""


func _ready() -> void:
	_player = get_node("../dog_alex_base/AnimationPlayer") as AnimationPlayer
	_loco = get_node("../LocomotionAnim")
	_player.animation_finished.connect(_on_animation_finished)


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
		return
	if token == "E":
		for node in get_tree().get_nodes_in_group("unit"):
			var api := _unit_api(node)
			if api != null and api.has_method("try_interact"):
				api.try_interact()
		return
	var action := int(action_id)
	var clip: String = str(_CLIPS.get(action, ""))
	if clip == "":
		return
	if action == 1:
		_hit_units(2)
		_notify_called()
	elif action == 3:
		_hit_units(-2)
	var has_clip := _player.has_animation(clip)
	if not has_clip:
		print("ActionController: 沒有 %s（%s），略過動畫" % [clip, _LABELS.get(action, "")])
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
	if dog == null:
		return
	for node in get_tree().get_nodes_in_group("unit"):
		if node == dog:
			continue
		var unit := node as Node3D
		if unit == null:
			continue
		var api := _unit_api(node)
		if api == null or not api.has_method("apply_friendship"):
			continue
		var offset := unit.global_position - dog.global_position
		offset.y = 0.0
		if offset.length() <= CALL_BARK_RANGE:
			api.apply_friendship(amount)


func _notify_called() -> void:
	var dog := get_parent() as Node3D
	if dog == null:
		return
	for node in get_tree().get_nodes_in_group("unit"):
		if node == dog:
			continue
		var unit := node as Node3D
		if unit == null:
			continue
		var api := _unit_api(node)
		if api == null or not api.has_method("on_dog_call"):
			continue
		var offset := unit.global_position - dog.global_position
		offset.y = 0.0
		if offset.length() <= CALL_BARK_RANGE:
			api.on_dog_call()


func _unit_api(node: Node) -> Node:
	if node.has_method("apply_friendship") or node.has_method("on_dog_call") or node.has_method("try_interact"):
		return node
	return node.get_node_or_null("FollowAI")


func _on_animation_finished(anim_name: StringName) -> void:
	if not _busy or str(anim_name) != _playing:
		return
	_busy = false
	_playing = ""
	_loco.set_busy(false)
