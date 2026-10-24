class_name ResourceNode
extends Node2D

## Điểm tài nguyên trên map: cây gỗ / mỏ đá / mỏ vàng / xác thịt (do cừu để lại).
##
## API "MỐI NỐI TÍCH HỢP" — giai đoạn 2 (kinh tế hữu hạn) lái cùng các hàm này,
## không cần biết hiệu ứng bên trong:
##   amount / max_amount          trữ lượng hiện tại / tối đa
##   remaining_fraction()         1.0 = đầy -> 0.0 = cạn
##   depletion_fraction()         0.0 = đầy -> 1.0 = cạn
##   is_depleted() / is_available()
##   take(n) -> int               lấy tối đa n, trả về số THỰC lấy được (0 nếu
##                                điểm đang gốc/sập/không farm được); tự kích
##                                hiệu ứng cạn khi về 0.
##   regen: Stats.RESOURCE_NODES[type]["regen_time"] giây (0 = không hồi).
##     Cây: cạn -> ĐỔ + còn GỐC -> mọc lại đầy sau regen_time.
##     Đá:  cạn -> VỠ TAN (mảnh vụn) rồi biến mất. Nứt dần theo tỉ lệ cạn.
##     Vàng: cạn -> sprite Destroyed, ở lại làm phế tích (không farm được).
##     Thịt: cạn -> biến mất (xác đã xẻ hết).

signal depleted(node: ResourceNode)
signal regrown(node: ResourceNode)

var res_type: String = "wood" # wood | stone | gold | meat
var is_big: bool = false
var amount: int = 0
var max_amount: int = 0

var _state: String = "ready" # ready | falling | stump | destroyed | gone
var _spr: Sprite2D = null
var _stump_spr: Sprite2D = null
var _spr_base_pos: Vector2 = Vector2.ZERO
var _spr_base_scale: Vector2 = Vector2.ONE
var _shake_left: float = 0.0
var _regen_left: float = -1.0
var _fall_dir: float = 1.0
var _rng := RandomNumberGenerator.new()

# Vết nứt đá: các polyline (tọa độ local quanh tâm sprite), hiện dần theo mức cạn.
const _CRACKS: Array = [
	[Vector2(-6, -26), Vector2(-2, -14), Vector2(-7, -4)],
	[Vector2(10, -24), Vector2(6, -12), Vector2(11, -2)],
	[Vector2(-16, -16), Vector2(-8, -10), Vector2(-12, 0)],
	[Vector2(2, -28), Vector2(0, -16), Vector2(4, -6), Vector2(1, 2)],
	[Vector2(16, -12), Vector2(9, -6), Vector2(13, 3)],
	[Vector2(-3, -10), Vector2(-10, -3), Vector2(-6, 5)],
	[Vector2(6, -8), Vector2(12, -1), Vector2(8, 6)],
]

func setup(p_type: String, p_big: bool) -> void:
	res_type = p_type
	is_big = p_big
	_rng.randomize()
	add_to_group("res_nodes")
	var def: Dictionary = Stats.RESOURCE_NODES.get(p_type, {"amount": 100, "big_amount": 100, "regen_time": 0.0})
	max_amount = int(def["big_amount"]) if p_big else int(def["amount"])
	amount = max_amount
	_spr = Sprite2D.new()
	match p_type:
		"wood":
			var at := AtlasTexture.new()
			at.atlas = load("res://assets/deco/tree.png")
			at.region = Rect2(0, 0, 256, 256)
			_spr.texture = at
			_spr_base_scale = Vector2(0.62, 0.62) if p_big else Vector2(0.44, 0.44)
			_spr_base_pos = Vector2(0, -46)
			# Gốc cây (ẩn cho tới khi cây đổ): biến thể 1-4 ngẫu nhiên theo điểm.
			_stump_spr = Sprite2D.new()
			_stump_spr.texture = load("res://assets/deco/stump%d.png" % _rng.randi_range(1, 4))
			_stump_spr.scale = _spr_base_scale
			_stump_spr.position = _spr_base_pos
			_stump_spr.visible = false
			add_child(_stump_spr)
		"stone":
			# Đá XÁM của pack (Rock1) — cấm dùng stone.png (icon thịt, xem ASSETS.md §2.1).
			_spr.texture = load("res://assets/deco/rock1.png")
			_spr_base_scale = Vector2(1.9, 1.9) if p_big else Vector2(1.35, 1.35)
			_spr_base_pos = Vector2(0, -12)
		"gold":
			_spr.texture = load("res://assets/resources/goldmine.png")
			_spr_base_scale = Vector2(1.05, 1.05) if p_big else Vector2(0.72, 0.72)
			_spr_base_pos = Vector2(0, -16)
		"meat":
			_spr.texture = load("res://assets/animals/meat_resource.png")
			_spr_base_scale = Vector2(1.0, 1.0)
			_spr_base_pos = Vector2(0, -8)
	_spr.scale = _spr_base_scale
	_spr.position = _spr_base_pos
	add_child(_spr)

# ===================== API TRỮ LƯỢNG =====================

func remaining_fraction() -> float:
	if max_amount <= 0:
		return 0.0
	return clampf(float(amount) / float(max_amount), 0.0, 1.0)

func depletion_fraction() -> float:
	return 1.0 - remaining_fraction()

func is_depleted() -> bool:
	return amount <= 0 or _state != "ready"

func is_available() -> bool:
	return _state == "ready" and amount > 0

func state_name() -> String:
	return _state

## Mức nứt của đá theo tỉ lệ cạn: 0 = nguyên, 1/2/3 = nứt dần.
func crack_level() -> int:
	if res_type != "stone":
		return 0
	var f := remaining_fraction()
	if f > 0.75:
		return 0
	if f > 0.5:
		return 1
	if f > 0.25:
		return 2
	return 3

func regen_time() -> float:
	var def: Dictionary = Stats.RESOURCE_NODES.get(res_type, {})
	return float(def.get("regen_time", 0.0))

func take(n: int) -> int:
	if not is_available() or n <= 0:
		return 0
	var got := mini(n, amount)
	amount -= got
	_on_hit()
	# Đá sẫm màu dần theo độ cạn (kèm vết nứt vẽ ở _draw) để đọc mức từ xa.
	if res_type == "stone" and _spr != null:
		var dark := 1.0 - depletion_fraction() * 0.45
		_spr.modulate = Color(dark, dark, dark * 1.05)
	if amount <= 0:
		_on_depleted()
	queue_redraw()
	return got

# ===================== HIỆU ỨNG =====================

func _on_hit() -> void:
	# Bị chặt/đào/đập: rung nhẹ (đá rung yếu hơn cây).
	_shake_left = 0.22 if res_type == "wood" else 0.12

func _process(delta: float) -> void:
	# Rung khi bị khai thác.
	if _shake_left > 0.0 and _spr != null and _state == "ready":
		_shake_left -= delta
		var amp := 2.2 * clampf(_shake_left / 0.22, 0.0, 1.0)
		_spr.position = _spr_base_pos + Vector2(_rng.randf_range(-amp, amp), 0)
		if _shake_left <= 0.0:
			_spr.position = _spr_base_pos
	# Cây mọc lại từ gốc.
	if _state == "stump" and _regen_left > 0.0:
		_regen_left -= delta
		if _regen_left <= 0.0:
			_regrow()

func _on_depleted() -> void:
	depleted.emit(self)
	match res_type:
		"wood":
			_fall_tree()
		"stone":
			_shatter()
		"gold":
			_state = "destroyed"
			if _spr != null:
				_spr.texture = load("res://assets/resources/goldmine_destroyed.png")
		"meat":
			_state = "gone"
			queue_free()

func _fall_tree() -> void:
	_state = "falling"
	_fall_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	if _spr == null:
		_become_stump()
		return
	# Xoay quanh CHÂN cây: tâm sprite chạy theo cung để gốc đứng yên tại chỗ.
	var half_h := 128.0 * _spr_base_scale.y # nửa chiều cao sprite (frame 256px)
	var base_point := _spr_base_pos + Vector2(0, half_h)
	var target := _fall_dir * deg_to_rad(82.0)
	var tw := create_tween()
	tw.tween_method(_apply_fall.bind(base_point, half_h), 0.0, target, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_spr, "modulate:a", 0.0, 0.15)
	tw.tween_callback(_become_stump)

func _apply_fall(angle: float, base_point: Vector2, half_h: float) -> void:
	if _spr == null:
		return
	_spr.rotation = angle
	_spr.position = base_point - Vector2(0, half_h).rotated(angle)

func _become_stump() -> void:
	_state = "stump"
	if _spr != null:
		_spr.visible = false
	if _stump_spr != null:
		_stump_spr.visible = true
	var rt := regen_time()
	if rt > 0.0:
		_regen_left = rt

func _regrow() -> void:
	amount = max_amount
	_state = "ready"
	if _stump_spr != null:
		_stump_spr.visible = false
	if _spr != null:
		_spr.visible = true
		_spr.rotation = 0.0
		_spr.position = _spr_base_pos
		_spr.modulate.a = 1.0
		_spr.scale = _spr_base_scale * 0.55
		var tw := create_tween()
		tw.tween_property(_spr, "scale", _spr_base_scale, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	regrown.emit(self)
	queue_redraw()

func _shatter() -> void:
	_state = "gone"
	# Mảnh vụn: vài mẩu đá nhỏ bay ra + mờ dần, nuôi bởi node cha để sống sót
	# qua lúc điểm này tự huỷ.
	var parent := get_parent()
	if parent != null and _spr != null:
		for i in 6:
			var piece := Sprite2D.new()
			piece.texture = load("res://assets/deco/rock2.png")
			piece.scale = Vector2.ONE * _rng.randf_range(0.22, 0.45)
			piece.position = global_position + Vector2(0, -12)
			piece.z_index = z_index + 1
			parent.add_child(piece)
			var dir := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.7, 0.2)).normalized()
			var dist := _rng.randf_range(18.0, 42.0)
			var tw := piece.create_tween()
			tw.set_parallel(true)
			tw.tween_property(piece, "position", piece.position + dir * dist + Vector2(0, 10), 0.55) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(piece, "modulate:a", 0.0, 0.55)
			tw.chain().tween_callback(piece.queue_free)
	queue_free()

func _draw() -> void:
	# Vết nứt đá theo mức cạn (vẽ quanh tâm sprite).
	if res_type != "stone" or _state != "ready":
		return
	var lvl := crack_level()
	if lvl <= 0:
		return
	var n_cracks: int = [0, 2, 4, 7][lvl]
	var center := _spr_base_pos
	var scl := 1.35 if not is_big else 1.9
	for i in n_cracks:
		var pts: PackedVector2Array = []
		for p in _CRACKS[i]:
			pts.append(center + (p as Vector2) * scl * 0.55)
		draw_polyline(pts, Color(0.08, 0.09, 0.1, 0.6), 1.6)
