class_name NetClient
extends Node

## NetClient — phía NGƯỜI CHƠI trong chế độ LAN (bản web trong trình duyệt
## hoặc bản native khi test). Client KHÔNG mô phỏng thế giới:
## - gửi lệnh qua NetController (cùng hình dạng PlayerController),
## - nhận snapshot ĐÃ LỌC SƯƠNG MÙ của riêng mình -> dựng bản gương NetGhost,
## - sương mù hiển thị = lưới explored do server đồng bộ + visible tính lại
##   tại máy từ tầm nhìn quân NHÀ (đúng công thức Main._update_fog phía
##   server — client chỉ được biết phần của mình, và phần đó thì đầy đủ),
## - tự nối lại bằng token trong hạn grace 60s khi rớt mạng.
##
## Chế độ --autotest=A|B: client tự chơi theo kịch bản cố định để vòng kiểm
## chứng chạy không cần người (kế thừa ý tưởng autotest của prototype):
## A = chủ phòng (bắt đầu trận, luyện quân, xây nhà, phân bổ, di chuyển);
## B = khách (luyện quân, thử tấn công thành chưa lộ diện -> phải bị FOG từ
## chối, trinh sát tới nơi -> tấn công được chấp nhận, và vòng nối lại).

var session: Node = null
var game: Node = null # Main
var peer: WebSocketMultiplayerPeer = null
var hud: NetHud = null
var world: NetGhostWorld = null
var controller: NetController = null

# --- Trạng thái mà NetHud đọc ---
var conn_status: String = "Đang kết nối..."
var slot: int = -1
var is_host: bool = false
var my_ready: bool = false
var lobby_slots: Dictionary = {}
var match_running: bool = false
var player_you: Dictionary = {}
# Phòng chờ v3: prejoin = đã nối WS nhưng CHƯA ở trong phòng (màn hình
# tạo phòng / nhập mã). room_info = {"exists","name","code"} do server
# gửi (lobby_update mang sang cả khi prejoin). lobby_error = câu lỗi gần
# nhất của luồng lobby (sai mã / không phải chủ phòng...) để HUD hiện.
var prejoin: bool = false
var room_info: Dictionary = {"exists": false, "name": "", "code": ""}
var lobby_error: String = ""

var _url: String = "ws://127.0.0.1:8910"
var _my_name: String = "Người chơi"
var _roomcode: String = "" # CHỈ autotest: mã phòng lấy từ server log qua tham số
var _wrongcode: String = "" # CHỈ autotest C: mã sai để kiểm chứng bị từ chối
var _token: int = 0
var _tokenfile: String = ""
var _connected: bool = false
var _stopped: bool = false # lệch phiên bản/phòng đầy -> ngừng thử lại
var _retry_in: float = -1.0
var _ready_in: float = -1.0
var _quit_in: float = -1.0
var _fog_acc: float = 0.0
var _my_fog: FogOfWar = null
var _match_info: Dictionary = {}
var _ended: bool = false
var _awaiting_resync: bool = false

# --- Chế độ ra lệnh bằng chuột ---
var placing_type: String = ""
var _mode: String = "" # "" | "attack_target" | "scout_point" | "attack_move" | "patrol" | "guard"
var _drag_candidate: bool = false
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO

# --- Kiểm chứng phía client (gương không được chứa địch ngoài tầm nhìn) ---
var fog_violations: int = 0
var fog_checks: int = 0

# --- Log/autotest ---
var _log: Array = []
var _netlog_path: String = ""
var _shotdir: String = ""
var _autotest: String = ""
var _expect_reclaim: bool = false
var _pending: Array = [] # thẻ kỳ vọng kết quả lệnh (FIFO) cho autotest
var _at_t: float = 0.0
var _at_flags: Dictionary = {}
var _at_reported: bool = false

func start(p_session: Node, p_game: Node) -> void:
	session = p_session
	game = p_game
	var params: Dictionary = game.net_params
	_url = String(params.get("url", "ws://127.0.0.1:%d" % NetProtocol.PORT))
	_my_name = String(params.get("name", "Khách web" if OS.has_feature("web") else "Người chơi"))
	_tokenfile = String(params.get("tokenfile", ""))
	_autotest = String(params.get("autotest", ""))
	_roomcode = String(params.get("roomcode", ""))
	_wrongcode = String(params.get("wrongcode", ""))
	_expect_reclaim = String(params.get("expect_reclaim", "")) == "true"
	_netlog_path = String(params.get("netlog", ""))
	_shotdir = String(params.get("shotdir", ""))
	if _tokenfile != "" and FileAccess.file_exists(_tokenfile):
		_token = int(FileAccess.get_file_as_string(_tokenfile).strip_edges())
	elif _tokenfile == "":
		var cfg := ConfigFile.new()
		if cfg.load("user://net_lan.cfg") == OK:
			_token = int(cfg.get_value("lan", "token", 0))
	world = NetGhostWorld.new()
	world.name = "NetGhostWorld"
	game.add_child(world)
	hud = NetHud.new()
	hud.name = "NetHud"
	game.add_child(hud)
	hud.setup(self)
	_connect()

func _logline(s: String) -> void:
	_log.append(s)
	print("NETCLIENT ", s)

# ============================ KẾT NỐI ============================

func _connect() -> void:
	if _stopped:
		return
	peer = WebSocketMultiplayerPeer.new()
	var err := peer.create_client(_url)
	if err != OK:
		conn_status = "Không nối được tới chủ nhà — đang thử lại..."
		hud.refresh_lobby()
		_retry_in = 1.0
		return
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	conn_status = "Đang kết nối tới %s..." % _url
	hud.refresh_lobby()

func _on_connected() -> void:
	_connected = true
	conn_status = "Đã kết nối — đang vào phòng..."
	session.rpc_id(1, "submit_hello", _my_name, _token, NetProtocol.PROTOCOL_VERSION)
	_logline("CONNECTED url=%s" % _url)
	hud.refresh_lobby()

func _on_connection_failed() -> void:
	_connected = false
	conn_status = "Kết nối thất bại — đang thử lại..."
	_logline("CONNECTION_FAILED")
	_retry_in = 1.0
	hud.refresh_lobby()

func _on_server_disconnected() -> void:
	_connected = false
	if _stopped:
		return
	# Rớt mạng: GIỮ nguyên gương + slot kỳ vọng, tự nối lại bằng token —
	# server giữ phe trong hạn grace 60s (NET_DESIGN.md mục 7).
	conn_status = "MẤT KẾT NỐI — đang nối lại (server giữ phe của bạn 60 giây)..."
	_logline("DISCONNECTED")
	_retry_in = 1.0
	hud.refresh_lobby()

# ============================ NHẬN TỪ SERVER ============================

func handle_welcome(data: Dictionary) -> void:
	var new_slot := int(data.get("slot", -1))
	if new_slot == -2:
		_stopped = true
		conn_status = "Lệch phiên bản giao thức với chủ nhà — hãy tải lại bản client từ gói chủ nhà."
		_logline("WELCOME_VERSION_REJECT")
		hud.refresh_lobby()
		return
	if new_slot == -3:
		# PREJOIN (giao thức v3): đã nối WS, chưa ở trong phòng. Server
		# cho biết phòng đã có hay chưa để client hiện đúng màn hình.
		prejoin = true
		room_info = {"exists": bool(data.get("room_exists", false)),
			"name": String(data.get("room_name", "")), "code": ""}
		if bool(room_info["exists"]):
			conn_status = "Đã nối tới chủ nhà — phòng \"%s\" đang mở, nhập MÃ PHÒNG để vào." % String(room_info["name"])
		else:
			conn_status = "Đã nối tới chủ nhà — chưa có phòng nào, hãy TẠO PHÒNG mới."
		_logline("PREJOIN room_exists=%s" % str(room_info["exists"]))
		hud.show_entry()
		if _autotest == "" and _shotdir != "":
			_take_shot_deferred("net_entry.png") # chụp màn hình tạo/nhập mã khi chạy tay bằng xvfb
		# Kịch bản kiểm chứng tự động cho luồng phòng:
		if _autotest == "A" and not bool(room_info["exists"]):
			ui_create_room(_my_name, "Phòng kiểm chứng")
		elif _autotest == "B":
			ui_join_room(_my_name, _roomcode)
		elif _autotest == "C":
			if _wrongcode != "":
				_pending.append("join_wrong")
				session.rpc_id(1, "submit_lobby_action", {"action": "join_room", "name": _my_name, "code": _wrongcode})
			else:
				ui_join_room(_my_name, _roomcode)
		return
	if new_slot < 0:
		_stopped = true
		conn_status = "Không vào được phòng (đầy hoặc trận đã bắt đầu)."
		_logline("WELCOME_REJECT reason=%s" % String(data.get("reason", "")))
		if _autotest == "E":
			# Ca kiểm chứng: người mới nối vào GIỮA trận phải bị từ chối.
			_at_flags["late_reject"] = String(data.get("reason", "")) == "IN_MATCH"
			_at_finish_report()
			_quit_in = 1.5
		hud.refresh_lobby()
		return
	prejoin = false
	lobby_error = ""
	slot = new_slot
	_token = int(data.get("token", 0))
	is_host = bool(data.get("is_host", false))
	var reclaimed := bool(data.get("reclaimed", false))
	_save_token()
	world.setup(slot)
	_my_fog = game.fogs[slot]
	controller = NetController.new()
	controller.setup(session, slot)
	controller.result_received.connect(_on_cmd_result)
	conn_status = "Đã vào phòng — bạn là Phe %s%s" % [NetHud.SLOT_NAMES[slot], " (CHỦ PHÒNG)" if is_host else ""]
	_logline("WELCOME slot=%d host=%s reclaimed=%s" % [slot, str(is_host), str(reclaimed)])
	if reclaimed:
		_at_flags["reclaim"] = true
		_awaiting_resync = true
		print("AUTOTEST reclaim=1")
	if reclaimed and _autotest == "C2":
		# Nối lại lúc còn ở LOBBY (trận chưa bắt đầu) cũng phải đúng slot.
		_at_flags["lobby_reclaim"] = true
	if _autotest == "C":
		# Khách thử bấm BẮT ĐẦU ngay khi vừa vào phòng: server phải từ
		# chối NOT_HOST (kết quả về qua command_result, thẻ "start_guest").
		_pending.append("start_guest")
		session.rpc_id(1, "submit_lobby_action", {"action": "start"})
	if _autotest != "":
		_ready_in = 0.5
	hud.refresh_lobby()
	if _autotest != "" and not reclaimed:
		_take_shot_deferred("net_lobby_%s.png" % _autotest)

func _save_token() -> void:
	if _token == 0:
		return
	if _tokenfile != "":
		var f := FileAccess.open(_tokenfile, FileAccess.WRITE)
		if f != null:
			f.store_string(str(_token))
			f.close()
	else:
		var cfg := ConfigFile.new()
		cfg.set_value("lan", "token", _token)
		cfg.save("user://net_lan.cfg")

func handle_lobby(state: Dictionary) -> void:
	lobby_slots = state.get("slots", {})
	room_info = state.get("room", room_info)
	if lobby_slots.has(slot):
		my_ready = bool((lobby_slots[slot] as Dictionary).get("ready", false))
	if match_running:
		return # giữa trận, lobby_update chỉ còn là nhịp giữ trạng thái
	if prejoin:
		hud.refresh_entry()
	else:
		hud.refresh_lobby()
	# Autotest C/C2: ghi nhận khi thấy 1 slot bị chủ phòng ĐÓNG.
	if _autotest == "C" or _autotest == "C2":
		for s in lobby_slots.keys():
			if String((lobby_slots[s] as Dictionary).get("kind", "")) == "closed":
				_at_flags["slot_closed_seen"] = true
	# Autotest A (CHỦ PHÒNG): đánh giá điều kiện phòng chờ — hàm eval
	# cũng được _process gọi mỗi frame vì mốc "giữ điều kiện 8 giây"
	# cần nhịp thời gian liên tục (lobby_update là sự kiện rời rạc,
	# sau thay đổi cuối cùng sẽ không còn sự kiện nào để mà bấm bắt đầu).
	if _autotest == "A" and is_host and not match_running:
		_at_lobby_host_eval(0.0)

## Đánh giá phòng chờ phía autotest A: đủ 3 người thì ĐÓNG slot trống
## còn lại; khi lệnh đóng đã có hiệu lực + mọi người ĐANG NỐI đều sẵn
## sàng, GIỮ điều kiện đó liên tục 8 giây mới bấm Bắt đầu — cửa sổ 8s
## là để kịch bản kịp GIẾT C giữa lobby rồi nối lại bằng token (C2)
## trước khi trận bắt đầu (bấm ngay khi đủ người là cuộc đua với thao
## tác giết/nối lại, kết quả lật theo nhịp máy).
var _at_start_hold: float = 0.0

func _at_lobby_host_eval(delta: float) -> void:
	var humans := 0
	var connected_humans := 0
	var all_connected_ready := true
	var empty_open_slot := -1
	for s in lobby_slots.keys():
		var info: Dictionary = lobby_slots[s]
		var kind := String(info.get("kind", ""))
		if kind == "human":
			humans += 1
			if bool(info.get("connected", false)):
				connected_humans += 1
				if not bool(info.get("ready", false)):
					all_connected_ready = false
		elif kind == "open" and empty_open_slot < 0:
			empty_open_slot = int(s)
	if humans >= 3 and empty_open_slot >= 0 and not bool(_at_flags.get("set_slot_sent", false)):
		_at_flags["set_slot_sent"] = true
		_at_flags["closed_slot"] = empty_open_slot
		session.rpc_id(1, "submit_lobby_action", {"action": "set_slot", "slot": empty_open_slot, "mode": "closed"})
		_logline("AUTOTEST_SET_SLOT_CLOSED slot=%d" % empty_open_slot)
	var cs := int(_at_flags.get("closed_slot", -1))
	if cs >= 0 and lobby_slots.has(cs) and String((lobby_slots[cs] as Dictionary).get("kind", "")) == "closed":
		_at_flags["slot_closed_ok"] = true
	if humans >= 3 and not bool(_at_flags.get("shot_lobby_full", false)):
		_at_flags["shot_lobby_full"] = true
		_take_shot_deferred("net_lobby_A.png") # lobby đủ người + mã phòng + slot đã đóng
	var cond_ok := bool(_at_flags.get("slot_closed_ok", false)) and connected_humans >= 3 and all_connected_ready
	if cond_ok and not bool(_at_flags.get("start_sent", false)):
		_at_start_hold += delta
		if _at_start_hold >= 8.0:
			_at_flags["start_sent"] = true
			session.rpc_id(1, "submit_lobby_action", {"action": "start"})
			_logline("AUTOTEST_START_SENT")
	elif not cond_ok:
		_at_start_hold = 0.0

func handle_match_started(data: Dictionary) -> void:
	_match_info = data
	match_running = true
	_ended = false
	world.reset()
	hud.show_game()
	var castles: Dictionary = data.get("castles", {})
	if castles.has(slot):
		var cp: Array = castles[slot]
		game.set_camera_to(Vector2(float(cp[0]), float(cp[1])))
	_at_t = 0.0
	_logline("MATCH_START slot=%d" % slot)
	_at_flags["match_started"] = true

func handle_snapshot(msg: Dictionary) -> void:
	if slot < 0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	world.apply_snapshot(msg, now)
	player_you = msg.get("you", {})
	hud.refresh_you()
	_check_fog_violations()
	if _awaiting_resync:
		_awaiting_resync = false
		_at_flags["resync"] = true
		print("AUTOTEST resync=1")
		_logline("RESYNC_OK")

func handle_explored(data: PackedByteArray) -> void:
	if _my_fog != null and data.size() == _my_fog.explored.size():
		_my_fog.explored = data.duplicate()
		_refresh_fog_overlay()

func handle_result(res: Dictionary) -> void:
	if controller != null:
		controller._on_result(res)
	else:
		# Chưa có controller (controller chỉ sinh khi đã nhận slot) mà
		# server vẫn hồi báo cho các hành động LOBBY (vào phòng sai mã,
		# khách bấm bắt đầu...) — xử lý thẳng tại đây, đừng đánh rơi.
		_on_cmd_result(bool(res.get("ok", false)), String(res.get("reason", "")), String(res.get("op", "")))

func handle_match_ended(data: Dictionary) -> void:
	_ended = true
	var winner := int(data.get("winner", -1))
	var text := ""
	if winner == slot:
		text = "THẮNG! Thành địch đã sụp đổ."
	elif winner < 0:
		text = "Trận kết thúc."
	else:
		text = "Thua — Phe %s đã thắng trận này." % NetHud.SLOT_NAMES[winner]
	hud.show_end(text)
	_logline("MATCH_END winner=%d" % winner)
	if _autotest != "":
		_at_finish_report()
		_quit_in = 2.0

func _on_cmd_result(ok: bool, reason: String, op: String) -> void:
	var tag := ""
	if not _pending.is_empty():
		tag = String(_pending.pop_front())
	_logline("RESULT tag=%s op=%s ok=%s reason=%s" % [tag, op, str(ok), reason])
	if not ok:
		if match_running:
			hud.show_message(NetProtocol.reason_text(reason))
		else:
			# Lỗi của luồng phòng chờ (sai mã, không phải chủ phòng, thiếu
			# đối thủ...) hiện ngay trên màn hình phòng, không phải HUD trận.
			lobby_error = NetProtocol.reason_text(reason)
			if prejoin:
				hud.refresh_entry()
			else:
				hud.refresh_lobby()
	_at_apply_result(tag, ok, reason)

# ============================ SƯƠNG MÙ PHÍA CLIENT ============================

func _refresh_fog_overlay() -> void:
	if _my_fog == null:
		return
	var overlay = game.get("_fog_overlay")
	if overlay != null:
		overlay.set_fog(_my_fog)
		overlay.queue_redraw()

func _recompute_visible() -> void:
	# visible_now của MÌNH được phép biết đầy đủ: tính lại từ tầm nhìn quân
	# nhà trong gương — đúng công thức Main._update_fog phía server.
	if _my_fog == null or not match_running:
		return
	_my_fog.reset_visible()
	var vision: Dictionary = Stats.FOG["vision"]
	for g in world.ghosts.values():
		var gh := g as NetGhost
		if gh.owner_pid != slot:
			continue
		var r := 0.0
		match gh.kind:
			"castle":
				r = float(vision["castle"])
			"building":
				r = float(vision["tower"]) if gh.sub == "tower" and gh.is_constructed() else float(vision["building"])
			"unit":
				r = float(vision.get(gh.sub, 150.0))
			"villager":
				r = float(vision["pawn"])
		if r > 0.0:
			_my_fog.reveal_circle(gh.render, r)
	_refresh_fog_overlay()

## Kiểm chứng phía client: quân địch nằm trong gương mà cách MỌI thực thể
## của mình quá tầm nhìn lớn nhất (thành 265) + biên nội suy = server đã rò.
func _check_fog_violations() -> void:
	var mine: Array = []
	for g in world.ghosts.values():
		var gh := g as NetGhost
		if gh.owner_pid == slot:
			mine.append(gh.render)
	if mine.is_empty():
		return
	for g in world.ghosts.values():
		var gh := g as NetGhost
		if gh.owner_pid != slot and gh.kind == "unit":
			fog_checks += 1
			var best := 1e9
			for mp in mine:
				best = minf(best, gh.render.distance_to(mp))
			if best > 300.0:
				fog_violations += 1

# ============================ HÀNH ĐỘNG TỪ HUD ============================

func ui_ready() -> void:
	if slot >= 0 and _connected:
		session.rpc_id(1, "submit_ready")

func ui_start() -> void:
	if is_host:
		session.rpc_id(1, "submit_lobby_action", {"action": "start"})

# ---------------- PHÒNG CHỜ v3: tạo phòng / vào phòng / slot ----------------

func ui_create_room(p_name: String, room_name: String) -> void:
	lobby_error = ""
	session.rpc_id(1, "submit_lobby_action", {"action": "create_room", "name": p_name, "room_name": room_name})

func ui_join_room(p_name: String, code: String) -> void:
	lobby_error = ""
	session.rpc_id(1, "submit_lobby_action", {"action": "join_room", "name": p_name, "code": code})

func ui_set_slot_mode(target_slot: int, mode: String) -> void:
	if is_host:
		session.rpc_id(1, "submit_lobby_action", {"action": "set_slot", "slot": target_slot, "mode": mode})

func ui_rename_room(room_name: String) -> void:
	if is_host:
		session.rpc_id(1, "submit_lobby_action", {"action": "rename_room", "room_name": room_name})

func ui_alloc(res_key: String, delta_sign: int) -> void:
	if controller == null:
		return
	var alloc: Dictionary = player_you.get("allocation", {"wood": 0, "stone": 0, "gold": 0, "meat": 0})
	controller.set_villager_allocation(
		int(alloc.get("wood", 0)) + (delta_sign if res_key == "wood" else 0),
		int(alloc.get("stone", 0)) + (delta_sign if res_key == "stone" else 0),
		int(alloc.get("gold", 0)) + (delta_sign if res_key == "gold" else 0),
		int(alloc.get("meat", 0)) + (delta_sign if res_key == "meat" else 0))

func ui_build(btype: String) -> void:
	if not match_running:
		return
	placing_type = btype
	_mode = ""
	hud.show_message("Bấm vào vị trí trên map để đặt %s (chuột phải để huỷ). Máy chủ sẽ kiểm tra vùng/tài nguyên." % Stats.BUILDINGS[btype]["label"])

func ui_train(producer_id: int, unit_type: String) -> void:
	if controller != null:
		controller.queue_training(producer_id, unit_type)

func ui_hold() -> void:
	if controller != null:
		_mode = ""
		controller.set_stance("hold")
		hud.show_message("Quân về thế giữ nhà.")

func ui_attack_mode() -> void:
	_mode = "attack_target"
	placing_type = ""
	hud.show_message("Bấm vào THÀNH ĐỊCH ĐÃ LỘ DIỆN để tổng tấn công.")

func ui_scout_mode() -> void:
	_mode = "scout_point"
	placing_type = ""
	hud.show_message("Bấm 1 điểm trên map để quân đi trinh sát tới đó.")

# ---------------- LỆNH RTS / CHỢ / ĐỜI (giao thức v2) ----------------

func ui_attack_move_mode() -> void:
	if world.selected_ids.is_empty():
		hud.show_message("Hãy chọn quân trước rồi mới ra lệnh đánh-di-chuyển.")
		return
	_mode = "attack_move"
	placing_type = ""
	hud.show_message("Đánh-di-chuyển: bấm điểm đích — quân tự đánh địch thấy được trên đường.")

func ui_patrol_mode() -> void:
	if world.selected_ids.is_empty():
		hud.show_message("Hãy chọn quân trước rồi mới ra lệnh tuần tra.")
		return
	_mode = "patrol"
	placing_type = ""
	hud.show_message("Tuần tra: bấm điểm đầu kia của tuyến tuần tra.")

func ui_guard_mode() -> void:
	if world.selected_ids.is_empty():
		hud.show_message("Hãy chọn quân trước rồi mới ra lệnh hộ vệ.")
		return
	_mode = "guard"
	placing_type = ""
	hud.show_message("Hộ vệ: bấm vào quân/công trình ĐỒNG MINH cần bảo vệ.")

func ui_market_sell(res_key: String) -> void:
	if controller != null:
		controller.market_sell(res_key)

func ui_market_buy(res_key: String) -> void:
	if controller != null:
		controller.market_buy(res_key)

func ui_age_up() -> void:
	if controller != null:
		controller.start_age_up()

func ui_research(unit_type: String) -> void:
	if controller != null and world.selected_structure_id != 0:
		controller.start_unit_research(world.selected_structure_id, unit_type)

func ui_upgrade() -> void:
	if controller != null and world.selected_structure_id != 0:
		controller.start_building_upgrade(world.selected_structure_id)

# ============================ INPUT TRÊN MAP ============================

func _selected_ghosts() -> Array:
	var out: Array = []
	for id in world.selected_ids:
		var gh := world.ghost(int(id))
		if gh != null:
			out.append(gh)
	return out

func _unhandled_input(event: InputEvent) -> void:
	if not match_running or _ended or controller == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if placing_type != "" or _mode != "":
				placing_type = ""
				_mode = ""
				hud.show_message("Đã huỷ.")
			else:
				_handle_right_click(game.get_global_mouse_position())
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var pos: Vector2 = game.get_global_mouse_position()
		if placing_type != "":
			controller.place_building(placing_type, pos)
			hud.show_message("Đã gửi lệnh đặt %s..." % Stats.BUILDINGS[placing_type]["label"])
			placing_type = ""
			return
		if _mode == "attack_target":
			_mode = ""
			var castle := world.nearest_ghost(pos, 95.0, func(g: NetGhost) -> bool: return g.kind == "castle" and g.owner_pid != slot)
			if castle != null:
				controller.set_stance("attack", castle.owner_pid)
			else:
				hud.show_message("Chưa chọn được thành địch nào ở đó.")
			return
		if _mode == "scout_point":
			_mode = ""
			controller.order_move(pos)
			hud.show_message("Quân đang đi trinh sát.")
			return
		if _mode == "attack_move":
			_mode = ""
			controller.set_selection(world.selected_ids)
			controller.order_selected_attack_move(pos)
			hud.show_message("Đánh-di-chuyển tới điểm đã chọn!")
			return
		if _mode == "patrol":
			_mode = ""
			controller.set_selection(world.selected_ids)
			controller.order_selected_patrol(pos)
			hud.show_message("Tuần tra tới điểm đã chọn!")
			return
		if _mode == "guard":
			_mode = ""
			var ally := world.nearest_ghost(pos, 1e9, func(g: NetGhost) -> bool: return g.owner_pid == slot and (g.kind == "unit" or g.kind == "castle" or g.kind == "building"))
			if ally != null and ally.render.distance_to(pos) > ally.radius() + 20.0:
				ally = null
			if ally != null:
				controller.set_selection(world.selected_ids)
				controller.order_selected_guard(ally.net_id)
				hud.show_message("Hộ vệ mục tiêu!")
			else:
				hud.show_message("Chưa chọn được đồng minh nào ở đó để hộ vệ.")
			return
		_drag_candidate = true
		_dragging = false
		_drag_start = pos
		return
	if event is InputEventMouseMotion and _drag_candidate:
		var pos: Vector2 = game.get_global_mouse_position()
		if pos.distance_to(_drag_start) > 8.0:
			_dragging = true
		if _dragging:
			world.drag_active = true
			world.drag_rect = Rect2(_drag_start, pos - _drag_start).abs()
			world.queue_redraw()
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _drag_candidate:
		_drag_candidate = false
		world.drag_active = false
		world.queue_redraw()
		if _dragging:
			_dragging = false
			var ids := world.own_units_at_rect(Rect2(_drag_start, game.get_global_mouse_position() - _drag_start).abs())
			world.set_selection(ids)
			world.set_structure_selection(0)
			controller.set_selection(ids)
		else:
			var gh := world.nearest_ghost(game.get_global_mouse_position(), 30.0,
				func(g: NetGhost) -> bool: return g.owner_pid == slot and (g.kind == "unit" or g.kind == "villager"))
			if gh != null:
				world.set_selection([gh.net_id])
				world.set_structure_selection(0)
				controller.set_selection([gh.net_id])
			else:
				# Click vào công trình của mình -> chọn công trình (panel
				# Lên Đời / Nghiên cứu / Nâng cấp ở NetHud).
				var st := world.nearest_ghost(game.get_global_mouse_position(), 1e9,
					func(g: NetGhost) -> bool: return g.owner_pid == slot and (g.kind == "castle" or g.kind == "building"))
				if st != null and st.render.distance_to(game.get_global_mouse_position()) > st.radius() + 14.0:
					st = null
				if st != null:
					world.set_selection([])
					controller.set_selection([])
					world.set_structure_selection(st.net_id)
					hud.refresh_you()
				else:
					world.set_selection([])
					world.set_structure_selection(0)
					controller.set_selection([])
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				placing_type = ""
				_mode = ""
				world.set_selection([])
				world.set_structure_selection(0)
				controller.set_selection([])
			KEY_A:
				ui_attack_move_mode()
			KEY_P:
				ui_patrol_mode()
			KEY_G:
				ui_guard_mode()

func _handle_right_click(pos: Vector2) -> void:
	var sel := _selected_ghosts()
	if sel.is_empty():
		hud.show_message("Hãy chọn quân trước: kéo chuột trái chọn vùng, rồi click phải ra lệnh.")
		return
	# 0) Đồng minh (quân/công trình của mình) -> HỘ VỆ, như click phải
	# trong chơi đơn. Nông dân không làm đối tượng hộ vệ được (luật Main).
	var ally := world.nearest_ghost(pos, 1e9, func(g: NetGhost) -> bool: return g.owner_pid == slot and (g.kind == "unit" or g.kind == "castle" or g.kind == "building"))
	if ally != null and ally.render.distance_to(pos) > ally.radius() + 14.0:
		ally = null
	var has_military := false
	for gh in sel:
		if (gh as NetGhost).kind == "unit":
			has_military = true
	if ally != null and has_military and not world.selected_ids.has(ally.net_id):
		controller.set_selection(world.selected_ids)
		controller.order_selected_guard(ally.net_id)
		hud.show_message("Hộ vệ mục tiêu!")
		return
	# 1) Quân địch đang thấy -> tấn công.
	var eu := world.nearest_ghost(pos, 30.0, func(g: NetGhost) -> bool: return g.kind == "unit" and g.owner_pid != slot)
	if eu != null:
		controller.order_selected_attack(eu.net_id)
		hud.show_message("Tấn công mục tiêu!")
		return
	# 2) Công trình địch -> tấn công (server vẫn giữ luật sương mù).
	var es := world.nearest_ghost(pos, 1e9, func(g: NetGhost) -> bool: return (g.kind == "castle" or g.kind == "building") and g.owner_pid != slot)
	if es != null and es.render.distance_to(pos) > es.radius() + 14.0:
		es = null
	if es != null:
		controller.order_selected_attack(es.net_id)
		hud.show_message("Tấn công mục tiêu!")
		return
	var villager_ids: Array = []
	var military_ids: Array = []
	for gh in sel:
		if (gh as NetGhost).kind == "villager":
			villager_ids.append((gh as NetGhost).net_id)
		elif (gh as NetGhost).kind == "unit":
			military_ids.append((gh as NetGhost).net_id)
	# 3) Cừu đang thấy -> nông dân săn.
	var sheep := world.nearest_ghost(pos, 36.0, func(g: NetGhost) -> bool: return g.kind == "sheep")
	if sheep != null:
		if not villager_ids.is_empty():
			controller.order_selected_farm(sheep.net_id, villager_ids)
			hud.show_message("Nông dân đi săn cừu lấy thịt.")
		else:
			hud.show_message("Hãy chọn NÔNG DÂN để săn cừu.")
		return
	# 4) Node tài nguyên -> nông dân farm, quân đi tới điểm.
	var node := world.nearest_ghost(pos, 36.0, func(g: NetGhost) -> bool: return g.kind == "node")
	if node != null:
		if not villager_ids.is_empty():
			controller.order_selected_farm(node.net_id, villager_ids)
		if not military_ids.is_empty():
			controller.set_selection(military_ids)
			controller.order_selected_move(node.render, false)
			controller.set_selection(world.selected_ids)
		if not villager_ids.is_empty():
			hud.show_message("Nông dân đi farm.")
		else:
			hud.show_message("Quân đang di chuyển tới điểm đã chọn.")
		return
	# 5) Đất trống -> di chuyển.
	controller.order_selected_move(pos, true)
	hud.show_message("Quân đang di chuyển tới điểm đã chọn.")

# ============================ VÒNG LẶP ============================

func _process(delta: float) -> void:
	if _retry_in >= 0.0:
		_retry_in -= delta
		if _retry_in <= 0.0:
			_retry_in = -1.0
			_connect()
	if _ready_in >= 0.0:
		_ready_in -= delta
		if _ready_in <= 0.0:
			_ready_in = -1.0
			ui_ready()
	if _autotest == "A" and is_host and not match_running and slot >= 0:
		_at_lobby_host_eval(delta) # nhịp thời gian cho mốc giữ điều kiện 8s
	if _quit_in >= 0.0:
		_quit_in -= delta
		if _quit_in <= 0.0:
			get_tree().quit()
		return
	if placing_type != "":
		world.placing_active = true
		world.placing_pos = game.get_global_mouse_position()
		world.placing_radius = float(Stats.BUILDINGS[placing_type]["radius"])
		world.queue_redraw()
	elif world.placing_active:
		world.placing_active = false
		world.queue_redraw()
	if match_running and not _ended:
		_fog_acc += delta
		if _fog_acc >= 0.25:
			_fog_acc = 0.0
			_recompute_visible()
		if _autotest != "":
			_at_t += delta
			_at_tick()

# ============================ AUTOTEST ============================

func _send_tagged(tag: String) -> void:
	_pending.append(tag)

func _at_apply_result(tag: String, ok: bool, reason: String) -> void:
	if _autotest == "":
		return
	match tag:
		"join_wrong":
			# Ca phòng chờ v3: vào phòng bằng MÃ SAI phải bị WRONG_CODE,
			# sau đó vào lại bằng mã đúng (kết quả là welcome, không phải
			# command_result).
			_at_flags["wrong_code_reject"] = (not ok and reason == NetProtocol.R_WRONG_CODE)
			if bool(_at_flags["wrong_code_reject"]):
				print("AUTOTEST wrong_code_reject=1")
				ui_join_room(_my_name, _roomcode)
		"start_guest":
			_at_flags["start_guest_reject"] = (not ok and reason == NetProtocol.R_NOT_HOST)
			if bool(_at_flags["start_guest_reject"]):
				print("AUTOTEST start_guest_reject=1")
		"train":
			_at_flags["train_ok"] = ok
		"build":
			_at_flags["build_ok"] = ok
		"alloc":
			_at_flags["alloc_ok"] = ok
		"move":
			_at_flags["move_ok"] = ok
		# --- Ca lệnh mới (giao thức v2) ---
		"market_sell":
			_at_flags["market_sell_ok"] = ok
		"market_buy":
			_at_flags["market_buy_ok"] = ok
		"train_monk":
			_at_flags["train_monk_ok"] = ok
		"build_barracks":
			_at_flags["build_barracks_ok"] = ok
		"build_farm":
			_at_flags["build_farm_ok"] = ok
		"age_up":
			_at_flags["age_up_ok"] = ok
		"age_up_busy":
			_at_flags["age_up_busy"] = (not ok and reason == NetProtocol.R_BUSY)
		"upgrade_farm":
			_at_flags["upgrade_farm_reject"] = (not ok and reason == NetProtocol.R_NOT_UPGRADEABLE)
		"research_gate":
			if not ok and reason == NetProtocol.R_AGE_GATE:
				_at_flags["research_gate"] = true
			elif ok:
				_at_flags["research_gate_bad"] = true
			elif reason == NetProtocol.R_NO_TARGET:
				_at_flags["research_gate_sent"] = false # doanh trại chưa xây xong -> thử lại
		"research":
			if ok:
				_at_flags["research_ok"] = true
			elif reason == NetProtocol.R_AGE_GATE or reason == NetProtocol.R_BUSY:
				_at_flags["research_sent"] = false # Đời chưa lên xong -> thử lại
		"upgrade":
			if ok:
				_at_flags["upgrade_ok"] = true
			elif reason == NetProtocol.R_AGE_GATE:
				_at_flags["upgrade_sent"] = false
		"attack_move":
			_at_flags["attack_move_ok"] = ok
		"patrol":
			_at_flags["patrol_ok"] = ok
		"guard":
			_at_flags["guard_ok"] = ok
		"fog_attack":
			_at_flags["fog_reject"] = (not ok and reason == NetProtocol.R_FOG)
			if bool(_at_flags["fog_reject"]):
				print("AUTOTEST fog_reject=1")
		"castle_attack":
			_at_flags["castle_attack_ok"] = ok
			if ok:
				print("AUTOTEST castle_attack_ok=1")
		"post_alloc":
			_at_flags["post_reconnect_cmd"] = ok
			if ok:
				print("AUTOTEST post_reconnect_cmd=1")
	if tag != "":
		print("AUTOTEST result tag=%s ok=%s reason=%s" % [tag, str(ok), reason])

func _my_castle_ghost() -> NetGhost:
	return world.ghost(slot + 1)

func _enemy_human_slot() -> int:
	# Địch người GẦN THÀNH MÌNH NHẤT: kịch bản B phải cho trinh sát đi
	# hết đường và lộ thành trong thời lượng phiên — chọn địch xa nhất
	# (chéo map) thì lính trinh sát dễ chết dọc đường vì quân giữ nhà
	# của các phe nó đi ngang, mốc lộ thành không bao giờ đạt.
	var castles: Dictionary = _match_info.get("castles", {})
	var mine := Vector2(1e9, 1e9)
	if castles.has(slot):
		var mp: Array = castles[slot]
		mine = Vector2(float(mp[0]), float(mp[1]))
	var best := -1
	var best_d := 1e18
	var infos: Array = _match_info.get("slots", [])
	for info in infos:
		var s := int((info as Dictionary).get("slot", -1))
		if s == slot or String((info as Dictionary).get("kind", "")) != "human":
			continue
		var d := 0.0
		if castles.has(s):
			var ep: Array = castles[s]
			d = mine.distance_squared_to(Vector2(float(ep[0]), float(ep[1])))
		if d < best_d:
			best_d = d
			best = s
	return best

func _at_tick() -> void:
	if _autotest == "A":
		_at_tick_a()
	elif _autotest == "B" or _autotest == "B2":
		# B2 = vòng nối lại của B, chạy chung kịch bản (nhánh _expect_reclaim
		# bên trong _at_tick_b xử lý phần nối lại).
		_at_tick_b()

## Ghost nhà của mình theo loại (phục vụ autotest: nghiên cứu/nâng cấp).
func _my_building_ghost(sub: String) -> NetGhost:
	for g in world.ghosts.values():
		var gh := g as NetGhost
		if gh.owner_pid == slot and gh.kind == "building" and gh.sub == sub:
			return gh
	return null

func _at_tick_a() -> void:
	if not bool(_at_flags.get("train_sent", false)) and _at_t >= 1.0:
		_at_flags["train_sent"] = true
		_send_tagged("train")
		controller.queue_training(slot + 1, "warrior")
	if not bool(_at_flags.get("build_sent", false)) and _at_t >= 2.0:
		var castle := _my_castle_ghost()
		if castle != null:
			_at_flags["build_sent"] = true
			var mx := 1.0 if castle.render.x < 960.0 else -1.0
			var my := 1.0 if castle.render.y < 480.0 else -1.0
			_send_tagged("build")
			controller.place_building("house", castle.render + Vector2(mx * -105, my * -80))
	if not bool(_at_flags.get("alloc_sent", false)) and _at_t >= 3.0:
		_at_flags["alloc_sent"] = true
		_send_tagged("alloc")
		controller.set_villager_allocation(2, 1, 1, 0)
	# --- Chuỗi ca lệnh mới (server chạy --testgrant nên đủ tài nguyên) ---
	if not bool(_at_flags.get("market_sell_sent", false)) and _at_t >= 4.0:
		_at_flags["market_sell_sent"] = true
		_send_tagged("market_sell")
		controller.market_sell("wood")
	if not bool(_at_flags.get("market_buy_sent", false)) and _at_t >= 5.0:
		_at_flags["market_buy_sent"] = true
		_send_tagged("market_buy")
		controller.market_buy("stone")
	if not bool(_at_flags.get("train_monk_sent", false)) and _at_t >= 6.0:
		_at_flags["train_monk_sent"] = true
		_send_tagged("train_monk")
		controller.queue_training(slot + 1, "monk")
	if not bool(_at_flags.get("build_barracks_sent", false)) and _at_t >= 8.0:
		var castle2 := _my_castle_ghost()
		if castle2 != null:
			_at_flags["build_barracks_sent"] = true
			var mx2 := 1.0 if castle2.render.x < 960.0 else -1.0
			var my2 := 1.0 if castle2.render.y < 480.0 else -1.0
			_send_tagged("build_barracks")
			controller.place_building("barracks", castle2.render + Vector2(mx2 * 30, my2 * -102))
	if not bool(_at_flags.get("build_farm_sent", false)) and _at_t >= 10.0:
		var castle3 := _my_castle_ghost()
		if castle3 != null:
			_at_flags["build_farm_sent"] = true
			var mx3 := 1.0 if castle3.render.x < 960.0 else -1.0
			var my3 := 1.0 if castle3.render.y < 480.0 else -1.0
			_send_tagged("build_farm")
			controller.place_building("farm", castle3.render + Vector2(mx3 * 30, my3 * 102))
	if not bool(_at_flags.get("age_up_sent", false)) and _at_t >= 12.0:
		_at_flags["age_up_sent"] = true
		_send_tagged("age_up")
		controller.start_age_up()
	if not bool(_at_flags.get("age_up_busy_sent", false)) and _at_t >= 14.0:
		_at_flags["age_up_busy_sent"] = true
		_send_tagged("age_up_busy")
		controller.start_age_up() # thành đang nghiên cứu Đời 2 -> BUSY
	if not bool(_at_flags.get("upgrade_farm_sent", false)) and _at_t >= 30.0:
		var farm := _my_building_ghost("farm")
		if farm != null:
			_at_flags["upgrade_farm_sent"] = true
			_send_tagged("upgrade_farm")
			controller.start_building_upgrade(farm.net_id) # ruộng -> NOT_UPGRADEABLE
	if not bool(_at_flags.get("research_gate_sent", false)) and _at_t >= 40.0:
		var bar := _my_building_ghost("barracks")
		if bar != null:
			_at_flags["research_gate_sent"] = true
			_send_tagged("research_gate")
			controller.start_unit_research(bar.net_id, "warrior") # Đời 1 -> AGE_GATE
	if not bool(_at_flags.get("research_sent", false)) and _at_t >= 78.0:
		_at_flags["research_sent"] = true
		_send_tagged("research")
		controller.start_unit_research(slot + 1, "pawn") # Đời 2 đã xong (~t=72)
	if not bool(_at_flags.get("upgrade_sent", false)) and _at_t >= 84.0:
		var house := _my_building_ghost("house")
		if house != null:
			_at_flags["upgrade_sent"] = true
			_send_tagged("upgrade")
			controller.start_building_upgrade(house.net_id)
	var my_units := world.own_military_ids()
	if not my_units.is_empty():
		_at_flags["warrior_seen"] = true
		if not bool(_at_flags.get("move_sent", false)):
			_at_flags["move_sent"] = true
			_send_tagged("move")
			controller.set_selection([int(my_units[0])])
			controller.order_selected_move(Vector2(960, 480), false)
	# Chuỗi lệnh RTS: move xong -> attack-move -> tuần tra -> hộ vệ thành.
	# Điểm đích lấy gần nhà (hướng tâm map 160px) để quân mẫu không đi xa
	# vào vùng nguy hiểm giữa lúc đang kiểm chứng đường lệnh.
	var home := _my_castle_ghost()
	var toward := Vector2(760, 480)
	if home != null:
		toward = home.render + (Vector2(960, 480) - home.render).normalized() * 160.0
	if bool(_at_flags.get("move_ok", false)) and not bool(_at_flags.get("am_sent", false)):
		_at_flags["am_sent"] = true
		_send_tagged("attack_move")
		controller.set_selection([int(my_units[0])])
		controller.order_selected_attack_move(toward)
	if bool(_at_flags.get("attack_move_ok", false)) and not bool(_at_flags.get("patrol_sent", false)):
		_at_flags["patrol_sent"] = true
		_send_tagged("patrol")
		controller.set_selection([int(my_units[0])])
		controller.order_selected_patrol(toward)
	if bool(_at_flags.get("patrol_ok", false)) and not bool(_at_flags.get("guard_sent", false)):
		_at_flags["guard_sent"] = true
		_send_tagged("guard")
		controller.set_selection([int(my_units[0])])
		controller.order_selected_guard(slot + 1)
	if not bool(_at_flags.get("shot_match", false)) and _at_t >= 8.0:
		_at_flags["shot_match"] = true
		_take_shot_deferred("net_match_A.png")

func _at_tick_b() -> void:
	if _expect_reclaim:
		# Vòng nối lại: chỉ cần reclaim + resync + 1 lệnh được chấp nhận.
		if bool(_at_flags.get("reclaim", false)) and bool(_at_flags.get("resync", false)) and not bool(_at_flags.get("post_sent", false)):
			_at_flags["post_sent"] = true
			_send_tagged("post_alloc")
			controller.set_villager_allocation(1, 1, 1, 1)
		if bool(_at_flags.get("post_reconnect_cmd", false)) and not _at_reported:
			_at_finish_report()
			_quit_in = 1.5
		return
	if not bool(_at_flags.get("train_sent", false)) and _at_t >= 1.0:
		_at_flags["train_sent"] = true
		_send_tagged("train")
		controller.queue_training(slot + 1, "warrior")
	var enemy := _enemy_human_slot()
	var my_units := world.own_military_ids()
	if enemy >= 0 and not my_units.is_empty() and not bool(_at_flags.get("fog_sent", false)):
		_at_flags["fog_sent"] = true
		_send_tagged("fog_attack")
		controller.set_selection([int(my_units[0])])
		controller.set_stance("attack", enemy) # thành địch CHƯA lộ diện -> phải bị FOG
	if bool(_at_flags.get("fog_reject", false)) and not bool(_at_flags.get("scout_sent", false)):
		_at_flags["scout_sent"] = true
		var castles: Dictionary = _match_info.get("castles", {})
		if castles.has(enemy):
			var ec: Array = castles[enemy]
			var epos := Vector2(float(ec[0]), float(ec[1]))
			var mine := _my_castle_ghost()
			if mine != null:
				# Tiếp cận từ PHÍA SƯỜN (ngang thành, lệch về mép map):
				# điểm đứng cách tâm thành ~155px — vừa trong tầm nhìn
				# 165 của kiếm sĩ để lộ thành, vừa tránh hành lang tuần
				# tra của quân A trước cửa thành nó (kịch bản cũ đi thẳng
				# từ hướng nhà mình, lính trinh sát bị quân A + tu sĩ
				# chặn giết trước khi kịp lộ thành).
				var side := -150.0 if epos.x < 960.0 else 150.0
				controller.order_move(epos + Vector2(side, 40.0))
				_logline("AUTOTEST_SCOUT_SENT")
	var ec_ghost := world.ghost(enemy + 1) if enemy >= 0 else null
	if ec_ghost != null and bool(_at_flags.get("scout_sent", false)) and not bool(_at_flags.get("castle_sent", false)):
		_at_flags["castle_sent"] = true
		_send_tagged("castle_attack")
		controller.set_stance("attack", enemy) # ĐÃ lộ diện -> phải được chấp nhận
		_logline("AUTOTEST_CASTLE_ATTACK_SENT")
	if not bool(_at_flags.get("shot_match", false)) and _at_t >= 20.0:
		_at_flags["shot_match"] = true
		_take_shot_deferred("net_match_B.png")

func _at_finish_report() -> void:
	if _at_reported:
		return
	_at_reported = true
	var lines: Array = []
	lines.append("ROLE %s" % _autotest)
	lines.append("SLOT %d" % slot)
	for k in _at_flags.keys():
		lines.append("FLAG %s %s" % [k, str(_at_flags[k])])
	lines.append("FOG_VIOLATIONS %d" % fog_violations)
	lines.append("FOG_CHECKS %d" % fog_checks)
	for l in _log:
		lines.append(l)
	print("AUTOTEST_REPORT role=", _autotest, " flags=", _at_flags, " fog_violations=", fog_violations)
	if _netlog_path == "":
		return
	var f := FileAccess.open(_netlog_path, FileAccess.WRITE)
	if f == null:
		return
	for line in lines:
		f.store_line(line)
	f.close()

func _take_shot_deferred(file_name: String) -> void:
	if _shotdir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		DirAccess.make_dir_recursive_absolute(_shotdir)
		img.save_png(_shotdir.path_join(file_name))
		_logline("SHOT %s" % file_name)
