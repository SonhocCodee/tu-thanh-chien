extends SceneTree

## Test tự động HỆ LÊN ĐỜI + NÂNG CẤP NHÀ/QUÂN (nhánh nang-cap):
##   ages_a) CỔNG ĐỜI: Đời 1 không nâng nhà cấp 2 / không nghiên cứu quân
##           cấp 2 được; lên Đời 2 xong thì mở. Lên đời qua đường exec thật.
##   ages_b) ÍCH LỢI THEO CẤP áp thật: kho 500 -> 800 -> 1200; Nhà Lính
##           +6 -> +9 ô quân; Nhà Dân +8 -> +12 dân; máu nhà x1.6 ở cấp 2.
##   ages_c) NGHIÊN CỨU QUÂN áp cho quân ĐANG SỐNG (chỉ số + sprite đổi
##           tại chỗ) và quân luyện sau; nông dân cấp 2 vác 13 + farm nhanh.
##   ages_d) BOT tự lên được Đời 2 trong 1 trận mô phỏng (kinh tế được cấp
##           sân khấu — kiểm đường quyết định + ống nghiên cứu của bot).
## Chạy: godot --headless --script tests/test_ages.gd

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

func _grant_all(g, pid: int, amount: int = 6000) -> void:
	for k in Stats.RES_KEYS:
		g.grant_resource(pid, k, amount)

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

## Rút đồng hồ nghiên cứu của 1 công trình xuống sắp xong rồi chờ nó hoàn tất.
func _finish_research(g, s: Structure, max_sec: float = 30.0) -> bool:
	if s == null or not s.is_researching():
		return false
	s.research_left = 0.05
	var t := await _sim_until(g, func() -> bool: return not s.is_researching(), max_sec)
	return t >= 0.0

func _age_up_fast(g, p) -> bool:
	var castle = g.castles[p.pid]
	if not g.exec_start_age_up(p, castle):
		return false
	return await _finish_research(g, castle)

func _run() -> void:
	# ================= ages_a) Cổng Đời =================
	var g = await _new_game(false)
	await _wait(0.5)
	var p0 = g.get_player(0)
	_grant_all(g, 0)
	g.exec_set_allocation(p0, 0, 0, 0, 0)
	var slots: Array = g.build_slots(0)
	var house := _place_done(g, p0, "house", slots[0])
	var barracks := _place_done(g, p0, "barracks", slots[1])
	var gate_b: bool = not g.exec_start_building_upgrade(p0, house)
	var gate_u: bool = not g.exec_start_unit_research(p0, barracks, "warrior")
	var gate_p: bool = not g.exec_start_unit_research(p0, g.castles[0], "pawn")
	_check("ages_a1", house != null and barracks != null and gate_b and gate_u and gate_p and p0.age == 1,
		"Đời 1: nâng nhà cấp 2 bị chặn=%s, nghiên cứu kiếm cấp 2 bị chặn=%s, nghiên cứu nông dân cấp 2 bị chặn=%s (cổng Đời)" % [
			str(gate_b), str(gate_u), str(gate_p)])
	var aged := await _age_up_fast(g, p0)
	var up_ok: bool = g.exec_start_building_upgrade(p0, house)
	var up_done := await _finish_research(g, house)
	_check("ages_a2", aged and p0.age == 2 and up_ok and up_done and house.level == 2,
		"lên Đời 2 xong=%s (Đời=%d); nâng nhà cấp 2 mở=%s và hoàn tất=%s (nhà cấp %d)" % [
			str(aged), p0.age, str(up_ok), str(up_done), house.level])
	g.queue_free()
	await _wait(0.3)

	# ================= ages_b) Ích lợi theo cấp =================
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	_grant_all(g, 0)
	g.exec_set_allocation(p0, 0, 0, 0, 0)
	slots = g.build_slots(0)
	house = _place_done(g, p0, "house", slots[0])
	var store := _place_done(g, p0, "store_wood", slots[6])
	var soldier := _place_done(g, p0, "soldier_house", slots[5])
	var cap0: Array = [g.pop_cap(0), g.army_cap(0), store.storage_capacity(), house.max_hp]
	await _age_up_fast(g, p0)
	# Kho lên cấp 2 (cần Đời 2) rồi Đời 3 -> cấp 3.
	var s_up1: bool = g.exec_start_building_upgrade(p0, store)
	await _finish_research(g, store)
	var cap_mid := store.storage_capacity()
	await _age_up_fast(g, p0) # Đời 3
	var s_up2: bool = g.exec_start_building_upgrade(p0, store)
	await _finish_research(g, store)
	var sh_up: bool = g.exec_start_building_upgrade(p0, soldier)
	await _finish_research(g, soldier)
	var h_up: bool = g.exec_start_building_upgrade(p0, house)
	await _finish_research(g, house)
	_check("ages_b", store != null and soldier != null
		and int(cap0[0]) == 18 and int(cap0[1]) == 12 and int(cap0[2]) == 500 and absf(float(cap0[3]) - 250.0) < 0.01
		and s_up1 and cap_mid == 800 and s_up2 and store.storage_capacity() == 1200 and store.level == 3
		and sh_up and g.army_cap(0) == 15
		and h_up and g.pop_cap(0) == 22 and absf(house.max_hp - 400.0) < 0.01,
		"gốc: dân 18, quân 12, kho 500, máu nhà 250 -> kho cấp2=%d, cấp3=%d; Nhà Lính cấp2: trần quân=%d (phải 15); Nhà Dân cấp2: trần dân=%d (phải 22), máu=%d (phải 400)" % [
			cap_mid, store.storage_capacity(), g.army_cap(0), g.pop_cap(0), int(house.max_hp)])
	g.queue_free()
	await _wait(0.3)

	# ================= ages_c) Nghiên cứu áp cho quân đang sống =================
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	_grant_all(g, 0)
	await _age_up_fast(g, p0) # Đời 2
	slots = g.build_slots(0)
	barracks = _place_done(g, p0, "barracks", slots[1])
	g.spawn_trained_unit(0, "warrior", g.castles[0])
	await _wait(0.3)
	var w: Unit = null
	for n in get_nodes_in_group("units"):
		var u := n as Unit
		if u.owner_pid == 0 and u.unit_type == "warrior":
			w = u
	var hp_before := w.max_hp if w != null else -1.0
	var res_ok: bool = g.exec_start_unit_research(p0, barracks, "warrior")
	await _finish_research(g, barracks)
	var tex_path := ""
	if w != null:
		var at := w.get("_anim").sprite_frames.get_frame_texture("idle", 0) as AtlasTexture
		if at != null and at.atlas != null:
			tex_path = at.atlas.resource_path
	var pawn_ok: bool = g.exec_start_unit_research(p0, g.castles[0], "pawn")
	await _finish_research(g, g.castles[0])
	var v_carry := -1
	var v_harvest := -1.0
	for n in get_nodes_in_group("villagers"):
		var v := n as Villager
		if v.owner_pid == 0:
			v_carry = int(v.st["carry_capacity"])
			v_harvest = float(v.st["harvest_time"])
			break
	g.spawn_trained_unit(0, "warrior", g.castles[0])
	await _wait(0.3)
	var w2_hp := -1.0
	for n in get_nodes_in_group("units"):
		var u := n as Unit
		if u.owner_pid == 0 and u.unit_type == "warrior" and u != w:
			w2_hp = u.max_hp
	_check("ages_c", w != null and absf(hp_before - 130.0) < 0.01 and res_ok
		and w.level == 2 and absf(w.max_hp - 156.0) < 0.5 and absf(float(w.st["damage"]) - 16.1) < 0.05
		and tex_path.find("warrior_idle_lv2") >= 0
		and pawn_ok and v_carry == 13 and absf(v_harvest - 2.55) < 0.01
		and absf(w2_hp - 156.0) < 0.5,
		"kiếm sĩ đang sống: máu %d -> tối đa %d (phải 156), đánh %.1f (phải 16.1), sprite=%s; nông dân: vác %d (phải 13), lượt farm %.2fs (phải 2.55); kiếm luyện sau: máu %d (phải 156)" % [
			int(hp_before), int(w.max_hp), float(w.st["damage"]),
			"lv2" if tex_path.find("warrior_idle_lv2") >= 0 else tex_path,
			v_carry, v_harvest, int(w2_hp)])
	g.queue_free()
	await _wait(0.3)

	# ================= ages_d) Bot tự lên Đời 2 =================
	g = await _new_game(true)
	await _wait(0.5)
	var p1 = g.get_player(1)
	var t_d := 0.0
	var grant_t := 0.0
	while t_d < 900.0 and p1.age < 2:
		await _wait(0.5)
		t_d += 0.5 * 8.0 # đồng hồ MÔ PHỎNG (time_scale 8)
		grant_t += 0.5 * 8.0
		if grant_t >= 20.0:
			grant_t = 0.0
			# Kinh tế sân khấu: cấp đều để bot không chết đói thịt/vàng,
			# phần quyết định lên đời + ống nghiên cứu vẫn là của bot.
			g.grant_resource(1, "meat", 400)
			g.grant_resource(1, "wood", 300)
			g.grant_resource(1, "gold", 200)
			g.grant_resource(1, "stone", 100)
	_check("ages_d", p1.age >= 2 and p1.ages_reached_total >= 1,
		"bot (pid 1) tự lên Đời %d sau ~%.0fs mô phỏng, số lần lên đời=%d" % [
			p1.age, t_d, p1.ages_reached_total])
	g.queue_free()

	print("==================================")
	if _failures.is_empty():
		print("ALL TESTS PASS")
		quit(0)
	else:
		print("TESTS FAILED: %d" % _failures.size())
		quit(1)
