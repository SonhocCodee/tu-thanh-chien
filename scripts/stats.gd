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
		"size": "small",
	},
	"barracks": {
		"label": "Doanh trại",
		"cost": {"wood": 150, "stone": 50},
		"build_time": 20.0,
		"hp": 400.0,
		"radius": 55.0,
		"size": "large",
	},
	"tower": {
		"label": "Tháp canh",
		"cost": {"stone": 100},
		"build_time": 15.0,
		"hp": 300.0,
		"radius": 34.0,
		"size": "large",
		"tower_range": 185.0,
		# Tháp KHÔNG tự bắn: xây xong có 1 CUNG THỦ đứng trên đỉnh tháp và
		# chính nó bắn — sát thương / hồi chiêu / tốc độ tên lấy theo
		# Stats.UNITS[crew_unit]. "crew_pop" = số ô dân tháp GIỮ cho cung thủ
		# trong suốt thời gian tháp còn đứng (đếm trong Main.pop_used VÀ
		# Main.army_used — cung thủ trực tháp ngốn cả ô quân theo
		# pop_cost(crew_unit); đặt tháp khi hết ô bị từ chối ngay ở can_place).
		"crew_unit": "archer",
		"crew_pop": 1,
	},
	# KHO CHUYÊN DỤNG (kiểu Clash of Clans): mỗi loại tài nguyên 1 kho riêng,
	# CHỈ chứa đúng loại của nó, có SỨC CHỨA (storage_capacity). Thành chính là
	# kho TỔNG: nhận mọi loại, không giới hạn. Kho bị phá -> phe tấn công cướp
	# toàn bộ lượng đang chứa trong kho đó. Không sản xuất, không cộng dân số.
	# Đặt được ở mọi vùng ĐÃ KHÁM PHÁ (không giới hạn vùng căn cứ) để kê gần
	# bãi farm. "storage_res" = khoá loại kho chứa; có khoá này = là kho.
	"store_wood": {
		"label": "Kho Gỗ",
		"cost": {"wood": 80},
		"build_time": 10.0,
		"hp": 300.0,
		"radius": 40.0,
		"storage_res": "wood",
		"storage_capacity": 500,
		"size": "small",
	},
	"store_stone": {
		"label": "Kho Đá",
		"cost": {"wood": 80},
		"build_time": 10.0,
		"hp": 300.0,
		"radius": 40.0,
		"storage_res": "stone",
		"storage_capacity": 500,
		"size": "small",
	},
	"store_gold": {
		"label": "Kho Vàng",
		"cost": {"wood": 80},
		"build_time": 10.0,
		"hp": 300.0,
		"radius": 40.0,
		"storage_res": "gold",
		"storage_capacity": 500,
		"size": "small",
	},
	"store_meat": {
		"label": "Kho Thịt",
		"cost": {"wood": 80},
		"build_time": 10.0,
		"hp": 300.0,
		"radius": 40.0,
		"storage_res": "meat",
		"storage_capacity": 500,
		"size": "small",
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
		"size": "large",
	},
	# RUỘNG (nông trại): nguồn THỊT chủ động kiểu Đế Chế — thay vì chỉ săn
	# cừu. Công trình chứa 1 lượng thịt HỮU HẠN (farm_meat): bên trong nó
	# "mọc" 1 node thịt do chính ruộng làm chủ (xem building.gd), nông dân
	# làm ruộng đúng như làm 1 điểm tài nguyên thịt, vác về kho thịt/thành.
	# CẠN -> ruộng TỰ SỤP thành đất trống rồi biến mất hẳn (xây lại từ đầu)
	# nên giá rẻ (60 gỗ). Đặt qua ĐÚNG luật vị trí hợp nhất
	# Main.can_place_building_at như mọi nhà (đã khám phá + trên đất +
	# không chồng lấn) — "free_place" chỉ là dấu hiệu "đặt tự do xa nhà"
	# cho HUD/bot đọc, luật thật nằm ở Main. Nhà NHỎ: 1 thợ xây.
	"farm": {
		"label": "Ruộng",
		"cost": {"wood": 60},
		"build_time": 8.0,
		"hp": 150.0,
		"radius": 40.0,
		"farm_meat": 250,
		"free_place": true,
		"size": "small",
	},
}

# --- Thợ xây (hệ thống xây mới): công trình chỉ tiến triển khi có nông dân
# TỚI TẬN NƠI đóng búa. "size" trong BUILDINGS quyết định số thợ cần:
# nhỏ = 1 thợ, lớn = 2 thợ. build_time trong BUILDINGS là thời gian khi
# ĐỦ thợ; thiếu thợ thì chậm tỉ lệ (có mặt / cần).
const BUILDER_COUNT := {
	"small": 1,
	"large": 2,
}

static func builders_required(building_type: String) -> int:
	var size: String = str(BUILDINGS[building_type].get("size", "small"))
	return int(BUILDER_COUNT.get(size, 1))

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
# regen_time (tích hợp AI 2026-10-24, user chốt): giây để điểm CẠN hồi lại
# đầy; 0 = KHÔNG hồi. CÂY mọc lại từ gốc sau 90s; ĐÁ/VÀNG không hồi.
const NODE_AMOUNTS := {
	"wood": {"small": 300, "big": 900, "regen_time": 90.0},
	"stone": {"small": 240, "big": 720, "regen_time": 0.0},
	"gold": {"small": 300, "big": 1000, "regen_time": 0.0},
}

# --- Cừu trung lập: nguồn thịt ---
const SHEEP := {
	"hp": 25.0,
	"meat": 100, # thịt trong 1 xác cừu
	"speed": 22.0,
	"wander_radius": 85.0,
}

# --- AI quân lính (unit.gd): chọn mục tiêu / tách đàn / leash / cung thủ giữ tầm ---
# Điểm chọn mục tiêu (thấp = ưu tiên): score = khoảng cách * 1.0
#   + target_hp_bias * (máu địch / máu tối đa)   -> địch yếu máu bị "kết liễu" trước
#   + target_type_bias[loại địch]               -> âm = ưu tiên đánh trước
#   + target_focus_penalty * (số ĐỒNG MINH đang cùng nhắm địch đó)
#                                               -> CHIA LỬA: cả đội không dồn
#                                                  hết vào 1 mục tiêu nữa
#   - target_stickiness nếu là mục tiêu hiện tại -> tránh nhảy mục tiêu liên tục.
const UNIT_AI := {
	"think_interval": 0.18, # nhịp tái chọn mục tiêu (giây), lệch pha theo từng quân
	"target_hp_bias": 150.0, # địch đầy máu +150 điểm ~ tương đương 150px xa hơn
	"target_type_bias": {"warrior": 0.0, "archer": -40.0}, # cung thủ: nguy hiểm + máu mỏng -> diệt trước
	"target_focus_penalty": 45.0, # mỗi đồng minh đang nhắm cùng 1 địch -> +45 điểm cho địch đó
	"target_stickiness": 30.0,
	"leash_hold": 400.0, # giữ nhà: không đuổi địch quá bán kính này tính từ THÀNH
	"leash_move": 300.0, # đi trinh sát: không đuổi quá bán kính này tính từ ĐIỂM ĐƯỢC LỆNH
	"separation_radius": 30.0, # khoảng cách cá nhân tối thiểu giữa quân/nông dân
	"separation_push": 85.0, # tốc độ đẩy tách tối đa (px/s, khi chồng khít)
	"separation_interval": 0.1, # nhịp tính lại lực tách (giây), lệch pha từng quân
	"archer_kite_distance": 84.0, # địch áp sát gần hơn mức này -> cung thủ vừa bắn vừa lùi giữ tầm
	# Kite PHẢI TRẢ GIÁ (cân bằng can-bang): vừa lùi vừa bắn chỉ còn 55% tốc độ
	# thường (66 -> ~36 px/s) — kiếm sĩ (72) áp sát thực ~36 px/s, băng vùng
	# kite 84->36px trong ~1,3s thay vì ~8s chết dọc đường như trước.
	"archer_kite_speed_factor": 0.55,
}

# --- AI nông dân (villager.gd): bỏ chạy khi nguy hiểm ---
const VILLAGER_AI := {
	"flee_time": 2.5, # thời gian hoảng tối thiểu mỗi lần bỏ chạy (giây)
	"flee_trigger_range": 56.0, # quân địch áp sát trong bán kính này -> bỏ chạy (kể cả chưa bị đánh)
	"flee_safe_distance": 84.0, # về tới gần kho chừng này thì coi như an toàn
	"flee_max_time": 6.0, # quá hạn chót này thì quay lại việc dù chưa về tới kho
	"threat_check_interval": 0.15, # nhịp quét nguy hiểm (giây), lệch pha từng nông dân
}

# --- Thú trung lập: cừu (animal_ai.gd / sheep.gd / herd_keeper.gd) ---
# sheep_hp KHỚP SHEEP.hp = 25 của giai đoạn 2 (bản AI gốc là 30 — KHÔNG lấy;
# SHEEP ở trên là nguồn sự thật của gameplay, dict này là cấu hình bộ não thú
# + đàn; hai giá trị máu/thịt phải luôn bằng nhau).
const ANIMALS := {
	"sheep_hp": 25.0,
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
