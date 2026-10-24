extends SceneTree

## PROBE (không chấm điểm): chạy trận bot như g2e, ghi tiến triển mỗi 60s game:
## máu thành + số quân từng phe — để phân biệt "trận chậm nhưng tiến" với
## "trận ĐỨNG HẲN" (stall). godot --headless --script tests/_probe_g2e.gd

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _initialize() -> void:
	_run()

func _run() -> void:
	Engine.time_scale = 20.0
	paused = false
	var g = load("res://scenes/main.tscn").instantiate()
	g.bots_enabled = true
	root.add_child(g)
	await _wait(0.5)
	var t := 0.0
	while t < 3000.0 and not g.match_over:
		await _wait(60.0)
		t += 60.0
		var line := "t=%5.0fs over=%s | " % [t, str(g.match_over)]
		for pid in 4:
			var p = g.get_player(pid)
			var castle_hp := -1.0
			if g.castles.has(pid) and is_instance_valid(g.castles[pid]):
				castle_hp = (g.castles[pid] as Castle).hp
			var army := 0
			var pop := 0
			for n in get_nodes_in_group("units"):
				var u := n as Unit
				if u != null and u.owner_pid == pid and u.is_alive():
					army += 1
			for n in get_nodes_in_group("villagers"):
				var v := n as Node
				if v != null and "owner_pid" in v and int(v.get("owner_pid")) == pid:
					pop += 1
			line += "P%d[alive=%s thanh=%.0f quan=%d dan=%d] " % [pid, str(p.alive), castle_hp, army, pop]
		print(line)
	print("PROBE DONE: match_over=", g.match_over, " sau ", t, "s")
	quit(0)
