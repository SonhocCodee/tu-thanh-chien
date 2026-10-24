extends SceneTree

## Test headless M2 — Điều khiển chuẩn Đế Chế + camera + map lớn + luật sương mù mờ.
## Chạy: godot --headless --script tests/test_m2.gd
## In PASS/FAIL từng mục kèm số liệu; exit code 0 = đạt hết.
## (Map M2: WORLD 1920x960, thành 4 góc: (220,780) / (220,180) / (1700,180) / (1700,780).)

var _failures := 0
var _game: Node = null

func _initialize() -> void:
	_run()

func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("TEST ", name, ": PASS — ", detail)
	else:
		_failures += 1
		print("TEST ", name, ": FAIL — ", detail)

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _new_game(bots: bool, time_scale: float) -> Node:
	if _game != null and is_instance_valid(_game):
		root.remove_child(_game)
		_game.free()
	Engine.time_scale = time_scale
	paused = false
	_game = load("res://scenes/main.tscn").instantiate()
	_game.bots_enabled = bots
	root.add_child(_game)
	return _game

func _train_warriors(g: Node, pid: int, count: int) -> void:
	var p = g.get_player(pid)
	p.resources["gold"] = 5000
	var ctrl = g.controllers[pid]
	for i in count:
		ctrl.queue_training(g.castles[pid], "warrior")

func _own_warriors(g: Node) -> Array:
	var out: Array = []
	for n in get_nodes_in_group("units"):
		if (n as Unit).owner_pid == 0 and (n as Unit).is_alive():
			out.append(n)
	return out

func _run() -> void:
	# ============ m2a) Khung chọn: đúng quân mình trong vùng, loại quân địch ============
	var g = await _new_game(false, 20.0)
	await _wait(0.5)
	var ctrl0 = g.human_controller()
	_train_warriors(g, 0, 2)
	_train_warriors(g, 2, 1)
	var t := 0.0
	while t < 150.0 and (g.military_count(0) < 2 or g.military_count(2) < 1):
		await _wait(1.0)
		t += 1.0
	var n_sel: int = g.select_in_rect(Rect2(100, 650, 400, 300))
	var sel_has_enemy := false
	for n in ctrl0.get_selection():
		if (n as Node2D).get("owner_pid") != 0:
			sel_has_enemy = true
	var n_enemy_rect: int = g.select_in_rect(Rect2(1500, 150, 250, 200))
	var warriors := _own_warriors(g)
	var single_ok := false
	var empty_ok := false
	if not warriors.is_empty():
		g.click_select((warriors[0] as Unit).global_position)
		single_ok = ctrl0.get_selection().size() == 1
		g.click_select(Vector2(960, 480))
		empty_ok = ctrl0.get_selection().size() == 0
	_check("m2a", n_sel == 5 and not sel_has_enemy and n_enemy_rect == 0 and single_ok and empty_ok,
		"khung quanh căn cứ chọn=%d (đúng: 5 = 3 nông dân + 2 kiếm sĩ), lẫn địch=%s, khung vùng địch chọn=%d (đúng: 0), click 1 quân=%s, click đất trống bỏ chọn=%s" % [n_sel, str(sel_has_enemy), n_enemy_rect, str(single_ok), str(empty_ok)])

	# ============ m2b) Click phải đất = di chuyển tới đó ============
	g = await _new_game(false, 20.0)
	await _wait(0.5)
	ctrl0 = g.human_controller()
	_train_warriors(g, 0, 1)
	t = 0.0
	while t < 120.0 and g.military_count(0) < 1:
		await _wait(1.0)
		t += 1.0
	warriors = _own_warriors(g)
	var moved_ok := false
	var direct_ok := false
	var min_dist := 1e9
	if not warriors.is_empty():
		var w: Unit = warriors[0]
		g.click_select(w.global_position)
		var target := Vector2(900, 700)
		var d0 := w.global_position.distance_to(target)
		ctrl0.order_selected_move(target, true)
		direct_ok = w.direct_mode == "move"
		t = 0.0
		while t < 60.0:
			await _wait(0.5)
			t += 0.5
			var d := w.global_position.distance_to(target)
			if d < min_dist:
				min_dist = d
			if min_dist < 100.0:
				break
		moved_ok = min_dist < 100.0 and min_dist < d0 - 200.0
	_check("m2b", direct_ok and moved_ok,
		"lệnh trực tiếp move=%s, khoảng cách tới đích nhỏ nhất=%.0f (xuất phát cách đích, đã di chuyển tới gần)" % [str(direct_ok), min_dist])

	# ============ m2c) Click phải tài nguyên = farm đúng loại + hết lệnh về phân bổ ============
	g = await _new_game(false, 20.0)
	await _wait(0.5)
	ctrl0 = g.human_controller()
	var p0 = g.get_player(0)
	var wood_node: ResourceNode = null
	var best_d := 1e9
	for n in get_nodes_in_group("res_nodes"):
		var node := n as ResourceNode
		if node.res_type != "wood":
			continue
		var d := node.global_position.distance_to(Vector2(220, 780))
		if d < best_d:
			best_d = d
			wood_node = node
	var vil: Villager = null
	for n in get_nodes_in_group("villagers"):
		if (n as Villager).owner_pid == 0:
			vil = n
			break
	var farm_ok := false
	var delivered_ok := false
	var back_ok := false
	if vil != null and wood_node != null:
		g.click_select(vil.global_position)
		var n_farm: int = ctrl0.order_selected_farm(wood_node)
		farm_ok = n_farm == 1 and vil.direct and vil.direct_res == "wood" and vil.assigned == "wood"
		var wood0: int = p0.resources["wood"]
		t = 0.0
		while t < 120.0 and int(p0.resources["wood"]) <= wood0:
			await _wait(1.0)
			t += 1.0
		delivered_ok = int(p0.resources["wood"]) > wood0 and vil.direct
		# Mỏ biến mất -> nông dân hết lệnh trực tiếp, quay lại phân bổ.
		wood_node.queue_free()
		t = 0.0
		while t < 60.0 and vil.direct:
			await _wait(1.0)
			t += 1.0
		back_ok = not vil.direct and vil.assigned != ""
	_check("m2c", farm_ok and delivered_ok and back_ok,
		"lệnh farm trực tiếp=%s (đúng loại wood), giao gỗ tăng=%s, hết mỏ về phân bổ=%s (assigned=%s)" % [str(farm_ok), str(delivered_ok), str(back_ok), vil.assigned if vil != null else "?"])

	# ============ m2d) Click phải địch chưa lộ diện = bị từ chối; lộ diện rồi = được ============
	g = await _new_game(false, 20.0)
	await _wait(0.5)
	ctrl0 = g.human_controller()
	_train_warriors(g, 0, 1)
	t = 0.0
	while t < 120.0 and g.military_count(0) < 1:
		await _wait(1.0)
		t += 1.0
	warriors = _own_warriors(g)
	var rejected_ok := false
	var accepted_ok := false
	if not warriors.is_empty():
		var w: Unit = warriors[0]
		g.click_select(w.global_position)
		var red_castle: Castle = g.castles[2]
		rejected_ok = not ctrl0.order_selected_attack(red_castle) and w.direct_mode == ""
		ctrl0.order_move(Vector2(1620, 220))
		t = 0.0
		while t < 400.0 and not g.is_castle_revealed_for(0, 2):
			await _wait(2.0)
			t += 2.0
		if g.is_castle_revealed_for(0, 2):
			g.click_select(w.global_position)
			accepted_ok = ctrl0.order_selected_attack(red_castle) and w.direct_mode == "attack_struct"
	_check("m2d", rejected_ok and accepted_ok,
		"tấn công thành chưa lộ diện bị từ chối=%s, sau trinh sát lộ diện được chấp nhận=%s" % [str(rejected_ok), str(accepted_ok)])

	# ============ m2e) Camera kẹp biên map ============
	g = await _new_game(false, 20.0)
	await _wait(0.5)
	g.set_camera_to(Vector2(-500, -500))
	var c1: Vector2 = g.get_camera_pos()
	g.set_camera_to(Vector2(99999, 99999))
	var c2: Vector2 = g.get_camera_pos()
	g.set_camera_to(Vector2(960, 480))
	var c3: Vector2 = g.get_camera_pos()
	_check("m2e", c1 == Vector2(640, 360) and c2 == Vector2(1280, 600) and c3 == Vector2(960, 480),
		"kẹp góc trái-trên=%s (đúng: (640, 360)), kẹp góc phải-dưới=%s (đúng: (1280, 600)), giữa map=%s" % [str(c1), str(c2), str(c3)])

	# ============ m2f) Trận bot trên map lớn vẫn kết thúc có thắng thua ============
	g = await _new_game(true, 30.0)
	await _wait(0.5)
	t = 0.0
	while t < 2000.0 and not g.match_over:
		await _wait(5.0)
		t += 5.0
	var alive_count := 0
	for pid in [0, 1, 2, 3]:
		if g.get_player(pid).alive:
			alive_count += 1
	var bot_buildings := 0
	var bot_trained := 0
	var bot_attacks := 0
	for pid in [1, 2, 3]:
		var bp = g.get_player(pid)
		bot_buildings += bp.buildings_completed_total
		bot_trained += bp.units_trained_total
		bot_attacks += bp.attacks_launched_total
	_check("m2f", g.match_over and (g.player_won or not g.get_player(0).alive) and bot_buildings > 0 and bot_trained > 0 and bot_attacks > 0,
		"mô phỏng %.0fs game: match_over=%s, thắng=%s, phe còn sống=%d, bot xây=%d, luyện=%d, tấn công=%d" % [t, str(g.match_over), str(g.player_won), alive_count, bot_buildings, bot_trained, bot_attacks])

	# ============ m2g) Thành xa nhau + vùng đã khám phá chỉ mờ, không đen lại ============
	g = await _new_game(false, 20.0)
	await _wait(0.5)
	var min_castle_dist := 1e9
	var cps: Array = []
	for pid in g.CASTLE_POS.keys():
		cps.append(g.CASTLE_POS[pid])
	for i in cps.size():
		for j in range(i + 1, cps.size()):
			var d := (cps[i] as Vector2).distance_to(cps[j] as Vector2)
			if d < min_castle_dist:
				min_castle_dist = d
	ctrl0 = g.human_controller()
	_train_warriors(g, 0, 1)
	t = 0.0
	while t < 120.0 and g.military_count(0) < 1:
		await _wait(1.0)
		t += 1.0
	var fog0: FogOfWar = g.fogs[0]
	ctrl0.order_move(Vector2(960, 480))
	t = 0.0
	while t < 300.0 and not fog0.is_explored_pos(Vector2(960, 480)):
		await _wait(1.0)
		t += 1.0
	var explored_ok := fog0.is_explored_pos(Vector2(960, 480))
	ctrl0.set_stance("hold")
	t = 0.0
	while t < 300.0 and fog0.state_at(Vector2(960, 480)) != 1:
		await _wait(1.0)
		t += 1.0
	var dim_ok := fog0.state_at(Vector2(960, 480)) == 1 and fog0.is_explored_pos(Vector2(960, 480))
	_check("m2g", min_castle_dist >= 600.0 and explored_ok and dim_ok,
		"khoảng cách thành gần nhất=%.0f (tối thiểu 600; tầm nhìn 2 thành 530 không chạm nhau), giữa map đã khám phá=%s, rút quân xong trạng thái=%d (1=MỜ, không về 0=ĐEN)" % [min_castle_dist, str(explored_ok), fog0.state_at(Vector2(960, 480))])

	# ============ m2h) Lệnh trực tiếp ưu tiên hơn phân bổ ============
	g = await _new_game(false, 20.0)
	await _wait(0.5)
	ctrl0 = g.human_controller()
	var stone_node: ResourceNode = null
	best_d = 1e9
	for n in get_nodes_in_group("res_nodes"):
		var node := n as ResourceNode
		if node.res_type != "stone":
			continue
		var d := node.global_position.distance_to(Vector2(220, 780))
		if d < best_d:
			best_d = d
			stone_node = node
	vil = null
	for n in get_nodes_in_group("villagers"):
		if (n as Villager).owner_pid == 0:
			vil = n
			break
	var priority_ok := false
	var rejoin_ok := false
	if vil != null and stone_node != null:
		g.click_select(vil.global_position)
		ctrl0.order_selected_farm(stone_node)
		# Đổi phân bổ sang toàn vàng: nông dân direct farm đá vẫn giữ lệnh.
		ctrl0.set_villager_allocation(0, 0, 3)
		priority_ok = vil.direct and vil.direct_res == "stone"
		# Ra lệnh di chuyển (hủy direct) rồi đổi phân bổ: nông dân về phân bổ.
		ctrl0.order_selected_move(Vector2(400, 800), true)
		ctrl0.set_villager_allocation(2, 0, 1)
		rejoin_ok = not vil.direct and vil.assigned != ""
	_check("m2h", priority_ok and rejoin_ok,
		"đổi phân bổ không cướp lệnh trực tiếp=%s, hủy direct + đổi phân bổ thì về phân bổ=%s" % [str(priority_ok), str(rejoin_ok)])

	print("==================================")
	if _failures == 0:
		print("ALL TESTS PASS")
	else:
		print("TESTS FAILED: ", _failures)
	quit(1 if _failures > 0 else 0)
