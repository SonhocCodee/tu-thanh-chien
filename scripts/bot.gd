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
var _desperate_attack: bool = false # đợt công "tất tay" khi hết đường tăng quân (mục 5c)
var _scout_wait: float = 20.0
var _scout_elapsed: float = 0.0
var _scout: Unit = null # trinh sát = 1 quân đi riêng (lệnh trực tiếp), KHÔNG kéo cả đạo quân
var _scout_dest: Vector2 = Vector2.ZERO
var _farm_cooldown: float = 0.0 # giãn nhịp thử trồng ruộng (đặt trượt không được kẹt cả chuỗi xây)

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
	_farm_cooldown -= delta
	if _timer > 0.0:
		return
	_timer = float(Stats.BOT["decision_interval"])
	_decide()

## Lượt trinh sát hiện tại đã xong chưa: quân chết dọc đường, đã tới điểm
## hẹn, hoặc đi quá lâu (kẹt) — xong thì chờ một lúc rồi cử lượt mới.
## Còn quân nào đang trong hàng chờ luyện không (đang tăng quân thì
## chưa phải thế bế tắc — cổng cho nhánh tất tay 5c).
func _military_queued() -> bool:
	var castle := game.castles[player.pid] as Structure
	if castle != null:
		for it in castle.train_queue:
			if Stats.is_military(str(it["unit_type"])):
				return true
	var barr: Building = game.active_barracks(player.pid)
	if barr != null:
		for it in barr.train_queue:
			if Stats.is_military(str(it["unit_type"])):
				return true
	return false

## Cừu quanh nhà đã hết chưa — theo ĐÚNG tầm hiểu biết sương mù của bot:
## không còn con cừu SỐNG nào ĐÃ KHÁM PHÁ trong 420px quanh thành.
## (Cừu giữa map do HerdKeeper hồi liên tục nhưng ở xa >600px và thường
## chưa khám phá đầu trận; cừu quanh thành săn hết là hết.)
func _sheep_near_home_gone(castle: Castle) -> bool:
	for n in game.get_tree().get_nodes_in_group("sheep"):
		var s := n as Sheep
		if s.alive and castle.global_position.distance_to(s.global_position) <= 420.0 \
				and game.is_pos_explored_for(player.pid, s.global_position):
			return false
	return true

## Đặt ruộng vào 1 trong 2 ô trống hai bên thành. Tọa độ đã rà tay trên
## nền nhánh (cách mọi ô build_slots >= ~70px, cách node gỗ gần nhất
## ~100px+, trong tầm nhìn thành 212px < 265 nên chắc chắn đã khám phá);
## luật vị trí hợp nhất của main (can_place_building_at: + trên đất,
## không chồng cừu/node) vẫn là chốt chặn cuối — ô nào không hợp lệ thì
## place_building tự trả false và bot thử ô còn lại.
func _try_place_farm(castle: Castle) -> void:
	var c := castle.global_position
	var mx := 1.0 if c.x < game.WORLD.x * 0.5 else -1.0
	var my := 1.0 if c.y < game.WORLD.y * 0.5 else -1.0
	for off in [Vector2(mx * -140, my * -160), Vector2(mx * -140, my * 160)]:
		if ctrl.place_building("farm", c + off):
			return

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

	# 3) Xây dựng theo thứ tự: Nhà -> Doanh trại -> RUỘNG (chỉ khi cừu
	# quanh nhà đã cạn) -> Tháp -> 4 kho chuyên dụng (Gỗ -> Vàng -> Đá ->
	# Thịt, ô [6]-[9]) -> Nhà Lính -> Nhà 2.
	# NGOẠI LỆ ƯU TIÊN: đang kẹt GIỚI HẠN QUÂN mà chưa
	# có Nhà Lính và còn đủ tài nguyên -> xây Nhà Lính ngay để mở cap.
	var counts := counts0
	var slots: Array = game.build_slots(player.pid)
	var army_capped: bool = game.army_used(player.pid) >= game.army_cap(player.pid)
	if army_capped and int(counts.get("soldier_house", 0)) == 0 and player.can_afford(Stats.BUILDINGS["soldier_house"]["cost"]):
		ctrl.place_building("soldier_house", slots[5])
	elif int(counts.get("house", 0)) == 0:
		ctrl.place_building("house", slots[0])
	elif int(counts.get("barracks", 0)) == 0:
		ctrl.place_building("barracks", slots[1])
	elif int(counts.get("farm", 0)) == 0 and _farm_cooldown <= 0.0 \
			and _sheep_near_home_gone(castle) and player.can_afford(Stats.BUILDINGS["farm"]["cost"]):
		# RUỘNG: cừu quanh nhà đã săn cạn -> trồng ruộng làm nguồn thịt
		# chủ động (nông dân phân bổ "thịt" tự tìm tới node trong ruộng
		# như điểm thịt thường). Ruộng cạn tự sụp -> counts về 0 -> bot
		# trồng lại ở nhịp sau. Thử đặt xong nghỉ 1 nhịp dài để 1 lần đặt
		# trượt (cừu đứng chắn, node kề...) không kẹt cả chuỗi xây.
		_try_place_farm(castle)
		_farm_cooldown = 15.0
	elif int(counts.get("tower", 0)) == 0 and game.pop_used(player.pid) + 1 <= game.pop_cap(player.pid):
		# Tháp giữ thêm 1 ô dân cho cung thủ đứng bắn: hết ô thì BỎ QUA
		# tháp, xây nhà khác trước (Nhà Kho / Nhà Lính / Nhà 2 để nới dân
		# số) thay vì kẹt mãi ở bước này. Luật chặn thật vẫn ở Main.can_place.
		ctrl.place_building("tower", slots[2])
	elif int(counts.get("store_wood", 0)) == 0:
		ctrl.place_building("store_wood", slots[6])
	elif int(counts.get("store_gold", 0)) == 0:
		ctrl.place_building("store_gold", slots[7])
	elif int(counts.get("store_stone", 0)) == 0:
		ctrl.place_building("store_stone", slots[8])
	elif int(counts.get("store_meat", 0)) == 0:
		ctrl.place_building("store_meat", slots[9])
	elif int(counts.get("soldier_house", 0)) == 0:
		ctrl.place_building("soldier_house", slots[5])
	elif int(counts.get("house", 0)) < 2:
		ctrl.place_building("house", slots[3])

	# 4) Huấn luyện: nông dân tới ngưỡng, rồi quân liên tục khi còn giới hạn.
	if villagers < int(Stats.BOT["villager_target"]) and castle.queue_count() < 2:
		ctrl.queue_training(castle, "pawn")
	var barracks: Building = game.active_barracks(player.pid)
	if barracks != null and barracks.queue_count() < 3:
		# Trộn LÍNH GIÁO (tinh nhuệ, 2 ô) vào đạo quân: giữ tỉ lệ khoảng
		# 1 giáo / 4 quân; chỉ gọi luyện khi còn đủ 2 ô quân trống.
		# Bẫy cũ: bot đòi lancer (150 vàng) vô điều kiện mỗi tick — vàng
		# kẹt ở 70-149 (đủ mua cung/kiếm) mà nguồn vàng ĐÃ CẠN thì đứng
		# vĩnh viễn đúng 1 ô dưới ngưỡng tấn công (probe seed 11/33:
		# gold 80-110, army 7/12, queue rỗng hàng nghìn giây). Xử lý:
		# nguồn vàng còn sống -> giữ nguyên ý đồ, để dành vàng cho giáo;
		# nguồn vàng đã chết -> mua cung ngay bằng số vàng hiện có.
		var lancers: int = game.unit_type_count(player.pid, "lancer")
		var mil: int = game.military_count(player.pid)
		var want_lancer: bool = lancers * 4 < mil \
			and game.army_used(player.pid) + Stats.pop_cost("lancer") <= game.army_cap(player.pid)
		if want_lancer and not player.can_afford(Stats.TRAINING["lancer"]["cost"]) \
				and game.nearest_resource_node(player.pid, "gold", castle.global_position) != null:
			pass # đang để dành vàng cho lính giáo — thợ vàng còn đào được
		elif want_lancer and player.can_afford(Stats.TRAINING["lancer"]["cost"]):
			ctrl.queue_training(barracks, "lancer")
		else:
			ctrl.queue_training(barracks, "archer")
	elif castle.queue_count() < 3:
		ctrl.queue_training(castle, "warrior")

	# 5) Trinh sát + tấn công (không làm khi đang bị uy hiếp).
	if _threatened:
		return
	# 5a) HẠ THẾ: đợt tổng tấn công đã bị đánh tan (ô quân rơi xuống dưới
	# ngưỡng xuất kích) mà stance vẫn "attack" thì bot kẹt vĩnh viễn —
	# vài quân lẻ cắm ở đất địch (giữ phe địch ở trạng thái bị uy hiếp),
	# còn bản thân bot không bao giờ quay về tích lũy/trinh sát/hồi phục.
	# Hạ về giữ nhà để chu trình bình thường chạy lại; đủ ngưỡng thì
	# bước tấn công ở cuối _decide sẽ mở đợt mới.
	if player.stance != "attack":
		_desperate_attack = false
	if player.stance == "attack" and game.army_used(player.pid) < attack_army_size:
		# Đợt tất tay (5c) thì KHÔNG hạ thế giữa chừng: nó là đạo quân
		# cuối, quay về cũng không mọc thêm được — chỉ hạ khi mục tiêu
		# đã bị diệt hoặc SÓNG ĐÃ TAN (rơi xuống dưới mức xuất kích 3
		# quân: 1-2 quân lẻ không thể hạ thành có tháp, ghim stance
		# attack lúc đó chỉ chặn trinh sát/hồi phục — probe seed 11:
		# 2 cung ghim attack 1600s mài thành địch được 0,3 DPS).
		var desperate_alive: bool = _desperate_attack and player.target_pid >= 0 \
			and game.get_player(player.target_pid).alive \
			and game.military_count(player.pid) >= 3
		if not desperate_alive:
			_desperate_attack = false
			ctrl.set_stance("hold")
	var military: int = game.military_count(player.pid)
	var known := ctrl.known_enemy_castles()
	# 5c) TẤT TAY KHI HẾT ĐƯỜNG TĂNG QUÂN — dạng đứng trận còn lại sau
	# khi đã sửa các gốc khác (probe seed 33): vàng toàn map hữu hạn,
	# cả 4 phe cùng đốt vào đạo đầu + thay thế, mỏ giữa cạn mà không phe
	# nào chạm ngưỡng 8 ô -> mọi bot đứng chờ vĩnh viễn ở 6-7 ô với
	# 20-40 vàng. Khi bot CHỨNG MINH được mình không thể tăng quân thêm
	# nữa — (i) giữa map đã khám phá (mỏ lớn hoặc đã cạn hoặc không
	# còn), (ii) không còn mỏ vàng đã khám phá nào đào được, (iii)
	# không đủ tiền luyện quân rẻ nhất, (iv) không quân nào đang luyện
	# — thì đạo hiện có là đạo cuối: xuất kích với nó thay vì chờ một
	# ngưỡng không bao giờ tới. Ngưỡng thiết kế cho đợt thường KHÔNG
	# đổi; đây là nhánh riêng của thế bế tắc, có cổng quân tối thiểu 3.
	if player.stance == "hold" and not known.is_empty() \
			and game.army_used(player.pid) < attack_army_size \
			and military >= 3 \
			and not player.can_afford(Stats.TRAINING["archer"]["cost"]) \
			and game.nearest_resource_node(player.pid, "gold", castle.global_position) == null \
			and ctrl.is_point_explored(game.WORLD * 0.5) \
			and not _military_queued():
		# Tất tay thì đánh phe YẾU NHẤT đã lộ diện (ít quân nhất, hoà
		# thì thành yếu máu hơn): sóng cuối chỉ lật được kẻ yếu, và
		# cướp kho của nó là đường hồi vàng duy nhất còn lại.
		var desperate_target: int = -1
		var best_score: float = 1e18
		for kpid in known:
			var kp: int = int(kpid)
			var score: float = float(game.military_count(kp)) * 10000.0 \
				+ (game.castles[kp] as Structure).hp
			if score < best_score:
				best_score = score
				desperate_target = kp
		if desperate_target >= 0 and ctrl.set_stance("attack", desperate_target):
			_desperate_attack = true
			return
	# 5b) CHẾT ĐÓI VÀNG -> cử trinh sát ĐI TÌM MỎ (gốc của bug đứng trận
	# đã bắt bằng probe seed 33/44): mỏ vàng quanh thành có 300, bot xài
	# gần hết cho đạo quân đầu (~450-500 vàng = 6-7 ô) rồi đứng ở 20-50
	# vàng — không đủ luyện ô thứ 8 (ngưỡng tổng tấn công). Nông dân đào
	# vàng chỉ tới điểm ĐÃ KHÁM PHÁ nên đứng chờ quanh thành vô hạn, còn
	# trinh sát thường thì chỉ chạy khi CHƯA biết thành địch nào và chạy
	# dọc cạnh map nên không bao giờ lộ mỏ lớn giữa map. Điều kiện đói
	# vàng: còn phân bổ đào vàng + quân dưới ngưỡng + không còn mỏ vàng
	# nào đã khám phá còn trữ lượng (đúng cổng đang làm thợ vàng đứng).
	var gold_starved: bool = int(player.allocation["gold"]) > 0 \
		and game.army_used(player.pid) < attack_army_size \
		and game.nearest_resource_node(player.pid, "gold", castle.global_position) == null
	if gold_starved:
		if _scout != null:
			if _scout_done():
				_scout = null
				_scout_wait = 5.0
			return
		# Bình thường giữ tối thiểu 2 quân (1 ở nhà phòng thủ). Nhưng phe
		# đã bị quét gần sạch mà cũng không còn tiền luyện BẤT KỲ quân nào
		# thì giữ quân cuối ở nhà cũng vô ích — cử nó đi tìm mỏ là đường
		# sống duy nhất, không thì phe đó đóng băng vĩnh viễn.
		var can_afford_any: bool = player.can_afford(Stats.TRAINING["archer"]["cost"]) \
			or player.can_afford(Stats.TRAINING["warrior"]["cost"])
		var min_military: int = 2 if can_afford_any else 1
		if military >= min_military and player.stance == "hold" and _scout_wait <= 0.0:
			var su := _pick_scout()
			if su != null:
				_scout_wait = 25.0
				_scout_elapsed = 0.0
				# Điểm đến: GIỮA MAP — vùng tài nguyên lớn là luật map
				# công khai (như hướng góc thành địch), lệch ngẫu nhiên nhẹ
				# để các phe không dẫm đúng một điểm.
				_scout_dest = Vector2(game.WORLD.x, game.WORLD.y) * 0.5 \
					+ Vector2(_rng.randf_range(-120.0, 120.0), _rng.randf_range(-120.0, 120.0))
				_scout = su
				ctrl.set_selection([su])
				ctrl.order_selected_move(_scout_dest, false)
		return
	# Còn thành địch CHƯA lộ diện thì tiếp tục cử trinh sát tìm — trước
	# đây bot chỉ scout khi chưa biết BẤT KỲ thành nào, lộ 1 thành là
	# ngừng mở map vĩnh viễn: các thành còn lại (kể cả phe yếu nhất,
	# mục tiêu đúng của sóng quyết định) không bao giờ vào danh sách
	# biết, bot cứ đâm sóng vào thành có phòng thủ đã biết (probe
	# seed 11: P1 xuất kích 8 ô đánh P2 trong khi thành P0 không quân
	# phòng thủ mà P1 chưa từng lộ diện). Chỉ scout khi chưa sẵn sàng
	# xuất kích — đủ ngưỡng thì ưu tiên đánh mục tiêu đã biết.
	var unknown: Array = []
	for p in game.players:
		if p.pid != player.pid and p.alive and not known.has(p.pid):
			unknown.append(p.pid)
	if not unknown.is_empty() and (known.is_empty() or game.army_used(player.pid) < attack_army_size):
		# Cử 1 QUÂN trinh sát đi mở map về hướng góc của 1 phe địch chưa
		# biết (hướng góc là luật map công khai; vị trí thành chỉ khoá
		# sau khi thấy). Đạo quân chính Ở NHÀ tích lũy tới ngưỡng mới
		# tổng tấn công — cách cũ order_move kéo CẢ đạo quân đi "trinh
		# sát", quân tự va thành địch dọc đường và phá thành mà không
		# qua lệnh tổng tấn công nào (trận kết thúc nhưng
		# attacks_launched = 0).
		if _scout != null:
			if _scout_done():
				_scout = null
				_scout_wait = 5.0
			return
		if military >= 2 and player.stance == "hold" and _scout_wait <= 0.0:
			var u := _pick_scout()
			if u == null:
				return
			var others: Array = unknown
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
	# Ngưỡng tổng tấn công tính theo Ô QUÂN (army_used), KHÔNG theo đầu
	# người: lính tinh nhuệ chiếm 2 ô nên một đạo quân đầy ô có thể chỉ có
	# 6-7 đầu — đếm đầu thì không bao giờ đủ 8 để xuất kích, mọi phe cùng
	# kẹt ở cap và trận không bao giờ kết thúc (đã bắt gặp ở test m2f).
	# Mục tiêu: phe YẾU NHẤT đã lộ diện (ít quân nhất, hoà thì ít máu
	# thành hơn) — chọn ngẫu nhiên như trước làm sóng quyết định liên
	# tục đâm vào thành phòng thủ mạnh nhất, sóng chết mà không hạ được
	# ai, cả 4 phe cùng đốt hết vàng hữu hạn rồi đóng băng (probe
	# sweep: ~50% số trận thuần bot không kết thúc).
	if game.army_used(player.pid) >= attack_army_size and player.stance != "attack":
		var target_pid: int = -1
		var best_score: float = 1e18
		for kpid in known:
			var kp: int = int(kpid)
			var score: float = float(game.military_count(kp)) * 10000.0 \
				+ (game.castles[kp] as Structure).hp
			if score < best_score:
				best_score = score
				target_pid = kp
		if target_pid >= 0:
			ctrl.set_stance("attack", target_pid)
