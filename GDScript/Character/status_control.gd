extends Node
## 共用角色狀態。友善值 -10 到 10。6 以上為友善，-6 以下為恐懼，其餘閒置。

const FRIEND_MIN := -10
const FRIEND_MAX := 10
const FRIEND_AT := 6
const FEAR_AT := -6

@export var display_name := ""
@export var age := "30歲"
@export var note := "草寮鎮鎮民"
@export var body_state := "正常"
## 之後換成頭像。空路徑且沒有貼圖時，頭像列用名字縮寫。
@export var portrait_path := ""
@export var portrait: Texture2D

var friendliness := 0
var _body: CharacterBody3D


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if _body == null:
		push_error("Status_Control 的父節點必須是 CharacterBody3D")
		return
	if not _body.is_in_group("unit"):
		_body.add_to_group("unit")
	if is_following():
		call_deferred("_notify_follow", true)


func selection_info() -> String:
	var shown := display_name
	if shown == "":
		if _body == null:
			shown = String(name)
		else:
			shown = String(_body.name)
	return "姓名：%s\n年齡：%s\n備註：%s\n身體狀態：%s\n心理狀態：%s\n友善值：%d" % [
		shown, age, note, body_state, mental_state_name(), friendliness
	]


func mental_state_name() -> String:
	if friendliness <= FEAR_AT:
		return "恐懼"
	if friendliness >= FRIEND_AT:
		return "友善"
	return "閒置"


func is_following() -> bool:
	return friendliness >= FRIEND_AT


func apply_friendship(amount: int) -> void:
	var was_following := is_following()
	friendliness = clampi(friendliness + amount, FRIEND_MIN, FRIEND_MAX)
	_spawn_delta(amount)
	_refresh_selection()
	_notify_if_changed(was_following)


## 呼叫是與狗的互動。尚未陷入恐懼時，把友善值拉到友善門檻。
func on_dog_call() -> void:
	if friendliness <= FEAR_AT:
		return
	var was_following := is_following()
	if friendliness < FRIEND_AT:
		friendliness = FRIEND_AT
	_refresh_selection()
	_notify_if_changed(was_following)


func _notify_if_changed(was_following: bool) -> void:
	var now_following := is_following()
	if was_following == now_following:
		return
	_notify_follow(now_following)


func _notify_follow(following: bool) -> void:
	if _body == null or not is_instance_valid(_body):
		return
	var portraits: Array[Node] = get_tree().get_nodes_in_group("follow_portraits")
	for portrait in portraits:
		if portrait.has_method("set_following"):
			portrait.call("set_following", _body, following)


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
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	var dog := scene.find_child("dog_alex", true, false)
	if dog == null or not dog.has_method("refresh_selection"):
		return
	if dog.get("selected_unit") == _body or dog.get("selected_unit") == self:
		dog.refresh_selection()
