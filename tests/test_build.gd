extends SceneTree

# Headless test cho HỆ THỐNG XÂY MỚI (đặt nhà tự do + nông dân ra xây):
#  (b1) đặt nhà thành công ở XA thành (vùng đã khám phá) — luật cũ từ chối
#  (b2) đặt vào vùng CHƯA khám phá bị từ chối, không trừ tài nguyên
#  (b3) nhà NHỎ: đúng 1 thợ tới xây (có cảnh đóng búa), hoàn thành quanh
#       build_time khi đủ thợ (kể cả thời gian thợ đi ra công trường)
#  (b4) nhà LỚN (Doanh trại): đúng 2 thợ được cử
#  (b5) rút 1 thợ của nhà lớn giữa chừng -> tốc độ tiến độ ~một nửa
#  (b6) xây xong thợ quay lại ĐÚNG việc cũ (phân bổ farm)
#  (b7) lệnh trực tiếp: cử nông dân tới xây tiếp công trình đang xây dở
#  (b8) phe không còn nông dân nào -> không cho đặt nhà
# Chạy: godot --headless --script tests/test_build.gd

var _failures: Array = []

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK  ", msg)
	else:
		_failures.append(msg)
		print("  FAIL ", msg)

func _initialize() -> void:
	call_deferred("_run")

func _find_building(g: Node, pid: int, type: String) -> Building:
	for n in g.get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.building_type == type:
			return b
	return null

func _game_seconds_since(t0_ms: int) -> float:
	return float(Time.get_ticks_msec() - t0_ms) / 1000.0 * Engine.time_scale

# Chờ 1 lượng THỜI GIAN GAME (đã nhân time_scale) trôi qua.
func _wait_game(seconds: float) -> void:
	var frames := int(ceil(seconds / Engine.time_scale * 60.0))
	for i in maxi(1, frames):
		await physics_frame

func _run() -> void:
	Engine.time_scale = 20.0
	paused = true
	var g: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	g.bots_enabled = false
	root.add_child(g)
	await process_frame
	await process_frame
	var p0 = g.players[0]
	var p1 = g.players[1]
	var p3 = g.players[3]

	# Mở map 1 vùng XA thành phe 0 (thành ở (220,780); điểm đặt (800,480)
	# cách ~640px — luật vùng căn cứ cũ chắc chắn từ chối).
	g.fogs[0].reveal_circle(Vector2(800, 480), 170)

	# ---------- (b1) đặt nhà xa thành ----------
	print("[b1] Đặt Nhà dân ở xa thành (vùng đã khám phá)")
	var wood_before: int = p0.resources["wood"]
	var ok_far: bool = g.exec_place_building(p0, "house", Vector2(800, 480))
	_check(ok_far, "đặt nhà ở (800,480) xa thành THÀNH CÔNG theo luật mới")
	_check(int(p0.resources["wood"]) == wood_before - 100, "trừ đúng 100 gỗ khi đặt")
	var house := _find_building(g, 0, "house")
	_check(house != null and house.global_position.distance_to(Vector2(800, 480)) < 1.0, "nhà mọc đúng vị trí xa thành")
	_check(house != null and not house.constructed, "nhà mới đặt chưa hoạt động (constructed=false)")
	_check(house != null and g.builders_assigned_count(house) == 1, "nhà NHỎ: đúng 1 thợ được cử ngay khi đặt")
	var builder: Villager = null
	for vn in g._villagers_of(0):
		if (vn as Villager).build_target == house:
			builder = vn
	_check(builder != null, "bắt được danh tính thợ xây nhà")

	# ---------- (b2) đặt vào vùng chưa khám phá ----------
	print("[b2] Đặt nhà vào vùng CHƯA khám phá")
	wood_before = p0.resources["wood"]
	var ok_unexplored: bool = g.exec_place_building(p0, "house", Vector2(1500, 480))
	_check(not ok_unexplored, "đặt vào vùng chưa khám phá bị TỪ CHỐI")
	_check(int(p0.resources["wood"]) == wood_before, "bị từ chối thì không trừ tài nguyên")
	_check(_find_building(g, 0, "house") == house, "không mọc thêm nhà nào sau lần đặt bị từ chối")

	# ---------- (b3) + (b6) thợ xây xong và quay lại việc cũ ----------
	print("[b3] Thờ
...[truncated 5831 chars]i gian thợ xây nhà nhỏ và việc cũ sau khi xây xong")
	paused = false
	var t0 := Time.get_ticks_msec()
	var saw_hammer := false
	while house != null and not house.constructed and _game_seconds_since(t0) < 120.0:
		await process_frame
		if builder != null and is_instance_valid(builder) and builder._state == "build":
			saw_hammer = true
	var elapsed := _game_seconds_since(t0)
	_check(house != null and house.constructed, "nhà nhỏ HOÀN THÀNH (%.1fs game)" % elapsed)
	_check(saw_hammer, "thợ có đứng ĐÓNG BÚA tại công trường (state=build)")
	_check(elapsed >= 9.5 and elapsed <= 32.0, "thời gian xong quanh build_time 12s + đi đường (đo %.1fs, chấp nhận 9.5–32)" % elapsed)
	print("[b6] Thợ quay lại việc cũ")
	# Thợ tự giải phóng ở tick _process kế tiếp sau khi nhà lật constructed.
	var tw := Time.get_ticks_msec()
	while builder != null and is_instance_valid(builder) and builder.build_target != null and _game_seconds_since(tw) < 2.0:
		await process_frame
	_check(builder != null and is_instance_valid(builder) and builder.build_target == null, "xây xong thợ hết nhiệm vụ xây")
	_check(builder != null and builder.assigned != "", "thợ quay lại phân bổ farm cũ (assigned='%s')" % (builder.assigned if builder != null else "?"))

	# ---------- (b4) nhà LỚN: 2 thợ ----------
	print("[b4] Doanh trại (nhà LỚN) có 2 thợ")
	p0.add_resource("wood", 1000)
	p0.add_resource("stone", 1000)
	var ok_bar: bool = g.exec_place_building(p0, "barracks", Vector2(860, 380))
	_check(ok_bar, "đặt Doanh trại ở vùng đã khám phá xa thành thành công")
	var barracks := _find_building(g, 0, "barracks")
	_check(barracks != null and barracks.builders_required == 2, "Doanh trại yêu cầu 2 thợ (size=large)")
	_check(barracks != null and g.builders_assigned_count(barracks) == 2, "đúng 2 thợ được cử cho nhà lớn")

	# ---------- (b7) lệnh trực tiếp cử thợ xây tiếp ----------
	print("[b7] Cử thợ bằng lệnh trực tiếp (exec_villager_build)")
	var pulled: Villager = null
	for vn in g._villagers_of(0):
		if (vn as Villager).build_target == barracks:
			pulled = vn
			break
	_check(pulled != null, "có thợ đang nhận nhiệm vụ xây Doanh trại")
	if pulled != null:
		pulled.set_move_point(Vector2(1500, 850)) # người chơi điều đi chỗ khác
		_check(pulled.build_target == null, "lệnh di chuyển mới huỷ nhiệm vụ xây của thợ")
		var ok_direct: bool = g.exec_villager_build(p0, pulled, barracks)
		_check(ok_direct and pulled.build_target == barracks, "lệnh trực tiếp cử thợ quay lại xây tiếp Doanh trại")

	# ---------- (b5) rút 1 thợ nhà lớn -> tiến độ một nửa ----------
	print("[b5] Tháp canh phe 1: rút 1/2 thợ -> tốc độ giảm một nửa")
	var v1s: Array = g._villagers_of(1)
	_check(v1s.size() == 3, "phe 1 có 3 nông dân lúc đầu (có %d)" % v1s.size())
	if v1s.size() > 0:
		(v1s[0] as Node).queue_free() # chỉ còn đúng 2 nông dân -> không có người thay
	await physics_frame
	await physics_frame
	p1.add_resource("stone", 500)
	g.fogs[1].reveal_circle(Vector2(300, 90), 130)
	var ok_tower: bool = g.exec_place_building(p1, "tower", Vector2(300, 90))
	_check(ok_tower, "phe 1 đặt Tháp canh thành công")
	var tower := _find_building(g, 1, "tower")
	_check(tower != null and g.builders_assigned_count(tower) == 2, "tháp (lớn) được cử đủ 2 thợ")
	var both_on_site := false
	var t1 := Time.get_ticks_msec()
	while tower != null and _game_seconds_since(t1) < 90.0:
		await process_frame
		if tower.builders_on_site() == 2:
			both_on_site = true
			break
	_check(both_on_site, "cả 2 thợ đều TỚI công trường tháp")
	if tower != null and both_on_site:
		var l0: float = tower.build_left
		await _wait_game(4.0)
		var d_full: float = l0 - tower.build_left
		_check(d_full > 3.0 and d_full < 5.0, "đủ 2 thợ: tiến độ ~4.0 trong 4s game (đo %.2f)" % d_full)
		var pull2: Villager = null
		for vn in g._villagers_of(1):
			if (vn as Villager).build_target == tower:
				pull2 = vn
				break
		_check(pull2 != null, "bắt được 1 thợ tháp để rút đi")
		if pull2 != null:
			pull2.set_move_point(Vector2(1500, 850))
		await _wait_game(1.0)
		_check(tower.builders_on_site() == 1 and g.builders_assigned_count(tower) == 1, "rút 1 thợ, không có người thay -> còn đúng 1 thợ tại chỗ")
		var l1: float = tower.build_left
		await _wait_game(6.0)
		var d_half: float = l1 - tower.build_left
		_check(d_half > 2.0 and d_half < 4.1, "thiếu 1/2 thợ: tiến độ ~3.0 trong 6s game = một nửa tốc độ (đo %.2f)" % d_half)

	# ---------- (b8) hết nông dân -> không cho đặt ----------
	print("[b8] Phe không còn nông dân -> không đặt được nhà")
	for vn in g._villagers_of(3):
		(vn as Node).queue_free()
	await physics_frame
	await physics_frame
	_check(g.villager_count(3) == 0, "phe 3 đã hết nông dân")
	p3.add_resource("wood", 500)
	g.fogs[3].reveal_circle(Vector2(1600, 700), 130)
	var wood3: int = p3.resources["wood"]
	var ok_none: bool = g.exec_place_building(p3, "house", Vector2(1600, 700))
	_check(not ok_none, "không còn nông dân -> đặt nhà bị TỪ CHỐI")
	_check(int(p3.resources["wood"]) == wood3, "bị từ chối vì hết thợ thì không trừ tài nguyên")

	print("")
	if _failures.is_empty():
		print("TEST_BUILD: TẤT CẢ ĐẠT")
		quit(0)
	else:
		print("TEST_BUILD: ", _failures.size(), " MỤC THẤT BẠI:")
		for f in _failures:
			print(" - ", f)
		quit(1)
