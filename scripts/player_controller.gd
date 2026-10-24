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

# ===================== LÊN ĐỜI / NÂNG CẤP / NGHIÊN CỨU =====================

func start_age_up(castle: Structure) -> bool:
	if player == null or not player.alive or castle == null:
		return false
	return game.exec_start_age_up(player, castle)

func start_unit_research(building: Structure, unit_type: String) -> bool:
	if player == null or not player.alive or building == null:
		return false
	return game.exec_start_unit_research(player, building, unit_type)

func start_building_upgrade(building: Building) -> bool:
	if player == null or not player.alive or building == null:
		return false
	return game.exec_start_building_upgrade(player, building)

# ===================== M2: CHỌN QUÂN + LỆNH TRỰC TIẾP =====================
# Selection là trạng thái của "nguồn lệnh" này (bot không dùng, nhưng vẫn
# nằm chung cửa để sau này người qua mạng cắm chung). Mọi lệnh trực tiếp
# đều đi qua Main (lớp thực thi) như mọi lệnh cũ.

var selected: Array = [] # Array[Node] (Unit/Villager của player này)
var selected_structure: Structure = null # công trình đang chọn (panel nâng cấp/nghiên cứu)

## Chọn 1 công trình của mình (HUD hiện panel Lên Đời / Nâng cấp / Nghiên
## cứu). Chọn công trình thì bỏ chọn quân và ngược lại.
func set_structure_selection(s: Structure) -> void:
	set_selection([])
	selected_structure = s

func get_selected_structure() -> Structure:
	if selected_structure != null and (not is_instance_valid(selected_structure) or not selected_structure.is_alive()):
		selected_structure = null
	return selected_structure

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
	selected_structure = null
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
