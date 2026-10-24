class_name Castle
extends Structure

## Thành chính: sprite đúng màu phe, tháp tự vệ, sinh Pawn + Warrior.
## Sập = chủ bị loại (Main xử lý qua signal structure_destroyed).

var display_name: String = ""
var highlight_target: bool = false

var _sprite: Sprite2D
var _tower_visual: Sprite2D
var _pulse: float = 0.0

func setup(p_pid: int, p_color: String, p_name: String, p_main: Node) -> void:
	owner_pid = p_pid
	color_key = p_color
	display_name = p_name
	main_ref = p_main
	hp = Stats.CASTLE["hp"]
	max_hp = hp
	radius = Stats.CASTLE["radius"]
	producer_kind = "castle"
	fire_offset = Vector2(-10, -78)
	display_hp = hp

func _ready() -> void:
	add_to_group("structures")
	add_to_group("castles")
	_tower_visual = Sprite2D.new()
	_tower_visual.texture = load("res://assets/buildings/tower_%s.png" % color_key)
	_tower_visual.scale = Vector2(0.42, 0.42)
	_tower_visual.position = Vector2(64, -18)
	add_child(_tower_visual)
	_sprite = Sprite2D.new()
	_sprite.scale = Vector2(0.52, 0.52)
	_sprite.position = Vector2(-14, -6)
	add_child(_sprite)
	var lbl := Label.new()
	lbl.text = display_name
	lbl.position = Vector2(-70, 68)
	lbl.size = Vector2(140, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Stats.FACTION_COLORS[color_key])
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	add_child(lbl)
	_make_fire()
	_refresh_display()

func _refresh_display() -> void:
	if _sprite == null:
		return
	if disp_destroyed():
		_sprite.texture = load("res://assets/buildings/castle_destroyed.png")
		if _tower_visual != null:
			_tower_visual.modulate = Color(0.4, 0.4, 0.4, 0.7)
	else:
		_sprite.texture = load("res://assets/buildings/castle_%s.png" % color_key)
		if _tower_visual != null:
			_tower_visual.modulate = Color.WHITE

func tower_muzzle() -> Vector2:
	return global_position + Vector2(64, -95)

func _process(delta: float) -> void:
	_update_fire()
	if highlight_target and not disp_destroyed():
		_pulse += delta * 6.0
		var s := 1.0 + 0.12 * sin(_pulse)
		_sprite.modulate = Color(s, s, 1.0)
	elif _sprite != null:
		_sprite.modulate = Color.WHITE
	if not is_alive() or main_ref == null or main_ref.match_over:
		return
	_tick_production(delta)
	_tick_tower(delta, Stats.CASTLE["tower_range"], Stats.CASTLE["tower_damage"], Stats.CASTLE["tower_cooldown"], Stats.CASTLE["projectile_speed"], tower_muzzle())

func _draw() -> void:
	var w := 130.0
	var pos := Vector2(-w / 2.0, -112.0)
	draw_rect(Rect2(pos, Vector2(w, 10)), Color(0, 0, 0, 0.7))
	var frac := clampf(effective_hp() / max_hp, 0.0, 1.0)
	draw_rect(Rect2(pos, Vector2(w * frac, 10)), Stats.FACTION_COLORS[color_key])
	draw_rect(Rect2(pos, Vector2(w, 10)), Color(1, 1, 1, 0.5), false, 1.0)
