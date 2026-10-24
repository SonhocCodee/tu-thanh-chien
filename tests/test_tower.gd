extends SceneTree

## Test tự động THÁP CANH CÓ CUNG THỦ (nhánh thap-cung):
##   ta) đặt tháp GIỮ 1 ô dân cho cung thủ ngay từ lúc đặt (đang xây đã tính)
##   td) dân số đầy -> đặt tháp bị TỪ CHỐI + lý do rõ (place_fail_reason);
##       dọn hàng chờ -> ô trở lại như trước khi lấp
##   tb) tháp ĐANG XÂY không bắn (địch đứng trong tầm, máu nguyên vẹn)
##   tc) xây xong: cung thủ đứng trên đỉnh (archer_manned) và BẮN trúng
##       địch trong tầm (địch mất máu — nguồn sát thương duy nhất tại chỗ)
##   te) phá tháp -> cung thủ biến mất + ô dân được TRẢ LẠI
## Sân khấu: tháp đặt ở vị trí quét được trong vùng căn cứ sao cho địch
## đứng ở điểm dừng (cách tháp 70) vẫn NGOÀI tầm bắn của thành chính
## (195) — mọi mất máu của địch chỉ có thể do cung thủ trên tháp.
## Chạy: godot --headless --script tests/test_tower.gd

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
	Engine.time_scale = 10.0
	g.bots_enabled = false # gán TRƯỚC add_child — _ready đọc cờ này
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

func _find_tower(g, pid: int) -> Building:
	for n in get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.building_type == "tower":
			return b
	return null

func _spawn_enemy(g, pid: int, pos: Vector2) -> Unit:
	var u = load("res://scenes/unit.tscn").instantiate()
	u.setup(pid, "warrior", g.get_player(pid).color_key, g, Vector2.ZERO)
	u.position = pos
	u.z_index = 10
	g.get("_units_layer").add_child(u)
	return u

## Quét tìm vị trí đặt tháp hợp lệ trong vùng căn cứ của pid: địch áp sát
## từ phía đông, điểm dừng cách tháp 70 và điểm spawn cách 170 đều phải
## ngoài tầm thành chính (195) một khoảng đệm an toàn.
func _find_tower_spot(g, p) -> Vector2:
	var castle_pos: Vector2 = g.castles[p.pid].global_position
	var zone: Rect2 = g.base_zone(p.pid)
	var slots: Array = g.build_slots(p.pid)
	for cx in range(int(zone.position.x) + 20, int(zone.end.x) - 10, 10):
		for cy in range(int(zone.position.y) + 20, int(zone.end.y) - 10, 10):
			var pos := Vector2(cx, cy)
			if pos.distance_to(slots[3]) < 75.0:
				continue # chừa ô slots[3] cho mục td (tháp thứ hai)
			if pos.distance_to(castle_pos) < 150.0:
				continue
			if (pos + Vector2(70, 0)).distance_to(castle_pos) < 215.0:
				continue
			if (pos + Vector2(170, 0)).distance_to(castle_pos) < 215.0:
				continue
			if g.can_place_building(p, "tower", pos):
				return pos
	return Vector2.ZERO

func _run() -> void:
	var g = await _new_game()
	await _wait(0.5)
	var p0 = g.get_player(0)
	var ctrl0 = g.human_controller()
	for k in Stats.RES_KEYS:
		p0.resources[k] = 5000
	var used0: int = g.pop_used(0)
	var cap0: int = g.pop_cap(0)

	# ================= ta) Đặt tháp giữ 1 ô cung thủ ngay từ lúc đặt =====
	var spot := _find_tower_spot(g, p0)
	_check("ta_spot", spot != Vector2.ZERO, "tìm được vị trí đặt tháp cách ly khỏi tầm thành: %s" % str(spot))
	var placed: bool = ctrl0.place_building("tower", spot)
	var tower := _find_tower(g, 0)
	_check("ta", placed and tower != null and not tower.constructed
		and g.pop_used(0) == used0 + 1 and not tower.archer_manned(),
		"đặt tháp=%s; dân số %d -> %d (giữ 1 ô khi đang xây); cung thủ chưa đứng (đang xây)=%s" % [
			str(placed), used0, g.pop_used(0), str(tower != null and not tower.archer_manned())])

	# ================= td) Dân số đầy -> từ chối đặt tháp + lý do rõ =====
	var guard := 0
	while g.pop_used(0) < g.pop_cap(0) and guard < 30:
		guard += 1
		if not ctrl0.queue_training(g.castles[0], "warrior"):
			break
	var full: bool = g.pop_used(0) >= g.pop_cap(0)
	var slots: Array = g.build_slots(0)
	var placed2: bool = ctrl0.place_building("tower", slots[3])
	var reason: String = g.place_fail_reason(p0, "tower", slots[3])
	_check("td", full and not placed2 and reason.contains("cung thủ"),
		"lấp đầy dân số %d/%d; đặt tháp 2 bị từ chối=%s; lý do: '%s'" % [
			g.pop_used(0), g.pop_cap(0), str(not placed2), reason])
	g.castles[0].train_queue.clear()
	_check("td2", g.pop_used(0) == used0 + 1,
		"dọn hàng chờ: dân số về %d (3 dân + 1 ô cung thủ của tháp)" % g.pop_used(0))

	# ================= tb) Đang xây không bắn =================
	var enemy := _spawn_enemy(g, 1, spot + Vector2(170, 0))
	enemy.set_direct_attack(tower)
	var enemy_hp0: float = enemy.hp
	await _sim_until(g, func() -> bool: return tower.constructed, 6.0)
	_check("tb", not tower.constructed and enemy.hp >= enemy_hp0,
		"tháp còn đang xây (build_left=%.1f), địch trong tầm mà máu nguyên %.0f/%.0f" % [
			tower.build_left, enemy.hp, enemy_hp0])

	# ================= tc) Xây xong: cung thủ đứng + bắn trúng ============
	var t_build := await _sim_until(g, func() -> bool: return tower.constructed, 30.0)
	var archer_ok: bool = tower.archer_manned() and (tower.get("_archer") as Node2D).visible
	var t_hit := await _sim_until(g, func() -> bool: return enemy.hp < enemy_hp0, 20.0)
	_check("tc", t_build >= 0.0 and archer_ok and t_hit >= 0.0 and g.pop_used(0) == used0 + 1,
		"xây xong sau thêm %.0fs; cung thủ đứng trên đỉnh=%s; địch mất máu sau %.0fs bắn (còn %.0f/%.0f); dân số vẫn %d" % [
			t_build, str(archer_ok), t_hit, enemy.hp, enemy_hp0, g.pop_used(0)])

	# ================= te) Phá tháp: cung thủ biến mất + trả ô ============
	tower.take_damage(100000.0, 1)
	await _wait(0.5)
	_check("te", not tower.is_alive() and not tower.archer_manned()
		and not (tower.get("_archer") as Node2D).visible and g.pop_used(0) == used0,
		"tháp sập: cung thủ biến mất=%s; dân số trả về %d (trước khi có tháp: %d)" % [
			str(not (tower.get("_archer") as Node2D).visible), g.pop_used(0), used0])

	g.queue_free()
	await _wait(0.3)
	if _failures.is_empty():
		print("ALL TOWER TESTS PASS")
		quit(0)
	else:
		print("TESTS FAILED: %d" % _failures.size())
		quit(1)
