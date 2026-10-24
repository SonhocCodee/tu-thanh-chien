class_name Hud
extends CanvasLayer

## HUD: chỉ HIỂN THỊ trạng thái và gọi lệnh qua PlayerController của người chơi.
## Không chứa logic game.

var game: Node = null
var ctrl: PlayerController = null

var _res_label: Label
var _pop_label: Label
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
	_pop_label = _mk_label(top, Vector2(360, 8), 18)
	_clock_label = _mk_label(top, Vector2(560, 8), 18)
	_stance_label = _mk_label(top, Vector2(680, 8), 18)
	_msg_label = _mk_label(top, Vector2(12, 40), 16)
	_msg_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_msg_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_msg_label.add_theme_constant_override("shadow_offset_x", 1)
	_msg_label.add_theme_constant_override("shadow_offset_y", 1)

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

	# --- Panel dưới ---
	var bottom := Panel.new()
	bottom.position = Vector2(0, 610)
	bottom.size = Vector2(1280, 110)
	add_child(bottom)
	_mk_title(bottom, Vector2(12, 4), "Phân bổ nông dân")
	_villager_label = _mk_label(bottom, Vector2(12, 84), 13)
	var res_keys := ["wood", "stone", "gold"]
	for i in 3:
		var x := 12 + i * 96
		var key: String = res_keys[i]
		var name_lbl := _mk_label(bottom, Vector2(x, 26), 14)
		name_lbl.text = Stats.RES_LABELS[key]
		var minus := _mk_button(bottom, Vector2(x, 48), Vector2(26, 26), "-")
		var count := _mk_label(bottom, Vector2(x + 30, 50), 16)
		var plus := _mk_button(bottom, Vector2(x + 58, 48), Vector2(26, 26), "+")
		_alloc_labels[key] = count
		_alloc_minus[key] = minus
		_alloc_plus[key] = plus
		minus.pressed.connect(_on_alloc.bind(key, -1))
		plus.pressed.connect(_on_alloc.bind(key, 1))

	_mk_title(bottom, Vector2(312, 4), "Xây dựng (bấm rồi bấm vào vùng quanh thành)")
	for i in Stats.BUILDINGS.keys().size():
		var btype: String = Stats.BUILDINGS.keys()[i]
		var def: Dictionary = Stats.BUILDINGS[btype]
		var btn := _mk_button(bottom, Vector2(312 + i * 108, 26), Vector2(102, 56), "%s\n%s" % [def["label"], Stats.cost_text(def["cost"])])
		btn.pressed.connect(_on_build.bind(btype))
		_build_buttons[btype] = btn

	_mk_title(bottom, Vector2(648, 4), "Huấn luyện")
	var row1 := _mk_label(bottom, Vector2(648, 26), 13)
	row1.text = "Thành chính:"
	_train_castle_buttons["pawn"] = _mk_button(bottom, Vector2(730, 22), Vector2(86, 24), "Nông dân")
	_train_castle_buttons["warrior"] = _mk_button(bottom, Vector2(820, 22), Vector2(86, 24), "Kiếm sĩ")
	_castle_queue_label = _mk_label(bottom, Vector2(912, 26), 12)
	var row2 := _mk_label(bottom, Vector2(648, 58), 13)
	row2.text = "Doanh trại:"
	_train_barracks_buttons["warrior"] = _mk_button(bottom, Vector2(730, 54), Vector2(86, 24), "Kiếm sĩ")
	_train_barracks_buttons["archer"] = _mk_button(bottom, Vector2(820, 54), Vector2(86, 24), "Cung thủ")
	_barracks_queue_label = _mk_label(bottom, Vector2(912, 58), 12)
	(_train_castle_buttons["pawn"] as Button).pressed.connect(func() -> void: ctrl.queue_training(game.castles[0], "pawn"))
	(_train_castle_buttons["warrior"] as Button).pressed.connect(func() -> void: ctrl.queue_training(game.castles[0], "warrior"))
	(_train_barracks_buttons["warrior"] as Button).pressed.connect(func() -> void: ctrl.queue_training(game.active_barracks(0), "warrior"))
	(_train_barracks_buttons["archer"] as Button).pressed.connect(func() -> void: ctrl.queue_training(game.active_barracks(0), "archer"))

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

func _on_alloc(res_key: String, delta_sign: int) -> void:
	var p := ctrl.player
	var a := {"wood": int(p.allocation["wood"]), "stone": int(p.allocation["stone"]), "gold": int(p.allocation["gold"])}
	a[res_key] = maxi(0, int(a[res_key]) + delta_sign)
	ctrl.set_villager_allocation(a["wood"], a["stone"], a["gold"])

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
	_res_label.text = "Gỗ: %d    Đá: %d    Vàng: %d" % [int(p.resources["wood"]), int(p.resources["stone"]), int(p.resources["gold"])]
	_pop_label.text = "Dân số: %d/%d" % [game.pop_used(0), game.pop_cap(0)]
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
	_castle_queue_label.text = "hàng chờ: %d" % castle.queue_count()
	for utype in _train_castle_buttons.keys():
		var btn := _train_castle_buttons[utype] as Button
		btn.disabled = not _can_train(castle, utype)
		btn.text = "%s (%s)" % [Stats.UNITS[utype]["label"], Stats.cost_text(Stats.TRAINING[utype]["cost"])]
	var barracks: Building = game.active_barracks(0)
	_barracks_queue_label.text = "chưa có doanh trại" if barracks == null else "hàng chờ: %d" % barracks.queue_count()
	for utype in _train_barracks_buttons.keys():
		var btn2 := _train_barracks_buttons[utype] as Button
		btn2.disabled = barracks == null or not _can_train(barracks, utype)
		btn2.text = "%s (%s)" % [Stats.UNITS[utype]["label"], Stats.cost_text(Stats.TRAINING[utype]["cost"])]

func _can_train(producer: Structure, unit_type: String) -> bool:
	var p := ctrl.player
	if not p.can_afford(Stats.TRAINING[unit_type]["cost"]):
		return false
	if game.pop_used(0) + 1 > game.pop_cap(0):
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
