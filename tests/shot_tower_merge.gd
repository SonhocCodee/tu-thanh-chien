extends SceneTree

## Chụp ảnh kiểm chứng SAU TÍCH HỢP THÁP CUNG THỦ vào main (render thật,
## KHÔNG --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" tools_bin/Godot_v4.3-stable_linux.x86_64 \
##     --audio-driver Dummy --path . --script tests/shot_tower_merge.gd
## Ảnh ra screenshots/:
##   tower_merge_cung_dang_ban.png — tháp xây xong, cung thủ đứng nóc đang
##     bắn (hoạt ảnh attack / tên bay), địch áp sát trong tầm.
##   tower_merge_bong_ma_do.png — dân số ĐẦY: bóng ma tháp nhuộm ĐỎ ở vị
##     trí vốn hợp lệ + HUD hiện lý do place_fail_reason (cần ô dân).

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _initialize() -> void:
	_run()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path)

func _new_game():
	var g = load("res://scenes/main.tscn").instantiate()
	g.bots_enabled = false # gán TRƯỚC add_child
	root.add_child(g)
	await _wait(0.6)
	if g._hud != null:
		g._hud.close_help()
	var p0 = g.get_player(0)
	for k in Stats.RES_KEYS:
		p0.resources[k] = 5000
	return g

## Cùng thuật toán quét vị trí như test_tower: địch đứng cách tháp 70/170
## vẫn ngoài tầm thành chính -> phát bắn nào cũng là của cung thủ nóc tháp.
func _find_spot(g, p) -> Vector2:
	var castle_pos: Vector2 = g.castles[p.pid].global_position
	var zone: Rect2 = g.base_zone(p.pid)
	for cx in range(int(zone.position.x) + 20, int(zone.end.x) - 10, 10):
		for cy in range(int(zone.position.y) + 20, int(zone.end.y) - 10, 10):
			var pos := Vector2(cx, cy)
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
	# ---------- BÀY 1: cung thủ trên nóc tháp đang bắn ----------
	var g = await _new_game()
	var p0 = g.get_player(0)
	var spot := _find_spot(g, p0)
	print("SPOT ", spot)
	g.human_controller().place_building("tower", spot)
	var tower: Building = null
	for n in get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == 0 and b.building_type == "tower":
			tower = b
	var enemy = load("res://scenes/unit.tscn").instantiate()
	enemy.setup(1, "warrior", g.get_player(1).color_key, g, Vector2.ZERO)
	enemy.position = spot + Vector2(170, 0)
	enemy.z_index = 10
	g.get("_units_layer").add_child(enemy)
	enemy.set_direct_attack(tower)
	Engine.time_scale = 10.0
	var guard := 0
	while (tower == null or not tower.constructed) and guard < 40:
		await _wait(0.5)
		guard += 1
	Engine.time_scale = 1.0
	print("MANNED ", tower != null and tower.archer_manned())
	# LƯU Ý camera: _clamp_camera của main kẹp tâm vào [640..1280]x[360..600]
	# (nửa viewport zoom 1) — tháp ở góc (350,875) KHÔNG bao giờ ra giữa
	# khung được, kể cả trong game thật. Zoom 1 + tâm kẹp (640,600) thì
	# tháp hiện ở (350,635) màn hình, thành chính + địch cùng lọt khung.
	g.set_camera_to(spot)
	root.warp_mouse(Vector2(640, 360)) # chuột giữa màn: tránh lia camera theo cạnh
	# Chờ đúng khoảnh khắc cung thủ giương cung (anim attack) rồi chụp.
	# Ghim lại camera mỗi vòng: lia cạnh có thể đã kéo camera đi chỗ khác.
	var snapped := false
	for i in 60:
		g.set_camera_to(spot)
		await _wait(0.12)
		var arch = tower.get("_archer") as AnimatedSprite2D
		if arch != null and arch.animation == "attack" and arch.is_playing():
			await _shot("res://screenshots/tower_merge_cung_dang_ban.png")
			snapped = true
			break
	if not snapped:
		await _shot("res://screenshots/tower_merge_cung_dang_ban.png")
	print("ENEMY_HP ", enemy.hp, " / ", enemy.max_hp)
	g.queue_free()
	await _wait(0.4)

	# ---------- BÀY 2: dân đầy -> bóng ma tháp ĐỎ + lý do ----------
	Engine.time_scale = 1.0
	var g2 = await _new_game()
	var q0 = g2.get_player(0)
	var ctrl = g2.human_controller()
	var guard2 := 0
	while g2.pop_used(0) < g2.pop_cap(0) and guard2 < 30:
		guard2 += 1
		if not ctrl.queue_training(g2.castles[0], "pawn"):
			break
	print("POP ", g2.pop_used(0), "/", g2.pop_cap(0))
	var slot: Vector2 = g2.build_slots(0)[2]
	g2.set_placement_mode("tower")
	g2.set_camera_to(slot)
	await _wait(0.3)
	root.warp_mouse(Vector2(640, 360))
	# Hiện đúng thông báo mà cú click đặt thất bại sẽ bật (place_fail_reason).
	var reason: String = g2.place_fail_reason(q0, "tower", slot)
	print("REASON ", reason)
	if g2._hud != null and reason != "":
		g2._hud.show_message(reason)
	await _wait(0.5)
	await _shot("res://screenshots/tower_merge_bong_ma_do.png")
	print("SHOTS DONE")
	quit(0)
