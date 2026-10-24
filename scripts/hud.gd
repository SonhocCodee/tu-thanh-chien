class_name Hud
extends CanvasLayer

## HUD: chỉ HIỂN THỊ trạng thái và gọi lệnh qua PlayerController của người chơi.
## Không chứa logic game.

var game: Node = null
var ctrl: PlayerController = null

var _res_label: Label
var _pop_label: Label
var _army_label: Label
var _clock_label: Label
var _stance_label: Label
var _msg_label: Label
var _alloc_labels: Dictionary = {}
var _alloc_minus: Dictionary = {}
var _alloc_plus: Dictionary = {}
var _villager_label: Label
var _build_buttons: Dictionary = {}
var _train_castle_buttons: Dictionary = {}
var _train_barracks_buttons: Dictionary = {}
var _castle_queue_label: Label
var _barracks_queue_label: Label
var _end_panel: Panel = null
var _msg_timer: float = 0.0
var _help_panel: Panel = null
var _sel_label: Label = null

func setup(p_game: Node, p_ctrl: PlayerController) -> void:
	game = p_game
	ctrl = p_ctrl

func _ready() -> void:
	# --- Thanh trên ---
	var top := Panel.new()
	top.position = Vector2(0, 0)
	top.size = Vector2(1280, 38)
	add_child(top)
	_res_label = _mk_label(top, Vector2(12, 8), 18)
	_pop_label = _mk_label(top, Vector2(410, 8), 18)
	_army_label = _mk_label(top, Vector2(548, 8), 18)
	_clock_label = _mk_label(top, Vector2(705, 8), 18)
	_stance_label = _mk_label(top, Vector2(885, 8), 18)
	_msg_label = _mk_label(top, Vector2(12, 40), 16)
	_msg_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_msg_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_msg_label.add_theme_constant_override("shadow_offset_x", 1)
	_msg_label.add_theme_constant_override("shadow_offset_y", 1)

	# --- Nút Trợ giúp (thanh trên) ---
	var help_btn := _mk_button(top, Vector2(1150, 5), Vector2(110, 28), "Trợ giúp")
	help_btn.pressed.connect(show_help)

	# --- Minimap góc phải trên ---
	var mm := Minimap.new()
	mm.game = game
	mm.position = Vector2(1068, 44)
	mm.size = Vector2(204, 102)
	add_child(mm)
	var mm_title := Label.new()
	mm_title.text = "Bản đồ nhỏ"
	mm_title.position = Vector2(1068, 146)
	mm_title.add_theme_font_size_override("font_size", 12)
	add_child(mm_title)
	_sel_label = _mk_label(self, Vector2(1068, 164), 13)
	_sel_label.add_theme_color_override("font_color", Color(0.5, 1, 0.6))

	# --- Panel hướng dẫn M2 (tự mở khi vào trận, tắt/mở lại được) ---
	_help_panel = Panel.new()
	_help_panel.position = Vector2(340, 150)
	_help_panel.size = Vector2(600, 400)
	_help_panel.visible = false
	add_child(_help_panel)
	var help_title := _mk_label(_help_panel, Vector2(20, 12), 18)
	help_title.text = "HƯỚNG DẪN ĐIỀU KHIỂN"
	help_title.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	var help_body := _mk_label(_help_panel, Vector2(20, 44), 14)
	help_body.size = Vector2(560, 300)
	help_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_body.text = "\n".join([
		"KÉO CHUỘT TRÁI: chọn quân trong khung (vòng xanh = đã chọn).",
		"CLICK TRÁI 1 đơn vị: chọn riêng nó. Bấm đất trống / quân địch: bỏ chọn.",
		"CLICK PHẢI ĐẤT TRỐNG: quân đã chọn di chuyển tới đó.",
		"CLICK PHẢI CÂY/MỎ: nông dân đã chọn đi farm đúng loại đó. CLICK PHẢI CỪU: nông dân đi săn lấy thịt.",
		"CLICK PHẢI QUÂN/CÔNG TRÌNH ĐỊCH: tấn công (chỉ mục tiêu đã lộ diện — chưa lộ thì game từ chối, cần trinh sát trước).",
		"LIA CAMERA: đưa chuột ra mép màn hình, phím WASD / mũi tên, hoặc bấm vào bản đồ nhỏ.",
		"PHÂN BỔ: nút +/- chia nông dân farm gỗ/đá/vàng/thịt — phân thịt là đi SĂN CỪU (lệnh click phải ưu tiên hơn phân bổ).",
		"XÂY: bấm nút công trình rồi bấm vào vùng sáng quanh thành. NHÀ KHO: điểm giao tài nguyên, đặt được ở mọi vùng đã khám phá. LUYỆN QUÂN: nút ở thành/doanh trại.",
		"THÁI ĐỘ: GIỮ NHÀ (quân ở nhà thủ) / TỔNG TẤN CÔNG (đánh thành địch đã lộ diện).",
		"GIỚI HẠN QUÂN: quân có giới hạn riêng theo Ô (xem 'Quân: x/y ô') — xây NHÀ LÍNH để tăng. LÍNH GIÁO là tinh nhuệ: mạnh hơn hẳn kiếm sĩ nhưng chiếm 2 ô.",
		"SƯƠNG MÙ: đen = chưa khám phá, mờ = đã qua (chỉ mờ đi, không đen lại), sáng = đang nhìn thấy.",
	])
	var help_close := _mk_button(_help_panel, Vector2(240, 350), Vector2(120, 36), "Đã hiểu")
	help_close.pressed.connect(close_help)

	# --- Panel dưới ---
	var bottom := Panel.new()
	bottom.position = Vector2(0, 610)
	bottom.size = Vector2(1280, 110)
	add_child(bottom)
	_mk_title(bottom, Vector2(12, 4), "Phân bổ nông dân")
	_villager_label = _mk_label(bottom, Vector2(12, 84), 13)
	var res_keys := ["wood", "stone", "gold", "meat"]
	for i in 4:
		var x := 12 + i * 74
		var key: String = res_keys[i]
		var name_lbl := _mk_label(bottom, Vector2(x, 26), 14)
		name_lbl.text = Stats.RES_LABELS[key]
		var minus := _mk_button(bottom, Vector2(x, 48), Vector2(22, 26), "-")
		var count := _mk_label(bottom, Vector2(x + 25, 50), 16)
		var plus := _mk_button(bottom, Vector2(x + 47, 48), Vector2(22, 26), "+")
		_alloc_labels[key] = count
		_alloc_minus[key] = minus
		_alloc_plus[key] = plus
		minus.pressed.connect(_on_alloc.bind(key, -1))
		plus.pressed.connect(_on_alloc.bind(key, 1))

	_mk_title(bottom, Vector2(312, 4), "Xây dựng (bấm rồi bấm vào vùng quanh thành)")
	for i in Stats.BUILDINGS.keys().size():
		var btype: String = Stats.BUILDINGS.keys()[i]
		var def: Dictionary = Stats.BUILDINGS[btype]
		var btn := _mk_button(bottom, Vector2(312 + (i % 3) * 108, 24 + (i / 3) * 40), Vector2(102, 36), "%s\n%s" % [def["label"], Stats.cost_text(def["cost"])])
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_build.bind(btype))
		_build_buttons[btype] = btn

	_mk_title(bottom, Vector2(648, 4), "Huấn luyện")
	var row1 := _mk_label(bottom, Vector2(648, 26), 13)
	row1.text = "Thành chính:"
	_train_castle_buttons["pawn"] = _mk_button(bottom, Vector2(742, 22), Vector2(88, 24), "Nông dân")
	_train_castle_buttons["warrior"] = _mk_button(bottom, Vector2(834, 22), Vector2(88, 24), "Kiếm sĩ")
	_castle_queue_label = _mk_label(bottom, Vector2(928, 26), 12)
	var row2 := _mk_label(bottom, Vector2(648, 58), 13)
	row2.text = "Doanh trại:"
	_train_barracks_buttons["warrior"] = _mk_button(bottom, Vector2(742, 54), Vector2(76, 24), "Kiếm sĩ")
	_train_barracks_buttons["archer"] = _mk_button(bottom, Vector2(820, 54), Vector2(76, 24), "Cung thủ")
	_train_barracks_buttons["lancer"] = _mk_button(bottom, Vector2(898, 54), Vector2(76, 24), "Lính giáo")
	_barracks_queue_label = _mk_label(bottom, Vector2(978, 58), 11)
	var cost_hint := _mk_label(bottom, Vector2(648, 82), 11)
	cost_hint.text = "Giá: Nông dân 50 thịt • Kiếm sĩ 80 vàng • Cung thủ 70 vàng + 30 gỗ\nLính giáo 150 vàng + 30 gỗ — TINH NHUỆ, chiếm 2 ô quân (Nhà Lính tăng giới hạn quân)"
	(_train_castle_buttons["pawn"] as Button).pressed.connect(func() -> void: ctrl.queue_training(game.castles[0], "pawn"))
	(_train_castle_buttons["warrior"] as Button).pressed.connect(func() -> void: ctrl.queue_training(game.castles[0], "warrior"))
	(_train_barracks_buttons["warrior"] as Button).pressed.connect(func() -> void: ctrl.queue_training(game.active_barracks(0), "warrior"))
	(_train_barracks_buttons["archer"] as Button).pressed.connect(func() -> void: ctrl.queue_training(game.active_barracks(0), "archer"))
	(_train_barracks_buttons["lancer"] as Button).pressed.connect(func() -> void: ctrl.queue_training(game.active_barracks(0), "lancer"))

	_mk_title(bottom, Vector2(1030, 4), "Điều quân")
	var hold_btn := _mk_button(bottom, Vector2(1030, 26), Vector2(110, 30), "GIỮ NHÀ")
	hold_btn.pressed.connect(func() -> void: ctrl.set_stance("hold"); show_message("Quân về thế GIỮ NHÀ."))
	var atk_btn := _mk_button(bottom, Vector2(1150, 26), Vector2(118, 30), "TẤN CÔNG…")
	atk_btn.pressed.connect(func() -> void: game.start_order_mode())
	var hint := _mk_label(bottom, Vector2(1030, 62), 12)
	hint.text = "Tấn công…: bấm thành địch\nđã lộ diện / điểm trinh sát."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size = Vector2(240, 44)

	# --- Banner kết trận ---
	_end_panel = Panel.new()
	_end_panel.position = Vector2(440, 260)
	_end_panel.size = Vector2(400, 170)
	_end_panel.visible = false
	_end_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_end_panel)

func _mk_label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l

func _mk_title(parent: Node, pos: Vector2, text: String) -> Label:
	var l := _mk_label(parent, pos, 14)
	l.text = text
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	return l

func _mk_button(parent: Node, pos: Vector2, sz: Vector2, text: String) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.text = text
	b.add_theme_font_size_override("font_size", 13)
	parent.add_child(b)
	return b

func show_message(text: String) -> void:
	_msg_label.text = text
	_msg_timer = 6.0

func show_help() -> void:
	if _help_panel != null:
		_help_panel.visible = true

func close_help() -> void:
	if _help_panel != null:
		_help_panel.visible = false

func _on_alloc(res_key: String, delta_sign: int) -> void:
	var p := ctrl.player
	var a := {"wood": int(p.allocation["wood"]), "stone": int(p.allocation["stone"]), "gold": int(p.allocation["gold"]), "meat": int(p.allocation["meat"])}
	a[res_key] = maxi(0, int(a[res_key]) + delta_sign)
	ctrl.set_villager_allocation(a["wood"], a["stone"], a["gold"], a["meat"])

func _on_build(btype: String) -> void:
	game.set_placement_mode(btype)

func _process(delta: float) -> void:
	if game == null or ctrl == null:
		return
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			_msg_label.text = ""
	var p := ctrl.player
	_res_label.text = "Gỗ: %d    Đá: %d    Vàng: %d    Thịt: %d" % [int(p.resources["wood"]), int(p.resources["stone"]), int(p.resources["gold"]), int(p.resources["meat"])]
	_pop_label.text = "Dân số: %d/%d" % [game.pop_used(0), game.pop_cap(0)]
	_army_label.text = "Quân: %d/%d ô" % [game.army_used(0), game.army_cap(0)]
	if _sel_label != null:
		var n_sel := ctrl.get_selection().size()
		_sel_label.text = "Đã chọn: %d" % n_sel if n_sel > 0 else ""
	var t := int(game.elapsed)
	_clock_label.text = "Thời gian: %02d:%02d" % [t / 60, t % 60]
	_stance_label.text = "Thái độ quân: %s" % ("GIỮ NHÀ" if p.stance == "hold" else ("TỔNG TẤN CÔNG" if p.stance == "attack" else "TRINH SÁT"))
	var total_v: int = game.villager_count(0)
	var busy := 0
	for k in Stats.RES_KEYS:
		(_alloc_labels[k] as Label).text = str(int(p.allocation[k]))
		busy += int(p.allocation[k])
		(_alloc_minus[k] as Button).disabled = int(p.allocation[k]) <= 0
		(_alloc_plus[k] as Button).disabled = busy >= total_v
	_villager_label.text = "Nông dân: %d (đang chờ: %d)" % [total_v, maxi(0, total_v - busy)]
	for btype in _build_buttons.keys():
		(_build_buttons[btype] as Button).disabled = not p.can_afford(Stats.BUILDINGS[btype]["cost"])
	var castle: Castle = game.castles[0]
	_castle_queue_label.text = "chờ: %d" % castle.queue_count()
	for utype in _train_castle_buttons.keys():
		var btn := _train_castle_buttons[utype] as Button
		btn.disabled = not _can_train(castle, utype)
	var barracks: Building = game.active_barracks(0)
	_barracks_queue_label.text = "chưa có" if barracks == null else "chờ: %d" % barracks.queue_count()
	for utype in _train_barracks_buttons.keys():
		var btn2 := _train_barracks_buttons[utype] as Button
		btn2.disabled = barracks == null or not _can_train(barracks, utype)

func _can_train(producer: Structure, unit_type: String) -> bool:
	var p := ctrl.player
	if not p.can_afford(Stats.TRAINING[unit_type]["cost"]):
		return false
	# Cả hai giới hạn: dân số chung + giới hạn quân (theo ô pop_cost).
	if game.cap_block_reason(0, unit_type) != "":
		return false
	return producer != null and producer.can_produce()

func show_end(won: bool) -> void:
	_end_panel.visible = true
	var l := Label.new()
	l.text = "THẮNG RỒI!" if won else "THUA RỒI!"
	l.position = Vector2(0, 28)
	l.size = Vector2(400, 50)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 38)
	l.process_mode = Node.PROCESS_MODE_ALWAYS
	_end_panel.add_child(l)
	var b := Button.new()
	b.text = "Chơi lại"
	b.position = Vector2(140, 100)
	b.size = Vector2(120, 44)
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	b.pressed.connect(func() -> void:
		get_tree().paused = false
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
	)
	_end_panel.add_child(b)
