class_name HerdKeeper
extends Node2D

## NGƯỜI GIỮ ĐÀN — "hồi sinh tài nguyên sống": giữ số cừu trong 1 bãi chăn
## quanh điểm này ở mức trần (herd_cap); đàn bị săn/thiếu thì hồi sinh CHẬM
## (herd_respawn_time/con) cho tới khi đủ trần. Đây là cơ chế regen của cừu
## trong Stats.ANIMALS; đặt 1 HerdKeeper ở mỗi vùng trung lập khi tích hợp.

var radius: float = 220.0
var cap: int = 6
var respawn_time: float = 20.0

var _check_left: float = 0.0
var _progress: float = 0.0
var _rng := RandomNumberGenerator.new()

func setup(p_radius: float = -1.0, p_cap: int = -1, p_respawn: float = -1.0) -> void:
	radius = float(Stats.ANIMALS["herd_radius"]) if p_radius < 0.0 else p_radius
	cap = int(Stats.ANIMALS["herd_cap"]) if p_cap < 0 else p_cap
	respawn_time = float(Stats.ANIMALS["herd_respawn_time"]) if p_respawn < 0.0 else p_respawn
	_rng.randomize()

func herd_count() -> int:
	var tree := get_tree()
	if tree == null:
		return 0 # node đang ngoài cây (vừa tạo/chưa add hoặc đang dọn) -> đàn = 0
	var c := 0
	for n in tree.get_nodes_in_group("animals"):
		var s := n as Sheep
		if s != null and not s.is_dead() and global_position.distance_to(s.global_position) <= radius:
			c += 1
	return c

func spawn_one() -> Sheep:
	var parent := get_parent()
	if parent == null:
		return null
	var s := Sheep.new()
	var ang := _rng.randf() * TAU
	var dist := _rng.randf_range(radius * 0.25, radius * 0.85)
	s.position = global_position + Vector2(cos(ang), sin(ang)) * dist
	s.z_index = 10
	parent.add_child(s)
	return s

func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 1.0 # nhịp kiểm tra đàn: 1s/lần
	if herd_count() >= cap:
		_progress = 0.0
		return
	_progress += 1.0
	if _progress >= respawn_time:
		_progress = 0.0
		spawn_one()
