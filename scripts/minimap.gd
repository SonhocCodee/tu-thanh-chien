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
	var w: Vector2 = game.WORLD if game != null else Vector2(1920, 960)
	return Vector2(pos.x / w.x * size.x, pos.y / w.y * size.y)

func _jump_to(click_pos: Vector2) -> void:
	if game == null:
		return
	var w: Vector2 = game.WORLD
	var world := Vector2(click_pos.x / size.x * w.x, click_pos.y / size.y * w.y)
	game.set_camera_to(world)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_jump_to(event.position)
		accept_event()
	elif event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_jump_to(event.position)
		accept_event()

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
				# M2: vùng MỜ sáng hơn rõ rệt so với ĐEN (0,0,0) để không
				# bị nhìn nhầm là "đen lại" — luật: đã khám phá thì chỉ mờ.
				col = Color(0.32, 0.42, 0.25)
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
	# Khung vùng camera đang nhìn (M2).
	if game != null and game.has_method("get_camera_pos"):
		var cam: Vector2 = game.get_camera_pos()
		var view_tl := _to_map(cam - Vector2(640, 360))
		var view_br := _to_map(cam + Vector2(640, 360))
		draw_rect(Rect2(view_tl, view_br - view_tl), Color(1, 0.9, 0.3, 0.95), false, 2.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.6), false, 1.0)
