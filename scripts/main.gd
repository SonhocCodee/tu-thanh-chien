extends Node2D

## MAIN — lớp THỰC THI lệnh (mọi lệnh từ PlayerController đều chạy qua đây),
## quản lý trận: map, sương mù, spawn, loại phe, thắng/thua, chế độ demo chụp ảnh.

const UnitScene := preload("res://scenes/unit.tscn")
const VillagerScene := preload("res://scenes/villager.tscn")
const CastleScene := preload("res://scenes/castle.tscn")
const BuildingScene := preload("res://scenes/building.tscn")
const ProjectileScene := preload("res://scenes/projectile.tscn")

const WORLD := Vector2(1280, 640)
const FIELD_BOTTOM := 610.0
const CASTLE_POS := {
	0: Vector2(180, 470), # Xanh dương — người chơi, dưới-trái
	1: Vector2(180, 160), # Vàng — trên-trái
	2: Vector2(1100, 160), # Đỏ — trên-phải
	3: Vector2(1100, 470), # Tím — dưới-phải
}
const HUMAN_PID := 0

var players: Array = [] # Array[PlayerState]
var controllers: Array = [] # Array[PlayerController]
var castles: Dictionary = {} # pid -> Castle
var fogs: Dictionary = {} # pid -> FogOfWar
var bots_enabled: bool = true
var demo_mode: bool = false
var bot_attack_size_override: int = -1

var match_over: bool = false
var player_won: bool = false
var elapsed: float = 0.0

var placing_type: String = ""
var awaiting_order: bool = false

var _rng := RandomNumberGenerator.new()
var _fog_timer: float = 0.0
var _fog_overlay: Node2D = null
var _zone_rect: Polygon2D = null
var _units_layer: Node2D
var _fx_layer: Node2D
var _hud: CanvasLayer = null
var _demo_shot_stage: int = 0
var _arrow_textures: Dictionary = {}

func _ready() -> void:
	_rng.randomize()
	var args := OS.get_cmdline_user_args()
	if "--demo" in args:
		demo_mode = true
		Engine.time_scale = 3.0
		bot_attack_size_override = 4
	_build_players()
	_build_map()
	_build_resource_nodes()
	_build_castles()
	_build_start_villagers()
	_build_fog()
	_build_bots()
	_build_hud()
	_update_fog()
	if demo_mode:
		# Sân khấu demo (chỉ để chụp ảnh kiểm chứng): cấp thêm tài nguyên cho mọi phe.
		for p in players:
			for k in Stats.RES_KEYS:
				p.resources[k] = int(p.resources[k]) + 500

func _process(delta: float) -> void:
	if not match_over:
		elapsed += delta
	_fog_timer -= delta
	if _fog_timer <= 0.0:
		_fog_timer = float(Stats.FOG["update_interval"])
		_update_fog()
	if demo_mode:
		_demo_update()

# ===================== DỰNG BAN ĐẦU =====================

func _build_players() -> void:
	for i in Stats.PLAYERS.size():
		var ps := PlayerState.new()
		ps.setup(i, Stats.PLAYERS[i])
		players.append(ps)
		var ctrl := PlayerController.new()
		ctrl.setup(ps, self)
		controllers.append(ctrl)
		add_child(ctrl)

func get_player(pid: int) -> PlayerState:
	return players[pid]

func human_controller() -> PlayerController:
	return controllers[HUMAN_PID]

func public_castle_pos(pid: int) -> Vector2:
	return CASTLE_POS[pid]

func _build_map() -> void:
	# Nước toàn map + đảo cỏ ở giữa bằng TileMap dựng từ tileset của pack.
	var ts := TileSet.new()
	ts.tile_size = Vector2i(64, 64)
	var water_src := TileSetAtlasSource.new()
	water_src.texture = load("res://assets/terrain/water.png")
	water_src.texture_region_size = Vector2i(64, 64)
	water_src.create_tile(Vector2i(0, 0))
	ts.add_source(water_src, 0)
	var land_src := TileSetAtlasSource.new()
	land_src.texture = load("res://assets/terrain/tilemap.png")
	land_src.texture_region_size = Vector2i(64, 64)
	land_src.create_tile(Vector2i(1, 1))
	ts.add_source(land_src, 1)
	var water_map := TileMap.new()
	water_map.tile_set = ts
	water_map.z_index = -10
	for x in 20:
		for y in 12:
			water_map.set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0))
	add_child(water_map)
	var land_map := TileMap.new()
	land_map.tile_set = ts
	land_map.z_index = -9
	for x in range(0, 20):
		for y in range(0, 10):
			land_map.set_cell(0, Vector2i(x, y), 1, Vector2i(1, 1))
	add_child(land_map)
	_units_layer = Node2D.new()
	_units_layer.z_index = 10
	add_child(_units_layer)
	_fx_layer = Node2D.new()
	_fx_layer.z_index = 20
	add_child(_fx_layer)
	# Trang trí: cây/đá rải xa căn cứ và điểm tài nguyên.
	var deco_pos := [Vector2(430, 120), Vector2(850, 130), Vector2(430, 520), Vector2(850, 520), Vector2(640, 200), Vector2(640, 420), Vector2(330, 300), Vector2(950, 300)]
	for i in deco_pos.size():
		var spr := Sprite2D.new()
		if i % 2 == 0:
			var at := AtlasTexture.new()
			at.atlas = load("res://assets/deco/tree.png")
			at.region = Rect2(0, 0, 256, 256)
			spr.texture = at
			spr.scale = Vector2(0.4, 0.4)
			spr.position = deco_pos[i] + Vector2(0, -40)
		else:
			spr.texture = load("res://assets/deco/rock1.png")
			spr.position = deco_pos[i]
		spr.z_index = -5
		add_child(spr)
	# Vùng đặt công trình (hiện khi đang đặt).
	_zone_rect = Polygon2D.new()
	_zone_rect.z_index = 1
	_zone_rect.color = Color(1, 1, 1, 0.13)
	_zone_rect.visible = false
	add_child(_zone_rect)
	# Lớp phủ sương mù phía người chơi.
	_fog_overlay = FogOverlay.new()
	_fog_overlay.z_index = 50
	add_child(_fog_overlay)

func _build_resource_nodes() -> void:
	for pid in CASTLE_POS.keys():
		var c: Vector2 = CASTLE_POS[pid]
		var mx := 1.0 if c.x < 640.0 else -1.0
		var my := 1.0 if c.y < 320.0 else -1.0
		_add_node("wood", false, c + Vector2(mx * 150, -45))
		_add_node("wood", false, c + Vector2(mx * 150, 45))
		_add_node("wood", false, c + Vector2(mx * 95, my * 105))
		_add_node("stone", false, c + Vector2(mx * 205, my * 55))
		_add_node("gold", false, c + Vector2(mx * 205, -my * 55))
	# Điểm tài nguyên LỚN giữa map — nằm trong vùng tối đầu trận, phải trinh sát.
	_add_node("gold", true, Vector2(640, 305))
	_add_node("wood", true, Vector2(600, 105))
	_add_node("wood", true, Vector2(680, 105))
	_add_node("stone", true, Vector2(610, 505))
	_add_node("stone", true, Vector2(675, 505))

func _add_node(res_type: String, big: bool, pos: Vector2) -> void:
	var n := ResourceNode.new()
	n.setup(res_type, big)
	n.position = pos
	n.z_index = -4
	add_child(n)

func _build_castles() -> void:
	for pid in CASTLE_POS.keys():
		var castle := CastleScene.instantiate() as Castle
		castle.setup(pid, Stats.PLAYERS[pid]["color_key"], Stats.PLAYERS[pid]["name"], self)
		castle.position = CASTLE_POS[pid]
		castle.z_index = 5
		add_child(castle)
		castle.structure_destroyed.connect(_on_structure_destroyed)
		castles[pid] = castle

func _build_start_villagers() -> void:
	for pid in CASTLE_POS.keys():
		for i in int(Stats.ECONOMY["start_villagers"]):
			_spawn_villager(pid)
		# Phân bổ mặc định: 2 gỗ + 1 vàng.
		exec_set_allocation(players[pid], 2, 0, 1)

func _build_fog() -> void:
	for pid in CASTLE_POS.keys():
		var f := FogOfWar.new()
		f.setup(WORLD, float(Stats.FOG["cell_size"]))
		fogs[pid] = f

func _build_bots() -> void:
	if not bots_enabled:
		return
	for pid in CASTLE_POS.keys():
		if pid == HUMAN_PID and not demo_mode:
			continue
		var bot := Bot.new()
		bot.setup(controllers[pid], self)
		if bot_attack_size_override > 0:
			bot.attack_army_size = bot_attack_size_override
		add_child(bot)

func _build_hud() -> void:
	_hud = Hud.new()
	_hud.setup(self, human_controller())
	add_child(_hud)

# ===================== SƯƠNG MÙ =====================

func _update_fog() -> void:
	var vision: Dictionary = Stats.FOG["vision"]
	for pid in fogs.keys():
		var fog: FogOfWar = fogs[pid]
		fog.reset_visible()
		if not players[pid].alive:
			continue
		for n in get_tree().get_nodes_in_group("structures"):
			var s := n as Structure
			if s.owner_pid == pid and s.is_alive():
				var r := float(vision["building"])
				if s is Castle:
					r = float(vision["castle"])
				elif s is Building and (s as Building).building_type == "tower" and (s as Building).constructed:
					r = float(vision["tower"])
				fog.reveal_circle(s.global_position, r)
		for n in get_tree().get_nodes_in_group("units"):
			var u := n as Unit
			if u.owner_pid == pid and u.is_alive():
				fog.reveal_circle(u.global_position, float(vision[u.unit_type]))
		for n in get_tree().get_nodes_in_group("villagers"):
			var v := n as Villager
			if v.owner_pid == pid:
				fog.reveal_circle(v.global_position, float(vision["pawn"]))
	_refresh_human_display()

func _refresh_human_display() -> void:
	var fog: FogOfWar = fogs[HUMAN_PID]
	# Quân + nông dân địch: chỉ render khi ô đang SÁNG với người chơi.
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		u.visible = u.owner_pid == HUMAN_PID or fog.is_visible_pos(u.global_position)
	for n in get_tree().get_nodes_in_group("villagers"):
		var v := n as Villager
		v.visible = v.owner_pid == HUMAN_PID or fog.is_visible_pos(v.global_position)
	for n in get_tree().get_nodes_in_group("projectiles"):
		var pr := n as Projectile
		pr.visible = pr.owner_pid == HUMAN_PID or fog.is_visible_pos(pr.global_position)
	# Công trình địch: ĐEN -> ẩn hẳn; MỜ -> hiện theo snapshot lần cuối SÁNG; SÁNG -> trực tiếp.
	for n in get_tree().get_nodes_in_group("structures"):
		var s := n as Structure
		if s.owner_pid == HUMAN_PID:
			s.use_snapshot = false
			s.visible = true
			continue
		var state := fog.state_at(s.global_position)
		if state == 0:
			s.visible = false
			s.use_snapshot = true
		elif state == 2:
			s.visible = true
			s.use_snapshot = false
			s.display_hp = s.hp
			s.display_burning = s.is_burning_live()
			s.display_destroyed = s.destroyed
			if s is Building:
				s.display_constructed = (s as Building).constructed
			s._refresh_display()
			s.queue_redraw()
		else:
			s.visible = true
			s.use_snapshot = true
			s._refresh_display()
			s.queue_redraw()
	if _fog_overlay != null:
		(_fog_overlay as FogOverlay).set_fog(fog)
		_fog_overlay.queue_redraw()

func is_pos_explored_for(pid: int, pos: Vector2) -> bool:
	return (fogs[pid] as FogOfWar).is_explored_pos(pos)

func is_castle_revealed_for(pid: int, target_pid: int) -> bool:
	if pid == target_pid or not castles.has(target_pid):
		return false
	if not players[target_pid].alive:
		return false
	return is_pos_explored_for(pid, CASTLE_POS[target_pid])

func known_enemy_castles(pid: int) -> Array:
	var out: Array = []
	for other in players:
		if other.pid != pid and other.alive and is_castle_revealed_for(pid, other.pid):
			out.append(other.pid)
	return out

func visible_enemy_units_for(pid: int, point: Vector2, radius: float) -> Array:
	var fog: FogOfWar = fogs[pid]
	var out: Array = []
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u.owner_pid != pid and u.is_alive() and u.global_position.distance_to(point) <= radius and fog.is_visible_pos(u.global_position):
			out.append(u)
	return out

# ===================== THỰC THI LỆNH (qua PlayerController) =====================

func exec_set_allocation(player: PlayerState, w: int, s: int, g: int) -> bool:
	player.allocation = {"wood": w, "stone": s, "gold": g}
	_rebalance_villagers(player)
	return true

func _rebalance_villagers(player: PlayerState) -> void:
	var list := _villagers_of(player.pid)
	var want := [int(player.allocation["wood"]), int(player.allocation["stone"]), int(player.allocation["gold"])]
	var keys := ["wood", "stone", "gold"]
	var idx := 0
	for ki in 3:
		for j in want[ki]:
			if idx >= list.size():
				return
			(list[idx] as Villager).set_assignment(keys[ki])
			idx += 1
	while idx < list.size():
		(list[idx] as Villager).set_assignment("")
		idx += 1

func base_zone(pid: int) -> Rect2:
	var c: Vector2 = CASTLE_POS[pid]
	var r := Rect2(c - Vector2(150, 115), Vector2(300, 230))
	return r.intersection(Rect2(8, 8, 1264, 602))

func build_slots(pid: int) -> Array:
	var c: Vector2 = CASTLE_POS[pid]
	var mx := 1.0 if c.x < 640.0 else -1.0
	var my := 1.0 if c.y < 320.0 else -1.0
	return [
		c + Vector2(mx * -105, my * -80),
		c + Vector2(mx * -105, my * 80),
		c + Vector2(mx * 30, my * -102),
		c + Vector2(mx * 30, my * 102),
	]

func exec_place_building(player: PlayerState, building_type: String, pos: Vector2) -> bool:
	if not Stats.BUILDINGS.has(building_type):
		return false
	var def: Dictionary = Stats.BUILDINGS[building_type]
	if not player.can_afford(def["cost"]):
		return false
	if not base_zone(player.pid).has_point(pos):
		return false
	for n in get_tree().get_nodes_in_group("structures"):
		var s := n as Structure
		if s.global_position.distance_to(pos) < 62.0:
			return false
	for n in get_tree().get_nodes_in_group("res_nodes"):
		if (n as Node2D).global_position.distance_to(pos) < 48.0:
			return false
	player.pay(def["cost"])
	var b := BuildingScene.instantiate() as Building
	b.setup(player.pid, building_type, player.color_key, self)
	b.position = pos
	b.z_index = 5
	add_child(b)
	b.structure_destroyed.connect(_on_structure_destroyed)
	return true

func exec_queue_training(player: PlayerState, building: Structure, unit_type: String) -> bool:
	if building.owner_pid != player.pid or not building.can_produce():
		return false
	var prod: Dictionary = Stats.PRODUCERS[building.producer_kind]
	if not (prod["units"] as Array).has(unit_type):
		return false
	var def: Dictionary = Stats.TRAINING[unit_type]
	if not player.can_afford(def["cost"]):
		return false
	if pop_used(player.pid) + 1 > pop_cap(player.pid):
		return false
	player.pay(def["cost"])
	building.enqueue(unit_type, float(def["time"]) / float(prod["speed"]))
	return true

func exec_set_stance(player: PlayerState, stance: String, target_pid: int) -> bool:
	if stance == "hold":
		player.stance = "hold"
		player.target_pid = -1
		return true
	if stance == "attack":
		if target_pid < 0 or target_pid == player.pid or not players[target_pid].alive:
			return false
		player.stance = "attack"
		player.target_pid = target_pid
		player.attacks_launched_total += 1
		return true
	return false

func exec_order_move(player: PlayerState, point: Vector2) -> bool:
	player.stance = "move"
	player.target_pid = -1
	player.move_point = Vector2(clampf(point.x, 16, 1264), clampf(point.y, 16, FIELD_BOTTOM - 8))
	return true

# ===================== DÂN SỐ / ĐẾM =====================

func pop_cap(pid: int) -> int:
	var cap := int(Stats.ECONOMY["pop_base"])
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.building_type == "house" and b.constructed and b.is_alive():
			cap += int(Stats.ECONOMY["pop_per_house"])
	return cap

func pop_used(pid: int) -> int:
	var used := villager_count(pid) + military_count(pid)
	for n in get_tree().get_nodes_in_group("structures"):
		var s := n as Structure
		if s.owner_pid == pid:
			used += s.queue_count()
	return used

func villager_count(pid: int) -> int:
	return _villagers_of(pid).size()

func military_count(pid: int) -> int:
	var c := 0
	for n in get_tree().get_nodes_in_group("units"):
		if (n as Unit).owner_pid == pid and (n as Unit).is_alive():
			c += 1
	return c

func _villagers_of(pid: int) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("villagers"):
		if (n as Villager).owner_pid == pid:
			out.append(n)
	return out

func building_counts(pid: int) -> Dictionary:
	var counts := {"house": 0, "barracks": 0, "tower": 0}
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.is_alive():
			counts[b.building_type] = int(counts[b.building_type]) + 1
	return counts

func active_barracks(pid: int) -> Building:
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.building_type == "barracks" and b.constructed and b.is_alive():
			return b
	return null

func rally_point(pid: int) -> Vector2:
	var c: Vector2 = CASTLE_POS[pid]
	var mx := 1.0 if c.x < 640.0 else -1.0
	var my := 1.0 if c.y < 320.0 else -1.0
	return c + Vector2(mx * 88, my * 62)

func nearest_resource_node(pid: int, res_type: String, from_pos: Vector2) -> Node2D:
	var fog: FogOfWar = fogs[pid]
	var best: Node2D = null
	var best_d := 1e9
	for n in get_tree().get_nodes_in_group("res_nodes"):
		var node := n as ResourceNode
		if node.res_type != res_type:
			continue
		# Nông dân chỉ tới điểm tài nguyên thuộc vùng ĐÃ KHÁM PHÁ của phe mình.
		if not fog.is_explored_pos(node.global_position):
			continue
		var d := from_pos.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

# ===================== SPAWN =====================

func _spawn_villager(pid: int) -> Villager:
	var v := VillagerScene.instantiate() as Villager
	var off := Vector2(_rng.randf_range(-46, 46), _rng.randf_range(52, 84))
	v.setup(pid, players[pid].color_key, self, off)
	v.position = CASTLE_POS[pid] + off
	v.z_index = 10
	_units_layer.add_child(v)
	return v

func spawn_trained_unit(pid: int, unit_type: String, _producer: Structure) -> void:
	players[pid].units_trained_total += 1
	if unit_type == "pawn":
		_spawn_villager(pid)
		_rebalance_villagers(players[pid])
		return
	var u := UnitScene.instantiate() as Unit
	var slot := Vector2(_rng.randf_range(-42, 42), _rng.randf_range(-30, 30))
	u.setup(pid, unit_type, players[pid].color_key, self, slot)
	u.position = rally_point(pid) + slot
	u.z_index = 10
	_units_layer.add_child(u)
	u.died.connect(_on_unit_died)

func spawn_projectile(from_pos: Vector2, target, damage: float, owner_pid: int, speed: float, color_key: String) -> void:
	if not _arrow_textures.has(color_key):
		_arrow_textures[color_key] = load("res://assets/units/%s/arrow.png" % color_key)
	var p := ProjectileScene.instantiate() as Projectile
	p.setup(from_pos, target, damage, owner_pid, speed, _arrow_textures[color_key])
	p.z_index = 15
	add_child(p)

func _on_unit_died(_unit: Unit, _killer_pid: int) -> void:
	pass

func spawn_explosion(pos: Vector2, scale_factor: float = 1.0) -> void:
	var spr := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	var sheet := load("res://assets/fx/explosion.png") as Texture2D
	sf.add_animation("boom")
	sf.set_animation_speed("boom", 12.0)
	sf.set_animation_loop("boom", false)
	for i in 8:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * 192, 0, 192, 192)
		sf.add_frame("boom", at)
	spr.sprite_frames = sf
	spr.scale = Vector2(1.3, 1.3) * scale_factor
	spr.position = pos
	_fx_layer.add_child(spr)
	spr.play("boom")
	spr.animation_finished.connect(spr.queue_free)

# ===================== PHÁ HUỶ / LOẠI PHE =====================

func _on_structure_destroyed(s: Structure) -> void:
	spawn_explosion(s.global_position, 1.2 if s is Castle else 0.8)
	if s is Castle:
		_eliminate_player(s.owner_pid)

func on_building_completed(b: Building) -> void:
	players[b.owner_pid].buildings_completed_total += 1

func _eliminate_player(pid: int) -> void:
	var player: PlayerState = players[pid]
	if not player.alive:
		return
	player.alive = false
	# Quân + nông dân của họ tan rã.
	for n in get_tree().get_nodes_in_group("units"):
		if (n as Unit).owner_pid == pid:
			n.queue_free()
	for n in get_tree().get_nodes_in_group("villagers"):
		if (n as Villager).owner_pid == pid:
			n.queue_free()
	# Công trình còn lại thành tàn tích.
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.is_alive():
			b.force_ruin()
	# Phe khác đang nhắm vào phe này thì về giữ nhà.
	for p in players:
		if p.alive and p.target_pid == pid:
			p.stance = "hold"
			p.target_pid = -1
	# Thắng/thua.
	if pid == HUMAN_PID:
		_end_match(false)
	elif players[HUMAN_PID].alive:
		var others_alive := 0
		for p in players:
			if p.pid != HUMAN_PID and p.alive:
				others_alive += 1
		if others_alive == 0:
			_end_match(true)

func _end_match(won: bool) -> void:
	if match_over:
		return
	match_over = true
	player_won = won
	if _hud != null and _hud.has_method("show_end"):
		_hud.show_end(won)
	get_tree().paused = true

# ===================== INPUT NGƯỜI CHƠI =====================

func set_placement_mode(building_type: String) -> void:
	placing_type = building_type
	awaiting_order = false
	_zone_rect.polygon = PackedVector2Array([
		base_zone(HUMAN_PID).position,
		base_zone(HUMAN_PID).position + Vector2(base_zone(HUMAN_PID).size.x, 0),
		base_zone(HUMAN_PID).end,
		base_zone(HUMAN_PID).position + Vector2(0, base_zone(HUMAN_PID).size.y),
	])
	_zone_rect.visible = true
	if _hud != null:
		_hud.show_message("Bấm vào vùng sáng quanh thành để đặt %s (chuột phải để huỷ)." % Stats.BUILDINGS[building_type]["label"])

func cancel_modes() -> void:
	placing_type = ""
	awaiting_order = false
	_zone_rect.visible = false
	for c in castles.values():
		(c as Castle).highlight_target = false

func start_order_mode() -> void:
	awaiting_order = true
	placing_type = ""
	_zone_rect.visible = false
	for pid in castles.keys():
		(castles[pid] as Castle).highlight_target = pid != HUMAN_PID and players[pid].alive
	if _hud != null:
		_hud.show_message("Bấm vào THÀNH ĐỊCH ĐÃ LỘ DIỆN để tổng tấn công, hoặc bấm 1 điểm trên map để quân đi trinh sát tới đó.")

func _unhandled_input(event: InputEvent) -> void:
	if match_over:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_modes()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var pos := get_global_mouse_position()
		if pos.y > FIELD_BOTTOM:
			return
		if placing_type != "":
			var ok := human_controller().place_building(placing_type, pos)
			if _hud != null:
				_hud.show_message("Đã đặt %s." % Stats.BUILDINGS[placing_type]["label"] if ok else "Không đặt được ở đó (ngoài vùng/thiếu tài nguyên/trùng công trình).")
			if ok:
				cancel_modes()
			return
		if awaiting_order:
			# Bấm trúng thành địch?
			for pid in castles.keys():
				if pid != HUMAN_PID and players[pid].alive and pos.distance_to(CASTLE_POS[pid]) <= 95.0:
					var ok := human_controller().set_stance("attack", pid)
					if _hud != null:
						_hud.show_message("TỔNG TẤN CÔNG thành %s!" % players[pid].display_name if ok else "Thành đó CHƯA LỘ DIỆN — hãy cho quân trinh sát tới gần trước!")
					if ok:
						cancel_modes()
					return
			# Bấm điểm trống -> đi trinh sát.
			human_controller().order_move(pos)
			if _hud != null:
				_hud.show_message("Quân đang đi trinh sát tới điểm đã chọn.")
			cancel_modes()
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_modes()

# ===================== DEMO CHỤP ẢNH =====================

func _demo_update() -> void:
	if _demo_shot_stage == 0 and elapsed >= 6.0:
		_demo_shot_stage = 1
		_take_shot("res://screenshots/m1_can_cu_dau_tran.png")
	elif _demo_shot_stage == 1 and elapsed >= 80.0:
		_demo_shot_stage = 2
		_take_shot("res://screenshots/m1_giao_tranh.png")
	elif _demo_shot_stage == 2 and elapsed >= 84.0:
		get_tree().quit()

func _take_shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("DEMO_SHOT ", path)

# ===================== LỚP PHỦ SƯƠNG MÙ (vẽ cho người chơi) =====================

class FogOverlay:
	extends Node2D
	var fog: FogOfWar = null

	func set_fog(f: FogOfWar) -> void:
		fog = f

	func _draw() -> void:
		if fog == null:
			return
		for y in fog.rows:
			for x in fog.cols:
				var i := y * fog.cols + x
				var rect := Rect2(x * fog.cell, y * fog.cell, fog.cell, fog.cell)
				if fog.visible_now[i] == 1:
					continue
				elif fog.explored[i] == 1:
					draw_rect(rect, Color(0, 0, 0, 0.45))
				else:
					draw_rect(rect, Color(0, 0, 0, 1))
