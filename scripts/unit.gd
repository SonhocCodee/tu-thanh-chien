class_name Unit
extends Node2D

## Quân lính (Warrior/Archer): hành vi theo THÁI ĐỘ của chủ (PlayerState):
## - hold: quanh quẩn điểm tập kết trước thành, đánh chặn địch vào vùng giữ nhà.
## - attack: đi thẳng tới thành địch mục tiêu, dọc đường tự đánh mọi địch/công trình cản đường.
## - move: đi tới điểm trinh sát đã lệnh, đánh địch chạm trán dọc đường.

signal died(unit: Unit, killer_pid: int)

const FRAME := 192.0

var owner_pid: int = -1
var unit_type: String = "warrior"
var color_key: String = "blue"
var st: Dictionary = {}
var hp: float = 0.0
var max_hp: float = 0.0
var main_ref: Node = null
var slot_offset: Vector2 = Vector2.ZERO

var _atk_timer: float = 0.0
var _dead: bool = false
var _last_attacker: int = -1
var _anim: AnimatedSprite2D
var _cur_anim: String = ""

# M2: chọn quân + lệnh trực tiếp (ưu tiên hơn thái độ chung, tới khi xong).
var selected: bool = false
var direct_mode: String = "" # "" | "move" | "attack_unit" | "attack_struct" | "attack_move" | "patrol" | "guard"
var direct_point: Vector2 = Vector2.ZERO
var direct_target: Node = null

# RTS nâng cao (port tay từ nhánh lenh-rts): attack-move nhớ điểm XUẤT PHÁT
# (am_from) để neo leash theo đoạn đường đi; tuần tra qua lại A (patrol_a =
# vị trí lúc ra lệnh) <-> B (direct_point); hộ vệ bám guard_target (Unit/
# Structure đồng minh). Mọi lệnh mới đều bị huỷ bởi clear_direct() như lệnh
# trực tiếp cũ.
var am_from: Vector2 = Vector2.ZERO
var patrol_a: Vector2 = Vector2.ZERO
var patrol_to_b: bool = true
var guard_target: Node = null

# AI (Stats.UNIT_AI): chọn mục tiêu theo NHỊP NGHĨ lệch pha (không quét mỗi
# frame), giữ mục tiêu giữa các nhịp; tách đàn cũng tính theo nhịp thưa.
var _think_left: float = 0.0
var _target_unit: Unit = null
var _target_struct: Structure = null
var _sep_left: float = 0.0
var _sep_push: Vector2 = Vector2.ZERO

# --- Tu Sĩ (unit_type == "monk"): không tấn công — chữa trị + đi theo đội
# + bỏ chạy. State riêng để nhánh _process_monk không đụng logic chiến đấu.
var _heal_left: float = 0.0
var _heal_target: Unit = null
var _heal_fx: AnimatedSprite2D = null
var _fleeing: bool = false
var _flee_left: float = 0.0
var _threat_left: float = 0.0

## Mục tiêu AI hiện tại (phục vụ test + tích hợp/debug).
func current_target() -> Node:
	if direct_target != null and is_instance_valid(direct_target):
		return direct_target
	if _target_unit != null and is_instance_valid(_target_unit):
		return _target_unit
	if _target_struct != null and is_instance_valid(_target_struct):
		return _target_struct
	return null

func set_direct_move(point: Vector2) -> void:
	direct_mode = "move"
	direct_point = point
	direct_target = null
	guard_target = null

func set_direct_attack(target: Node) -> void:
	if target is Unit:
		direct_mode = "attack_unit"
	elif target is Structure:
		direct_mode = "attack_struct"
	else:
		return
	direct_target = target
	guard_target = null

## Đánh-di-chuyển: đi tới point, tự đánh mọi địch THẤY ĐƯỢC trên đường;
## tới nơi thì GIỮ ĐIỂM ở đó (lệnh vẫn hiệu lực, tiếp tục quét địch).
func set_attack_move(point: Vector2) -> void:
	direct_mode = "attack_move"
	am_from = global_position
	direct_point = point
	direct_target = null
	guard_target = null

## Tuần tra: qua lại giữa vị trí HIỆN TẠI (A) và point (B) vô hạn tới khi
## có lệnh khác. Đánh địch thấy được dọc tuyến như attack-move.
func set_patrol(point_b: Vector2) -> void:
	direct_mode = "patrol"
	patrol_a = global_position
	direct_point = point_b
	patrol_to_b = true
	direct_target = null
	guard_target = null

## Hộ vệ: bám theo đối tượng đồng minh (Main đã kiểm tra hợp lệ), đánh
## địch áp sát nó. Đối tượng mất -> chuyển giữ điểm tại chỗ (xem _step_guard).
func set_guard(target: Node) -> void:
	direct_mode = "guard"
	guard_target = target
	direct_target = null

func clear_direct() -> void:
	direct_mode = ""
	direct_target = null
	guard_target = null

func setup(p_owner: int, p_type: String, p_color: String, p_main: Node, p_slot: Vector2) -> void:
	owner_pid = p_owner
	unit_type = p_type
	color_key = p_color
	st = Stats.unit_stats(p_type)
	hp = st["hp"]
	max_hp = hp
	main_ref = p_main
	slot_offset = p_slot
	# Lệch pha nhịp nghĩ/tách đàn theo id để cả đội không dồn tính toán 1 frame.
	var phase := float(abs(get_instance_id()) % 10) / 10.0
	_think_left = float(Stats.UNIT_AI["think_interval"]) * phase
	_sep_left = float(Stats.UNIT_AI["separation_interval"]) * phase

func _ready() -> void:
	add_to_group("units")
	_anim = AnimatedSprite2D.new()
	# Lính giáo: sheet frame 320 (các quân khác 192) -> thu tỉ lệ để hình
	# hiển thị ~109px, nhỉnh hơn kiếm sĩ (96px) đúng chất tinh nhuệ.
	_anim.scale = Vector2(0.34, 0.34) if unit_type == "lancer" else Vector2(0.5, 0.5)
	_anim.position = Vector2(0, -20)
	_anim.sprite_frames = _build_frames()
	add_child(_anim)
	_play("idle")
	if unit_type == "monk":
		# Hiệu ứng chữa của pack (Heal_Effect): node top_level để đặt đè
		# đúng vị trí MỤC TIÊU đang được chữa, không dính theo tu sĩ.
		_heal_fx = AnimatedSprite2D.new()
		_heal_fx.top_level = true
		_heal_fx.scale = Vector2(0.5, 0.5)
		_heal_fx.sprite_frames = _build_heal_fx_frames()
		_heal_fx.visible = false
		_heal_fx.z_index = 16
		add_child(_heal_fx)
		_heal_fx.animation_finished.connect(func() -> void: _heal_fx.visible = false)
		_threat_left = float(Stats.MONK_AI["threat_check_interval"]) \
			* float(abs(get_instance_id()) % 7) / 7.0

func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var base := "res://assets/units/%s/" % color_key
	if unit_type == "warrior":
		_add_anim(sf, "idle", base + "warrior_idle.png", 8, 8.0)
		_add_anim(sf, "run", base + "warrior_run.png", 6, 10.0)
		_add_anim(sf, "attack", base + "warrior_attack.png", 4, 10.0)
	elif unit_type == "lancer":
		# Sheet Lancer của pack: frame 320x320 (Idle 12, Run 6,
		# Right_Attack 3 — bản đánh ngang khớp cơ chế lật trái/phải sẵn có).
		_add_anim(sf, "idle", base + "lancer_idle.png", 12, 8.0, 320.0)
		_add_anim(sf, "run", base + "lancer_run.png", 6, 10.0, 320.0)
		_add_anim(sf, "attack", base + "lancer_attack.png", 3, 8.0, 320.0)
	elif unit_type == "monk":
		# Sheet Monk của pack (frame 192): Idle 6, Run 4, Heal 11 frame.
		_add_anim(sf, "idle", base + "monk_idle.png", 6, 8.0)
		_add_anim(sf, "run", base + "monk_run.png", 4, 10.0)
		_add_anim(sf, "heal", base + "monk_heal.png", 11, 12.0)
	else:
		_add_anim(sf, "idle", base + "archer_idle.png", 6, 8.0)
		_add_anim(sf, "run", base + "archer_run.png", 4, 10.0)
		_add_anim(sf, "attack", base + "archer_shoot.png", 8, 12.0)
	return sf

func _add_anim(sf: SpriteFrames, anim_name: String, tex_path: String, frames: int, fps: float, frame_size: float = FRAME) -> void:
	var sheet := load(tex_path) as Texture2D
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, anim_name != "attack")
	for i in frames:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		sf.add_frame(anim_name, at)

func _build_heal_fx_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var sheet := load("res://assets/units/%s/monk_heal_effect.png" % color_key) as Texture2D
	sf.add_animation("fx")
	sf.set_animation_speed("fx", 12.0)
	sf.set_animation_loop("fx", false)
	for i in 11:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * FRAME, 0, FRAME, FRAME)
		sf.add_frame("fx", at)
	return sf

func _play(anim_name: String) -> void:
	if _cur_anim != anim_name:
		_cur_anim = anim_name
		_anim.play(anim_name)

func is_alive() -> bool:
	return not _dead

func get_aim_point() -> Vector2:
	return global_position + Vector2(0, -22)

func take_damage(amount: float, attacker_pid: int) -> void:
	if _dead:
		return
	_last_attacker = attacker_pid
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		_die()

## Hồi máu (Tu Sĩ chữa cho): kẹp ở máu tối đa, quân đã chết không hồi.
func heal(amount: float) -> void:
	if _dead:
		return
	hp = minf(max_hp, hp + amount)
	queue_redraw()

func _die() -> void:
	_dead = true
	remove_from_group("units")
	died.emit(self, _last_attacker)
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

func _process(delta: float) -> void:
	if _dead or main_ref == null:
		return
	if main_ref.match_over:
		_play("idle")
		return
	_atk_timer = maxf(0.0, _atk_timer - delta)
	var player: PlayerState = main_ref.get_player(owner_pid)
	if player == null or not player.alive:
		_play("idle")
		return
	var home_castle: Castle = main_ref.castles[owner_pid]

	# Tu Sĩ: nhánh AI riêng — không tấn công, chỉ chữa/đi theo đội/bỏ chạy.
	# Cắm TRƯỚC khối lệnh trực tiếp + giao tranh bên dưới: monk không có
	# khoá "damage" nên tuyệt đối không được rơi vào _combat_unit/
	# _combat_structure/_engage_visible; lệnh trực tiếp của người chơi
	# được _process_monk tự tôn trọng (xem trong hàm).
	if unit_type == "monk":
		_process_monk(delta, home_castle)
		_separate(delta)
		queue_redraw()
		return

	# Nhịp nghĩ: tái chọn mục tiêu theo chu kỳ (lệch pha), giữa các nhịp dùng
	# mục tiêu đã nhớ — quân đông cũng không quét toàn bản đồ mỗi frame.
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = float(Stats.UNIT_AI["think_interval"])
		_acquire_targets(player)

	# 0) M2: lệnh trực tiếp ưu tiên hơn thái độ chung.
	if direct_mode == "attack_unit" or direct_mode == "attack_struct":
		var t := direct_target
		var dead_target := t == null or not is_instance_valid(t) \
			or (t is Unit and not (t as Unit).is_alive()) \
			or (t is Structure and not (t as Structure).is_alive())
		if dead_target:
			clear_direct()
		else:
			if t is Unit:
				_combat_unit(t as Unit, delta)
			else:
				_combat_structure(t as Structure, delta)
			_separate(delta)
			queue_redraw()
			return
	if direct_mode == "attack_move":
		_step_attack_move(player, delta)
		_separate(delta)
		queue_redraw()
		return
	if direct_mode == "patrol":
		_step_patrol(player, delta)
		_separate(delta)
		queue_redraw()
		return
	if direct_mode == "guard":
		_step_guard(player, delta)
		_separate(delta)
		queue_redraw()
		return
	if direct_mode == "move":
		if global_position.distance_to(direct_point) > 16.0:
			_move_toward(direct_point + slot_offset * 0.5, delta)
		else:
			_play("idle")
			clear_direct()
		_separate(delta)
		queue_redraw()
		return

	# 1) Địch (quân) đã chọn trong tầm phát hiện -> đánh trước.
	var enemy := _valid_target_unit()
	if enemy != null:
		var engage := true
		if player.stance == "hold":
			# Chỉ đánh chặn khi địch đã vào vùng giữ nhà.
			engage = enemy.global_position.distance_to(home_castle.global_position) <= float(Stats.MILITARY["hold_radius"])
		if engage:
			_combat_unit(enemy, delta, player)
			_separate(delta)
			queue_redraw()
			return

	if player.stance == "hold":
		# Về điểm tập kết trước thành.
		var rally: Vector2 = main_ref.rally_point(owner_pid) + slot_offset
		if global_position.distance_to(rally) > 14.0:
			_move_toward(rally, delta)
		else:
			_play("idle")
	elif player.stance == "attack":
		var target_castle: Castle = null
		if main_ref.castles.has(player.target_pid):
			target_castle = main_ref.castles[player.target_pid]
		# Công trình địch cản đường trong tầm phát hiện -> đánh.
		var struct := _valid_target_struct()
		if struct != null:
			_combat_structure(struct, delta, player)
			_separate(delta)
			queue_redraw()
			return
		if target_castle != null and target_castle.is_alive():
			_combat_structure(target_castle, delta, player)
		else:
			_play("idle")
	elif player.stance == "move":
		var struct2 := _valid_target_struct()
		if struct2 != null:
			_combat_structure(struct2, delta, player)
			_separate(delta)
			queue_redraw()
			return
		if global_position.distance_to(player.move_point) > 16.0:
			_move_toward(player.move_point + slot_offset * 0.5, delta)
		else:
			_play("idle")
	_separate(delta)
	queue_redraw()

# ===================== AI: CHỌN MỤC TIÊU / LEASH / TẦM NHÌN =====================

func _valid_target_unit() -> Unit:
	if _target_unit != null and is_instance_valid(_target_unit) and _target_unit.is_alive():
		return _target_unit
	_target_unit = null
	return null

func _valid_target_struct() -> Structure:
	if _target_struct != null and is_instance_valid(_target_struct) and _target_struct.is_alive():
		return _target_struct
	_target_struct = null
	return null

func _acquire_targets(player: PlayerState) -> void:
	_target_unit = _find_best_enemy_unit(float(st["detect_range"]), player)
	_target_struct = _find_enemy_structure(float(st["detect_range"]), player)

## Phe của quân này có "thấy" được vị trí đó không — LUẬT SƯƠNG MÙ:
## trong tầm mắt của chính quân này (vision của loại quân) thì luôn thấy;
## xa hơn thì phải nằm trong ô đang SÁNG của phe (đồng đội/công trình soi).
func _can_see(pos: Vector2) -> bool:
	var vision := float(Stats.FOG["vision"].get(unit_type, 0.0))
	if vision > 0.0 and global_position.distance_to(pos) <= vision * 0.95:
		return true
	if main_ref != null and main_ref.fogs.has(owner_pid):
		return (main_ref.fogs[owner_pid] as FogOfWar).is_visible_pos(pos)
	return true

## Điểm trên ĐOẠN a-b gần vị trí quân nhất — neo leash "trượt" cho
## attack-move/tuần tra: vòng giữ bám theo tuyến đường nên quân đánh địch
## DỌC ĐƯỜNG nhưng không bị dụ đuổi quá leash_move khỏi tuyến.
func _segment_anchor(a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 1.0:
		return a
	var t := clampf((global_position - a).dot(ab) / len2, 0.0, 1.0)
	return a + ab * t

## Neo giữ khoảng (leash) theo ngữ cảnh: lệnh trực tiếp thường + tổng tấn
## công = không neo (người chơi đã ra lệnh rõ); giữ nhà = neo THÀNH; đi
## điểm = neo điểm lệnh; lệnh RTS nâng cao = neo theo NGỮ CẢNH LỆNH
## (đoạn đường đi / đối tượng hộ vệ).
## Trả về [anchor, radius]; radius < 0 = không áp leash.
func _leash(player: PlayerState) -> Array:
	if direct_mode == "attack_move":
		return [_segment_anchor(am_from, direct_point), float(Stats.UNIT_AI["leash_move"])]
	if direct_mode == "patrol":
		return [_segment_anchor(patrol_a, direct_point), float(Stats.UNIT_AI["leash_move"])]
	if direct_mode == "guard":
		var gt := guard_target
		if gt != null and is_instance_valid(gt):
			return [(gt as Node2D).global_position, float(Stats.UNIT_AI["leash_move"])]
		return [Vector2.ZERO, -1.0]
	if direct_mode != "":
		return [Vector2.ZERO, -1.0]
	if player.stance == "hold":
		var c: Castle = main_ref.castles[owner_pid]
		if c != null:
			return [c.global_position, float(Stats.UNIT_AI["leash_hold"])]
	elif player.stance == "move":
		return [player.move_point, float(Stats.UNIT_AI["leash_move"])]
	return [Vector2.ZERO, -1.0]

func _beyond_leash(player: PlayerState) -> bool:
	var lz := _leash(player)
	if float(lz[1]) < 0.0:
		return false
	return global_position.distance_to(lz[0] as Vector2) > float(lz[1])

## Chọn địch theo ĐIỂM ƯU TIÊN (Stats.UNIT_AI): gần + yếu máu + loại nguy hiểm
## được ưu tiên; chỉ xét địch phe mình THẤY được và (khi có leash) nằm trong
## vòng giữ — quân không đuổi theo thứ ngoài tầm nhìn/khu vực của nó.
func _find_best_enemy_unit(range_px: float, player: PlayerState) -> Unit:
	var lz := _leash(player)
	var anchor: Vector2 = lz[0]
	var leash_r := float(lz[1])
	var hp_bias := float(Stats.UNIT_AI["target_hp_bias"])
	var type_bias: Dictionary = Stats.UNIT_AI["target_type_bias"]
	var sticky := float(Stats.UNIT_AI["target_stickiness"])
	var focus_penalty := float(Stats.UNIT_AI.get("target_focus_penalty", 0.0))
	var atk_range := float(st["attack_range"])
	# Đếm trước số đồng minh đang nhắm từng địch (bản đồ instance_id -> số
	# người nhắm) để cộng phạt CHIA LỬA bên dưới — quét 1 lần, không lồng vòng.
	var focus_count := {}
	if focus_penalty > 0.0:
		for an in get_tree().get_nodes_in_group("units"):
			var au := an as Unit
			if au == null or au == self or au.owner_pid != owner_pid or not au.is_alive():
				continue
			var at := au._target_unit
			if at != null and is_instance_valid(at):
				var key := at.get_instance_id()
				focus_count[key] = int(focus_count.get(key, 0)) + 1
	var best: Unit = null
	var best_score := INF
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u == self or u.owner_pid == owner_pid or not u.is_alive():
			continue
		var d := global_position.distance_to(u.global_position)
		if d > range_px:
			continue
		if not _can_see(u.global_position):
			continue
		if leash_r >= 0.0 and u.global_position.distance_to(anchor) > leash_r + atk_range:
			continue
		var score := d + hp_bias * clampf(u.hp / u.max_hp, 0.0, 1.0) \
			+ float(type_bias.get(u.unit_type, 0.0)) \
			+ focus_penalty * float(focus_count.get(u.get_instance_id(), 0))
		if u == _target_unit:
			score -= sticky
		if score < best_score:
			best_score = score
			best = u
	return best

# ===================== LỆNH RTS NÂNG CAO (port từ nhánh lenh-rts) =====================
# Cả 3 lệnh dùng CHUNG 1 cửa giao tranh (_engage_visible): mục tiêu do
# _acquire_targets chọn — đã qua cổng sương mù _can_see (chỉ địch phe mình
# THẤY ĐƯỢC) + leash theo ngữ cảnh lệnh. Không có đường tắt "biết" địch
# trong vùng đen nào ở đây.

## Ưu tiên giao tranh của các lệnh RTS: quân địch đã chọn -> công trình
## địch cản đường. Trả true nếu frame này đã xử lý giao tranh.
func _engage_visible(player: PlayerState, delta: float) -> bool:
	var enemy := _valid_target_unit()
	if enemy != null:
		_combat_unit(enemy, delta, player)
		return true
	var struct := _valid_target_struct()
	if struct != null:
		_combat_structure(struct, delta, player)
		return true
	return false

func _step_attack_move(player: PlayerState, delta: float) -> void:
	if _engage_visible(player, delta):
		return
	if global_position.distance_to(direct_point) > 16.0:
		_move_toward(direct_point + slot_offset * 0.5, delta)
	else:
		_play("idle") # tới nơi: GIỮ ĐIỂM — lệnh còn hiệu lực, vẫn quét địch

func _step_patrol(player: PlayerState, delta: float) -> void:
	if _engage_visible(player, delta):
		return
	var wp := direct_point if patrol_to_b else patrol_a
	var dest := wp + slot_offset * 0.5
	if global_position.distance_to(dest) > 18.0:
		_move_toward(dest, delta)
	else:
		patrol_to_b = not patrol_to_b
		_play("idle")

func _step_guard(player: PlayerState, delta: float) -> void:
	var t := guard_target
	var gone := t == null or not is_instance_valid(t) \
		or (t is Unit and not (t as Unit).is_alive()) \
		or (t is Structure and not (t as Structure).is_alive())
	if gone:
		# Đối tượng hộ vệ mất -> GIỮ ĐIỂM NGAY TẠI CHỖ (attack-move tại vị
		# trí hiện tại), không tự quay về thành như thái độ hold thường.
		set_attack_move(global_position)
		return
	if _engage_visible(player, delta):
		return
	var anchor := (t as Node2D).global_position
	if t is Structure:
		# Đứng ở vòng ngoài quanh công trình, phía mình đang đứng.
		var want := (t as Structure).radius + 34.0
		if global_position.distance_to(anchor) > want + 12.0:
			var dir := (global_position - anchor).normalized()
			_move_toward(anchor + dir * want, delta)
		else:
			_play("idle")
	else:
		# Bám theo quân đồng minh: điểm bám = vị trí đối tượng + slot_offset
		# riêng của mình (nhiều quân hộ vệ tự tỏa ra, không chồng 1 điểm).
		var follow := anchor + slot_offset
		if global_position.distance_to(follow) > 14.0:
			_move_toward(follow, delta)
		else:
			_play("idle")

## player == null khi đánh theo LỆNH TRỰC TIẾP (không áp leash).
func _combat_unit(u: Unit, delta: float, player: PlayerState = null) -> void:
	var d := global_position.distance_to(u.global_position)
	var range := float(st["attack_range"])
	# Cung thủ giữ tầm: địch áp sát gần hơn kite_distance -> vừa bắn vừa lùi.
	if unit_type == "archer" and d <= range and d < float(Stats.UNIT_AI["archer_kite_distance"]):
		_face(u.global_position)
		if _atk_timer <= 0.0:
			_atk_timer = float(st["attack_cooldown"])
			_play("attack")
			main_ref.spawn_projectile(get_aim_point(), u, float(st["damage"]), owner_pid, float(st["projectile_speed"]), color_key)
		_kite_away(u.global_position, delta, player)
		return
	if d <= range:
		_face(u.global_position)
		_play("attack")
		if _atk_timer <= 0.0:
			_atk_timer = float(st["attack_cooldown"])
			if unit_type == "archer":
				main_ref.spawn_projectile(get_aim_point(), u, float(st["damage"]), owner_pid, float(st["projectile_speed"]), color_key)
			else:
				u.take_damage(float(st["damage"]), owner_pid)
	else:
		# Đuổi theo — nhưng đã ra ngoài vòng leash thì quay về neo, không đuổi nữa.
		if player != null and _beyond_leash(player):
			_move_toward(_leash(player)[0] as Vector2, delta)
		else:
			_move_toward(u.global_position, delta)

func _kite_away(from_pos: Vector2, delta: float, player: PlayerState) -> void:
	var dir := global_position - from_pos
	if dir.length() < 0.01:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	# Vừa lùi vừa bắn thì lùi CHẬM hơn hẳn tốc độ thường (kite phải trả giá —
	# xem Stats.UNIT_AI.archer_kite_speed_factor): địch nhanh hơn sẽ áp sát được.
	var kite_factor := float(Stats.UNIT_AI.get("archer_kite_speed_factor", 1.0))
	var dest := global_position + dir * float(st["speed"]) * kite_factor * delta
	# Hết đất lùi (chạm vòng leash) thì đứng lại bắn, không lùi khỏi khu vực giữ.
	if player != null:
		var lz := _leash(player)
		if float(lz[1]) >= 0.0 and dest.distance_to(lz[0] as Vector2) > float(lz[1]):
			_play("attack")
			return
	global_position = dest
	_play("run")

func _combat_structure(s: Structure, delta: float, player: PlayerState = null) -> void:
	var d := global_position.distance_to(s.global_position)
	if d <= float(st["attack_range"]) + s.radius:
		_face(s.global_position)
		_play("attack")
		if _atk_timer <= 0.0:
			_atk_timer = float(st["attack_cooldown"])
			if unit_type == "archer":
				main_ref.spawn_projectile(get_aim_point(), s, float(st["damage"]), owner_pid, float(st["projectile_speed"]), color_key)
			else:
				s.take_damage(float(st["damage"]), owner_pid)
	else:
		if player != null and _beyond_leash(player):
			_move_toward(_leash(player)[0] as Vector2, delta)
		else:
			_move_toward(s.global_position, delta)

func _find_enemy_unit(range_px: float) -> Unit:
	var best: Unit = null
	var best_d := range_px
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u == self or u.owner_pid == owner_pid or not u.is_alive():
			continue
		var d := global_position.distance_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best

func _find_enemy_structure(range_px: float, player: PlayerState) -> Structure:
	var lz := _leash(player)
	var anchor: Vector2 = lz[0]
	var leash_r := float(lz[1])
	var best: Structure = null
	var best_d := range_px
	for n in get_tree().get_nodes_in_group("structures"):
		var s := n as Structure
		if s == null or s.owner_pid == owner_pid or not s.is_alive():
			continue
		# Nha DANG XAY DO chua co hieu luc chien dau -> khong tu nham:
		# neu nham, quan cong se farm 1 cong trinh re tien ma bot dich xay
		# lai tai dung o do ngay khi vua pha (vong lap vo han, quan khong
		# bao gio tien toi thanh — mot goc cua bug dung tran).
		if s is Building and not (s as Building).constructed:
			continue
		var d := global_position.distance_to(s.global_position)
		if d >= best_d:
			continue
		# Luật sương mù + leash: không tự ý đánh công trình ngoài tầm nhìn/vòng giữ.
		if not _can_see(s.global_position):
			continue
		if leash_r >= 0.0 and s.global_position.distance_to(anchor) > leash_r + float(st["attack_range"]) + s.radius:
			continue
		best_d = d
		best = s
	return best

func _move_toward(to: Vector2, delta: float) -> void:
	var dir := to - global_position
	if dir.length() < 2.0:
		_play("idle")
		return
	dir = dir.normalized()
	global_position += dir * float(st["speed"]) * delta
	_face(to)
	_play("run")

func _separate(delta: float) -> void:
	# Tách đàn theo NHỊP THƯA lệch pha: tính lực đẩy mỗi separation_interval,
	# các frame giữa hai nhịp áp lực đã nhớ — không quét toàn bản đồ mỗi frame.
	_sep_left -= delta
	if _sep_left <= 0.0:
		_sep_left = float(Stats.UNIT_AI["separation_interval"])
		_sep_push = _compute_separation()
	if _sep_push != Vector2.ZERO:
		global_position += _sep_push * delta

func _compute_separation() -> Vector2:
	var radius := float(Stats.UNIT_AI["separation_radius"])
	var strength := float(Stats.UNIT_AI["separation_push"])
	var push := Vector2.ZERO
	for group_name in ["units", "villagers"]:
		for n in get_tree().get_nodes_in_group(group_name):
			var o := n as Node2D
			if o == null or o == self:
				continue
			# Quân HỘ VỆ không bị chính ĐỐI TƯỢNG mình bám theo đẩy ra:
			# separation_push (85) > tốc độ quân (72) nên nếu tính cả đối
			# tượng, quân đuổi địch đứng SAU đối tượng sẽ kẹt ở điểm cân
			# bằng ~4,6px trước đối tượng và không bao giờ áp sát được
			# địch (bẫy đã tái hiện ở test_rts rts3 trên cả nhánh gốc).
			if guard_target != null and o == guard_target:
				continue
			if o is Unit and not (o as Unit).is_alive():
				continue
			var diff := global_position - o.global_position
			var d := diff.length()
			if d >= radius:
				continue
			if d < 0.01:
				# Chồng khít đúng 1 điểm: tách theo hướng ổn định suy từ id.
				diff = Vector2.RIGHT.rotated(float(abs(get_instance_id()) % 628) / 100.0)
				d = 0.01
			push += diff / d * (1.0 - d / radius) * strength
	return push

func _face(to: Vector2) -> void:
	if _anim == null:
		return
	var dx := to.x - global_position.x
	if absf(dx) > 2.0:
		_anim.flip_h = dx < 0.0

# ===================== TU SĨ: CHỮA TRỊ / ĐI THEO ĐỘI / BỎ CHẠY =====================
# Tu sĩ KHÔNG BAO GIỜ tấn công (Stats.UNITS.monk không có "damage"):
# vòng đời mỗi frame chỉ gồm: bỏ chạy nếu bị dí -> tôn trọng lệnh trực
# tiếp -> chữa đồng minh bị thương -> bám sau lưng đội hình -> về điểm
# tập kết. Mọi đích di chuyển đều là vị trí PHE MÌNH (quân mình/thành
# mình) nên không bao giờ tự lao vào vùng chưa khám phá — cổng sương mù
# nguyên vẹn.
# ADAPT với lệnh RTS của main: người chơi ra lệnh trực tiếp thì lệnh
# THẮNG hành vi tự động như mọi quân — nhưng tu sĩ không giao tranh nên
# attack-move/tuần tra/hộ vệ được thực thi như DI CHUYỂN thuần tương
# ứng ngay tại đây, KHÔNG đi qua _step_* dùng chung (chúng gọi
# _engage_visible -> _combat_* cần khoá "damage" tu sĩ không có).

func _process_monk(delta: float, home_castle: Castle) -> void:
	# Lệnh tấn công đích danh vô nghĩa với tu sĩ: huỷ, quay về hỗ trợ.
	if direct_mode == "attack_unit" or direct_mode == "attack_struct":
		clear_direct()

	# Quét nguy hiểm theo nhịp thưa lệch pha (như nông dân): địch áp sát
	# trong flee_trigger_range là bỏ chạy, kể cả chưa bị đánh.
	_threat_left -= delta
	if _threat_left <= 0.0:
		_threat_left = float(Stats.MONK_AI["threat_check_interval"]) \
			* (0.8 + 0.1 * float(abs(get_instance_id()) % 5))
		if not _fleeing and _enemy_unit_near(float(Stats.MONK_AI["flee_trigger_range"])):
			_fleeing = true
			_flee_left = float(Stats.MONK_AI["flee_time"])
	if _fleeing:
		_step_monk_flee(delta, home_castle)
		return # đang chạy trốn thì không chữa (như dân không farm khi chạy)

	# Lệnh trực tiếp của người chơi thắng hành vi tự động.
	if direct_mode == "move":
		if global_position.distance_to(direct_point) > 16.0:
			_move_toward(direct_point + slot_offset * 0.5, delta)
		else:
			_play("idle")
			clear_direct()
		return
	if direct_mode == "attack_move":
		# Đi tới điểm lệnh rồi GIỮ ĐIỂM (lệnh còn hiệu lực như quân thường).
		if global_position.distance_to(direct_point) > 16.0:
			_move_toward(direct_point + slot_offset * 0.5, delta)
		else:
			_play("idle")
		return
	if direct_mode == "patrol":
		var wp := direct_point if patrol_to_b else patrol_a
		var dest := wp + slot_offset * 0.5
		if global_position.distance_to(dest) > 18.0:
			_move_toward(dest, delta)
		else:
			patrol_to_b = not patrol_to_b
			_play("idle")
		return
	if direct_mode == "guard":
		var t := guard_target
		var gone := t == null or not is_instance_valid(t) \
			or (t is Unit and not (t as Unit).is_alive()) \
			or (t is Structure and not (t as Structure).is_alive())
		if gone:
			# Đối tượng hộ vệ mất -> giữ điểm tại chỗ như _step_guard của main.
			set_attack_move(global_position)
			return
		var anchor := (t as Node2D).global_position
		if t is Structure:
			var want := (t as Structure).radius + 34.0
			if global_position.distance_to(anchor) > want + 12.0:
				var dir := (global_position - anchor).normalized()
				_move_toward(anchor + dir * want, delta)
			else:
				_play("idle")
		else:
			var follow := anchor + slot_offset
			if global_position.distance_to(follow) > 14.0:
				_move_toward(follow, delta)
			else:
				_play("idle")
		return

	_heal_left = maxf(0.0, _heal_left - delta)
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = float(Stats.UNIT_AI["think_interval"])
		_heal_target = _find_heal_target()
	var target := _valid_heal_target()
	if target != null:
		var d := global_position.distance_to(target.global_position)
		if d <= float(st["heal_range"]):
			# Trong tầm chữa: đứng yên, hồi theo nhịp heal_interval.
			_face(target.global_position)
			_play("heal")
			if _heal_left <= 0.0:
				_heal_left = float(st["heal_interval"])
				target.heal(float(st["heal_amount"]))
				_show_heal_fx(target)
			return
		if d <= float(Stats.MONK_AI["seek_radius"]):
			# Bị thương ngoài tầm chữa nhưng còn gần: chủ động tới gần.
			_move_toward(target.global_position, delta)
			return
	# Không ai cần chữa ở gần: bám sau lưng quân chiến đấu gần nhất.
	var anchor2 := _nearest_combat_ally()
	if anchor2 != null:
		if global_position.distance_to(anchor2.global_position) > float(Stats.MONK_AI["follow_distance"]):
			_move_toward(anchor2.global_position, delta)
		else:
			_play("idle")
		return
	# Chưa có quân nào khác: về điểm tập kết trước thành như mọi quân.
	var rally: Vector2 = main_ref.rally_point(owner_pid) + slot_offset
	if global_position.distance_to(rally) > 14.0:
		_move_toward(rally, delta)
	else:
		_play("idle")

func _valid_heal_target() -> Unit:
	if _heal_target != null and is_instance_valid(_heal_target) and _heal_target.is_alive() \
			and _heal_target.hp < _heal_target.max_hp - 0.5:
		return _heal_target
	_heal_target = null
	return null

## Mục tiêu chữa = đồng minh có % máu THẤP NHẤT. Chỉ xét QUÂN (Unit) cùng
## phe và KHÔNG phải chính mình (tu sĩ khác vẫn được chữa như mọi đồng
## minh; công trình và nông dân không thuộc diện chữa). Ưu tiên vòng
## heal_range trước để tu sĩ không bỏ đồng minh cạnh bên chạy theo người xa.
func _find_heal_target() -> Unit:
	for radius in [float(st["heal_range"]), float(Stats.MONK_AI["seek_radius"])]:
		var best: Unit = null
		var best_frac := 1.0
		for n in get_tree().get_nodes_in_group("units"):
			var u := n as Unit
			if u == null or u == self or u.owner_pid != owner_pid or not u.is_alive():
				continue
			if u.hp >= u.max_hp - 0.5:
				continue
			if global_position.distance_to(u.global_position) > radius:
				continue
			var frac := u.hp / u.max_hp
			if frac < best_frac:
				best_frac = frac
				best = u
		if best != null:
			return best
	return null

## Quân chiến đấu (kiếm/cung/giáo) cùng phe gần nhất — mỏ neo để tu sĩ bám
## sau lưng đội hình. Tu sĩ khác KHÔNG làm mỏ neo (tránh 2 tu sĩ bám nhau).
func _nearest_combat_ally() -> Unit:
	var best: Unit = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u == self or u.owner_pid != owner_pid or not u.is_alive():
			continue
		if u.unit_type == "monk":
			continue
		var d := global_position.distance_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best

func _enemy_unit_near(range_px: float) -> bool:
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u.owner_pid == owner_pid or not u.is_alive():
			continue
		if global_position.distance_to(u.global_position) <= range_px:
			return true
	return false

## Bỏ chạy về THÀNH CHÍNH (nơi an toàn của tu sĩ — nó không vác tài
## nguyên nên không cần kho như nông dân). Điều kiện dừng chạy mượn đúng
## luật của nông dân: hết giờ hoảng tối thiểu VÀ đã về gần nhà, hoặc quá
## hạn chót flee_time + flee_max_time thì thôi chạy.
func _step_monk_flee(delta: float, home_castle: Castle) -> void:
	_flee_left -= delta
	var dest := home_castle.global_position
	var d_home := global_position.distance_to(dest)
	var safe := d_home <= float(Stats.MONK_AI["flee_safe_distance"])
	if (_flee_left <= 0.0 and safe) or _flee_left <= -float(Stats.MONK_AI["flee_max_time"]):
		_fleeing = false
		_flee_left = 0.0
		_play("idle")
	elif d_home > 30.0:
		_move_toward(dest, delta)
	else:
		_play("idle")

func _show_heal_fx(target: Unit) -> void:
	if _heal_fx == null:
		return
	_heal_fx.global_position = target.global_position + Vector2(0, -20)
	_heal_fx.visible = true
	_heal_fx.play("fx")

func _draw() -> void:
	if _dead:
		return
	if selected:
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, Color(0.3, 1, 0.4, 0.95), 3.0)
	var w := 34.0
	var pos := Vector2(-w / 2.0, -58.0)
	draw_rect(Rect2(pos, Vector2(w, 5)), Color(0, 0, 0, 0.65))
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(pos, Vector2(w * frac, 5)), Color(0.3, 0.95, 0.35))
