extends Node3D
## 格子迷霧。視野內無霧；走過的格子留下變暗、去飽和；沒走過全黑。看見不會寫入經過。

enum State { CLEAR, EXPLORED, HIDDEN }

const DOG_RADIUS := 9.0
const FOLLOW_RADIUS := 5.0
const BLACK_HEIGHT := 2.8
const _Map := preload("res://GDScript/Scene/ruin_map.gd")

var _map: _Map
var _floors: Dictionary = {}
var _explored: Dictionary = {}
var _state: Dictionary = {}
var _visual: Dictionary = {}
var _black_mesh: BoxMesh
var _dim_mesh: BoxMesh
var _black_mat: StandardMaterial3D
var _dim_mat: ShaderMaterial
var _ready_done := false


func _ready() -> void:
	_map = get_parent() as _Map
	_black_mesh = BoxMesh.new()
	_black_mesh.size = Vector3(1, 1, 1)
	_dim_mesh = BoxMesh.new()
	_dim_mesh.size = Vector3(1, 1, 1)
	_black_mat = StandardMaterial3D.new()
	_black_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_black_mat.albedo_color = Color(0, 0, 0, 1)
	_black_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dim_mat = ShaderMaterial.new()
	_dim_mat.shader = _dim_shader()
	setup()


func setup() -> void:
	if _map == null or not _map.has_method("cell_center"):
		return
	for cell in _map.floor_cells:
		_floors[cell] = true
		if _visual.has(cell):
			continue
		var view := MeshInstance3D.new()
		view.name = "Fog_%d_%d" % [cell.x, cell.y]
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(view)
		_visual[cell] = view
		_state[cell] = -1
	_ready_done = true
	_refresh()


func state_of(cell: Vector2i) -> int:
	return int(_state.get(cell, State.HIDDEN))


func explored_keys() -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	for cell in _explored.keys():
		keys.append(cell)
	return keys


func _physics_process(_delta: float) -> void:
	if not _ready_done or Engine.time_scale == 0.0:
		return
	_refresh()


func _refresh() -> void:
	_mark_walked(_dog())
	for unit in _followers():
		_mark_walked(unit)
	for cell in _floors.keys():
		var next := State.HIDDEN
		if _is_clear(cell):
			next = State.CLEAR
		elif _explored.has(cell):
			next = State.EXPLORED
		if int(_state.get(cell, -1)) == next:
			continue
		_state[cell] = next
		_apply(cell, next)


func _mark_walked(body: Node3D) -> void:
	if body == null:
		return
	var cell: Vector2i = _map.world_to_cell(body.global_position)
	if _floors.has(cell):
		_explored[cell] = true


func _is_clear(cell: Vector2i) -> bool:
	var dog := _dog()
	if dog != null and _within(cell, dog.global_position, DOG_RADIUS):
		return true
	for unit in _followers():
		if _within(cell, unit.global_position, FOLLOW_RADIUS):
			return true
	return false


func _within(cell: Vector2i, origin: Vector3, radius: float) -> bool:
	var flat: Vector3 = _map.cell_center(cell) - origin
	flat.y = 0.0
	return flat.length() <= radius


func _apply(cell: Vector2i, state: int) -> void:
	var view := _visual[cell] as MeshInstance3D
	var center: Vector3 = _map.cell_center(cell)
	var foot := Vector2(_map.cell_size.x + 0.02, _map.cell_size.z + 0.02)
	if state == State.CLEAR:
		view.visible = false
		return
	view.visible = true
	if state == State.EXPLORED:
		view.mesh = _dim_mesh
		view.material_override = _dim_mat
		view.position = Vector3(center.x, 0.04, center.z)
		view.scale = Vector3(foot.x, 0.04, foot.y)
		return
	view.mesh = _black_mesh
	view.material_override = _black_mat
	view.position = Vector3(center.x, 0.02 + BLACK_HEIGHT * 0.5, center.z)
	view.scale = Vector3(foot.x, BLACK_HEIGHT, foot.y)


func _dog() -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		scene = _map
	if scene == null:
		return null
	return scene.find_child("dog_alex", true, false) as Node3D


func _followers() -> Array[Node3D]:
	var list: Array[Node3D] = []
	var dog := _dog()
	for node in get_tree().get_nodes_in_group("unit"):
		if node == dog or not node is Node3D:
			continue
		var body := node as Node3D
		var api: Node = body
		if not body.has_method("is_following"):
			var ai := body.get_node_or_null("FollowAI")
			if ai != null:
				api = ai
		if api.has_method("is_following") and bool(api.call("is_following")):
			list.append(body)
	return list


func _dim_shader() -> Shader:
	var shader := Shader.new()
	# 經過格：薄霧。保留畫面顏色，只壓對比並加一點地面噪點。
	shader.code = "shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, ambient_light_disabled, blend_mix;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

float fog_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 screen = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(screen, vec3(0.299, 0.587, 0.114));
	vec3 washed = mix(screen, vec3(luma), 0.35);
	vec3 fog = vec3(0.68, 0.72, 0.76);
	vec3 soft = mix(fog, washed, 0.62);
	soft = mix(vec3(0.58, 0.60, 0.63), soft, 0.78);
	vec2 ground = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float coarse = fog_hash(floor(ground * 5.0));
	float fine = fog_hash(floor(ground * 14.0) + vec2(19.0, 7.0));
	float grain = coarse * 0.65 + fine * 0.35 - 0.5;
	soft += grain * 0.055;
	ALBEDO = soft;
	ALPHA = clamp(0.58 + grain * 0.08, 0.46, 0.70);
}
"
	return shader
