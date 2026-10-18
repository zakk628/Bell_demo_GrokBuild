extends Node
## 人類 locomotion。播放速度與移動倍率共用同一組係數，不改動畫資源。

enum MoveState { IDLE, WALK, RUN, SPRINT }

const IDLE_01 := "stdman_move00_idle_01"
const IDLE_02 := "stdman_move00_idle_02"
const IDLE_03 := "stdman_move00_idle_03"
const IDLE_04 := "stdman_move00_idle_04"
const WALK_ANIM := "stdman_move01_walk"
const RUN_ANIM := "stdman_move02_run"
const SPRINT_ANIM := "stdman_move03_sprint"

@export var walk_scale := 1.0
@export var run_scale := 1.5
@export var sprint_scale := 2.0
## 跟隨中回到閒置後，idle_01 播滿這段時間就改回初始閒置。建議 8～12 秒。
@export var follow_idle_timeout := 10.0

var initial_idle := ""
var _player: AnimationPlayer
var _state: MoveState = MoveState.IDLE
var _idle_kind := ""
var _idle_left := 0.0


func _ready() -> void:
	var root := get_parent()
	if root == null:
		push_error("LocomotionAnim 的父節點必須是角色根節點")
		return
	_player = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		push_error("角色根節點底下沒有 AnimationPlayer")
		return
	var pool: Array[String] = [IDLE_02, IDLE_03, IDLE_04]
	initial_idle = pool[randi() % pool.size()]
	_idle_kind = "initial"
	_play(initial_idle, 1.0)


func move_scale(state: MoveState) -> float:
	match state:
		MoveState.WALK:
			return walk_scale
		MoveState.SPRINT:
			return sprint_scale
		_:
			return run_scale


func set_move_state(state: MoveState) -> void:
	if state == MoveState.IDLE:
		return
	_idle_kind = ""
	_idle_left = 0.0
	_state = state
	var clip := RUN_ANIM
	var scale := run_scale
	match state:
		MoveState.WALK:
			clip = WALK_ANIM
			scale = walk_scale
		MoveState.RUN:
			clip = RUN_ANIM
			scale = run_scale
		MoveState.SPRINT:
			clip = SPRINT_ANIM
			scale = sprint_scale
	_play(clip, scale)


## from_follow：跟隨中停下時先播 idle_01；否則播初始閒置。
func set_idle(from_follow: bool) -> void:
	if from_follow:
		if _idle_kind == "follow" or _idle_kind == "settled":
			return
		_idle_kind = "follow"
		_idle_left = follow_idle_timeout
		_state = MoveState.IDLE
		_play(IDLE_01, 1.0)
		return
	if _idle_kind == "initial":
		return
	_idle_kind = "initial"
	_idle_left = 0.0
	_state = MoveState.IDLE
	_play(initial_idle, 1.0)


func _process(delta: float) -> void:
	if _idle_kind != "follow" or Engine.time_scale == 0.0:
		return
	_idle_left -= delta
	if _idle_left > 0.0:
		return
	_idle_kind = "settled"
	_state = MoveState.IDLE
	_play(initial_idle, 1.0)


func _play(anim_name: String, playback: float) -> void:
	if _player == null:
		return
	if not _player.has_animation(anim_name):
		push_error("AnimationPlayer 沒有 %s。現有：%s" % [anim_name, " ".join(_player.get_animation_list())])
		return
	var same := str(_player.current_animation) == anim_name and _player.is_playing() and is_equal_approx(_player.get_playing_speed(), playback)
	if same:
		return
	_player.speed_scale = 1.0
	_player.play(anim_name, 0.1, playback)
