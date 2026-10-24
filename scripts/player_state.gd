class_name PlayerState
extends RefCounted

## Trạng thái 1 người chơi: tài nguyên, phân bổ nông dân, thái độ quân, thống kê.
## Mọi thay đổi lên trạng thái này đi qua PlayerController -> Main (lớp thực thi).

var pid: int = 0
var display_name: String = ""
var color_key: String = "blue"
var is_bot: bool = false
var alive: bool = true

var resources: Dictionary = {"wood": 0, "stone": 0, "gold": 0}
var allocation: Dictionary = {"wood": 0, "stone": 0, "gold": 0} # số nông dân mong muốn theo việc
var stance: String = "hold" # "hold" = giữ nhà | "attack" = tổng tấn công | "move" = đi tới điểm (trinh sát)
var target_pid: int = -1
var move_point: Vector2 = Vector2.ZERO

# Thống kê (phục vụ test/báo cáo)
var units_trained_total: int = 0
var buildings_completed_total: int = 0
var attacks_launched_total: int = 0
var resources_gathered_total: int = 0

# Kỹ năng thành — dữ liệu để sẵn, chưa kích hoạt.
var skill_id: String = ""
var skill_cooldown: float = 0.0
var skill_cooldown_left: float = 0.0

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
