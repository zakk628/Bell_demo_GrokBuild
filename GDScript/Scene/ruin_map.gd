extends Node3D
## 社區廢墟平面。35 個方塊進 GridMap，外框一圈牆，中央 16×16 可走。

const FLOOR_SCENE := "res://Assets/Floor/export_floor_a.glb"
const COLLISION_THICKNESS := 0.4
const SEAM_OVERLAP := 0.02
const INNER_MIN := -8
const INNER_MAX := 7
const CENTER_CELL := Vector2i(-1, -1)
const FOLLOWER_CELL := Vector2i(3, -1)
const JOHN_CELL := Vector2i(-5, 4)
const ADAM_CELL := Vector2i(2, -3)
const MASTER_CELL := Vector2i(-4, -4)
const BUDDHA_CELL := Vector2i(-2, 2)
const EXIT_CELL := Vector2i(6, 1)
const WALL_BELOW := 0.4
const WALL_TEXTURE := "res://Assets/Floor/export_floor_a_floor_A.jpg"

var cell_size := Vector3(2, 2, 2)
var floor_names: PackedStringArray = PackedStringArray()
var floor_cells: Array[Vector2i] = []
var frame_cells: Array[Vector2i] = []
var used_type_count := 0
var walk_surface_y := 0.0

var _built := false
var _floor_set: Dictionary = {}
var grid: GridMap


func _enter_tree() -> void:
	if _built:
		return
	_built = true
	grid = get_node("Floor") as GridMap
	_build_library()
	_paint_floors()
	_build_frame()
	_place_actors()


func cell_center(cell: Vector2i) -> Vector3:
	var local := grid.map_to_local(Vector3i(cell.x, 0, cell.y))
	return grid.position + Vector3(local.x, walk_surface_y - grid.position.y, local.z)


func world_to_cell(world_pos: Vector3) -> Vector2i:
	var mapped := grid.local_to_map(world_pos - grid.position)
	return Vector2i(mapped.x, mapped.z)


func is_floor_cell(cell: Vector2i) -> bool:
	return _floor_set.has(cell)


func _build_library() -> void:
	var packed := load(FLOOR_SCENE) as PackedScene
	if packed == null:
		push_error("找不到地板場景 %s" % FLOOR_SCENE)
		return
	var preview := packed.instantiate()
	var pattern := RegEx.new()
	pattern.compile("floor_A_(\\d+)")
	var found: Array[Dictionary] = []
	for node in preview.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var match := pattern.search(mesh_node.name)
		if match == null:
			continue
		var index := int(match.get_string(1))
		var duplicated := false
		for previous in found:
			if int(previous.index) == index:
				duplicated = true
				break
		if duplicated:
			continue
		found.append({
			"index": index,
			"mesh": mesh_node.mesh.duplicate(),
			"name": "floor_A_%02d" % index,
		})
	preview.free()
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.index) < int(b.index))
	if found.is_empty():
		push_error("export_floor_a 裡沒有 floor_A 網格")
		return

	var first := found[0].mesh as Mesh
	var bounds := first.get_aabb()
	for entry in found:
		var size := (entry.mesh as Mesh).get_aabb().size
		if absf(size.x - bounds.size.x) > 0.02 or absf(size.z - bounds.size.z) > 0.02:
			push_error("方塊 %s 的平面尺寸和其他不一致" % str(entry.name))
	# 垂直格距用平面模數（約 2 m）。薄片本身只有約 0.2 m，碰撞另補到 0.4 m。
	cell_size = Vector3(bounds.size.x, maxf(bounds.size.x, bounds.size.z), bounds.size.z)

	var top_y := bounds.position.y + bounds.size.y
	var shape := BoxShape3D.new()
	shape.size = Vector3(bounds.size.x + SEAM_OVERLAP, COLLISION_THICKNESS, bounds.size.z + SEAM_OVERLAP)
	var shape_origin := Vector3(bounds.get_center().x, top_y - COLLISION_THICKNESS * 0.5, bounds.get_center().z)
	var shapes: Array = [shape, Transform3D(Basis.IDENTITY, shape_origin)]

	var library := MeshLibrary.new()
	floor_names = PackedStringArray()
	for entry in found:
		var id := int(entry.index) - 1
		library.create_item(id)
		library.set_item_name(id, str(entry.name))
		library.set_item_mesh(id, entry.mesh)
		library.set_item_shapes(id, shapes)
		floor_names.append(str(entry.name))

	grid.cell_size = cell_size
	grid.cell_center_x = true
	grid.cell_center_y = true
	grid.cell_center_z = true
	grid.mesh_library = library
	var origin_local := grid.map_to_local(Vector3i.ZERO)
	walk_surface_y = 0.0
	grid.position = Vector3(0, -(origin_local.y + top_y), 0)


func _paint_floors() -> void:
	var used := {}
	for x in range(INNER_MIN, INNER_MAX + 1):
		for z in range(INNER_MIN, INNER_MAX + 1):
			var cell := Vector2i(x, z)
			var id := _item_for(cell)
			grid.set_cell_item(Vector3i(x, 0, z), id)
			floor_cells.append(cell)
			_floor_set[cell] = true
			used[id] = true
	used_type_count = used.size()


func _item_for(cell: Vector2i) -> int:
	var u := cell.x - INNER_MIN
	var v := cell.y - INNER_MIN
	var count := maxi(floor_names.size(), 1)
	return (2 * u + 3 * v) % count


func _build_frame() -> void:
	var outer_min := INNER_MIN - 1
	var outer_max := INNER_MAX + 1
	for x in range(outer_min, outer_max + 1):
		for z in range(outer_min, outer_max + 1):
			if x < INNER_MIN or x > INNER_MAX or z < INNER_MIN or z > INNER_MAX:
				frame_cells.append(Vector2i(x, z))

	var body := StaticBody3D.new()
	body.name = "Frame"
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.6, 0.56)
	material.roughness = 0.92
	var texture := load(WALL_TEXTURE) as Texture2D
	if texture != null:
		material.albedo_texture = texture
		material.uv1_scale = Vector3(0.35, 0.35, 1)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = box
	multi.instance_count = frame_cells.size()
	var visual := MultiMeshInstance3D.new()
	visual.name = "Walls"
	visual.material_override = material
	visual.multimesh = multi
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(visual)

	var foot_x := cell_size.x + SEAM_OVERLAP
	var foot_z := cell_size.z + SEAM_OVERLAP
	for i in frame_cells.size():
		var cell := frame_cells[i]
		var center := cell_center(cell)
		var rise := 1.35 + float(posmod(cell.x * 5 + cell.y * 3, 5)) * 0.14
		var total := rise + WALL_BELOW
		var mid_y := walk_surface_y - WALL_BELOW + total * 0.5
		multi.set_instance_transform(i, Transform3D(
			Basis.IDENTITY.scaled(Vector3(foot_x, total, foot_z)),
			Vector3(center.x, mid_y, center.z)
		))
		var shape := BoxShape3D.new()
		shape.size = Vector3(foot_x, total, foot_z)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(center.x, mid_y, center.z)
		body.add_child(collision)
	add_child(body)


func _place_actors() -> void:
	var dog := get_node_or_null("dog_alex") as Node3D
	if dog != null:
		var spawn := cell_center(CENTER_CELL)
		dog.position = Vector3(spawn.x, walk_surface_y, spawn.z)
	var unit := get_node_or_null("test_unit") as Node3D
	if unit != null:
		var spot := cell_center(FOLLOWER_CELL)
		unit.position = Vector3(spot.x, walk_surface_y + 0.05, spot.z)
	var marker := get_node_or_null("ruin_01") as Node3D
	if marker != null:
		var mark_at := cell_center(EXIT_CELL)
		marker.position = Vector3(mark_at.x, walk_surface_y + 0.5, mark_at.z)
	_place_on_floor("John", JOHN_CELL)
	_place_on_floor("Adam", ADAM_CELL)
	_place_on_floor("Latern_Master", MASTER_CELL)
	_place_on_floor("Latern_Buddha", BUDDHA_CELL)


func _place_on_floor(node_name: String, cell: Vector2i) -> void:
	var actor := get_node_or_null(node_name) as Node3D
	if actor == null:
		return
	var spot := cell_center(cell)
	actor.position = Vector3(spot.x, walk_surface_y, spot.z)
