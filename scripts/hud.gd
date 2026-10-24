class_name Hud
extends CanvasLayer

## HUD — M2 GIAI ĐOẠN 3: làm lại toàn bộ lớp trình bày theo bản mẫu C đã chốt:
##   * Thanh tài nguyên dạng VIÊN THUỐC nổi giữa-trên (icon pack + số).
##   * Dải TAB MỎNG cạnh trái (Xây / Luyện / Dân) — bấm để mở panel thẻ nổi
##     giữa-dưới; panel THU GỌN/MỞ RỘNG được (mặc định GỌN: chỉ còn dải icon),
##     phím Tab thu/mở, phím 1/2/3 mở tab tương ứng.
##   * Thẻ xây/luyện: ảnh sprite thật + giá + chỉ số + mô tả (tooltip).
##   * Minimap TRÒN góc phải-dưới (mặt nạ tròn, vẫn bấm để lia camera).
##   * Chrome lấy từ pack Tiny Swords: nút Update 010 (1 bộ duy nhất),
##     ribbon/banner cho tiêu đề, Bars cho tiến trình luyện quân, nền panel
##     Carved 9Slides; con trỏ pack Free Pack (Cursor_01/02/03) theo ngữ cảnh.
## HUD chỉ HIỂN THỊ trạng thái và gọi lệnh qua PlayerController — không chứa
## logic game. Mọi danh sách (tài nguyên, công trình, nơi sản xuất, phân bổ)
## đều đọc từ Stats / PlayerState tại runtime (data-driven) để khi gộp thêm
## tài nguyên/công trình mới (vd Thịt, Nhà Kho ở giai đoạn 2) không phải sửa
## lại cấu trúc HUD.

var game: Node = null
var ctrl: PlayerController = null

# --- Định nghĩa trình bày (chỉ là dữ liệu hiển thị, chỉ số thật đọc từ Stats) ---
const RES_ICONS := {
	"wood": "res://assets/ui/res/icon_wood.png",
	"gold": "res://assets/ui/res/icon_gold.png",
	"meat": "res://assets/ui/res/icon_meat.png",
	"stone": "res://assets/deco/rock1.png",
}
const BUILD_ART := {
	"house": "res://assets/buildings/house_%s.png",
	"barracks": "res://assets/buildings/barracks_%s.png",
	"tower": "res://assets/buildings/tower_%s.png",
	"storehouse": "res://assets/buildings/storehouse_%s.png",
}
const BUILD_DESC := {
	"house": "Tăng giới hạn dân số.",
	"barracks": "Nơi luyện kiếm sĩ và cung thủ, tốc độ nhanh hơn thành chính.",
	"tower": "Tháp tự bắn tên vào địch trong tầm.",
	"storehouse": "Điểm giao tài nguyên — đặt gần bãi farm để dân khỏi đi xa.",
}
const UNIT_ART := {
	"pawn": "res://assets/units/%s/pawn_idle.png",
	"warrior": "res://assets/units/%s/warrior_idle.png",
	"archer": "res://assets/units/%s/archer_idle.png",
}
const UNIT_DESC := {
	"pawn": "Thu thập tài nguyên, xây dựng.",
	"warrior": "Quân cận chiến, máu cao.",
	"archer": "Quân tầm xa, máu thấp.",
}
const PRODUCER_LABELS := {"castle": "Thành chính", "barracks": "Doanh trại"}
const TAB_TITLES := ["XÂY DỰNG", "HUẤN LUYỆN", "DÂN & PHÂN BỔ"]
const TAB_HINTS := [
	"Bấm thẻ rồi bấm vào vùng sáng quanh thành để đặt.",
	"Bấm thẻ để xếp hàng luyện quân. Hàng chờ + tiến trình ở trên mỗi nhóm thẻ.",
	"Nút +/- chia nông dân đi farm. Lệnh click phải ưu tiên hơn phân bổ.",
]
const UNIT_FRAME := 192.0 # cạnh 1 frame trong sprite sheet quân (khớp unit.gd/villager.gd)
# Vùng hình nhân vật trong frame đầu (đo từ alpha của sheet blue — mọi màu
# dùng chung layout): cắt sát để ảnh thẻ/rail không bị chìm trong khoảng trống.
const UNIT_FRAME_REGIONS := {
	"pawn": Rect2(61, 42, 68, 99),
	"warrior": Rect2(54, 26, 95, 117),
	"archer": Rect2(50, 26, 86, 116),
}
const CARD_SIZE := Vector2(122, 100)

const COL_TEXT_DARK := Color(0.16, 0.10, 0.05)
const COL_TEXT_DARK2 := Color(0.35, 0.26, 0.16)
const COL_CARD_TITLE := Color(0.99, 0.96, 0.88)
const COL_CARD_COST := Color(1.0, 0.86, 0.45)
const COL_CARD_STAT := Color(0.88, 0.92, 0.97)

var _pill: PanelContainer
var _pill_row: HBoxContainer
var _res_chips: HBoxContainer
var _res_value_labels: Dictionary = {}
var _res_keys_shown: Array = []
var _pop_label: Label
var _clock_label: Label
var _stance_label: Label
var _msg_label: Label
var _msg_timer: float = 0.0

var _rail: VBoxContainer
var _tab_buttons: Array = []
var _collapse_glyph: Label
var _panel: PanelContainer
var _panel_open: bool = false
var _active_tab: int = 0
var _tab_title: Label
var _tab_hint: Label
var _tab_box: HBoxContainer

var _build_buttons: Dictionary = {}
var _train_cards: Dictionary = {} # "producer:unit" -> Button
var _prod_ui: Dictionary = {} # producer -> {queue_label, fill}
var _alloc_labels: Dictionary = {}
var _alloc_minus: Dictionary = {}
var _alloc_plus: Dictionary = {}
var _villager_label: Label = null
var _hold_btn: Button = null
var _attack_btn: Button = null

var _mm_frame: Control = null
var _sel_label: Label = null
var _help_panel: PanelContainer = null
var _end_panel: PanelContainer = null
var _end_title: Label = null

func setup(p_game: Node, p_ctrl: PlayerController) -> void:
	game = p_game
	ctrl = p_ctrl

# =====================================================================
# KHỞI TẠO
# =====================================================================

func _ready() -> void:
	_setup_cursors()
	_build_pill()
	_build_rail()
	_build_panel()
	_build_minimap()
	_build_help()
	_build_end()

func _faction() -> String:
	if ctrl != null and ctrl.player != null and str(ctrl.player.color_key) != "":
		return str(ctrl.player.color_key)
	return "blue"

func _tex(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _unit_frame_tex(sheet_path: String, utype: String = "") -> Texture2D:
	var t := _tex(sheet_path)
	if t == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = t
	at.region = UNIT_FRAME_REGIONS.get(utype, Rect2(0, 0, UNIT_FRAME, UNIT_FRAME))
	return at

# --- Con trỏ pack (Free Pack Cursors): 01 mặc định, 02 tay chỉ khi hover
# phần tử bấm được, 03 cấm khi nút bị khoá (không đủ tài nguyên/dân số). ---
func _setup_cursors() -> void:
	var c1 := _tex("res://assets/ui/cursors/cursor_01.png")
	var c2 := _tex("res://assets/ui/cursors/cursor_02.png")
	var c3 := _tex("res://assets/ui/cursors/cursor_03.png")
	if c1 != null:
		Input.set_custom_mouse_cursor(c1, Input.CURSOR_ARROW, Vector2(23, 18))
	if c2 != null:
		Input.set_custom_mouse_cursor(c2, Input.CURSOR_POINTING_HAND, Vector2(30, 17))
	if c3 != null:
		Input.set_custom_mouse_cursor(c3, Input.CURSOR_FORBIDDEN, Vector2(32, 31))

func _carved_style(margin: int, pad: Vector4) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _tex("res://assets/ui/carved_panel.png")
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.z
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.w
	return sb

func _btn_style(tex_name: String, mx: int, my: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _tex("res://assets/ui/buttons/" + tex_name)
	sb.texture_margin_left = mx
	sb.texture_margin_right = mx
	sb.texture_margin_top = my
	sb.texture_margin_bottom = my
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

func _style_card_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _btn_style("button_blue_9.png", 40, 40))
	b.add_theme_stylebox_override("hover", _btn_style("button_hover_9.png", 40, 40))
	b.add_theme_stylebox_override("pressed", _btn_style("button_blue_9_pressed.png", 40, 40))
	b.add_theme_stylebox_override("disabled", _btn_style("button_disable_9.png", 40, 40))
	b.add_theme_color_override("font_color", COL_CARD_TITLE)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _style_wide_button(b: Button, font_size: int = 14) -> void:
	b.add_theme_stylebox_override("normal", _btn_style("button_blue_9.png", 40, 14))
	b.add_theme_stylebox_override("hover", _btn_style("button_hover_9.png", 40, 14))
	b.add_theme_stylebox_override("pressed", _btn_style("button_blue_9_pressed.png", 40, 14))
	b.add_theme_stylebox_override("disabled", _btn_style("button_disable_9.png", 40, 14))
	b.add_theme_color_override("font_color", COL_CARD_TITLE)
	b.add_theme_color_override("font_hover_color", COL_CARD_TITLE)
	b.add_theme_color_override("font_disabled_color", Color(0.75, 0.72, 0.66))
	b.add_theme_font_size_override("font_size", font_size)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

# Nút vuông pack (Update 010 Buttons 64x64) có icon ở giữa.
func _mk_tex_button(sz: int, icon: Texture2D, tip: String) -> TextureButton:
	var b := TextureButton.new()
	b.custom_minimum_size = Vector2(sz, sz)
	b.texture_normal = _tex("res://assets/ui/buttons/button_blue.png")
	b.texture_hover = _tex("res://assets/ui/buttons/button_hover.png")
	b.texture_pressed = _tex("res://assets/ui/buttons/button_blue_pressed.png")
	b.texture_disabled = _tex("res://assets/ui/buttons/button_disable.png")
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if tip != "":
		b.tooltip_text = tip
	if icon != null:
		# Icon nằm trong 1 "slot" Control kích thước cố định, TextureRect
		# full-rect theo anchor — tránh việc TextureRect tự về kích thước
		# gốc của texture (hành vi mặc định khi expand != IGNORE_SIZE).
		var slot := Control.new()
		slot.position = Vector2(sz * 0.17, sz * 0.17)
		slot.size = Vector2(sz * 0.66, sz * 0.66)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(slot)
		var tr := TextureRect.new()
		tr.texture = icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tr)
	return b

func _mk_label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)

# =====================================================================
# THANH TÀI NGUYÊN — viên thuốc nổi giữa-trên (data-driven theo player)
# =====================================================================

func _build_pill() -> void:
	_pill = PanelContainer.new()
	_pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pill.offset_top = 8
	_pill.offset_bottom = 8
	_pill.add_theme_stylebox_override("panel", _carved_style(18, Vector4(16, 4, 16, 5)))
	add_child(_pill)
	_pill_row = HBoxContainer.new()
	_pill_row.add_theme_constant_override("separation", 12)
	_pill.add_child(_pill_row)
	_res_chips = HBoxContainer.new()
	_res_chips.add_theme_constant_override("separation", 12)
	_pill_row.add_child(_res_chips)
	_pill_row.add_child(VSeparator.new())
	# Dân số: icon nông dân + "đang dùng/giới hạn"
	var pop_box := HBoxContainer.new()
	pop_box.add_theme_constant_override("separation", 4)
	_pill_row.add_child(pop_box)
	var pop_icon := TextureRect.new()
	pop_icon.texture = _unit_frame_tex(UNIT_ART["pawn"] % _faction(), "pawn")
	pop_icon.custom_minimum_size = Vector2(26, 26)
	pop_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pop_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pop_icon.tooltip_text = "Dân số"
	pop_box.add_child(pop_icon)
	_pop_label = _mk_label(pop_box, "0/0", 17, COL_TEXT_DARK)
	_pop_label.tooltip_text = "Dân số"
	_pill_row.add_child(VSeparator.new())
	_clock_label = _mk_label(_pill_row, "00:00", 17, COL_TEXT_DARK)
	_clock_label.tooltip_text = "Thời gian trận"
	_stance_label = _mk_label(_pill_row, "", 14, COL_TEXT_DARK)
	_stance_label.tooltip_text = "Thái độ quân"

	# Dòng thông báo: nổi giữa, ngay dưới viên thuốc.
	_msg_label = Label.new()
	_msg_label.position = Vector2(0, 54)
	_msg_label.size = Vector2(1280, 24)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.add_theme_font_size_override("font_size", 16)
	_msg_label.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
	_shadow(_msg_label)
	_msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_msg_label)

func _rebuild_res_chips(keys: Array) -> void:
	for c in _res_chips.get_children():
		c.queue_free()
	_res_value_labels.clear()
	_res_keys_shown = keys.duplicate()
	for k in keys:
		var key := str(k)
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)
		_res_chips.add_child(chip)
		var icon_path: String = RES_ICONS.get(key, "")
		var icon_tex := _tex(icon_path)
		if icon_tex != null:
			var tr := TextureRect.new()
			tr.texture = icon_tex
			tr.custom_minimum_size = Vector2(26, 26)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.tooltip_text = str(Stats.RES_LABELS.get(key, key.capitalize()))
			chip.add_child(tr)
		var val := _mk_label(chip, "0", 18, COL_TEXT_DARK)
		val.tooltip_text = str(Stats.RES_LABELS.get(key, key.capitalize()))
		_res_value_labels[key] = val

# =====================================================================
# DẢI TAB MỎNG CẠNH TRÁI + PANEL THẺ NỔI GIỮA-DƯỚI
# =====================================================================

func _build_rail() -> void:
	_rail = VBoxContainer.new()
	_rail.position = Vector2(8, 222)
	_rail.add_theme_constant_override("separation", 6)
	add_child(_rail)
	var group := ButtonGroup.new()
	group.allow_unpress = true
	var fac := _faction()
	var tab_icons: Array = [
		_tex(BUILD_ART["house"] % fac),
		_tex("res://assets/ui/icons/icon_swords.png"),
		_unit_frame_tex(UNIT_ART["pawn"] % fac, "pawn"),
	]
	var tab_tips := ["Xây dựng (phím 1)", "Huấn luyện & điều quân (phím 2)", "Dân & phân bổ (phím 3)"]
	for i in 3:
		var b := _mk_tex_button(48, tab_icons[i], tab_tips[i])
		b.toggle_mode = true
		b.button_group = group
		b.toggled.connect(_on_tab_toggled.bind(i))
		_rail.add_child(b)
		_tab_buttons.append(b)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(48, 12)
	_rail.add_child(spacer)
	var help_btn := _mk_tex_button(48, _tex("res://assets/ui/icons/icon_info.png"), "Trợ giúp")
	help_btn.pressed.connect(show_help)
	_rail.add_child(help_btn)
	var collapse_btn := _mk_tex_button(48, null, "Thu gọn / mở rộng panel (phím Tab)")
	_collapse_glyph = Label.new()
	_collapse_glyph.text = "▲"
	_collapse_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_collapse_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collapse_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_collapse_glyph.add_theme_font_size_override("font_size", 18)
	_collapse_glyph.add_theme_color_override("font_color", COL_CARD_TITLE)
	_shadow(_collapse_glyph)
	_collapse_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	collapse_btn.add_child(_collapse_glyph)
	collapse_btn.pressed.connect(toggle_panel)
	_rail.add_child(collapse_btn)

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_top = -8
	_panel.offset_bottom = -8
	_panel.add_theme_stylebox_override("panel", _carved_style(24, Vector4(18, 8, 18, 10)))
	_panel.visible = false
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vb.add_child(header)
	_tab_title = _mk_label(header, "", 15, COL_TEXT_DARK)
	_tab_hint = _mk_label(header, "", 12, COL_TEXT_DARK2)
	_tab_box = HBoxContainer.new()
	_tab_box.add_theme_constant_override("separation", 8)
	vb.add_child(_tab_box)

func _on_tab_toggled(on: bool, idx: int) -> void:
	if on:
		open_tab(idx)
	elif _panel_open and _active_tab == idx:
		_close_panel()

func open_tab(idx: int) -> void:
	_active_tab = idx
	_panel_open = true
	_panel.visible = true
	_sync_rail()
	_rebuild_tab()

func _close_panel() -> void:
	_panel_open = false
	_panel.visible = false
	_sync_rail()

func toggle_panel() -> void:
	if _panel_open:
		_close_panel()
	else:
		open_tab(_active_tab)

func _sync_rail() -> void:
	for i in _tab_buttons.size():
		(_tab_buttons[i] as BaseButton).set_pressed_no_signal(_panel_open and i == _active_tab)
	_collapse_glyph.text = "▼" if _panel_open else "▲"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				toggle_panel()
				get_viewport().set_input_as_handled()
			KEY_1:
				open_tab(0)
				get_viewport().set_input_as_handled()
			KEY_2:
				open_tab(1)
				get_viewport().set_input_as_handled()
			KEY_3:
				open_tab(2)
				get_viewport().set_input_as_handled()

# main.gd hỏi HUD: điểm màn hình này có nằm trên UI không (thay cho dải
# y cứng của panel cũ) — click trúng UI thì không tính là click map.
func is_point_over_ui(pos: Vector2) -> bool:
	for c in [_pill, _rail]:
		if (c as Control).get_global_rect().has_point(pos):
			return true
	if _mm_frame != null and _mm_frame.get_global_rect().has_point(pos):
		return true
	if _panel.visible and _panel.get_global_rect().has_point(pos):
		return true
	if _help_panel != null and _help_panel.visible and _help_panel.get_global_rect().has_point(pos):
		return true
	if _end_panel != null and _end_panel.visible and _end_panel.get_global_rect().has_point(pos):
		return true
	return false

# =====================================================================
# THẺ (card) — nút pack 9Slides + ảnh sprite thật + giá + chỉ số
# =====================================================================

func _mk_card(art: Texture2D, title: String, cost_line: String, stat_line: String, tip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.size = CARD_SIZE
	_style_card_button(b)
	b.tooltip_text = tip
	if art != null:
		var slot := Control.new()
		slot.position = Vector2(16, 1)
		slot.size = Vector2(90, 48)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(slot)
		var tr := TextureRect.new()
		tr.texture = art
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tr)
	var t := _mk_label(b, title, 13, COL_CARD_TITLE)
	t.position = Vector2(1, 49)
	t.size = Vector2(CARD_SIZE.x - 2, 15)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.clip_text = true
	_shadow(t)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := _mk_label(b, cost_line, 12, COL_CARD_COST)
	c.position = Vector2(1, 65)
	c.size = Vector2(CARD_SIZE.x - 2, 14)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.clip_text = true
	_shadow(c)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := _mk_label(b, stat_line, 11, COL_CARD_STAT)
	s.position = Vector2(1, 80)
	s.size = Vector2(CARD_SIZE.x - 2, 14)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.clip_text = true
	_shadow(s)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func _rebuild_tab() -> void:
	for c in _tab_box.get_children():
		c.queue_free()
	_build_buttons.clear()
	_train_cards.clear()
	_prod_ui.clear()
	_alloc_labels.clear()
	_alloc_minus.clear()
	_alloc_plus.clear()
	_villager_label = null
	_hold_btn = null
	_attack_btn = null
	_tab_title.text = TAB_TITLES[_active_tab]
	_tab_hint.text = TAB_HINTS[_active_tab]
	match _active_tab:
		0:
			_build_tab_build()
		1:
			_build_tab_train()
		2:
			_build_tab_people()

# --- Tab XÂY: thẻ sinh từ Stats.BUILDINGS (thêm nhà mới = thêm thẻ tự động) ---
func _build_tab_build() -> void:
	var fac := _faction()
	for btype in Stats.BUILDINGS.keys():
		var def: Dictionary = Stats.BUILDINGS[btype]
		var art_path: String = BUILD_ART.get(btype, BUILD_ART["house"]) % fac
		var bonus := ""
		if btype == "house":
			bonus = " • +%d dân" % int(Stats.ECONOMY["pop_per_house"])
		var stat_line := "%d máu%s" % [int(def["hp"]), bonus]
		var cost_line := "%s • %ds" % [Stats.cost_text(def["cost"]), int(def["build_time"])]
		var tip := "%s — %s\nGiá: %s • Máu: %d • Thời gian xây: %ds" % [
			str(def["label"]), str(BUILD_DESC.get(btype, "")), Stats.cost_text(def["cost"]), int(def["hp"]), int(def["build_time"])]
		var card := _mk_card(_tex(art_path), str(def["label"]), cost_line, stat_line, tip)
		card.pressed.connect(_on_build.bind(btype))
		_tab_box.add_child(card)
		_build_buttons[btype] = card

# --- Tab LUYỆN: nhóm theo nơi sản xuất (Stats.PRODUCERS) + điều quân ---
func _build_tab_train() -> void:
	var fac := _faction()
	var first := true
	for producer in Stats.PRODUCERS.keys():
		if not first:
			_tab_box.add_child(VSeparator.new())
		first = false
		var pdef: Dictionary = Stats.PRODUCERS[producer]
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 3)
		_tab_box.add_child(group)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		group.add_child(head)
		_mk_label(head, str(PRODUCER_LABELS.get(producer, producer.capitalize())), 13, COL_TEXT_DARK)
		var q_lbl := _mk_label(head, "", 12, COL_TEXT_DARK2)
		# Thanh tiến trình luyện quân (Bars của pack) — dữ liệu thật từ hàng chờ.
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(CARD_SIZE.x * 2 + 8, 14)
		bar.size = Vector2(CARD_SIZE.x * 2 + 8, 14)
		group.add_child(bar)
		var base := TextureRect.new()
		# Ảnh Bars của pack phần lớn là trong suốt — cắt đúng dải có hình
		# (đo từ alpha) để kéo giãn không bị loãng thành sợi chỉ.
		var base_at := AtlasTexture.new()
		base_at.atlas = _tex("res://assets/ui/bars/bar_base.png")
		base_at.region = Rect2(45, 20, 230, 23)
		base.texture = base_at
		base.set_anchors_preset(Control.PRESET_FULL_RECT)
		base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		base.stretch_mode = TextureRect.STRETCH_SCALE
		base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(base)
		# Fill chạy trong slot có clip: chỉnh bề ngang slot = tiến trình,
		# texture fill full-rect bên trong bị cắt theo — không bị trả về
		# kích thước gốc của texture.
		var fill := Control.new()
		fill.position = Vector2(2, 2)
		fill.size = Vector2(0, 10)
		fill.clip_contents = true
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(fill)
		var fill_tex := TextureRect.new()
		var fill_at := AtlasTexture.new()
		fill_at.atlas = _tex("res://assets/ui/bars/bar_fill.png")
		fill_at.region = Rect2(0, 29, 64, 5)
		fill_tex.texture = fill_at
		fill_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fill_tex.stretch_mode = TextureRect.STRETCH_SCALE
		fill_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		fill_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.add_child(fill_tex)
		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation", 8)
		group.add_child(cards)
		for utype in pdef["units"]:
			var u: Dictionary = Stats.UNITS[utype]
			var tr: Dictionary = Stats.TRAINING[utype]
			var tsec := int(round(float(tr["time"]) / float(pdef["speed"])))
			var dmg := ""
			if u.has("damage"):
				dmg = " • %d đánh" % int(u["damage"])
			var stat_line := "%d máu%s" % [int(u["hp"]), dmg]
			var cost_line := "%s • %ds" % [Stats.cost_text(tr["cost"]), tsec]
			var tip := "%s — %s\nGiá: %s • Máu: %d%s • Huấn luyện: %ds tại %s" % [
				str(u["label"]), str(UNIT_DESC.get(utype, "")), Stats.cost_text(tr["cost"]), int(u["hp"]),
				(" • Sát thương: %d" % int(u["damage"])) if u.has("damage") else "",
				tsec, str(PRODUCER_LABELS.get(producer, producer))]
			var card := _mk_card(_unit_frame_tex(UNIT_ART.get(utype, UNIT_ART["pawn"]) % fac, utype), str(u["label"]), cost_line, stat_line, tip)
			card.pressed.connect(_on_train_pressed.bind(producer, utype))
			cards.add_child(card)
			_train_cards[producer + ":" + utype] = card
		_prod_ui[producer] = {"queue_label": q_lbl, "fill": fill, "bar_w": bar.size.x - 4.0}
	# Nhóm điều quân: 2 thái độ (chức năng cũ, giữ nguyên hành vi).
	_tab_box.add_child(VSeparator.new())
	var stance_box := VBoxContainer.new()
	stance_box.add_theme_constant_override("separation", 3)
	_tab_box.add_child(stance_box)
	_mk_label(stance_box, "ĐIỀU QUÂN", 13, COL_TEXT_DARK)
	_hold_btn = Button.new()
	_hold_btn.custom_minimum_size = Vector2(158, 44)
	_style_wide_button(_hold_btn, 13)
	_hold_btn.text = "GIỮ NHÀ"
	_hold_btn.tooltip_text = "Quân ở nhà thủ quanh thành chính."
	_hold_btn.pressed.connect(_on_hold)
	stance_box.add_child(_hold_btn)
	_attack_btn = Button.new()
	_attack_btn.custom_minimum_size = Vector2(158, 44)
	_style_wide_button(_attack_btn, 13)
	_attack_btn.text = "TỔNG TẤN CÔNG…"
	_attack_btn.tooltip_text = "Bấm rồi chọn thành địch đã lộ diện, hoặc 1 điểm để quân đi trinh sát."
	_attack_btn.pressed.connect(func() -> void: game.start_order_mode())
	stance_box.add_child(_attack_btn)
	var hint := _mk_label(stance_box, "Tấn công…: bấm thành địch\nđã lộ diện / điểm trinh sát.", 11, COL_TEXT_DARK2)
	hint.custom_minimum_size = Vector2(158, 26)

# --- Tab DÂN: phân bổ +/- theo đúng khóa tài nguyên của player ---
func _build_tab_people() -> void:
	var p := ctrl.player
	var groups := HBoxContainer.new()
	groups.add_theme_constant_override("separation", 14)
	_tab_box.add_child(groups)
	for key in p.allocation.keys():
		var res_key := str(key)
		var g := VBoxContainer.new()
		g.add_theme_constant_override("separation", 3)
		groups.add_child(g)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		g.add_child(head)
		var icon_tex := _tex(RES_ICONS.get(res_key, ""))
		if icon_tex != null:
			var tr := TextureRect.new()
			tr.texture = icon_tex
			tr.custom_minimum_size = Vector2(22, 22)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			head.add_child(tr)
		_mk_label(head, str(Stats.RES_LABELS.get(res_key, res_key.capitalize())), 14, COL_TEXT_DARK)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		g.add_child(row)
		var minus := _mk_tex_button(34, null, "Giảm")
		var minus_lbl := Label.new()
		minus_lbl.text = "-"
		minus_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		minus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		minus_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		minus_lbl.add_theme_font_size_override("font_size", 20)
		minus_lbl.add_theme_color_override("font_color", COL_CARD_TITLE)
		_shadow(minus_lbl)
		minus_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		minus.add_child(minus_lbl)
		row.add_child(minus)
		var count := _mk_label(row, "0", 17, COL_TEXT_DARK)
		count.custom_minimum_size = Vector2(30, 34)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var plus := _mk_tex_button(34, null, "Tăng")
		var plus_lbl := Label.new()
		plus_lbl.text = "+"
		plus_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		plus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus_lbl.add_theme_font_size_override("font_size", 20)
		plus_lbl.add_theme_color_override("font_color", COL_CARD_TITLE)
		_shadow(plus_lbl)
		plus_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plus.add_child(plus_lbl)
		row.add_child(plus)
		_alloc_labels[res_key] = count
		_alloc_minus[res_key] = minus
		_alloc_plus[res_key] = plus
		minus.pressed.connect(_on_alloc.bind(res_key, -1))
		plus.pressed.connect(_on_alloc.bind(res_key, 1))
	_tab_box.add_child(VSeparator.new())
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	_tab_box.add_child(info)
	_villager_label = _mk_label(info, "", 13, COL_TEXT_DARK)
	var note := _mk_label(info, "Lệnh trực tiếp bằng click phải (vào cây/mỏ)\nluôn ưu tiên hơn phân bổ ở đây.", 11, COL_TEXT_DARK2)
	note.custom_minimum_size = Vector2(240, 30)

# =====================================================================
# MINIMAP TRÒN — phải-dưới (mặt nạ tròn bằng shader discard, vòng viền vàng)
# =====================================================================

class RoundFrame:
	extends Control

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		draw_circle(c, r, Color(0.05, 0.07, 0.04))
		draw_arc(c, r - 4.5, 0.0, TAU, 72, Color(0.0, 0.0, 0.0, 0.5), 1.5)
		draw_arc(c, r - 1.5, 0.0, TAU, 72, Color(0.88, 0.72, 0.38), 3.0)

func _build_minimap() -> void:
	_sel_label = Label.new()
	_sel_label.position = Vector2(1080, 492)
	_sel_label.size = Vector2(190, 20)
	_sel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sel_label.add_theme_font_size_override("font_size", 13)
	_sel_label.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
	_shadow(_sel_label)
	_sel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sel_label)
	var frame := RoundFrame.new()
	frame.position = Vector2(1080, 520)
	frame.size = Vector2(190, 190)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_mm_frame = frame
	var mm := Minimap.new()
	mm.game = game
	mm.round_mode = true
	mm.position = Vector2(1080, 520)
	mm.size = Vector2(190, 190)
	# Mặt nạ tròn bằng shader: bỏ mọi pixel ngoài đường tròn nội tiếp
	# (control vuông 190x190 nên UV 0..1 cho đường tròn chuẩn).
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 d = UV - vec2(0.5, 0.5);\n\tif (dot(d, d) > 0.25) {\n\t\tdiscard;\n\t}\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mm.material = mat
	add_child(mm)
	var north := Label.new()
	north.text = "N"
	north.position = Vector2(1080, 518)
	north.size = Vector2(190, 16)
	north.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	north.add_theme_font_size_override("font_size", 13)
	north.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	_shadow(north)
	north.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(north)

# =====================================================================
# PANEL TRỢ GIÚP + KẾT TRẬN (nền Carved + ribbon tiêu đề của pack)
# =====================================================================

func _ribbon_header(parent: Node, text: String, font_size: int = 19) -> Label:
	var center := CenterContainer.new()
	parent.add_child(center)
	var box := Control.new()
	box.custom_minimum_size = Vector2(330, 54)
	center.add_child(box)
	var tr := TextureRect.new()
	tr.texture = _tex("res://assets/ui/ribbon_blue.png")
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tr)
	var l := Label.new()
	l.text = text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.99, 0.97, 0.9))
	_shadow(l)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return l

func _build_help() -> void:
	_help_panel = PanelContainer.new()
	_help_panel.set_anchors_preset(Control.PRESET_CENTER)
	_help_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_help_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_help_panel.offset_left = -380
	_help_panel.offset_right = 380
	_help_panel.offset_top = -270
	_help_panel.offset_bottom = 270
	_help_panel.add_theme_stylebox_override("panel", _carved_style(24, Vector4(30, 18, 30, 18)))
	_help_panel.visible = false
	add_child(_help_panel)
	var root := Control.new()
	_help_panel.add_child(root)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 10)
	root.add_child(vb)
	_ribbon_header(vb, "HƯỚNG DẪN ĐIỀU KHIỂN")
	var body := _mk_label(vb, "", 13, COL_TEXT_DARK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.text = "\n".join([
		"KÉO CHUỘT TRÁI: kéo khung chọn quân (khung GÓC VÀNG = vùng đang chọn, vòng xanh dưới chân = quân đã chọn).",
		"CLICK TRÁI 1 đơn vị: chọn riêng nó. Bấm đất trống / quân địch: bỏ chọn.",
		"CLICK PHẢI ĐẤT TRỐNG: quân đã chọn di chuyển tới đó.",
		"CLICK PHẢI CÂY/MỎ: nông dân đã chọn đi farm đúng loại đó. CLICK PHẢI CỪU: nông dân đi săn lấy thịt.",
		"CLICK PHẢI QUÂN/CÔNG TRÌNH ĐỊCH: tấn công (chỉ mục tiêu đã lộ diện — chưa lộ thì game từ chối, cần trinh sát trước).",
		"LIA CAMERA: đưa chuột ra mép màn hình, phím WASD / mũi tên, hoặc bấm vào bản đồ nhỏ.",
		"GIAO DIỆN: dải icon bên trái mở các tab Xây / Luyện / Dân. Phím Tab thu gọn/mở rộng panel, phím 1/2/3 mở tab tương ứng.",
		"PHÂN BỔ: nút +/- ở tab Dân chia nông dân farm gỗ/đá/vàng/thịt — phân thịt là đi SĂN CỪU (lệnh click phải ưu tiên hơn phân bổ).",
		"XÂY: bấm thẻ công trình ở tab Xây rồi bấm vào vùng sáng quanh thành. NHÀ KHO: điểm giao tài nguyên, đặt được ở mọi vùng đã khám phá. LUYỆN QUÂN: thẻ ở tab Luyện.",
		"THÁI ĐỘ: GIỮ NHÀ (quân ở nhà thủ) / TỔNG TẤN CÔNG (đánh thành địch đã lộ diện) — ở tab Luyện.",
		"SƯƠNG MÙ: đen = chưa khám phá, mờ = đã qua (chỉ mờ đi, không đen lại), sáng = đang nhìn thấy.",
	])
	var center := CenterContainer.new()
	vb.add_child(center)
	var ok := Button.new()
	ok.text = "Đã hiểu"
	ok.custom_minimum_size = Vector2(160, 44)
	_style_wide_button(ok, 15)
	ok.pressed.connect(close_help)
	center.add_child(ok)
	var x := _mk_tex_button(36, _tex("res://assets/ui/icons/icon_close.png"), "Đóng")
	x.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	x.offset_left = -40
	x.offset_top = 2
	x.offset_right = -4
	x.offset_bottom = 38
	x.pressed.connect(close_help)
	root.add_child(x)

func _build_end() -> void:
	_end_panel = PanelContainer.new()
	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_end_panel.offset_left = -215
	_end_panel.offset_right = 215
	_end_panel.offset_top = -88
	_end_panel.offset_bottom = 88
	_end_panel.add_theme_stylebox_override("panel", _carved_style(24, Vector4(26, 16, 26, 16)))
	_end_panel.visible = false
	_end_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_end_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_end_panel.add_child(vb)
	_end_title = _ribbon_header(vb, "", 24)
	var center := CenterContainer.new()
	vb.add_child(center)
	var b := Button.new()
	b.text = "Chơi lại"
	b.custom_minimum_size = Vector2(170, 46)
	_style_wide_button(b, 16)
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	b.pressed.connect(func() -> void:
		get_tree().paused = false
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
	)
	center.add_child(b)

# =====================================================================
# API CÔNG KHAI (main.gd gọi — giữ nguyên như HUD cũ)
# =====================================================================

func show_message(text: String) -> void:
	_msg_label.text = text
	_msg_timer = 6.0

func show_help() -> void:
	if _help_panel != null:
		_help_panel.visible = true

func close_help() -> void:
	if _help_panel != null:
		_help_panel.visible = false

func show_end(won: bool) -> void:
	_end_title.text = "THẮNG RỒI!" if won else "THUA RỒI!"
	_end_panel.visible = true

# =====================================================================
# HÀNH ĐỘNG
# =====================================================================

func _on_build(btype: String) -> void:
	game.set_placement_mode(btype)

func _on_hold() -> void:
	ctrl.set_stance("hold")
	show_message("Quân về thế GIỮ NHÀ.")

func _producer_node(producer: String) -> Structure:
	if producer == "castle":
		return game.castles[0]
	return game.active_barracks(0)

func _on_train_pressed(producer: String, utype: String) -> void:
	var node := _producer_node(producer)
	if node != null:
		ctrl.queue_training(node, utype)

func _on_alloc(res_key: String, delta_sign: int) -> void:
	var p := ctrl.player
	# Gọi set_villager_allocation bằng callv với đúng số tham số mà
	# PlayerController hiện có (thứ tự = thứ tự khóa trong allocation):
	# bản 3 tài nguyên truyền 3 số, khi gộp giai đoạn 2 (thêm thịt) tự
	# truyền 4 số — HUD không phải sửa.
	var args: Array = []
	for k in p.allocation.keys():
		var v := int(p.allocation[k])
		if str(k) == res_key:
			v = maxi(0, v + delta_sign)
		args.append(v)
	ctrl.callv("set_villager_allocation", args)

func _can_train(producer: Structure, unit_type: String) -> bool:
	var p := ctrl.player
	if not p.can_afford(Stats.TRAINING[unit_type]["cost"]):
		return false
	if game.pop_used(0) + 1 > game.pop_cap(0):
		return false
	return producer != null and producer.can_produce()

func _set_btn_state(b: BaseButton, enabled: bool) -> void:
	b.disabled = not enabled
	b.modulate = Color(1, 1, 1, 1) if enabled else Color(0.62, 0.62, 0.62, 0.85)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_FORBIDDEN

# =====================================================================
# CẬP NHẬT MỖI FRAME
# =====================================================================

func _process(delta: float) -> void:
	if game == null or ctrl == null:
		return
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			_msg_label.text = ""
	var p := ctrl.player
	# Thanh tài nguyên: tự khớp với danh sách tài nguyên player đang có.
	var keys := p.resources.keys()
	if keys != _res_keys_shown:
		_rebuild_res_chips(keys)
	for k in _res_value_labels.keys():
		(_res_value_labels[k] as Label).text = str(int(p.resources.get(k, 0)))
	_pop_label.text = "%d/%d" % [game.pop_used(0), game.pop_cap(0)]
	var t := int(game.elapsed)
	_clock_label.text = "%02d:%02d" % [t / 60, t % 60]
	match p.stance:
		"hold":
			_stance_label.text = "GIỮ NHÀ"
			_stance_label.add_theme_color_override("font_color", Color(0.1, 0.4, 0.12))
		"attack":
			_stance_label.text = "TỔNG TẤN CÔNG"
			_stance_label.add_theme_color_override("font_color", Color(0.62, 0.12, 0.08))
		_:
			_stance_label.text = "TRINH SÁT"
			_stance_label.add_theme_color_override("font_color", Color(0.1, 0.25, 0.55))
	if _sel_label != null:
		var n_sel := ctrl.get_selection().size()
		_sel_label.text = "Đã chọn: %d" % n_sel if n_sel > 0 else ""
	if not _panel_open:
		return
	match _active_tab:
		0:
			for btype in _build_buttons.keys():
				_set_btn_state(_build_buttons[btype], p.can_afford(Stats.BUILDINGS[btype]["cost"]))
		1:
			_update_train_tab(p)
		2:
			_update_people_tab(p)

func _update_train_tab(p: PlayerState) -> void:
	for producer in _prod_ui.keys():
		var ui: Dictionary = _prod_ui[producer]
		var node := _producer_node(producer)
		var q_lbl := ui["queue_label"] as Label
		if node == null:
			q_lbl.text = "chưa có"
			(ui["fill"] as Control).size.x = 0.0
		else:
			q_lbl.text = "chờ: %d" % node.queue_count()
			var prog := 0.0
			if not node.train_queue.is_empty():
				var item: Dictionary = node.train_queue[0]
				if float(item["total"]) > 0.0:
					prog = clampf(1.0 - float(item["time_left"]) / float(item["total"]), 0.0, 1.0)
			(ui["fill"] as Control).size.x = float(ui["bar_w"]) * prog
		for utype in Stats.PRODUCERS[producer]["units"]:
			var card := _train_cards.get(producer + ":" + utype) as Button
			if card != null:
				_set_btn_state(card, node != null and _can_train(node, utype))
	if _hold_btn != null:
		_hold_btn.text = ("▶ " if p.stance == "hold" else "") + "GIỮ NHÀ"
	if _attack_btn != null:
		_attack_btn.text = ("▶ " if p.stance == "attack" else "") + "TỔNG TẤN CÔNG…"

func _update_people_tab(p: PlayerState) -> void:
	var total_v: int = game.villager_count(0)
	var busy := 0
	for k in p.allocation.keys():
		busy += int(p.allocation[k])
	for k in _alloc_labels.keys():
		(_alloc_labels[k] as Label).text = str(int(p.allocation.get(k, 0)))
		_set_btn_state(_alloc_minus[k], int(p.allocation.get(k, 0)) > 0)
		_set_btn_state(_alloc_plus[k], busy < total_v)
	if _villager_label != null:
		_villager_label.text = "Nông dân: %d (đang chờ: %d)" % [total_v, maxi(0, total_v - busy)]
