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

var res_type: String = "wood" # wood | stone | gold | meat
var is_big: bool = false
var amount: int = 0
var max_amount: int = 0
var variant: int = 0 # biến thể sprite (đá 1/2, quặng 1..6, gốc 1..4)

var _sprite: Sprite2D = null
var _depleted: bool = false # đã cạn (không khai thác được nữa)
var _is_stump: bool = false # cây đã cạn -> chỉ còn gốc
var _rubble_left: float = -1.0 # >0: đang là đống đổ nát của mỏ, đếm ngược để biến mất
var _falling: bool = false

func setup(p_type: String, p_big: bool, p_variant: int = 0) -> void:
	res_type = p_type
	is_big = p_big
	variant = p_variant
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

## Đặt trữ lượng tùy ý (dùng cho sân khấu demo/test cạn nhanh).
func set_amount(value: int) -> void:
	amount = clampi(value, 0, max_amount)
	if amount <= 0 and not _depleted:
		_on_depleted()

func is_depleted() -> bool:
	return _depleted

func is_stump() -> bool:
	return _is_stump

## Nông dân kết thúc 1 lượt khai thác: lấy tối đa `capacity`, trả số lấy được.
func take_harvest(capacity: int) -> int:
	if _depleted or amount <= 0:
		return 0
	var take := mini(capacity, amount)
	amount -= take
	if res_type == "stone" or (res_type == "gold" and not is_big):
		_update_size_by_amount()
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
			# Cây ĐỔ: xoay ngã + mờ dần, xong chỉ CÒN GỐC nằm lại hẳn.
			_is_stump = true
			_falling = true
			var tw := create_tween()
			tw.tween_property(_sprite, "rotation", 1.35, 0.45)
			tw.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.45)
			tw.tween_callback(_show_stump)
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

func _process(delta: float) -> void:
	if _rubble_left > 0.0:
		_rubble_left -= delta
		if _rubble_left <= 0.0:
			queue_free()
