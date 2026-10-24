extends SceneTree

## CÔNG CỤ CHỤP ẢNH kiểm chứng TU SĨ (không phải test): dựng đội hình
## 3 kiếm sĩ bị thương + 1 tu sĩ phe Xanh quanh điểm tập kết, chờ tu sĩ
## vào nhịp chữa (anim "heal" + hiệu ứng Heal_Effect hiện trên mục tiêu)
## rồi chụp cận cảnh.
## Chạy:
##   xvfb-run -a -s "-screen 0 1280x720x24" <godot-4.3> --audio-driver Dummy \
##     --path . --script tests/shot_monk.gd

func _initialize() -> void:
	_run.call_deferred()

func _capture_centre() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var full := root.get_texture().get_image()
	return full.get_region(Rect2i(390, 110, 500, 500))

func _units_of(pid: int, utype: String) -> Array:
	var out: Array = []
	for n in get_nodes_in_group("units"):
		var u := n as Unit
		if u.owner_pid == pid and u.unit_type == utype and u.is_alive():
			out.append(u)
	return out

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
	for k in Stats.RES_KEYS:
		p0.resources[k] = 9000
	var ctrl0 = g.human_controller()
	ctrl0.queue_training(g.castles[0], "monk")
	for i in 3:
		g.spawn_trained_unit(0, "warrior", g.castles[0])
	# Chờ tu sĩ ra quân.
	var monk: Unit = null
	var t := 0.0
	while monk == null and t < 20.0:
		await create_timer(0.25).timeout
		t += 0.25
		var arr := _units_of(0, "monk")
		if not arr.is_empty():
			monk = arr[0]
	if monk == null:
		print("SHOT_MONK: FAIL — không luyện được tu sĩ")
		quit(1)
		return
	# Xếp đội hình: tu sĩ giữa, 3 kiếm sĩ quanh, tất cả bị thương.
	var centre: Vector2 = g.rally_point(0) + Vector2(150, 40)
	monk.global_position = centre
	var warriors := _units_of(0, "warrior")
	var offs := [Vector2(-62, -8), Vector2(58, -20), Vector2(6, 58)]
	for i in warriors.size():
		(warriors[i] as Unit).global_position = centre + offs[i % offs.size()]
		(warriors[i] as Unit).hp = 45.0
	Engine.time_scale = 1.0
	g._camera.zoom = Vector2(2.2, 2.2)
	g._camera.position = centre + Vector2(0, -16)
	# Chờ bắt đúng khoảnh khắc hiệu ứng chữa đang hiện trên mục tiêu.
	var shot: Image = null
	t = 0.0
	while t < 12.0:
		await RenderingServer.frame_post_draw
		t += 1.0 / 60.0
		if monk.get("_heal_fx") != null and (monk.get("_heal_fx") as CanvasItem).visible:
			shot = await _capture_centre()
			break
	if shot == null:
		shot = await _capture_centre()
		print("SHOT_MONK: không bắt được frame FX, chụp ảnh thường")
	shot.save_png("res://screenshots/monk_heal.png")
	print("SHOT_SAVED screenshots/monk_heal.png")
	quit(0)
