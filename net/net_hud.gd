class_name NetHud
extends CanvasLayer

## NetHud — UI tối thiểu cho chế độ LAN: phòng chờ + HUD trận rút gọn.
## HUD chơi đơn (hud.gd) đọc trạng thái thật từ Main nên KHÔNG dùng lại được
## phía client (client không có trạng thái thật); HUD này chỉ đọc dữ liệu
## server gửi về (lobby_update + trường "you" trong snapshot) và gửi lệnh
## qua NetController — đúng ranh giới tầng dữ liệu của thiết kế.
## Bố cục theo bản C đã chốt của HUD chính: viên thuốc tài nguyên nổi giữa
## trên, thẻ nổi giữa dưới, thông báo ở giữa.

var client: Node = null # NetClient

var _lobby_panel: Panel = null
var _lobby_title: Label = null
var _lobby_rows: Label = null
var _lobby_status: Label = null
var _btn_ready: Button = null
var _btn_start: Button = null

var _pill: Label = null
var _msg: Label = null
var _msg_timer: float = 0.0
var _bottom: HBoxContainer = null
var _alloc_box: VBoxContainer = null
var _bar_sig: String = ""
var _end_panel: Panel = null
var _end_label: Label = null

const SLOT_NAMES := ["Xanh Dương", "Vàng", "Đỏ", "Tím"]
const BUILD_TYPES := ["house", "barracks", "tower", "storehouse", "soldier_house"]
const TRAIN_AT_CASTLE := ["pawn", "warrior"]
const TRAIN_AT_BARRACKS := ["warrior", "archer", "lancer"]

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.13, 0.88)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _mk_label(text: String, size: int, color: Color = Color(0.92, 0.93, 0.97)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l

func _mk_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 14)
	return b

func setup(p_client: Node) -> void:
	client = p_client
	_build_lobby()
	_build_game_hud()
	_build_end()
	show_lobby()

# ============================ PHÒNG CHỜ ============================

func _build_lobby() -> void:
	_lobby_panel = Panel.new()
	_lobby_panel.add_theme_stylebox_override("panel", _panel_style())
	_lobby_panel.position = Vector2(400, 130)
	_lobby_panel.size = Vector2(480, 440)
	add_child(_lobby_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 10)
	_lobby_panel.add_child(vb)
	_lobby_title = _mk_label("PHÒNG CHỜ — CHƠI QUA MẠNG LAN", 22, Color(1.0, 0.85, 0.3))
	_lobby_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_lobby_title)
	_lobby_status = _mk_label("Đang kết nối...", 15)
	_lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_lobby_status)
	_lobby_rows = _mk_label("", 17)
	_lobby_rows.custom_minimum_size = Vector2(440, 170)
	vb.add_child(_lobby_rows)
	_btn_ready = _mk_button("SẴN SÀNG")
	_btn_ready.pressed.connect(func() -> void: client.ui_ready())
	vb.add_child(_btn_ready)
	_btn_start = _mk_button("BẮT ĐẦU TRẬN (chủ phòng)")
	_btn_start.pressed.connect(func() -> void: client.ui_start())
	vb.add_child(_btn_start)
	var note := _mk_label("Slot trống sẽ do BOT lấp khi trận bắt đầu.\nChủ phòng là người kết nối đầu tiên.", 13, Color(0.7, 0.75, 0.85))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(note)

func show_lobby() -> void:
	_lobby_panel.visible = true
	_pill.visible = false
	_bottom.visible = false
	_alloc_box.visible = false

func refresh_lobby() -> void:
	if client == null:
		return
	_lobby_status.text = String(client.conn_status)
	var lines: Array = []
	var slots: Dictionary = client.lobby_slots
	for slot in range(4):
		var info: Dictionary = slots.get(slot, {"kind": "bot"})
		var color: String = SLOT_NAMES[slot]
		if String(info.get("kind", "bot")) == "human":
			var nm: String = String(info.get("name", "?"))
			var st := "đã sẵn sàng" if bool(info.get("ready", false)) else "chưa sẵn sàng"
			if not bool(info.get("connected", true)):
				st = "ĐANG RỚT MẠNG (giữ slot 60s)"
			var host_tag := " — CHỦ PHÒNG" if bool(info.get("is_host", false)) else ""
			var me_tag := " (BẠN)" if slot == client.slot else ""
			lines.append("Phe %s: %s%s — %s%s" % [color, nm, me_tag, st, host_tag])
		else:
			lines.append("Phe %s: BOT (tự động lấp)" % color)
	_lobby_rows.text = "\n".join(lines)
	_btn_ready.disabled = client.slot < 0 or bool(client.my_ready)
	_btn_start.visible = bool(client.is_host)
	_btn_start.disabled = client.slot < 0

# ============================ HUD TRẬN ============================

func _build_game_hud() -> void:
	_pill = _mk_label("", 16)
	_pill.position = Vector2(340, 8)
	_pill.size = Vector2(600, 30)
	_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_pill)
	_msg = _mk_label("", 16, Color(1.0, 0.9, 0.45))
	_msg.position = Vector2(240, 640)
	_msg.size = Vector2(800, 26)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_msg)
	_bottom = HBoxContainer.new()
	_bottom.position = Vector2(190, 672)
	_bottom.add_theme_constant_override("separation", 6)
	add_child(_bottom)
	_alloc_box = VBoxContainer.new()
	_alloc_box.position = Vector2(8, 250)
	_alloc_box.add_theme_constant_override("separation", 4)
	add_child(_alloc_box)
	var title := _mk_label("PHÂN BỔ NÔNG DÂN", 13, Color(1.0, 0.85, 0.3))
	_alloc_box.add_child(title)
	for key in ["wood", "stone", "gold", "meat"]:
		var k: String = key # bản sao cho lambda bắt đúng loại tài nguyên của hàng này
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var nm := _mk_label(Stats.RES_LABELS[k], 14)
		nm.custom_minimum_size = Vector2(38, 0)
		row.add_child(nm)
		var minus := _mk_button("−")
		minus.pressed.connect(func() -> void: client.ui_alloc(k, -1))
		row.add_child(minus)
		var cnt := _mk_label("0", 14)
		cnt.name = "cnt_" + k
		cnt.custom_minimum_size = Vector2(22, 0)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(cnt)
		var plus := _mk_button("+")
		plus.pressed.connect(func() -> void: client.ui_alloc(k, 1))
		row.add_child(plus)
		_alloc_box.add_child(row)

func show_game() -> void:
	_lobby_panel.visible = false
	_pill.visible = true
	_bottom.visible = true
	_alloc_box.visible = true
	_bar_sig = ""

func refresh_you() -> void:
	if client == null or not bool(client.match_running):
		return
	var you: Dictionary = client.player_you
	if you.is_empty():
		return
	var res: Dictionary = you.get("resources", {})
	_pill.text = "Gỗ %d • Đá %d • Vàng %d • Thịt %d   |   Dân %d/%d • Quân %d/%d" % [
		int(res.get("wood", 0)), int(res.get("stone", 0)), int(res.get("gold", 0)), int(res.get("meat", 0)),
		int(you.get("pop_used", 0)), int(you.get("pop_cap", 0)),
		int(you.get("army_used", 0)), int(you.get("army_cap", 0))]
	var alloc: Dictionary = you.get("allocation", {})
	for key in ["wood", "stone", "gold", "meat"]:
		var cnt := _alloc_box.find_child("cnt_" + key, true, false) as Label
		if cnt != null:
			cnt.text = str(int(alloc.get(key, 0)))
	_refresh_bottom(you)

func _refresh_bottom(you: Dictionary) -> void:
	# Chữ ký = các nhà sản xuất của mình + hàng chờ + chế độ đang mở; đổi mới dựng lại.
	var world: NetGhostWorld = client.world
	if world == null:
		return
	var producers: Array = []
	for g in world.ghosts.values():
		var gh := g as NetGhost
		if gh.owner_pid == client.slot and (gh.kind == "castle" or (gh.kind == "building" and gh.sub == "barracks")):
			producers.append(gh)
	producers.sort_custom(func(a: NetGhost, b: NetGhost) -> bool: return a.net_id < b.net_id)
	var queues: Dictionary = you.get("queues", {})
	var sig := ""
	for p in producers:
		sig += "%d:%d;" % [(p as NetGhost).net_id, int(queues.get(str((p as NetGhost).net_id), 0))]
	if sig == _bar_sig:
		return
	_bar_sig = sig
	for c in _bottom.get_children():
		c.queue_free()
	var build_title := _mk_label("XÂY:", 14, Color(1.0, 0.85, 0.3))
	_bottom.add_child(build_title)
	for btype in BUILD_TYPES:
		var def: Dictionary = Stats.BUILDINGS[btype]
		var b := _mk_button("%s (%s)" % [String(def["label"]), Stats.cost_text(def["cost"])])
		var t: String = btype
		b.pressed.connect(func() -> void: client.ui_build(t))
		_bottom.add_child(b)
	for p in producers:
		var gh := p as NetGhost
		var units: Array = TRAIN_AT_CASTLE if gh.kind == "castle" else TRAIN_AT_BARRACKS
		var pname := "Thành" if gh.kind == "castle" else "Doanh trại"
		var q := int(queues.get(str(gh.net_id), 0))
		var lbl := _mk_label("%s%s:" % [pname, " (đang luyện %d)" % q if q > 0 else ""], 14, Color(1.0, 0.85, 0.3))
		_bottom.add_child(lbl)
		for ut in units:
			var tdef: Dictionary = Stats.TRAINING[ut]
			var b2 := _mk_button("%s (%s)" % [String(Stats.UNITS[ut]["label"]), Stats.cost_text(tdef["cost"])])
			var pid2 := gh.net_id
			var u2: String = ut
			b2.pressed.connect(func() -> void: client.ui_train(pid2, u2))
			_bottom.add_child(b2)
	var stance_title := _mk_label("QUÂN:", 14, Color(1.0, 0.85, 0.3))
	_bottom.add_child(stance_title)
	var b_hold := _mk_button("Giữ nhà")
	b_hold.pressed.connect(func() -> void: client.ui_hold())
	_bottom.add_child(b_hold)
	var b_atk := _mk_button("Tổng tấn công…")
	b_atk.pressed.connect(func() -> void: client.ui_attack_mode())
	_bottom.add_child(b_atk)
	var b_scout := _mk_button("Trinh sát…")
	b_scout.pressed.connect(func() -> void: client.ui_scout_mode())
	_bottom.add_child(b_scout)

# ============================ THÔNG BÁO / KẾT TRẬN ============================

func show_message(text: String) -> void:
	_msg.text = text
	_msg_timer = 4.0

func _process(delta: float) -> void:
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			_msg.text = ""

func _build_end() -> void:
	_end_panel = Panel.new()
	_end_panel.add_theme_stylebox_override("panel", _panel_style())
	_end_panel.position = Vector2(440, 260)
	_end_panel.size = Vector2(400, 170)
	_end_panel.visible = false
	add_child(_end_panel)
	_end_label = _mk_label("", 20)
	_end_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_panel.add_child(_end_label)

func show_end(text: String) -> void:
	_end_label.text = text
	_end_panel.visible = true
