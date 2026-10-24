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
const RES_LABELS := {"wood": "Gỗ", "stone": "Đá", "gold": "Vàng"}

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
