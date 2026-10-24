class_name Villager
extends Node2D

## Nông dân (Pawn): theo phân bổ của chủ, tự chạy tới điểm tài nguyên GẦN NHẤT
## thuộc loại được phân VÀ đã được phe mình khám phá; khai thác (có hoạt ảnh +
## thời gian), chất đầy tải thì mang về thành chính, cộng tài nguyên, lặp lại.
## Hết phân bổ -> chờ gần thành, nhận phân bổ mới thì đi tiếp.

const FRAME := 192.0

var owner_pid: int = -1
var color_key: String = "blue"
var st: Dictionary = {}
var hp: float = 0.0
var max_hp: float = 0.0
var main_ref: Node = null
var idle_offset: Vector2 = Vector2.ZERO

# AI bỏ chạy (Stats.VILLAGER_AI): bị đánh hoặc quân địch áp sát -> chạy về
# thành một lúc rồi QUAY LẠI việc cũ (kể cả lệnh trực tiếp — không huỷ lệnh).
var _flee_left: float = 0.0
var _resume_state: String = ""
var _threat_left: float = 0.0

var assigned: String = "" # "" | "wood" | "stone" | "gold"
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

var _state: String = "idle" # idle | to_node | harvest | return | move_to | hold
var _node: Node2D = null
var _harvest_left: float = 0.0
var _anim: AnimatedSprite2D
var _cur_anim: String = ""

func setup(p_owner: int, p_color: String, p_main: Node, p_idle_offset: Vector2) -> void:
	owner_pid = p_owner
	color_key = p_color
	st = Stats.unit_stats("pawn")
	hp = st["hp"]
	max_hp = hp
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
	_add_anim(sf, "axe", base + "pawn_axe.png", 6, 10.0)
	_add_anim(sf, "pick", base + "pawn_pick.png", 6, 10.0)
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

func is_fleeing() -> bool:
	return _state == "flee"

## Bị đánh: trừ máu (kẹp tối thiểu 1 — mốc này nông dân chưa chết, chỉ tan rã
## khi chủ bị loại) và BỎ CHẠY về thành. Điểm móc cho mốc sau khi quân địch
## được phép đánh nông dân.
func take_damage(amount: float, _attacker_pid: int) -> void:
	hp = maxf(1.0, hp - amount)
	queue_redraw()
	_start_flee()

func _start_flee() -> void:
	if _state == "flee":
		_flee_left = maxf(_flee_left, float(Stats.VILLAGER_AI["flee_time"]))
		return
	_resume_state = _state
	_state = "flee"
	_flee_left = float(Stats.VILLAGER_AI["flee_time"])

func _end_flee() -> void:
	_flee_left = 0.0
	if carrying > 0:
		_state = "return"
	elif _resume_state == "move_to" or _resume_state == "hold":
		_state = _resume_state # quay lại đúng điểm người chơi đã lệnh đứng
	elif assigned != "":
		_state = "to_node"
		if _node != null and is_instance_valid(_node) and _node is ResourceNode \
				and (_node as ResourceNode).is_depleted():
			_node = null
	else:
		_state = "idle"

func _enemy_unit_near(range_px: float) -> bool:
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u.owner_pid == owner_pid or not u.is_alive():
			continue
		if global_position.distance_to(u.global_position) <= range_px:
			return true
	return false

func is_direct() -> bool:
	return direct

func set_direct(node: Node2D) -> void:
	direct = true
	direct_node = node
	direct_res = (node as ResourceNode).res_type
	holding = false
	assigned = direct_res
	_node = node
	if carrying > 0:
		_state = "return"
	else:
		_state = "to_node"

func set_move_point(point: Vector2) -> void:
	direct = false
	direct_node = null
	direct_res = ""
	holding = false
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

func _process(delta: float) -> void:
	if main_ref == null or main_ref.match_over:
		_play("idle")
		return
	var castle: Castle = main_ref.castles[owner_pid]
	if castle == null:
		return
	# Quét nguy hiểm theo nhịp thưa (lệch pha từng nông dân): quân địch áp sát
	# là bỏ chạy, kể cả chưa bị đánh.
	_threat_left -= delta
	if _threat_left <= 0.0:
		_threat_left = float(Stats.VILLAGER_AI["threat_check_interval"]) \
			* (0.8 + 0.1 * float(get_instance_id() % 5))
		if _state != "flee" and _enemy_unit_near(float(Stats.VILLAGER_AI["flee_trigger_range"])):
			_start_flee()
	if _state == "flee":
		_flee_left -= delta
		var d_home := global_position.distance_to(castle.global_position)
		# Trả hàng luôn nếu đã về tới kho (thành) trong lúc chạy.
		if d_home <= 58.0 and carrying > 0:
			main_ref.get_player(owner_pid).add_resource(carrying_type, carrying)
			carrying = 0
			carrying_type = ""
		var safe := d_home <= float(Stats.VILLAGER_AI["flee_safe_distance"])
		if (_flee_left <= 0.0 and safe) or _flee_left <= -float(Stats.VILLAGER_AI["flee_max_time"]):
			_end_flee()
		elif d_home > 34.0:
			var anim := "run"
			if carrying_type == "wood":
				anim = "run_wood"
			elif carrying_type == "gold" or carrying_type == "stone":
				anim = "run_gold"
			_move_toward(castle.global_position, delta, anim)
		else:
			_play("idle")
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
			if assigned == "":
				_state = "idle"
			else:
				if direct and _node == null and direct_node != null and is_instance_valid(direct_node):
					_node = direct_node
				# Điểm đã CẠN (cây thành gốc, mỏ sập...) thì coi như điểm đã mất:
				# direct -> hết lệnh về phân bổ; phân bổ -> bỏ điểm, tìm điểm khác.
				if _node != null and is_instance_valid(_node) and _node is ResourceNode \
						and (_node as ResourceNode).is_depleted():
					if direct:
						direct = false
						direct_node = null
						direct_res = ""
						assigned = ""
						_state = "idle"
						if main_ref != null:
							main_ref.rebalance_player(owner_pid)
						return
					_node = null
				if _node == null or not is_instance_valid(_node):
					if direct:
						# Mỏ trực tiếp biến mất -> hết lệnh, quay lại phân bổ.
						direct = false
						direct_node = null
						direct_res = ""
						assigned = ""
						_state = "idle"
						if main_ref != null:
							main_ref.rebalance_player(owner_pid)
						return
					_node = main_ref.nearest_resource_node(owner_pid, assigned, global_position)
				if _node == null:
					# Chưa khám phá thấy điểm tài nguyên loại này -> chờ gần thành.
					var spot2: Vector2 = castle.global_position + idle_offset
					if global_position.distance_to(spot2) > 10.0:
						_move_toward(spot2, delta, "run")
					else:
						_play("idle")
				elif global_position.distance_to(_node.global_position) <= 30.0:
					_state = "harvest"
					_harvest_left = float(st["harvest_time"])
					_face(_node.global_position)
				else:
					_move_toward(_node.global_position, delta, "run")
		"harvest":
			_play("axe" if assigned == "wood" else "pick")
			_harvest_left -= delta
			if _harvest_left <= 0.0:
				# MỐI NỐI TÍCH HỢP (giai đoạn 2): trừ trữ lượng thật của điểm qua
				# API take(); điểm cạn ngay trước mặt -> bỏ điểm, tìm điểm khác.
				var got := int(st["carry_capacity"])
				if _node != null and is_instance_valid(_node) and _node is ResourceNode:
					got = (_node as ResourceNode).take(got)
				if got <= 0:
					_node = null
					if direct:
						direct = false
						direct_node = null
						direct_res = ""
						assigned = ""
						_state = "idle"
						if main_ref != null:
							main_ref.rebalance_player(owner_pid)
					else:
						_state = "to_node" if assigned != "" else "idle"
				else:
					carrying = got
					carrying_type = assigned
					_state = "return"
		"return":
			if global_position.distance_to(castle.global_position) <= 58.0:
				if carrying > 0:
					main_ref.get_player(owner_pid).add_resource(carrying_type, carrying)
					carrying = 0
					carrying_type = ""
				_state = "to_node" if assigned != "" else "idle"
				if not direct:
					_node = null
			else:
				var anim := "run"
				if carrying_type == "wood":
					anim = "run_wood"
				elif carrying_type == "gold" or carrying_type == "stone":
					anim = "run_gold"
				_move_toward(castle.global_position, delta, anim)

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
	# Thanh máu nhỏ — chỉ hiện khi đã mất máu (bị đánh).
	if max_hp > 0.0 and hp < max_hp:
		var w := 30.0
		var pos := Vector2(-w / 2.0, -52.0)
		draw_rect(Rect2(pos, Vector2(w, 4)), Color(0, 0, 0, 0.65))
		var frac := clampf(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(pos, Vector2(w * frac, 4)), Color(0.3, 0.95, 0.35))
