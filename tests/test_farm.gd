extends SceneTree

## Test tự động RUỘNG (nông trại kiểu Đế Chế) — bản ADAPT vào main:
##   farm_a) LUẬT ĐẶT HỢP NHẤT: ruộng đi qua ĐÚNG Main.can_place_building
##           (bọc can_place_building_at) như mọi nhà trên main — đặt được
##           ở vùng ĐÃ KHÁM PHÁ bất kỳ trên đất, bị chặn ở vùng CHƯA khám
##           phá và khi chồng công trình; exec qua đường thật trừ đúng
##           60 gỗ. (Khác nền nhánh cũ: nhà thường GIỜ cũng đặt tự do —
##           không còn luật vùng căn cứ để đối chiếu nữa.)
##   farm_a2) THỢ XÂY: đặt ruộng -> hệ thợ xây cử đúng 1 thợ (size small);
##           node thịt CHƯA bật khi đang xây; thợ xây XONG thật (không ép
##           constructed) thì node mới BẬT (250 thịt, chủ 0).
##   farm_b) LÀM RUỘNG: nông dân phân bổ thịt tới làm theo lượt, vác về
##           nộp ĐÚNG Kho Thịt (gần hơn thành) — sổ kho + tổng phe khớp
##           bất biến.
##   farm_c) CẠN -> SỤP: node bị hút cạn -> ruộng tự sụp (im lặng) thành
##           đất trống, vài giây sau BIẾN MẤT HẲN; nông dân đang làm dở
##           tự chuyển việc, đất trống xây lại được.
##   farm_d) CHỦ QUYỀN NODE: phe khác KHÔNG tìm thấy node ruộng của địch
##           (nearest_resource_node), lệnh farm trực tiếp lên ruộng địch
##           bị từ chối; click phải (res_node_at) cũng không nhắm được.
##   farm_e) BOT: cừu quanh nhà của bot bị dọn sạch -> bot tự trồng ruộng
##           trong trận mô phỏng (và node ruộng bot dùng được).
##   farm_f) BỊ PHÁ: ruộng trúng đòn chết -> thành tàn tích như nhà thường
##           (KHÔNG tự biến mất), node thịt chết theo, không farm được.
## Chạy: godot --headless --script tests/test_farm.gd

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

func _ledger_ok(g, pid: int) -> bool:
	var p = g.get_player(pid)
	var tot: Dictionary = g.total_stored(pid)
	for k in ["wood", "stone", "gold", "meat"]:
		if int(p.resources[k]) != int(tot[k]):
			return false
	return true

func _place_done(g, p, btype: String, pos: Vector2) -> Building:
	if not g.exec_place_building(p, btype, pos):
		return null
	var b := _building(g, p.pid, btype)
	if b != null:
		b.constructed = true
		b._refresh_display()
	return b

func _run() -> void:
	# ================= farm_a) Luật đặt hợp nhất =================
	var g = await _new_game(false)
	await _wait(0.5)
	var p0 = g.get_player(0)
	var castle_pos: Vector2 = g.castles[0].global_position
	g.exec_set_allocation(p0, 0, 0, 0, 0)
	# Điểm đã khám phá NGOÀI vùng căn cứ cũ (cách thành ~238px, vẫn trong
	# tầm nhìn thành 265): luật hợp nhất của main cho đặt TỰ DO mọi nhà ở
	# vùng đã khám phá trên đất — ruộng phải đặt được qua đúng hàm đó.
	var out_pos := castle_pos + Vector2(200, 130)
	var law_at: bool = g.can_place_building_at(0, out_pos)
	var ok_out: bool = g.can_place_building(p0, "farm", out_pos)
	var ok_center: bool = g.can_place_building(p0, "farm", Vector2(960, 480)) # giữa map: chưa khám phá
	var ok_overlap: bool = g.can_place_building(p0, "farm", castle_pos) # chồng thành
	var wood_before := int(p0.resources["wood"])
	var placed: bool = g.exec_place_building(p0, "farm", out_pos)
	var farm := _building(g, 0, "farm")
	_check("farm_a", law_at and ok_out and not ok_center and not ok_overlap
		and placed and farm != null and int(p0.resources["wood"]) == wood_before - 60
		and _ledger_ok(g, 0),
		"luật vị trí hợp nhất tại điểm đặt=%s; đặt ruộng vùng đã khám phá=%s, giữa map tối=%s (phải false), chồng thành=%s (phải false); exec=%s, gỗ %d->%d (trừ 60), sổ khớp=%s" % [
			str(law_at), str(ok_out), str(ok_center), str(ok_overlap),
			str(placed), wood_before, int(p0.resources["wood"]), str(_ledger_ok(g, 0))])
	# ============ farm_a2) Thợ xây ruộng + node bật khi xây xong ========
	# Hệ thợ xây của main phải cử ĐÚNG 1 thợ (farm khai size=small) ngay
	# khi đặt; node thịt chưa bật trong lúc xây; thợ xây xong THẬT thì
	# node mới bật với đủ 250 thịt.
	var builders_now: int = g.builders_assigned_count(farm) if farm != null else -1
	var hidden_node: Node2D = g.nearest_resource_node(0, "meat", castle_pos)
	var node_hidden: bool = hidden_node == null or (hidden_node as ResourceNode).get_parent() != farm
	var t_a2 := await _sim_until(g, func() -> bool:
		if farm == null or not is_instance_valid(farm) or not farm.constructed:
			return false
		var fn: ResourceNode = farm.get("_farm_node")
		return fn != null and fn.is_in_group("res_nodes"), 90.0)
	var fnode_a: ResourceNode = farm.get("_farm_node") if farm != null and is_instance_valid(farm) else null
	_check("farm_a2", builders_now == 1 and node_hidden and t_a2 >= 0.0
		and fnode_a != null and fnode_a.amount == 250 and fnode_a.owner_pid == 0,
		"thợ được cử=%d (phải 1); node ẩn khi đang xây=%s; thợ xây xong + node bật sau %.0fs, node=%d thịt chủ 0" % [
			builders_now, str(node_hidden), t_a2,
			fnode_a.amount if fnode_a != null else -1])
	g.queue_free()
	await _wait(0.3)

	# ================= farm_b) Làm ruộng + nộp đúng kho thịt =================
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	castle_pos = g.castles[0].global_position
	g.exec_set_allocation(p0, 0, 0, 0, 0)
	# Kho Thịt kê GIỮA ruộng và thành, sát ruộng: nông dân đứng làm ở phía
	# thành của ruộng nên kho phải gần ĐIỂM ĐỨNG của dân hơn thành thì mới
	# là điểm giao gần nhất (đã rà: kho-ruộng 90px, kho-node gỗ 51px).
	var store_meat := _place_done(g, p0, "store_meat", castle_pos + Vector2(105, 155))
	farm = _place_done(g, p0, "farm", castle_pos + Vector2(200, 140))
	await _wait(0.6) # 1 nhịp _process để node trong ruộng BẬT
	var fnode: ResourceNode = farm.get("_farm_node")
	var node_on: bool = fnode != null and fnode.is_in_group("res_nodes") and fnode.amount == 250 \
		and fnode.owner_pid == 0 and fnode.res_type == "meat"
	var near_node: Node2D = g.nearest_resource_node(0, "meat", castle_pos)
	# 1 nông dân phân bổ thịt -> phải tới ruộng làm và nộp vào Kho Thịt.
	g.exec_set_allocation(p0, 0, 0, 0, 1)
	var meat_before := int(p0.resources["meat"])
	var t_b := await _sim_until(g, func() -> bool: return store_meat.stored_amount("meat") >= 10, 150.0)
	# Node còn + đã nộp vào kho phải ≈ 250 (sai lệch tối đa 1 chuyến đang vác dở).
	var conserved: bool = fnode.amount <= 250 - store_meat.stored_amount("meat") \
		and fnode.amount >= 250 - store_meat.stored_amount("meat") - 10
	_check("farm_b", node_on and near_node == fnode and t_b >= 0.0
		and int(p0.resources["meat"]) == meat_before + store_meat.stored_amount("meat")
		and conserved
		and _ledger_ok(g, 0),
		"node ruộng bật=%s (250 thịt, chủ 0), nearest thịt=ruộng=%s; dân nộp vào Kho Thịt=%d sau %.0fs, tổng thịt %d->%d khớp sổ kho, node còn %d, sổ khớp=%s" % [
			str(node_on), str(near_node == fnode), store_meat.stored_amount("meat"), t_b,
			meat_before, int(p0.resources["meat"]), fnode.amount, str(_ledger_ok(g, 0))])
	g.queue_free()
	await _wait(0.3)

	# ================= farm_c) Cạn -> sụp -> biến mất -> xây lại =========
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	castle_pos = g.castles[0].global_position
	g.exec_set_allocation(p0, 0, 0, 0, 0)
	var farm_pos := castle_pos + Vector2(140, 130)
	farm = _place_done(g, p0, "farm", farm_pos)
	await _wait(0.6)
	fnode = farm.get("_farm_node")
	# Nông dân đang làm ruộng (lệnh trực tiếp) thì ruộng cạn giữa chừng.
	var v0 := _villager(g, 0, 0)
	var direct_ok: bool = g.exec_direct_farm(p0, v0, fnode)
	fnode.set_amount(10) # chỉ còn đúng 1 lượt vác
	var farm_box := [farm] # bọc holder: lambda bắt thẳng biến farm sẽ lỗi khi farm bị freed
	var t_c := await _sim_until(g, func() -> bool:
		return not is_instance_valid(farm_box[0]) or not farm_box[0].is_alive(), 120.0)
	var collapsed: bool = t_c >= 0.0 and is_instance_valid(farm) and not farm.is_alive() \
		and farm.silent_destroy and farm.visible
	# Nông dân phải nộp nốt chuyến cuối (thịt phe tăng) rồi chuyển việc,
	# không đứng kẹt ở ruộng đã sụp.
	var t_c2 := await _sim_until(g, func() -> bool: return v0.carrying == 0 and not v0.is_direct(), 60.0)
	var meat_after := int(p0.resources["meat"])
	# Ruộng biến mất hẳn sau vài giây -> đất trống xây lại được.
	var t_c3 := await _sim_until(g, func() -> bool: return not is_instance_valid(farm_box[0]), 30.0)
	var rebuild_ok: bool = t_c3 >= 0.0 and g.can_place_building(p0, "farm", farm_pos)
	_check("farm_c", direct_ok and collapsed and t_c2 >= 0.0 and meat_after == 110 and rebuild_ok,
		"lệnh trực tiếp vào ruộng=%s; cạn -> sụp im lặng=%s (đất trống còn hiện); dân nộp nốt + hết lệnh trực tiếp sau %.0fs, thịt=110 (100 đầu + 10 cuối)=%s; ruộng biến mất hẳn=%s, xây lại tại chỗ=%s" % [
			str(direct_ok), str(collapsed), t_c2, str(meat_after == 110),
			str(t_c3 >= 0.0), str(rebuild_ok)])
	g.queue_free()
	await _wait(0.3)

	# ================= farm_d) Không farm trộm ruộng địch ================
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	var p1 = g.get_player(1)
	g.exec_set_allocation(p0, 0, 0, 0, 0)
	g.exec_set_allocation(p1, 0, 0, 0, 0)
	var enemy_farm := _place_done(g, p1, "farm", g.castles[1].global_position + Vector2(-140, -160))
	await _wait(0.6)
	var enode: ResourceNode = enemy_farm.get("_farm_node")
	var seek: Node2D = g.nearest_resource_node(0, "meat", enode.global_position)
	var seek_ok: bool = seek != enode
	v0 = _villager(g, 0, 0)
	var steal_ok: bool = g.exec_direct_farm(p0, v0, enode)
	var click_ok: bool = g.res_node_at(enode.global_position, 36.0) != enode
	_check("farm_d", enemy_farm != null and seek_ok and not steal_ok and click_ok,
		"nearest thịt của phe 0 tại ruộng địch=%s (không được là node địch); lệnh farm trực tiếp lên ruộng địch bị từ chối=%s; res_node_at bỏ qua node địch=%s" % [
			"khác" if seek != enode else "NODE ĐỊCH!", str(not steal_ok), str(click_ok)])
	g.queue_free()
	await _wait(0.3)

	# ================= farm_e) Bot tự trồng ruộng =======================
	g = await _new_game(true)
	await _wait(0.5)
	p1 = g.get_player(1)
	var c1: Vector2 = g.castles[1].global_position
	# Dọn sạch cừu quanh nhà bot (trong 420px) như đã bị săn hết; cấp gỗ
	# dư để bot không kẹt tiền trong lúc dựng cơ sở.
	for n in get_nodes_in_group("sheep"):
		var s := n as Sheep
		if s.global_position.distance_to(c1) <= 420.0:
			s.queue_free()
	g.grant_resource(1, "wood", 1500)
	g.grant_resource(1, "stone", 500)
	g.grant_resource(1, "gold", 500)
	var t_e := await _sim_until(g, func() -> bool:
		return _building(g, 1, "farm") != null, 300.0, 1.0)
	var bot_farm := _building(g, 1, "farm")
	var t_e2 := -1.0
	if bot_farm != null:
		# Chờ xây xong (thợ xây của main) + node bật; ruộng bot phải nằm ở
		# vùng bot đã khám phá (luật đặt chung) và node thuộc chủ bot.
		t_e2 = await _sim_until(g, func() -> bool:
			var fn: ResourceNode = bot_farm.get("_farm_node")
			return bot_farm.constructed and fn != null and fn.is_in_group("res_nodes"), 120.0)
	_check("farm_e", bot_farm != null and t_e2 >= 0.0,
		"bot trồng được ruộng sau %.0fs mô phỏng; xây xong + node thịt bật=%s (vị trí %s)" % [
			t_e, str(t_e2 >= 0.0), str(bot_farm.global_position) if bot_farm != null else "—"])
	g.queue_free()
	await _wait(0.3)

	# ================= farm_f) Bị phá -> tàn tích, node chết ============
	g = await _new_game(false)
	await _wait(0.5)
	p0 = g.get_player(0)
	castle_pos = g.castles[0].global_position
	g.exec_set_allocation(p0, 0, 0, 0, 0)
	farm = _place_done(g, p0, "farm", castle_pos + Vector2(140, 130))
	await _wait(0.6)
	fnode = farm.get("_farm_node")
	farm.take_damage(99999.0, 1)
	await _wait(0.6)
	var ruin_ok: bool = is_instance_valid(farm) and not farm.is_alive() and not farm.silent_destroy
	var node_dead: bool = fnode == null or not is_instance_valid(fnode) or not fnode.is_in_group("res_nodes")
	# (fnode đã freed thì == null trong GDScript nên không so sánh trực tiếp
	# được; sân khấu này không có node thịt nào khác quanh thành -> phải null.)
	var seek2: Node2D = g.nearest_resource_node(0, "meat", castle_pos)
	_check("farm_f", ruin_ok and node_dead and seek2 == null,
		"ruộng bị phá: còn tàn tích (không tự biến mất, không silent)=%s; node thịt chết theo=%s; nearest thịt quanh thành=null (hết node ruộng)=%s" % [
			str(ruin_ok), str(node_dead), str(seek2 == null)])
	g.queue_free()

	print("==================================")
	if _failures.is_empty():
		print("ALL TESTS PASS")
		quit(0)
	else:
		print("TESTS FAILED: %d" % _failures.size())
		quit(1)
