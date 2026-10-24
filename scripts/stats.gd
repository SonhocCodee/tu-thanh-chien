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
}

# --- Huấn luyện: giá tài nguyên + thời gian, theo từng đơn vị ---
const TRAINING := {
	"pawn": {"cost": {"gold": 50}, "time": 6.0},
	"warrior": {"cost": {"gold": 80}, "time": 9.0},
	"archer": {"cost": {"gold": 70, "wood": 30}, "time": 11.0},
}
# Nơi sản xuất đẻ được quân gì; barracks_speed = hệ số tốc độ huấn luyện ở doanh trại (>1 = nhanh hơn).
const PRODUCERS := {
	"castle": {"units": ["pawn", "warrior"], "speed": 1.0},
	"barracks": {"units": ["warrior", "archer"], "speed": 1.4},
}

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
	"start_resources": {"wood": 200, "stone": 150, "gold": 200},
	"start_villagers": 3,
	"pop_base": 10,
	"pop_per_house": 8,
}

# --- Quân sự ---
const MILITARY := {
	"hold_radius": 265.0, # bán kính giữ nhà quanh thành chính
}

# --- AI quân lính (unit.gd): chọn mục tiêu / tách đàn / leash / cung thủ giữ tầm ---
# Điểm chọn mục tiêu (thấp = ưu tiên): score = khoảng cách * 1.0
#   + target_hp_bias * (máu địch / máu tối đa)   -> địch yếu máu bị "kết liễu" trước
#   + target_type_bias[loại địch]               -> âm = ưu tiên đánh trước
#   - target_stickiness nếu là mục tiêu hiện tại -> tránh nhảy mục tiêu liên tục.
const UNIT_AI := {
	"think_interval": 0.18, # nhịp tái chọn mục tiêu (giây), lệch pha theo từng quân
	"target_hp_bias": 150.0, # địch đầy máu +150 điểm ~ tương đương 150px xa hơn
	"target_type_bias": {"warrior": 0.0, "archer": -40.0}, # cung thủ: nguy hiểm + máu mỏng -> diệt trước
	"target_stickiness": 30.0,
	"leash_hold": 400.0, # giữ nhà: không đuổi địch quá bán kính này tính từ THÀNH
	"leash_move": 300.0, # đi trinh sát: không đuổi quá bán kính này tính từ ĐIỂM ĐƯỢC LỆNH
	"separation_radius": 30.0, # khoảng cách cá nhân tối thiểu giữa quân/nông dân
	"separation_push": 85.0, # tốc độ đẩy tách tối đa (px/s, khi chồng khít)
	"separation_interval": 0.1, # nhịp tính lại lực tách (giây), lệch pha từng quân
	"archer_kite_distance": 84.0, # địch áp sát gần hơn mức này -> cung thủ vừa bắn vừa lùi giữ tầm
}

# --- AI nông dân (villager.gd): bỏ chạy khi nguy hiểm ---
const VILLAGER_AI := {
	"flee_time": 2.5, # thời gian hoảng tối thiểu mỗi lần bỏ chạy (giây)
	"flee_trigger_range": 56.0, # quân địch áp sát trong bán kính này -> bỏ chạy (kể cả chưa bị đánh)
	"flee_safe_distance": 84.0, # về tới gần thành chừng này thì coi như an toàn
	"flee_max_time": 6.0, # quá hạn chót này thì quay lại việc dù chưa về tới thành
	"threat_check_interval": 0.15, # nhịp quét nguy hiểm (giây), lệch pha từng nông dân
}

# --- Điểm tài nguyên (resource_node.gd): trữ lượng hữu hạn + HỒI (regen) ---
# amount: trữ lượng điểm thường; big_amount: điểm lớn giữa map.
# regen_time: giây để điểm CẠN hồi lại đầy; 0 = KHÔNG hồi.
# Mặc định: CÂY hồi từ gốc sau 90s (rừng tái sinh, giữ nhịp farm cả trận);
# ĐÁ/VÀNG = 0 (hữu hạn tuyệt đối — áp lực cuối trận + tranh điểm giữa map,
# đúng quyết định giai đoạn 2). Đổi số ở đây là đổi luật, logic không sửa.
const RESOURCE_NODES := {
	"wood": {"amount": 500, "big_amount": 1200, "regen_time": 90.0},
	"stone": {"amount": 800, "big_amount": 2000, "regen_time": 0.0},
	"gold": {"amount": 1000, "big_amount": 3000, "regen_time": 0.0},
	"meat": {"amount": 100, "big_amount": 100, "regen_time": 0.0},
}

# --- Thú trung lập: cừu (animal_ai.gd / sheep.gd / herd_keeper.gd) ---
const ANIMALS := {
	"sheep_hp": 30.0,
	"sheep_meat": 100, # trữ lượng thịt của xác cừu (điểm "meat" cho nông dân xẻ)
	"graze_time_min": 2.0,
	"graze_time_max": 5.0,
	"idle_time_min": 1.0,
	"idle_time_max": 2.5,
	"wander_radius": 110.0, # lang thang quanh điểm nhà không quá bán kính này
	"wander_speed": 22.0,
	"flee_speed": 95.0,
	"scare_range": 64.0, # quân áp sát trong tầm này -> bỏ chạy
	"flee_time": 1.2, # thời gian chạy trốn mỗi lần bị dọa/đánh
	"scan_interval": 0.2, # nhịp quét nguy hiểm của đàn thú
	"herd_cap": 6, # trần đàn mỗi bãi chăn (herd_keeper)
	"herd_respawn_time": 20.0, # đàn dưới trần -> hồi sinh 1 con sau ngần này giây
	"herd_radius": 220.0,
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

const RES_KEYS: Array[String] = ["wood", "stone", "gold"]
# "meat": nhãn + ô chứa để sẵn cho hệ thịt (giai đoạn 2 đưa vào RES_KEYS/economy);
# ở nhánh này thịt mới tồn tại dưới dạng điểm tài nguyên (xác cừu), chưa vào kho.
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
