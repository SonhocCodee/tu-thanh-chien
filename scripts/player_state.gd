class_name PlayerState
extends RefCounted

## Trạng thái 1 người chơi: tài nguyên, phân bổ nông dân, thái độ quân, thống kê.
## Mọi thay đổi lên trạng thái này đi qua PlayerController -> Main (lớp thực thi).

var pid: int = 0
var display_name: String = ""
var color_key: String = "blue"
var is_bot: bool = false
var alive: bool = true

var resources: Dictionary = {"wood": 0, "stone": 0, "gold": 0, "meat": 0}

# --- Lên Đời + cấp quân (hệ nâng cấp) ---
# age: Đời hiện tại của phe (1..3) — cổng khoá cho nâng cấp nhà/nghiên cứu
# quân cấp 2/3. unit_levels: cấp nghiên cứu theo TỪNG LOẠI quân của phe
# (áp cho mọi quân loại đó: đang sống + luyện sau). Tu sĩ KHÔNG có cấp
# nghiên cứu (không có khoá "monk" ở đây — get_unit_level trả 1 mặc định).
var age: int = 1
var unit_levels: Dictionary = {"pawn": 1, "warrior": 1, "archer": 1, "lancer": 1}
var allocation: Dictionary = {"wood": 0, "stone": 0, "gold": 0, "meat": 0} # số nông dân mong muốn theo việc
var stance: String = "hold" # "hold" = giữ nhà | "attack" = tổng tấn công | "move" = đi tới điểm (trinh sát)
var target_pid: int = -1
var move_point: Vector2 = Vector2.ZERO

# Thống kê (phục vụ test/báo cáo)
var units_trained_total: int = 0
var buildings_completed_total: int = 0
var ages_reached_total: int = 0 # số lần lên đời thành công
var upgrades_completed_total: int = 0 # số nhà đã nâng cấp xong
var researches_completed_total: int = 0 # số nghiên cứu quân đã xong
var attacks_launched_total: int = 0
var resources_gathered_total: int = 0

# Kỹ năng thành — dữ liệu để sẵn, chưa kích hoạt.
var skill_id: String = ""
var skill_cooldown: float = 0.0
var skill_cooldown_left: float = 0.0

# --- Chợ: hệ số giá TỪNG PHE cho từng loại giao dịch được (1.0 = giá gốc).
# Chỉ phe đó tự làm trôi giá của mình qua giao dịch của chính mình; hồi dần
# về 1.0 theo thời gian qua tick_market (Main gọi mỗi frame).
var market_factor: Dictionary = {"wood": 1.0, "stone": 1.0, "meat": 1.0}
var market_trades_total: int = 0

func setup(p_pid: int, def: Dictionary) -> void:
	pid = p_pid
	display_name = def["name"]
	color_key = def["color_key"]
	is_bot = def["is_bot"]
	skill_id = def["skill_id"]
	skill_cooldown = def["skill_cooldown"]
	var start: Dictionary = Stats.ECONOMY["start_resources"]
	for k in Stats.RES_KEYS:
		resources[k] = int(start[k])

## Hồi giá chợ: độ lệch của từng factor so với 1.0 thu hẹp recover_rate
## mỗi recover_interval giây (cấp số nhân theo delta — không phụ thuộc fps).
func tick_market(delta: float) -> void:
	if delta <= 0.0:
		return
	var cfg: Dictionary = Stats.MARKET
	var shrink := pow(1.0 - float(cfg["recover_rate"]), delta / float(cfg["recover_interval"]))
	for k in market_factor.keys():
		var f := float(market_factor[k])
		if not is_equal_approx(f, 1.0):
			market_factor[k] = clampf(1.0 + (f - 1.0) * shrink,
				float(cfg["factor_min"]), float(cfg["factor_max"]))

func can_afford(cost: Dictionary) -> bool:
	for k in cost.keys():
		if int(resources[k]) < int(cost[k]):
			return false
	return true

func pay(cost: Dictionary) -> void:
	for k in cost.keys():
		resources[k] = int(resources[k]) - int(cost[k])

func add_resource(res_key: String, amount: int) -> void:
	if not alive:
		return
	resources[res_key] = int(resources[res_key]) + amount
	resources_gathered_total += amount
