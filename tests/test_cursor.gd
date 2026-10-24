extends SceneTree

## Test tự động CON TRỎ NGỮ CẢNH khi di chuột (hover):
##   cura) chọn nông dân + chuột lên CÂY đã khám phá -> ngữ cảnh "gather",
##         hover_target đúng cây đó, vòng nổi hiện.
##   curb) bỏ chọn nông dân -> "default", hết mục tiêu nổi, vòng nổi ẩn.
##   curc) chọn nông dân + chuột lên MỎ VÀNG LỚN giữa map (vùng ĐEN chưa
##         khám phá) -> "default" (không thấy thì không farm được).
##   curd) chọn nông dân + chuột lên CỪU đang SÁNG gần thành -> "gather",
##         hover_target là con cừu (đúng nhánh săn của click phải).
##   cure) đang ở chế độ đặt nhà -> placement thắng hover, không gather.
## Chạy: godot --headless --script tests/test_cursor.gd

var _failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _check(tag: String, cond: bool, msg: String) -> void:
	if cond:
		print("TEST %s: PASS — %s" % [tag, msg])
	else:
		_failures.append(tag)
		print("TEST %s: FAIL — %s" % [tag, msg])

func _new_game():
	var scene: PackedScene = load("res://scenes/main.tscn")
	var g = scene.instantiate()
	g.bots_enabled = false # gán TRƯỚC add_child — _ready đọc cờ này
	root.add_child(g)
	return g

func _find_node_near(res_type: String, big: bool, near: Vector2) -> ResourceNode:
	var best: ResourceNode = null
	var best_d := 1e9
	for n in get_nodes_in_group("res_nodes"):
		var rn := n as ResourceNode
		if rn == null or rn.res_type != res_type or rn.is_big != big:
			continue
		var d := rn.global_position.distance_to(near)
		if d < best_d:
			best_d = d
			best = rn
	return best

func _run() -> void:
	var g = _new_game()
	await _wait(0.3) # chờ dựng xong + sương mù chu kỳ đầu
	# Panel hướng dẫn tự mở đầu trận và CHE giữa màn hình: chừng nào nó còn
	# mở thì HUD làm chủ con trỏ (đúng luật ưu tiên) — đóng lại như người
	# chơi thật sẽ làm, nếu không mọi điểm hover đều bị tính là "trên UI".
	if g._hud != null and g._hud.has_method("close_help"):
		g._hud.close_help()
	var ctrl = g.human_controller()

	# Cây gỗ cạnh thành người chơi (370,735) — nằm trong tầm nhìn thành, đã
	# khám phá ngay đầu trận.
	var tree := _find_node_near("wood", false, Vector2(370, 735))
	_check("cur0", tree != null and g.is_pos_explored_for(0, tree.global_position),
		"tìm được cây gần thành và vùng đó đã khám phá")
	var villagers: Array = g._villagers_of(0)
	_check("cur0b", villagers.size() > 0, "có nông dân đầu trận để chọn (n=%d)" % villagers.size())

	# cura) nông dân + hover cây đã khám phá -> gather + vòng nổi hiện.
	ctrl.set_selection([villagers[0]])
	g.update_hover_cursor(tree.global_position)
	_check("cura", g.cursor_context == "gather" and g.hover_target == tree
		and g._hover_ring != null and g._hover_ring.visible,
		"ngữ cảnh=%s, mục tiêu đúng cây, vòng nổi hiện" % g.cursor_context)

	# curb) bỏ chọn -> default.
	ctrl.clear_selection()
	g.update_hover_cursor(tree.global_position)
	_check("curb", g.cursor_context == "default" and g.hover_target == null
		and g._hover_ring != null and not g._hover_ring.visible,
		"bỏ chọn nông dân: ngữ cảnh=%s, vòng nổi ẩn" % g.cursor_context)

	# curc) mỏ vàng lớn giữa map (960,460) — vùng ĐEN của người chơi.
	var mine := _find_node_near("gold", true, Vector2(960, 460))
	_check("curc0", mine != null and not g.is_pos_explored_for(0, mine.global_position),
		"mỏ giữa map tồn tại và CHƯA khám phá với người chơi")
	ctrl.set_selection([villagers[0]])
	g.update_hover_cursor(mine.global_position)
	_check("curc", g.cursor_context == "default" and g.hover_target == null,
		"hover mục tiêu trong sương mù đen: ngữ cảnh=%s (không đổi con trỏ)" % g.cursor_context)

	# curd) cừu đang SÁNG gần thành -> gather, mục tiêu là cừu.
	var sheep: Sheep = null
	for n in get_nodes_in_group("sheep"):
		var s := n as Sheep
		if s != null and s.home.distance_to(Vector2(455, 675)) < 12.0:
			sheep = s
	_check("curd0", sheep != null, "tìm được cừu gần thành người chơi")
	if sheep != null:
		sheep.global_position = sheep.home # ghim về điểm nhà cho khỏi phụ thuộc lang thang
		g._update_fog()
		_check("curd0b", (g.fogs[0] as FogOfWar).is_visible_pos(sheep.global_position),
			"cừu đang ở ô SÁNG của người chơi")
		g.update_hover_cursor(sheep.global_position)
		_check("curd", g.cursor_context == "gather" and g.hover_target == sheep,
			"hover cừu sáng: ngữ cảnh=%s, mục tiêu là cừu" % g.cursor_context)

	# cure) chế độ đặt nhà thắng hover.
	g.set_placement_mode("house")
	g.update_hover_cursor(tree.global_position)
	_check("cure", g.cursor_context == "placement" and g.hover_target == null,
		"đang đặt nhà: ngữ cảnh=%s, không gather" % g.cursor_context)
	g.cancel_modes()

	g.queue_free()
	print("==================================")
	if _failures.is_empty():
		print("ALL TESTS PASS")
		quit(0)
	else:
		print("TESTS FAILED: %d" % _failures.size())
		quit(1)
