class_name Projectile
extends Node2D

## Tên bay: đuổi theo mục tiêu, chỉ trừ máu khi bay tới nơi.

var target = null # Unit hoặc Structure (duck-type: take_damage/is_alive/get_aim_point)
var speed: float = 430.0
var damage: float = 0.0
var owner_pid: int = -1
var _sprite: Sprite2D

func setup(p_from: Vector2, p_target, p_damage: float, p_owner: int, p_speed: float, arrow_tex: Texture2D) -> void:
	global_position = p_from
	target = p_target
	damage = p_damage
	owner_pid = p_owner
	speed = p_speed
	add_to_group("projectiles")
	_sprite = Sprite2D.new()
	_sprite.texture = arrow_tex
	_sprite.scale = Vector2(0.55, 0.55)
	add_child(_sprite)

func _process(delta: float) -> void:
	if not is_instance_valid(target) or (target.has_method("is_alive") and not target.is_alive()):
		queue_free()
		return
	var aim: Vector2 = target.global_position
	if target.has_method("get_aim_point"):
		aim = target.get_aim_point()
	var to := aim - global_position
	if to.length() <= 14.0:
		target.take_damage(damage, owner_pid)
		queue_free()
		return
	var dir := to.normalized()
	global_position += dir * speed * delta
	rotation = dir.angle()
