extends Node
## 共用角色動畫。依名稱尋找 idle_01、walk、run、sprint，不改動畫資源。

enum MoveState { IDLE, WALK, RUN, SPRINT }

const WALK_SCALE := 1.0
const RUN_SCALE := 1.5
const SPRINT_SCALE := 2.0

var _player: AnimationPlayer
var _idle := ""
var _walk := ""
var _run := ""
var _sprint := ""
var _state: MoveState = MoveState.IDLE
var _reported_missing := false


func _ready() -> void:
	var root := get_parent()
	if root == null:
		push_error("Anime_Control 的父節點必須是角色根節點")
		return
	_player = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		push_error("角色根節點底下沒有 AnimationPlayer")
		return
	_idle = _find_clip("idle_01")
	_walk = _find_clip("walk")
	_run = _find_clip("run")
	_sprint = _find_clip("sprint")
	_report_missing()
	set_idle()


func move_scale(state: MoveState) -> float:
	match state:
		MoveState.WALK:
			return WALK_SCALE
		MoveState.SPRINT:
			return SPRINT_SCALE
		_:
			return RUN_SCALE


func set_move_state(state: MoveState) -> void:
	if state == MoveState.IDLE or _player == null:
		return
	_state = state
	var clip := _run
	var scale := RUN_SCALE
	match state:
		MoveState.WALK:
			clip = _walk
			scale = WALK_SCALE
		MoveState.RUN:
			clip = _run
			scale = RUN_SCALE
		MoveState.SPRINT:
			clip = _sprint
			scale = SPRINT_SCALE
	_play(clip, scale)


func set_idle() -> void:
	if _state == MoveState.IDLE and _player != null and _player.is_playing():
		return
	_state = MoveState.IDLE
	_play(_idle, 1.0)


func _find_clip(token: String) -> String:
	if _player == null:
		return ""
	var preferred: Array[String] = []
	var fallback: Array[String] = []
	for anim_name in _player.get_animation_list():
		var lower := String(anim_name).to_lower()
		if not lower.contains(token):
			continue
		if token == "idle_01" and lower.contains("climb"):
			continue
		if token == "run" and lower.contains("sprint"):
			continue
		if lower.contains("move"):
			preferred.append(anim_name)
		else:
			fallback.append(anim_name)
	var pool: Array[String] = preferred if not preferred.is_empty() else fallback
	if pool.is_empty():
		return ""
	pool.sort()
	return pool[0]


func _report_missing() -> void:
	if _reported_missing or _player == null:
		return
	var missing: Array[String] = []
	if _idle == "":
		missing.append("idle_01")
	if _walk == "":
		missing.append("walk")
	if _run == "":
		missing.append("run")
	if _sprint == "":
		missing.append("sprint")
	if missing.is_empty():
		return
	_reported_missing = true
	push_error("AnimationPlayer 缺少 %s。現有：%s" % ["、".join(missing), " ".join(_player.get_animation_list())])


func _play(anim_name: String, playback: float) -> void:
	if _player == null or anim_name == "":
		return
	if not _player.has_animation(anim_name):
		push_error("AnimationPlayer 沒有 %s" % anim_name)
		return
	var same := false
	if str(_player.current_animation) == anim_name and _player.is_playing():
		same = is_equal_approx(_player.get_playing_speed(), playback)
	if same:
		return
	_player.speed_scale = 1.0
	_player.play(anim_name, 0.1, playback)
