extends Node
## 第 0 欄自動檔，1 起為手動檔。手動檔是紀錄點快照；自動檔再加上離開時的位置與之後的旗標。

const VERSION := 1
const AUTO_SLOT := 0
const MANUAL_SLOT_COUNT := 5
const CHECKPOINT_RANGE := 2.0
const SAVE_PATH := "user://rescue_bell_save.json"

var rescued_ids: Array[String] = []
var picked_ids: Array[String] = []
var checkpoint_id := ""
var last_manual_slot := 0

var _slots: Dictionary = {}
var _pending_position := Vector3.ZERO
var _pending_yaw := 0.0
var _has_pending := false


func _ready() -> void:
	_load_file()


func slot_count() -> int:
	return 1 + MANUAL_SLOT_COUNT


func slot_label(index: int) -> String:
	if index == AUTO_SLOT:
		return "自動存檔"
	return "Save%02d" % index


func has_slot(index: int) -> bool:
	return _slots.has(str(index))


func slot_summary(index: int) -> String:
	if not has_slot(index):
		return "空"
	var data: Dictionary = _slots[str(index)]
	var cp := str(data.get("checkpoint_id", ""))
	var pos: Array = data.get("position", [0, 0, 0])
	var where := "無關卡點" if cp == "" else cp
	return "%s  (%.1f, %.1f)" % [where, float(pos[0]), float(pos[2])]


func begin_new_run() -> void:
	rescued_ids = []
	picked_ids = []
	checkpoint_id = ""
	_has_pending = false


func add_rescued(id: String) -> void:
	if id != "" and id not in rescued_ids:
		rescued_ids.append(id)


func add_picked(id: String) -> void:
	if id != "" and id not in picked_ids:
		picked_ids.append(id)


func nearest_checkpoint() -> Node3D:
	var dog := _dog()
	if dog == null:
		return null
	var best: Node3D = null
	var best_distance := CHECKPOINT_RANGE
	for node in get_tree().get_nodes_in_group("checkpoint"):
		if not node is Node3D:
			continue
		var marker := node as Node3D
		var offset := marker.global_position - dog.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= best_distance:
			best = marker
			best_distance = distance
	return best


func write_manual_slot(index: int) -> String:
	if index < 1 or index > MANUAL_SLOT_COUNT:
		return "這一欄不能手動寫入"
	var marker := nearest_checkpoint()
	if marker == null:
		return "靠近紀錄點才能寫入手動檔"
	var dog := _dog()
	if dog == null:
		return "找不到狗"
	var cp_id := str(marker.get("checkpoint_id"))
	checkpoint_id = cp_id
	_slots[str(index)] = _make_record(cp_id, dog.global_position, dog.rotation.y)
	last_manual_slot = index
	_save_file()
	return ""


func write_auto_save() -> void:
	var dog := _dog()
	if dog == null:
		return
	var cp := checkpoint_id
	if last_manual_slot >= 1 and has_slot(last_manual_slot):
		cp = str(_slots[str(last_manual_slot)].get("checkpoint_id", cp))
	_slots[str(AUTO_SLOT)] = _make_record(cp, dog.global_position, dog.rotation.y)
	_save_file()


func load_slot(index: int) -> bool:
	if not has_slot(index):
		return false
	var data: Dictionary = _slots[str(index)]
	rescued_ids = _string_array(data.get("rescued_ids", []))
	picked_ids = _string_array(data.get("picked_ids", []))
	checkpoint_id = str(data.get("checkpoint_id", ""))
	var pos: Array = data.get("position", [0, 0, 0])
	_pending_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	_pending_yaw = float(data.get("yaw", 0.0))
	_has_pending = true
	var level := str(data.get("level", ""))
	if level == "":
		return false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(level)
	return true


func restart_from_last_manual() -> void:
	Engine.time_scale = 1.0
	if last_manual_slot >= 1 and has_slot(last_manual_slot):
		load_slot(last_manual_slot)
		return
	_has_pending = false
	rescued_ids = []
	picked_ids = []
	checkpoint_id = ""
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path != "":
		get_tree().reload_current_scene()


func take_pending_spawn() -> Dictionary:
	if not _has_pending:
		return {}
	_has_pending = false
	return {"position": _pending_position, "yaw": _pending_yaw}


func _make_record(cp_id: String, pos: Vector3, yaw: float) -> Dictionary:
	var scene := get_tree().current_scene
	var level := ""
	if scene != null:
		level = scene.scene_file_path
	return {
		"version": VERSION,
		"level": level,
		"checkpoint_id": cp_id,
		"rescued_ids": rescued_ids.duplicate(),
		"picked_ids": picked_ids.duplicate(),
		"position": [pos.x, pos.y, pos.z],
		"yaw": yaw,
		"enemies": [],
	}


func _dog() -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("dog_alex", true, false) as Node3D


func _save_file() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("無法寫入存檔")
		return
	var body := {
		"version": VERSION,
		"last_manual_slot": last_manual_slot,
		"slots": _slots,
	}
	file.store_string(JSON.stringify(body))


func _load_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var body: Dictionary = parsed
	last_manual_slot = int(body.get("last_manual_slot", 0))
	var slots: Variant = body.get("slots", {})
	if typeof(slots) == TYPE_DICTIONARY:
		_slots = slots


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(str(item))
	return result
