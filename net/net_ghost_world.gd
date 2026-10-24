class_name NetGhostWorld
extends Node2D

## NetGhostWorld — "bản gương" của client: giữ mọi NetGhost, áp snapshot,
## và vẽ khung kéo chọn quân. Đây là toàn bộ "thế giới" mà người chơi mạng
## nhìn thấy — dữ liệu trong này 100% đến từ snapshot đã lọc sương mù của
## server (client không có đường nào khác để biết trạng thái trận).

var my_slot: int = -1
var ghosts: Dictionary = {} # net_id -> NetGhost
var selected_ids: Array = []

# Khung kéo chọn (vẽ ở đây vì _sel_overlay của Main neo theo input chơi đơn).
var drag_active: bool = false
var drag_rect: Rect2 = Rect2()

# Vòng chân đế xem trước khi đang chọn công trình để đặt (client không tự
# tính hợp lệ — server là nơi quyết; vòng chỉ cho biết vị trí + kích cỡ).
var placing_active: bool = false
var placing_pos: Vector2 = Vector2.ZERO
var placing_radius: float = 40.0

func setup(p_slot: int) -> void:
	my_slot = p_slot

func reset() -> void:
	for id in ghosts.keys():
		(ghosts[id] as NetGhost).queue_free()
	ghosts.clear()
	selected_ids.clear()

func apply_snapshot(msg: Dictionary, now: float) -> void:
	for rid in msg.get("removals", []):
		var id := int(rid)
		if ghosts.has(id):
			(ghosts[id] as NetGhost).queue_free()
			ghosts.erase(id)
			selected_ids.erase(id)
	for rec in msg.get("upserts", []):
		var id := int(rec[0])
		var owner := int(rec[1])
		var color_key := "blue"
		if owner >= 0 and owner < Stats.PLAYERS.size():
			color_key = String(Stats.PLAYERS[owner]["color_key"])
		if ghosts.has(id):
			(ghosts[id] as NetGhost).apply(rec, now)
		else:
			var g := NetGhost.new()
			g.setup_from(rec, color_key, now)
			add_child(g)
			ghosts[id] = g
	_refresh_selection_visual()

# ---------------- Truy vấn phục vụ input / sương mù client ----------------

func ghost(id: int) -> NetGhost:
	return ghosts.get(id, null)

func own_ghosts() -> Array:
	var out: Array = []
	for g in ghosts.values():
		if (g as NetGhost).owner_pid == my_slot:
			out.append(g)
	return out

func own_military_ids() -> Array:
	var out: Array = []
	for g in ghosts.values():
		var gh := g as NetGhost
		if gh.owner_pid == my_slot and gh.kind == "unit":
			out.append(gh.net_id)
	return out

func own_villager_ids() -> Array:
	var out: Array = []
	for g in ghosts.values():
		var gh := g as NetGhost
		if gh.owner_pid == my_slot and gh.kind == "villager":
			out.append(gh.net_id)
	return out

func own_units_at_rect(rect: Rect2) -> Array:
	var out: Array = []
	for g in ghosts.values():
		var gh := g as NetGhost
		if gh.owner_pid == my_slot and (gh.kind == "unit" or gh.kind == "villager") and rect.has_point(gh.render):
			out.append(gh.net_id)
	return out

func nearest_ghost(pos: Vector2, radius: float, filter: Callable) -> NetGhost:
	var best: NetGhost = null
	var best_d := radius
	for g in ghosts.values():
		var gh := g as NetGhost
		if not filter.call(gh):
			continue
		var d := gh.render.distance_to(pos)
		if d < best_d:
			best_d = d
			best = gh
	return best

func set_selection(ids: Array) -> void:
	selected_ids = ids.duplicate()
	_refresh_selection_visual()

func _refresh_selection_visual() -> void:
	for g in ghosts.values():
		var gh := g as NetGhost
		var sel := selected_ids.has(gh.net_id)
		if gh.selected != sel:
			gh.selected = sel
			gh.queue_redraw()

func _draw() -> void:
	if drag_active:
		draw_rect(drag_rect, Color(1, 1, 1, 0.08))
		draw_rect(drag_rect, Color(1.0, 0.85, 0.3, 0.8), false, 1.5)
	if placing_active:
		draw_arc(placing_pos, placing_radius, 0.0, TAU, 40, Color(1.0, 0.9, 0.4, 0.9), 2.0)
		draw_circle(placing_pos, 3.0, Color(1.0, 0.9, 0.4, 0.9))
