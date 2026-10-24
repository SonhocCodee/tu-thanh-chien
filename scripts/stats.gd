class_name Stats
extends RefCounted

## TOÀN BỘ CHỈ SỐ GAME NẰM Ở ĐÂY — logic không hardcode số, luôn đọc từ file này.
## M1 — Lõi Đế Chế: nông dân farm Gỗ/Đá/Vàng, xây dựng, huấn luyện, 2 thái độ quân.

# --- Đơn vị ---
# damage_type / armor_type: để sẵn cho hệ khắc chế ở mốc sau (chưa tính khắc chế).
const UNITS := {
	"pawn": {
		"label": "Nông dân",
		"hp": 60.0,
		"speed": 88.0,
		"damage_type": "vat_ly",
		"armor_type": "nhe",
		"carry_capacity": 10,
		"harvest_time": 3.0,
	},
	"warrior": {
		"label": "Kiếm sĩ",
		"hp": 130.0,
		"damage": 14.0,
		"speed": 72.0,
		"attack_range": 36.0,
		"detect_range": 180.0,
		"attack_cooldown": 0.9,
		"damage_type": "vat_ly",
		"armor_type": "nhe",
		"bounty": 0,
		"projectile_speed": 0.0,
	},
	"archer": {
		"label": "Cung thủ",
		"hp": 75.0,
		"damage": 11.0,
		"speed": 66.0,
		"attack_range": 150.0,
		"detect_range": 235.0,
		"attack_cooldown": 1.25,
		"damage_type": "vat_ly",
		"armor_type": "nhe",
		"bounty": 0,
		"projectile_speed": 430.0,
	},
	# Lính giáo — TINH NHUỆ đầu tiên: chiếm 2 ô quân (xem TRAINING.pop_cost).
	# Mạnh hơn hẳn kiếm sĩ từng con: máu 220 (gần gấp đôi 130), đòn 21/1,05s
	# (DPS ~20 so với ~15,6), tầm đánh 55 nhờ giáo dài (kiếm 36) nên chạm
	# địch trước; đổi lại mỗi con ăn 2 ô nên tính theo ô thì thua 2 kiếm sĩ
	# về DPS — vai trò là tấm khiên sống tuyến đầu, không phải thay thế kiếm.
	"lancer": {
		"label": "Lính giáo",
		"hp": 220.0,
		"damage": 21.0,
		"speed": 68.0,
		"attack_range": 55.0,
		"detect_range": 200.0,
		"attack_cooldown": 1.05,
		"damage_type": "vat_ly",
		"armor_type": "nhe",
		"bounty": 0,
		"projectile_speed": 0.0,
	},
}

# --- Huấn luyện: giá tài nguyên + thời gian, theo từng đơn vị ---
# M2 giai đoạn 2: nông dân tốn THỊT (săn cừu) thay cho 50 vàng như M1;
# quân vẫn tốn vàng/gỗ như cũ.
# pop_cost = số Ô chiếm chỗ: tính CẢ vào dân số chung LẪN giới hạn quân
# (army cap) nếu là quân (military=true). Lính thường 1 ô, tinh nhuệ 2 ô.
const TRAINING := {
	"pawn": {"cost": {"meat": 50}, "time": 6.0, "pop_cost": 1, "military": false},
	"warrior": {"cost": {"gold": 80}, "time": 9.0, "pop_cost": 1, "military": true},
	"archer": {"cost": {"gold": 70, "wood": 30}, "time": 11.0, "pop_cost": 1, "military": true},
	# Lính giáo: giá ~1,9 lần kiếm sĩ (150 vàng + 30 gỗ), luyện 16s ở
	# doanh trại (tốc độ 1,4 -> ~11,4s thực). Chỉ cần Doanh trại + còn ô.
	"lancer": {"cost": {"gold": 150, "wood": 30}, "time": 16.0, "pop_cost": 2, "military": true},
}
# Nơi sản xuất đẻ được quân gì; barracks_speed = hệ số tốc độ huấn luyện ở doanh trại (>1 = nhanh hơn).
const PRODUCERS := {
	"castle": {"units": ["pawn", "warrior"], "speed": 1.0},
	"barracks": {"units": ["warrior", "archer", "lancer"], "speed": 1.4},
}

static func pop_cost(unit_type: String) -> int:
	if TRAINING.has(unit_type):
		return int(TRAINING[unit_type].get("pop_cost", 1))
	return 1

static func is_military(unit_type: String) -> bool:
	if TRAINING.has(unit_type):
		return bool(TRAINING[unit_type].get("military", false))
	return false

# --- Công trình: giá / thời gian xây / máu / bán kính ---
const BUILDINGS := {
	"house": {
		"label": "Nhà dân",
		"cost": {"wood": 100},
		"build_time": 12.0,
		"hp": 250.0,
		"radius": 42.0,
	},
	"barracks": {
		"label": "Doanh trại",
		"cost": {"wood": 150, "stone": 50},
		"build_time": 20.0,
		"hp": 400.0,
		"radius": 55.0,
	},
	"tower": {
		"label": "Tháp canh",
		"cost": {"stone": 100},
		"build_time": 15.0,
		"hp": 300.0,
		"radius": 34.0,
		"tower_damage": 10.0,
		"tower_range": 185.0,
		"tower_cooldown": 1.1,
		"projectile_speed": 470.0,
	},
	# Nhà Kho: điểm giao tài nguyên (drop-off) phụ cạnh thành chính — nhận MỌI
	# tài nguyên kể cả vàng. Không sản xuất, không cộng dân số. Đặt được ở mọi
	# vùng ĐÃ KHÁM PHÁ (không giới hạn vùng căn cứ) để kê gần bãi farm.
	"storehouse": {
		"label": "Nhà Kho",
		"cost": {"wood": 80},
		"build_time": 10.0,
		"hp": 300.0,
		"radius": 40.0,
	},
	# Nhà Lính: KHÔNG luyện quân — chức năng duy nhất là tăng GIỚI HẠN QUÂN
	# (army cap) thêm army_bonus ô. Army cap tách khỏi dân số chung: quân
	# đông tới đâu do Nhà Lính quyết, dân số chung do Nhà Dân quyết.
	# Phá 1 Nhà Lính -> cap tụt army_bonus; quân đang có KHÔNG chết theo,
	# chỉ không luyện thêm được tới khi số ô quay xuống dưới cap.
	"soldier_house": {
		"label": "Nhà Lính",
		"cost": {"wood": 100},
		"build_time": 12.0,
		"hp": 300.0,
		"radius": 42.0,
		"army_bonus": 6,
	},
}

# --- Thành chính ---
const CASTLE := {
	"hp": 700.0,
	"radius": 78.0,
	"tower_damage": 12.0,
	"tower_range": 195.0,
	"tower_cooldown": 1.1,
	"projectile_speed": 470.0,
}

# --- Kinh tế / dân số ---
const ECONOMY := {
	"start_resources": {"wood": 200, "stone": 150, "gold": 200, "meat": 100},
	"start_villagers": 3,
	"pop_base": 10,
	"pop_per_house": 8,
	# Giới hạn quân nền (chưa có Nhà Lính nào): 6 ô — đủ thủ nhà + trinh
	# sát đầu trận, nhưng đạo quân tổng tấn công chuẩn (8 quân) bắt buộc
	# phải xây Nhà Lính (+6 ô/nhà). Ép Nhà Lính thành 1 mắt xích kinh tế.
	"army_base": 6,
}

# --- Tài nguyên HỮU HẠN (M2 giai đoạn 2): trữ lượng từng điểm trên map ---
# Đơn vị = đúng đơn vị tài nguyên; mỗi chuyến nông dân vác tối đa
# UNITS.pawn.carry_capacity (10). Cạn -> cây đổ còn gốc, mỏ biến mất.
const NODE_AMOUNTS := {
	"wood": {"small": 300, "big": 900},
	"stone": {"small": 240, "big": 720},
	"gold": {"small": 300, "big": 1000},
}

# --- Cừu trung lập: nguồn thịt ---
const SHEEP := {
	"hp": 25.0,
	"meat": 100, # thịt trong 1 xác cừu
	"speed": 22.0,
	"wander_radius": 85.0,
}

# Thời gian đống đổ nát của mỏ vàng lớn nằm lại trên map sau khi cạn
# (hiện sprite GoldMine_Destroyed) trước khi biến mất hẳn.
const GOLDMINE_RUBBLE_TIME := 6.0

# --- Quân sự ---
const MILITARY := {
	"hold_radius": 265.0, # bán kính giữ nhà quanh thành chính
}

# --- Sương mù chiến tranh ---
const FOG := {
	"cell_size": 32,
	"update_interval": 0.25,
	"vision": { # bán kính tầm nhìn theo loại
		"castle": 265.0,
		"tower": 250.0,
		"building": 130.0,
		"archer": 195.0,
		"warrior": 165.0,
		"lancer": 185.0,
		"pawn": 120.0,
	},
}

# --- Bot ---
const BOT := {
	"decision_interval": 1.2,
	"villager_target": 6,
	"attack_army_size": 8,
	"threat_radius": 290.0,
}

const RES_KEYS: Array[String] = ["wood", "stone", "gold", "meat"]
const RES_LABELS := {"wood": "Gỗ", "stone": "Đá", "gold": "Vàng", "meat": "Thịt"}

# --- Người chơi ---
# skill_id / skill_cooldown: kỹ năng thành để sẵn dữ liệu (chưa kích hoạt ở mốc này).
const PLAYERS := [
	{"name": "Xanh Dương", "color_key": "blue", "is_bot": false, "skill_id": "mua_ten", "skill_cooldown": 30.0},
	{"name": "Vàng", "color_key": "yellow", "is_bot": true, "skill_id": "hoi_mau_thanh", "skill_cooldown": 40.0},
	{"name": "Đỏ", "color_key": "red", "is_bot": true, "skill_id": "mua_ten", "skill_cooldown": 30.0},
	{"name": "Tím", "color_key": "purple", "is_bot": true, "skill_id": "dong_bang_lane", "skill_cooldown": 35.0},
]

const FACTION_COLORS := {
	"blue": Color(0.35, 0.55, 1.0),
	"yellow": Color(1.0, 0.85, 0.25),
	"red": Color(1.0, 0.35, 0.3),
	"purple": Color(0.75, 0.45, 1.0),
}

static func unit_stats(unit_type: String) -> Dictionary:
	return UNITS[unit_type]

static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for k in RES_KEYS:
		if cost.has(k):
			parts.append("%d %s" % [int(cost[k]), RES_LABELS[k].to_lower()])
	return ", ".join(parts)
