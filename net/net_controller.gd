class_name NetController
extends RefCounted

## NetController — "PlayerController qua mạng" (phía CLIENT).
## Cùng hình dạng API với PlayerController của game chính: mã điều khiển phía
## client (NetHud/NetClient/autotest) gọi các hàm này, chúng đóng gói lệnh
## thành Dictionary rồi gửi RPC lên server. Server có 1 PlayerController THẬT
## cho slot của người đó và cho lệnh chạy qua đúng các hàm exec_* của Main
## như bot/hotseat — toàn bộ kiểm tra hợp lệ (tài nguyên, dân số, sương mù)
## được tái sử dụng nguyên vẹn ở phía server.
##
## Khác biệt duy nhất so với PlayerController: BẤT ĐỒNG BỘ. Hàm ở đây chỉ có
## nghĩa "đã gửi lệnh đi"; kết quả thật về sau qua signal result_received
## (NetSession.command_result). Hiển thị phía client vì thế là LẠC QUAN:
## bấm là thấy phản hồi ngay, server từ chối thì HUD báo lý do (đúng phương
## án đã ghi ở INTEGRATION.md mục 1.2).
##
## Ánh xạ 1-1 với PlayerController (NET_DESIGN.md mục 4):
##   set_villager_allocation(w,s,g,m)     -> cmd "alloc"
##   place_building(type, position)       -> cmd "build"
##   queue_training(building_id, type)    -> cmd "train"  (building = net_id)
##   set_stance(stance, target_pid)       -> cmd "stance"
##   order_move(point)                    -> cmd "order_move"
##   order_selected_move(point, incl_v)   -> cmd "move"   (units = net_id[])
##   order_selected_farm(node_id)         -> cmd "farm"   (node = net_id)
##   order_selected_attack(target_id)     -> cmd "attack" (target = net_id)
## Bổ sung khi gộp vào main sau plan Đế Chế hoá (giao thức v2):
##   order_selected_attack_move(point)    -> cmd "attack_move" (units = net_id[])
##   order_selected_patrol(point)         -> cmd "patrol"      (units = net_id[])
##   order_selected_guard(target_id)      -> cmd "guard"       (units + target)
##   market_sell(res) / market_buy(res)   -> cmd "market_sell" / "market_buy"
##   start_age_up()                       -> cmd "age_up"      (tại Thành mình)
##   start_unit_research(b_id, type)      -> cmd "unit_research"
##   start_building_upgrade(b_id)         -> cmd "building_upgrade"
## Chọn quân (set_selection) là trạng thái LOCAL của client, không lên mạng —
## chỉ lệnh kết quả kèm danh sách net_id mới đi. Chọn TOÀN QUÂN (Shift+A) và
## tìm nông dân nhàn (".") cũng là thao tác chọn/hiển thị phía client: client
## tự chọn từ bản gương (quân mình luôn có đủ trong gương); trạng thái "nhàn"
## của nông dân KHÔNG có trong snapshot nên tìm-nông-dân-nhàn không có bản
## tương đương phía client (ghi nhận ở INTEGRATION_STATUS).

signal result_received(ok: bool, reason: String, op: String)

var _session: Node = null # NetSession — nơi chứa hàm RPC submit_command
var slot: int = -1
var selected_ids: Array = [] # net_id đang chọn (trạng thái local)

func setup(p_session: Node, p_slot: int) -> void:
	_session = p_session
	slot = p_slot

func _send(cmd: Dictionary) -> bool:
	if _session == null or slot < 0:
		return false
	_session.rpc_id(1, "submit_command", cmd) # peer 1 luôn là server
	return true

## Được NetClient gọi khi có command_result về từ server.
func _on_result(res: Dictionary) -> void:
	result_received.emit(bool(res.get("ok", false)), String(res.get("reason", "")), String(res.get("op", "")))

# ---------------- API cùng hình dạng PlayerController ----------------

func set_villager_allocation(wood: int, stone: int, gold: int, meat: int = 0) -> bool:
	return _send({"cmd": "alloc", "w": maxi(0, wood), "s": maxi(0, stone), "g": maxi(0, gold), "m": maxi(0, meat)})

func place_building(building_type: String, position: Vector2) -> bool:
	return _send({"cmd": "build", "type": building_type, "pos": [position.x, position.y]})

func queue_training(building_net_id: int, unit_type: String) -> bool:
	return _send({"cmd": "train", "building": building_net_id, "unit": unit_type})

func set_stance(stance: String, target_pid: int = -1) -> bool:
	return _send({"cmd": "stance", "stance": stance, "target": target_pid})

func order_move(point: Vector2) -> bool:
	return _send({"cmd": "order_move", "point": [point.x, point.y]})

func set_selection(ids: Array) -> void:
	selected_ids = ids.duplicate()

func get_selection() -> Array:
	return selected_ids.duplicate()

func order_selected_move(point: Vector2, include_villagers: bool) -> bool:
	if selected_ids.is_empty():
		return false
	return _send({"cmd": "move", "units": selected_ids.duplicate(), "point": [point.x, point.y], "villagers": include_villagers})

func order_selected_farm(node_net_id: int, villager_ids: Array) -> bool:
	if villager_ids.is_empty():
		return false
	return _send({"cmd": "farm", "units": villager_ids.duplicate(), "node": node_net_id})

func order_selected_attack(target_net_id: int) -> bool:
	if selected_ids.is_empty():
		return false
	return _send({"cmd": "attack", "units": selected_ids.duplicate(), "target": target_net_id})

# ---------------- LỆNH RTS NÂNG CAO (giao thức v2) ----------------

func order_selected_attack_move(point: Vector2) -> bool:
	if selected_ids.is_empty():
		return false
	return _send({"cmd": "attack_move", "units": selected_ids.duplicate(), "point": [point.x, point.y]})

func order_selected_patrol(point: Vector2) -> bool:
	if selected_ids.is_empty():
		return false
	return _send({"cmd": "patrol", "units": selected_ids.duplicate(), "point": [point.x, point.y]})

func order_selected_guard(target_net_id: int) -> bool:
	if selected_ids.is_empty():
		return false
	return _send({"cmd": "guard", "units": selected_ids.duplicate(), "target": target_net_id})

# ---------------- CHỢ / LÊN ĐỜI / NGHIÊN CỨU / NÂNG CẤP (v2) ----------------

func market_sell(res_key: String) -> bool:
	return _send({"cmd": "market_sell", "res": res_key})

func market_buy(res_key: String) -> bool:
	return _send({"cmd": "market_buy", "res": res_key})

## Lên Đời luôn tại Thành chính của mình (net_id thành = slot + 1).
func start_age_up() -> bool:
	return _send({"cmd": "age_up", "building": slot + 1})

func start_unit_research(building_net_id: int, unit_type: String) -> bool:
	return _send({"cmd": "unit_research", "building": building_net_id, "unit": unit_type})

func start_building_upgrade(building_net_id: int) -> bool:
	return _send({"cmd": "building_upgrade", "building": building_net_id})
