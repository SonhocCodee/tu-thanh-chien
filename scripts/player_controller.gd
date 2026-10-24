class_name PlayerController
extends Node

## LỚP ĐIỀU KHIỂN — cửa lệnh DUY NHẤT vào game.
## Người thật (qua HUD), bot, và sau này là người qua mạng LAN đều là "nguồn lệnh"
## cắm vào đây. HUD/bot KHÔNG chạm trực tiếp logic game; mọi lệnh đều qua API này
## và được Main (lớp thực thi) kiểm tra hợp lệ rồi mới chạy.
##
## API lệnh:
##   set_villager_allocation(wood, stone, gold) -> bool
##   place_building(building_type, position) -> bool
##   queue_training(building, unit_type) -> bool
##   set_stance("hold") / set_stance("attack", target_player_id) -> bool
##   order_move(point) -> bool   (cho quân đi tới điểm — trinh sát/mở map)
## API truy vấn (đọc, qua dữ liệu sương mù của phe mình):
##   is_castle_revealed(target_player_id) -> bool
##   is_point_explored(point) -> bool

var player: PlayerState = null
var game: Node = null # Main

func setup(p_player: PlayerState, p_game: Node) -> void:
	player = p_player
	game = p_game

func set_villager_allocation(wood: int, stone: int, gold: int, meat: int = 0) -> bool:
	if player == null or not player.alive:
		return false
	return game.exec_set_allocation(player, maxi(0, wood), maxi(0, stone), maxi(0, gold), maxi(0, meat))

func place_building(building_type: String, position: Vector2) -> bool:
	if player == null or not player.alive:
		return false
	return game.exec_place_building(player, building_type, position)

func queue_training(building: Structure, unit_type: String) -> bool:
	if player == null or not player.alive or building == null:
		return false
	return game.exec_queue_training(player, building, unit_type)

func set_stance(stance: String, target_player_id: int = -1) -> bool:
	if player == null or not player.alive:
		return false
	if stance == "attack":
		# Luật sương mù: chỉ tấn công đích danh thành ĐÃ LỘ DIỆN với phe mình.
		if not is_castle_revealed(target_player_id):
			return false
	return game.exec_set_stance(player, stance, target_player_id)

func order_move(point: Vector2) -> bool:
	if player == null or not player.alive:
		return false
	return game.exec_order_move(player, point)

# ===================== M2: CHỌN QUÂN + LỆNH TRỰC TIẾP =====================
# Selection là trạng thái của "nguồn lệnh" này (bot không dùng, nhưng vẫn
# nằm chung cửa để sau này người qua mạng cắm chung). Mọi lệnh trực tiếp
# đều đi qua Main (lớp thực thi) như mọi lệnh cũ.

var selected: Array = [] # Array[Node] (Unit/Villager của player này)

func _prune_selection() -> void:
	var kept: Array = []
	for n in selected:
		if n == null or not is_instance_valid(n):
			continue
		if n is Unit and not (n as Unit).is_alive():
			continue
		kept.append(n)
	selected = kept

func set_selection(units: Array) -> void:
	for n in selected:
		if n != null and is_instance_valid(n):
			if n is Unit:
				(n as Unit).selected = false
				(n as Unit).queue_redraw()
			elif n is Villager:
				(n as Villager).selected = false
				(n as Villager).queue_redraw()
	selected = []
	for n in units:
		if n == null or not is_instance_valid(n):
			continue
		if n is Unit:
			var u := n as Unit
			if u.owner_pid != player.pid or not u.is_alive():
				continue
			u.selected = true
			u.queue_redraw()
			selected.append(u)
		elif n is Villager:
			var v := n as Villager
			if v.owner_pid != player.pid:
				continue
			v.selected = true
			v.queue_redraw()
			selected.append(v)

func clear_selection() -> void:
	set_selection([])

func get_selection() -> Array:
	_prune_selection()
	return selected.duplicate()

func _selected_military() -> Array:
	var out: Array = []
	for n in get_selection():
		if n is Unit:
			out.append(n)
	return out

func _selected_villagers() -> Array:
	var out: Array = []
	for n in get_selection():
		if n is Villager:
			out.append(n)
	return out

func order_selected_move(point: Vector2, include_villagers: bool) -> int:
	if player == null or not player.alive:
		return 0
	var count := 0
	for u in _selected_military():
		if game.exec_direct_move(player, u, point):
			count += 1
	if include_villagers:
		for v in _selected_villagers():
			if game.exec_villager_move(player, v, point):
				count += 1
	return count

func order_selected_farm(node: Node2D) -> int:
	if player == null or not player.alive:
		return 0
	var count := 0
	for v in _selected_villagers():
		if game.exec_direct_farm(player, v, node):
			count += 1
	return count

func order_selected_attack(target: Node) -> bool:
	if player == null or not player.alive:
		return false
	var mil := _selected_military()
	if mil.is_empty():
		return false
	var any := false
	for u in mil:
		if game.exec_direct_attack(player, u, target):
			any = true
	return any

# ===================== LỆNH RTS NÂNG CAO (Team 5) =====================
# Chỉ quân LÍNH nhận các lệnh này (nông dân bỏ qua). Vẫn qua Main kiểm tra
# hợp lệ như mọi lệnh khác — bot/người qua mạng sau này dùng chung cửa này.

## Đánh-di-chuyển tới 1 điểm: tự đánh địch thấy được trên đường, tới nơi
## giữ điểm. Trả về số quân đã nhận lệnh.
func order_selected_attack_move(point: Vector2) -> int:
	if player == null or not player.alive:
		return 0
	var count := 0
	for u in _selected_military():
		if game.exec_attack_move(player, u, point):
			count += 1
	return count

## Tuần tra giữa vị trí hiện tại của từng quân (A) và point (B).
func order_selected_patrol(point: Vector2) -> int:
	if player == null or not player.alive:
		return 0
	var count := 0
	for u in _selected_military():
		if game.exec_patrol(player, u, point):
			count += 1
	return count

## Hộ vệ 1 quân/công trình ĐỒNG MINH (target do Main kiểm tra phe/tính
## sống; quân tự hộ vệ chính nó bị loại ở Main).
func order_selected_guard(target: Node) -> int:
	if player == null or not player.alive or target == null:
		return 0
	var count := 0
	for u in _selected_military():
		if game.exec_guard(player, u, target):
			count += 1
	return count

## Chọn TOÀN BỘ quân lính còn sống của phe (phím Shift+A / nút HUD).
func select_all_military() -> int:
	if player == null or not player.alive:
		return 0
	var list: Array = game.military_units_of(player.pid)
	set_selection(list)
	return list.size()

## Tìm nông dân NHÀN RỖI kế tiếp (xoay vòng): Main chọn hộ + lia camera
## tới (phím "." / nút HUD). Trả null nếu không còn ai nhàn.
func find_idle_villager() -> Villager:
	if player == null or not player.alive:
		return null
	return game.exec_find_idle_villager(player)

func is_castle_revealed(target_player_id: int) -> bool:
	if game == null or player == null:
		return false
	return game.is_castle_revealed_for(player.pid, target_player_id)

func is_point_explored(point: Vector2) -> bool:
	if game == null or player == null:
		return false
	return game.is_pos_explored_for(player.pid, point)

## Địch mà phe mình đang NHÌN THẤY (ô SÁNG trong sương mù của mình) gần 1 điểm.
func visible_enemies_near(point: Vector2, radius: float) -> Array:
	if game == null or player == null:
		return []
	return game.visible_enemy_units_for(player.pid, point, radius)

## Các phe địch mà thành của họ ĐÃ LỘ DIỆN trong dữ liệu khám phá của mình.
func known_enemy_castles() -> Array:
	if game == null or player == null:
		return []
	return game.known_enemy_castles(player.pid)
