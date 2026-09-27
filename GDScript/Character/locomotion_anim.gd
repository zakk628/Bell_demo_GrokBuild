extends Node
## 播現有 locomotion。速度只改播放端，不改動畫資源。

enum MoveState { IDLE, WALK, RUN, SPRINT }
enum IdlePhase { PRIMARY, BREAK }

const IDLE_01 := "alex_move00_idle_01"
const IDLE_02 := "alex_move00_idle_02"
const IDLE_03 := "alex_move00_idle_03"
const WALK_ANIM := "alex_move01_walk"
const RUN_ANIM := "alex_move02_run"
const SPRINT_ANIM := "alex_move03_sprint"
const WALK_PLAYBACK := 1.5
const RUN_PLAYBACK := 2.0
const SPRINT_PLAYBACK := 2.5
const IDLE_PLAYBACK := 1.0
const PRIMARY_LAPS := 10

var _player: AnimationPlayer
var _state: MoveState = MoveState.IDLE
var _busy := false
var _phase: IdlePhase = IdlePhase.PRIMARY
var _primary_clip := IDLE_01
var _primary_done := 0
var _break_target := 1
var _break_done := 0
var _prev_pos := 0.0
var _arm_wrap := false


func _ready() -> void:
	_player = get_node("../dog_alex_base/AnimationPlayer") as AnimationPlayer
	_player.speed_scale = 1.0
	_enter_idle()


func set_busy(busy: bool) -> void:
	if _busy == busy:
		return
	_busy = busy
	if _busy:
		return
	if _state == MoveState.IDLE:
		_enter_idle()
	else:
		_apply_move()


func set_move_state(state: MoveState) -> void:
	var changed := state != _state
	_state = state
	if _busy:
		return
	if state == MoveState.IDLE:
		if changed:
			_enter_idle()
		return
	if changed:
		_apply_move()


func _process(_delta: float) -> void:
	if _player == null or _busy or _state != MoveState.IDLE:
		return
	var anim_name := str(_player.current_animation)
	if anim_name != _primary_clip and anim_name != IDLE_02:
		return
	var pos := _player.current_animation_position
	if not _arm_wrap:
		_arm_wrap = true
		_prev_pos = pos
		return
	if pos + 0.02 < _prev_pos:
		_prev_pos = pos
		_on_idle_lap()
		return
	_prev_pos = pos


func _enter_idle() -> void:
	_phase = IdlePhase.PRIMARY
	_primary_done = 0
	_break_done = 0
	_break_target = 0
	_primary_clip = IDLE_01 if randi() % 2 == 0 else IDLE_03
	_play(_primary_clip, IDLE_PLAYBACK, true)


func _on_idle_lap() -> void:
	if _phase == IdlePhase.PRIMARY:
		_primary_done += 1
		if _primary_done < PRIMARY_LAPS:
			return
		_phase = IdlePhase.BREAK
		_break_target = randi_range(1, 3)
		_break_done = 0
		_play(IDLE_02, IDLE_PLAYBACK, true)
		return
	_break_done += 1
	if _break_done >= _break_target:
		_enter_idle()


func _apply_move() -> void:
	match _state:
		MoveState.WALK:
			_play(WALK_ANIM, WALK_PLAYBACK, false)
		MoveState.RUN:
			_play(RUN_ANIM, RUN_PLAYBACK, false)
		MoveState.SPRINT:
			_play(SPRINT_ANIM, SPRINT_PLAYBACK, false)
		_:
			pass


func _play(anim_name: String, playback: float, restart: bool) -> void:
	if not _player.has_animation(anim_name):
		push_error("AnimationPlayer 沒有 %s。現有：%s" % [anim_name, " ".join(_player.get_animation_list())])
		return
	var same := str(_player.current_animation) == anim_name and _player.is_playing() and is_equal_approx(_player.get_playing_speed(), playback)
	if same and not restart:
		return
	_player.speed_scale = 1.0
	_player.play(anim_name, 0.0, playback)
	_prev_pos = 0.0
	_arm_wrap = false
