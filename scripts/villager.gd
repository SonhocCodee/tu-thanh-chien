class_name Villager
extends Node2D

## Nông dân (Pawn): theo phân bổ của chủ, tự chạy tới điểm tài nguyên GẦN NHẤT
## thuộc loại được phân VÀ đã được phe mình khám phá; khai thác (có hoạt ảnh +
## thời gian), chất đầy tải thì VÁC VỀ KHO (thành chính hoặc Nhà Kho gần nhất),
## TỚI KHO MỚI ĐƯỢC CỘNG tài nguyên, lặp lại.
## M2 giai đoạn 2: tài nguyên HỮU HẠN (khai thác trừ trữ lượng của điểm);
## phân bổ "meat" = đi SĂN CỪU (dao) / xẻ xác thịt. Hết phân bổ -> chờ gần
## thành, nhận phân bổ mới thì đi tiếp.

const FRAME := 192.0

var owner_pid: int = -1
var color_key: String = "blue"
var st: Dictionary = {}
var hp: float = 0.0
var main_ref: Node = null
var idle_offset: Vector2 = Vector2.ZERO

var assigned: String = "" # "" | "wood" | "stone" | "gold" | "meat"
var carrying_type: String = ""
var carrying: int = 0

# M2: chọn quân + lệnh trực tiếp. direct = đang farm đúng mỏ được click phải
# (ưu tiên hơn phân bổ; hết mỏ thì quay lại phân bổ). holding = đã đi tới
# điểm click phải và đứng chờ ở đó.
var selected: bool = false
var direct: bool = false
var direct_node: Node2D = null
var direct_res: String = ""
var move_point: Vector2 = Vector2.ZERO
var holding: bool = false

var _state: String = "idle" # idle | to_node | to_sheep | hunt | harvest | return | move_to | hold | to_build | build
var _node: Node2D = null
var _sheep: Sheep = null
var _dropoff: Node2D = null # kho đang hướng về (thành chính / Nhà Kho) — test đọc được
var _harvest_left: float = 0.0

# --- Nhiệm vụ xây dựng (hệ thống xây mới): nông dân được cử TỚI TẬN công
# trường đóng búa; tiến độ công trình chỉ chạy theo số thợ có mặt tại chỗ.
# Việc cũ (phân bổ / lệnh trực tiếp / điểm giữ) được LƯU LẠI khi nhận nhiệm
# vụ và khôi phục nguyên vẹn khi xây xong / công trình bị phá.
var build_target: Building = null
var _build_spot: Vector2 = Vector2.ZERO
var _saved_assigned: String = ""
var _saved_direct: bool = false
var _saved_direct_node: Node2D = null
var _saved_direct_sheep: Sheep = null
var _saved_direct_res: String = ""
var _saved_holding: bool = false
var _saved_move_point: Vector2 = Vector2.ZERO
var _anim: AnimatedSprite2D
var _cur_anim: String = ""

func setup(p_owner: int, p_color: String, p_main: Node, p_idle_offset: Vector2) -> void:
	owner_pid = p_owner
	color_key = p_color
	st = Stats.unit_stats("pawn")
	hp = st["hp"]
	main_ref = p_main
	idle_offset = p_idle_offset

func _ready() -> void:
	add_to_group("villagers")
	_anim = AnimatedSprite2D.new()
	_anim.scale = Vector2(0.5, 0.5)
	_anim.position = Vector2(0, -20)
	_anim.sprite_frames = _build_frames()
	add_child(_anim)
	_play("idle")

func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var base := "res://assets/units/%s/" % color_key
	_add_anim(sf, "idle", base + "pawn_idle.png", 8, 8.0)
	_add_anim(sf, "run", base + "pawn_run.png", 6, 10.0)
	_add_anim(sf, "run_wood", base + "pawn_run_wood.png", 6, 10.0)
	_add_anim(sf, "run_gold", base + "pawn_run_gold.png", 6, 10.0)
	_add_anim(sf, "run_meat", base + "pawn_run_meat.png", 6, 10.0)
	_add_anim(sf, "axe", base + "pawn_axe.png", 6, 10.0)
	_add_anim(sf, "pick", base + "pawn_pick.png", 6, 10.0)
	_add_anim(sf, "knife", base + "pawn_knife.png", 4, 10.0)
	_add_anim(sf, "hammer", base + "pawn_hammer.png", 3, 10.0)
	_add_anim(sf, "run_hammer", base + "pawn_run_hammer.png", 6, 10.0)
	return sf

func _add_anim(sf: SpriteFrames, anim_name: String, tex_path: String, frames: int, fps: float) -> void:
	var sheet := load(tex_path) as Texture2D
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, true)
	for i in frames:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * FRAME, 0, FRAME, FRAME)
		sf.add_frame(anim_name, at)

func _play(anim_name: String) -> void:
	if _cur_anim != anim_name:
		_cur_anim = anim_name
		_anim.play(anim_name)

func is_alive() -> bool:
	return true # M1: nông dân chưa bị đánh (chỉ tan rã khi chủ bị loại)

func is_direct() -> bool:
	return direct

# ===================== NHIỆM VỤ XÂY DỰNG =====================

func is_building() -> bool:
	return build_target != null

## Đang đứng đóng búa TẠI công trường này (điều kiện để công trình tiến độ).
func is_building_at(b: Building) -> bool:
	return build_target == b and _state == "build"

## Nhận nhiệm vụ xây 1 công trình: lưu việc cũ rồi đi tới công trường.
## Đang xây dở công trình khác mà bị điều sang chỗ mới thì GIỮ NGUYÊN việc
## gốc đã lưu (không ghi đè bằng trạng thái xây hiện tại).
func assign_builder(b: Building) -> void:
	if b == null:
		return
	if build_target == null:
		_saved_assigned = assigned
		_saved_direct = direct
		_saved_direct_node = direct_node
		_saved_direct_sheep = _sheep if direct else null
		_saved_direct_res = direct_res
		_saved_holding = holding
		_saved_move_point = move_point
	build_target = b
	# Mỗi thợ đứng 1 góc quanh công trình (theo instance id cho khỏi chồng).
	var ang := float(absi(get_instance_id()) % 8) * TAU / 8.0
	_build_spot = b.global_position + Vector2(cos(ang), sin(ang)) * (b.radius + 16.0)
	_state = "to_build"

## Huỷ nhiệm vụ xây KHÔNG khôi phục (lệnh mới của người chơi thắng nhiệm vụ).
func _abandon_build() -> void:
	build_target = null
	_saved_assigned = ""
	_saved_direct = false
	_saved_direct_node = null
	_saved_direct_sheep = null
	_saved_direct_res = ""
	_saved_holding = false

## Kết thúc nhiệm vụ xây (xây xong / công trình bị phá / mất thợ thay):
## quay lại ĐÚNG việc cũ đã lưu — lệnh trực tiếp còn hiệu lực thì làm tiếp
## lệnh đó, không thì về phân bổ cũ; việc cũ là điểm giữ thì đi lại về đó.
func _finish_build_duty() -> void:
	build_target = null
	var sd := _saved_direct
	var snode := _saved_direct_node
	var ssheep := _saved_direct_sheep
	var sassigned := _saved_assigned
	var sholding := _saved_holding
	var smove := _saved_move_point
	_abandon_build()
	if sd:
		if ssheep != null and is_instance_valid(ssheep) and ssheep.alive:
			set_direct_sheep(ssheep)
			return
		if snode != null and is_instance_valid(snode) and not (snode as ResourceNode).is_depleted():
			set_direct(snode)
			return
		# Mục tiêu trực tiếp đã mất -> rơi về phân bổ hiện hành.
		direct = false
		direct_node = null
		direct_res = ""
		assigned = ""
		_state = "idle"
		if main_ref != null:
			main_ref.rebalance_player(owner_pid)
		return
	if sholding:
		assigned = sassigned
		move_point = smove
		_state = "move_to"
		if main_ref != null:
			main_ref.rebalance_player(owner_pid)
		return
	assigned = sassigned
	if carrying > 0:
		_state = "return"
	elif assigned != "":
		_state = "to_node"
		_node = null
	else:
		_state = "idle"
	# QUAN TRỌNG: trong lúc thợ đi xây, rebalance BỎ QUA thợ (bận) nên quota
	# phân bổ có thể đã lệch (thợ khác lãnh việc đầu danh sách, quota cuối
	# không ai nhận) và chủ phe đổi phân bổ thì thợ cũng không biết. Xây xong
	# phải rebalance lại 1 lần cho TOÀN ĐỘI hội tụ về phân bổ HIỆN HÀNH —
	# nếu không, thợ quay về việc cũ đã lỗi thời vĩnh viễn (bot kẹt kinh tế).
	if main_ref != null:
		main_ref.rebalance_player(owner_pid)

func _step_to_build(delta: float) -> void:
	if build_target == null or not is_instance_valid(build_target) or not build_target.is_alive() or build_target.constructed:
		_finish_build_duty()
		return
	if global_position.distance_to(_build_spot) <= 12.0:
		_state = "build"
	else:
		_move_toward(_build_spot, delta, "run_hammer")

func _step_build(_delta: float) -> void:
	if build_target == null or not is_instance_valid(build_target) or not build_target.is_alive() or build_target.constructed:
		_finish_build_duty()
		return
	if global_position.distance_to(_build_spot) > 24.0:
		_state = "to_build"
		return
	_play("hammer")
	_face(build_target.global_position)

func carry_anim() -> String:
	# Đang vác gì thì hiện đúng hoạt ảnh vác loại đó.
	match carrying_type:
		"wood":
			return "run_wood"
		"gold", "stone":
			return "run_gold"
		"meat":
			return "run_meat"
	return "run"

func harvest_anim() -> String:
	# Gỗ = rìu, đá/vàng = cuốc chim ĐÀO, thịt = dao xẻ.
	match assigned:
		"wood":
			return "axe"
		"meat":
			return "knife"
	return "pick"

func set_direct(node: Node2D) -> void:
	if build_target != null:
		_abandon_build() # lệnh trực tiếp mới thắng nhiệm vụ xây
	holding = false
	if node is Sheep:
		set_direct_sheep(node as Sheep)
		return
	direct = true
	direct_node = node
	direct_res = (node as ResourceNode).res_type
	_sheep = null
	assigned = direct_res
	_node = node
	if carrying > 0:
		_state = "return"
	else:
		_state = "to_node"

func set_direct_sheep(sheep: Sheep) -> void:
	if build_target != null:
		_abandon_build() # lệnh trực tiếp mới thắng nhiệm vụ xây
	direct = true
	direct_node = null
	direct_res = "meat"
	holding = false
	assigned = "meat"
	_sheep = sheep
	_node = null
	if carrying > 0:
		_state = "return"
	else:
		_state = "to_sheep"

func set_move_point(point: Vector2) -> void:
	if build_target != null:
		_abandon_build() # lệnh di chuyển mới thắng nhiệm vụ xây
	direct = false
	direct_node = null
	direct_res = ""
	holding = false
	_sheep = null
	move_point = point
	_state = "move_to"
	_node = null

func set_assignment(res_key: String) -> void:
	# Phân bổ (qua _rebalance) không bao giờ gọi lên nông dân đang direct:
	# _rebalance đã bỏ qua direct. Tới đây nghĩa là lệnh direct đã hết hoặc
	# bị thay, nên dọn trạng thái lệnh trực tiếp/di chuyển trước.
	direct = false
	direct_node = null
	direct_res = ""
	holding = false
	_sheep = null
	if assigned == res_key and _state != "hold" and _state != "move_to":
		return
	assigned = res_key
	if carrying > 0:
		_state = "return"
	elif assigned == "":
		_state = "idle"
		_node = null
	else:
		_state = "to_node"
		_node = null

func _end_direct() -> void:
	# Mục tiêu trực tiếp biến mất/cạn -> hết lệnh, quay lại phân bổ.
	direct = false
	direct_node = null
	direct_res = ""
	_sheep = null
	assigned = ""
	_state = "idle"
	_node = null
	if main_ref != null:
		main_ref.rebalance_player(owner_pid)

func _node_gone(n: Variant) -> bool:
	# Tham số KHÔNG typed: node đã freed truyền vào tham số typed Node2D sẽ
	# gây lỗi runtime trước khi thân hàm chạy (dân kẹt vĩnh viễn).
	if n == null or not is_instance_valid(n):
		return true
	return (n as ResourceNode).is_depleted()

func _process(delta: float) -> void:
	if main_ref == null or main_ref.match_over:
		_play("idle")
		return
	var castle: Castle = main_ref.castles[owner_pid]
	if castle == null:
		return
	match _state:
		"idle":
			if assigned != "" and carrying == 0:
				_state = "to_node"
				if not direct:
					_node = null
			else:
				var spot: Vector2 = castle.global_position + idle_offset
				if global_position.distance_to(spot) > 10.0:
					_move_toward(spot, delta, "run")
				else:
					_play("idle")
		"move_to":
			if global_position.distance_to(move_point) > 10.0:
				_move_toward(move_point, delta, "run")
			else:
				_state = "hold"
				holding = true
				_play("idle")
		"hold":
			_play("idle")
		"to_node":
			_step_to_node(delta, castle)
		"to_sheep":
			_step_to_sheep(delta)
		"hunt":
			_step_hunt(delta)
		"harvest":
			_step_harvest(delta)
		"return":
			_step_return(delta, castle)
		"to_build":
			_step_to_build(delta)
		"build":
			_step_build(delta)

func _step_to_node(delta: float, castle: Castle) -> void:
	if assigned == "":
		_state = "idle"
		return
	# Mục tiêu trực tiếp: node tài nguyên hoặc cừu.
	if direct:
		if direct_node != null:
			if _node_gone(direct_node):
				_end_direct()
				return
			_node = direct_node
		elif _sheep != null and is_instance_valid(_sheep) and _sheep.alive:
			_state = "to_sheep"
			return
		elif direct_res == "meat":
			# Cừu trực tiếp đã chết (thợ khác giết) -> xẻ xác của nó nếu còn.
			_node = main_ref.nearest_resource_node(owner_pid, "meat", global_position)
			if _node == null:
				_end_direct()
				return
		else:
			_end_direct()
			return
	# Hết mục tiêu hiện tại -> tìm điểm gần nhất còn trữ lượng.
	if _node_gone(_node):
		_node = main_ref.nearest_resource_node(owner_pid, assigned, global_position)
	# Phân bổ thịt mà không có xác nào -> đi săn cừu còn sống đã khám phá.
	if _node == null and assigned == "meat":
		_sheep = main_ref.nearest_sheep(owner_pid, global_position)
		if _sheep != null:
			_state = "to_sheep"
			return
	if _node == null:
		# Chưa khám phá thấy điểm tài nguyên loại này -> chờ gần thành.
		var spot: Vector2 = castle.global_position + idle_offset
		if global_position.distance_to(spot) > 10.0:
			_move_toward(spot, delta, "run")
		else:
			_play("idle")
	elif global_position.distance_to(_node.global_position) <= 34.0:
		_state = "harvest"
		_harvest_left = float(st["harvest_time"])
		_face(_node.global_position)
	else:
		_move_toward(_node.global_position, delta, "run")

func _step_to_sheep(delta: float) -> void:
	if _sheep == null or not is_instance_valid(_sheep) or not _sheep.alive:
		_sheep = null
		_node = null
		_state = "to_node"
		return
	if global_position.distance_to(_sheep.global_position) <= 30.0:
		_state = "hunt"
		_harvest_left = float(st["harvest_time"])
		_face(_sheep.global_position)
	else:
		_move_toward(_sheep.global_position, delta, "run")

func _step_hunt(delta: float) -> void:
	if _sheep == null or not is_instance_valid(_sheep) or not _sheep.alive:
		_sheep = null
		_node = null
		_state = "to_node"
		return
	if global_position.distance_to(_sheep.global_position) > 42.0:
		_state = "to_sheep" # cừu chạy xa giữa lúc săn -> đuổi tiếp
		return
	_play("knife")
	_face(_sheep.global_position)
	_harvest_left -= delta
	if _harvest_left <= 0.0:
		# Giết cừu -> xác thịt xuất hiện tại chỗ, chuyển sang xẻ thịt ở xác.
		var carcass: ResourceNode = main_ref.kill_sheep(_sheep)
		_sheep = null
		if carcass != null:
			_node = carcass
			_state = "harvest"
			_harvest_left = float(st["harvest_time"])
			if direct:
				direct_node = carcass
		else:
			_state = "to_node"
			_node = null

func _step_harvest(delta: float) -> void:
	if _node_gone(_node):
		_node = null
		_state = "to_node"
		return
	_play(harvest_anim())
	_face(_node.global_position)
	_harvest_left -= delta
	if _harvest_left <= 0.0:
		var take: int = (_node as ResourceNode).take_harvest(int(st["carry_capacity"]))
		if take > 0:
			carrying = take
			carrying_type = (_node as ResourceNode).res_type
			_dropoff = null
			_state = "return"
		else:
			_node = null
			_state = "to_node"

func _step_return(delta: float, castle: Castle) -> void:
	# Kho đích = thành chính hoặc Nhà Kho (đã xây xong, còn đứng) GẦN NHẤT.
	# Kho bị phá giữa đường -> tính lại kho khác.
	if _dropoff == null or not is_instance_valid(_dropoff) or (_dropoff is Building and not (_dropoff as Building).is_valid_dropoff()):
		_dropoff = main_ref.nearest_dropoff(owner_pid, global_position)
	if _dropoff == null:
		_dropoff = castle
	var reach := 58.0 if _dropoff is Castle else 52.0
	if global_position.distance_to(_dropoff.global_position) <= reach:
		# CHỈ khi về TỚI KHO mới cộng tài nguyên.
		if carrying > 0:
			main_ref.get_player(owner_pid).add_resource(carrying_type, carrying)
			carrying = 0
			carrying_type = ""
		_state = "to_node" if assigned != "" else "idle"
		if not direct:
			_node = null
	else:
		_move_toward(_dropoff.global_position, delta, carry_anim())

func _move_toward(to: Vector2, delta: float, anim_name: String) -> void:
	var dir := to - global_position
	if dir.length() < 2.0:
		return
	dir = dir.normalized()
	global_position += dir * float(st["speed"]) * delta
	_face(to)
	_play(anim_name)

func _face(to: Vector2) -> void:
	if _anim == null:
		return
	var dx := to.x - global_position.x
	if absf(dx) > 2.0:
		_anim.flip_h = dx < 0.0

func _draw() -> void:
	if selected:
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, Color(0.3, 1, 0.4, 0.95), 3.0)
