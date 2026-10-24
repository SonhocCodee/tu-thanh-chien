class_name ResourceNode
extends Node2D

## Điểm tài nguyên HỮU HẠN trên map (M2 giai đoạn 2 — thay bản vô hạn của M1):
## cây gỗ / cụm đá xám / quặng vàng / MỎ VÀNG lớn / xác cừu (thịt).
## Mỗi điểm có trữ lượng `amount`; nông dân khai thác trừ dần, cạn thì:
##   - cây: ĐỔ (hoạt ảnh ngã xoay + mờ) rồi chỉ CÒN GỐC (sprite Stump) nằm lại hẳn.
##   - đá / quặng vàng nhỏ / xác thịt: biến mất.
##   - mỏ vàng lớn: hiện đống đổ nát GoldMine_Destroyed một lúc rồi biến mất.
## Sprite lấy đúng ASSETS.md §3 — node đá dùng đá XÁM Rock1/2 (CẤM dùng lại
## stone.png cũ = icon thịt), node vàng nhỏ dùng quặng Gold Stone, mỏ lớn dùng
## bộ GoldMine Active/Inactive/Destroyed.

signal depleted(node: ResourceNode)
signal regrown(node: ResourceNode)

var res_type: String = "wood" # wood | stone | gold | meat
var is_big: bool = false
var amount: int = 0
var max_amount: int = 0
var variant: int = 0 # biến thể sprite (đá 1/2, quặng 1..6, gốc 1..4)

var _sprite: Sprite2D = null
var _crack_overlay: CrackOverlay = null
var _depleted: bool = false # đã cạn (không khai thác được nữa)
var _is_stump: bool = false # cây đã cạn -> chỉ còn gốc
var _rubble_left: float = -1.0 # >0: đang là đống đổ nát của mỏ, đếm ngược để biến mất
var _falling: bool = false
# Port từ nhánh AI: rung khi bị khai thác + đếm ngược MỌC LẠI của cây.
var _shake_left: float = 0.0
var _regen_left: float = -1.0 # >0 khi đang là gốc chờ mọc lại (chỉ cây, regen_time=90s)
var _spr_base_pos: Vector2 = Vector2.ZERO
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

## Lớp vẽ vết nứt — PHẢI là node con vẽ SAU sprite đá (z cao hơn trong cùng
## cha) thì nét nứt mới nằm TRÊN mặt đá; vẽ ở _draw của chính ResourceNode
## sẽ bị sprite con đè lên (lỗi bản gộp đầu — đã sửa).
class CrackOverlay:
	extends Node2D
	var node: ResourceNode = null
	func _draw() -> void:
		if node == null or node.res_type != "stone" or node.is_depleted() or node._sprite == null:
			return
		var lvl := node.crack_level()
		if lvl <= 0:
			return
		var n_cracks: int = [0, 2, 4, 7][lvl]
		var center: Vector2 = node._sprite.position
		var scl: float = node._sprite.scale.x
		for i in n_cracks:
			var pts: PackedVector2Array = []
			for p in node._CRACKS[i]:
				pts.append(center + (p as Vector2) * scl * 0.55)
			draw_polyline(pts, Color(0.08, 0.09, 0.1, 0.6), 1.6)

func setup(p_type: String, p_big: bool, p_variant: int = 0) -> void:
	res_type = p_type
	is_big = p_big
	variant = p_variant
	_rng.randomize()
	if p_type == "meat":
		max_amount = int(Stats.SHEEP["meat"])
	else:
		var table: Dictionary = Stats.NODE_AMOUNTS[p_type]
		max_amount = int(table["big" if p_big else "small"])
	amount = max_amount
	add_to_group("res_nodes")
	_sprite = Sprite2D.new()
	_refresh_sprite()
	add_child(_sprite)
	_crack_overlay = CrackOverlay.new()
	_crack_overlay.node = self
	_crack_overlay.z_index = 1
	add_child(_crack_overlay)

## Đặt trữ lượng tùy ý (dùng cho sân khấu demo/test cạn nhanh).
func set_amount(value: int) -> void:
	amount = clampi(value, 0, max_amount)
	if amount <= 0 and not _depleted:
		_on_depleted()

func is_depleted() -> bool:
	return _depleted

func is_stump() -> bool:
	return _is_stump

# --- API tỉ lệ / trạng thái (port từ nhánh AI, giữ nguyên ngữ nghĩa) ---
func remaining_fraction() -> float:
	if max_amount <= 0:
		return 0.0
	return clampf(float(amount) / float(max_amount), 0.0, 1.0)

func depletion_fraction() -> float:
	return 1.0 - remaining_fraction()

func is_available() -> bool:
	return not _depleted and amount > 0

## Mức nứt của đá theo tỉ lệ còn lại: 0 = nguyên, 1/2/3 = nứt dần.
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

## Giây để điểm cạn hồi lại đầy (0 = không hồi). Chỉ cây có regen (90s).
func regen_time() -> float:
	if res_type == "meat":
		return 0.0
	var table: Dictionary = Stats.NODE_AMOUNTS.get(res_type, {})
	return float(table.get("regen_time", 0.0))

func state_name() -> String:
	if _falling:
		return "falling"
	if _is_stump:
		return "stump"
	if _depleted:
		return "destroyed" if res_type == "gold" else "gone"
	return "ready"

## Nông dân kết thúc 1 lượt khai thác: lấy tối đa `capacity`, trả số lấy được.
func take_harvest(capacity: int) -> int:
	if _depleted or amount <= 0:
		return 0
	var take := mini(capacity, amount)
	amount -= take
	# Bị chặt/đào: rung nhẹ (đá rung yếu hơn cây) — port từ nhánh AI.
	_shake_left = 0.22 if res_type == "wood" else 0.12
	if res_type == "stone" or (res_type == "gold" and not is_big):
		_update_size_by_amount()
	if res_type == "stone" and _sprite != null:
		# Đá SẪM MÀU dần theo độ cạn (kèm vết nứt ở lớp CrackOverlay) để đọc mức từ xa.
		var dark := 1.0 - depletion_fraction() * 0.45
		_sprite.modulate = Color(dark, dark, dark * 1.05)
		if _crack_overlay != null:
			_crack_overlay.queue_redraw()
	if amount <= 0:
		_on_depleted()
	return take

func _refresh_sprite() -> void:
	if _sprite == null:
		return
	match res_type:
		"wood":
			if _is_stump:
				_sprite.texture = load("res://assets/resources/stump%d.png" % (variant % 4 + 1))
				# Canvas Stump 192x256 gần như trong suốt: hình gốc thật chỉ
				# ~24x34px ở đáy canvas (đo bbox pixel đặc) — phải phóng to
				# và nâng vị trí để đáy gốc chạm đúng điểm node, không là
				# 12x17px vô hình như scale 0.5 ban đầu.
				_sprite.scale = Vector2(1.3, 1.3)
				_sprite.position = Vector2(0, -140)
			else:
				var at := AtlasTexture.new()
				at.atlas = load("res://assets/deco/tree.png")
				at.region = Rect2(0, 0, 256, 256)
				_sprite.texture = at
				_sprite.scale = Vector2(0.62, 0.62) if is_big else Vector2(0.44, 0.44)
				_sprite.position = Vector2(0, -46)
		"stone":
			# Đá XÁM Rock1/2 — nhìn vào phải ra ĐÁ (ASSETS.md §2.1).
			_sprite.texture = load("res://assets/deco/rock%d.png" % (variant % 2 + 1))
			_sprite.position = Vector2(0, -14)
			_update_size_by_amount()
		"gold":
			if is_big:
				# MỎ VÀNG lớn: cửa mỏ 3 trạng thái (ASSETS.md §2.2).
				if _depleted:
					_sprite.texture = load("res://assets/resources/goldmine_destroyed.png")
				elif amount < max_amount:
					_sprite.texture = load("res://assets/resources/goldmine_active.png")
				else:
					_sprite.texture = load("res://assets/resources/goldmine_inactive.png")
				_sprite.scale = Vector2(1.05, 1.05)
				_sprite.position = Vector2(0, -26)
			else:
				# Quặng vàng Gold Stone — cục quặng, đọc rõ là VÀNG.
				_sprite.texture = load("res://assets/resources/gold_stone%d.png" % (variant % 6 + 1))
				_sprite.position = Vector2(0, -14)
				_update_size_by_amount()
		"meat":
			_sprite.texture = load("res://assets/resources/meat.png")
			_sprite.scale = Vector2(0.85, 0.85)
			_sprite.position = Vector2(0, -12)
	_spr_base_pos = _sprite.position

func _update_size_by_amount() -> void:
	if _sprite == null or max_amount <= 0:
		return
	var frac := clampf(float(amount) / float(max_amount), 0.0, 1.0)
	var base := 1.7 if is_big else 1.25
	var s := base * (0.55 + 0.45 * frac)
	_sprite.scale = Vector2(s, s)

func _on_depleted() -> void:
	_depleted = true
	remove_from_group("res_nodes")
	depleted.emit(self)
	match res_type:
		"wood":
			# Cây ĐỔ: xoay ngã + mờ dần, xong CÒN GỐC; gốc MỌC LẠI cây đầy
			# sau regen_time (90s — xem _show_stump/_regrow).
			_is_stump = true
			_falling = true
			var tw := create_tween()
			tw.tween_property(_sprite, "rotation", 1.35, 0.45)
			tw.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.45)
			tw.tween_callback(_show_stump)
		"stone":
			# Đá cạn -> VỠ TAN thành mảnh vụn rồi biến mất (port từ nhánh AI).
			_shatter()
		"gold":
			if is_big:
				_refresh_sprite() # -> GoldMine_Destroyed
				_rubble_left = float(Stats.GOLDMINE_RUBBLE_TIME)
			else:
				queue_free()
		_:
			queue_free()

func _show_stump() -> void:
	_falling = false
	if _sprite == null:
		return
	_sprite.rotation = 0.0
	_sprite.modulate = Color.WHITE
	_refresh_sprite()
	# Gốc chờ mọc lại (chỉ khi regen_time > 0 — cây = 90s theo user chốt).
	var rt := regen_time()
	if rt > 0.0:
		_regen_left = rt

## Cây mọc lại từ gốc: đầy trữ lượng, trở lại group cho nông dân farm tiếp.
func _regrow() -> void:
	_regen_left = -1.0
	amount = max_amount
	_depleted = false
	_is_stump = false
	add_to_group("res_nodes")
	if _sprite != null:
		_sprite.rotation = 0.0
		_sprite.modulate = Color.WHITE
		_refresh_sprite()
		# Hiệu ứng lớn dần cho đọc được "cây non mọc lại".
		var target_scale := _sprite.scale
		_sprite.scale = target_scale * 0.55
		var tw := create_tween()
		tw.tween_property(_sprite, "scale", target_scale, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	regrown.emit(self)
	if _crack_overlay != null:
		_crack_overlay.queue_redraw()

## Đá vỡ: vài mẩu đá nhỏ bay ra + mờ dần (nuôi bởi node cha để sống sót
## qua lúc điểm này tự huỷ) — port từ nhánh AI.
func _shatter() -> void:
	var parent := get_parent()
	if parent != null and _sprite != null:
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

func _process(delta: float) -> void:
	if _rubble_left > 0.0:
		_rubble_left -= delta
		if _rubble_left <= 0.0:
			queue_free()
	# Rung khi bị khai thác (chỉ khi điểm còn farm được).
	if _shake_left > 0.0 and _sprite != null and not _depleted:
		_shake_left -= delta
		var amp := 2.2 * clampf(_shake_left / 0.22, 0.0, 1.0)
		_sprite.position = _spr_base_pos + Vector2(_rng.randf_range(-amp, amp), 0)
		if _shake_left <= 0.0:
			_sprite.position = _spr_base_pos
	# Gốc cây đếm ngược mọc lại.
	if _is_stump and _regen_left > 0.0:
		_regen_left -= delta
		if _regen_left <= 0.0:
			_regrow()
