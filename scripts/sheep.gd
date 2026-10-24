class_name Sheep
extends Node2D

## Cừu TRUNG LẬP: lang thang ăn cỏ quanh điểm sinh. Không thuộc phe nào,
## không đánh ai. Nông dân săn bằng dao (Pawn_Interact Knife) -> cừu chết
## thành XÁC THỊT (ResourceNode loại "meat") tại chỗ; nông dân xẻ thịt
## ở xác rồi VÁC THỊT VỀ KHO mới được cộng (như mọi tài nguyên khác).
## Sprite: Free Pack Sheep_Idle (6 frame) / Sheep_Move (4 frame) /
## Sheep_Grass (12 frame), frame 128px (ASSETS.md §3).

const FRAME := 128.0

var hp: float = 25.0
var alive: bool = true
var home: Vector2 = Vector2.ZERO
var main_ref: Node = null

var _anim: AnimatedSprite2D
var _cur_anim: String = ""
var _walking: bool = false
var _target: Vector2 = Vector2.ZERO
var _wait_left: float = 0.0
var _rng := RandomNumberGenerator.new()

func setup(p_main: Node, p_home: Vector2, p_seed: int) -> void:
	main_ref = p_main
	home = p_home
	hp = float(Stats.SHEEP["hp"])
	_rng.seed = p_seed
	_wait_left = _rng.randf_range(0.5, 3.0)

func _ready() -> void:
	add_to_group("sheep")
	_anim = AnimatedSprite2D.new()
	_anim.scale = Vector2(0.55, 0.55)
	_anim.position = Vector2(0, -14)
	_anim.sprite_frames = _build_frames()
	add_child(_anim)
	_play("grass")

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

func _play(anim_name: String) -> void:
	if _cur_anim != anim_name:
		_cur_anim = anim_name
		_anim.play(anim_name)

func _process(delta: float) -> void:
	if not alive:
		return
	if _walking:
		var dir := _target - global_position
		if dir.length() < 4.0:
			_walking = false
			_wait_left = _rng.randf_range(1.5, 5.0)
			_play("grass" if _rng.randf() < 0.6 else "idle")
		else:
			dir = dir.normalized()
			global_position += dir * float(Stats.SHEEP["speed"]) * delta
			if absf(dir.x) > 0.1:
				_anim.flip_h = dir.x < 0.0
			_play("move")
	else:
		_wait_left -= delta
		if _wait_left <= 0.0:
			var r := float(Stats.SHEEP["wander_radius"])
			_target = home + Vector2(_rng.randf_range(-r, r), _rng.randf_range(-r * 0.6, r * 0.6))
			_walking = true

## Bị săn: chết tại chỗ (Main sinh xác thịt ở vị trí này).
func kill() -> void:
	alive = false
