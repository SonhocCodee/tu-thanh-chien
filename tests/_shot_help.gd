extends SceneTree

## CÔNG CỤ CHỤP ẢNH bảng HƯỚNG DẪN ĐIỀU KHIỂN (không phải test): vào trận
## không bot, bảng hướng dẫn tự mở khi vào trận — chụp trạng thái đầu (chưa
## cuộn) ra screenshots/help_top.png. Nếu vùng chữ là ScrollContainer, đặt
## scroll_vertical về max rồi chụp tiếp screenshots/help_bottom.png để soi
## dòng cuối có tới được không. Đặt SHOT_LABEL=before|after qua biến môi
## trường để phân biệt thư mục xuất nếu cần (mặc định ghi thẳng screenshots/).
## Chạy:
##   xvfb-run -a -s "-screen 0 1280x720x24" <godot-4.3> --audio-driver Dummy \
##     --path . --script tests/_shot_help.gd

func _initialize() -> void:
	_run.call_deferred()

func _find_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer:
		return n
	for c in n.get_children():
		var r := _find_scroll(c)
		if r != null:
			return r
	return null

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var g = scene.instantiate()
	g.bots_enabled = false
	root.add_child(g)
	Engine.time_scale = 1.0
	await create_timer(0.8).timeout
	# Bảng hướng dẫn đã tự mở khi vào trận; chắc chắn nó đang mở.
	if g._hud != null and g._hud.has_method("show_help"):
		g._hud.show_help()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("res://screenshots/help_top.png")
	print("SHOT_SAVED screenshots/help_top.png size=", img.get_size())

	var sc := _find_scroll(g._hud)
	if sc != null:
		var maxv := sc.get_v_scroll_bar().max_value
		sc.scroll_vertical = int(maxv)
		print("SCROLL max=", maxv, " page=", sc.get_v_scroll_bar().page)
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img2 := root.get_texture().get_image()
		img2.save_png("res://screenshots/help_bottom.png")
		print("SHOT_SAVED screenshots/help_bottom.png")
	else:
		print("NO_SCROLL_CONTAINER")
	quit(0)
