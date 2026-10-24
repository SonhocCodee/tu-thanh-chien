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
var direct_mode: String = "" # "" | "move" | "attack_unit" | "attack_struct"
var direct_point: Vector2 = Vector2.ZERO
var direct_target: Node = null

# AI (Stats.UNIT_AI): chọn mục tiêu theo NHỊP NGHĨ lệch pha (không quét mỗi
# frame), giữ mục tiêu giữa các nhịp; tách đàn cũng tính theo nhịp thưa.
var _think_left: float = 0.0
var _target_unit: Unit = null
var _target_struct: Structure = null
var _sep_left: float = 0.0
var _sep_push: Vector2 = Vector2.ZERO

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

func set_direct_attack(target: Node) -> void:
	if target is Unit:
		direct_mode = "attack_unit"
	elif target is Structure:
		direct_mode = "attack_struct"
	else:
		return
	direct_target = target

func clear_direct() -> void:
	direct_mode = ""
	direct_target = null

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

## Neo giữ khoảng (leash) theo ngữ cảnh: lệnh trực tiếp + tổng tấn công = không
## neo (người chơi đã ra lệnh rõ); giữ nhà = neo THÀNH; đi điểm = neo điểm lệnh.
## Trả về [anchor, radius]; radius < 0 = không áp leash.
func _leash(player: PlayerState) -> Array:
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
	var atk_range := float(st["attack_range"])
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
			+ float(type_bias.get(u.unit_type, 0.0))
		if u == _target_unit:
			score -= sticky
		if score < best_score:
			best_score = score
			best = u
	return best

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
	var dest := global_position + dir * float(st["speed"]) * delta
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
