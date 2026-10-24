class_name AnimalAI
extends Node

## Component AI THÚ TRUNG LẬP — dùng lại được cho mọi loài thú ăn cỏ.
## Gắn vào 1 "thân" Node2D có giao diện tối thiểu:
##   play_anim(name: String)  với name thuộc {"idle", "move", "grass"}
##   face_dir(dx: float)      lật sprite theo hướng ngang
##   is_dead() -> bool
## Chu trình trạng thái:
##   graze (gặm cỏ) -> wander (lang thang chậm quanh nhà) -> idle/graze ...
##   flee: bị đánh hoặc quân áp sát trong scare_range -> chạy trốn một đoạn
##         rồi quay lại chu trình. Thú KHÔNG đánh trả.
## Quét nguy hiểm theo nhịp thưa lệch pha (Stats.ANIMALS["scan_interval"]).

var body: Node2D = null
var cfg: Dictionary = {}
var state: String = "graze" # graze | wander | idle | flee
var home_point: Vector2 = Vector2.ZERO

var _state_left: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _flee_left: float = 0.0
var _threat_pos: Vector2 = Vector2.ZERO
var _has_threat: bool = false
var _scan_left: float = 0.0
var _rng := RandomNumberGenerator.new()

func setup(p_body: Node2D, p_cfg: Dictionary) -> void:
	body = p_body
	cfg = p_cfg
	home_point = p_body.global_position
	_rng.randomize()
	_scan_left = float(cfg.get("scan_interval", 0.2)) * _rng.randf()
	_enter("graze")

func current_state() -> String:
	return state

## Thân bị đánh: hoảng + chạy trốn khỏi hướng mối nguy gần nhất.
func startle() -> void:
	var threat := _nearest_threat(float(cfg.get("scare_range", 64.0)) * 3.0)
	if threat != null:
		_threat_pos = threat.global_position
		_has_threat = true
	_flee_left = float(cfg.get("flee_time", 1.2))
	_enter("flee")

func _enter(next: String) -> void:
	state = next
	_has_target = false
	match next:
		"graze":
			_state_left = _rng.randf_range(float(cfg["graze_time_min"]), float(cfg["graze_time_max"]))
			body.play_anim("grass")
		"idle":
			_state_left = _rng.randf_range(float(cfg["idle_time_min"]), float(cfg["idle_time_max"]))
			body.play_anim("idle")
		"wander":
			body.play_anim("move")
		"flee":
			body.play_anim("move")

func _process(delta: float) -> void:
	if body == null or not is_instance_valid(body) or body.is_dead():
		return
	# Quét nguy hiểm: bất kỳ QUÂN nào (mọi phe — thú là trung lập) áp sát
	# trong scare_range đều làm thú bỏ chạy.
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = float(cfg.get("scan_interval", 0.2))
		if state != "flee":
			var threat := _nearest_threat(float(cfg.get("scare_range", 64.0)))
			if threat != null:
				_threat_pos = threat.global_position
				_has_threat = true
				_flee_left = float(cfg.get("flee_time", 1.2))
				_enter("flee")
	match state:
		"graze", "idle":
			_state_left -= delta
			if _state_left <= 0.0:
				_enter("wander" if _rng.randf() < 0.65 else ("graze" if state == "idle" else "idle"))
		"wander":
			if not _has_target:
				var r := float(cfg.get("wander_radius", 110.0))
				_wander_target = home_point + Vector2(_rng.randf_range(-r, r), _rng.randf_range(-r, r))
				_wander_target = _clamp_world(_wander_target)
				_has_target = true
			if _move_body(_wander_target, float(cfg.get("wander_speed", 22.0)), delta):
				_enter("graze")
		"flee":
			_flee_left -= delta
			var from := _threat_pos if _has_threat else home_point
			var dir := body.global_position - from
			if dir.length() < 0.01:
				dir = Vector2.RIGHT.rotated(_rng.randf() * TAU)
			dir = dir.normalized()
			var dest := _clamp_world(body.global_position + dir * float(cfg.get("flee_speed", 95.0)) * delta)
			body.face_dir(dest.x - body.global_position.x)
			body.global_position = dest
			if _flee_left <= 0.0:
				_has_threat = false
				_enter("graze")

func _move_body(to: Vector2, speed: float, delta: float) -> bool:
	var diff := to - body.global_position
	if diff.length() <= 4.0:
		return true
	var dir := diff.normalized()
	body.face_dir(dir.x)
	body.global_position += dir * speed * delta
	return false

func _nearest_threat(range_px: float) -> Node2D:
	var best: Node2D = null
	var best_d := range_px
	for n in body.get_tree().get_nodes_in_group("units"):
		var u := n as Node2D
		if u == null:
			continue
		if u is Unit and not (u as Unit).is_alive():
			continue
		var d := body.global_position.distance_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best

func _clamp_world(p: Vector2) -> Vector2:
	# Map game 1920x960 (khớp Stats/main WORLD); thú sống trong bãi của nó
	# nên chỉ cần kẹp biên an toàn.
	return Vector2(clampf(p.x, 20.0, 1900.0), clampf(p.y, 20.0, 940.0))
