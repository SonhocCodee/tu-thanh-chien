extends SceneTree

## CÔNG CỤ CHỤP ẢNH kiểm chứng sửa lỗi cắt sprite cây (không phải test):
## bản đồ thật, tắt lớp sương mù chỉ để soi sprite (không đổi gameplay).
## Ảnh ra là 1 hình ghép 2 ô cạnh nhau:
##   TRÁI  = 1 cây nhỏ đứng lẻ cạnh thành người chơi (370,735), zoom 2.
##   PHẢI  = bìa rừng giữa map: 2 cây lớn (900,155)+(1020,155) + cây trang
##           trí của main.gd ở (645,180) — cùng lỗi cắt lát cây thứ 2.
## Chạy TRƯỚC và SAU khi sửa với tên file ra khác nhau:
##   xvfb-run -a -s "-screen 0 1280x720x24" <godot-4.3> --audio-driver Dummy \
##     --path . --script tests/_shot_fixcay.gd -- fix_cay_truoc.png

func _initialize() -> void:
	_run.call_deferred()

func _capture_centre() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var full := root.get_texture().get_image()
	# Cắt ô 500x500 quanh tâm viewport (cây đã được đặt giữa khung).
	return full.get_region(Rect2i(390, 110, 500, 500))

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_name := "fix_cay_sau.png"
	if args.size() > 0:
		out_name = args[0]
	var scene: PackedScene = load("res://scenes/main.tscn")
	var g = scene.instantiate()
	g.bots_enabled = false
	root.add_child(g)
	await create_timer(0.8).timeout
	if g._hud != null and g._hud.has_method("close_help"):
		g._hud.close_help()
	g._fog_overlay.visible = false # chỉ để soi sprite trong ảnh chụp

	# Ô TRÁI: cây nhỏ đứng lẻ cạnh thành (có thật trên map).
	# Gán thẳng _camera.position (bỏ qua _clamp_camera của set_camera_to —
	# hàm đó kẹp theo nửa viewport CHƯA nhân zoom nên khung chụp bị lệch).
	g._camera.zoom = Vector2(2, 2)
	g._camera.position = Vector2(370, 735)
	await create_timer(0.3).timeout
	var left := await _capture_centre()

	# Ô PHẢI: bìa rừng cây lớn giữa map + cây trang trí.
	g._camera.zoom = Vector2(1.25, 1.25)
	g._camera.position = Vector2(960, 210)
	await create_timer(0.3).timeout
	var right := await _capture_centre()

	var combo := Image.create(1000, 500, false, Image.FORMAT_RGBA8)
	combo.blit_rect(left, Rect2i(0, 0, 500, 500), Vector2i(0, 0))
	combo.blit_rect(right, Rect2i(0, 0, 500, 500), Vector2i(500, 0))
	combo.save_png("res://screenshots/" + out_name)
	print("SHOT_SAVED screenshots/", out_name)
	quit(0)
