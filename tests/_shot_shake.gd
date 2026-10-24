extends SceneTree

## CÔNG CỤ CHỤP ẢNH kiểm chứng sửa lỗi RUNG CÂY (không phải test):
## nông dân chặt 1 cây gần thành; ảnh ghép 2 ô cùng 1 cây, cùng camera:
##   TRÁI  = cây ĐỨNG YÊN (chưa ai chặt).
##   PHẢI  = GIỮA LƯỢT CHẶT, bắt đúng frame cây đang rung lệch (sau sửa:
##           villager gọi notify_hit mỗi 0.5s, biên độ ~4px, 0.25s/cú).
## Chạy:
##   xvfb-run -a -s "-screen 0 1280x720x24" <godot-4.3> --audio-driver Dummy \
##     --path . --script tests/_shot_shake.gd

func _initialize() -> void:
	_run.call_deferred()

func _capture_centre() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var full := root.get_texture().get_image()
	return full.get_region(Rect2i(390, 110, 500, 500))

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var g = scene.instantiate()
	g.bots_enabled = false
	root.add_child(g)
	Engine.time_scale = 4.0
	await create_timer(0.8).timeout
	if g._hud != null and g._hud.has_method("close_help"):
		g._hud.close_help()
	g._fog_overlay.visible = false # chỉ để soi sprite trong ảnh chụp

	var castle_pos: Vector2 = g.castles[0].global_position
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

	# Camera bám cây, zoom 3 cho lệch rung đọc rõ.
	g._camera.zoom = Vector2(3, 3)
	g._camera.position = tree.global_position + Vector2(0, -30)
	await create_timer(0.4).timeout
	var left := await _capture_centre() # cây đứng yên

	# Ra lệnh chặt; chờ vào giữa lượt.
	g.exec_direct_farm(g.get_player(0), v0, tree)
	var t := 0.0
	while str(v0.get("_state")) != "harvest" and t < 30.0:
		await create_timer(0.25).timeout
		t += 0.25
	Engine.time_scale = 1.0 # chụp theo nhịp thật

	# Bắt frame cây đang rung lệch mạnh nhất (trong lúc amount còn nguyên).
	var base_pos: Vector2 = tree.get("_spr_base_pos")
	var amount0: int = tree.amount
	var best_img: Image = null
	var best_off := 0.0
	t = 0.0
	while t < 20.0 and tree.amount == amount0:
		await RenderingServer.frame_post_draw
		t += 1.0 / 60.0
		var spr := tree.get("_sprite") as Sprite2D
		if spr == null:
			continue
		var off: float = absf(spr.position.x - base_pos.x)
		if float(tree.get("_shake_left")) > 0.05 and off > best_off:
			var img := await _capture_centre()
			best_off = off
			best_img = img
			if off >= 2.6:
				break
	print("SHAKE_SHOT offset tot nhat = %.2fpx" % best_off)
	var right := best_img
	if right == null:
		right = await _capture_centre()

	var combo := Image.create(1000, 500, false, Image.FORMAT_RGBA8)
	combo.blit_rect(left, Rect2i(0, 0, 500, 500), Vector2i(0, 0))
	combo.blit_rect(right, Rect2i(0, 0, 500, 500), Vector2i(500, 0))
	combo.save_png("res://screenshots/rung_cay.png")
	print("SHOT_SAVED screenshots/rung_cay.png")
	quit(0)
