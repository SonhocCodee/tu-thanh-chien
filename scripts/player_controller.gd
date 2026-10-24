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

func set_villager_allocation(wood: int, stone: int, gold: int) -> bool:
	if player == null or not player.alive:
		return false
	return game.exec_set_allocation(player, maxi(0, wood), maxi(0, stone), maxi(0, gold))

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
