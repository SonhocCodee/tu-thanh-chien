class_name Structure
extends Node2D

## Lớp nền cho mọi công trình (thành chính + nhà/doanh trại/tháp):
## máu, cháy dưới 50%, sập, hàng chờ huấn luyện, và "snapshot hiển thị"
## phục vụ sương mù (vùng MỜ của người chơi thấy trạng thái lần cuối được nhìn).

signal structure_destroyed(structure: Structure)

var owner_pid: int = -1
var color_key: String = "blue"
var hp: float = 0.0
var max_hp: float = 0.0
var radius: float = 40.0
var destroyed: bool = false
var main_ref: Node = null
var producer_kind: String = "" # "" = không sản xuất | "castle" | "barracks"

# --- Sổ chứa tài nguyên (kho chuyên dụng + thành chính) ---
# Lượng chứa trong TỪNG công trình là số thật; tổng tài nguyên của phe
# (PlayerState.resources) luôn = thành chính + tổng các kho. Mọi cộng/trừ
# đi qua các điểm tập trung ở Main: deposit_to / spend_resources / cướp kho.
var stored: Dictionary = {"wood": 0, "stone": 0, "gold": 0, "meat": 0}
var last_attacker_pid: int = -1 # pid của kẻ gây đòn gần nhất (để tính cướp kho)

var train_queue: Array = [] # [{unit_type, time_left, total}]

# Snapshot hiển thị cho sương mù phía người chơi (chỉ cập nhật khi ô đang SÁNG với người chơi)
var use_snapshot: bool = false
var display_hp: float = 0.0
var display_burning: bool = false
var display_destroyed: bool = false
var display_constructed: bool = true

var _fire: AnimatedSprite2D = null
var fire_offset: Vector2 = Vector2(0, -60)

func is_alive() -> bool:
	return not destroyed

# --- API kho chứa (lớp con ghi đè) ---
## Công trình này có phải KHO không (thành chính + 4 kho chuyên dụng).
func is_storage() -> bool:
	return false

## Loại tài nguyên kho chứa: "" = nhận MỌI loại (thành chính);
## kho chuyên dụng trả đúng khoá loại của nó ("wood"/"stone"/"gold"/"meat").
func storage_res() -> String:
	return ""

## Sức chứa tối đa cho loại của kho; -1 = không giới hạn (thành chính).
func storage_capacity() -> int:
	return -1

func stored_amount(res_key: String) -> int:
	return int(stored.get(res_key, 0))

## Kho này có NHẬN loại res_key không (đúng loại + còn đứng/đã xây xong).
func accepts_res(res_key: String) -> bool:
	if not is_storage() or not is_alive():
		return false
	return storage_res() == "" or storage_res() == res_key

## Chỗ trống còn nhận được cho res_key (0 = không nhận/đã đầy).
func free_space(res_key: String) -> int:
	if not accepts_res(res_key):
		return 0
	var cap := storage_capacity()
	if cap < 0:
		return 1 << 30
	return maxi(0, cap - stored_amount(res_key))

func can_accept(res_key: String) -> bool:
	return free_space(res_key) > 0

func get_aim_point() -> Vector2:
	return global_position + Vector2(0, -30)

func disp_destroyed() -> bool:
	return display_destroyed if use_snapshot else destroyed

func effective_hp() -> float:
	return display_hp if use_snapshot else hp

func is_burning_live() -> bool:
	return is_alive() and hp < max_hp * 0.5

func take_damage(amount: float, _attacker_pid: int) -> void:
	if destroyed:
		return
	last_attacker_pid = _attacker_pid
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		hp = 0.0
		destroyed = true
		_refresh_display()
		structure_destroyed.emit(self)
		queue_redraw()

func force_ruin() -> void:
	# Biến thành tàn tích không phát signal (dùng khi chủ bị loại).
	hp = 0.0
	destroyed = true
	train_queue.clear()
	_refresh_display()
	queue_redraw()

func _refresh_display() -> void:
	pass # lớp con cài đặt (đổi sprite theo trạng thái hiển thị)

# --- Huấn luyện ---
func can_produce() -> bool:
	return is_alive() and producer_kind != ""

func enqueue(unit_type: String, total_time: float) -> void:
	train_queue.append({"unit_type": unit_type, "time_left": total_time, "total": total_time})

func queue_count() -> int:
	return train_queue.size()

func _tick_production(delta: float) -> void:
	if not can_produce() or train_queue.is_empty():
		return
	var item: Dictionary = train_queue[0]
	item["time_left"] = float(item["time_left"]) - delta
	train_queue[0] = item
	if float(item["time_left"]) <= 0.0:
		train_queue.remove_at(0)
		if main_ref != null:
			main_ref.spawn_trained_unit(owner_pid, item["unit_type"], self)

# --- Lửa cháy ---
func _make_fire() -> void:
	_fire = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	var sheet := load("res://assets/fx/fire.png") as Texture2D
	sf.add_animation("fire")
	sf.set_animation_speed("fire", 10.0)
	for i in 8:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * 64, 0, 64, 64)
		sf.add_frame("fire", at)
	_fire.sprite_frames = sf
	_fire.position = fire_offset
	_fire.scale = Vector2(1.15, 1.15)
	_fire.visible = false
	add_child(_fire)
	_fire.play("fire")

func _update_fire() -> void:
	if _fire == null:
		return
	var burning: bool = display_burning if use_snapshot else is_burning_live()
	_fire.visible = burning and not disp_destroyed()

# --- Tháp bắn tự vệ dùng chung ---
var _tower_timer: float = 0.0

func _tick_tower(delta: float, p_range: float, p_damage: float, p_cooldown: float, p_proj_speed: float, muzzle: Vector2) -> void:
	_tower_timer = maxf(0.0, _tower_timer - delta)
	if _tower_timer > 0.0 or main_ref == null:
		return
	var best: Node2D = null
	var best_d := p_range
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u.owner_pid == owner_pid or not u.is_alive():
			continue
		var d := global_position.distance_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	if best != null:
		_tower_timer = p_cooldown
		main_ref.spawn_projectile(muzzle, best, p_damage, owner_pid, p_proj_speed, color_key)
