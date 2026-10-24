extends Node2D

## MAIN — lớp THỰC THI lệnh (mọi lệnh từ PlayerController đều chạy qua đây),
## quản lý trận: map, sương mù, spawn, loại phe, thắng/thua, chế độ demo chụp ảnh.

const UnitScene := preload("res://scenes/unit.tscn")
const VillagerScene := preload("res://scenes/villager.tscn")
const CastleScene := preload("res://scenes/castle.tscn")
const BuildingScene := preload("res://scenes/building.tscn")
const ProjectileScene := preload("res://scenes/projectile.tscn")

const WORLD := Vector2(1920, 960)
const FIELD_BOTTOM := 610.0 # mép trên của panel HUD dưới (tọa độ MÀN HÌNH, không phải map)
const CASTLE_POS := {
	0: Vector2(220, 780), # Xanh dương — người chơi, dưới-trái
	1: Vector2(220, 180), # Vàng — trên-trái
	2: Vector2(1700, 180), # Đỏ — trên-phải
	3: Vector2(1700, 780), # Tím — dưới-phải
}
# Khoảng cách tối thiểu giữa 2 thành kề nhau (cặp trên-dưới): 600px.
# Tầm nhìn thành 265 + 265 = 530 < 600 nên đầu trận các căn cứ không thấy nhau:
# muốn biết địch ở đâu bắt buộc phải trinh sát.
const HUMAN_PID := 0
const CAM_SPEED := 1000.0
const EDGE_MARGIN := 18.0

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

# --- Placement preview: bóng ma công trình bám theo chuột khi đang đặt ---
var _place_ghost: Node2D = null
var _ghost_sprite: Sprite2D = null
var _ghost_foot: Polygon2D = null
var _ghost_type: String = ""
# Khớp đúng tỉ lệ + độ lệch sprite trong building.gd để bóng ma trông y nhà thật.
const GHOST_PRESENT := {
	"house": [0.55, -28.0],
	"barracks": [0.5, -38.0],
	"tower": [0.45, -52.0],
	"storehouse": [0.6, -30.0],
	"soldier_house": [0.55, -28.0],
}

# --- Con trỏ ngữ cảnh khi di chuột (hover) ---
var cursor_context: String = "default" # "default" | "gather" | "placement"
var hover_target: Node2D = null # mục tiêu thu thập đang được vòng sáng làm nổi
var _hover_timer: float = 0.0
var _hover_ring: Node2D = null
var _cursor_tex_default: Texture2D = null
var _cursor_tex_gather: Texture2D = null

# --- M2: camera + chọn quân ---
var _camera: Camera2D = null
var _sel_overlay: Node2D = null
var _drag_candidate: bool = false
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_current: Vector2 = Vector2.ZERO
var _demo_drag_rect: Rect2 = Rect2()
var _demo_show_drag: bool = false
var m2demo_mode: bool = false
var _m2demo_stage: int = 0
var _m2demo_timer: float = 0.0
var g2demo_mode: bool = false
var _g2demo_stage: int = 0
var _g2demo_timer: float = 0.0
var popdemo_mode: bool = false
var _popdemo_stage: int = 0
var _popdemo_timer: float = 0.0
var _g2_tree: ResourceNode = null
var _g2_hunter: Villager = null
var _g2_store: Building = null
var _g2_mine: ResourceNode = null
var _g2_scout_sent: bool = false

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
	if "--m2demo" in args:
		m2demo_mode = true
		bots_enabled = false
		Engine.time_scale = 3.0
	if "--g2demo" in args:
		g2demo_mode = true
		bots_enabled = false
		Engine.time_scale = 3.0
	if "--popdemo" in args:
		popdemo_mode = true
		bots_enabled = false
		Engine.time_scale = 3.0
	_build_players()
	_build_map()
	_build_resource_nodes()
	_build_sheep()
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
	_update_camera(delta)
	_update_place_ghost()
	# Con trỏ ngữ cảnh: quét throttle 0.08s (không quét mỗi frame); vòng nổi
	# thì bám theo mục tiêu từng frame cho khỏi giật khi mục tiêu di động (cừu).
	_hover_timer -= delta
	if _hover_timer <= 0.0:
		_hover_timer = 0.08
		update_hover_cursor(get_global_mouse_position())
	if _hover_ring != null and _hover_ring.visible and hover_target != null and is_instance_valid(hover_target):
		_hover_ring.global_position = hover_target.global_position
	if demo_mode:
		_demo_update()
	if m2demo_mode:
		_demo_m2_update(delta)
	if g2demo_mode:
		_demo_g2_update(delta)
	if popdemo_mode:
		_demo_pop_update(delta)

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
	for x in 30:
		for y in 16:
			water_map.set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0))
	add_child(water_map)
	var land_map := TileMap.new()
	land_map.tile_set = ts
	land_map.z_index = -9
	for x in range(0, 30):
		for y in range(0, 15):
			land_map.set_cell(0, Vector2i(x, y), 1, Vector2i(1, 1))
	add_child(land_map)
	_units_layer = Node2D.new()
	_units_layer.z_index = 10
	add_child(_units_layer)
	_fx_layer = Node2D.new()
	_fx_layer.z_index = 20
	add_child(_fx_layer)
	# Trang trí: cây/đá rải xa căn cứ và điểm tài nguyên.
	var deco_pos := [Vector2(645, 180), Vector2(1275, 195), Vector2(645, 780), Vector2(1275, 780), Vector2(960, 300), Vector2(960, 630), Vector2(495, 450), Vector2(1425, 450)]
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
	# Camera M2: bắt đầu nhìn về góc căn cứ người chơi, kẹp trong biên map.
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	_camera.make_current()
	set_camera_to(CASTLE_POS[HUMAN_PID])
	# Lớp vẽ khung chọn quân (tọa độ thế giới, đi theo camera).
	_sel_overlay = SelectionOverlay.new()
	_sel_overlay.game = self
	_sel_overlay.z_index = 60
	add_child(_sel_overlay)

func _build_resource_nodes() -> void:
	var variant_counter := 0
	for pid in CASTLE_POS.keys():
		var c: Vector2 = CASTLE_POS[pid]
		var mx := 1.0 if c.x < WORLD.x / 2.0 else -1.0
		var my := 1.0 if c.y < WORLD.y / 2.0 else -1.0
		_add_node("wood", false, c + Vector2(mx * 150, -45), variant_counter)
		variant_counter += 1
		_add_node("wood", false, c + Vector2(mx * 150, 45), variant_counter)
		variant_counter += 1
		_add_node("wood", false, c + Vector2(mx * 95, my * 105), variant_counter)
		variant_counter += 1
		_add_node("stone", false, c + Vector2(mx * 205, my * 55), pid)
		_add_node("gold", false, c + Vector2(mx * 205, -my * 55), pid)
	# Điểm tài nguyên LỚN giữa map — nằm trong vùng tối đầu trận, phải trinh sát.
	_add_node("gold", true, Vector2(960, 460), 0)
	_add_node("wood", true, Vector2(900, 155), 1)
	_add_node("wood", true, Vector2(1020, 155), 2)
	_add_node("stone", true, Vector2(920, 765), 0)
	_add_node("stone", true, Vector2(1010, 765), 1)

func _add_node(res_type: String, big: bool, pos: Vector2, variant: int = 0) -> ResourceNode:
	var n := ResourceNode.new()
	n.setup(res_type, big, variant)
	n.position = pos
	n.z_index = -4
	add_child(n)
	return n

# ===================== CỪU TRUNG LẬP (nguồn thịt) =====================

func _build_sheep() -> void:
	var seed_val := 1000
	# Mỗi căn cứ: 2 cừu trong tầm nhìn thành (săn được ngay đầu trận) + 1 xa hơn.
	for pid in CASTLE_POS.keys():
		var c: Vector2 = CASTLE_POS[pid]
		var mx := 1.0 if c.x < WORLD.x / 2.0 else -1.0
		var my := 1.0 if c.y < WORLD.y / 2.0 else -1.0
		for off in [Vector2(mx * 235, my * 105), Vector2(mx * 255, -my * 95), Vector2(mx * 330, my * 30)]:
			_add_sheep(c + off, seed_val)
			seed_val += 77
	# Đàn giữa map + 2 đàn hai bên: điểm tranh thịt, phải trinh sát mới thấy.
	for i in 6:
		var a := TAU * float(i) / 6.0
		_add_sheep(Vector2(960, 480) + Vector2(cos(a), sin(a)) * 90.0, seed_val)
		seed_val += 77
	for center in [Vector2(565, 480), Vector2(1355, 480)]:
		for i in 3:
			var a2 := TAU * float(i) / 3.0 + 0.5
			_add_sheep(center + Vector2(cos(a2), sin(a2)) * 55.0, seed_val)
			seed_val += 77
	# NGƯỜI GIỮ ĐÀN (tích hợp AI): các bãi chăn TRUNG LẬP tự hồi cừu về trần
	# (giữa map 6 con, hai bên 3 con = đúng số ban đầu ở trên; hồi 20s/con).
	# Cừu quanh thành từng phe KHÔNG có keeper — săn hết là hết, như GĐ2.
	var keeper_mid := HerdKeeper.new()
	keeper_mid.position = Vector2(960, 480)
	add_child(keeper_mid)
	keeper_mid.setup()
	for center in [Vector2(565, 480), Vector2(1355, 480)]:
		var keeper_side := HerdKeeper.new()
		keeper_side.position = center
		add_child(keeper_side)
		keeper_side.setup(180.0, 3)

func _add_sheep(pos: Vector2, seed_val: int) -> Sheep:
	var s := Sheep.new()
	s.setup(self, pos, seed_val)
	s.position = pos
	s.z_index = 6
	_units_layer.add_child(s)
	return s

## Nông dân săn trúng: cừu chết -> sinh XÁC THỊT tại chỗ, trả về xác.
func kill_sheep(sheep: Sheep) -> ResourceNode:
	if sheep == null or not is_instance_valid(sheep) or not sheep.alive:
		return null
	var pos := sheep.global_position
	sheep.kill()
	sheep.queue_free()
	var carcass := _add_node("meat", false, pos, 0)
	return carcass

## Cừu còn sống GẦN NHẤT mà phe này ĐÃ KHÁM PHÁ vị trí của nó.
func nearest_sheep(pid: int, from_pos: Vector2) -> Sheep:
	var fog: FogOfWar = fogs[pid]
	var best: Sheep = null
	var best_d := 1e9
	for n in get_tree().get_nodes_in_group("sheep"):
		var s := n as Sheep
		if not s.alive:
			continue
		if not fog.is_explored_pos(s.global_position):
			continue
		var d := from_pos.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best

## Cừu gần 1 điểm (cho click phải của người chơi — chỉ tính cừu đang SÁNG).
func sheep_at(pos: Vector2, radius: float) -> Sheep:
	var fog: FogOfWar = fogs[HUMAN_PID]
	var best: Sheep = null
	var best_d := radius
	for n in get_tree().get_nodes_in_group("sheep"):
		var s := n as Sheep
		if not s.alive:
			continue
		if not fog.is_visible_pos(s.global_position):
			continue
		var d := s.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = s
	return best

# ===================== KHO (điểm giao tài nguyên) =====================

## Kho GẦN NHẤT của 1 phe: thành chính hoặc Nhà Kho đã xây xong còn đứng.
## Nông dân chỉ được cộng tài nguyên khi vác về TỚI 1 kho như thế này.
func nearest_dropoff(pid: int, from_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := 1e9
	if castles.has(pid):
		var castle := castles[pid] as Castle
		if castle != null and castle.is_alive():
			best = castle
			best_d = from_pos.distance_to(castle.global_position)
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.is_valid_dropoff():
			var d := from_pos.distance_to(b.global_position)
			if d < best_d:
				best_d = d
				best = b
	return best

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
		exec_set_allocation(players[pid], 2, 0, 1, 0)

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
	# Panel hướng dẫn tự mở khi vào trận (trừ chế độ demo chụp ảnh).
	if not demo_mode and not m2demo_mode and not g2demo_mode and not popdemo_mode:
		_hud.show_help()

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
	# Cừu trung lập: chỉ hiện khi ô đang SÁNG với người chơi.
	for n in get_tree().get_nodes_in_group("sheep"):
		var sh := n as Sheep
		sh.visible = fog.is_visible_pos(sh.global_position)
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

## Ô tại pos có đang SÁNG (trong tầm nhìn hiện tại) với phe pid không —
## cổng sương mù ở tầng dữ liệu cho đơn vị bắn xa / cung thủ trên tháp canh.
func is_pos_visible_for(pid: int, pos: Vector2) -> bool:
	return (fogs[pid] as FogOfWar).is_visible_pos(pos)

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

func exec_set_allocation(player: PlayerState, w: int, s: int, g: int, m: int = 0) -> bool:
	player.allocation = {"wood": w, "stone": s, "gold": g, "meat": m}
	_rebalance_villagers(player)
	return true

func rebalance_player(pid: int) -> void:
	_rebalance_villagers(players[pid])

func _rebalance_villagers(player: PlayerState) -> void:
	# Nông dân đang làm theo LỆNH TRỰC TIẾP (click phải) được giữ nguyên:
	# lệnh trực tiếp ưu tiên hơn phân bổ +/-. Số lượng direct theo từng loại
	# được trừ vào chỉ tiêu phân bổ, phần còn lại chia cho nông dân chưa có lệnh.
	var list := _villagers_of(player.pid)
	var want := [int(player.allocation["wood"]), int(player.allocation["stone"]), int(player.allocation["gold"]), int(player.allocation["meat"])]
	var keys := ["wood", "stone", "gold", "meat"]
	for v in list:
		var vil := v as Villager
		if vil.is_direct():
			var ki := keys.find(vil.direct_res)
			if ki >= 0:
				want[ki] = maxi(0, want[ki] - 1)
	var idx := 0
	for ki in 4:
		for j in want[ki]:
			while idx < list.size() and (list[idx] as Villager).is_direct():
				idx += 1
			if idx >= list.size():
				return
			(list[idx] as Villager).set_assignment(keys[ki])
			idx += 1
	while idx < list.size():
		if not (list[idx] as Villager).is_direct():
			(list[idx] as Villager).set_assignment("")
		idx += 1

func base_zone(pid: int) -> Rect2:
	var c: Vector2 = CASTLE_POS[pid]
	var r := Rect2(c - Vector2(150, 115), Vector2(300, 230))
	return r.intersection(Rect2(8, 8, WORLD.x - 16, WORLD.y - 16))

func build_slots(pid: int) -> Array:
	var c: Vector2 = CASTLE_POS[pid]
	var mx := 1.0 if c.x < WORLD.x / 2.0 else -1.0
	var my := 1.0 if c.y < WORLD.y / 2.0 else -1.0
	return [
		c + Vector2(mx * -105, my * -80),
		c + Vector2(mx * -105, my * 80),
		c + Vector2(mx * 30, my * -102),
		c + Vector2(mx * 30, my * 102),
		c + Vector2(mx * -175, 0), # ô cho Nhà Kho (đặt ngoài vùng căn cứ cũng được)
		c + Vector2(mx * -40, my * 110), # ô cho Nhà Lính (cách ô 3 ~70px, ô 1 ~72px, trong vùng căn cứ)
	]

## Luật đặt nhà DÙNG CHUNG — 1 nguồn luật duy nhất cho click đặt thật
## (exec_place_building) và bóng ma xem trước (placement preview).
## true = đặt được tại pos: còn đủ tiền, đúng vùng (Nhà Kho: vùng ĐÃ KHÁM PHÁ;
## nhà thường: vùng căn cứ), không quá gần công trình (62) / node (48) / cừu (40).
func can_place_building(player: PlayerState, building_type: String, pos: Vector2) -> bool:
	if not Stats.BUILDINGS.has(building_type):
		return false
	var def: Dictionary = Stats.BUILDINGS[building_type]
	if not player.can_afford(def["cost"]):
		return false
	# Công trình có tổ vận hành (tháp canh giữ 1 ô cho cung thủ đứng bắn):
	# dân số phải còn trống đủ ô NGAY LÚC ĐẶT — bóng ma xem trước gọi đúng
	# hàm này nên tự nhuộm đỏ khi hết ô, không cần luật riêng.
	var crew_pop := int(def.get("crew_pop", 0))
	if crew_pop > 0 and pop_used(player.pid) + crew_pop > pop_cap(player.pid):
		return false
	if building_type == "storehouse":
		# Nhà Kho: đặt ở bất cứ vùng ĐÃ KHÁM PHÁ nào của phe mình (để kê
		# gần bãi farm xa), không giới hạn vùng căn cứ như nhà thường.
		if not is_pos_explored_for(player.pid, pos):
			return false
	elif not base_zone(player.pid).has_point(pos):
		return false
	for n in get_tree().get_nodes_in_group("structures"):
		var s := n as Structure
		if s.global_position.distance_to(pos) < 62.0:
			return false
	for n in get_tree().get_nodes_in_group("res_nodes"):
		if (n as Node2D).global_position.distance_to(pos) < 48.0:
			return false
	for n in get_tree().get_nodes_in_group("sheep"):
		if (n as Node2D).global_position.distance_to(pos) < 40.0:
			return false
	return true

## Lý do ĐẶC THÙ khiến đặt nhà bị từ chối ("" = đặt được, hoặc bị từ chối
## vì lý do chung chung như ngoài vùng/trùng/thiếu tiền — caller tự dùng
## câu mặc định). Hiện chỉ có 1 lý do đặc thù: tháp canh cần ô dân cho
## cung thủ mà dân số đã đầy. HUD gọi hàm này sau khi đặt thất bại để
## hiện thông báo rõ cho người chơi.
func place_fail_reason(player: PlayerState, building_type: String, pos: Vector2) -> String:
	if can_place_building(player, building_type, pos):
		return ""
	if not Stats.BUILDINGS.has(building_type):
		return ""
	var crew_pop := int(Stats.BUILDINGS[building_type].get("crew_pop", 0))
	if crew_pop > 0 and pop_used(player.pid) + crew_pop > pop_cap(player.pid):
		return "Tháp cần 1 ô dân cho cung thủ đứng bắn — dân số đã đầy (%d/%d). Xây thêm Nhà Dân trước!" % [pop_used(player.pid), pop_cap(player.pid)]
	return ""

func exec_place_building(player: PlayerState, building_type: String, pos: Vector2) -> bool:
	if not can_place_building(player, building_type, pos):
		return false
	var def: Dictionary = Stats.BUILDINGS[building_type]
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
	# HAI giới hạn cùng áp: giới hạn quân (army cap, theo Ô) cho lính và
	# dân số chung (theo Ô) cho mọi đơn vị. Kẹt ở đâu báo rõ ở đó.
	var block := cap_block_reason(player.pid, unit_type)
	if block != "":
		if player.pid == HUMAN_PID and _hud != null:
			if block == "army":
				_hud.show_message("Đã đạt GIỚI HẠN QUÂN %d/%d ô — xây thêm NHÀ LÍNH để tăng!" % [army_used(player.pid), army_cap(player.pid)])
			else:
				_hud.show_message("Đã đạt GIỚI HẠN DÂN SỐ %d/%d — xây thêm NHÀ DÂN để tăng!" % [pop_used(player.pid), pop_cap(player.pid)])
		return false
	player.pay(def["cost"])
	building.enqueue(unit_type, float(def["time"]) / float(prod["speed"]))
	return true

func _clear_direct_orders(pid: int) -> void:
	# Lệnh thái độ / trinh sát toàn quân thắng lệnh trực tiếp từng nhóm.
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u.owner_pid == pid and u.is_alive():
			u.clear_direct()

func exec_set_stance(player: PlayerState, stance: String, target_pid: int) -> bool:
	if stance == "hold":
		player.stance = "hold"
		player.target_pid = -1
		_clear_direct_orders(player.pid)
		return true
	if stance == "attack":
		if target_pid < 0 or target_pid == player.pid or not players[target_pid].alive:
			return false
		player.stance = "attack"
		player.target_pid = target_pid
		player.attacks_launched_total += 1
		_clear_direct_orders(player.pid)
		return true
	return false

func exec_order_move(player: PlayerState, point: Vector2) -> bool:
	player.stance = "move"
	player.target_pid = -1
	player.move_point = Vector2(clampf(point.x, 16, WORLD.x - 16), clampf(point.y, 16, WORLD.y - 16))
	_clear_direct_orders(player.pid)
	return true

# ===================== LỆNH TRỰC TIẾP M2 (qua PlayerController) =====================

func clamp_to_world(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, 16, WORLD.x - 16), clampf(point.y, 16, WORLD.y - 16))

func exec_direct_move(player: PlayerState, unit: Unit, point: Vector2) -> bool:
	if unit == null or unit.owner_pid != player.pid or not unit.is_alive():
		return false
	unit.set_direct_move(clamp_to_world(point))
	return true

func exec_villager_move(player: PlayerState, v: Villager, point: Vector2) -> bool:
	if v == null or v.owner_pid != player.pid:
		return false
	v.set_move_point(clamp_to_world(point))
	return true

func exec_direct_farm(player: PlayerState, v: Villager, node: Node2D) -> bool:
	if v == null or v.owner_pid != player.pid or node == null or not is_instance_valid(node):
		return false
	# Lệnh farm trực tiếp cũng tôn trọng sương mù: chỉ farm/săn mục tiêu
	# ở vùng đã khám phá của phe mình.
	if not is_pos_explored_for(player.pid, node.global_position):
		return false
	if node is Sheep and not (node as Sheep).alive:
		return false
	if node is ResourceNode and (node as ResourceNode).is_depleted():
		return false
	v.set_direct(node)
	return true

func exec_direct_attack(player: PlayerState, unit: Unit, target: Node) -> bool:
	if unit == null or unit.owner_pid != player.pid or not unit.is_alive():
		return false
	if target == null or not is_instance_valid(target):
		return false
	# Luật sương mù cho tấn công trực tiếp (giống luật tấn công thành):
	# quân địch phải đang SÁNG; công trình địch phải đã khám phá (thành: lộ diện).
	if target is Unit:
		var tu := target as Unit
		if tu.owner_pid == player.pid or not tu.is_alive():
			return false
		if not (fogs[player.pid] as FogOfWar).is_visible_pos(tu.global_position):
			return false
	elif target is Structure:
		var ts := target as Structure
		if ts.owner_pid == player.pid or not ts.is_alive():
			return false
		if ts is Castle:
			if not is_castle_revealed_for(player.pid, ts.owner_pid):
				return false
		elif not is_pos_explored_for(player.pid, ts.global_position):
			return false
	else:
		return false
	unit.set_direct_attack(target)
	return true

# ---- Tìm mục tiêu click phải (chỉ tính những gì người chơi THẤY được) ----

func enemy_unit_at(pos: Vector2, radius: float) -> Unit:
	var fog: FogOfWar = fogs[HUMAN_PID]
	var best: Unit = null
	var best_d := radius
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u.owner_pid == HUMAN_PID or not u.is_alive():
			continue
		if not fog.is_visible_pos(u.global_position):
			continue
		var d := u.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = u
	return best

func enemy_structure_at(pos: Vector2) -> Structure:
	var best: Structure = null
	var best_d := 1e9
	for n in get_tree().get_nodes_in_group("structures"):
		var s := n as Structure
		if s.owner_pid == HUMAN_PID or not s.is_alive():
			continue
		var d := s.global_position.distance_to(pos)
		if d <= s.radius + 14.0 and d < best_d:
			best_d = d
			best = s
	return best

func res_node_at(pos: Vector2, radius: float) -> ResourceNode:
	var best: ResourceNode = null
	var best_d := radius
	for n in get_tree().get_nodes_in_group("res_nodes"):
		var node := n as ResourceNode
		var d := node.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = node
	return best

func spawn_order_marker(pos: Vector2, color: Color) -> void:
	var m := OrderMarker.new()
	m.position = pos
	m.marker_color = color
	# Marker là phản hồi lệnh của chính người chơi nên vẽ TRÊN sương mù
	# (fog z=50) — nếu không, lệnh vào vùng chưa khám phá sẽ không thấy
	# dấu hiệu gì dù lệnh vẫn chạy.
	m.z_index = 70
	_fx_layer.add_child(m)

# ===================== CAMERA M2 =====================

func get_camera_pos() -> Vector2:
	if _camera == null:
		return WORLD / 2.0
	return _camera.position

func set_camera_to(pos: Vector2) -> void:
	if _camera == null:
		return
	_camera.position = _clamp_camera(pos)

func _clamp_camera(pos: Vector2) -> Vector2:
	var half := Vector2(640, 360) # nửa viewport 1280x720
	var x := pos.x
	var y := pos.y
	if WORLD.x > 1280.0:
		x = clampf(x, half.x, WORLD.x - half.x)
	else:
		x = WORLD.x / 2.0
	if WORLD.y > 720.0:
		y = clampf(y, half.y, WORLD.y - half.y)
	else:
		y = WORLD.y / 2.0
	return Vector2(x, y)

func _update_camera(delta: float) -> void:
	if _camera == null or match_over:
		return
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if pan != Vector2.ZERO:
		set_camera_to(_camera.position + pan.normalized() * CAM_SPEED * delta)
	# Lia bằng mép màn hình (không lia khi đang kéo khung chọn, khi ở chế độ
	# headless/test, khi đang demo chụp ảnh, và khi chuột đang ở trên nút/minimap).
	if _dragging or demo_mode or m2demo_mode:
		return
	if DisplayServer.get_name() == "headless":
		return
	var mp := get_viewport().get_mouse_position()
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered is Button or hovered is Minimap:
		return
	var e := Vector2.ZERO
	if mp.x < EDGE_MARGIN:
		e.x -= 1.0
	elif mp.x > 1280.0 - EDGE_MARGIN:
		e.x += 1.0
	if mp.y < EDGE_MARGIN:
		e.y -= 1.0
	elif mp.y > 720.0 - EDGE_MARGIN:
		e.y += 1.0
	if e != Vector2.ZERO:
		set_camera_to(_camera.position + e.normalized() * CAM_SPEED * delta)

# ===================== CHỌN QUÂN M2 =====================

func select_in_rect(rect: Rect2) -> int:
	var list: Array = []
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u.owner_pid == HUMAN_PID and u.is_alive() and rect.has_point(u.global_position):
			list.append(u)
	for n in get_tree().get_nodes_in_group("villagers"):
		var v := n as Villager
		if v.owner_pid == HUMAN_PID and rect.has_point(v.global_position):
			list.append(v)
	human_controller().set_selection(list)
	if not list.is_empty() and _hud != null:
		_hud.show_message("Đã chọn %d quân." % list.size())
	return list.size()

func click_select(pos: Vector2) -> void:
	var best: Node2D = null
	var best_d := 30.0
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u.owner_pid != HUMAN_PID or not u.is_alive():
			continue
		var d := u.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = u
	for n in get_tree().get_nodes_in_group("villagers"):
		var v := n as Villager
		if v.owner_pid != HUMAN_PID:
			continue
		var d := v.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = v
	if best != null:
		human_controller().set_selection([best])
	else:
		human_controller().clear_selection()

# ===================== DÂN SỐ / ĐẾM =====================

func pop_cap(pid: int) -> int:
	var cap := int(Stats.ECONOMY["pop_base"])
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.building_type == "house" and b.constructed and b.is_alive():
			cap += int(Stats.ECONOMY["pop_per_house"])
	return cap

func pop_used(pid: int) -> int:
	# Dân số tính theo Ô (pop_cost): nông dân 1 ô, lính thường 1 ô, tinh
	# nhuệ 2 ô. Quân đang trong hàng chờ cũng giữ ô ngay từ lúc bấm luyện.
	var used := villager_count(pid) * Stats.pop_cost("pawn")
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u.owner_pid == pid and u.is_alive():
			used += Stats.pop_cost(u.unit_type)
	for n in get_tree().get_nodes_in_group("structures"):
		var s := n as Structure
		if s.owner_pid == pid:
			for item in s.train_queue:
				used += Stats.pop_cost(item["unit_type"])
	# Công trình có TỔ VẬN HÀNH (tháp canh: crew_pop ô cho cung thủ đứng
	# bắn trên đỉnh): ô được GIỮ từ lúc đặt — tháp đang xây đã tính — cho
	# tới khi tháp sập thì trả lại. Đếm ngay trong hàm này để HUD, luật
	# huấn luyện và luật đặt nhà dùng chung đúng 1 con số dân số.
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.is_alive():
			used += int(Stats.BUILDINGS[b.building_type].get("crew_pop", 0))
	return used

## Giới hạn quân (army cap) — TÁCH khỏi dân số: nền army_base + mỗi
## Nhà Lính đã xây xong cộng army_bonus ô. Chỉ tính QUÂN (không tính dân).
func army_cap(pid: int) -> int:
	var cap := int(Stats.ECONOMY["army_base"])
	var bonus := int(Stats.BUILDINGS["soldier_house"]["army_bonus"])
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.building_type == "soldier_house" and b.constructed and b.is_alive():
			cap += bonus
	return cap

## Ô quân đã dùng: quân đang sống + quân đang chờ luyện (theo pop_cost).
func army_used(pid: int) -> int:
	var used := 0
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u.owner_pid == pid and u.is_alive():
			used += Stats.pop_cost(u.unit_type)
	for n in get_tree().get_nodes_in_group("structures"):
		var s := n as Structure
		if s.owner_pid == pid:
			for item in s.train_queue:
				if Stats.is_military(item["unit_type"]):
					used += Stats.pop_cost(item["unit_type"])
	# Cung thủ TRỰC THÁP cũng là quân: mỗi công trình có tổ vận hành còn
	# đứng (kể cả đang xây — ô giữ từ lúc đặt, khớp pop_used ở trên) ngốn
	# thêm crew_pop × pop_cost(crew_unit) Ô QUÂN. Nhờ vậy bộ đếm "Quân:
	# X/Y ô" và cap_block_reason tự tính cả crew, không cần luật riêng.
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.is_alive():
			var bdef: Dictionary = Stats.BUILDINGS[b.building_type]
			var crew := int(bdef.get("crew_pop", 0))
			if crew > 0:
				used += crew * Stats.pop_cost(str(bdef.get("crew_unit", "archer")))
	return used

func unit_type_count(pid: int, unit_type: String) -> int:
	var c := 0
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u.owner_pid == pid and u.unit_type == unit_type and u.is_alive():
			c += 1
	return c

## Lý do bị chặn bởi GIỚI HẠN (chưa xét tài nguyên/nơi sản xuất):
## "" = không kẹt | "army" = kẹt giới hạn quân | "pop" = kẹt dân số chung.
func cap_block_reason(pid: int, unit_type: String) -> String:
	var cost := Stats.pop_cost(unit_type)
	if Stats.is_military(unit_type) and army_used(pid) + cost > army_cap(pid):
		return "army"
	if pop_used(pid) + cost > pop_cap(pid):
		return "pop"
	return ""

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
	var counts := {"house": 0, "barracks": 0, "tower": 0, "storehouse": 0, "soldier_house": 0}
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
	var mx := 1.0 if c.x < WORLD.x / 2.0 else -1.0
	var my := 1.0 if c.y < WORLD.y / 2.0 else -1.0
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
	if building_type == "storehouse":
		# Nhà Kho đặt được ở mọi vùng đã khám phá -> không hiện khung vùng căn cứ.
		_zone_rect.visible = false
		if _hud != null:
			_hud.show_message("Bấm vào vùng ĐÃ KHÁM PHÁ bất kỳ để đặt Nhà Kho — điểm giao tài nguyên (chuột phải để huỷ).")
		return
	_zone_rect.polygon = PackedVector2Array([
		base_zone(HUMAN_PID).position,
		base_zone(HUMAN_PID).position + Vector2(base_zone(HUMAN_PID).size.x, 0),
		base_zone(HUMAN_PID).end,
		base_zone(HUMAN_PID).position + Vector2(0, base_zone(HUMAN_PID).size.y),
	])
	_zone_rect.visible = true
	if _hud != null:
		if building_type == "tower":
			_hud.show_message("Bấm vào vùng sáng quanh thành để đặt Tháp canh — tháp giữ thêm 1 ô dân cho cung thủ đứng bắn (chuột phải để huỷ).")
		else:
			_hud.show_message("Bấm vào vùng sáng quanh thành để đặt %s (chuột phải để huỷ)." % Stats.BUILDINGS[building_type]["label"])

func cancel_modes() -> void:
	placing_type = ""
	awaiting_order = false
	_zone_rect.visible = false
	for c in castles.values():
		(c as Castle).highlight_target = false

# ===================== BÓNG MA ĐẶT NHÀ (placement preview) =====================
# Khi đang ở chế độ đặt nhà (placing_type != ""): hiện sprite thật của công
# trình (đúng loại + màu phe người chơi, bán trong suốt) neo tại điểm mặt đất
# dưới con trỏ (tọa độ world qua camera) + vòng chân đế đúng bán kính chiếm
# đất của công trình. Xanh = đặt được, đỏ = không — tính bằng ĐÚNG hàm luật
# can_place_building mà click đặt nhà dùng (không có bộ luật thứ hai).
# Mọi đường thoát placement (đặt xong / chuột phải / Esc) đều đưa placing_type
# về "" nên bóng ma tự ẩn ở frame kế tiếp, không cần móc thêm vào từng đường.

func _ensure_place_ghost() -> void:
	if _place_ghost != null:
		return
	_place_ghost = Node2D.new()
	_place_ghost.z_index = 65 # trên lớp sương mù (50) và khung chọn (60)
	_place_ghost.visible = false
	_ghost_foot = Polygon2D.new()
	_ghost_foot.z_as_relative = true
	_ghost_foot.z_index = -1 # chân đế nằm dưới sprite trong cùng node ghost
	_place_ghost.add_child(_ghost_foot)
	_ghost_sprite = Sprite2D.new()
	_place_ghost.add_child(_ghost_sprite)
	add_child(_place_ghost)

func _setup_ghost_for(building_type: String) -> void:
	_ghost_type = building_type
	var color_key: String = players[HUMAN_PID].color_key
	_ghost_sprite.texture = load("res://assets/buildings/%s_%s.png" % [building_type, color_key])
	var present: Array = GHOST_PRESENT.get(building_type, [0.55, -30.0])
	var sc := float(present[0])
	_ghost_sprite.scale = Vector2(sc, sc)
	_ghost_sprite.position = Vector2(0, float(present[1]))
	var r := float(Stats.BUILDINGS[building_type]["radius"])
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * float(i) / 40.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	_ghost_foot.polygon = pts

func _update_place_ghost() -> void:
	if placing_type == "" or match_over:
		if _place_ghost != null:
			_place_ghost.visible = false
		return
	_ensure_place_ghost()
	if _ghost_type != placing_type:
		_setup_ghost_for(placing_type)
	var pos := get_global_mouse_position()
	_place_ghost.global_position = pos
	_place_ghost.visible = true
	var ok := can_place_building(players[HUMAN_PID], placing_type, pos)
	if ok:
		_ghost_sprite.modulate = Color(0.65, 1.35, 0.65, 0.55)
		_ghost_foot.color = Color(0.35, 1.0, 0.35, 0.30)
	else:
		_ghost_sprite.modulate = Color(1.45, 0.5, 0.5, 0.55)
		_ghost_foot.color = Color(1.0, 0.3, 0.3, 0.30)

# ===================== CON TRỎ NGỮ CẢNH KHI DI CHUỘT (hover) =====================
# Người chơi từng tưởng click trượt vì di chuột vào tài nguyên mà con trỏ
# không đổi. Luật: đang chọn >= 1 NÔNG DÂN + chuột lên mục tiêu THU THẬP ĐƯỢC
# -> con trỏ đổi sang Cursor_02 (tay chỉ) + vòng sáng nổi dưới chân mục tiêu.
# "Thu thập được" KHỚP ĐÚNG 2 nhánh farm của _handle_right_click (cùng hàm
# phân giải, cùng bán kính 36): cừu qua sheep_at() — phải đang SÁNG trong
# sương mù; node tài nguyên qua res_node_at() + cổng luật của
# exec_direct_farm() — đã khám phá (sương mù ĐEN thì không đổi con trỏ) và
# chưa cạn. Thứ tự cũng theo click phải: cừu xét trước node.
# Pack KHÔNG có con trỏ hình công cụ (rìu/cuốc) hay kiếm tấn công — đã soi
# đủ bộ Cursors 01-04 + Pointers 01-06: chỉ có mũi tên / tay chỉ / dấu cấm /
# góc khung. Nên ngữ cảnh farm dùng Cursor_02; ngữ cảnh tấn công bỏ qua.
# Ưu tiên trạng thái: đang đặt nhà (có bóng ma) hoặc chờ lệnh tổng tấn công
# -> giữ nguyên hành vi cũ; chuột trên HUD -> HUD làm chủ con trỏ như hiện
# tại; đang kéo khung chọn -> không chen vào.
# Cách áp con trỏ: HUD đã gán ảnh pack cho từng shape của Input; riêng shape
# ARROW (shape hiển thị trên vùng map) được hoán ảnh 01 <-> 02 theo ngữ
# cảnh, về "default"/"placement" thì khôi phục đúng ảnh + hotspot HUD đã cài.

## Tính ngữ cảnh con trỏ tại 1 điểm world (vòng lặp chính gọi theo throttle;
## test gọi thẳng hàm này rồi đọc cursor_context / hover_target).
func update_hover_cursor(world_pos: Vector2) -> void:
	if placing_type != "" or awaiting_order:
		_set_cursor_context("placement" if placing_type != "" else "default", null)
		return
	if match_over or _dragging or _is_point_over_ui(world_pos):
		_set_cursor_context("default", null)
		return
	if _selection_has_villager():
		var sheep := sheep_at(world_pos, 36.0)
		if sheep != null:
			_set_cursor_context("gather", sheep)
			return
		var node := res_node_at(world_pos, 36.0)
		if node != null and not node.is_depleted() and is_pos_explored_for(HUMAN_PID, node.global_position):
			_set_cursor_context("gather", node)
			return
	_set_cursor_context("default", null)

func _selection_has_villager() -> bool:
	for n in human_controller().get_selection():
		if n is Villager:
			return true
	return false

## Chuột có đang trên UI không — tính TỪ ĐIỂM WORLD (qua phép biến đổi
## canvas) để khớp cả khi test gọi thẳng update_hover_cursor, không phụ
## thuộc vị trí chuột thật của hệ điều hành. Cùng nguồn sự thật với
## _unhandled_input: hỏi HUD trước, fallback dải y cũ.
func _is_point_over_ui(world_pos: Vector2) -> bool:
	var screen_pos := get_global_transform_with_canvas() * world_pos
	if _hud != null and _hud.has_method("is_point_over_ui"):
		return _hud.is_point_over_ui(screen_pos)
	return screen_pos.y < 38.0 or screen_pos.y > FIELD_BOTTOM

func _set_cursor_context(ctx: String, target: Node2D) -> void:
	var changed := ctx != cursor_context
	cursor_context = ctx
	hover_target = target
	if changed:
		_apply_cursor_image()
	_refresh_hover_ring()

func _apply_cursor_image() -> void:
	if _cursor_tex_default == null:
		_cursor_tex_default = load("res://assets/ui/cursors/cursor_01.png")
		_cursor_tex_gather = load("res://assets/ui/cursors/cursor_02.png")
	if cursor_context == "gather":
		if _cursor_tex_gather != null:
			Input.set_custom_mouse_cursor(_cursor_tex_gather, Input.CURSOR_ARROW, Vector2(30, 17))
	elif _cursor_tex_default != null:
		Input.set_custom_mouse_cursor(_cursor_tex_default, Input.CURSOR_ARROW, Vector2(23, 18))

func _refresh_hover_ring() -> void:
	if cursor_context != "gather" or hover_target == null or not is_instance_valid(hover_target):
		if _hover_ring != null:
			_hover_ring.visible = false
		return
	if _hover_ring == null:
		_hover_ring = HoverRing.new()
		_hover_ring.z_index = 62 # trên sương mù (50) + khung chọn (60), dưới bóng ma đặt nhà (65)
		add_child(_hover_ring)
	_hover_ring.global_position = hover_target.global_position
	(_hover_ring as HoverRing).radius = _hover_ring_radius(hover_target)
	_hover_ring.visible = true
	_hover_ring.queue_redraw()

func _hover_ring_radius(target: Node2D) -> float:
	if target is Sheep:
		return 26.0
	if target is ResourceNode:
		var n := target as ResourceNode
		if n.res_type == "wood":
			return 34.0
		if n.res_type == "meat":
			return 24.0
		return 40.0 if n.is_big else 28.0
	return 30.0

func start_order_mode() -> void:
	awaiting_order = true
	placing_type = ""
	_zone_rect.visible = false
	for pid in castles.keys():
		(castles[pid] as Castle).highlight_target = pid != HUMAN_PID and players[pid].alive
	if _hud != null:
		_hud.show_message("Bấm vào THÀNH ĐỊCH ĐÃ LỘ DIỆN để tổng tấn công, hoặc bấm 1 điểm trên map để quân đi trinh sát tới đó.")

func _handle_right_click(pos: Vector2) -> void:
	var ctrl := human_controller()
	var sel := ctrl.get_selection()
	if sel.is_empty():
		if _hud != null:
			_hud.show_message("Hãy chọn quân trước: kéo chuột trái chọn vùng, rồi click phải ra lệnh.")
		return
	# 1) Quân địch đang SÁNG -> tấn công (chỉ quân mới đánh được).
	var eu := enemy_unit_at(pos, 30.0)
	if eu != null:
		var ordered := ctrl.order_selected_attack(eu)
		if ordered:
			spawn_order_marker(eu.global_position, Color(1, 0.3, 0.3))
			if _hud != null:
				_hud.show_message("Tấn công mục tiêu!")
		else:
			if _hud != null:
				_hud.show_message("Mục tiêu chưa lộ diện — hãy cho quân trinh sát tới gần trước!")
		return
	# 2) Công trình địch -> tấn công (giữ luật sương mù: chưa khám phá thì từ chối).
	var es := enemy_structure_at(pos)
	if es != null:
		var ordered2 := ctrl.order_selected_attack(es)
		if ordered2:
			spawn_order_marker(es.global_position, Color(1, 0.3, 0.3))
			if _hud != null:
				_hud.show_message("Tấn công mục tiêu!")
		else:
			if _hud != null:
				_hud.show_message("Mục tiêu chưa lộ diện — hãy cho quân trinh sát tới gần trước!")
		return
	# 2.5) Cừu đang SÁNG -> nông dân đi SĂN lấy thịt (chỉ nông dân săn được).
	var sheep := sheep_at(pos, 36.0)
	if sheep != null:
		var n_hunt := ctrl.order_selected_farm(sheep)
		if n_hunt > 0:
			spawn_order_marker(sheep.global_position, Color(0.3, 1, 0.4))
			if _hud != null:
				_hud.show_message("Nông dân đi săn cừu lấy thịt.")
		else:
			if _hud != null:
				_hud.show_message("Hãy chọn NÔNG DÂN để săn cừu (quân lính không săn).")
		return
	# 3) Tài nguyên -> nông dân farm đúng loại đó; quân đi tới điểm đó.
	var node := res_node_at(pos, 36.0)
	if node != null:
		var n_farm := ctrl.order_selected_farm(node)
		if n_farm > 0:
			ctrl.order_selected_move(node.global_position, false)
			spawn_order_marker(node.global_position, Color(0.3, 1, 0.4))
			if _hud != null:
				_hud.show_message("Nông dân đi farm %s." % Stats.RES_LABELS[node.res_type])
		else:
			if _hud != null:
				_hud.show_message("Điểm tài nguyên chưa khám phá — hãy trinh sát trước!")
		return
	# 4) Đất trống -> di chuyển tới đó.
	ctrl.order_selected_move(pos, true)
	spawn_order_marker(pos, Color(1, 0.9, 0.3))
	if _hud != null:
		_hud.show_message("Quân đang di chuyển tới điểm đã chọn.")

func _unhandled_input(event: InputEvent) -> void:
	if match_over:
		return
	if event is InputEventMouseButton and event.pressed:
		# Click trên HUD (panel trên/dưới, tọa độ màn hình) thì không tính là click map.
		var screen_pos := get_viewport().get_mouse_position()
		# M2 giai đoạn 3: HUD mới không còn là 2 dải đặc — hỏi thẳng HUD xem
		# điểm này có nằm trên UI không (fallback về dải y cũ nếu HUD chưa có).
		var over_ui := screen_pos.y < 38.0 or screen_pos.y > FIELD_BOTTOM
		if _hud != null and _hud.has_method("is_point_over_ui"):
			over_ui = _hud.is_point_over_ui(screen_pos)
		if over_ui:
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if placing_type != "" or awaiting_order:
				cancel_modes()
			else:
				_handle_right_click(get_global_mouse_position())
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var pos := get_global_mouse_position()
		if placing_type != "":
			var ok := human_controller().place_building(placing_type, pos)
			if _hud != null:
				if ok:
					_hud.show_message("Đã đặt %s." % Stats.BUILDINGS[placing_type]["label"])
				else:
					# Lý do đặc thù (vd tháp hết ô dân cho cung thủ) thì nói
					# rõ, còn lại dùng câu chung như cũ.
					var reason := place_fail_reason(players[HUMAN_PID], placing_type, pos)
					_hud.show_message(reason if reason != "" else "Không đặt được ở đó (ngoài vùng/thiếu tài nguyên/trùng công trình).")
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
		# M2: bắt đầu kéo khung chọn.
		_drag_candidate = true
		_dragging = false
		_drag_start = pos
		_drag_current = pos
		return
	if event is InputEventMouseMotion and _drag_candidate:
		var pos := get_global_mouse_position()
		if pos.distance_to(_drag_start) > 8.0:
			_dragging = true
		_drag_current = pos
		if _dragging and _sel_overlay != null:
			_sel_overlay.queue_redraw()
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _drag_candidate:
		_drag_candidate = false
		if _dragging:
			_dragging = false
			var rect := Rect2(_drag_start, _drag_current - _drag_start).abs()
			select_in_rect(rect)
			if _sel_overlay != null:
				_sel_overlay.queue_redraw()
		else:
			click_select(get_global_mouse_position())
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_modes()
		human_controller().clear_selection()

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

# ===================== DEMO M2 (chạy với -- --m2demo, không bot) =====================
# Các bước: chọn quân bằng khung -> lệnh click phải -> lia camera ->
# panel hướng dẫn -> trinh sát giữa map rồi rút về (vùng đó chỉ còn MỜ).

func _demo_m2_update(delta: float) -> void:
	if elapsed > 300.0:
		get_tree().quit()
		return
	var ctrl := human_controller()
	match _m2demo_stage:
		0:
			if _hud != null:
				_hud.close_help()
			if military_count(0) < 1:
				if castles[0].queue_count() < 1:
					ctrl.queue_training(castles[0], "warrior")
			else:
				_m2demo_stage = 1
		1:
			var rect := Rect2(100, 650, 400, 300)
			select_in_rect(rect)
			_demo_drag_rect = rect
			_demo_show_drag = true
			if _sel_overlay != null:
				_sel_overlay.queue_redraw()
			_m2demo_timer = 0.6
			_m2demo_stage = 2
		2:
			_m2demo_timer -= delta
			if _m2demo_timer <= 0.0:
				_take_shot("res://screenshots/m2_khung_chon.png")
				_m2demo_stage = 3
		3:
			_demo_show_drag = false
			if _sel_overlay != null:
				_sel_overlay.queue_redraw()
			ctrl.order_selected_move(Vector2(700, 700), true)
			spawn_order_marker(Vector2(700, 700), Color(1, 0.9, 0.3))
			_m2demo_timer = 0.5
			_m2demo_stage = 4
		4:
			_m2demo_timer -= delta
			if _m2demo_timer <= 0.0:
				_take_shot("res://screenshots/m2_lenh_click_phai.png")
				_m2demo_stage = 5
		5:
			set_camera_to(Vector2(1000, 500))
			_m2demo_timer = 0.5
			_m2demo_stage = 6
		6:
			_m2demo_timer -= delta
			if _m2demo_timer <= 0.0:
				_take_shot("res://screenshots/m2_camera.png")
				_m2demo_stage = 7
		7:
			if _hud != null:
				_hud.show_help()
			_m2demo_timer = 0.5
			_m2demo_stage = 8
		8:
			_m2demo_timer -= delta
			if _m2demo_timer <= 0.0:
				_take_shot("res://screenshots/m2_huong_dan.png")
				_m2demo_stage = 9
		9:
			if _hud != null:
				_hud.close_help()
			ctrl.order_move(Vector2(960, 480))
			_m2demo_stage = 10
		10:
			if (fogs[HUMAN_PID] as FogOfWar).is_explored_pos(Vector2(960, 480)):
				ctrl.order_move(Vector2(300, 780))
				_m2demo_stage = 11
		11:
			var fog: FogOfWar = fogs[HUMAN_PID]
			if fog.state_at(Vector2(960, 480)) == 1:
				set_camera_to(Vector2(700, 600))
				_m2demo_timer = 0.5
				_m2demo_stage = 12
		12:
			_m2demo_timer -= delta
			if _m2demo_timer <= 0.0:
				_take_shot("res://screenshots/m2_suong_mu_mo.png")
				_m2demo_stage = 13
		13:
			get_tree().quit()

# ===================== DEMO NHÀ LÍNH (chạy với -- --popdemo, không bot) ====
# Sân khấu chụp ảnh: Nhà Lính cạnh Doanh trại -> hàng Lính giáo + Kiếm sĩ
# -> điền đầy ô quân và cố luyện thêm để HUD báo kẹt GIỚI HẠN QUÂN.

func _demo_pop_update(delta: float) -> void:
	if elapsed > 200.0:
		get_tree().quit()
		return
	var p0: PlayerState = players[HUMAN_PID]
	var ctrl := human_controller()
	match _popdemo_stage:
		0:
			for k in Stats.RES_KEYS:
				p0.resources[k] = 9000
			var slots := build_slots(HUMAN_PID)
			exec_place_building(p0, "house", slots[0])
			exec_place_building(p0, "barracks", slots[1])
			exec_place_building(p0, "soldier_house", slots[5])
			for n in get_tree().get_nodes_in_group("buildings"):
				var b := n as Building
				if b.owner_pid == HUMAN_PID:
					b.constructed = true # sân khấu: coi như xây xong ngay
					b._refresh_display()
			set_camera_to(CASTLE_POS[HUMAN_PID] + Vector2(60, -60))
			_popdemo_timer = 0.8
			_popdemo_stage = 1
		1:
			_popdemo_timer -= delta
			if _popdemo_timer <= 0.0:
				_take_shot("res://screenshots/pop_nha_linh.png")
				_popdemo_stage = 2
		2:
			# Hàng quân xen kẽ giáo/kiếm trên bãi cỏ trống dưới thành: gán
			# slot_offset để quân tự về đứng đúng hàng (điểm tập kết +
			# slot_offset), giáo dài nhìn khác hẳn kiếm.
			var kinds := ["lancer", "warrior", "lancer", "warrior", "lancer"]
			for kind in kinds:
				spawn_trained_unit(HUMAN_PID, kind, castles[HUMAN_PID])
			var rally := rally_point(HUMAN_PID)
			var idx := 0
			for n in get_tree().get_nodes_in_group("units"):
				var u := n as Unit
				if u.owner_pid == HUMAN_PID:
					u.slot_offset = Vector2(200 + idx * 50, -80) - (rally - CASTLE_POS[HUMAN_PID])
					u.global_position = rally + u.slot_offset # đứng ngay vào hàng
					idx += 1
			_popdemo_timer = 0.6
			_popdemo_stage = 3
		3:
			_popdemo_timer -= delta
			if _popdemo_timer <= 0.0:
				_take_shot("res://screenshots/pop_lancer.png")
				_popdemo_stage = 4
		4:
			# Điền đầy ô quân rồi cố luyện thêm -> HUD hiện thông báo kẹt.
			while army_used(HUMAN_PID) + 1 <= army_cap(HUMAN_PID):
				spawn_trained_unit(HUMAN_PID, "warrior", castles[HUMAN_PID])
			ctrl.queue_training(castles[HUMAN_PID], "warrior")
			_popdemo_timer = 0.4
			_popdemo_stage = 5
		5:
			_popdemo_timer -= delta
			if _popdemo_timer <= 0.0:
				_take_shot("res://screenshots/pop_ket_quan.png")
				_popdemo_stage = 6
		6:
			get_tree().quit()

# ===================== DEMO GIAI ĐOẠN 2 (chạy với -- --g2demo, không bot) ====
# Sân khấu chụp ảnh kiểm chứng hệ tài nguyên: cây cạn còn gốc -> dân vác thịt
# từ cừu -> Nhà Kho nhận tài nguyên -> mỏ vàng lớn ở trạng thái Destroyed.

func _g2_villagers() -> Array:
	var list: Array = []
	for n in get_tree().get_nodes_in_group("villagers"):
		var v := n as Villager
		if v.owner_pid == HUMAN_PID:
			list.append(v)
	return list

func _demo_g2_update(delta: float) -> void:
	if elapsed > 400.0:
		get_tree().quit()
		return
	var p0: PlayerState = players[HUMAN_PID]
	var castle_pos: Vector2 = castles[HUMAN_PID].global_position
	match _g2demo_stage:
		0:
			p0.resources["wood"] = int(p0.resources["wood"]) + 500
			var vils := _g2_villagers()
			# Cây gần thành: để trữ lượng nhỏ cho cạn nhanh.
			_g2_tree = nearest_resource_node(HUMAN_PID, "wood", castle_pos) as ResourceNode
			_g2_tree.set_amount(15)
			exec_direct_farm(p0, vils[0], _g2_tree)
			# Dân 2: săn cừu gần nhất.
			_g2_hunter = vils[1]
			var sheep := nearest_sheep(HUMAN_PID, castle_pos)
			if sheep != null:
				exec_direct_farm(p0, _g2_hunter, sheep)
			# Nhà Kho cạnh mỏ vàng nhỏ + dân 3 farm vàng (giao về kho này).
			exec_place_building(p0, "storehouse", castle_pos + Vector2(185, -140))
			for n in get_tree().get_nodes_in_group("buildings"):
				var b := n as Building
				if b.owner_pid == HUMAN_PID and b.building_type == "storehouse":
					_g2_store = b
					b.constructed = true
			var gold_node := nearest_resource_node(HUMAN_PID, "gold", castle_pos)
			if gold_node != null:
				exec_direct_farm(p0, vils[2], gold_node)
			# Mỏ vàng lớn giữa map: ghi lại vị trí; luyện thêm 1 nông dân
			# làm trinh sát (cử đi ở stage 5, cho mỏ cạn khi trinh sát tới gần).
			for n in get_tree().get_nodes_in_group("res_nodes"):
				var rn := n as ResourceNode
				if rn.res_type == "gold" and rn.is_big:
					_g2_mine = rn
			human_controller().queue_training(castles[HUMAN_PID], "pawn")
			_g2demo_stage = 1
		1:
			if _g2_tree != null and _g2_tree.is_stump():
				_g2demo_timer += delta
				if _g2demo_timer > 1.2:
					set_camera_to(_g2_tree.global_position + Vector2(60, 40))
					_g2demo_timer = 0.0
					_g2demo_stage = 2
		2:
			_g2demo_timer += delta
			if _g2demo_timer > 0.6:
				_take_shot("res://screenshots/g2_cay_do_goc.png")
				_g2demo_timer = 0.0
				_g2demo_stage = 3
		3:
			if _g2_hunter != null and _g2_hunter.carrying_type == "meat":
				set_camera_to(_g2_hunter.global_position + Vector2(-40, 30))
				_g2demo_stage = 4
		4:
			_g2demo_timer += delta
			if _g2demo_timer > 0.35:
				_take_shot("res://screenshots/g2_cuu_vac_thit.png")
				_g2demo_timer = 0.0
				_g2demo_stage = 5
		5:
			if not _g2_scout_sent and villager_count(HUMAN_PID) >= 4:
				for v in _g2_villagers():
					var vil := v as Villager
					if vil != _g2_hunter and not vil.is_direct():
						vil.set_move_point(_g2_mine.global_position + Vector2(-70, 60))
						_g2_scout_sent = true
			var delivering := false
			if _g2_store != null:
				for v in _g2_villagers():
					var vil := v as Villager
					if vil.carrying > 0 and vil.global_position.distance_to(_g2_store.global_position) < 300.0:
						delivering = true
			_g2demo_timer += delta
			if delivering or _g2demo_timer > 45.0:
				set_camera_to(_g2_store.global_position + Vector2(30, 30))
				_g2demo_timer = 0.0
				_g2demo_stage = 6
		6:
			_g2demo_timer += delta
			if _g2demo_timer > 0.6:
				_take_shot("res://screenshots/g2_nha_kho.png")
				_g2demo_timer = 0.0
				_g2demo_stage = 7
		7:
			if _g2_mine == null or not is_instance_valid(_g2_mine):
				_g2demo_stage = 9 # mỏ đã biến mất trước khi trinh sát tới
			else:
				# Trinh sát tới gần -> cho mỏ cạn NGAY (hiện Destroyed 6s).
				if not _g2_mine.is_depleted():
					for v in _g2_villagers():
						if (v as Villager).global_position.distance_to(_g2_mine.global_position) < 320.0:
							_g2_mine.set_amount(0)
				if _g2_mine.is_depleted() and (fogs[HUMAN_PID] as FogOfWar).is_visible_pos(_g2_mine.global_position):
					set_camera_to(_g2_mine.global_position)
					_g2demo_timer = 0.0
					_g2demo_stage = 8
		8:
			_g2demo_timer += delta
			if _g2demo_timer > 0.6:
				_take_shot("res://screenshots/g2_mo_destroyed.png")
				_g2demo_stage = 9
		9:
			get_tree().quit()

# ===================== LỚP PHỦ SƯƠNG MÙ (vẽ cho người chơi) =====================

class FogOverlay:
	extends Node2D
	# Luật hiển thị sương mù: ĐEN = chưa khám phá (alpha 1.0), MỜ = đã khám phá
	# nhưng không còn tầm nhìn (chỉ mờ đi, KHÔNG BAO GIỜ đen lại), SÁNG = không phủ.
	# M2: giảm alpha lớp mờ từ 0.45 xuống 0.25 — lớp 0.45 phủ lên địa hình tối
	# nhìn gần như đen, người chơi tưởng vùng đã mở bị đen lại.
	const DIM_COLOR := Color(0, 0, 0, 0.25)
	const BLACK_COLOR := Color(0, 0, 0, 1.0)
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
					draw_rect(rect, DIM_COLOR)
				else:
					draw_rect(rect, BLACK_COLOR)

# Khung kéo chọn quân (vẽ theo tọa độ thế giới, đi theo camera).
# M2 giai đoạn 3: khung = nền trắng mờ + 4 GÓC VÀNG lấy từ pack
# (Update 010 UI/Pointers/02 — mỗi góc là 1/4 ảnh, vẽ kích thước cố định
# bất kể khung to nhỏ). Vòng chọn dưới chân quân giữ nguyên màu xanh.
class SelectionOverlay:
	extends Node2D
	const CORNER_TEX := preload("res://assets/ui/pointers_02.png")
	const CORNER := 30.0 # kích thước mỗi góc khi vẽ (ảnh gốc 64, mỗi góc 32)
	var game: Node = null

	func _draw() -> void:
		if game == null:
			return
		var rect := Rect2()
		if game._dragging:
			rect = Rect2(game._drag_start, game._drag_current - game._drag_start).abs()
		elif game._demo_show_drag:
			rect = game._demo_drag_rect
		else:
			return
		draw_rect(rect, Color(1, 1, 1, 0.08))
		var h := CORNER * 0.5
		var tl := rect.position
		var br := rect.position + rect.size
		draw_texture_rect_region(CORNER_TEX, Rect2(tl - Vector2(h, h), Vector2(CORNER, CORNER)), Rect2(0, 0, 32, 32))
		draw_texture_rect_region(CORNER_TEX, Rect2(Vector2(br.x - h, tl.y - h), Vector2(CORNER, CORNER)), Rect2(32, 0, 32, 32))
		draw_texture_rect_region(CORNER_TEX, Rect2(Vector2(tl.x - h, br.y - h), Vector2(CORNER, CORNER)), Rect2(0, 32, 32, 32))
		draw_texture_rect_region(CORNER_TEX, Rect2(br - Vector2(h, h), Vector2(CORNER, CORNER)), Rect2(32, 32, 32, 32))

# Vòng sáng dưới chân mục tiêu thu thập được khi di chuột (nông dân đang
# chọn): elip dẹt theo mặt đất, vàng nhạt — cùng họ "dấu mục tiêu" với khung
# chọn góc vàng của pack, nhưng nhẹ và nằm dưới chân node cho khỏi rối.
class HoverRing:
	extends Node2D
	var radius: float = 32.0

	func _draw() -> void:
		var outline := PackedVector2Array()
		var fill := PackedVector2Array()
		for i in 41:
			var a := TAU * float(i) / 40.0
			var p := Vector2(cos(a) * radius, sin(a) * radius * 0.42)
			outline.append(p)
			if i < 40:
				fill.append(p)
		draw_colored_polygon(fill, Color(1.0, 0.9, 0.45, 0.13))
		draw_polyline(outline, Color(1.0, 0.9, 0.45, 0.85), 2.5, true)

# Vòng dấu lệnh click phải: hiện rồi mờ dần.
class OrderMarker:
	extends Node2D
	var marker_color: Color = Color(1, 0.9, 0.3)

	func _ready() -> void:
		var tw := create_tween()
		tw.tween_interval(0.7)
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, marker_color, 3.0)
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 24, marker_color, 2.0)
