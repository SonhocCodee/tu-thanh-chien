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
var _lobby_status: Label = null
var _btn_ready: Button = null
var _btn_start: Button = null
# Phòng chờ v3: 2 hộp nội dung trong cùng 1 panel — hộp VÀO PHÒNG (tạo
# phòng / nhập mã) và hộp LOBBY (mã phòng + slot + nút của chủ phòng).
# Mọi control dựng 1 lần lúc setup, refresh chỉ đổi text/visible (không
# dựng lại) để ô nhập liệu không bị xoá chữ giữa chừng.
var _entry_box: VBoxContainer = null
var _create_box: VBoxContainer = null
var _join_box: VBoxContainer = null
var _join_info: Label = null
var _entry_error: Label = null
var _edit_name_create: LineEdit = null
var _edit_room_name: LineEdit = null
var _edit_name_join: LineEdit = null
var _edit_code: LineEdit = null
var _room_box: VBoxContainer = null
var _room_title: Label = null
var _code_label: Label = null
var _rename_row: HBoxContainer = null
var _edit_rename: LineEdit = null
var _slot_labels: Array = [] # 4 Label của 4 hàng slot
var _slot_btns: Array = [] # 4 Button đổi chế độ slot (chỉ chủ phòng thấy)
var _lobby_error: Label = null
var _lobby_note: Label = null

var _pill: Label = null
var _msg: Label = null
var _msg_timer: float = 0.0
var _bottom: HBoxContainer = null
var _bottom2: HBoxContainer = null # hàng 2: chợ + lệnh quân (hàng 1: xây + luyện + panel nhà)
var _alloc_box: VBoxContainer = null
var _bar_sig: String = ""
var _end_panel: Panel = null
var _end_label: Label = null

const SLOT_NAMES := ["Xanh Dương", "Vàng", "Đỏ", "Tím"]
# Đủ 9 loại nhà của game hiện tại (thứ tự trình bày ở hàng XÂY).
const BUILD_TYPES := ["house", "barracks", "tower", "soldier_house",
	"store_wood", "store_stone", "store_gold", "store_meat", "farm"]
# Loại nhà nâng cấp được (khớp Building.UPGRADE_TEX — ruộng KHÔNG có).
const UPGRADEABLE := ["house", "barracks", "tower", "store_wood", "store_stone",
	"store_gold", "store_meat", "soldier_house"]

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
	show_entry()

# ============================ PHÒNG CHỜ ============================

func _mk_edit(placeholder: String, text: String = "", max_len: int = 0) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.max_length = max_len
	e.add_theme_font_size_override("font_size", 15)
	e.custom_minimum_size = Vector2(0, 34)
	return e

func _build_lobby() -> void:
	_lobby_panel = Panel.new()
	_lobby_panel.add_theme_stylebox_override("panel", _panel_style())
	_lobby_panel.position = Vector2(330, 84)
	_lobby_panel.size = Vector2(620, 552)
	add_child(_lobby_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 8)
	_lobby_panel.add_child(vb)
	_lobby_title = _mk_label("CHƠI QUA MẠNG LAN", 22, Color(1.0, 0.85, 0.3))
	_lobby_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_lobby_title)
	_lobby_status = _mk_label("Đang kết nối...", 14)
	_lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_lobby_status)
	# ---------- Hộp VÀO PHÒNG (prejoin) ----------
	_entry_box = VBoxContainer.new()
	_entry_box.add_theme_constant_override("separation", 8)
	vb.add_child(_entry_box)
	_create_box = VBoxContainer.new()
	_create_box.add_theme_constant_override("separation", 6)
	_entry_box.add_child(_create_box)
	var create_title := _mk_label("TẠO PHÒNG MỚI", 17, Color(1.0, 0.85, 0.3))
	create_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_create_box.add_child(create_title)
	_edit_room_name = _mk_edit("Tên phòng", "Phòng của chủ nhà", 40)
	_create_box.add_child(_edit_room_name)
	_edit_name_create = _mk_edit("Tên hiển thị của bạn", "", 24)
	_create_box.add_child(_edit_name_create)
	var btn_create := _mk_button("TẠO PHÒNG")
	btn_create.pressed.connect(func() -> void:
		client.ui_create_room(_edit_name_create.text, _edit_room_name.text))
	_create_box.add_child(btn_create)
	var create_note := _mk_label("Tạo phòng xong, game cho bạn 1 MÃ PHÒNG —\ngửi link + mã cho bạn bè cùng Wi-Fi để họ vào.", 13, Color(0.7, 0.75, 0.85))
	create_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_create_box.add_child(create_note)
	_join_box = VBoxContainer.new()
	_join_box.add_theme_constant_override("separation", 6)
	_entry_box.add_child(_join_box)
	var join_title := _mk_label("VÀO PHÒNG", 17, Color(1.0, 0.85, 0.3))
	join_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_box.add_child(join_title)
	_join_info = _mk_label("", 14)
	_join_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_box.add_child(_join_info)
	_edit_name_join = _mk_edit("Tên hiển thị của bạn", "", 24)
	_join_box.add_child(_edit_name_join)
	_edit_code = _mk_edit("MÃ PHÒNG (6 ký tự)", "", 6)
	_join_box.add_child(_edit_code)
	var btn_join := _mk_button("VÀO PHÒNG")
	btn_join.pressed.connect(func() -> void:
		client.ui_join_room(_edit_name_join.text, _edit_code.text))
	_join_box.add_child(btn_join)
	_entry_error = _mk_label("", 14, Color(1.0, 0.45, 0.4))
	_entry_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entry_box.add_child(_entry_error)
	# ---------- Hộp LOBBY (đã có slot) ----------
	_room_box = VBoxContainer.new()
	_room_box.add_theme_constant_override("separation", 7)
	vb.add_child(_room_box)
	_room_title = _mk_label("", 20, Color(1.0, 0.85, 0.3))
	_room_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_box.add_child(_room_title)
	_code_label = _mk_label("", 27, Color(1.0, 0.85, 0.3))
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_box.add_child(_code_label)
	_rename_row = HBoxContainer.new()
	_rename_row.add_theme_constant_override("separation", 6)
	_room_box.add_child(_rename_row)
	_edit_rename = _mk_edit("Tên phòng mới", "", 40)
	_edit_rename.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rename_row.add_child(_edit_rename)
	var btn_rename := _mk_button("ĐỔI TÊN")
	btn_rename.pressed.connect(func() -> void: client.ui_rename_room(_edit_rename.text))
	_rename_row.add_child(btn_rename)
	for slot in range(4):
		var s: int = slot # bản sao cho lambda bắt đúng slot của hàng này
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_room_box.add_child(row)
		var lb := _mk_label("", 15)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lb)
		_slot_labels.append(lb)
		var b := _mk_button("")
		b.custom_minimum_size = Vector2(168, 0)
		b.pressed.connect(func() -> void: _cycle_slot(s))
		row.add_child(b)
		_slot_btns.append(b)
	_lobby_error = _mk_label("", 14, Color(1.0, 0.45, 0.4))
	_lobby_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_box.add_child(_lobby_error)
	_btn_ready = _mk_button("SẴN SÀNG")
	_btn_ready.pressed.connect(func() -> void: client.ui_ready())
	_room_box.add_child(_btn_ready)
	_btn_start = _mk_button("BẮT ĐẦU TRẬN (chủ phòng)")
	_btn_start.pressed.connect(func() -> void: client.ui_start())
	_room_box.add_child(_btn_start)
	_lobby_note = _mk_label("", 13, Color(0.7, 0.75, 0.85))
	_lobby_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_room_box.add_child(_lobby_note)

## Chủ phòng bấm nút chế độ của 1 slot trống: xoay vòng
## CHỜ NGƯỜI -> BOT -> ĐÓNG -> CHỜ NGƯỜI (server là nơi chốt thật).
const SLOT_MODE_CYCLE := {"open": "bot", "bot": "closed", "closed": "open"}
const SLOT_MODE_LABEL := {"open": "CHỜ NGƯỜI", "bot": "BOT", "closed": "ĐÓNG"}

func _cycle_slot(target_slot: int) -> void:
	var info: Dictionary = client.lobby_slots.get(target_slot, {})
	var kind := String(info.get("kind", "open"))
	client.ui_set_slot_mode(target_slot, String(SLOT_MODE_CYCLE.get(kind, "open")))

func _hide_game_hud() -> void:
	_pill.visible = false
	_bottom.visible = false
	_bottom2.visible = false
	_alloc_box.visible = false

func show_entry() -> void:
	_lobby_panel.visible = true
	_entry_box.visible = true
	_room_box.visible = false
	_hide_game_hud()
	refresh_entry()

func show_lobby() -> void:
	_lobby_panel.visible = true
	_entry_box.visible = false
	_room_box.visible = true
	_hide_game_hud()
	refresh_lobby()

func refresh_entry() -> void:
	if client == null:
		return
	_lobby_status.text = String(client.conn_status)
	var has_room := bool(client.room_info.get("exists", false))
	_create_box.visible = not has_room
	_join_box.visible = has_room
	if has_room:
		_join_info.text = "Phòng \"%s\" đang mở — nhập mã chủ phòng đã gửi:" % String(client.room_info.get("name", ""))
	if _edit_name_create.text == "":
		_edit_name_create.text = String(client._my_name)
	if _edit_name_join.text == "":
		_edit_name_join.text = String(client._my_name)
	_entry_error.text = String(client.lobby_error)

func refresh_lobby() -> void:
	if client == null:
		return
	if client.slot < 0:
		# Chưa có slot (prejoin / bị từ chối): màn hình vào phòng lo hết.
		show_entry()
		return
	if not _room_box.visible:
		show_lobby()
		return
	_lobby_status.text = String(client.conn_status)
	_room_title.text = String(client.room_info.get("name", ""))
	_code_label.text = "MÃ PHÒNG: %s" % String(client.room_info.get("code", ""))
	_rename_row.visible = bool(client.is_host)
	_lobby_error.text = String(client.lobby_error)
	var slots: Dictionary = client.lobby_slots
	for slot in range(4):
		var info: Dictionary = slots.get(slot, {"kind": "open"})
		var kind := String(info.get("kind", "open"))
		var lb := _slot_labels[slot] as Label
		var btn := _slot_btns[slot] as Button
		if kind == "human":
			var st := "đã sẵn sàng" if bool(info.get("ready", false)) else "chưa sẵn sàng"
			if not bool(info.get("connected", true)):
				st = "ĐANG RỚT MẠNG (giữ slot 60s)"
			var host_tag := " — CHỦ PHÒNG" if bool(info.get("is_host", false)) else ""
			var me_tag := " (BẠN)" if slot == client.slot else ""
			lb.text = "Phe %s: %s%s — %s%s" % [SLOT_NAMES[slot], String(info.get("name", "?")), me_tag, st, host_tag]
			btn.visible = false
		else:
			match kind:
				"bot":
					lb.text = "Phe %s: BOT giữ chỗ" % SLOT_NAMES[slot]
				"closed":
					lb.text = "Phe %s: ĐÃ ĐÓNG — không tham gia trận" % SLOT_NAMES[slot]
				_:
					lb.text = "Phe %s: TRỐNG — chờ người vào" % SLOT_NAMES[slot]
			btn.visible = bool(client.is_host)
			btn.text = "Chế độ: %s ▸" % String(SLOT_MODE_LABEL.get(kind, kind))
	_btn_ready.disabled = bool(client.my_ready)
	_btn_start.visible = bool(client.is_host)
	if client.is_host:
		_lobby_note.text = "Bấm nút chế độ ở mỗi slot trống để đổi: CHỜ NGƯỜI (ai vào cũng được, trống lúc bắt đầu thì BOT lấp) / BOT / ĐÓNG (phe không tham gia)."
	else:
		_lobby_note.text = "Chờ chủ phòng bắt đầu trận..."

# ============================ HUD TRẬN ============================

func _build_game_hud() -> void:
	_pill = _mk_label("", 16)
	_pill.position = Vector2(340, 8)
	_pill.size = Vector2(600, 30)
	_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_pill)
	_msg = _mk_label("", 16, Color(1.0, 0.9, 0.45))
	_msg.position = Vector2(240, 596)
	_msg.size = Vector2(800, 26)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_msg)
	_bottom = HBoxContainer.new()
	_bottom.position = Vector2(8, 630)
	_bottom.add_theme_constant_override("separation", 6)
	add_child(_bottom)
	_bottom2 = HBoxContainer.new()
	_bottom2.position = Vector2(8, 676)
	_bottom2.add_theme_constant_override("separation", 6)
	add_child(_bottom2)
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
	_bottom2.visible = true
	_alloc_box.visible = true
	_bar_sig = ""

func refresh_you() -> void:
	if client == null or not bool(client.match_running):
		return
	var you: Dictionary = client.player_you
	if you.is_empty():
		return
	var res: Dictionary = you.get("resources", {})
	_pill.text = "Gỗ %d • Đá %d • Vàng %d • Thịt %d   |   Dân %d/%d • Quân %d/%d   |   ĐỜI %d" % [
		int(res.get("wood", 0)), int(res.get("stone", 0)), int(res.get("gold", 0)), int(res.get("meat", 0)),
		int(you.get("pop_used", 0)), int(you.get("pop_cap", 0)),
		int(you.get("army_used", 0)), int(you.get("army_cap", 0)),
		int(you.get("age", 1))]
	var alloc: Dictionary = you.get("allocation", {})
	for key in ["wood", "stone", "gold", "meat"]:
		var cnt := _alloc_box.find_child("cnt_" + key, true, false) as Label
		if cnt != null:
			cnt.text = str(int(alloc.get(key, 0)))
	_refresh_bottom(you)

func _refresh_bottom(you: Dictionary) -> void:
	# Chữ ký = nhà sản xuất + hàng chờ + Đời/cấp chợ/công trình đang chọn;
	# đổi mới dựng lại hàng nút.
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
	var research: Dictionary = you.get("research", {})
	var market: Dictionary = you.get("market", {})
	var sel := world.ghost(world.selected_structure_id) if world.selected_structure_id != 0 else null
	var sig := ""
	for p in producers:
		sig += "%d:%d:%s;" % [(p as NetGhost).net_id, int(queues.get(str((p as NetGhost).net_id), 0)),
			String(research.get(str((p as NetGhost).net_id), ""))]
	sig += "|age=%d|sel=%d:%s:%d|mkt=" % [int(you.get("age", 1)), world.selected_structure_id,
		(sel as NetGhost).sub if sel != null else "", (sel as NetGhost).extra_i if sel != null else 0]
	for k in ["wood", "stone", "meat"]:
		var row: Dictionary = market.get(k, {})
		sig += "%s:%.3f;" % [k, float(row.get("factor", 1.0))]
	if sig == _bar_sig:
		return
	_bar_sig = sig
	for c in _bottom.get_children():
		c.queue_free()
	for c in _bottom2.get_children():
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
		var kind := "castle" if gh.kind == "castle" else "barracks"
		var units: Array = Stats.PRODUCERS[kind]["units"]
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
	# --- Panel công trình đang chọn: Lên Đời / Nghiên cứu / Nâng cấp ---
	if sel != null:
		var sgh := sel as NetGhost
		var levels: Dictionary = you.get("unit_levels", {})
		if sgh.kind == "castle":
			var age := int(you.get("age", 1))
			if age < int(Stats.MAX_AGE):
				var adef: Dictionary = Stats.AGES[age + 1]
				var bage := _mk_button("LÊN ĐỜI %d (%s)" % [age + 1, Stats.cost_text(adef["cost"])])
				bage.pressed.connect(func() -> void: client.ui_age_up())
				_bottom.add_child(bage)
			var plv := int(levels.get("pawn", 1))
			if plv < int(Stats.MAX_LEVEL):
				var bres := _mk_button("NC Nông dân→%d" % (plv + 1))
				bres.pressed.connect(func() -> void: client.ui_research("pawn"))
				_bottom.add_child(bres)
		elif sgh.kind == "building" and sgh.sub == "barracks":
			for ut in ["warrior", "archer", "lancer"]:
				var lv := int(levels.get(ut, 1))
				if lv < int(Stats.MAX_LEVEL):
					var br := _mk_button("NC %s→%d" % [String(Stats.UNITS[ut]["label"]), lv + 1])
					var u3: String = ut
					br.pressed.connect(func() -> void: client.ui_research(u3))
					_bottom.add_child(br)
		elif sgh.kind == "building" and UPGRADEABLE.has(sgh.sub):
			if sgh.extra_i < int(Stats.MAX_LEVEL):
				var bup := _mk_button("NÂNG CẤP NHÀ→%d" % (sgh.extra_i + 1))
				bup.pressed.connect(func() -> void: client.ui_upgrade())
				_bottom.add_child(bup)
	# --- Hàng 2: Chợ (bán/mua 1 gói 100 tại Thành, giá của phe mình) ---
	var mkt_title := _mk_label("CHỢ:", 14, Color(1.0, 0.85, 0.3))
	_bottom2.add_child(mkt_title)
	for k in ["wood", "stone", "meat"]:
		var key: String = k
		var row2: Dictionary = market.get(key, {"sell": 0, "buy": 0})
		var bs := _mk_button("Bán %s +%dv" % [String(Stats.RES_LABELS[key]), int(row2.get("sell", 0))])
		bs.pressed.connect(func() -> void: client.ui_market_sell(key))
		_bottom2.add_child(bs)
		var bb := _mk_button("Mua %s −%dv" % [String(Stats.RES_LABELS[key]), int(row2.get("buy", 0))])
		bb.pressed.connect(func() -> void: client.ui_market_buy(key))
		_bottom2.add_child(bb)
	var stance_title := _mk_label("QUÂN:", 14, Color(1.0, 0.85, 0.3))
	_bottom2.add_child(stance_title)
	var b_hold := _mk_button("Giữ nhà")
	b_hold.pressed.connect(func() -> void: client.ui_hold())
	_bottom2.add_child(b_hold)
	var b_atk := _mk_button("Tổng tấn công…")
	b_atk.pressed.connect(func() -> void: client.ui_attack_mode())
	_bottom2.add_child(b_atk)
	var b_scout := _mk_button("Trinh sát…")
	b_scout.pressed.connect(func() -> void: client.ui_scout_mode())
	_bottom2.add_child(b_scout)
	var b_am := _mk_button("Đánh-di-chuyển (A)")
	b_am.pressed.connect(func() -> void: client.ui_attack_move_mode())
	_bottom2.add_child(b_am)
	var b_pt := _mk_button("Tuần tra (P)")
	b_pt.pressed.connect(func() -> void: client.ui_patrol_mode())
	_bottom2.add_child(b_pt)
	var b_gd := _mk_button("Hộ vệ (G)")
	b_gd.pressed.connect(func() -> void: client.ui_guard_mode())
	_bottom2.add_child(b_gd)

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
