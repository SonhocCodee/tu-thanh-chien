extends SceneTree

## Test headless — TEAM AI + VÒNG ĐỜI TÀI NGUYÊN.
## Chạy: godot --headless --script tests/test_ai.gd
## ai1) Tách đàn khi giao tranh cụm. ai2) Ưu tiên mục tiêu (yếu máu trước).
## ai3) Leash giữ nhà (không đuổi xa). ai4) Cây đổ+gốc+mọc lại, đá nứt+vỡ, vàng Destroyed.
## ai5) Cừu: giữ đàn, bỏ chạy, chết để lại xác thịt, đàn hồi sinh.

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

func _min_pairwise(units: Array) -> float:
	var best := 1e9
	for i in units.size():
		for j in range(i + 1, units.size()):
			var d := (units[i] as Node2D).global_position.distance_to((units[j] as Node2D).global_position)
			if d < best:
				best = d
	return best

func _run() -> void:
	# ============ ai5) Cừu: đàn + bỏ chạy + xác thịt + hồi đàn (scene riêng) ============
	Engine.time_scale = 10.0
	var pasture := Node2D.new()
	root.add_child(pasture)
	var keeper := HerdKeeper.new()
	keeper.position = Vector2(500, 420)
	pasture.add_child(keeper)
	keeper.setup(200.0, 3, 1.0)
	var t := 0.0
	while t < 6.0 and keeper.herd_count() < 3:
		await _wait(0.25)
		t += 0.25
	var herd_ok := keeper.herd_count() == 3
	var sheep_list: Array = []
	for n in get_nodes_in_group("animals"):
		sheep_list.append(n)
	# Bỏ chạy khi có "quân" áp sát.
	var flee_ok := false
	var saw_flee := false
	if not sheep_list.is_empty():
		var sheep := sheep_list[0] as Sheep
		var threat := Node2D.new()
		threat.add_to_group("units")
		threat.position = sheep.global_position + Vector2(28, 0)
		pasture.add_child(threat)
		var d0 := sheep.global_position.distance_to(threat.position)
		t = 0.0
		while t < 2.0:
			await _wait(0.2)
			t += 0.2
			if sheep.ai_state() == "flee":
				saw_flee = true
			if sheep.global_position.distance_to(threat.position) > d0 + 30.0:
				break
		flee_ok = saw_flee and sheep.global_position.distance_to(threat.position) > d0 + 25.0
		threat.queue_free()
	# Chết -> xác thịt; đàn hồi sinh về đủ trần.
	var carcass_ok := false
	var respawn_ok := false
	if not sheep_list.is_empty():
		var sheep2 := sheep_list[0] as Sheep
		sheep2.take_damage(9999.0, 0)
		await _wait(0.4)
		for n in get_nodes_in_group("res_nodes"):
			var node := n as ResourceNode
			if node.res_type == "meat" and node.amount == int(Stats.ANIMALS["sheep_meat"]):
				carcass_ok = true
		t = 0.0
		while t < 6.0 and keeper.herd_count() < 3:
			await _wait(0.25)
			t += 0.25
		respawn_ok = keeper.herd_count() == 3
	_check("ai5", herd_ok and flee_ok and carcass_ok and respawn_ok,
		"đàn đủ trần 3=%s, cừu bỏ chạy khi bị áp sát=%s (thấy trạng thái flee=%s), chết để lại xác thịt %d=%s, đàn hồi sinh đủ lại=%s" % [str(herd_ok), str(flee_ok), str(saw_flee), int(Stats.ANIMALS["sheep_meat"]), str(carcass_ok), str(respawn_ok)])
	root.remove_child(pasture)
	pasture.free()
	await _wait(0.2)

	# ============ ai1) Tách đàn: 6 kiếm sĩ xuất phát ĐÚNG 1 điểm, vây 1 địch ============
	var g = await _new_game(false, 20.0)
	await _wait(0.5)
	var punchbag := _spawn_unit(g, 2, "warrior", Vector2(820, 480))
	punchbag.hp = 100000.0
	punchbag.max_hp = 100000.0
	g.controllers[2].order_move(Vector2(820, 480))
	var attackers: Array = []
	for i in 6:
		attackers.append(_spawn_unit(g, 0, "warrior", Vector2(700, 480)))
	g.controllers[0].order_move(Vector2(820, 480))
	# Đếm thời gian theo GIÂY MÔ PHỎNG (timer chịu time_scale): chờ điều kiện
	# bền (địch đã bị đánh + cặp quân sống gần nhất cách nhau >= 11px).
	t = 0.0
	var spread_ok := false
	var last_min_pair := 0.0
	while t < 25.0:
		await _wait(0.5)
		t += 0.5
		var alive_attackers: Array = []
		for a in attackers:
			if is_instance_valid(a) and (a as Unit).is_alive():
				alive_attackers.append(a)
		if alive_attackers.size() >= 2:
			last_min_pair = _min_pairwise(alive_attackers)
		if punchbag.hp < 100000.0 and last_min_pair >= 11.0:
			spread_ok = true
			break
	_check("ai1", spread_ok and punchbag.hp < 100000.0,
		"6 quân xuất phát cùng 1 điểm: khoảng cách cặp nhỏ nhất khi giao tranh=%.1fpx (phải >= 11, không chồng điểm), địch bị đánh mất máu=%s" % [last_min_pair, str(punchbag.hp < 100000.0)])

	# ============ ai2) Ưu tiên mục tiêu: cung thủ chọn địch YẾU MÁU dù xa hơn ============
	g = await _new_game(false, 20.0)
	await _wait(0.5)
	var archer := _spawn_unit(g, 0, "archer", Vector2(500, 480))
	var enemy_a := _spawn_unit(g, 2, "warrior", Vector2(600, 480)) # gần (100px), đầy máu
	var enemy_b := _spawn_unit(g, 2, "warrior", Vector2(645, 480)) # xa hơn (145px), yếu máu
	enemy_b.hp = 20.0
	g.controllers[0].order_move(Vector2(560, 480))
	g.controllers[2].order_move(Vector2(620, 480))
	var picked: Node = null
	t = 0.0
	while t < 1.5 and picked == null:
		await _wait(0.05)
		t += 0.05
		if archer.is_alive():
			picked = archer.current_target()
	_check("ai2", picked == enemy_b,
		"mục tiêu đầu tiên của cung thủ = địch yếu máu ở 145px (điểm thấp hơn địch đầy máu ở 100px nhờ target_hp_bias): %s" % str(picked == enemy_b))

	# ============ ai3) Leash (thái độ move/trinh sát): đuổi theo địch bị kéo đi
	# nhưng KHÔNG vượt vòng leash quanh điểm được lệnh; địch xa hẳn -> quay về điểm.
	# (Thái độ hold còn bị luật engage 265px quanh thành chặn trước — leash phát
	# huy ở move: trinh sát không bị dụ chạy khắp map.)
	g = await _new_game(false, 20.0)
	await _wait(0.5)
	var castle0: Vector2 = g.public_castle_pos(0)
	var anchor := Vector2(700, 480)
	var defender := _spawn_unit(g, 0, "warrior", anchor)
	var dummy := _spawn_unit(g, 2, "warrior", anchor + Vector2(75, 0))
	dummy.hp = 100000.0
	dummy.max_hp = 100000.0
	dummy.set_process(false) # địch thụ động: chỉ di chuyển do test kéo đi
	g.controllers[0].order_move(anchor)
	# Giai đoạn 1: defender áp sát đánh địch tại chỗ (chứng minh có giao tranh).
	t = 0.0
	while t < 2.0 and dummy.hp >= 100000.0:
		await _wait(0.1)
		t += 0.1
	var fought := dummy.hp < 100000.0
	# Giai đoạn 2: kéo địch chạy xa dần, CHẬM hơn tốc độ defender (36px/giây mô
	# phỏng < 72px/s) để defender bám kịp; nó đuổi tới vòng leash thì dừng.
	var max_dist := 0.0
	t = 0.0
	while t < 30.0 and dummy.global_position.x < 1350.0:
		await _wait(1.0)
		t += 1.0
		dummy.global_position.x += 36.0
		if is_instance_valid(defender):
			var dd := defender.global_position.distance_to(anchor)
			if dd > max_dist:
				max_dist = dd
	# Giai đoạn 3: địch ngoài vòng -> defender quay về điểm được lệnh.
	var back_ok := false
	t = 0.0
	while t < 10.0:
		await _wait(0.25)
		t += 0.25
		if is_instance_valid(defender) and defender.global_position.distance_to(anchor) <= 70.0:
			back_ok = true
			break
	var leash_limit := float(Stats.UNIT_AI["leash_move"]) + 36.0 + 60.0
	_check("ai3", fought and max_dist > 120.0 and max_dist <= leash_limit and back_ok,
		"có giao tranh tại điểm trinh sát=%s, defender đuổi xa nhất=%.0fpx khỏi điểm lệnh (giới hạn leash+đuôi=%.0f, địch bị kéo tới 1350), quay về điểm lệnh=%s" % [str(fought), max_dist, leash_limit, str(back_ok)])

	# ============ ai4) Vòng đời tài nguyên: cây/gốc/mọc lại, đá nứt/vỡ, vàng Destroyed ============
	g = await _new_game(false, 20.0)
	await _wait(0.5)
	var wood_node: ResourceNode = null
	var best_d := 1e9
	for n in get_nodes_in_group("res_nodes"):
		var node := n as ResourceNode
		if node.res_type != "wood":
			continue
		var d := node.global_position.distance_to(castle0)
		if d < best_d:
			best_d = d
			wood_node = node
	var tree_ok := false
	var stump_ok := false
	var skip_ok := false
	var regrow_ok := false
	if wood_node != null:
		var full := wood_node.max_amount
		var got1: int = wood_node.take(10)
		tree_ok = got1 == 10 and wood_node.amount == full - 10 and not wood_node.is_depleted()
		wood_node.take(full)
		t = 0.0
		while t < 3.0 and wood_node.state_name() != "stump":
			await _wait(0.2)
			t += 0.2
		stump_ok = wood_node.is_depleted() and wood_node.state_name() == "stump"
		var nearest = g.nearest_resource_node(0, "wood", castle0)
		skip_ok = nearest != null and nearest != wood_node
		wood_node._regen_left = 0.5 # test: rút ngắn chờ hồi (regen_time thật = 90s)
		t = 0.0
		while t < 3.0 and wood_node.state_name() != "ready":
			await _wait(0.2)
			t += 0.2
		regrow_ok = wood_node.state_name() == "ready" and wood_node.amount == wood_node.max_amount and not wood_node.is_depleted()
	# Đá: mức nứt theo tỉ lệ cạn + vỡ tan khi cạn hẳn.
	var stone := ResourceNode.new()
	stone.setup("stone", false)
	stone.position = Vector2(500, 300)
	g.add_child(stone)
	stone.take(160) # còn 80%
	var crack0 := stone.crack_level()
	stone.take(240) # còn 50%
	var crack2 := stone.crack_level()
	stone.take(200) # còn 25%
	var crack3 := stone.crack_level()
	stone.take(200) # cạn -> vỡ
	await _wait(0.3)
	var shatter_ok := not is_instance_valid(stone)
	var stone_ok := crack0 == 0 and crack2 == 2 and crack3 == 3 and shatter_ok
	# Vàng: cạn -> Destroyed, còn nguyên node (phế tích), không farm được.
	var gold := ResourceNode.new()
	gold.setup("gold", false)
	gold.position = Vector2(580, 300)
	g.add_child(gold)
	gold.take(gold.max_amount)
	var gold_ok := is_instance_valid(gold) and gold.state_name() == "destroyed" and gold.is_depleted() and gold.take(10) == 0
	_check("ai4", tree_ok and stump_ok and skip_ok and regrow_ok and stone_ok and gold_ok,
		"cây trừ trữ lượng đúng=%s, cạn -> gốc=%s, nông dân bỏ qua gốc=%s, gốc mọc lại đầy=%s, đá nứt 0/2/3 + vỡ tan=%s, vàng cạn -> Destroyed=%s" % [str(tree_ok), str(stump_ok), str(skip_ok), str(regrow_ok), str(stone_ok), str(gold_ok)])

	print("==================================")
	if _failures == 0:
		print("ALL TESTS PASS")
	else:
		print("TESTS FAILED: ", _failures)
	quit(1 if _failures > 0 else 0)
