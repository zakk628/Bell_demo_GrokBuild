extends Node

const SCAN_RADIUS := 10.0
const SCAN_SPREAD := 0.7
const HIGHLIGHT_HOLD := 1.2
const SCAN_COOLDOWN := 5.0

var _dog: Node3D
var _ring: MeshInstance3D
var _scan_time := -1.0
var _cooldown := 0.0
var _highlighted: Array[MeshInstance3D] = []


func _ready() -> void:
	_dog = get_parent() as Node3D
	_ring = MeshInstance3D.new()
	_ring.name = "ScanRing"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.08
	_ring.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.35, 0.9, 1.0, 0.28)
	_ring.material_override = mat
	_ring.position = Vector3(0, 0.15, 0)
	_ring.visible = false
	add_child(_ring)


func start_scan() -> void:
	if Engine.time_scale == 0.0 or _scan_time >= 0.0 or _cooldown > 0.0:
		return
	_clear_highlight()
	_scan_time = 0.0
	_ring.visible = true
	_ring.scale = Vector3(0.05, 1, 0.05)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)
	if _scan_time < 0.0:
		return
	_scan_time += delta
	var spread := clampf(_scan_time / SCAN_SPREAD, 0.0, 1.0)
	var radius := SCAN_RADIUS * spread
	_ring.scale = Vector3(maxf(radius, 0.05), 1.0, maxf(radius, 0.05))
	_highlight_within(radius)
	if _scan_time >= SCAN_SPREAD + HIGHLIGHT_HOLD:
		_scan_time = -1.0
		_ring.visible = false
		_clear_highlight()
		_cooldown = SCAN_COOLDOWN


func _highlight_within(radius: float) -> void:
	for group_name in ["unit", "item"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node == _dog or not node is Node3D:
				continue
			var body := node as Node3D
			var offset := body.global_position - _dog.global_position
			offset.y = 0.0
			if offset.length() > radius:
				continue
			for mesh_node in body.find_children("*", "MeshInstance3D", true, false):
				var mesh := mesh_node as MeshInstance3D
				if mesh.name == "eye" or _highlighted.has(mesh):
					continue
				var overlay := StandardMaterial3D.new()
				overlay.albedo_color = Color(1.0, 0.92, 0.35, 1.0)
				overlay.emission_enabled = true
				overlay.emission = Color(1.0, 0.85, 0.2)
				overlay.emission_energy_multiplier = 1.4
				mesh.material_overlay = overlay
				_highlighted.append(mesh)


func _clear_highlight() -> void:
	for mesh in _highlighted:
		if is_instance_valid(mesh):
			mesh.material_overlay = null
	_highlighted.clear()
