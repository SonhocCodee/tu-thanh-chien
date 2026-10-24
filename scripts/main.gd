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
	"store_wood": [0.6, -30.0],
	"store_stone": [0.6, -30.0],
	"store_gold": [0.38, -26.0],
	"store_meat": [0.46, -28.0],
}

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
var storedemo_mode: bool = false
var _storedemo_stage: int = 0
var _storedemo_timer: float = 0.0
var _storedemo_enemy: Building = null
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
	if "--storedemo" in args:
		storedemo_mode = true
		bots_enabled = false
		Engine.time_scale = 2.0
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
				grant_resource(p.pid, k, 500)

func _process(delta: float) -> void:
	if not match_over:
		elapsed += delta
	_fog_timer -= delta
	if _fog_timer <= 0.0:
		_fog_timer = float(Stats.FOG["update_interval"])
		_update_fog()
	_update_camera(delta)
	_update_place_ghost()
	if demo_mode:
		_demo_update()
	if m2demo_mode:
		_demo_m2_update(delta)
	if g2demo_mode:
		_demo_g2_update(delta)
	if storedemo_mode:
		_demo_store_update(delta)

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

# ===================== KHO (điểm giao tài nguyên) + SỔ CHỨA =====================
# Hệ kho kiểu Clash of Clans: thành chính = kho TỔNG (nhận mọi loại, không
# giới hạn); mỗi kho chuyên dụng CHỈ nhận đúng loại của nó và có sức chứa.
# Lượng chứa trong từng công trình (Structure.stored) là SỔ THẬT: tổng tài
# nguyên của phe (player.resources, cái HUD/bot/giá cả đọc) LUÔN bằng
# thành + tổng các kho. Mọi cộng/trừ đi qua 3 điểm tập trung dưới đây:
# deposit_to (nộp hàng), spend_resources (chi tiêu), _loot_structure (cướp).

## Điểm giao GẦN NHẤT của 1 phe CHO ĐÚNG LOẠI res_key: kho chuyên dụng đúng
## loại còn chỗ trống, hoặc thành chính (luôn nhận). Kho đầy thì tự rơi xuống
## điểm hợp lệ tiếp theo — không bao giờ kẹt vì thành chính không giới hạn.
func nearest_dropoff(pid: int, from_pos: Vector2, res_key: String) -> Node2D:
	var best: Node2D = null
	var best_d := 1e9
	if castles.has(pid):
		var castle := castles[pid] as Castle
		if castle != null and castle.is_alive():
			best = castle
			best_d = from_pos.distance_to(castle.global_position)
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.is_valid_dropoff() and b.can_accept(res_key):
			var d := from_pos.distance_to(b.global_position)
			if d < best_d:
				best_d = d
				best = b
	return best

## Nộp `amount` tài nguyên loại res_key vào ĐÚNG công trình kho s.
## Trả về số THỰC nộp được (kho chuyên dụng gần đầy -> nộp một phần).
## Cộng đồng thời vào sổ của công trình và tổng của phe (qua add_resource).
func deposit_to(s: Structure, res_key: String, amount: int) -> int:
	if s == null or not is_instance_valid(s):
		return 0
	var put: int = mini(amount, s.free_space(res_key))
	if put <= 0:
		return 0
	s.stored[res_key] = s.stored_amount(res_key) + put
	players[s.owner_pid].add_resource(res_key, put)
	return put

## Chi tiêu TẬP TRUNG cho xây/luyện: trừ sổ theo thứ tự THÀNH CHÍNH trước,
## rồi tới các kho chuyên dụng; tổng của phe trừ qua PlayerState.pay.
## Trả false (không trừ gì) nếu không đủ tổng tài nguyên.
func spend_resources(player: PlayerState, cost: Dictionary) -> bool:
	if not player.can_afford(cost):
		return false
	for k in cost.keys():
		var need := int(cost[k])
		if need <= 0:
			continue
		var castle := castles.get(player.pid) as Castle
		if castle != null:
			var take := mini(need, castle.stored_amount(k))
			if take > 0:
				castle.stored[k] = castle.stored_amount(k) - take
				need -= take
		if need > 0:
			for n in get_tree().get_nodes_in_group("buildings"):
				var b := n as Building
				if b.owner_pid == player.pid and b.is_storage():
					var take2 := mini(need, b.stored_amount(k))
					if take2 > 0:
						b.stored[k] = b.stored_amount(k) - take2
						need -= take2
					if need <= 0:
						break
	player.pay(cost)
	return true

## Tổng lượng đang chứa trong mọi kho của 1 phe, theo loại.
## Bất biến sổ: phải luôn bằng player.resources của phe đó.
func total_stored(pid: int) -> Dictionary:
	var tot := {"wood": 0, "stone": 0, "gold": 0, "meat": 0}
	var castle := castles.get(pid) as Castle
	if castle != null:
		for k in Stats.RES_KEYS:
			tot[k] = int(tot[k]) + castle.stored_amount(k)
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.is_storage():
			for k in Stats.RES_KEYS:
				tot[k] = int(tot[k]) + b.stored_amount(k)
	return tot

## Cấp tài nguyên thẳng vào thành chính (chỉ dùng cho sân khấu demo chụp ảnh).
func grant_resource(pid: int, res_key: String, amount: int) -> void:
	var castle := castles.get(pid) as Castle
	if castle != null:
		castle.stored[res_key] = castle.stored_amount(res_key) + amount
	players[pid].add_resource(res_key, amount)

func _build_castles() -> void:
	for pid in CASTLE_POS.keys():
		var castle := CastleScene.instantiate() as Castle
		castle.setup(pid, Stats.PLAYERS[pid]["color_key"], Stats.PLAYERS[pid]["name"], self)
		castle.position = CASTLE_POS[pid]
		castle.z_index = 5
		add_child(castle)
		castle.structure_destroyed.connect(_on_structure_destroyed)
		castles[pid] = castle
		# Tài nguyên khởi đầu nằm trong THÀNH CHÍNH (kho tổng) — sổ chứa
		# khởi tạo bằng đúng tổng resources mà PlayerState đã nhận.
		for k in Stats.RES_KEYS:
			castle.stored[k] = int(players[pid].resources[k])

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
	if not demo_mode and not m2demo_mode and not g2demo_mode and not storedemo_mode:
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
		c + Vector2(mx * -175, 0), # ô cũ của Nhà Kho (giữ trống)
		# 4 ô kho chuyên dụng (bot xây lần lượt Gỗ -> Vàng -> Đá -> Thịt).
		# Đã kiểm: cách mọi công trình >= 62, node >= 48, cừu >= 40 ở cả 4 góc,
		# và nằm trong tầm nhìn thành (265) nên thuộc vùng đã khám phá.
		c + Vector2(mx * -175, my * -95),
		c + Vector2(mx * -175, my * 95),
		c + Vector2(mx * 105, my * -115),
		c + Vector2(mx * 150, my * 110),
	]

## Công trình này có phải KHO chuyên dụng không (khai "storage_res" trong Stats).
func is_warehouse_type(building_type: String) -> bool:
	return Stats.BUILDINGS.get(building_type, {}).has("storage_res")

## Luật đặt nhà DÙNG CHUNG — 1 nguồn luật duy nhất cho click đặt thật
## (exec_place_building) và bóng ma xem trước (placement preview).
## true = đặt được tại pos: còn đủ tiền, đúng vùng (kho: vùng ĐÃ KHÁM PHÁ;
## nhà thường: vùng căn cứ), không quá gần công trình (62) / node (48) / cừu (40).
func can_place_building(player: PlayerState, building_type: String, pos: Vector2) -> bool:
	if not Stats.BUILDINGS.has(building_type):
		return false
	var def: Dictionary = Stats.BUILDINGS[building_type]
	if not player.can_afford(def["cost"]):
		return false
	if is_warehouse_type(building_type):
		# Kho chuyên dụng: đặt ở bất cứ vùng ĐÃ KHÁM PHÁ nào của phe mình
		# (để kê gần bãi farm xa), không giới hạn vùng căn cứ như nhà thường.
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

func exec_place_building(player: PlayerState, building_type: String, pos: Vector2) -> bool:
	if not can_place_building(player, building_type, pos):
		return false
	var def: Dictionary = Stats.BUILDINGS[building_type]
	spend_resources(player, def["cost"])
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
	spend_resources(player, def["cost"])
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
	var counts := {"house": 0, "barracks": 0, "tower": 0,
		"store_wood": 0, "store_stone": 0, "store_gold": 0, "store_meat": 0}
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
	_loot_structure(s)
	if s is Castle:
		_eliminate_player(s.owner_pid)

## CƯỚP KHO (kiểu Clash of Clans): kho/thành bị phá -> phe tấn công nhận
## TOÀN BỘ lượng đang chứa trong công trình đó (cộng vào THÀNH CHÍNH của
## phe tấn công — không giới hạn nên không bao giờ mất phần cướp vì đầy).
## Công trình không phải kho thì không có gì để cướp. Phần chứa của nạn
## nhân trừ tương ứng; không có kẻ phá hợp lệ (đòn tự huỷ/test) thì phần
## chứa cháy theo công trình.
func _loot_structure(s: Structure) -> void:
	if not s.is_storage():
		return
	var loot := {}
	for k in Stats.RES_KEYS:
		var amt := s.stored_amount(k)
		if amt > 0:
			loot[k] = amt
	if loot.is_empty():
		return
	var victim: PlayerState = players[s.owner_pid]
	for k in loot.keys():
		victim.resources[k] = int(victim.resources[k]) - int(loot[k])
		s.stored[k] = 0
	var atk_pid := s.last_attacker_pid
	if atk_pid < 0 or atk_pid == s.owner_pid or atk_pid >= players.size() or not players[atk_pid].alive:
		return
	var atk_castle := castles.get(atk_pid) as Castle
	if atk_castle == null or not atk_castle.is_alive():
		return
	for k in loot.keys():
		atk_castle.stored[k] = atk_castle.stored_amount(k) + int(loot[k])
		players[atk_pid].resources[k] = int(players[atk_pid].resources[k]) + int(loot[k])
	# Báo cho 2 phía liên quan nếu là người chơi (bot đánh nhau thì bỏ qua).
	if _hud != null:
		var parts: Array[String] = []
		for k in Stats.RES_KEYS:
			if loot.has(k):
				parts.append("%d %s" % [int(loot[k]), str(Stats.RES_LABELS[k]).to_lower()])
		var loot_text := ", ".join(parts)
		var sname := "Thành chính" if s is Castle else str(Stats.BUILDINGS[(s as Building).building_type]["label"])
		if s.owner_pid == HUMAN_PID:
			_hud.show_message("%s bị phá! Địch cướp mất: %s." % [sname, loot_text])
		elif atk_pid == HUMAN_PID:
			_hud.show_message("Cướp được %s từ %s của địch!" % [loot_text, sname])

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
	# Công trình còn lại thành tàn tích; sổ chứa của chúng cháy theo
	# (phe đã bị loại thì tổng tài nguyên cũng về 0 cho sổ sách sạch).
	for n in get_tree().get_nodes_in_group("buildings"):
		var b := n as Building
		if b.owner_pid == pid and b.is_alive():
			b.force_ruin()
			for k in Stats.RES_KEYS:
				b.stored[k] = 0
	for k in Stats.RES_KEYS:
		player.resources[k] = 0
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
	if is_warehouse_type(building_type):
		# Kho chuyên dụng đặt được ở mọi vùng đã khám phá -> không hiện khung vùng căn cứ.
		_zone_rect.visible = false
		if _hud != null:
			var res_key := str(Stats.BUILDINGS[building_type]["storage_res"])
			_hud.show_message("Bấm vào vùng ĐÃ KHÁM PHÁ bất kỳ để đặt %s — điểm giao %s (chuột phải để huỷ)." % [
				str(Stats.BUILDINGS[building_type]["label"]), str(Stats.RES_LABELS[res_key]).to_lower()])
		return
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
			grant_resource(HUMAN_PID, "wood", 500)
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
			# Kho Vàng cạnh mỏ vàng nhỏ + dân 3 farm vàng (giao về kho này).
			exec_place_building(p0, "store_gold", castle_pos + Vector2(185, -140))
			for n in get_tree().get_nodes_in_group("buildings"):
				var b := n as Building
				if b.owner_pid == HUMAN_PID and b.building_type == "store_gold":
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
				_take_shot("res://screenshots/g2_kho_vang.png")
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

# ===================== DEMO KHO (chạy với -- --storedemo, không bot) ====
# Sân khấu chụp ảnh cho hệ kho chuyên dụng: 4 kho cạnh nhau (thấy biển hiệu
# từng loại) -> phá Kho Vàng địch chứa 260 vàng, thông báo cướp hiện lên.

func _demo_store_update(delta: float) -> void:
	if elapsed > 120.0:
		get_tree().quit()
		return
	var p0: PlayerState = players[HUMAN_PID]
	match _storedemo_stage:
		0:
			grant_resource(HUMAN_PID, "wood", 3000)
			var base: Vector2 = CASTLE_POS[HUMAN_PID] + Vector2(-120, -160)
			var types := ["store_wood", "store_stone", "store_gold", "store_meat"]
			for i in 4:
				if exec_place_building(p0, types[i], base + Vector2(i * 110, 0)):
					for n in get_tree().get_nodes_in_group("buildings"):
						var b := n as Building
						if b.owner_pid == HUMAN_PID and b.building_type == types[i]:
							b.constructed = true
							b._refresh_display()
			set_camera_to(Vector2(640, 600))
			_storedemo_timer = 0.8
			_storedemo_stage = 1
		1:
			_storedemo_timer -= delta
			if _storedemo_timer <= 0.0:
				_take_shot("res://screenshots/store_4_kho.png")
				_storedemo_stage = 2
		2:
			# Kho Vàng của địch (pid 1) chứa sẵn 260 vàng (sổ phe địch tăng
			# tương ứng), dựng cạnh căn cứ người chơi + 3 kiếm sĩ vây quanh.
			var p1: PlayerState = players[1]
			var eb := BuildingScene.instantiate() as Building
			eb.setup(1, "store_gold", p1.color_key, self)
			eb.position = CASTLE_POS[HUMAN_PID] + Vector2(340, -80)
			eb.z_index = 5
			add_child(eb)
			eb.structure_destroyed.connect(_on_structure_destroyed)
			eb.constructed = true
			eb._refresh_display()
			eb.stored["gold"] = 260
			p1.resources["gold"] = int(p1.resources["gold"]) + 260
			_storedemo_enemy = eb
			for i in 3:
				var u := UnitScene.instantiate() as Unit
				u.setup(HUMAN_PID, "warrior", p0.color_key, self, Vector2.ZERO)
				u.position = eb.position + Vector2(-70 + i * 55, 55)
				u.z_index = 10
				_units_layer.add_child(u)
				u.died.connect(_on_unit_died)
			set_camera_to(Vector2(640, 600))
			_storedemo_timer = 0.8
			_storedemo_stage = 3
		3:
			_storedemo_timer -= delta
			if _storedemo_timer <= 0.0:
				# Phá kho ngay trước lúc chụp: nổ + thông báo cướp.
				_storedemo_enemy.take_damage(99999.0, HUMAN_PID)
				_storedemo_timer = 0.35
				_storedemo_stage = 4
		4:
			_storedemo_timer -= delta
			if _storedemo_timer <= 0.0:
				_take_shot("res://screenshots/store_cuop_kho.png")
				_storedemo_stage = 5
		5:
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
