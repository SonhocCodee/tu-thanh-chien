extends SceneTree

## CÔNG CỤ CHỤP ẢNH kiểm chứng con trỏ ngữ cảnh (không phải test): dựng trận
## không bot, chọn toàn bộ nông dân, đặt điểm hover lên cây cạnh thành rồi
## chụp viewport — vòng sáng vàng nhạt phải nổi dưới chân cây.
## Con trỏ hệ điều hành KHÔNG chụp vào ảnh được; bằng chứng phần con trỏ là
## dòng CURSOR_CTX in ra + trạng thái trong test_cursor.gd.
## Chạy (cần X ảo, KHÔNG --headless để render thật):
##   xvfb-run -a -s "-screen 0 1280x720x24" <godot-4.3> --path . --script tests/_shot_cursor.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var g = scene.instantiate()
	g.bots_enabled = false
	root.add_child(g)
	await create_timer(0.6).timeout
	if g._hud != null and g._hud.has_method("close_help"):
		g._hud.close_help()
	var ctrl = g.human_controller()
	ctrl.set_selection(g._villagers_of(0))
	var tree: ResourceNode = null
	for n in get_nodes_in_group("res_nodes"):
		var rn := n as ResourceNode
		if rn != null and rn.res_type == "wood" and rn.global_position.distance_to(Vector2(370, 735)) < 60.0:
			tree = rn
	g.set_camera_to(Vector2(430, 720))
	g.update_hover_cursor(tree.global_position)
	print("CURSOR_CTX ", g.cursor_context, " target=", g.hover_target)
	g._hover_timer = 999.0 # khoá throttle quét theo chuột thật (0,0) cho tới lúc chụp
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("res://screenshots/cursor_hover_cay.png")
	print("SHOT_SAVED screenshots/cursor_hover_cay.png")
	quit(0)
