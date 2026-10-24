extends SceneTree

## Chụp kiểm chứng GỐC CÂY (cần render thật, KHÔNG --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" tools_bin/Godot_v4.3-stable_linux.x86_64 \
##     --audio-driver Dummy --path . --script tests/_shot_stump.gd -- --out truoc
## Bày: hàng trên = 4 cặp cây NHỎ (đứng | gốc) đủ 4 biến thể stump;
## hàng dưới = 2 cặp cây LỚN (đứng | gốc). Ảnh ra screenshots/canbang_goc_<out>.png

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _initialize() -> void:
	_run()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path)

func _add_node(g: Node, pos: Vector2, big: bool, variant: int) -> ResourceNode:
	var n := ResourceNode.new()
	n.setup("wood", big, variant)
	n.position = pos
	n.z_index = -4
	g.add_child(n)
	return n

func _spawn_lantern(g: Node, pos: Vector2) -> void:
	# Quân "đèn lồng": đóng băng tại chỗ, chỉ làm nguồn tầm nhìn xua sương mù
	# cho bãi chụp (sương mù tính từ vị trí quân, không cần nó xử lý).
	var u := load("res://scenes/unit.tscn").instantiate() as Unit
	u.setup(0, "warrior", g.get_player(0).color_key, g, Vector2.ZERO)
	u.position = pos
	u.z_index = 10
	g.add_child(u)
	u.died.connect(g._on_unit_died)
	u.set_process(false)

func _run() -> void:
	Engine.time_scale = 1.0
	var tag := "sau"
	for a in OS.get_cmdline_user_args():
		if a in ["truoc", "sau"]:
			tag = a
	var g = load("res://scenes/main.tscn").instantiate()
	g.bots_enabled = false
	root.add_child(g)
	await _wait(1.0)
	if g._hud != null and g._hud.has_method("close_help"):
		g._hud.close_help()
	if g._fog_overlay != null:
		g._fog_overlay.visible = false # chỉ để soi sprite trong ảnh (như _shot_fixcay)
	# (Bản main ẩn hẳn lớp sương mù để chụp nên không cần hàng quân "đèn lồng"
	# xua sương mù như bản nhánh nữa.)
	# Hàng cây NHỎ: 4 cặp (đứng | gốc) cho 4 biến thể.
	for v in 4:
		var x := 690.0 + float(v) * 180.0
		_add_node(g, Vector2(x, 400), false, v)
		var stump := _add_node(g, Vector2(x + 88.0, 400), false, v)
		stump.take_harvest(99999)
	# Hàng cây LỚN: 2 cặp (đứng | gốc) biến thể 1 và 3.
	for i in 2:
		var v: int = [0, 2][i]
		var x := 780.0 + float(i) * 360.0
		_add_node(g, Vector2(x, 590), true, v)
		var stump := _add_node(g, Vector2(x + 150.0, 590), true, v)
		stump.take_harvest(99999)
	await _wait(1.6) # chờ cây đổ xong, còn gốc
	g._camera.zoom = Vector2(1.6, 1.6)
	g.set_camera_to(Vector2(960, 480))
	await _wait(0.3)
	await _shot("res://screenshots/canbang_goc_%s.png" % tag)
	print("SHOTS DONE")
	quit(0)
