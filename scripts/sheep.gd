class_name Sheep
extends Node2D

## Cừu — thú trung lập ăn cỏ (nguồn thịt). Thân chứa: sprite + máu + chết ->
## xác thịt; BỘ NÃO là component AnimalAI gắn kèm (dùng lại cho loài khác).
## Chết -> để lại 1 điểm tài nguyên "meat" (ResourceNode) tại chỗ, đúng mô
## hình giai đoạn 2: xác = nguồn thịt cho nông dân xẻ qua API take().

signal died(sheep: Sheep)

const FRAME := 128.0

var hp: float = 0.0
var max_hp: float = 0.0

var _dead: bool = false
var _anim: AnimatedSprite2D = null
var _cur_anim: String = ""
var _brain: AnimalAI = null

func _ready() -> void:
	add_to_group("animals")
	max_hp = float(Stats.ANIMALS["sheep_hp"])
	hp = max_hp
	_anim = AnimatedSprite2D.new()
	_anim.scale = Vector2(0.55, 0.55)
	_anim.position = Vector2(0, -16)
	_anim.sprite_frames = _build_frames()
	add_child(_anim)
	play_anim("idle")
	_brain = AnimalAI.new()
	add_child(_brain)
	_brain.setup(self, Stats.ANIMALS)

func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	_add_anim(sf, "idle", "res://assets/animals/sheep_idle.png", 6, 6.0)
	_add_anim(sf, "move", "res://assets/animals/sheep_move.png", 4, 8.0)
	_add_anim(sf, "grass", "res://assets/animals/sheep_grass.png", 12, 8.0)
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
	return _dead

func ai_state() -> String:
	return _brain.current_state() if _brain != null else ""

# --- Sát thương / chết ---
func take_damage(amount: float, _attacker_pid: int) -> void:
	if _dead:
		return
	hp -= amount
	if hp <= 0.0:
		_die()
	elif _brain != null:
		_brain.startle()

func _die() -> void:
	_dead = true
	remove_from_group("animals")
	died.emit(self)
	# Để lại xác thịt tại chỗ cho nông dân xẻ (ResourceNode loại "meat").
	var parent := get_parent()
	if parent != null:
		var carcass := ResourceNode.new()
		carcass.setup("meat", false)
		carcass.max_amount = int(Stats.ANIMALS["sheep_meat"])
		carcass.amount = carcass.max_amount
		carcass.position = global_position
		carcass.z_index = z_index
		parent.add_child(carcass)
	# Thân ngã + mờ dần rồi biến mất.
	if _brain != null:
		_brain.set_process(false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_anim, "rotation", deg_to_rad(78.0), 0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(queue_free)
