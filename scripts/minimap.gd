class_name Minimap
extends Control

## Minimap áp sương mù GIỐNG HỆT map chính, theo dữ liệu sương mù của người chơi:
## ô đen / mờ / sáng; quân địch chỉ hiện chấm khi ô đang SÁNG; công trình địch
## hiện khi đã khám phá (snapshot), thành địch chưa lộ diện thì không có chấm.

var game: Node = null
var _redraw_timer: float = 0.0

func _process(delta: float) -> void:
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = 0.3
		queue_redraw()

func _to_map(pos: Vector2) -> Vector2:
	return Vector2(pos.x / 1280.0 * size.x, pos.y / 640.0 * size.y)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03))
	if game == null:
		return
	var fog: FogOfWar = game.fogs[0]
	var cw := size.x / fog.cols
	var ch := size.y / fog.rows
	for y in fog.rows:
		for x in fog.cols:
			var i := y * fog.cols + x
			var col := Color(0, 0, 0)
			if fog.visible_now[i] == 1:
				col = Color(0.4, 0.58, 0.3)
			elif fog.explored[i] == 1:
				col = Color(0.2, 0.28, 0.17)
			draw_rect(Rect2(x * cw, y * ch, cw + 1, ch + 1), col)
	# Điểm tài nguyên đã khám phá.
	for n in get_tree().get_nodes_in_group("res_nodes"):
		var node := n as ResourceNode
		if fog.is_explored_pos(node.global_position):
			var c := Color(0.3, 0.7, 0.3) if node.res_type == "wood" else (Color(0.6, 0.6, 0.6) if node.res_type == "stone" else Color(0.95, 0.8, 0.2))
			draw_circle(_to_map(node.global_position), 2.0, c)
	# Công trình: của mình luôn hiện; của địch chỉ khi đã khám phá.
	for n in get_tree().get_nodes_in_group("structures"):
		var s := n as Structure
		var col: Color = Stats.FACTION_COLORS[s.color_key]
		if s.owner_pid != 0:
			if not fog.is_explored_pos(s.global_position):
				continue
			if s.disp_destroyed():
				col = Color(0.35, 0.35, 0.35)
		var sz := 7.0 if s is Castle else 4.0
		draw_rect(Rect2(_to_map(s.global_position) - Vector2(sz, sz) / 2, Vector2(sz, sz)), col)
	# Quân: của mình luôn hiện; địch chỉ khi ô đang SÁNG.
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u.owner_pid != 0 and not fog.is_visible_pos(u.global_position):
			continue
		draw_circle(_to_map(u.global_position), 2.0, Stats.FACTION_COLORS[u.color_key])
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.6), false, 1.0)
