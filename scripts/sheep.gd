class_name Sheep
extends Node2D

## Cừu TRUNG LẬP: lang thang ăn cỏ quanh điểm sinh. Không thuộc phe nào,
## không đánh ai. Nông dân săn bằng dao (Pawn_Interact Knife) -> cừu chết
## thành XÁC THỊT (ResourceNode loại "meat") tại chỗ; nông dân xẻ thịt
## ở xác rồi VÁC THỊT VỀ KHO mới được cộng (như mọi tài nguyên khác).
## Sprite: Free Pack Sheep_Idle (6 frame) / Sheep_Move (4 frame) /
## Sheep_Grass (12 frame), frame 128px (ASSETS.md §3).
##
## Tích hợp AI (2026-10-24): BỘ NÃO là component AnimalAI gắn kèm (gặm cỏ ->
## lang thang -> nghỉ; bị dọa/đánh -> BỎ CHẠY). Khung sinh/tích hợp + đường
## chết qua Main.kill_sheep GIỮ NGUYÊN của giai đoạn 2; HP = Stats.SHEEP.hp
## = 25 (bản AI gốc 30 — không lấy). Cừu nằm ở cả 2 group: "sheep" (Main /
## nông dân săn) và "animals" (HerdKeeper đếm đàn).

signal died(sheep: Sheep)

const FRAME := 128.0

var hp: float = 25.0
var max_hp: float = 25.0
var alive: bool = true
var home: Vector2 = Vector2.ZERO
var main_ref: Node = null

var _anim: AnimatedSprite2D
var _cur_anim: String = ""
var _brain: AnimalAI = null
var _setup_done: bool = false
var _rng := RandomNumberGenerator.new()

func setup(p_main: Node, p_home: Vector2, p_seed: int) -> void:
	main_ref = p_main
	home = p_home
	hp = float(Stats.SHEEP["hp"])
	max_hp = hp
	_rng.seed = p_seed
	_setup_done = true

func _ready() -> void:
	add_to_group("sheep")
	add_to_group("animals")
	if not _setup_done:
		# Cừu do HerdKeeper sinh: không qua setup() — nhà = vị trí lúc sinh,
		# máu lấy mặc định từ Stats như mọi cừu khác.
		home = global_position
		hp = float(Stats.SHEEP["hp"])
		max_hp = hp
	_anim = AnimatedSprite2D.new()
	_anim.scale = Vector2(0.55, 0.55)
	_anim.position = Vector2(0, -14)
	_anim.sprite_frames = _build_frames()
	add_child(_anim)
	play_anim("grass")
	_brain = AnimalAI.new()
	add_child(_brain)
	_brain.setup(self, Stats.ANIMALS)

func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	_add_anim(sf, "idle", "res://assets/animals/sheep_idle.png", 6, 6.0)
	_add_anim(sf, "move", "res://assets/animals/sheep_move.png", 4, 8.0)
	_add_anim(sf, "grass", "res://assets/animals/sheep_grass.png", 12, 5.0)
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

# --- Giao diện cho AnimalAI ---
func play_anim(anim_name: String) -> void:
	if _anim != null and _cur_anim != anim_name:
		_cur_anim = anim_name
		_anim.play(anim_name)

func face_dir(dx: float) -> void:
	if _anim != null and absf(dx) > 0.05:
		_anim.flip_h = dx < 0.0

func is_dead() -> bool:
	return not alive

func ai_state() -> String:
	return _brain.current_state() if _brain != null else ""

## Bị săn: chết tại chỗ (Main sinh xác thịt ở vị trí này).
## GIỮ NGUYÊN ngữ nghĩa giai đoạn 2 — Main.kill_sheep gọi hàm này rồi
## queue_free + sinh xác; hàm này tự nó không sinh xác.
func kill() -> void:
	alive = false

## Nhận sát thương trực tiếp (móc cho quân/thợ săn đánh cừu + test):
## chết -> đi qua ĐÚNG đường Main.kill_sheep nếu đang trong trận; ngoài
## trận (không có main_ref, VD cừu của HerdKeeper trong sân test) thì tự
## để lại xác thịt tại chỗ như bản AI.
func take_damage(amount: float, _attacker_pid: int) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		_die()
	elif _brain != null:
		_brain.startle()

func _die() -> void:
	if main_ref != null and is_instance_valid(main_ref) and main_ref.has_method("kill_sheep"):
		# kill_sheep tự gọi kill() + queue_free + sinh xác qua _add_node.
		died.emit(self)
		main_ref.kill_sheep(self)
		return
	alive = false
	remove_from_group("animals")
	remove_from_group("sheep")
	died.emit(self)
	var parent := get_parent()
	if parent != null:
		var carcass := ResourceNode.new()
		carcass.setup("meat", false)
		carcass.position = global_position
		carcass.z_index = z_index
		parent.add_child(carcass)
	if _brain != null:
		_brain.set_process(false)
	if _anim != null:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_anim, "rotation", deg_to_rad(78.0), 0.35)
		tw.tween_property(self, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()
