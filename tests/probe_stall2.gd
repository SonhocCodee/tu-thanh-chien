extends SceneTree

## PROBE v2: seed co dinh tung van (global seed + reseed Bot._rng) de tai
## hien on dinh van dung -> co seed cu the chay lai sau khi sua.
## Chay: godot --headless --script tests/probe_stall2.gd

const BUDGET := 3600.0
const SEEDS := [11, 22, 33, 44, 55, 66, 77, 88, 99, 111, 222, 333]

func _initialize() -> void:
	_run.call_deferred()

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _bots(g) -> Dictionary:
	var out := {}
	for ch in g.get_children():
		if ch is Bot:
			out[ch.player.pid] = ch
	return out

func _job_counts(g, pid: int) -> Dictionary:
	var c := {"wood": 0, "stone": 0, "gold": 0, "meat": 0, "": 0}
	for n in get_nodes_in_group("villagers"):
		var v := n as Villager
		if v.owner_pid == pid:
			c[v.assigned] = int(c.get(v.assigned, 0)) + 1
	return c

func _sample(g, bots: Dictionary) -> void:
	var t := int(g.elapsed)
	for pid in range(4):
		var p = g.get_player(pid)
		var c = g.castles[pid]
		var chp := -999.0
		if c != null and is_instance_valid(c):
			chp = c.hp
		var jobs := _job_counts(g, pid)
		var bot = bots.get(pid)
		var thr := "?"
		if bot != null:
			thr = str(bot._threatened)
		var b: Dictionary = g.building_counts(pid)
		print("S t=%d P%d alive=%s chp=%d army=%d/%d mil=%d pop=%d/%d vil=%d job[w%d s%d g%d m%d i%d] res[w%d s%d g%d m%d] alloc[w%d s%d g%d m%d] stance=%s tgt=%d thr=%s bld[H%d B%d T%d SH%d SW%d SG%d SS%d SM%d]" % [
			t, pid, str(p.alive), int(chp),
			g.army_used(pid), g.army_cap(pid), g.military_count(pid),
			g.pop_used(pid), g.pop_cap(pid), g.villager_count(pid),
			int(jobs["wood"]), int(jobs["stone"]), int(jobs["gold"]), int(jobs["meat"]), int(jobs[""]),
			int(p.resources["wood"]), int(p.resources["stone"]), int(p.resources["gold"]), int(p.resources["meat"]),
			int(p.allocation["wood"]), int(p.allocation["stone"]), int(p.allocation["gold"]), int(p.allocation["meat"]),
			p.stance, p.target_pid, thr,
			int(b.get("house", 0)), int(b.get("barracks", 0)), int(b.get("tower", 0)), int(b.get("soldier_house", 0)),
			int(b.get("store_wood", 0)), int(b.get("store_gold", 0)), int(b.get("store_stone", 0)), int(b.get("store_meat", 0))])

func _dump_detail(g, bots: Dictionary) -> void:
	print("===== STALL DUMP t=%d =====" % int(g.elapsed))
	for pid in range(4):
		var p = g.get_player(pid)
		if not p.alive:
			continue
		var bot = bots.get(pid)
		print("-- P%d stance=%s tgt=%d bot_threatened=%s bot_scout=%s" % [pid, p.stance, p.target_pid,
			str(bot._threatened) if bot != null else "?", str(bot._scout) if bot != null else "?"])
		for n in get_nodes_in_group("villagers"):
			var v := n as Villager
			if v.owner_pid != pid:
				continue
			var ninfo := "none"
			if v._node != null and is_instance_valid(v._node):
				var nd = v._node
				ninfo = "%s@(%d,%d) amt=%s depl=%s" % [str(nd.get("res_type")), int(nd.global_position.x), int(nd.global_position.y), str(nd.get("amount")), str(nd.get("_depleted"))]
			print("   VIL assigned=%s state=%s pos=(%d,%d) carry=%s:%d node=%s direct=%s flee_left=%.1f threat_left=%.1f" % [
				v.assigned, v._state, int(v.global_position.x), int(v.global_position.y),
				v.carrying_type, v.carrying, ninfo, str(v.direct), v._flee_left, v._threat_left])
		for n in get_nodes_in_group("units"):
			var u := n as Unit
			if u.owner_pid != pid:
				continue
			var tinfo := "none"
			if u._target_unit != null and is_instance_valid(u._target_unit):
				tinfo = "unit P%d@(%d,%d)" % [u._target_unit.owner_pid, int(u._target_unit.global_position.x), int(u._target_unit.global_position.y)]
			elif u._target_struct != null and is_instance_valid(u._target_struct):
				tinfo = "struct P%d@(%d,%d) hp=%d" % [u._target_struct.owner_pid, int(u._target_struct.global_position.x), int(u._target_struct.global_position.y), int(u._target_struct.hp)]
			print("   UNIT %s hp=%d pos=(%d,%d) direct=%s dpoint=(%d,%d) target=%s" % [
				u.unit_type, int(u.hp), int(u.global_position.x), int(u.global_position.y),
				u.direct_mode, int(u.direct_point.x), int(u.direct_point.y), tinfo])
		var cpos: Vector2 = g.public_castle_pos(pid)
		var fog = g.fogs[pid]
		for n in get_nodes_in_group("res_nodes"):
			if str(n.get("res_type")) == "gold" and int(n.get("amount")) > 0:
				print("   LIVE_GOLD dist=%d amt=%d explored_by_P%d=%s" % [int(cpos.distance_to(n.global_position)), int(n.get("amount")), pid, str(fog.is_explored_pos(n.global_position))])
		for n in get_nodes_in_group("buildings"):
			var bb := n as Building
			if bb.owner_pid == pid and bb.building_type.begins_with("store"):
				print("   STORE %s stored=%s constructed=%s alive=%s" % [bb.building_type, str(bb.stored), str(bb.constructed), str(bb.is_alive())])

func _run() -> void:
	for sd in SEEDS:
		seed(sd)
		print("##### SEED %d #####" % sd)
		var scene: PackedScene = load("res://scenes/main.tscn")
		var g = scene.instantiate()
		Engine.time_scale = 30.0
		g.bots_enabled = true
		root.add_child(g)
		paused = false
		await _wait(0.5)
		var bots := _bots(g)
		for pid in bots.keys():
			bots[pid]._rng.seed = sd * 1000 + pid
		if g.get("_rng") != null:
			g._rng.seed = sd * 77 + 5
		var next_sample := 0.0
		var prev_alive := {}
		for pid in range(4):
			prev_alive[pid] = true
		while not g.match_over and g.elapsed < BUDGET:
			await _wait(5.0)
			for pid in range(4):
				var p = g.get_player(pid)
				if bool(prev_alive[pid]) and not p.alive:
					print("EVENT seed=%d t=%d P%d BI LOAI" % [sd, int(g.elapsed), pid])
				prev_alive[pid] = p.alive
			if g.elapsed >= next_sample:
				_sample(g, bots)
				next_sample += 200.0
		if g.match_over:
			print("##### SEED %d KET THUC t=%d #####" % [sd, int(g.elapsed)])
		else:
			print("##### SEED %d *** STALL *** #####" % sd)
			_sample(g, bots)
			_dump_detail(g, bots)
		g.queue_free()
		await _wait(0.3)
	print("PROBE2 DONE")
	quit()
