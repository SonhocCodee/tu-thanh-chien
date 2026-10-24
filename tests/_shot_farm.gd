extends SceneTree

## CÔNG CỤ CHỤP ẢNH kiểm chứng RUỘNG trên main (không phải test):
##   Ảnh 1 (farm_lam_ruong.png): ruộng cạnh thành, 1 nông dân đang làm
##   ruộng (giữa lượt harvest), kho thịt + nhãn thịt còn của ruộng hiện rõ.
##   Ảnh 2 (farm_can.png): ruộng đã cạn tự sụp — chỉ còn ĐẤT TRỐNG.
## Chạy:
##   xvfb-run -a -s "-screen 0 1280x720x24" <godot-4.3> --audio-driver Dummy \
##     --path . --script tests/_shot_farm.gd

func _initialize() -> void:
	_run.call_deferred()

func _capture() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

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

	var p0 = g.get_player(0)
	var castle_pos: Vector2 = g.castles[0].global_position
	g.exec_set_allocation(p0, 0, 0, 0, 0)
	# Kho thịt + ruộng cạnh thành (qua đường exec thật, xây xong ngay kiểu sân khấu).
	g.exec_place_building(p0, "store_meat", castle_pos + Vector2(240, -10))
	g.exec_place_building(p0, "farm", castle_pos + Vector2(140, 130))
	var farm: Building = null
	var store: Building = null
	for n in get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == 0 and b.building_type == "farm":
			farm = b
		if b.owner_pid == 0 and b.building_type == "store_meat":
			store = b
	farm.constructed = true
	store.constructed = true
	farm._refresh_display()
	store._refresh_display()
	await create_timer(0.5).timeout # node trong ruộng BẬT

	# Nông dân ra làm ruộng; chờ tới giữa lượt harvest mới chụp.
	var v0: Villager = null
	for n in get_nodes_in_group("villagers"):
		var v := n as Villager
		if v.owner_pid == 0:
			v0 = v
			break
	var fnode: ResourceNode = farm.get("_farm_node")
	g.exec_direct_farm(p0, v0, fnode)
	var t := 0.0
	while str(v0.get("_state")) != "harvest" and t < 40.0:
		await create_timer(0.25).timeout
		t += 0.25
	g.set_camera_to(farm.global_position + Vector2(-60, 10))
	await create_timer(0.3).timeout
	var img1 := await _capture()
	img1.save_png("res://screenshots/farm_lam_ruong.png")
	print("SHOT_SAVED screenshots/farm_lam_ruong.png (state=%s)" % str(v0.get("_state")))

	# Hút cạn ruộng -> tự sụp thành đất trống; chờ qua khoảnh khắc sụp.
	fnode.set_amount(0)
	await create_timer(1.2).timeout
	var img2 := await _capture()
	img2.save_png("res://screenshots/farm_can.png")
	print("SHOT_SAVED screenshots/farm_can.png (farm destroyed=%s)" % str(farm.destroyed))
	quit(0)
