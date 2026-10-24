class_name NetGhost
extends Node2D

## NetGhost — hình hài hiển thị của 1 thực thể trong "bản gương" phía client.
## Client KHÔNG có thực thể thật (không mô phỏng): nó chỉ có các ghost này,
## được NetGhostWorld sinh/cập nhật từ snapshot đã lọc sương mù của server.
## Sprite/frame/scale lấy ĐÚNG bảng của game thật (unit.gd / villager.gd /
## building.gd / castle.gd / resource_node.gd / sheep.gd) để nhìn như chơi đơn.
##
## Nội suy: giữ lịch sử (thời điểm, vị trí) từ các snapshot, hiển thị ở
## thời điểm (now - INTERP_DELAY) như prototype đã kiểm chứng (~15px lệch
## tối đa ở 10 Hz, hội tụ 0 khi đứng yên).

var net_id: int = 0
var owner_pid: int = -1
var kind: String = "" # unit | villager | castle | building | node | sheep
var sub: String = ""
var color_key: String = "blue"
var hp: float = 0.0
var max_hp: float = 0.0
var flags: int = 0
var extra_s: String = ""
var extra_f: float = 0.0
var extra_i: int = 0
var selected: bool = false

var hist: Array = [] # [[time, Vector2], ...]
var render: Vector2 = Vector2.ZERO
var _auth_pos: Vector2 = Vector2.ZERO # vị trí thật mới nhất (điểm nội suy hướng tới)
var _anim: AnimatedSprite2D = null
var _sprite: Sprite2D = null
var _cur_anim: String = ""
var _last_render: Vector2 = Vector2.ZERO
var _static_visual_key: String = "" # khoá trạng thái sprite tĩnh (nhà/node)

func is_static_kind() -> bool:
	return kind == "castle" or kind == "building" or kind == "node"

func is_dim() -> bool:
	return flags & NetProtocol.F_DIM != 0

func is_destroyed() -> bool:
	return flags & NetProtocol.F_DESTROYED != 0

func is_constructed() -> bool:
	return flags & NetProtocol.F_CONSTRUCTED != 0

func is_depleted() -> bool:
	return flags & NetProtocol.F_DEPLETED != 0

func radius() -> float:
	match kind:
		"castle":
			return float(Stats.CASTLE["radius"])
		"building":
			return float(Stats.BUILDINGS[sub]["radius"]) if Stats.BUILDINGS.has(sub) else 40.0
		"unit", "villager":
			return 20.0
		"sheep":
			return 18.0
		"node":
			return 40.0 if flags & NetProtocol.F_BIG != 0 else 28.0
	return 24.0

## rec = 1 bản ghi upsert của snapshot (định dạng ở net_server.gd).
func setup_from(rec: Array, p_color_key: String, now: float) -> void:
	net_id = int(rec[0])
	owner_pid = int(rec[1])
	kind = String(rec[2])
	sub = String(rec[3])
	color_key = p_color_key
	_auth_pos = Vector2(float(rec[4]), float(rec[5]))
	render = _auth_pos
	_last_render = render
	position = render
	hist = [[now, _auth_pos]]
	_apply_state(rec)
	_build_visual()
	if kind == "castle":
		z_index = 5
	elif kind == "building":
		z_index = 5
	elif kind == "node":
		z_index = -4
	elif kind == "sheep":
		z_index = 6
	else:
		z_index = 10

func apply(rec: Array, now: float) -> void:
	_auth_pos = Vector2(float(rec[4]), float(rec[5]))
	_apply_state(rec)
	if is_static_kind():
		render = _auth_pos
		position = render
		_refresh_static_visual()
	else:
		hist.append([now, _auth_pos])
		while hist.size() > 6:
			hist.pop_front()
	queue_redraw()

func _apply_state(rec: Array) -> void:
	hp = float(rec[6])
	max_hp = float(rec[7])
	flags = int(rec[8])
	extra_s = String(rec[9])
	extra_f = float(rec[10])
	extra_i = int(rec[11])

## Vị trí hiển thị tại thời điểm now (nội suy giữa 2 mẫu quanh now-delay).
func render_pos(now: float) -> Vector2:
	if is_static_kind() or hist.is_empty():
		return _auth_pos
	var rt := now - NetProtocol.INTERP_DELAY
	if rt <= float(hist[0][0]):
		return hist[0][1]
	if rt >= float(hist[hist.size() - 1][0]):
		return hist[hist.size() - 1][1]
	for i in range(hist.size() - 1):
		var t0 := float(hist[i][0])
		var t1 := float(hist[i + 1][0])
		if rt >= t0 and rt <= t1:
			var w := 0.0 if t1 <= t0 else (rt - t0) / (t1 - t0)
			return (hist[i][1] as Vector2).lerp(hist[i + 1][1], w)
	return hist[hist.size() - 1][1]

func _process(_delta: float) -> void:
	if is_static_kind():
		return
	var now := Time.get_ticks_msec() / 1000.0
	render = render_pos(now)
	position = render
	# Hoạt ảnh theo chuyển động thật trên màn hình.
	var moved := render - _last_render
	_last_render = render
	if _anim != null:
		if absf(moved.x) > 0.05:
			_anim.flip_h = moved.x < 0.0
		var moving := moved.length() > 0.05
		_play(_move_anim() if moving else _idle_anim())

func _idle_anim() -> String:
	return "grass" if kind == "sheep" else "idle"

func _move_anim() -> String:
	if kind == "sheep":
		return "move"
	if kind == "villager" and extra_i > 0 and extra_s != "":
		var a := "run_" + extra_s
		if _anim != null and _anim.sprite_frames != null and _anim.sprite_frames.has_animation(a):
			return a
	return "run"

func _play(anim_name: String) -> void:
	if _anim == null or anim_name == _cur_anim:
		return
	if _anim.sprite_frames == null or not _anim.sprite_frames.has_animation(anim_name):
		return
	_cur_anim = anim_name
	_anim.play(anim_name)

# ============================ DỰNG HÌNH ============================

func _build_visual() -> void:
	match kind:
		"unit":
			_anim = AnimatedSprite2D.new()
			_anim.scale = Vector2(0.34, 0.34) if sub == "lancer" else Vector2(0.5, 0.5)
			_anim.position = Vector2(0, -20)
			_anim.sprite_frames = _unit_frames()
			add_child(_anim)
			_play("idle")
		"villager":
			_anim = AnimatedSprite2D.new()
			_anim.scale = Vector2(0.5, 0.5)
			_anim.position = Vector2(0, -20)
			_anim.sprite_frames = _villager_frames()
			add_child(_anim)
			_play("idle")
		"sheep":
			_anim = AnimatedSprite2D.new()
			_anim.scale = Vector2(0.55, 0.55)
			_anim.position = Vector2(0, -14)
			_anim.sprite_frames = _sheep_frames()
			add_child(_anim)
			_play("grass")
		"castle":
			_sprite = Sprite2D.new()
			_sprite.scale = Vector2(0.52, 0.52)
			_sprite.position = Vector2(-14, -6)
			add_child(_sprite)
			var lbl := Label.new()
			lbl.text = String(Stats.PLAYERS[owner_pid]["name"]) if owner_pid >= 0 and owner_pid < Stats.PLAYERS.size() else ""
			lbl.position = Vector2(-70, 68)
			lbl.size = Vector2(140, 24)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 17)
			lbl.add_theme_color_override("font_color", Stats.FACTION_COLORS[color_key])
			lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			lbl.add_theme_constant_override("shadow_offset_x", 1)
			lbl.add_theme_constant_override("shadow_offset_y", 1)
			add_child(lbl)
			_refresh_static_visual()
		"building", "node":
			_sprite = Sprite2D.new()
			add_child(_sprite)
			_refresh_static_visual()

func _add_anim(sf: SpriteFrames, anim_name: String, tex_path: String, frames: int, fps: float, frame_size: float = 192.0) -> void:
	var sheet := load(tex_path) as Texture2D
	if sheet == null:
		return
	if not sf.has_animation(anim_name):
		sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, true)
	for i in frames:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		sf.add_frame(anim_name, at)

func _unit_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var base := "res://assets/units/%s/" % color_key
	if sub == "warrior":
		_add_anim(sf, "idle", base + "warrior_idle.png", 8, 8.0)
		_add_anim(sf, "run", base + "warrior_run.png", 6, 10.0)
	elif sub == "lancer":
		_add_anim(sf, "idle", base + "lancer_idle.png", 12, 8.0, 320.0)
		_add_anim(sf, "run", base + "lancer_run.png", 6, 10.0, 320.0)
	else:
		_add_anim(sf, "idle", base + "archer_idle.png", 6, 8.0)
		_add_anim(sf, "run", base + "archer_run.png", 4, 10.0)
	return sf

func _villager_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var base := "res://assets/units/%s/" % color_key
	_add_anim(sf, "idle", base + "pawn_idle.png", 8, 8.0)
	_add_anim(sf, "run", base + "pawn_run.png", 6, 10.0)
	_add_anim(sf, "run_wood", base + "pawn_run_wood.png", 6, 10.0)
	_add_anim(sf, "run_gold", base + "pawn_run_gold.png", 6, 10.0)
	_add_anim(sf, "run_meat", base + "pawn_run_meat.png", 6, 10.0)
	return sf

func _sheep_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	_add_anim(sf, "idle", "res://assets/animals/sheep_idle.png", 6, 6.0)
	_add_anim(sf, "move", "res://assets/animals/sheep_move.png", 4, 8.0)
	_add_anim(sf, "grass", "res://assets/animals/sheep_grass.png", 12, 5.0)
	return sf

## Sprite tĩnh (nhà/node): chỉ nạp lại khi TRẠNG THÁI THẤY ĐƯỢC đổi (xây
## xong / sập / thành gốc / mỏ đổi trạng thái / tỉ lệ trữ lượng đổi mạnh).
func _refresh_static_visual() -> void:
	if _sprite == null:
		return
	var key := ""
	if kind == "building":
		key = "%s|%s|%s" % [sub, str(is_destroyed()), str(is_constructed())]
	elif kind == "castle":
		key = "castle|%s" % str(is_destroyed())
	elif kind == "node":
		var mine_state := ""
		if sub == "gold" and flags & NetProtocol.F_BIG != 0:
			mine_state = "destroyed" if is_depleted() else ("active" if extra_f < 1.0 else "inactive")
		key = "%s|%s|%s|%.2f" % [sub, str(flags & (NetProtocol.F_STUMP | NetProtocol.F_DEPLETED | NetProtocol.F_BIG)), mine_state, extra_f if sub == "stone" or (sub == "gold" and flags & NetProtocol.F_BIG == 0) else 0.0]
	if key == _static_visual_key:
		return
	_static_visual_key = key
	if kind == "castle":
		_sprite.texture = load("res://assets/buildings/castle_destroyed.png") if is_destroyed() \
			else load("res://assets/buildings/castle_%s.png" % color_key)
	elif kind == "building":
		_apply_building_texture()
	elif kind == "node":
		_apply_node_visual()
	if is_dim():
		_sprite.modulate = Color(0.72, 0.78, 0.95, 0.92)
	elif kind == "building" and not is_constructed() and not is_destroyed():
		_sprite.modulate = Color(1, 1, 1, 0.75) if sub == "barracks" else Color.WHITE
	else:
		_sprite.modulate = Color.WHITE
	queue_redraw()

func _apply_building_texture() -> void:
	var normal := ""
	var construction: Texture2D = null
	var destroyed := load("res://assets/buildings/house_destroyed.png") as Texture2D
	match sub:
		"house":
			normal = "res://assets/buildings/house_%s.png" % color_key
			construction = load("res://assets/buildings/house_construction.png")
			_sprite.scale = Vector2(0.55, 0.55)
			_sprite.position = Vector2(0, -28)
		"barracks":
			normal = "res://assets/buildings/barracks_%s.png" % color_key
			_sprite.scale = Vector2(0.5, 0.5)
			_sprite.position = Vector2(0, -38)
		"tower":
			normal = "res://assets/buildings/tower_%s.png" % color_key
			construction = load("res://assets/buildings/tower_construction.png")
			destroyed = load("res://assets/buildings/tower_destroyed.png")
			_sprite.scale = Vector2(0.45, 0.45)
			_sprite.position = Vector2(0, -52)
		"storehouse":
			normal = "res://assets/buildings/storehouse_%s.png" % color_key
			construction = load("res://assets/buildings/house_construction.png")
			_sprite.scale = Vector2(0.6, 0.6)
			_sprite.position = Vector2(0, -30)
		"soldier_house":
			normal = "res://assets/buildings/soldier_house_%s.png" % color_key
			construction = load("res://assets/buildings/house_construction.png")
			_sprite.scale = Vector2(0.55, 0.55)
			_sprite.position = Vector2(0, -28)
	if is_destroyed():
		_sprite.texture = destroyed
		_sprite.modulate = Color(0.75, 0.75, 0.75)
	elif not is_constructed():
		if construction != null:
			_sprite.texture = construction
		else:
			_sprite.texture = load(normal)
	else:
		_sprite.texture = load(normal)

func _apply_node_visual() -> void:
	match sub:
		"wood":
			if flags & NetProtocol.F_STUMP != 0:
				_sprite.texture = load("res://assets/resources/stump%d.png" % (extra_i % 4 + 1))
				_sprite.scale = Vector2(1.3, 1.3)
				_sprite.position = Vector2(0, -140)
			else:
				var at := AtlasTexture.new()
				at.atlas = load("res://assets/deco/tree.png")
				at.region = Rect2(0, 0, 256, 256)
				_sprite.texture = at
				_sprite.scale = Vector2(0.62, 0.62) if flags & NetProtocol.F_BIG != 0 else Vector2(0.44, 0.44)
				_sprite.position = Vector2(0, -46)
		"stone":
			_sprite.texture = load("res://assets/deco/rock%d.png" % (extra_i % 2 + 1))
			_sprite.position = Vector2(0, -14)
			var base := 1.7 if flags & NetProtocol.F_BIG != 0 else 1.25
			var s := base * (0.55 + 0.45 * clampf(extra_f, 0.0, 1.0))
			_sprite.scale = Vector2(s, s)
		"gold":
			if flags & NetProtocol.F_BIG != 0:
				var state := "inactive"
				if is_depleted():
					state = "destroyed"
				elif extra_f < 1.0:
					state = "active"
				_sprite.texture = load("res://assets/resources/goldmine_%s.png" % state)
				_sprite.scale = Vector2(1.05, 1.05)
				_sprite.position = Vector2(0, -26)
			else:
				_sprite.texture = load("res://assets/resources/gold_stone%d.png" % (extra_i % 6 + 1))
				_sprite.position = Vector2(0, -14)
				var base2 := 1.25
				var s2 := base2 * (0.55 + 0.45 * clampf(extra_f, 0.0, 1.0))
				_sprite.scale = Vector2(s2, s2)
		"meat":
			_sprite.texture = load("res://assets/resources/meat.png")
			_sprite.scale = Vector2(0.85, 0.85)
			_sprite.position = Vector2(0, -12)

func _draw() -> void:
	if selected and (kind == "unit" or kind == "villager"):
		draw_arc(Vector2(0, 2), 17.0, 0.0, TAU, 24, Color(0.4, 1.0, 0.45, 0.9), 2.0)
	if kind == "node" or kind == "sheep":
		return
	if max_hp <= 0.0:
		return
	# Thanh máu kiểu game thật: chỉ vẽ khi mất máu (nhà/thành vẽ luôn).
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	if kind == "castle":
		var w := 130.0
		var pos := Vector2(-w / 2.0, -112.0)
		draw_rect(Rect2(pos, Vector2(w, 10)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(pos, Vector2(w * frac, 10)), Stats.FACTION_COLORS[color_key])
	elif kind == "building":
		var w := 84.0
		var pos := Vector2(-w / 2.0, -122.0) if sub == "tower" else Vector2(-w / 2.0, -96.0)
		if not is_constructed() and not is_destroyed():
			draw_rect(Rect2(pos, Vector2(w, 7)), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(pos, Vector2(w * clampf(extra_f, 0.0, 1.0), 7)), Color(1.0, 0.8, 0.3))
		else:
			draw_rect(Rect2(pos, Vector2(w, 7)), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(pos, Vector2(w * frac, 7)), Stats.FACTION_COLORS[color_key])
	elif hp < max_hp:
		var w := 36.0
		var pos := Vector2(-w / 2.0, -48.0)
		draw_rect(Rect2(pos, Vector2(w, 5)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(pos, Vector2(w * frac, 5)), Color(0.45, 1.0, 0.45))
