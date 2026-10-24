extends SceneTree

## Test tự động CHỢ — BUÔN BÁN TÀI NGUYÊN tại Thành chính (Team 3):
##   mkt_a) bán 1 gói gỗ ở giá gốc: -100 gỗ, +70 vàng, factor 1.0 -> 0.92,
##          giá bán mới = 64; sổ khớp bất biến (resources == thành + Σ kho)
##   mkt_b) bán tiếp: giá chốt theo factor đã trôi (64), factor -> 0.8464,
##          giá mới = 59; hết gỗ -> bán bị chặn "not_enough_resource";
##          giá của PHE KHÁC không đổi (thị trường riêng từng phe);
##          vàng không phải hàng giao dịch được
##   mkt_c) mua đá bằng vàng: giá 100 -> factor 1.08 -> giá 108 -> 117;
##          vàng không đủ -> chặn "not_enough_gold"
##   mkt_d) hồi giá: tick_market thu hẹp độ lệch 1% mỗi 5s (cấp số nhân)
##          + giá tự hồi trong trận đang chạy thật
##   mkt_e) chặn theo SỨC CHỨA: thành đã sập + kho vàng đầy -> bán bị chặn
##          "no_space_gold"; kho gỗ đầy -> mua bị chặn "no_space_resource"
##   mkt_f) sổ TÁCH (thành + kho chuyên dụng): bán trừ thành trước rồi tới
##          kho, vàng nhận cộng vào thành — bất biến giữ nguyên
##   mkt_g) BOT: kẹt vàng + có hàng dư -> bot tự bán (trades_total >= 1,
##          factor trôi); vàng dư dả -> bot KHÔNG bán gì cả
## Chạy: godot --headless --script tests/test_market.gd

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
	g.bots_enabled = with_bots # gán TRƯỚC add_child (như test_store)
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

func _ledger_ok(g, pid: int) -> bool:
	var p = g.get_player(pid)
	var tot: Dictionary = g.total_stored(pid)
	for k in ["wood", "stone", "gold", "meat"]:
		if int(p.resources[k]) != int(tot[k]):
			return false
	return true

func _building(g, pid: int, btype: String) -> Building:
	for n in get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.building_type == btype:
			return b
	return null

func _place_done(g, p, btype: String, pos: Vector2) -> Building:
	if not g.exec_place_building(p, btype, pos):
		return null
	var b := _building(g, p.pid, btype)
	if b != null:
		b.constructed = true
		b._refresh_display()
	return b

## Đóng băng nông dân 1 phe: hết việc, tay không — số liệu test không bị
## nhiễu bởi lượt nộp farm tự nhiên giữa các lần chốt giao dịch.
func _freeze_villagers(g, pid: int) -> void:
	g.exec_set_allocation(g.get_player(pid), 0, 0, 0, 0)
	for n in get_nodes_in_group("villagers"):
		var v := n as Villager
		if v.owner_pid == pid:
			v.carrying = 0
			v.carrying_type = ""
			v.set_assignment("")

func _run() -> void:
	# ============ mkt_a + mkt_b + mkt_c) Chuỗi giá trôi 1 phe ============
	var g = await _new_game(false)
	await _wait(0.5)
	var p0 = g.get_player(0)
	var ctrl0 = g.controllers[0]
	_freeze_villagers(g, 0)
	var ok_start := _ledger_ok(g, 0) and int(p0.resources["wood"]) == 200 and int(p0.resources["gold"]) == 200
	# --- a) bán gói đầu ở giá gốc qua đường PlayerController ---
	var sold1: bool = ctrl0.market_sell("wood")
	var f1 := float(p0.market_factor["wood"])
	_check("mkt_a", ok_start and sold1 and int(p0.resources["wood"]) == 100
		and int(p0.resources["gold"]) == 270 and absf(f1 - 0.92) < 0.01
		and g.market_sell_price(0, "wood") == 64 and _ledger_ok(g, 0),
		"bán gói 1: gỗ 200->%d, vàng 200->%d (+70 giá gốc), factor=%.4f (0.92), giá mới=%d (64), sổ khớp=%s" % [
			int(p0.resources["wood"]), int(p0.resources["gold"]), f1,
			g.market_sell_price(0, "wood"), str(_ledger_ok(g, 0))])
	# --- b) bán tiếp: chốt giá 64, trôi tiếp; hết hàng thì chặn ---
	var gold_before2 := int(p0.resources["gold"])
	var sold2: bool = ctrl0.market_sell("wood")
	var f2 := float(p0.market_factor["wood"])
	var sold3: bool = ctrl0.market_sell("wood") # gỗ đã 0 -> phải bị chặn
	_check("mkt_b", sold2 and not sold3 and int(p0.resources["wood"]) == 0
		and int(p0.resources["gold"]) == gold_before2 + 64 and absf(f2 - 0.8464) < 0.01
		and g.market_sell_price(0, "wood") == 59
		and ctrl0.market_block_reason("wood", true) == "not_enough_resource"
		and g.market_sell_price(1, "wood") == 70 and absf(float(g.get_player(1).market_factor["wood"]) - 1.0) < 0.0001
		and not ctrl0.market_sell("gold") and _ledger_ok(g, 0),
		"bán gói 2 chốt +64 (vàng %d->%d), factor=%.4f (0.8464), giá mới=%d (59); bán gói 3 bị chặn=%s; phe khác giá vẫn 70/factor 1.0; bán 'gold' bị từ chối; sổ khớp=%s" % [
			gold_before2, int(p0.resources["gold"]), f2, g.market_sell_price(0, "wood"),
			str(not sold3), str(_ledger_ok(g, 0))])
	# --- c) mua đá: giá đội dần 100 -> 108 -> 117, hết vàng thì chặn ---
	var gold_c0 := int(p0.resources["gold"]) # 334
	var b1: bool = ctrl0.market_buy("stone")
	var price_after1: int = g.market_buy_price(0, "stone")
	var b2: bool = ctrl0.market_buy("stone")
	var price_after2: int = g.market_buy_price(0, "stone")
	var b3: bool = ctrl0.market_buy("stone")
	var b4: bool = ctrl0.market_buy("stone") # vàng còn 9 < giá 126 -> chặn
	_check("mkt_c", b1 and b2 and b3 and not b4
		and int(p0.resources["gold"]) == gold_c0 - 100 - 108 - 117
		and int(p0.resources["stone"]) == 150 + 300
		and price_after1 == 108 and price_after2 == 117
		and ctrl0.market_block_reason("stone", false) == "not_enough_gold"
		and _ledger_ok(g, 0),
		"mua đá x3: vàng %d->%d (trừ 100/108/117), đá 150->%d, giá sau mua1=%d (108), sau mua2=%d (117); mua lần 4 bị chặn hết vàng=%s; sổ khớp=%s" % [
			gold_c0, int(p0.resources["gold"]), int(p0.resources["stone"]),
			price_after1, price_after2, str(not b4), str(_ledger_ok(g, 0))])
	g.queue_free()
	await _wait(0.3)

	# ================= mkt_d) Hồi giá theo thời gian ====================
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	p0.market_factor["wood"] = 0.5
	p0.tick_market(5.0) # 1 nhịp hồi: lệch -0.5 -> -0.5 * 0.99
	var f_d1 := float(p0.market_factor["wood"])
	p0.tick_market(45.0) # tổng 50s: lệch = -0.5 * 0.99^10
	var f_d2 := float(p0.market_factor["wood"])
	var expect_d2 := 1.0 - 0.5 * pow(0.99, 10.0)
	# Trong trận thật: Main._process tự tick — để yên là giá nhích về gốc.
	# (create_timer đếm giây giờ game: chờ 6s game -> lệch -0.5 * 0.99^(6/5).)
	p0.market_factor["stone"] = 0.5
	await _wait(6.0)
	var f_live := float(p0.market_factor["stone"])
	_check("mkt_d", absf(f_d1 - 0.505) < 0.001 and absf(f_d2 - expect_d2) < 0.001
		and f_live > 0.504 and f_live < 0.60,
		"hồi giá: 0.5 -(5s)-> %.4f (0.505), -(50s)-> %.4f (kỳ vọng %.4f); trong trận tự hồi lên %.4f sau 6s game" % [
			f_d1, f_d2, expect_d2, f_live])
	g.queue_free()
	await _wait(0.3)

	# ================= mkt_e) Chặn theo sức chứa =======================
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	_freeze_villagers(g, 0)
	var slots0: Array = g.build_slots(0)
	var store_wood := _place_done(g, p0, "store_wood", slots0[6])
	var store_gold := _place_done(g, p0, "store_gold", slots0[7])
	# Sân khấu cực đoan: THÀNH SẬP (hết chỗ chứa vô hạn), 2 kho đều ĐẦY.
	g.castles[0].force_ruin()
	store_wood.stored["wood"] = 500
	store_gold.stored["gold"] = 500
	g.castles[0].stored = {"wood": 0, "stone": 0, "gold": 0, "meat": 0}
	p0.resources["wood"] = 500
	p0.resources["gold"] = 500
	p0.resources["stone"] = 0 # đá/thịt cháy theo thành trong sân khấu này
	p0.resources["meat"] = 0
	var ledger_e := _ledger_ok(g, 0)
	var sell_blocked: bool = not g.exec_market_sell(p0, "wood")
	var sell_reason: String = g.market_block_reason(p0, "wood", true)
	var buy_blocked: bool = not g.exec_market_buy(p0, "wood")
	var buy_reason: String = g.market_block_reason(p0, "wood", false)
	_check("mkt_e", store_wood != null and store_gold != null and ledger_e
		and sell_blocked and sell_reason == "no_space_gold"
		and buy_blocked and buy_reason == "no_space_resource"
		and int(p0.resources["wood"]) == 500 and int(p0.resources["gold"]) == 500
		and _ledger_ok(g, 0),
		"thành sập + kho đầy: bán bị chặn=%s (lý do %s — hết chỗ nhận vàng), mua bị chặn=%s (lý do %s — hết chỗ chứa gỗ), số liệu nguyên vẹn, sổ khớp=%s" % [
			str(sell_blocked), sell_reason, str(buy_blocked), buy_reason, str(_ledger_ok(g, 0))])
	g.queue_free()
	await _wait(0.3)

	# ================= mkt_f) Sổ tách thành + kho ======================
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	_freeze_villagers(g, 0)
	slots0 = g.build_slots(0)
	store_wood = _place_done(g, p0, "store_wood", slots0[6]) # xây kho trừ 80 gỗ từ thành: thành còn 120
	# Chia sổ tay: thành 70 gỗ + Kho Gỗ 50 gỗ (tổng vẫn 120 như sổ thật).
	g.castles[0].stored["wood"] = 70
	store_wood.stored["wood"] = 50
	var sold_f: bool = g.exec_market_sell(p0, "wood")
	_check("mkt_f", store_wood != null and sold_f
		and g.castles[0].stored_amount("wood") == 0 and store_wood.stored_amount("wood") == 20
		and int(p0.resources["wood"]) == 20
		and g.castles[0].stored_amount("gold") == 270 and int(p0.resources["gold"]) == 270
		and _ledger_ok(g, 0),
		"bán 100 gỗ từ sổ tách: trừ THÀNH trước (70->0) rồi KHO (50->20), tổng gỗ=%d (20); +70 vàng vào thành (=%d); sổ khớp=%s" % [
			int(p0.resources["wood"]), g.castles[0].stored_amount("gold"), str(_ledger_ok(g, 0))])
	g.queue_free()
	await _wait(0.3)

	# ================= mkt_g) Bot dùng chợ ==============================
	g = await _new_game(true)
	await _wait(0.5)
	var p1 = g.get_player(1) # bot Vàng: kẹt vàng + dư gỗ -> phải bán
	g.castles[1].stored["gold"] = 0
	p1.resources["gold"] = 0
	g.castles[1].stored["wood"] = 1000
	p1.resources["wood"] = 1000
	var p2 = g.get_player(2) # bot Đỏ: vàng dư dả + dư gỗ -> KHÔNG được bán
	g.castles[2].stored["gold"] = 5000
	p2.resources["gold"] = 5000
	g.castles[2].stored["wood"] = 1000
	p2.resources["wood"] = 1000
	var t_g := await _sim_until(g, func() -> bool: return p1.market_trades_total >= 1, 40.0)
	await _wait(2.0) # thêm vài lượt quyết định cho bot Đỏ
	_check("mkt_g", t_g >= 0.0 and float(p1.market_factor["wood"]) <= 0.93
		and p2.market_trades_total == 0 and _ledger_ok(g, 1),
		"bot kẹt vàng đã bán sau %.0fs: trades=%d, factor gỗ=%.3f (<=0.93); bot dư vàng trades=%d (phải 0); sổ bot bán khớp=%s" % [
			t_g, p1.market_trades_total, float(p1.market_factor["wood"]),
			p2.market_trades_total, str(_ledger_ok(g, 1))])
	g.queue_free()

	print("==================================")
	if _failures.is_empty():
		print("ALL TESTS PASS")
		quit(0)
	else:
		print("TESTS FAILED: %d" % _failures.size())
		quit(1)
