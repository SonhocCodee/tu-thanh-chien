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
	if _timer > 0.0:
		return
	_timer = float(Stats.BOT["decision_interval"])
	_decide()

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
		ctrl.set_stance("hold")
	elif seen.is_empty() and not castle_hit:
		_threatened = false

	# 2) Phân bổ nông dân theo giai đoạn: đầu trận ưu tiên gỗ/đá để xây,
	# có doanh trại rồi thì dồn vàng để lên quân.
	var villagers: int = game.villager_count(player.pid)
	var counts0: Dictionary = game.building_counts(player.pid)
	if villagers > 0:
		var fw := 0.5
		var fs := 0.3
		if int(counts0.get("barracks", 0)) > 0:
			fw = 0.3
			fs = 0.2
		var w := int(ceil(villagers * fw))
		var s := int(ceil(villagers * fs))
		var g := maxi(0, villagers - w - s)
		if int(player.allocation["wood"]) != w or int(player.allocation["stone"]) != s or int(player.allocation["gold"]) != g:
			ctrl.set_villager_allocation(w, s, g)

	# 3) Xây dựng theo thứ tự: Nhà -> Doanh trại -> Tháp -> Nhà 2.
	var counts := counts0
	var slots: Array = game.build_slots(player.pid)
	if int(counts.get("house", 0)) == 0:
		ctrl.place_building("house", slots[0])
	elif int(counts.get("barracks", 0)) == 0:
		ctrl.place_building("barracks", slots[1])
	elif int(counts.get("tower", 0)) == 0:
		ctrl.place_building("tower", slots[2])
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
		# Chưa lộ diện thành nào: cử quân đi mở map về hướng góc của 1 phe địch
		# (hướng góc là luật map công khai; vị trí thành chỉ khoá sau khi thấy).
		if military >= 2 and player.stance == "hold" and _scout_wait <= 0.0:
			_scout_wait = 25.0
			var others: Array = []
			for p in game.players:
				if p.pid != player.pid and p.alive:
					others.append(p.pid)
			if not others.is_empty():
				var dest_pid: int = others[_rng.randi_range(0, others.size() - 1)]
				var dest: Vector2 = game.public_castle_pos(dest_pid)
				var mid := castle.global_position.lerp(dest, 0.82)
				ctrl.order_move(mid)
		return
	if player.stance == "move":
		ctrl.set_stance("hold")
	if military >= attack_army_size and player.stance != "attack":
		var target_pid: int = known[_rng.randi_range(0, known.size() - 1)]
		ctrl.set_stance("attack", target_pid)
