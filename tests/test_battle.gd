extends SceneTree

## Test headless M1 — Lõi Đế Chế + Sương mù.
## Chạy: godot --headless --script tests/test_battle.gd
## In PASS/FAIL từng mục kèm số liệu; exit code 0 = đạt hết.

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
	_game = load("res://scenes/main.tscn").instantiate()
	_game.bots_enabled = bots
	root.add_child(_game)
	return _game

func _run() -> void:
	# ============ a) Nông dân khai thác thật ============
	var g = await _new_game(false, 20.0)
	await _wait(0.5)
	var p0 = g.get_player(0)
	var wood0: int = p0.resources["wood"]
	var gold0: int = p0.resources["gold"]
	var t := 0.0
	while t < 90.0 and p0.resources_gathered_total <= 0:
		await _wait(2.0)
		t += 2.0
	_check("a", p0.resources_gathered_total > 0 and (int(p0.resources["wood"]) > wood0 or int(p0.resources["gold"]) > gold0),
		"sau %.0fs mô phỏng: gỗ %d->%d, vàng %d->%d, tổng thu thập=%d" % [t, wood0, int(p0.resources["wood"]), gold0, int(p0.resources["gold"]), p0.resources_gathered_total])

	# ============ b) Xây Nhà -> giới hạn dân số tăng đúng stats ============
	var ctrl0 = g.human_controller()
	var cap0: int = g.pop_cap(0)
	var slots: Array = g.build_slots(0)
	var placed := ctrl0.place_building("house", slots[0])
	t = 0.0
	while t < 60.0 and g.pop_cap(0) <= cap0:
		await _wait(2.0)
		t += 2.0
	_check("b", placed and g.pop_cap(0) == cap0 + int(Stats.ECONOMY["pop_per_house"]),
		"đặt nhà=%s, giới hạn %d -> %d (mỗi nhà +%d)" % [str(placed), cap0, g.pop_cap(0), int(Stats.ECONOMY["pop_per_house"])])

	# ============ c) Huấn luyện: trừ đúng tài nguyên + chặn ở giới hạn ============
	p0.resources["gold"] = 5000
	p0.resources["wood"] = 5000
	var gold_before: int = p0.resources["gold"]
	var ok_train := ctrl0.queue_training(g.castles[0], "pawn")
	var gold_after: int = p0.resources["gold"]
	var cost_pawn: int = Stats.TRAINING["pawn"]["cost"]["gold"]
	var blocked := false
	var guard := 0
	while guard < 60:
		guard += 1
		var ok2: bool = ctrl0.queue_training(g.castles[0], "warrior")
		if not ok2:
			# Hết vàng thì không tính là chặn dân số; nạp thêm rồi thử lại.
			if not p0.can_afford(Stats.TRAINING["warrior"]["cost"]):
				p0.resources["gold"] = 5000
				continue
			blocked = g.pop_used(0) >= g.pop_cap(0)
			break
		await _wait(0.3)
	_check("c", ok_train and gold_before - gold_after == cost_pawn and blocked,
		"luyện nông dân trừ %d vàng (đúng stats=%d); bị chặn khi dân số %d/%d" % [gold_before - gold_after, cost_pawn, g.pop_used(0), g.pop_cap(0)])

	# ============ d) Tổng tấn công phá thành địch (có trinh sát lộ diện trước) ============
	g = await _new_game(false, 30.0)
	await _wait(0.5)
	p0 = g.get_player(0)
	ctrl0 = g.human_controller()
	p0.resources["gold"] = 9000
	p0.resources["wood"] = 9000
	p0.resources["stone"] = 9000
	slots = g.build_slots(0)
	ctrl0.place_building("house", slots[0])
	ctrl0.place_building("house", slots[3])
	t = 0.0
	while t < 500.0 and g.military_count(0) < 9:
		if g.castles[0].queue_count() < 4:
			ctrl0.queue_training(g.castles[0], "warrior")
		await _wait(2.0)
		t += 2.0
	var army: int = g.military_count(0)
	# Chưa lộ diện thì lệnh tấn công đích danh phải bị từ chối.
	var rejected := not ctrl0.set_stance("attack", 2)
	# Trinh sát tới gần thành Đỏ qua API di chuyển.
	ctrl0.order_move(Vector2(985, 215))
	t = 0.0
	while t < 400.0 and not g.is_castle_revealed_for(0, 2) and g.get_player(2).alive:
		await _wait(2.0)
		t += 2.0
	var revealed: bool = g.is_castle_revealed_for(0, 2)
	if g.get_player(2).alive and revealed:
		ctrl0.set_stance("attack", 2)
	t = 0.0
	while t < 700.0 and g.get_player(2).alive:
		await _wait(2.0)
		t += 2.0
	_check("d", army >= 9 and rejected and not g.get_player(2).alive,
		"quân=%d, lệnh tấn công khi chưa lộ diện bị từ chối=%s, lộ diện sau trinh sát=%s, thành Đỏ bị phá=%s" % [army, str(rejected), str(revealed), str(not g.get_player(2).alive)])

	# ============ e) Bot tự vận hành trọn trận mô phỏng ============
	g = await _new_game(true, 30.0)
	await _wait(0.5)
	t = 0.0
	while t < 1800.0 and not g.match_over:
		await _wait(5.0)
		t += 5.0
	var bot_buildings := 0
	var bot_trained := 0
	var bot_attacks := 0
	for pid in [1, 2, 3]:
		var bp = g.get_player(pid)
		bot_buildings += bp.buildings_completed_total
		bot_trained += bp.units_trained_total
		bot_attacks += bp.attacks_launched_total
	_check("e", bot_buildings > 0 and bot_trained > 0 and bot_attacks > 0,
		"mô phỏng %.0fs game (match_over=%s): bot xây xong=%d, huấn luyện=%d, tổng tấn công=%d" % [t, str(g.match_over), bot_buildings, bot_trained, bot_attacks])

	# ============ Sương mù: fa) trạng thái đầu trận ============
	g = await _new_game(false, 20.0)
	await _wait(0.6)
	var fog0: FogOfWar = g.fogs[0]
	var center_state: int = fog0.state_at(Vector2(640, 305))
	var home_state: int = fog0.state_at(Vector2(180, 470))
	_check("fa", center_state == 0 and home_state == 2,
		"ô giữa map=%d (0=ĐEN), ô quanh thành nhà=%d (2=SÁNG)" % [center_state, home_state])

	# ============ fb) Quân đi trinh sát -> vùng chuyển ĐÃ KHÁM PHÁ ============
	p0 = g.get_player(0)
	ctrl0 = g.human_controller()
	p0.resources["gold"] = 1000
	ctrl0.queue_training(g.castles[0], "warrior")
	t = 0.0
	while t < 120.0 and g.military_count(0) < 1:
		await _wait(1.0)
		t += 1.0
	ctrl0.order_move(Vector2(640, 305))
	t = 0.0
	while t < 200.0 and not fog0.is_explored_pos(Vector2(640, 305)):
		await _wait(1.0)
		t += 1.0
	_check("fb", fog0.is_explored_pos(Vector2(640, 305)),
		"sau %.0fs: ô giữa map đã khám phá, trạng thái hiện tại=%d (1=MỜ/2=SÁNG)" % [t, fog0.state_at(Vector2(640, 305))])

	# ============ fc) Quân địch trong vùng MỜ không hiển thị, vùng SÁNG thì hiện ============
	ctrl0.set_stance("hold")
	t = 0.0
	while t < 200.0 and fog0.state_at(Vector2(640, 305)) != 1:
		await _wait(1.0)
		t += 1.0
	var p2 = g.get_player(2)
	var ctrl2 = g.controllers[2]
	p2.resources["gold"] = 1000
	ctrl2.queue_training(g.castles[2], "warrior")
	t = 0.0
	while t < 120.0 and g.military_count(2) < 1:
		await _wait(1.0)
		t += 1.0
	var enemy_unit: Unit = null
	for n in get_tree().get_nodes_in_group("units"):
		if (n as Unit).owner_pid == 2:
			enemy_unit = n
			break
	var hidden_ok := false
	var shown_ok := false
	if enemy_unit != null:
		enemy_unit.global_position = Vector2(640, 305) # vùng MỜ của người chơi
		await _wait(0.8)
		hidden_ok = not enemy_unit.visible
		enemy_unit.global_position = Vector2(330, 470) # vùng SÁNG cạnh thành người chơi
		await _wait(0.8)
		shown_ok = enemy_unit.visible
	_check("fc", hidden_ok and shown_ok,
		"quân địch ở vùng MỜ: visible=%s (đúng: false); ở vùng SÁNG: visible=%s (đúng: true)" % [str(not hidden_ok), str(shown_ok)])

	print("==================================")
	if _failures == 0:
		print("ALL TESTS PASS")
	else:
		print("TESTS FAILED: ", _failures)
	quit(1 if _failures > 0 else 0)
