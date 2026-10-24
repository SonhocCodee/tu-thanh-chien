class_name Bot
extends Node

## Bot chơi qua ĐÚNG PlayerController như người thật, và chỉ "biết" những gì
## sương mù của nó cho biết: địch đang nhìn thấy + thành địch đã lộ diện.
## Kịch bản: phân bổ nông dân -> xây Nhà -> Doanh trại -> Tháp -> huấn luyện ->
## cử quân trinh sát mở map -> lộ diện thành địch -> tổng tấn công.
## Căn cứ bị đánh (thấy địch gần nhà / thành mất máu) -> kéo quân về GIỮ NHÀ.

var ctrl: PlayerController = null
var player: PlayerState = null
var game: Node = null
var attack_army_size: int = 8

var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _last_castle_hp: float = -1.0
var _threatened: bool = false
var _scout_wait: float = 20.0
var _scout_elapsed: float = 0.0
var _scout: Unit = null # trinh sát = 1 quân đi riêng (lệnh trực tiếp), KHÔNG kéo cả đạo quân
var _scout_dest: Vector2 = Vector2.ZERO

func setup(p_ctrl: PlayerController, p_game: Node) -> void:
	ctrl = p_ctrl
	player = p_ctrl.player
	game = p_game
	_rng.randomize()
	_timer = _rng.randf_range(0.3, 1.0)
	attack_army_size = int(Stats.BOT["attack_army_size"])

func _process(delta: float) -> void:
	if player == null or not player.alive or game == null or game.match_over:
		return
	_timer -= delta
	_scout_wait -= delta
	_scout_elapsed += delta
	if _timer > 0.0:
		return
	_timer = float(Stats.BOT["decision_interval"])
	_decide()

## Lượt trinh sát hiện tại đã xong chưa: quân chết dọc đường, đã tới điểm
## hẹn, hoặc đi quá lâu (kẹt) — xong thì chờ một lúc rồi cử lượt mới.
func _scout_done() -> bool:
	if _scout == null or not is_instance_valid(_scout) or not _scout.is_alive():
		return true
	if _scout_elapsed > 120.0:
		return true
	return _scout.global_position.distance_to(_scout_dest) < 150.0

## Chọn 1 quân đang rảnh làm trinh sát.
func _pick_scout() -> Unit:
	for n in game.get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u.owner_pid == player.pid and u.is_alive() and u.direct_mode == "":
			return u
	return null

func _decide() -> void:
	var castle: Castle = game.castles[player.pid]
	if castle == null:
		return
	if _last_castle_hp < 0.0:
		_last_castle_hp = castle.hp

	# 1) Phòng thủ: chỉ phản ứng với địch ĐÃ NHÌN THẤY hoặc thành đang mất máu.
	var seen: Array = ctrl.visible_enemies_near(castle.global_position, float(Stats.BOT["threat_radius"]))
	var castle_hit := castle.hp < _last_castle_hp - 0.5
	_last_castle_hp = castle.hp
	if (not seen.is_empty() or castle_hit) and not _threatened:
		_threatened = true
		_scout = null # set_stance("hold") xoá lệnh trực tiếp của trinh sát
		ctrl.set_stance("hold")
	elif seen.is_empty() and not castle_hit:
		_threatened = false

	# 2) Phân bổ nông dân theo giai đoạn: đầu trận ưu tiên gỗ/đá để xây,
	# có doanh trại rồi thì dồn vàng để lên quân. M2 giai đoạn 2: nông dân
	# mới tốn THỊT nên phải có thợ săn — giữ 1-2 nông dân săn cừu/xẻ thịt
	# khi còn cần đẻ nông dân hoặc kho thịt dưới 50. Thợ săn tự chuyển bãi:
	# xác/mỏ cạn thì hệ thống tự tìm điểm gần nhất còn trữ lượng.
	var villagers: int = game.villager_count(player.pid)
	var counts0: Dictionary = game.building_counts(player.pid)
	if villagers > 0:
		var m := 0
		if villagers >= 2 and (villagers < int(Stats.BOT["villager_target"]) or int(player.resources["meat"]) < 50):
			m = 1
			if villagers >= 5 and int(player.resources["meat"]) < 50:
				m = 2
		var rest := villagers - m
		var fw := 0.5
		var fs := 0.3
		if int(counts0.get("barracks", 0)) > 0:
			fw = 0.3
			fs = 0.2
		var w := int(ceil(rest * fw))
		var s := int(ceil(rest * fs))
		var g := maxi(0, rest - w - s)
		if int(player.allocation["wood"]) != w or int(player.allocation["stone"]) != s or int(player.allocation["gold"]) != g or int(player.allocation["meat"]) != m:
			ctrl.set_villager_allocation(w, s, g, m)

	# 3) Xây dựng theo thứ tự: Nhà -> Doanh trại -> Tháp -> Nhà Kho -> Nhà 2.
	var counts := counts0
	var slots: Array = game.build_slots(player.pid)
	if int(counts.get("house", 0)) == 0:
		ctrl.place_building("house", slots[0])
	elif int(counts.get("barracks", 0)) == 0:
		ctrl.place_building("barracks", slots[1])
	elif int(counts.get("tower", 0)) == 0:
		ctrl.place_building("tower", slots[2])
	elif int(counts.get("storehouse", 0)) == 0:
		ctrl.place_building("storehouse", slots[4])
	elif int(counts.get("house", 0)) < 2:
		ctrl.place_building("house", slots[3])

	# 4) Huấn luyện: nông dân tới ngưỡng, rồi quân liên tục khi còn giới hạn.
	if villagers < int(Stats.BOT["villager_target"]) and castle.queue_count() < 2:
		ctrl.queue_training(castle, "pawn")
	var barracks: Building = game.active_barracks(player.pid)
	if barracks != null and barracks.queue_count() < 3:
		ctrl.queue_training(barracks, "archer")
	elif castle.queue_count() < 3:
		ctrl.queue_training(castle, "warrior")

	# 5) Trinh sát + tấn công (không làm khi đang bị uy hiếp).
	if _threatened:
		return
	var military: int = game.military_count(player.pid)
	var known := ctrl.known_enemy_castles()
	if known.is_empty():
		# Chưa lộ diện thành nào: cử 1 QUÂN trinh sát đi mở map về hướng góc
		# của 1 phe địch (hướng góc là luật map công khai; vị trí thành chỉ
		# khoá sau khi thấy). Đạo quân chính Ở NHÀ tích lũy tới ngưỡng mới
		# tổng tấn công — cách cũ order_move kéo CẢ đạo quân đi "trinh sát",
		# quân tự va thành địch dọc đường và phá thành mà không qua lệnh
		# tổng tấn công nào (trận kết thúc nhưng attacks_launched = 0).
		if _scout != null:
			if _scout_done():
				_scout = null
				_scout_wait = 5.0
			return
		if military >= 2 and player.stance == "hold" and _scout_wait <= 0.0:
			var u := _pick_scout()
			if u == null:
				return
			var others: Array = []
			for p in game.players:
				if p.pid != player.pid and p.alive:
					others.append(p.pid)
			if others.is_empty():
				return
			_scout_wait = 25.0
			_scout_elapsed = 0.0
			var dest_pid: int = others[_rng.randi_range(0, others.size() - 1)]
			var dest: Vector2 = game.public_castle_pos(dest_pid)
			# Dừng cách thành địch 140px: trong tầm nhìn (kiếm 165 /
			# cung 195) nên tới nơi là lộ diện thành.
			var dir := (castle.global_position - dest).normalized()
			_scout_dest = dest + dir * 140.0
			_scout = u
			ctrl.set_selection([u])
			ctrl.order_selected_move(_scout_dest, false)
		return
	if player.stance == "move":
		ctrl.set_stance("hold")
	if military >= attack_army_size and player.stance != "attack":
		var target_pid: int = known[_rng.randi_range(0, known.size() - 1)]
		ctrl.set_stance("attack", target_pid)
