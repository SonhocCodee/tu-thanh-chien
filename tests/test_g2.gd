extends SceneTree

## Test tự động GIAI ĐOẠN 2 (M2) — hệ tài nguyên kiểu đế chế:
##   g2a) cây cạn -> đổ, CHỈ CÒN GỐC (sprite Stump), gốc không khai thác được nữa
##   g2b) quặng vàng nhỏ cạn -> biến mất; MỎ VÀNG lớn cạn -> hiện
##        GoldMine_Destroyed một lúc rồi biến mất
##   g2c) săn cừu -> xác thịt -> thịt CHỈ cộng sau khi vác về TỚI KHO
##   g2d) phá nhà địch KHÔNG cho vàng
##   g2e) bot hoàn thành trận trên hệ mới + có bot xây Nhà Kho + bot săn thịt
##        (đẻ thêm nông dân bằng thịt)
##   g2f) Nhà Kho được chọn làm điểm giao khi gần bãi farm hơn thành chính
## Chạy: godot --headless --script tests/test_g2.gd

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

func _new_game(with_bots: bool):
	var scene: PackedScene = load("res://scenes/main.tscn")
	var g = scene.instantiate()
	Engine.time_scale = 8.0
	g.bots_enabled = with_bots # gán TRƯỚC add_child (như test_battle) — _ready đọc cờ này
	root.add_child(g)
	return g

func _sim_until(g, cond: Callable, max_sec: float, step: float = 0.5) -> float:
	# create_timer chạy theo GIỜ GAME (đã chịu Engine.time_scale) nên mỗi
	# _wait(step) = step giây game — KHÔNG nhân time_scale nữa.
	var t := 0.0
	while t < max_sec:
		if cond.call():
			return t
		await _wait(step)
		t += step
	return -1.0

func _find_node(g, res_type: String, big: bool, near: Vector2) -> ResourceNode:
	var best: ResourceNode = null
	var best_d := 1e9
	for n in get_nodes_in_group("res_nodes"):
		var rn := n as ResourceNode
		if rn.res_type == res_type and rn.is_big == big:
			var d := rn.global_position.distance_to(near)
			if d < best_d:
				best_d = d
				best = rn
	return best

func _villager(g, pid: int, idx: int) -> Villager:
	var list: Array = []
	for n in get_nodes_in_group("villagers"):
		var v := n as Villager
		if v.owner_pid == pid:
			list.append(v)
	return list[idx] if idx < list.size() else null

func _run() -> void:
	# ================= g2a) Cây cạn -> còn gốc =================
	var g = await _new_game(false)
	await _wait(0.5)
	var p0 = g.get_player(0)
	var castle_pos: Vector2 = g.castles[0].global_position
	var tree := _find_node(g, "wood", false, castle_pos)
	tree.set_amount(15) # 2 chuyến là cạn
	var v0 := _villager(g, 0, 0)
	g.exec_direct_farm(p0, v0, tree)
	var t_a := await _sim_until(g, func() -> bool: return tree.is_depleted(), 90.0)
	await _wait(1.0) # chờ hoạt ảnh cây đổ xong -> hiện gốc
	_check("g2a", t_a >= 0.0 and is_instance_valid(tree) and tree.is_stump()
		and not get_nodes_in_group("res_nodes").has(tree),
		"cây cạn sau %.0fs: node còn tồn tại=%s, is_stump=%s, đã ra khỏi nhóm khai thác=%s" % [
			t_a, str(is_instance_valid(tree)), str(is_instance_valid(tree) and tree.is_stump()),
			str(not get_nodes_in_group("res_nodes").has(tree))])
	g.queue_free()
	await _wait(0.3)

	# ================= g2b) Mỏ cạn: nhỏ biến mất, lớn Destroyed rồi biến mất =====
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	castle_pos = g.castles[0].global_position
	var small_gold := _find_node(g, "gold", false, castle_pos)
	small_gold.set_amount(5)
	v0 = _villager(g, 0, 0)
	g.exec_direct_farm(p0, v0, small_gold)
	var t_b := await _sim_until(g, func() -> bool: return not is_instance_valid(small_gold), 90.0)
	var big_mine := _find_node(g, "gold", true, Vector2(960, 480))
	big_mine.set_amount(0) # cạn ngay -> phải hiện trạng thái Destroyed
	await _wait(0.3)
	var destroyed_tex := ""
	if is_instance_valid(big_mine) and big_mine.get("_sprite") != null:
		var spr := big_mine.get("_sprite") as Sprite2D
		if spr.texture != null:
			destroyed_tex = spr.texture.resource_path
	var t_b2 := await _sim_until(g, func() -> bool: return not is_instance_valid(big_mine), 30.0)
	_check("g2b", t_b >= 0.0 and destroyed_tex.ends_with("goldmine_destroyed.png") and t_b2 >= 0.0,
		"quặng nhỏ cạn -> biến mất=%s; mỏ lớn hiện sprite '%s' rồi biến mất sau đống đổ nát=%s" % [
			str(t_b >= 0.0), destroyed_tex, str(t_b2 >= 0.0)])
	g.queue_free()
	await _wait(0.3)

	# ================= g2c) Cừu -> thịt chỉ cộng SAU KHI về kho =================
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	p0.resources["meat"] = 0
	castle_pos = g.castles[0].global_position
	var sheep: Sheep = null
	var best_sd := 1e9
	for n in get_nodes_in_group("sheep"):
		var s := n as Sheep
		var d := s.global_position.distance_to(castle_pos)
		if d < best_sd:
			best_sd = d
			sheep = s
	v0 = _villager(g, 0, 0)
	var hunt_ok: bool = g.exec_direct_farm(p0, v0, sheep)
	var saw_carcass := false
	var meat_while_carrying := -1
	var t_c := 0.0
	while t_c < 120.0:
		await _wait(0.5)
		t_c += 0.5 * Engine.time_scale
		for n in get_nodes_in_group("res_nodes"):
			if (n as ResourceNode).res_type == "meat":
				saw_carcass = true
		if v0.carrying_type == "meat" and v0.carrying > 0 and meat_while_carrying < 0:
			meat_while_carrying = int(p0.resources["meat"])
		if int(p0.resources["meat"]) > 0:
			break
	_check("g2c", hunt_ok and saw_carcass and meat_while_carrying == 0 and int(p0.resources["meat"]) > 0,
		"lệnh săn=%s, có xác thịt=%s, thịt khi đang vác=%d (phải 0), thịt sau khi về kho=%d" % [
			str(hunt_ok), str(saw_carcass), meat_while_carrying, int(p0.resources["meat"])])
	g.queue_free()
	await _wait(0.3)

	# ================= g2d) Phá nhà địch không cho vàng =================
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	var p1 = g.get_player(1)
	p1.resources["wood"] = 1000
	var slots1: Array = g.build_slots(1)
	g.exec_place_building(p1, "house", slots1[0])
	var house: Building = null
	for n in get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == 1 and b.building_type == "house":
			house = b
	var gold_before := int(p0.resources["gold"])
	var gathered_before: int = p0.resources_gathered_total
	house.take_damage(99999.0, -1)
	await _wait(0.3)
	_check("g2d", house != null and not house.is_alive() and int(p0.resources["gold"]) == gold_before
		and p0.resources_gathered_total == gathered_before,
		"nhà địch bị phá=%s, vàng kẻ phá %d -> %d (không đổi), tổng thu thập không đổi=%s" % [
			str(house != null and not house.is_alive()), gold_before, int(p0.resources["gold"]),
			str(p0.resources_gathered_total == gathered_before)])
	g.queue_free()
	await _wait(0.3)

	# ================= g2f) Nhà Kho là điểm giao gần nhất =================
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	castle_pos = g.castles[0].global_position
	p0.resources["wood"] = 1000
	var gold_node := _find_node(g, "gold", false, castle_pos)
	var store_pos: Vector2 = castle_pos + Vector2(185, -140) # >=48px từ mọi node/cừu, trong vùng đã khám phá, gần mỏ vàng hơn thành
	var placed_store: bool = g.exec_place_building(p0, "storehouse", store_pos)
	var store: Building = null
	for n in get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == 0 and b.building_type == "storehouse":
			store = b
	if store != null:
		store.constructed = true # sân khấu: coi như xây xong ngay
	var drop_at_gold: Node2D = g.nearest_dropoff(0, gold_node.global_position)
	var drop_at_castle: Node2D = g.nearest_dropoff(0, castle_pos + Vector2(30, 30))
	_check("g2f", placed_store and store != null and drop_at_gold == store and drop_at_castle == g.castles[0],
		"đặt Nhà Kho=%s; điểm giao tại mỏ vàng=%s (phải là Nhà Kho), tại sát thành=%s (phải là thành chính)" % [
			str(placed_store),
			"Nhà Kho" if drop_at_gold == store else ("thành" if drop_at_gold == g.castles[0] else "?"),
			"thành chính" if drop_at_castle == g.castles[0] else "?"])
	g.queue_free()
	await _wait(0.3)

	# ================= g2e) Bot trọn trận trên hệ mới =================
	Engine.time_scale = 20.0
	g = await _new_game(true)
	await _wait(0.5)
	var saw_storehouse := false
	var saw_bot_villager4 := false
	var t := 0.0
	while t < 2400.0 and not g.match_over:
		await _wait(2.0)
		t += 2.0 # _wait đã theo giờ game (xem _sim_until)
		for n in get_nodes_in_group("buildings"):
			var b := n as Building
			if b.owner_pid != 0 and b.building_type == "storehouse":
				saw_storehouse = true
		for pid in [1, 2, 3]:
			if g.villager_count(pid) > 3:
				saw_bot_villager4 = true
	_check("g2e", g.match_over and saw_storehouse and saw_bot_villager4,
		"mô phỏng %.0fs game: match_over=%s, có bot xây Nhà Kho=%s, có bot đẻ nông dân thứ 4 (tốn thịt)=%s" % [
			t, str(g.match_over), str(saw_storehouse), str(saw_bot_villager4)])
	g.queue_free()

	print("==================================")
	if _failures.is_empty():
		print("ALL TESTS PASS")
		quit(0)
	else:
		print("TESTS FAILED: %d" % _failures.size())
		quit(1)
