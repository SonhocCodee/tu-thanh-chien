extends SceneTree

## Test RUNG THEO NHỊP CHẶT (lỗi user báo từ chơi thật 2026-10-24): trước
## khi sửa, rung (_shake_left) CHỈ gán trong take_harvest ở CUỐI lượt 3s —
## suốt lúc nông dân vung rìu cây đứng im, chặt xong bê gỗ đi cây mới rung
## 1 cái yếu. Sau sửa: villager gọi ResourceNode.notify_hit() mỗi 0.5s
## trong _step_harvest -> cây phải RUNG NGAY GIỮA LƯỢT, khi amount còn
## nguyên (take_harvest chưa chạy).
##   shake-a) giữa lượt chặt đầu: >= 3 mẫu (state==harvest, amount chưa
##            đổi) có _shake_left > 0 hoặc sprite lệch khỏi _spr_base_pos.
##   shake-b) notify_hit() KHÔNG đổi amount (tách hình ảnh khỏi kinh tế)
##            nhưng có gán rung.
##   shake-c) hết lượt: take_harvest vẫn trừ đúng carry_capacity và nông
##            dân vác về kho như cũ (luồng kinh tế nguyên vẹn).
## Chạy: godot --headless --script tests/test_shake.gd

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

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var g = scene.instantiate()
	Engine.time_scale = 8.0
	g.bots_enabled = false
	root.add_child(g)
	await _wait(0.5)

	var p0 = g.get_player(0)
	var castle_pos: Vector2 = g.castles[0].global_position
	# Cây gỗ nhỏ gần thành nhất.
	var tree: ResourceNode = null
	var best_d := 1e9
	for n in get_nodes_in_group("res_nodes"):
		var rn := n as ResourceNode
		if rn.res_type == "wood" and not rn.is_big:
			var d := rn.global_position.distance_to(castle_pos)
			if d < best_d:
				best_d = d
				tree = rn
	var v0: Villager = null
	for n in get_nodes_in_group("villagers"):
		var v := n as Villager
		if v.owner_pid == 0:
			v0 = v
			break

	# ---- shake-b) notify_hit chỉ rung, không đụng amount ----
	var amount0: int = tree.amount
	for i in 5:
		tree.notify_hit()
	_check("shake-b", tree.amount == amount0 and float(tree.get("_shake_left")) > 0.0,
		"notify_hit x5: amount %d -> %d (phải nguyên), _shake_left=%.2f (phải >0)" % [
			amount0, tree.amount, float(tree.get("_shake_left"))])
	await _wait(0.6) # chờ cú rung b) tắt hẳn để mẫu a) sạch

	# ---- shake-a) lấy mẫu GIỮA lượt chặt đầu tiên ----
	g.exec_direct_farm(p0, v0, tree)
	var t := 0.0
	while str(v0.get("_state")) != "harvest" and t < 30.0:
		await _wait(0.25)
		t += 0.25
	_check("shake-a0", str(v0.get("_state")) == "harvest",
		"nông dân tới nơi và vào trạng thái harvest sau %.1fs" % t)

	var base_pos: Vector2 = tree.get("_spr_base_pos")
	var samples := 0
	var shaking := 0
	var max_off := 0.0
	t = 0.0
	# Chỉ mẫu khi amount CÒN NGUYÊN (= take_harvest chưa chạy) — đúng giữa lượt.
	while tree.amount == amount0 and t < 4.0:
		await _wait(0.1)
		t += 0.1
		if str(v0.get("_state")) != "harvest":
			continue
		samples += 1
		var spr := tree.get("_sprite") as Sprite2D
		var off := 0.0
		if spr != null:
			off = spr.position.distance_to(base_pos)
		max_off = maxf(max_off, off)
		if float(tree.get("_shake_left")) > 0.0 or off > 0.3:
			shaking += 1
	_check("shake-a", samples >= 10 and shaking >= 3,
		"giua luot chat: %d mau hop le, %d mau dang rung, lech sprite toi da %.2fpx (can >=3 mau rung)" % [
			samples, shaking, max_off])

	# ---- shake-c) hết lượt: trừ đúng tải, nông dân vác về ----
	var carry_cap := int(v0.st["carry_capacity"])
	var t2 := 0.0
	while tree.amount == amount0 and t2 < 10.0:
		await _wait(0.25)
		t2 += 0.25
	_check("shake-c", tree.amount == amount0 - carry_cap,
		"het luot: amount %d -> %d (phai tru dung %d)" % [amount0, tree.amount, carry_cap])
	var t3 := 0.0
	while v0.carrying <= 0 and t3 < 5.0:
		await _wait(0.25)
		t3 += 0.25
	_check("shake-c2", v0.carrying == carry_cap and str(v0.get("_state")) == "return",
		"nong dan vac %d %s ve kho (state=%s)" % [v0.carrying, v0.carrying_type, str(v0.get("_state"))])

	if _failures.is_empty():
		print("TEST shake: ALL PASS")
	else:
		print("TEST shake: FAILURES = ", _failures)
	quit(1 if _failures.is_empty() else 2)
