extends SceneTree

## Test tự động KHO CHUYÊN DỤNG + CƯỚP KHO (kiểu Clash of Clans):
##   store_a) dân vác VÀNG không nộp vào kho GỖ (đứng sát cửa cũng không),
##            chỉ cộng khi về đúng kho vàng/thành; farm tự nhiên từ mỏ vàng
##            -> nộp vào Kho Vàng (gần mỏ hơn thành)
##   store_b) kho vàng đầy 495/500: dân nộp nốt 5 cho đầy rồi vác phần còn
##            lại về THÀNH; kho đầy hẳn -> điểm giao vàng chỉ còn thành chính
##   store_c) BẤT BIẾN SỔ: resources của phe == thành + tổng các kho sau
##            mọi thao tác nộp/chi tiêu qua đường thật
##   store_d) CƯỚP KHO: phá Kho Vàng địch chứa 120 vàng -> kẻ phá +120,
##            nạn nhân -120, vào sổ thành của kẻ phá; phá nhà dân -> không gì
##   store_e) chi tiêu trừ THÀNH CHÍNH trước: mua nhà 100 gỗ, kho gỗ (đang
##            chứa 50) giữ nguyên, thành chịu đủ 100
## Chạy: godot --headless --script tests/test_store.gd

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
	g.bots_enabled = with_bots # gán TRƯỚC add_child (như test_battle)
	root.add_child(g)
	return g

func _sim_until(g, cond: Callable, max_sec: float, step: float = 0.5) -> float:
	var t := 0.0
	while t < max_sec:
		if cond.call():
			return t
		await _wait(step)
		t += step
	return -1.0

func _villager(g, pid: int, idx: int) -> Villager:
	var list: Array = []
	for n in get_nodes_in_group("villagers"):
		var v := n as Villager
		if v.owner_pid == pid:
			list.append(v)
	return list[idx] if idx < list.size() else null

func _building(g, pid: int, btype: String) -> Building:
	for n in get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.building_type == btype:
			return b
	return null

func _find_node(g, res_type: String, near: Vector2) -> ResourceNode:
	var best: ResourceNode = null
	var best_d := 1e9
	for n in get_nodes_in_group("res_nodes"):
		var rn := n as ResourceNode
		if rn.res_type == res_type:
			var d := rn.global_position.distance_to(near)
			if d < best_d:
				best_d = d
				best = rn
	return best

func _ledger_ok(g, pid: int) -> bool:
	var p = g.get_player(pid)
	var tot: Dictionary = g.total_stored(pid)
	for k in ["wood", "stone", "gold", "meat"]:
		if int(p.resources[k]) != int(tot[k]):
			return false
	return true

func _place_done(g, p, btype: String, pos: Vector2) -> Building:
	# Đặt kho qua đường exec thật rồi "xây xong ngay" kiểu sân khấu test.
	if not g.exec_place_building(p, btype, pos):
		return null
	var b := _building(g, p.pid, btype)
	if b != null:
		b.constructed = true
		b._refresh_display()
	return b

func _run() -> void:
	# ================= store_a) Vác vàng không nộp kho gỗ =================
	var g = await _new_game(false)
	await _wait(0.5)
	var p0 = g.get_player(0)
	var castle_pos: Vector2 = g.castles[0].global_position
	g.exec_set_allocation(p0, 0, 0, 0, 0) # các dân khác đứng yên, khỏi nhiễu số
	# Kho Vàng kê sát mỏ vàng: gần hơn thành ngay cả từ điểm dân đứng đào
	# (dân đứng lệch 34px về phía thành so với node nên phải tính cả lệch đó).
	var store_gold := _place_done(g, p0, "store_gold", castle_pos + Vector2(240, -10))
	var store_wood := _place_done(g, p0, "store_wood", castle_pos + Vector2(100, -20))
	# Dân 0: đứng SÁT cửa kho gỗ (36px), vác 10 vàng -> không được nộp ở đó.
	var v0 := _villager(g, 0, 0)
	v0.global_position = store_wood.global_position + Vector2(36, 0)
	v0.carrying = 10
	v0.carrying_type = "gold"
	v0.set_assignment("gold")
	await _wait(0.4) # đủ để chọn kho đích nhưng chưa đi tới nơi (kho vàng cách ~130px)
	var gold_early := int(p0.resources["gold"])
	var target_ok: bool = v0.get("_dropoff") == store_gold
	_check("store_a1", store_gold != null and store_wood != null and gold_early == 200
		and v0.carrying == 10 and store_wood.stored_amount("gold") == 0 and target_ok,
		"sát kho gỗ: vàng phe=%d (phải 200), còn vác=%d, kho gỗ chứa vàng=%d, kho đích=%s (phải Kho Vàng)" % [
			gold_early, v0.carrying, store_wood.stored_amount("gold"),
			"Kho Vàng" if target_ok else "khác"])
	var t_a := await _sim_until(g, func() -> bool: return int(p0.resources["gold"]) >= 210, 90.0)
	_check("store_a2", t_a >= 0.0 and store_gold.stored_amount("gold") == 10,
		"về đúng kho vàng: tổng vàng=%d (phải 210), sổ Kho Vàng=%d (phải 10), sau %.0fs" % [
			int(p0.resources["gold"]), store_gold.stored_amount("gold"), t_a])
	v0.set_assignment("")
	# Dân 1: farm tự nhiên từ mỏ vàng nhỏ -> kho gần nhất cho vàng = Kho Vàng.
	var gold_node := _find_node(g, "gold", castle_pos)
	var v1 := _villager(g, 0, 1)
	g.exec_direct_farm(p0, v1, gold_node)
	var t_a2 := await _sim_until(g, func() -> bool: return int(p0.resources["gold"]) >= 220, 120.0)
	_check("store_a3", t_a2 >= 0.0 and store_gold.stored_amount("gold") == 20
		and store_wood.stored_amount("gold") == 0 and _ledger_ok(g, 0),
		"farm tự nhiên: tổng vàng=%d (phải 220), sổ Kho Vàng=%d (phải 20), kho gỗ vẫn 0 vàng, sổ khớp=%s" % [
			int(p0.resources["gold"]), store_gold.stored_amount("gold"), str(_ledger_ok(g, 0))])
	g.queue_free()
	await _wait(0.3)

	# ================= store_b) Kho đầy -> chuyển điểm giao =================
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	castle_pos = g.castles[0].global_position
	g.exec_set_allocation(p0, 0, 0, 0, 0)
	store_gold = _place_done(g, p0, "store_gold", castle_pos + Vector2(185, -140))
	# Sân khấu sổ: kho vàng chứa sẵn 495 (tổng phe tăng tương ứng cho khớp sổ).
	store_gold.stored["gold"] = 495
	p0.resources["gold"] = 200 + 495
	gold_node = _find_node(g, "gold", castle_pos)
	var near_when_space: Node2D = g.nearest_dropoff(0, gold_node.global_position, "gold")
	v0 = _villager(g, 0, 0)
	v0.global_position = store_gold.global_position + Vector2(0, 50)
	v0.carrying = 10
	v0.carrying_type = "gold"
	v0.set_assignment("gold")
	var t_b := await _sim_until(g, func() -> bool: return v0.carrying == 0, 120.0)
	var near_when_full: Node2D = g.nearest_dropoff(0, gold_node.global_position, "gold")
	_check("store_b", store_gold != null and near_when_space == store_gold and t_b >= 0.0
		and store_gold.stored_amount("gold") == 500
		and int(p0.resources["gold"]) == 705
		and g.castles[0].stored_amount("gold") == 205
		and near_when_full == g.castles[0] and _ledger_ok(g, 0),
		"còn chỗ -> đích là Kho Vàng=%s; nộp xong: kho=%d/500, tổng=%d (695+10), thành=%d (200+5 phần dư), đầy hẳn -> đích=%s, sổ khớp=%s" % [
			str(near_when_space == store_gold), store_gold.stored_amount("gold"),
			int(p0.resources["gold"]), g.castles[0].stored_amount("gold"),
			"thành" if near_when_full == g.castles[0] else "khác", str(_ledger_ok(g, 0))])
	g.queue_free()
	await _wait(0.3)

	# ============ store_c + store_e) Bất biến sổ + trừ thành trước =========
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	g.exec_set_allocation(p0, 0, 0, 0, 0)
	var ok_start := _ledger_ok(g, 0)
	var slots0: Array = g.build_slots(0)
	store_wood = _place_done(g, p0, "store_wood", slots0[6]) # trừ 80 gỗ qua spend (ô [6] = ô Kho Gỗ trên main)
	var castle_wood_after_build: int = g.castles[0].stored_amount("wood")
	var put: int = g.deposit_to(store_wood, "wood", 50) # đường nộp thật của dân
	var ok_after_deposit := _ledger_ok(g, 0) and put == 50 and store_wood.stored_amount("wood") == 50
	# Mua nhà dân 100 gỗ (đắt hơn... không: thành đang có 120 gỗ > 100):
	# toàn bộ phải trừ từ THÀNH, kho gỗ giữ nguyên 50 (đây là store_e).
	var bought: bool = g.exec_place_building(p0, "house", slots0[0])
	_check("store_c", ok_start and store_wood != null and ok_after_deposit and bought
		and _ledger_ok(g, 0) and int(p0.resources["wood"]) == 200 - 80 + 50 - 100,
		"đầu trận sổ khớp=%s; xây kho -80 (thành còn %d gỗ); nộp 50 vào kho gỗ=%s; mua nhà xong tổng gỗ=%d (phải 70), sổ khớp=%s" % [
			str(ok_start), castle_wood_after_build, str(ok_after_deposit),
			int(p0.resources["wood"]), str(_ledger_ok(g, 0))])
	_check("store_e", bought and store_wood.stored_amount("wood") == 50
		and g.castles[0].stored_amount("wood") == 20,
		"chi tiêu trừ thành trước: sổ Kho Gỗ=%d (phải 50 — nguyên vẹn), sổ thành=%d (phải 20 = 120-100)" % [
			store_wood.stored_amount("wood"), g.castles[0].stored_amount("wood")])
	g.queue_free()
	await _wait(0.3)

	# ================= store_d) Cướp kho =================================
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	var p1 = g.get_player(1)
	g.exec_set_allocation(p0, 0, 0, 0, 0)
	g.exec_set_allocation(p1, 0, 0, 0, 0)
	var slots1: Array = g.build_slots(1)
	var enemy_store := _place_done(g, p1, "store_gold", slots1[7]) # ô [7] = ô Kho Vàng trên main
	# Sân khấu sổ phe địch: chuyển 120 vàng từ thành sang Kho Vàng (tổng giữ 200).
	enemy_store.stored["gold"] = 120
	g.castles[1].stored["gold"] = 80
	var p0_gold_before := int(p0.resources["gold"])
	var p1_gold_before := int(p1.resources["gold"])
	enemy_store.take_damage(99999.0, 0) # phe 0 là kẻ phá
	await _wait(0.3)
	var loot_ok: bool = not enemy_store.is_alive() and int(p0.resources["gold"]) == p0_gold_before + 120 \
		and int(p1.resources["gold"]) == p1_gold_before - 120 \
		and enemy_store.stored_amount("gold") == 0 \
		and g.castles[0].stored_amount("gold") == p0_gold_before + 120 \
		and _ledger_ok(g, 0) and _ledger_ok(g, 1)
	# Phá thêm nhà dân của địch -> không ai nhận gì.
	var house_ok: bool = g.exec_place_building(p1, "house", slots1[0])
	var enemy_house := _building(g, 1, "house")
	var snap0: Dictionary = p0.resources.duplicate()
	var snap1: Dictionary = p1.resources.duplicate()
	if enemy_house != null:
		enemy_house.take_damage(99999.0, 0)
	await _wait(0.3)
	var no_loot: bool = house_ok and enemy_house != null and not enemy_house.is_alive()
	for k in ["wood", "stone", "gold", "meat"]:
		if int(p0.resources[k]) != int(snap0[k]) or int(p1.resources[k]) != int(snap1[k]):
			no_loot = false
	_check("store_d", loot_ok and no_loot,
		"cướp kho: kẻ phá %d -> %d vàng (+120), nạn nhân %d -> %d (-120), sổ thành kẻ phá=%d, sổ 2 phe khớp; phá nhà dân không đổi tài nguyên=%s" % [
			p0_gold_before, int(p0.resources["gold"]), p1_gold_before, int(p1.resources["gold"]),
			g.castles[0].stored_amount("gold"), str(no_loot)])
	g.queue_free()

	print("==================================")
	if _failures.is_empty():
		print("ALL TESTS PASS")
		quit(0)
	else:
		print("TESTS FAILED: %d" % _failures.size())
		quit(1)
