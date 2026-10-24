class_name FogOfWar
extends RefCounted

## Sương mù RIÊNG của 1 phe: lưới ô phủ map, 3 trạng thái:
## 0 = ĐEN (chưa khám phá), 1 = MỜ (đã khám phá, không tầm nhìn), 2 = SÁNG (đang có tầm nhìn).
## explored lưu bền; visible_now tính lại mỗi chu kỳ từ tầm nhìn các đơn vị/công trình của phe.

var cols: int = 0
var rows: int = 0
var cell: float = 32.0
var explored: PackedByteArray = PackedByteArray()
var visible_now: PackedByteArray = PackedByteArray()

func setup(world_size: Vector2, p_cell: float) -> void:
	cell = p_cell
	cols = int(ceil(world_size.x / cell))
	rows = int(ceil(world_size.y / cell))
	explored.resize(cols * rows)
	visible_now.resize(cols * rows)

func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(clampi(int(pos.x / cell), 0, cols - 1), clampi(int(pos.y / cell), 0, rows - 1))

func _idx(c: Vector2i) -> int:
	return c.y * cols + c.x

func reset_visible() -> void:
	for i in visible_now.size():
		visible_now[i] = 0

func reveal_circle(pos: Vector2, radius: float) -> void:
	var min_c := cell_of(pos - Vector2(radius, radius))
	var max_c := cell_of(pos + Vector2(radius, radius))
	for y in range(min_c.y, max_c.y + 1):
		for x in range(min_c.x, max_c.x + 1):
			var center := Vector2(x * cell + cell * 0.5, y * cell + cell * 0.5)
			if center.distance_to(pos) <= radius:
				var i := y * cols + x
				visible_now[i] = 1
				explored[i] = 1

func state_at(pos: Vector2) -> int:
	var i := _idx(cell_of(pos))
	if visible_now[i] == 1:
		return 2
	if explored[i] == 1:
		return 1
	return 0

func is_explored_pos(pos: Vector2) -> bool:
	return explored[_idx(cell_of(pos))] == 1

func is_visible_pos(pos: Vector2) -> bool:
	return visible_now[_idx(cell_of(pos))] == 1
