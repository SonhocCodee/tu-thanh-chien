extends SceneTree

## Test headless — LỆNH RTS NÂNG CAO (port từ nhánh lenh-rts ae6b35d).
## Chạy: godot --headless --script tests/test_rts.gd
## rts1) Attack-move: diệt địch dọc đường -> tới đích -> giữ điểm (địch mới
##       tới gần điểm giữ vẫn bị đánh).
## rts2) Tuần tra: qua lại A<->B, diệt địch chắn giữa đường; lệnh mới huỷ.
## rts3) Hộ vệ: bám theo quân đồng minh đang di chuyển; phản ứng khi đối
##       tượng bị áp sát; hộ vệ công trình; đối tượng chết -> giữ điểm tại chỗ.
## rts4) Chọn toàn quân (không lẫn nông dân) + tìm nông dân nhàn rỗi
##       (xoay vòng + lia camera + hết nhàn khi tất cả có việc).
## rts5) Sương mù: attack-move KHÔNG đánh địch ngoài tầm nhìn/ô sáng.

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

func _spawn_unit(g: Node, pid: int, unit_type: String, pos: Vector2) -> Unit:
	var u := load("res://scenes/unit.tscn").instantiate() as Unit
	u.setup(pid, unit_type, g.get_player(pid).color_key, g, Vector2.ZERO)
	u.position = pos
	u.z_index = 10
	g.add_child(u)
	u.died.connect(g._on_unit_died)
	return u

func _gone_or_dead(u) -> bool:
	# Tham số KHÔNG typed: truyền object đã freed vào tham số typed Unit sẽ
	# lỗi runtime ngay tại lời gọi, trước khi thân hàm chạy (bẫy đã biết).
	return not is_instance_valid(u) or not (u as Unit).is_alive()

func _run() -> void:
	# ============ rts1) ATTACK-MOVE ============
	var g = await _new_game(false, 20.0)
	await _wait(0.5)
	var ctrl: PlayerController = g.controllers[0]
	var w := _spawn_unit(g, 0, "warrior", Vector2(560, 480))
	var dummy := _spawn_unit(g, 2, "warrior", Vector2(740, 480))
	dummy.hp = 60.0
	dummy.set_process(false) # địch thụ động: đứng yên hứng đòn trên đường đi
	ctrl.set_selection([w])
	var n1 := ctrl.order_selected_attack_move(Vector2(980, 480))
	var mode_ok := n1 == 1 and w.direct_mode == "attack_move"
	var t := 0.0
	var arrived := false
	while t < 40.0:
		await _wait(0.5)
		t += 0.5
		if _gone_or_dead(dummy) and w.global_position.distance_to(Vector2(980, 480)) <= 45.0:
			arrived = true
			break
	var dummy_dead := _gone_or_dead(dummy)
	var hold_ok := w.is_alive() and w.direct_mode == "attack_move"
	# Địch mới lảng vảng gần điểm giữ -> vẫn bị đánh (giữ điểm ≠ ngủ).
	var dummy2 := _spawn_unit(g, 2, "warrior", w.global_position + Vector2(95, 0))
	dummy2.hp = 45.0
	dummy2.set_process(false)
	t = 0.0
	var point_fight := false
	while t < 15.0:
		await _wait(0.5)
		t += 0.5
		if _gone_or_dead(dummy2) or dummy2.hp < 45.0:
			point_fight = true
			break
	_check("rts1", mode_ok and dummy_dead and arrived and hold_ok and point_fight,
		"lệnh qua controller=%s (mode=%s), địch dọc đường chết=%s, quân tới đích=%s, vẫn giữ điểm (mode attack_move)=%s, địch mới gần điểm giữ bị đánh=%s" % [
			str(mode_ok), w.direct_mode, str(dummy_dead), str(arrived), str(hold_ok), str(point_fight)])

	# ============ rts2) TUẦN TRA ============
	g = await _new_game(false, 20.0)
	await _wait(0.5)
	ctrl = g.controllers[0]
	var pw := _spawn_unit(g, 0, "warrior", Vector2(560, 300))
	var pdummy := _spawn_unit(g, 2, "warrior", Vector2(740, 300))
	pdummy.hp = 50.0
	pdummy.set_process(false)
	ctrl.set_selection([pw])
	var n2 := ctrl.order_selected_patrol(Vector2(920, 300))
	var pmode_ok := n2 == 1 and pw.direct_mode == "patrol" \
		and pw.patrol_a.distance_to(Vector2(560, 300)) < 1.0
	t = 0.0
	var reached_b := false
	var returned_a := false
	while t < 60.0:
		await _wait(0.5)
		t += 0.5
		if not reached_b and pw.global_position.distance_to(Vector2(920, 300)) <= 45.0:
			reached_b = true
		elif reached_b and pw.global_position.distance_to(Vector2(560, 300)) <= 60.0:
			returned_a = true
			break
	var pdummy_dead := _gone_or_dead(pdummy)
	# Lệnh mới bất kỳ -> huỷ tuần tra.
	ctrl.set_selection([pw])
	ctrl.order_selected_move(Vector2(700, 300), false)
	var cancel_ok := pw.direct_mode == "move"
	_check("rts2", pmode_ok and pdummy_dead and reached_b and returned_a and cancel_ok,
		"lệnh tuần tra=%s (A=vị trí ra lệnh), địch chắn đường chết=%s, tới B=%s, quay về A=%s, lệnh mới huỷ tuần tra (mode=%s)" % [
			str(pmode_ok), str(pdummy_dead), str(reached_b), str(returned_a), pw.direct_mode])

	# ============ rts3) HỘ VỆ ============
	g = await _new_game(false, 20.0)
	await _wait(0.5)
	ctrl = g.controllers[0]
	# (a) Bám theo quân đồng minh đang di chuyển.
	var ward := _spawn_unit(g, 0, "warrior", Vector2(900, 620))
	var guard := _spawn_unit(g, 0, "warrior", Vector2(820, 620))
	ctrl.set_selection([guard])
	var n3 := ctrl.order_selected_guard(ward)
	var gmode_ok := n3 == 1 and guard.direct_mode == "guard" and guard.guard_target == ward
	ctrl.set_selection([ward])
	ctrl.order_selected_move(Vector2(1300, 620), false)
	t = 0.0
	while t < 30.0:
		await _wait(0.5)
		t += 0.5
		if ward.global_position.distance_to(Vector2(1300, 620)) <= 35.0:
			break
	ward.set_process(false) # đóng băng đối tượng: từ đây chỉ hộ vệ hoạt động
	t = 0.0
	var follow_ok := false
	while t < 10.0:
		await _wait(0.5)
		t += 0.5
		if guard.global_position.distance_to(ward.global_position) <= 110.0:
			follow_ok = true
			break
	# (b) Địch áp sát đối tượng được hộ vệ -> hộ vệ phản ứng đánh.
	var threat := _spawn_unit(g, 2, "warrior", ward.global_position + Vector2(70, 0))
	threat.hp = 45.0
	threat.set_process(false)
	t = 0.0
	var react_ok := false
	while t < 15.0:
		await _wait(0.5)
		t += 0.5
		if _gone_or_dead(threat) or threat.hp < 45.0:
			react_ok = true
			break
	# (c) Hộ vệ CÔNG TRÌNH đồng minh: bám quanh thành mình.
	ctrl.set_selection([guard])
	var n3b := ctrl.order_selected_guard(g.castles[0])
	t = 0.0
	var struct_ok := false
	while t < 45.0:
		await _wait(0.5)
		t += 0.5
		if guard.direct_mode == "guard" \
			and guard.global_position.distance_to(g.castles[0].global_position) <= 78.0 + 34.0 + 45.0:
			struct_ok = true
			break
	# (d) Đối tượng chết -> giữ điểm TẠI CHỖ (không chạy về thành).
	var ward2 := _spawn_unit(g, 0, "warrior", Vector2(1000, 300))
	var guard2 := _spawn_unit(g, 0, "warrior", Vector2(930, 300))
	ctrl.set_selection([guard2])
	ctrl.order_selected_guard(ward2)
	await _wait(1.0)
	var spot := guard2.global_position
	ward2.take_damage(9999.0, 2)
	await _wait(1.0)
	var converted := guard2.direct_mode == "attack_move"
	t = 0.0
	var stay_ok := true
	while t < 6.0:
		await _wait(0.5)
		t += 0.5
		if guard2.global_position.distance_to(spot) > 130.0:
			stay_ok = false
			break
	var far_from_home := guard2.global_position.distance_to(g.castles[0].global_position) > 400.0
	_check("rts3", gmode_ok and follow_ok and react_ok and n3b == 1 and struct_ok and converted and stay_ok and far_from_home,
		"lệnh hộ vệ=%s, bám theo đối tượng di chuyển=%s, địch áp sát đối tượng bị đánh=%s, hộ vệ công trình=%s (n=%d), đối tượng chết -> chuyển giữ điểm=%s, ở yên tại chỗ=%s, không về thành=%s" % [
			str(gmode_ok), str(follow_ok), str(react_ok), str(struct_ok), n3b, str(converted), str(stay_ok), str(far_from_home)])

	# ============ rts4) CHỌN TOÀN QUÂN + NÔNG DÂN NHÀN ============
	g = await _new_game(false, 20.0)
	await _wait(0.5)
	ctrl = g.controllers[0]
	var m1 := _spawn_unit(g, 0, "warrior", Vector2(400, 700))
	var m2 := _spawn_unit(g, 0, "archer", Vector2(430, 700))
	var m3 := _spawn_unit(g, 0, "lancer", Vector2(460, 700))
	var n_all := ctrl.select_all_military()
	var sel := ctrl.get_selection()
	var all_ok := n_all == 3 and sel.size() == 3
	for s in sel:
		if not (s is Unit):
			all_ok = false
	# Đầu trận cả 3 nông dân đều có phân bổ mặc định (2 gỗ + 1 vàng) -> 0 nhàn.
	var none_idle := ctrl.find_idle_villager() == null
	ctrl.set_villager_allocation(0, 0, 0, 0)
	await _wait(0.3)
	var v1 := ctrl.find_idle_villager()
	var sel1 := ctrl.get_selection()
	var v1_ok: bool = v1 != null and sel1.size() == 1 and sel1[0] == v1
	var cam_ok := false
	if v1 != null:
		var expect := Vector2(clampf(v1.global_position.x, 640.0, 1280.0), clampf(v1.global_position.y, 360.0, 600.0))
		cam_ok = g.get_camera_pos().distance_to(expect) < 2.0
	var v2 := ctrl.find_idle_villager()
	var cycle_ok: bool = v2 != null and v2 != v1
	# Giao việc cho tất cả -> hết người nhàn.
	ctrl.set_villager_allocation(3, 0, 0, 0)
	await _wait(0.3)
	var none_left := ctrl.find_idle_villager() == null
	_check("rts4", all_ok and none_idle and v1_ok and cam_ok and cycle_ok and none_left,
		"chọn toàn quân=%s (n=%d, không lẫn nông dân), đầu trận 0 nhàn (đều có phân bổ)=%s, tìm được nông dân nhàn + đã chọn=%s, camera lia đúng điểm kẹp=%s, bấm tiếp xoay vòng người khác=%s, giao hết việc -> hết nhàn=%s" % [
			str(all_ok), n_all, str(none_idle), str(v1_ok), str(cam_ok), str(cycle_ok), str(none_left)])

	# ============ rts5) SƯƠNG MÙ LÀ LUẬT CỦA ATTACK-MOVE ============
	g = await _new_game(false, 20.0)
	await _wait(0.5)
	ctrl = g.controllers[0]
	var sw := _spawn_unit(g, 0, "warrior", Vector2(500, 480))
	# Địch đứng NGOÀI tầm nhìn của quân (235px ngang đường đi; tầm nhìn
	# kiếm sĩ 165) và ngoài mọi ô SÁNG của phe 0 -> không được bị đánh.
	var unseen := _spawn_unit(g, 2, "warrior", Vector2(800, 715))
	unseen.set_process(false)
	var unseen_hp := unseen.hp
	ctrl.set_selection([sw])
	ctrl.order_selected_attack_move(Vector2(1100, 480))
	t = 0.0
	var sarrived := false
	while t < 30.0:
		await _wait(0.5)
		t += 0.5
		if sw.global_position.distance_to(Vector2(1100, 480)) <= 45.0:
			sarrived = true
			break
	await _wait(1.0)
	var fog_ok := is_instance_valid(unseen) and unseen.hp == unseen_hp
	_check("rts5", sarrived and fog_ok,
		"quân tới đích attack-move=%s, địch ngoài tầm nhìn/ô sáng còn nguyên máu (%s/%s)=%s" % [
			str(sarrived), str(unseen.hp) if is_instance_valid(unseen) else "?", str(unseen_hp), str(fog_ok)])

	if _failures == 0:
		print("ALL RTS TESTS PASS")
	else:
		print("RTS FAILURES: ", _failures)
	quit(_failures)
