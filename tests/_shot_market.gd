extends SceneTree

## CÔNG CỤ CHỤP ẢNH panel CHỢ (không phải test): vào trận không bot, cấp
## thêm tài nguyên cho người chơi, bán 2 gói gỗ để giá TRÔI xuống (nút BÁN
## hiện 59 + nhãn "Giá đang THẤP hơn gốc"), mở tab Chợ (tab 3) rồi chụp
## toàn khung hình — panel nổi giữa-dưới hiện giá 3 loại gỗ/đá/thịt.
## Chạy:
##   xvfb-run -a -s "-screen 0 1280x720x24" <godot-4.3> --audio-driver Dummy \
##     --path . --script tests/_shot_market.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var g = scene.instantiate()
	g.bots_enabled = false
	root.add_child(g)
	Engine.time_scale = 1.0
	await create_timer(0.8).timeout
	if g._hud != null and g._hud.has_method("close_help"):
		g._hud.close_help()
	g._fog_overlay.visible = false # chỉ để soi cảnh trong ảnh chụp

	# Sân khấu: kho đầy hàng cho số đọc đẹp + giá gỗ đã trôi vì bán 2 gói.
	var p0 = g.get_player(0)
	for k in Stats.RES_KEYS:
		g.grant_resource(0, k, 600)
	g.exec_market_sell(p0, "wood")
	g.exec_market_sell(p0, "wood")

	# Camera về thành người chơi, mở tab Chợ.
	g.set_camera_to(g.castles[0].global_position)
	g._hud.open_tab(3)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("res://screenshots/cho.png")
	print("SHOT_SAVED screenshots/cho.png — gia ban go hien tai: %d vang/goi" % g.market_sell_price(0, "wood"))
	quit(0)
