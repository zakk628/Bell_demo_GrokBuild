extends Node3D
## 下陷那一格改由 FloorSink 承接。只清這一格，不刪 GridMap。

const SINK_CELL := Vector3i(1, 0, -4)


func _ready() -> void:
	var grid := get_parent().get_node_or_null("Floor") as GridMap
	if grid == null:
		push_error("RuinDressing 找不到 Floor")
		return
	if grid.get_cell_item(SINK_CELL) == -1:
		push_error("下陷格沒有地板可清")
		return
	grid.set_cell_item(SINK_CELL, -1)
