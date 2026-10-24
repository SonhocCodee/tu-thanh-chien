extends SceneTree

## Test tự động TU SĨ (quân chữa trị — Team 4 đợt Đế Chế hoá):
##   monka) luyện Tu Sĩ tại THÀNH: trừ đúng 100 vàng, giữ ô ngay trong
##          hàng chờ (army_used + pop_used cùng +1), ra quân unit_type
##          "monk"; thẻ luyện "castle:monk" tự sinh trong HUD.
##   monkb) CHỮA: đồng minh bị thương trong tầm được hồi máu thật theo
##          thời gian (+12 HP/s) và không bao giờ vượt máu tối đa.
##   monkc) KHÔNG chữa: địch cạnh bên, công trình phe mình, và chính
##          bản thân tu sĩ — cả 3 đều giữ nguyên máu.
##   monkd) tu sĩ CHẾT như quân thường (hết máu -> is_alive false, trả ô).
##   monke) ĐI THEO ĐỘI: tu sĩ tự bám lại gần quân chiến đấu đồng minh.
##   monkf) BOT trọn trận: có bot luyện được ít nhất 1 Tu Sĩ khi đạo
##          quân đạt cỡ vừa (army_used >= monk_min_army).
## Chạy: godot --headless --script tests/test_monk.gd

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

func _rich(p) -> void:
	for k in Stats.RES_KEYS:
		p.resources[k] = 9000

func _units_of(g, pid: int, utype: String) -> Array:
	var out: Array = []
	for n in get_nodes_in_group("units"):
		var u := n as Unit
		if u.owner_pid == pid and u.unit_type == utype and u.is_alive():
			out.append(u)
	return out

func _wait_for_unit(g, pid: int, utype: String, timeout_s: float) -> Unit:
	var t := 0.0
	while t < timeout_s:
		var arr := _units_of(g, pid, utype)
		if not arr.is_empty():
			return arr[0]
		await _wait(0.25)
		t += 0.25
	return null

func _run() -> void:
	# ================= monka) Luyện tại thành + ô + thẻ HUD =================
	var g = await _new_game(false)
	await _wait(0.5)
	var p0 = g.get_player(0)
	var ctrl0 = g.human_controller()
	_rich(p0)
	var gold0: int = int(p0.resources["gold"])
	var army0: int = g.army_used(0)
	var pop0: int = g.pop_used(0)
	_check("monka1", ctrl0.queue_training(g.castles[0], "monk"), "queue_training(castle, monk) được chấp nhận")
	_check("monka2", int(p0.resources["gold"]) == gold0 - 100, "trừ đúng 100 vàng (còn %d)" % int(p0.resources["gold"]))
	_check("monka3", g.army_used(0) == army0 + 1 and g.pop_used(0) == pop0 + 1,
		"hàng chờ giữ đúng 1 ô quân + 1 ô dân (army %d->%d, pop %d->%d)" % [army0, g.army_used(0), pop0, g.pop_used(0)])
	if g._hud != null:
		g._hud._on_tab_toggled(true, 1) # mở tab HUẤN LUYỆN — thẻ mới được dựng
	_check("monka4", g._hud != null and g._hud._train_cards.has("castle:monk"), "HUD tự sinh thẻ luyện Tu Sĩ ở nhóm Thành chính")
	var monk: Unit = await _wait_for_unit(g, 0, "monk", 30.0)
	_check("monka5", monk != null, "tu sĩ ra quân thật sau thời gian luyện (20s / tốc độ thành 1.0)")
	if monk == null:
		_finish(g)
		return
	_check("monka6", is_equal_approx(monk.max_hp, 60.0) and is_equal_approx(float(monk.st["speed"]), 60.0),
		"số liệu tu sĩ khớp Stats (HP 60, tốc 60)")

	# ================= monkb) Chữa đồng minh theo thời gian =================
	var w1: Unit = null
	g.spawn_trained_unit(0, "warrior", g.castles[0])
	w1 = await _wait_for_unit(g, 0, "warrior", 2.0)
	_check("monkb0", w1 != null, "có kiếm sĩ đồng minh để chữa")
	w1.global_position = monk.global_position + Vector2(60, 0)
	w1.hp = 40.0
	var hp_start := w1.hp
	await _wait(3.0) # 3s trong game: ~3 nhịp chữa x +12
	_check("monkb1", w1.hp > hp_start + 20.0, "kiếm sĩ 40 máu được chữa lên %.0f sau 3s (kỳ vọng +12 HP/s)" % w1.hp)
	w1.hp = w1.max_hp - 4.0
	await _wait(1.5)
	_check("monkb2", w1.hp <= w1.max_hp, "hồi không vượt máu tối đa (%.0f/%.0f)" % [w1.hp, w1.max_hp])

	# ================= monkc) Không chữa địch / nhà / chính mình =================
	# Địch: triệu hồi 1 kiếm sĩ phe 1, kéo cả tu sĩ lẫn địch ra bãi trống
	# XA kiếm sĩ phe mình — kiếm sĩ mình mà thấy địch gần thành là lao vào
	# đánh (đúng AI giữ nhà), máu địch tụt vì bị đánh chứ không liên quan
	# chữa trị; tách ra xa để mục kiểm này chỉ đo đúng 1 việc: tu sĩ có
	# chữa nhầm địch hay không. Địch đứng ngoài tầm bỏ chạy của tu sĩ.
	g.spawn_trained_unit(1, "warrior", g.castles[1])
	var foe: Unit = await _wait_for_unit(g, 1, "warrior", 2.0)
	monk.global_position = g.castles[0].global_position + Vector2(430, -170)
	foe.global_position = monk.global_position + Vector2(80, 0)
	foe.hp = 30.0
	# Công trình phe mình: thành chính mất máu.
	var castle_hp0 := 300.0
	g.castles[0].hp = castle_hp0
	# Chính tu sĩ bị thương, đồng minh xung quanh đầy máu.
	monk.hp = 30.0
	w1.hp = w1.max_hp
	await _wait(3.0)
	_check("monkc1", is_equal_approx(foe.hp, 30.0), "địch sát bên KHÔNG được chữa (máu %.0f)" % foe.hp)
	_check("monkc2", is_equal_approx(g.castles[0].hp, castle_hp0), "thành phe mình KHÔNG được chữa (máu %.0f)" % g.castles[0].hp)
	_check("monkc3", is_equal_approx(monk.hp, 30.0), "tu sĩ KHÔNG tự chữa chính mình (máu %.0f)" % monk.hp)
	# Dọn địch đi xa để các mục sau không bị nhiễu (địch tự về leash của nó).
	foe.global_position = g.castles[1].global_position + Vector2(120, 60)
	foe.hp = foe.max_hp

	# ================= monkd) Chết như quân thường =================
	var army_before: int = g.army_used(0)
	monk.take_damage(9999.0, 1)
	_check("monkd1", not monk.is_alive(), "tu sĩ hết máu -> chết (is_alive = false)")
	await _wait(0.5)
	_check("monkd2", g.army_used(0) == army_before - 1, "tu sĩ chết trả lại 1 ô quân (army %d->%d)" % [army_before, g.army_used(0)])

	# ================= monke) Đi theo đội hình =================
	var monk2: Unit = null
	ctrl0.queue_training(g.castles[0], "monk")
	monk2 = await _wait_for_unit(g, 0, "monk", 30.0)
	_check("monke0", monk2 != null, "có tu sĩ thứ hai cho mục đi theo đội")
	if monk2 != null:
		# Kéo tu sĩ ra xa đội hình: nó phải tự bám lại gần quân chiến đấu.
		monk2.global_position = w1.global_position + Vector2(300, 100)
		var d := 1e9
		var tw := 0.0
		while tw < 9.0:
			await _wait(0.5)
			tw += 0.5
			d = monk2.global_position.distance_to(w1.global_position)
			if d <= 140.0:
				break
		_check("monke1", d <= 140.0, "tu sĩ tự bám về gần kiếm sĩ (khoảng cách còn %.0f px)" % d)
	g.queue_free()
	await _wait(0.2)

	# ================= monkf) Bot trọn trận có luyện Tu Sĩ =================
	var g2 = await _new_game(true)
	Engine.time_scale = 12.0
	var seen_monk := false
	var t := 0.0
	while t < 1200.0 and not seen_monk: # tối đa 1200s trong game
		await _wait(2.0)
		t += 2.0
		for pid in range(4):
			if g2.unit_type_count(pid, "monk") > 0:
				seen_monk = true
				break
			# Tu sĩ đang nằm trong hàng chờ thành cũng tính là bot đã luyện.
			for item in g2.castles[pid].train_queue:
				if str(item["unit_type"]) == "monk":
					seen_monk = true
			if seen_monk:
				break
		if g2.match_over:
			break
	_check("monkf", seen_monk, "trong trận bot có phe luyện được Tu Sĩ (sau %.0f s chờ, match_over=%s)" % [t, str(g2.match_over)])
	_finish(g2)

func _finish(g) -> void:
	if is_instance_valid(g):
		g.queue_free()
	await _wait(0.2)
	if _failures.is_empty():
		print("TEST MONK: ALL PASS")
		quit(0)
	else:
		print("TEST MONK: FAILURES = %s" % [", ".join(_failures)])
		quit(1)
