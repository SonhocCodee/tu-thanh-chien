extends SceneTree

## Chụp ảnh kiểm chứng AI + vòng đời tài nguyên (cần render thật, KHÔNG --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --audio-driver Dummy \
##     --path . --script tests/shot_ai.gd
## Bãi diễn: vùng trống quanh (1000,300) — 2 kiếm sĩ phe 0 đứng giữ sáng bằng
## tầm nhìn của chính chúng (đúng luật sương mù), tài nguyên bày theo hàng.
## Ảnh: ai_tai_nguyen.png (cây đầy/gốc/mọc lại, đá nguyên/nứt, mỏ vàng Destroyed),
##      ai_cuu_bo_chay.png (đàn cừu + 1 con bỏ chạy khỏi lính địch),
##      ai_quan_tan_ra.png (đàn quân tản ra khi vây địch ở bãi trống).

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _initialize() -> void:
	_run()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path)

func _spawn_unit(g: Node, pid: int, unit_type: String, pos: Vector2) -> Unit:
	var u := load("res://scenes/unit.tscn").instantiate() as Unit
	u.setup(pid, unit_type, g.get_player(pid).color_key, g, Vector2.ZERO)
	u.position = pos
	u.z_index = 10
	g.add_child(u)
	u.died.connect(g._on_unit_died)
	return u

func _add_node(g: Node, res_type: String, pos: Vector2) -> ResourceNode:
	var n := ResourceNode.new()
	n.setup(res_type, false)
	n.position = pos
	n.z_index = -4
	g.add_child(n)
	return n

func _run() -> void:
	Engine.time_scale = 1.0
	var g = load("res://scenes/main.tscn").instantiate()
	g.bots_enabled = false
	root.add_child(g)
	await _wait(1.0)
	if g._hud != null:
		g._hud.close_help()

	# ---------- BÀY 1: vòng đời tài nguyên ở bãi trống (1000,300) ----------
	_spawn_unit(g, 0, "warrior", Vector2(950, 335))
	_spawn_unit(g, 0, "warrior", Vector2(1050, 335))
	g.controllers[0].order_move(Vector2(1000, 335))
	# Hàng cây: ĐẦY | GỐC (đã đổ) | MỌC LẠI.
	_add_node(g, "wood", Vector2(880, 235))
	var stump_tree := _add_node(g, "wood", Vector2(975, 235))
	var regrown_tree := _add_node(g, "wood", Vector2(1070, 235))
	stump_tree.take(99999)
	regrown_tree.take(99999)
	# Hàng đá: NGUYÊN | NỨT vừa (còn 50%) | NỨT nặng (còn 25%).
	_add_node(g, "stone", Vector2(865, 350))
	var stone_mid := _add_node(g, "stone", Vector2(960, 350))
	stone_mid.take(int(stone_mid.max_amount * 0.5))
	var stone_bad := _add_node(g, "stone", Vector2(1055, 350))
	stone_bad.take(int(stone_bad.max_amount * 0.75))
	# Hàng mỏ vàng: ĐANG KHAI THÁC | DESTROYED (cạn).
	_add_node(g, "gold", Vector2(930, 450))
	var gold_dead := _add_node(g, "gold", Vector2(1035, 450))
	gold_dead.take(99999)
	await _wait(1.4) # chờ cây đổ xong, còn gốc
	regrown_tree._regen_left = 0.3 # rút ngắn chờ hồi cho ảnh (regen thật 90s)
	await _wait(1.0) # cây mọc lại xong
	g.set_camera_to(Vector2(1000, 330))
	await _wait(0.3)
	await _shot("res://screenshots/ai_tai_nguyen.png")
	# Zoom cận cảnh cùng bãi: gốc cây + vết nứt đá đọc rõ hơn.
	g._camera.zoom = Vector2(2, 2)
	g.set_camera_to(Vector2(985, 320))
	await _wait(0.3)
	await _shot("res://screenshots/ai_tai_nguyen_zoom.png")
	g._camera.zoom = Vector2(1, 1)

	# ---------- BÀY 2: đàn cừu ở bãi chăn (1000,520), lính giữ sáng đi theo ----------
	g.controllers[0].order_move(Vector2(1000, 480))
	var keeper := HerdKeeper.new()
	keeper.position = Vector2(1000, 530)
	g.add_child(keeper)
	keeper.setup(150.0, 4, 30.0)
	var first_sheep: Sheep = null
	for i in 4:
		var s := keeper.spawn_one()
		if i == 0:
			first_sheep = s
	# Lính địch thụ động đứng sát con cừu đầu -> nó phải bỏ chạy về phía tây.
	var threat := _spawn_unit(g, 2, "warrior", Vector2(1095, 530))
	threat.set_process(false)
	if first_sheep != null:
		first_sheep.global_position = Vector2(1052, 530)
	g.set_camera_to(Vector2(1000, 470))
	await _wait(1.8)
	await _shot("res://screenshots/ai_cuu_bo_chay.png")

	# ---------- BÀY 3: đàn quân tản ra khi vây địch ở bãi trống (1300,350) ----------
	var punchbag := _spawn_unit(g, 2, "warrior", Vector2(1330, 350))
	punchbag.hp = 100000.0
	punchbag.max_hp = 100000.0
	g.controllers[2].order_move(Vector2(1330, 350))
	for i in 6:
		_spawn_unit(g, 0, "warrior", Vector2(1210, 350))
	g.controllers[0].order_move(Vector2(1330, 350))
	g.set_camera_to(Vector2(1300, 350))
	await _wait(4.0)
	await _shot("res://screenshots/ai_quan_tan_ra.png")

	print("SHOTS DONE")
	quit(0)
