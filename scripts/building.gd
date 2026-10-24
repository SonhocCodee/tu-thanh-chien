class_name Building
extends Structure

## Công trình xây trong vùng căn cứ: Nhà dân / Doanh trại / Tháp canh.
## Đang xây (có thanh tiến độ) -> xong mới có hiệu lực. <50% máu cháy, 0 máu sập thành tàn tích.

var building_type: String = "house"
var constructed: bool = false
var build_left: float = 0.0
var build_total: float = 1.0

var _sprite: Sprite2D
var _tex_normal: Texture2D
var _tex_destroyed: Texture2D
var _tex_construction: Texture2D

# Cung thủ đứng trên đỉnh tháp canh (chỉ tower): tháp không tự bắn — xây
# xong thì node này hiện và CHÍNH NÓ bắn (số bắn lấy theo Stats.UNITS của
# crew_unit). Không phải Unit: không chọn được, không di chuyển, không bị
# nhắm riêng — đòn vào tháp tính vào máu tháp; tháp sập là nó biến mất.
var _archer: AnimatedSprite2D = null

func setup(p_pid: int, p_type: String, p_color: String, p_main: Node) -> void:
	owner_pid = p_pid
	building_type = p_type
	color_key = p_color
	main_ref = p_main
	var def: Dictionary = Stats.BUILDINGS[p_type]
	hp = def["hp"]
	max_hp = hp
	radius = def["radius"]
	build_total = def["build_time"]
	build_left = build_total
	if p_type == "barracks":
		producer_kind = "barracks"
	display_hp = hp
	display_constructed = false
	fire_offset = Vector2(0, -64) if p_type != "tower" else Vector2(0, -105)

func _ready() -> void:
	add_to_group("structures")
	add_to_group("buildings")
	match building_type:
		"house":
			_tex_normal = load("res://assets/buildings/house_%s.png" % color_key)
			_tex_destroyed = load("res://assets/buildings/house_destroyed.png")
			_tex_construction = load("res://assets/buildings/house_construction.png")
		"barracks":
			_tex_normal = load("res://assets/buildings/barracks_%s.png" % color_key)
			_tex_destroyed = load("res://assets/buildings/house_destroyed.png")
			_tex_construction = null
		"tower":
			_tex_normal = load("res://assets/buildings/tower_%s.png" % color_key)
			_tex_destroyed = load("res://assets/buildings/tower_destroyed.png")
			_tex_construction = load("res://assets/buildings/tower_construction.png")
		"store_wood", "store_stone", "store_gold", "store_meat":
			# 4 kho chuyên dụng: mỗi kho 1 biến thể nhà riêng của Free Pack
			# theo màu phe (Gỗ = House2, Đá = House3, Vàng = Monastery,
			# Thịt = Archery — ASSETS.md §5) + biển hiệu icon loại tài
			# nguyên trên mái (xem _make_sign). Đang xây / tàn tích dùng
			# chung bộ của nhà dân.
			_tex_normal = load("res://assets/buildings/%s_%s.png" % [building_type, color_key])
			_tex_destroyed = load("res://assets/buildings/house_destroyed.png")
			_tex_construction = load("res://assets/buildings/house_construction.png")
		"soldier_house":
			# Nhà Lính: sprite House3 của Free Pack theo màu phe (ASSETS.md §5;
			# House1 = nhà dân, House2 = nhà kho nên House3 là biến thể nhà
			# còn trống duy nhất). Đang xây / tàn tích dùng chung bộ nhà dân.
			_tex_normal = load("res://assets/buildings/soldier_house_%s.png" % color_key)
			_tex_destroyed = load("res://assets/buildings/house_destroyed.png")
			_tex_construction = load("res://assets/buildings/house_construction.png")
	_sprite = Sprite2D.new()
	match building_type:
		"house":
			_sprite.scale = Vector2(0.55, 0.55)
			_sprite.position = Vector2(0, -28)
		"barracks":
			_sprite.scale = Vector2(0.5, 0.5)
			_sprite.position = Vector2(0, -38)
		"tower":
			_sprite.scale = Vector2(0.45, 0.45)
			_sprite.position = Vector2(0, -52)
		"store_wood", "store_stone":
			# House2/House3 — canvas 128x192 như Nhà Kho cũ.
			_sprite.scale = Vector2(0.6, 0.6)
			_sprite.position = Vector2(0, -30)
		"store_gold":
			# Monastery — canvas 192x320, thu nhỏ cho chiều cao hiển thị ngang kho khác.
			_sprite.scale = Vector2(0.38, 0.38)
			_sprite.position = Vector2(0, -26)
		"store_meat":
			# Archery — canvas 192x256.
			_sprite.scale = Vector2(0.46, 0.46)
			_sprite.position = Vector2(0, -28)
		"soldier_house":
			# House3 cùng cỡ canvas 128x192 với House1 (nhà dân) -> cùng tỉ lệ.
			_sprite.scale = Vector2(0.55, 0.55)
			_sprite.position = Vector2(0, -28)
	add_child(_sprite)
	if is_storage():
		_make_sign()
	_make_fire()
	if building_type == "tower":
		_build_archer()
	_refresh_display()

# Icon tài nguyên dùng cho biển hiệu kho — cùng bộ icon HUD đang dùng.
const SIGN_ICONS := {
	"wood": "res://assets/ui/res/icon_wood.png",
	"stone": "res://assets/deco/rock1.png",
	"gold": "res://assets/ui/res/icon_gold.png",
	"meat": "res://assets/ui/res/icon_meat.png",
}

var _sign: Sprite2D = null
var _stored_label: Label = null

func _make_sign() -> void:
	# Biển hiệu: icon loại tài nguyên trên TẤM BẢNG GỖ nổi trên mái kho
	# (bảng vẽ trong _draw) — nhìn map là biết kho gì.
	_sign = Sprite2D.new()
	_sign.texture = load(SIGN_ICONS[storage_res()])
	# Icon HUD 128px -> hiện ~58px; icon đá (rock1) canvas 64px nên phóng to hơn.
	var sc := 0.45 if storage_res() != "stone" else 0.9
	_sign.scale = Vector2(sc, sc)
	_sign.position = Vector2(0, -126)
	_sign.z_index = 3
	add_child(_sign)
	# Số lượng đang chứa (vd "120/500") ngay dưới chân kho — chỉ hiện cho
	# phe người chơi (kho của mình, hoặc kho địch đang trong tầm nhìn).
	_stored_label = Label.new()
	_stored_label.position = Vector2(-45, 26)
	_stored_label.size = Vector2(90, 18)
	_stored_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stored_label.add_theme_font_size_override("font_size", 13)
	_stored_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_stored_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_stored_label.add_theme_constant_override("shadow_offset_x", 1)
	_stored_label.add_theme_constant_override("shadow_offset_y", 1)
	_stored_label.z_index = 3
	add_child(_stored_label)

## Cập nhật biển hiệu + số chứa theo trạng thái HIỂN THỊ (snapshot sương mù).
func _update_sign() -> void:
	if _sign != null:
		# Biển hiệu chỉ hiện khi kho đã xây xong và còn đứng.
		_sign.visible = disp_constructed() and not disp_destroyed()
	if _stored_label != null:
		var show := disp_constructed() and not disp_destroyed()
		if show and main_ref != null and owner_pid != main_ref.HUMAN_PID:
			# Kho địch: chỉ lộ số chứa khi đang trong tầm nhìn người chơi.
			show = main_ref.is_pos_visible_for(main_ref.HUMAN_PID, global_position)
		_stored_label.visible = show
		if show:
			_stored_label.text = "%d/%d" % [stored_amount(storage_res()), storage_capacity()]

## Dựng cung thủ đứng trên đỉnh tháp: dùng đúng bộ frame Archer của pack
## như Unit (idle 6 frame, shoot 8 frame, khung 192px, tỉ lệ 0.5 như quân
## thật). Vị trí: chân cung thủ (điểm dưới frame, lệch +40px từ tâm khung)
## đáp lên nóc tháp (đỉnh sprite tháp hiển thị ở y ≈ -89 theo building).
func _build_archer() -> void:
	_archer = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	var base := "res://assets/units/%s/" % color_key
	_add_archer_anim(sf, "idle", base + "archer_idle.png", 6, 8.0)
	_add_archer_anim(sf, "attack", base + "archer_shoot.png", 8, 12.0)
	_archer.sprite_frames = sf
	_archer.scale = Vector2(0.5, 0.5)
	_archer.position = Vector2(0, -114)
	_archer.visible = false
	add_child(_archer)
	_archer.play("idle")

func _add_archer_anim(sf: SpriteFrames, anim_name: String, tex_path: String, frames: int, fps: float) -> void:
	var sheet := load(tex_path) as Texture2D
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, anim_name != "attack")
	for i in frames:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * 192, 0, 192, 192)
		sf.add_frame(anim_name, at)

## Tháp đã xây xong và cung thủ đang đứng trên đỉnh (để test/HUD kiểm tra).
func archer_manned() -> bool:
	return building_type == "tower" and constructed and is_alive() and _archer != null

func disp_constructed() -> bool:
	return display_constructed if use_snapshot else constructed

func _refresh_display() -> void:
	if _sprite == null:
		return
	_update_sign()
	if disp_destroyed():
		_sprite.texture = _tex_destroyed
		_sprite.modulate = Color(0.75, 0.75, 0.75)
	elif not disp_constructed():
		if _tex_construction != null:
			_sprite.texture = _tex_construction
			_sprite.modulate = Color.WHITE
		else:
			_sprite.texture = _tex_normal
			_sprite.modulate = Color(1, 1, 1, 0.55)
	else:
		_sprite.texture = _tex_normal
		_sprite.modulate = Color.WHITE
	# Cung thủ trên tháp: chỉ đứng trên tháp ĐÃ XÂY XONG và còn đứng vững —
	# đang xây thì chưa có ai, tháp sập thì cung thủ chết theo (biến mất).
	# Đi theo đúng trạng thái HIỂN THỊ (snapshot sương mù) như sprite tháp.
	if _archer != null:
		_archer.visible = disp_constructed() and not disp_destroyed()

func can_produce() -> bool:
	return super.can_produce() and constructed

# --- Kho chuyên dụng: chỉ chứa ĐÚNG loại của nó, có sức chứa ---
func is_storage() -> bool:
	return Stats.BUILDINGS.get(building_type, {}).has("storage_res")

func storage_res() -> String:
	return str(Stats.BUILDINGS.get(building_type, {}).get("storage_res", ""))

func storage_capacity() -> int:
	return int(Stats.BUILDINGS.get(building_type, {}).get("storage_capacity", 500))

func accepts_res(res_key: String) -> bool:
	# Kho đang xây dở thì chưa nhận hàng.
	return constructed and super.accepts_res(res_key)

## Kho dùng được làm điểm giao tài nguyên khi đã xây xong và còn đứng.
func is_valid_dropoff() -> bool:
	return is_storage() and constructed and is_alive()

func _process(delta: float) -> void:
	_update_fire()
	if is_storage():
		_update_sign()
	if not is_alive() or main_ref == null or main_ref.match_over:
		return
	if not constructed:
		build_left -= delta
		queue_redraw()
		if build_left <= 0.0:
			constructed = true
			_refresh_display()
			main_ref.on_building_completed(self)
			queue_redraw()
		return
	_tick_production(delta)
	if building_type == "tower":
		_tick_tower_archer(delta)

## Cung thủ trên đỉnh tháp bắn thay tháp (tháp không còn tự bắn):
## - Mục tiêu: quân địch GẦN NHẤT trong tầm tháp (Stats tower_range) VÀ
##   đang nằm trong tầm nhìn của phe mình (cổng sương mù tầng dữ liệu —
##   tầm tháp 185 < tầm nhìn tháp 250 nên địch vào tầm bắn là đã lộ diện).
## - Sát thương / hồi chiêu / tốc độ tên: theo Stats.UNITS[crew_unit]
##   (cung thủ) — nó bắn phát nào, hoạt ảnh "attack" chạy phát đó.
## Chỉ chạy khi tháp ĐÃ xây xong (_process trả về sớm lúc đang xây).
func _tick_tower_archer(delta: float) -> void:
	_tower_timer = maxf(0.0, _tower_timer - delta)
	if _archer != null and _archer.animation == "attack" and not _archer.is_playing():
		_archer.play("idle")
	if _tower_timer > 0.0 or main_ref == null:
		return
	var def: Dictionary = Stats.BUILDINGS["tower"]
	var ust: Dictionary = Stats.UNITS[str(def.get("crew_unit", "archer"))]
	var best: Unit = null
	var best_d := float(def["tower_range"])
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u == null or u.owner_pid == owner_pid or not u.is_alive():
			continue
		if not main_ref.is_pos_visible_for(owner_pid, u.global_position):
			continue
		var d := global_position.distance_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	if best != null:
		_tower_timer = float(ust["attack_cooldown"])
		if _archer != null:
			_archer.flip_h = best.global_position.x < global_position.x
			_archer.play("attack")
		main_ref.spawn_projectile(global_position + Vector2(0, -108), best, float(ust["damage"]), owner_pid, float(ust["projectile_speed"]), color_key)

func _draw() -> void:
	# Bảng gỗ treo biển hiệu của kho chuyên dụng (nằm trên thanh máu).
	if is_storage() and disp_constructed() and not disp_destroyed():
		draw_rect(Rect2(-31, -159, 62, 66), Color(0.55, 0.38, 0.2))
		draw_rect(Rect2(-28, -156, 56, 60), Color(0.23, 0.15, 0.08))
	var w := 84.0
	# Tháp: thanh nằm TRÊN ĐẦU cung thủ đứng nóc (đầu cung thủ ở y ≈ -138).
	var pos := Vector2(-w / 2.0, -96.0) if building_type != "tower" else Vector2(-w / 2.0, -148.0)
	if not disp_constructed() and not disp_destroyed():
		# Thanh tiến độ xây.
		draw_rect(Rect2(pos, Vector2(w, 7)), Color(0, 0, 0, 0.7))
		var frac := 1.0 - clampf(build_left / build_total, 0.0, 1.0)
		if use_snapshot:
			frac = 1.0
		draw_rect(Rect2(pos, Vector2(w * frac, 7)), Color(1.0, 0.8, 0.3))
	else:
		draw_rect(Rect2(pos, Vector2(w, 7)), Color(0, 0, 0, 0.7))
		var frac2 := clampf(effective_hp() / max_hp, 0.0, 1.0)
		draw_rect(Rect2(pos, Vector2(w * frac2, 7)), Stats.FACTION_COLORS[color_key])
