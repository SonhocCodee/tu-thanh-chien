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

	# 1) Địch (quân) trong tầm phát hiện -> đánh trước.
	var enemy := _find_enemy_unit(float(st["detect_range"]))
	if enemy != null:
		var engage := true
		if player.stance == "hold":
			# Chỉ đánh chặn khi địch đã vào vùng giữ nhà.
			engage = enemy.global_position.distance_to(home_castle.global_position) <= float(Stats.MILITARY["hold_radius"])
		if engage:
			_combat_unit(enemy, delta)
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
		var struct := _find_enemy_structure(float(st["detect_range"]))
		if struct != null:
			_combat_structure(struct, delta)
			_separate(delta)
			queue_redraw()
			return
		if target_castle != null and target_castle.is_alive():
			_combat_structure(target_castle, delta)
		else:
			_play("idle")
	elif player.stance == "move":
		var struct2 := _find_enemy_structure(float(st["detect_range"]))
		if struct2 != null:
			_combat_structure(struct2, delta)
			_separate(delta)
			queue_redraw()
			return
		if global_position.distance_to(player.move_point) > 16.0:
			_move_toward(player.move_point + slot_offset * 0.5, delta)
		else:
			_play("idle")
	_separate(delta)
	queue_redraw()

func _combat_unit(u: Unit, delta: float) -> void:
	var d := global_position.distance_to(u.global_position)
	if d <= float(st["attack_range"]):
		_face(u.global_position)
		_play("attack")
		if _atk_timer <= 0.0:
			_atk_timer = float(st["attack_cooldown"])
			if unit_type == "archer":
				main_ref.spawn_projectile(get_aim_point(), u, float(st["damage"]), owner_pid, float(st["projectile_speed"]), color_key)
			else:
				u.take_damage(float(st["damage"]), owner_pid)
	else:
		_move_toward(u.global_position, delta)

func _combat_structure(s: Structure, delta: float) -> void:
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

func _find_enemy_structure(range_px: float) -> Structure:
	var best: Structure = null
	var best_d := range_px
	for n in get_tree().get_nodes_in_group("structures"):
		var s := n as Structure
		if s == null or s.owner_pid == owner_pid or not s.is_alive():
			continue
		# Không tự ý đánh thành địch khác khi đang attack 1 đích (trừ khi nó cản đường thật gần).
		var d := global_position.distance_to(s.global_position)
		if d < best_d:
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
	# Đẩy nhẹ khỏi quân bạn đứng chồng lên nhau.
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u == self or not u.is_alive():
			continue
		var d := global_position.distance_to(u.global_position)
		if d > 0.01 and d < 17.0:
			global_position += (global_position - u.global_position).normalized() * 26.0 * delta

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
