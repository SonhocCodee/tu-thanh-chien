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
		"storehouse":
			# Nhà Kho: sprite House2 của Free Pack theo màu phe (ASSETS.md §5);
			# đang xây / tàn tích dùng chung bộ của nhà dân.
			_tex_normal = load("res://assets/buildings/storehouse_%s.png" % color_key)
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
		"storehouse":
			_sprite.scale = Vector2(0.6, 0.6)
			_sprite.position = Vector2(0, -30)
	add_child(_sprite)
	_make_fire()
	_refresh_display()

func disp_constructed() -> bool:
	return display_constructed if use_snapshot else constructed

func _refresh_display() -> void:
	if _sprite == null:
		return
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

func can_produce() -> bool:
	return super.can_produce() and constructed

## Nhà Kho dùng được làm điểm giao tài nguyên khi đã xây xong và còn đứng.
func is_valid_dropoff() -> bool:
	return building_type == "storehouse" and constructed and is_alive()

func _process(delta: float) -> void:
	_update_fire()
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
		var def: Dictionary = Stats.BUILDINGS["tower"]
		_tick_tower(delta, def["tower_range"], def["tower_damage"], def["tower_cooldown"], def["projectile_speed"], global_position + Vector2(0, -100))

func _draw() -> void:
	var w := 84.0
	var pos := Vector2(-w / 2.0, -96.0) if building_type != "tower" else Vector2(-w / 2.0, -122.0)
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
