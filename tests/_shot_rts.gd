extends SceneTree

## CÔNG CỤ CHỤP ẢNH nhóm LỆNH RTS ở tab Luyện (không phải test): vào trận
## không bot, mở tab HUẤN LUYỆN (tab 1) rồi chụp toàn khung hình — cuối
## panel có nhóm "LỆNH RTS" với 5 nút: ĐÁNH–DI CHUYỂN (A) / TUẦN TRA (P) /
## HỘ VỆ (G) / CHỌN TOÀN QUÂN (Shift+A) / NÔNG DÂN NHÀN (.).
## Chạy:
##   xvfb-run -a -s "-screen 0 1280x720x24" <godot-4.3> --audio-driver Dummy \
##     --path . --script tests/_shot_rts.gd

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
	g.set_camera_to(g.castles[0].global_position)
	g._hud.open_tab(1)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("res://screenshots/rts.png")
	print("SHOT_SAVED screenshots/rts.png")
	quit(0)
