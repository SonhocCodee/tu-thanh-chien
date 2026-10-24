extends SceneTree

## Test tự động HỆ NHÀ LÍNH + GIỚI HẠN QUÂN + LÍNH TINH NHUỆ:
##   popa) đạt army cap -> luyện lính bị chặn, ĐÚNG LÝ DO "army" (không
##         phải dân số), không trừ tiền; nông dân vẫn luyện được.
##   popb) xây Nhà Lính -> army cap tăng đúng army_bonus SAU khi xây xong
##         (đang xây chưa tính).
##   popc) Lancer chiếm đúng 2 ô ở CẢ army cap LẪN dân số (kể cả khi còn
##         trong hàng chờ), ra quân thật với unit_type "lancer".
##   popd) phá Nhà Lính -> cap tụt, quân đang có còn nguyên, luyện thêm
##         bị chặn lại.
##   pope) bot trọn trận: có bot xây Nhà Lính, có bot luyện Lính giáo,
##         trận kết thúc có thắng thua.
## Chạy: godot --headless --script tests/test_pop.gd

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
	g.bots_enabled = with_bots # gán TRƯỚC add_child — _ready đọc cờ này
	root.add_child(g)
	return g

func _building(g, pid: int, btype: String) -> Building:
	for n in get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.building_type == btype:
			return b
	return null

func _rich(p) -> void:
	for k in Stats.RES_KEYS:
		p.resources[k] = 9000

func _run() -> void:
	# ================= popa) Army cap chặn + đúng lý do =================
	var g = await _new_game(false)
	await _wait(0.5)
	var p0 = g.get_player(0)
	var ctrl0 = g.human_controller()
	_rich(p0)
	var cap0: int = g.army_cap(0)
	var queued := 0
	while queued < 20 and ctrl0.queue_training(g.castles[0], "warrior"):
		queued += 1
	var gold_after_block := int(p0.resources["gold"])
	var blocked_again: bool = not ctrl0.queue_training(g.castles[0], "warrior")
	var reason: String = g.cap_block_reason(0, "warrior")
	var gold_unchanged: bool = int(p0.resources["gold"]) == gold_after_block
	var pawn_ok: bool = ctrl0.queue_training(g.castles[0], "pawn")
	_check("popa", queued == cap0 and blocked_again and reason == "army" and gold_unchanged and pawn_ok,
		"hàng chờ nhận %d kiếm sĩ = army cap nền %d; luyện thêm bị chặn=%s lý do=%s (phải 'army'); không trừ tiền=%s; nông dân vẫn luyện được=%s; dân số lúc đó %d/%d" % [
			queued, cap0, str(blocked_again), reason, str(gold_unchanged), str(pawn_ok), g.pop_used(0), g.pop_cap(0)])
	g.queue_free()
	await _wait(0.3)

	# ================= popb) Nhà Lính tăng cap đúng số =================
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	ctrl0 = g.human_controller()
	_rich(p0)
	var slots: Array = g.build_slots(0)
	var cap_before: int = g.army_cap(0)
	var placed: bool = ctrl0.place_building("soldier_house", slots[5])
	var house := _building(g, 0, "soldier_house")
	var cap_during: int = g.army_cap(0)
	var t := 0.0
	while t < 60.0 and (house == null or not house.constructed):
		await _wait(0.5)
		t += 0.5
	var bonus := int(Stats.BUILDINGS["soldier_house"]["army_bonus"])
	_check("popb", placed and house != null and cap_during == cap_before and house.constructed
		and g.army_cap(0) == cap_before + bonus,
		"đặt Nhà Lính=%s; cap khi đang xây=%d (phải = nền %d); cap sau khi xong=%d (phải = %d + %d)" % [
			str(placed), cap_during, cap_before, g.army_cap(0), cap_before, bonus])
	g.queue_free()
	await _wait(0.3)

	# ================= popc) Lancer = 2 ô ở cả hai hệ đếm =================
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	ctrl0 = g.human_controller()
	_rich(p0)
	slots = g.build_slots(0)
	ctrl0.place_building("barracks", slots[1])
	var barracks := _building(g, 0, "barracks")
	if barracks != null:
		barracks.constructed = true # sân khấu: coi như xây xong ngay
	var army0: int = g.army_used(0)
	var pop0_used: int = g.pop_used(0)
	var ok_lancer: bool = barracks != null and ctrl0.queue_training(barracks, "lancer")
	var army_queued: int = g.army_used(0)
	var pop_queued: int = g.pop_used(0)
	t = 0.0
	while t < 90.0 and g.unit_type_count(0, "lancer") < 1:
		await _wait(0.5)
		t += 0.5
	_check("popc", ok_lancer and army_queued - army0 == 2 and pop_queued - pop0_used == 2
		and g.unit_type_count(0, "lancer") == 1 and g.military_count(0) == 1 and g.army_used(0) - army0 == 2,
		"luyện lính giáo=%s; ô quân khi chờ +%d, dân số khi chờ +%d (phải đều 2); lính giáo ra trận=%d con (đầu), ô quân sau khi ra=%d" % [
			str(ok_lancer), army_queued - army0, pop_queued - pop0_used,
			g.unit_type_count(0, "lancer"), g.army_used(0) - army0])
	g.queue_free()
	await _wait(0.3)

	# ================= popd) Phá Nhà Lính: cap tụt, quân còn nguyên ======
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	ctrl0 = g.human_controller()
	_rich(p0)
	slots = g.build_slots(0)
	ctrl0.place_building("soldier_house", slots[5])
	house = _building(g, 0, "soldier_house")
	if house != null:
		house.constructed = true # sân khấu: xây xong ngay để cap lên 12
	var cap_raised: int = g.army_cap(0)
	# Sân khấu quân: 6 kiếm sĩ (6 ô) + 3 lính giáo (6 ô) = đầy 12 ô.
	for i in 6:
		g.spawn_trained_unit(0, "warrior", g.castles[0])
	for i in 3:
		g.spawn_trained_unit(0, "lancer", g.castles[0])
	await _wait(0.5)
	var army_full: int = g.army_used(0)
	var heads_before: int = g.military_count(0)
	house.take_damage(99999.0, -1)
	await _wait(0.3)
	var cap_fell: int = g.army_cap(0)
	var heads_after: int = g.military_count(0)
	var train_blocked: bool = not ctrl0.queue_training(g.castles[0], "warrior")
	var reason_d: String = g.cap_block_reason(0, "warrior")
	_check("popd", cap_raised == 12 and army_full == 12 and not house.is_alive()
		and cap_fell == 6 and heads_after == heads_before and heads_before == 9
		and train_blocked and reason_d == "army",
		"cap có Nhà Lính=%d, ô dùng=%d/12; phá xong: nhà sập=%s, cap=%d (phải 6), quân còn %d/%d đầu (phải nguyên), luyện thêm bị chặn=%s lý do=%s" % [
			cap_raised, army_full, str(not house.is_alive()), cap_fell,
			heads_after, heads_before, str(train_blocked), reason_d])
	g.queue_free()
	await _wait(0.3)

	# ================= pope) Bot trọn trận trên hệ mới =================
	Engine.time_scale = 20.0
	g = await _new_game(true)
	await _wait(0.5)
	var saw_house := false
	var saw_lancer := false
	t = 0.0
	while t < 2400.0 and not g.match_over:
		await _wait(2.0)
		t += 2.0 # _wait đã theo giờ game
		for pid in [1, 2, 3]:
			if int(g.building_counts(pid).get("soldier_house", 0)) > 0:
				saw_house = true
			if g.unit_type_count(pid, "lancer") > 0:
				saw_lancer = true
	_check("pope", g.match_over and saw_house and saw_lancer,
		"mô phỏng %.0fs game: match_over=%s, có bot xây Nhà Lính=%s, có bot luyện Lính giáo=%s" % [
			t, str(g.match_over), str(saw_house), str(saw_lancer)])
	g.queue_free()

	print("==================================")
	if _failures.is_empty():
		print("ALL TESTS PASS")
		quit(0)
	else:
		print("TESTS FAILED: %d" % _failures.size())
		quit(1)
