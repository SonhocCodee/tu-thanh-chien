class_name NetServer
extends Node

## NetServer — phía CHỦ NHÀ (chạy trong tiến trình server của game thật).
## Vai trò (mang khung từ prototype netproto/scripts/server.gd, thay SimWorld
## bằng Main THẬT):
## - Phòng chờ: slot 0..3, token nối lại trong hạn grace 60s, chủ phòng =
##   người kết nối đầu tiên, slot trống khi bắt đầu trận -> bot lấp (đúng
##   thiết kế NET_DESIGN.md mục 3: bot là nguồn lệnh cắm vào PlayerController).
## - Cổng lệnh: mọi lệnh mạng đều dịch net_id -> node rồi chạy qua
##   PlayerController của slot người gửi — KHÔNG chọc thẳng vào Main. Mã lý
##   do từ chối được suy từ chính các hàm luật của game (sương mù/tài
##   nguyên/giới hạn) để client báo đúng cho người chơi.
## - Snapshot 10 Hz LỌC SƯƠNG MÙ theo từng người nhận + KIỂM TOÁN tại nguồn:
##   mọi upsert địch đều đối chiếu lại lưới sương mù của người nhận ngay khi
##   đóng gói; vi phạm (nếu có) bị đếm + ghi log — bằng chứng tầng dữ liệu.
## Server cũng phục vụ HTTP tĩnh (NetHttpServer) cho gói chủ nhà.

var session: Node = null
var game: Node = null # Main
var peer: WebSocketMultiplayerPeer = null
var http: NetHttpServer = null

var port: int = NetProtocol.PORT
var duration_sec: float = 0.0 # >0: trận tự kết thúc sau ngần này giây (test)
var netlog_path: String = ""
var _log_file: FileAccess = null

var slots: Dictionary = {} # slot -> {peer,name,token,ready,connected,gone_at,is_host,bot}
var peer_slot: Dictionary = {} # peer_id -> slot
var match_running: bool = false
var _tick: int = 0
var _snap_acc: float = 0.0
var _sweep_acc: float = 0.0
var _end_sent: bool = false
var _quit_in: float = -1.0
var _rng := RandomNumberGenerator.new()

# Trạng thái đồng bộ theo từng người nhận:
var _last_sent: Dictionary = {} # slot -> {net_id: true}
var _struct_seen: Dictionary = {} # slot -> {net_id: {hp,destroyed,constructed}}
var _explored_sent: Dictionary = {} # slot -> PackedByteArray đã gửi
var _snap_count: Dictionary = {} # slot -> số snapshot đã gửi
var _audit_checked: int = 0
var _audit_violations: int = 0

# Node tài nguyên phải theo dõi bằng THAM CHIẾU GIỮ LÂU: cây cạn rời group
# "res_nodes" nhưng object còn sống dạng gốc và sẽ mọc lại — quét group mỗi
# tick sẽ làm mất gốc cây khỏi snapshot. Các loại thực thể khác quét group
# trực tiếp là đủ (chết = rời khỏi tập "còn sống" -> removal tự sinh).
var _node_watch: Dictionary = {} # instance_id -> ResourceNode

func start(p_session: Node, p_game: Node) -> void:
	session = p_session
	game = p_game
	_rng.randomize()
	var params: Dictionary = game.net_params
	port = int(params.get("port", str(NetProtocol.PORT)))
	duration_sec = float(params.get("duration", "0"))
	netlog_path = String(params.get("netlog", ""))
	if netlog_path != "":
		_log_file = FileAccess.open(netlog_path, FileAccess.WRITE)
	peer = WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port, "*")
	if err != OK:
		push_error("NET_SERVER: create_server port %d that bai: %s" % [port, err])
		_logline("SERVER_FAIL err=%s" % err)
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_logline("SERVER_UP port=%d" % port)
	print("NET_SERVER_UP port=", port)
	# HTTP tĩnh cho gói chủ nhà (bỏ qua nếu không có thư mục web).
	var webroot := String(params.get("webroot", ""))
	if webroot == "":
		webroot = OS.get_executable_path().get_base_dir().path_join("web")
	http = NetHttpServer.new()
	http.name = "NetHttp"
	add_child(http)
	if http.start_server(int(params.get("httpport", str(NetProtocol.HTTP_PORT))), webroot):
		_logline("HTTP_UP root=%s" % webroot)

func _logline(s: String) -> void:
	if _log_file != null:
		_log_file.store_line(s)
		_log_file.flush()

# ============================ KẾT NỐI / PHÒNG CHỜ ============================

func _on_peer_connected(peer_id: int) -> void:
	_logline("PEER_CONNECTED peer=%d" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_logline("PEER_DISCONNECTED peer=%d" % peer_id)
	if peer_slot.has(peer_id):
		var slot := int(peer_slot[peer_id])
		peer_slot.erase(peer_id)
		if slots.has(slot):
			slots[slot]["connected"] = false
			slots[slot]["peer"] = 0
			slots[slot]["gone_at"] = Time.get_unix_time_from_system()
		_broadcast_lobby()

func handle_hello(peer_id: int, p_name: String, token: int, version: int) -> void:
	if version != NetProtocol.PROTOCOL_VERSION:
		session.rpc_id(peer_id, "welcome", {"slot": -2, "token": 0, "reclaimed": false, "is_host": false,
			"reason": "VERSION", "server_version": NetProtocol.PROTOCOL_VERSION})
		_logline("HELLO_VERSION_REJECT peer=%d ver=%d" % [peer_id, version])
		return
	if peer_slot.has(peer_id):
		var cur := int(peer_slot[peer_id])
		session.rpc_id(peer_id, "welcome", {"slot": cur, "token": int(slots[cur]["token"]), "reclaimed": false,
			"is_host": bool(slots[cur]["is_host"])})
		return
	# Nối lại bằng token: slot đã mất kết nối, còn trong hạn grace.
	if token != 0:
		for slot in slots.keys():
			var s: Dictionary = slots[slot]
			if int(s["token"]) == token and not bool(s["connected"]):
				if Time.get_unix_time_from_system() - float(s["gone_at"]) <= NetProtocol.RECONNECT_GRACE_SEC:
					s["peer"] = peer_id
					s["connected"] = true
					slots[slot] = s
					peer_slot[peer_id] = slot
					# Đồng bộ lại từ đầu cho người vừa quay lại: snapshot đầy đủ
					# + lưới explored của chính họ (NET_DESIGN.md mục 7).
					_last_sent.erase(slot)
					_struct_seen.erase(slot)
					_explored_sent.erase(slot)
					session.rpc_id(peer_id, "welcome", {"slot": slot, "token": token, "reclaimed": true,
						"is_host": bool(s["is_host"])})
					_logline("HELLO_RECLAIM peer=%d slot=%d name=%s" % [peer_id, slot, p_name])
					if match_running:
						session.rpc_id(peer_id, "match_started", _match_started_payload())
					_broadcast_lobby()
					return
	if match_running:
		session.rpc_id(peer_id, "welcome", {"slot": -1, "token": 0, "reclaimed": false, "is_host": false, "reason": "IN_MATCH"})
		_logline("HELLO_LATE_REJECT peer=%d" % peer_id)
		return
	# Slot mới: trống thấp nhất. Chủ phòng = người đầu tiên khi chưa có chủ.
	for slot in range(4):
		if not slots.has(slot):
			var new_token := _rng.randi_range(100000, 999999999)
			var has_host := false
			for s2 in slots.values():
				if bool((s2 as Dictionary)["is_host"]):
					has_host = true
			slots[slot] = {"peer": peer_id, "name": p_name, "token": new_token, "ready": false,
				"connected": true, "gone_at": 0.0, "is_host": not has_host, "bot": false}
			peer_slot[peer_id] = slot
			session.rpc_id(peer_id, "welcome", {"slot": slot, "token": new_token, "reclaimed": false,
				"is_host": not has_host})
			_logline("HELLO peer=%d slot=%d name=%s host=%s" % [peer_id, slot, p_name, str(not has_host)])
			_broadcast_lobby()
			return
	session.rpc_id(peer_id, "welcome", {"slot": -1, "token": 0, "reclaimed": false, "is_host": false, "reason": "FULL"})
	_logline("HELLO_FULL peer=%d" % peer_id)

func handle_ready(peer_id: int) -> void:
	if not peer_slot.has(peer_id):
		return
	var slot := int(peer_slot[peer_id])
	slots[slot]["ready"] = true
	_logline("READY slot=%d" % slot)
	_broadcast_lobby()

func handle_lobby_action(peer_id: int, action: Dictionary) -> void:
	if not peer_slot.has(peer_id):
		return
	var slot := int(peer_slot[peer_id])
	if not bool(slots[slot].get("is_host", false)):
		return # chỉ chủ phòng mới có quyền ở phòng chờ
	match String(action.get("action", "")):
		"start":
			_try_start(peer_id)

func _lobby_state() -> Dictionary:
	var view := {}
	for slot in range(4):
		if slots.has(slot):
			var s: Dictionary = slots[slot]
			view[slot] = {"name": String(s["name"]), "kind": "human", "ready": bool(s["ready"]),
				"connected": bool(s["connected"]), "is_host": bool(s["is_host"])}
		else:
			view[slot] = {"name": "", "kind": "bot", "ready": true, "connected": false, "is_host": false}
	return {"slots": view, "match_running": match_running}

func _broadcast_lobby() -> void:
	session.rpc("lobby_update", _lobby_state())

func _match_started_payload() -> Dictionary:
	var infos: Array = []
	for slot in range(4):
		var kind := "bot"
		var nm := String(Stats.PLAYERS[slot]["name"])
		if slots.has(slot):
			kind = "human"
			nm = String(slots[slot]["name"])
		infos.append({"slot": slot, "name": nm, "kind": kind})
	var castles := {}
	for pid in range(4):
		var cp: Vector2 = game.CASTLE_POS[pid]
		castles[pid] = [cp.x, cp.y]
	return {"slots": infos, "castles": castles, "world": [game.WORLD.x, game.WORLD.y]}

func _try_start(host_peer: int) -> void:
	if match_running:
		return
	for slot in slots.keys():
		var s: Dictionary = slots[slot]
		if bool(s["connected"]) and not bool(s["ready"]):
			session.rpc_id(host_peer, "command_result", {"ok": false, "reason": "NOT_READY", "op": "start"})
			_logline("START_REJECT reason=NOT_READY slot=%d" % slot)
			return
	_start_match()

func _start_match() -> void:
	# Slot trống hẳn -> bot lấp ngay (bot là nguồn lệnh qua PlayerController).
	# Slot CÓ người nhưng đang rớt mạng: giữ phe thụ động chờ nối lại trong
	# hạn grace — quá hạn _grace_sweep mới chuyển bot tiếp quản (tránh 2 nguồn
	# lệnh cùng điều khiển 1 phe khi người đó quay lại).
	var bot_pids: Array = []
	for slot in range(4):
		if not slots.has(slot):
			bot_pids.append(slot)
	game.spawn_bots_for(bot_pids)
	match_running = true
	_tick = 0
	_snap_acc = 0.0
	_last_sent.clear()
	_struct_seen.clear()
	_explored_sent.clear()
	game.match_over = false # thả cổng giữ trận (Main giữ sim đứng yên từ lúc boot)
	session.rpc("match_started", _match_started_payload())
	_logline("MATCH_START bots=%s" % str(bot_pids))
	print("NET_MATCH_START bots=", bot_pids)
	_broadcast_lobby()

# ============================ CỔNG LỆNH ============================
# Mọi lệnh: tra peer -> slot -> PlayerController của slot đó -> exec_* của
# Main như bot/hotseat. Mã lý do suy từ chính luật game trước khi gọi, để
# hồi báo cho client đúng nguyên nhân (FOG/NO_RESOURCES/CAP/...).

func handle_command(peer_id: int, cmd: Dictionary) -> void:
	if not peer_slot.has(peer_id):
		return
	var slot := int(peer_slot[peer_id])
	var op := String(cmd.get("cmd", ""))
	var ok := false
	var reason := ""
	if not match_running:
		reason = NetProtocol.R_NOT_IN_MATCH
	else:
		var player: PlayerState = game.players[slot]
		var ctrl: PlayerController = game.controllers[slot]
		if not player.alive:
			reason = NetProtocol.R_DEAD
		else:
			match op:
				"alloc":
					ok = ctrl.set_villager_allocation(int(cmd.get("w", 0)), int(cmd.get("s", 0)), int(cmd.get("g", 0)), int(cmd.get("m", 0)))
					if not ok:
						reason = NetProtocol.R_REJECTED
				"build":
					reason = _cmd_build(player, ctrl, cmd)
					ok = reason == ""
				"train":
					reason = _cmd_train(player, ctrl, cmd, slot)
					ok = reason == ""
				"stance":
					reason = _cmd_stance(player, ctrl, cmd, slot)
					ok = reason == ""
				"order_move":
					var pt := _pt(cmd.get("point", [0, 0]))
					if not _in_world(pt):
						reason = NetProtocol.R_BOUNDS
					else:
						ok = ctrl.order_move(pt)
						if not ok:
							reason = NetProtocol.R_REJECTED
				"move":
					reason = _cmd_move(ctrl, cmd, slot)
					ok = reason == ""
				"farm":
					reason = _cmd_farm(ctrl, cmd, slot)
					ok = reason == ""
				"attack":
					reason = _cmd_attack(ctrl, cmd, slot)
					ok = reason == ""
				_:
					reason = NetProtocol.R_UNKNOWN_CMD
	_logline("CMD slot=%d op=%s result=%s reason=%s" % [slot, op, "ACCEPT" if ok else "REJECT", reason])
	session.rpc_id(peer_id, "command_result", {"ok": ok, "reason": reason, "op": op})

func _pt(v: Variant) -> Vector2:
	var a: Array = v
	if a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO

func _in_world(p: Vector2) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 and p.x <= game.WORLD.x and p.y <= game.WORLD.y

func _cmd_build(player: PlayerState, ctrl: PlayerController, cmd: Dictionary) -> String:
	var btype := String(cmd.get("type", ""))
	if not Stats.BUILDINGS.has(btype):
		return NetProtocol.R_NO_TARGET
	var pos := _pt(cmd.get("pos", [0, 0]))
	if not _in_world(pos):
		return NetProtocol.R_BOUNDS
	if not player.can_afford(Stats.BUILDINGS[btype]["cost"]):
		return NetProtocol.R_NO_RESOURCES
	if not game.can_place_building(player, btype, pos):
		return NetProtocol.R_PLACEMENT
	return "" if ctrl.place_building(btype, pos) else NetProtocol.R_REJECTED

func _cmd_train(player: PlayerState, ctrl: PlayerController, cmd: Dictionary, slot: int) -> String:
	var node: Node = game.node_by_net_id(int(cmd.get("building", -1)))
	if node == null or not (node is Structure):
		return NetProtocol.R_NO_TARGET
	var st := node as Structure
	if st.owner_pid != slot:
		return NetProtocol.R_NOT_OWNER
	if not st.can_produce():
		return NetProtocol.R_NO_TARGET
	var unit_type := String(cmd.get("unit", ""))
	var prod: Dictionary = Stats.PRODUCERS[st.producer_kind]
	if not (prod["units"] as Array).has(unit_type):
		return NetProtocol.R_NO_TARGET
	if not player.can_afford(Stats.TRAINING[unit_type]["cost"]):
		return NetProtocol.R_NO_RESOURCES
	if game.cap_block_reason(slot, unit_type) != "":
		return NetProtocol.R_CAP
	return "" if ctrl.queue_training(st, unit_type) else NetProtocol.R_REJECTED

func _cmd_stance(player: PlayerState, ctrl: PlayerController, cmd: Dictionary, slot: int) -> String:
	var stance := String(cmd.get("stance", ""))
	if stance == "hold":
		return "" if ctrl.set_stance("hold") else NetProtocol.R_REJECTED
	if stance == "attack":
		var target := int(cmd.get("target", -1))
		if target < 0 or target >= 4 or target == slot or not (game.players[target] as PlayerState).alive:
			return NetProtocol.R_NO_TARGET
		# Luật sương mù gốc của PlayerController.set_stance: chỉ tấn công
		# đích danh thành ĐÃ LỘ DIỆN với phe mình.
		if not game.is_castle_revealed_for(slot, target):
			return NetProtocol.R_FOG
		return "" if ctrl.set_stance("attack", target) else NetProtocol.R_REJECTED
	return NetProtocol.R_UNKNOWN_CMD

## Kiểm tra 1 danh sách net_id quân/dân: tồn tại + đúng chủ + còn sống.
## Trả "" nếu ổn, ngược lại mã lý do. nodes = mảng node đã dịch (out qua return phụ).
func _validate_units(slot: int, ids: Array) -> Array:
	# return [reason, nodes]
	if ids.is_empty():
		return [NetProtocol.R_NO_UNITS, []]
	var nodes: Array = []
	for v in ids:
		var node: Node = game.node_by_net_id(int(v))
		if node == null or not (node is Unit or node is Villager):
			return [NetProtocol.R_NO_TARGET, []]
		if (node is Unit and (node as Unit).owner_pid != slot) or (node is Villager and (node as Villager).owner_pid != slot):
			return [NetProtocol.R_NOT_OWNER, []]
		if node is Unit and not (node as Unit).is_alive():
			return [NetProtocol.R_DEAD, []]
		if node is Villager and not (node as Villager).is_alive():
			return [NetProtocol.R_DEAD, []]
		nodes.append(node)
	return ["", nodes]

func _cmd_move(ctrl: PlayerController, cmd: Dictionary, slot: int) -> String:
	var chk := _validate_units(slot, cmd.get("units", []))
	if String(chk[0]) != "":
		return String(chk[0])
	var pt := _pt(cmd.get("point", [0, 0]))
	if not _in_world(pt):
		return NetProtocol.R_BOUNDS
	ctrl.set_selection(chk[1])
	var n := ctrl.order_selected_move(pt, bool(cmd.get("villagers", true)))
	return "" if n > 0 else NetProtocol.R_REJECTED

func _cmd_farm(ctrl: PlayerController, cmd: Dictionary, slot: int) -> String:
	var chk := _validate_units(slot, cmd.get("units", []))
	if String(chk[0]) != "":
		return String(chk[0])
	var node: Node = game.node_by_net_id(int(cmd.get("node", -1)))
	if node == null or not (node is ResourceNode or node is Sheep):
		return NetProtocol.R_NO_TARGET
	var n2d := node as Node2D
	# Luật sương mù của exec_direct_farm: chỉ farm mục tiêu ở vùng ĐÃ KHÁM PHÁ.
	if not game.is_pos_explored_for(slot, n2d.global_position):
		return NetProtocol.R_FOG
	if node is Sheep and not (node as Sheep).alive:
		return NetProtocol.R_TARGET_DEAD
	if node is ResourceNode and (node as ResourceNode).is_depleted():
		return NetProtocol.R_TARGET_DEAD
	ctrl.set_selection(chk[1])
	var n := ctrl.order_selected_farm(n2d)
	return "" if n > 0 else NetProtocol.R_REJECTED

func _cmd_attack(ctrl: PlayerController, cmd: Dictionary, slot: int) -> String:
	var chk := _validate_units(slot, cmd.get("units", []))
	if String(chk[0]) != "":
		return String(chk[0])
	var target: Node = game.node_by_net_id(int(cmd.get("target", -1)))
	if target == null or not (target is Unit or target is Structure):
		return NetProtocol.R_NO_TARGET
	# Luật sương mù cho tấn công trực tiếp — cùng luật exec_direct_attack:
	# quân địch phải đang SÁNG; thành địch phải đã lộ diện; nhà địch phải đã
	# khám phá vị trí.
	var fog: FogOfWar = game.fogs[slot]
	if target is Unit:
		var tu := target as Unit
		if tu.owner_pid == slot:
			return NetProtocol.R_OWN_TARGET
		if not tu.is_alive():
			return NetProtocol.R_TARGET_DEAD
		if not fog.is_visible_pos(tu.global_position):
			return NetProtocol.R_FOG
	else:
		var ts := target as Structure
		if ts.owner_pid == slot:
			return NetProtocol.R_OWN_TARGET
		if not ts.is_alive():
			return NetProtocol.R_TARGET_DEAD
		if ts is Castle:
			if not game.is_castle_revealed_for(slot, ts.owner_pid):
				return NetProtocol.R_FOG
		elif not game.is_pos_explored_for(slot, ts.global_position):
			return NetProtocol.R_FOG
	ctrl.set_selection(chk[1])
	return "" if ctrl.order_selected_attack(target) else NetProtocol.R_REJECTED

# ============================ SNAPSHOT LỌC SƯƠNG MÙ ============================
# Hình dạng upsert (mảng cố định 12 trường):
# [net_id, owner, kind, sub, x, y, hp, max_hp, flags, extra_s, extra_f, extra_i]
#   kind: "unit" | "villager" | "castle" | "building" | "node" | "sheep"
#   sub: unit_type / building_type / res_type / ""
#   extra_s: villager = loại đang vác ("" nếu tay không)
#   extra_f: node = tỉ lệ trữ lượng còn; building = tiến độ xây (1 = xong)
#   extra_i: villager = số đang vác; node = variant sprite

func _physics_process(delta: float) -> void:
	if _quit_in >= 0.0:
		_quit_in -= delta
		if _quit_in <= 0.0:
			get_tree().quit()
		return
	if not match_running:
		return
	_tick += 1
	_snap_acc += delta
	var interval := 1.0 / NetProtocol.SNAPSHOT_HZ
	if _snap_acc >= interval:
		_snap_acc = fmod(_snap_acc, interval)
		for slot in slots.keys():
			if bool(slots[slot]["connected"]):
				_send_snapshot(int(slot))

func _collect_entities() -> Array:
	# [node, kind] cho mọi thực thể đang sống trong thế giới thật.
	var out: Array = []
	for n in get_tree().get_nodes_in_group("structures"):
		var s := n as Structure
		if s != null:
			out.append([s, "castle" if s is Castle else "building"])
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u != null and u.is_alive():
			out.append([u, "unit"])
	for n in get_tree().get_nodes_in_group("villagers"):
		var v := n as Villager
		if v != null and v.is_alive():
			out.append([v, "villager"])
	for n in get_tree().get_nodes_in_group("sheep"):
		var sh := n as Sheep
		if sh != null and sh.alive:
			out.append([sh, "sheep"])
	# Node tài nguyên: quét group để ĐĂNG KÝ MỚI (xác cừu sinh giữa trận),
	# rồi duyệt sổ theo dõi (gốc cây đã rời group vẫn nằm trong sổ).
	for n in get_tree().get_nodes_in_group("res_nodes"):
		_node_watch[n.get_instance_id()] = n
	var dead_keys: Array = []
	for key in _node_watch.keys():
		var rn: ResourceNode = _node_watch[key]
		if rn == null or not is_instance_valid(rn):
			dead_keys.append(key)
		else:
			out.append([rn, "node"])
	for key in dead_keys:
		_node_watch.erase(key)
	return out

func _entity_record(node: Node, kind: String, dim: bool, frozen: Dictionary) -> Array:
	var owner := -1
	var sub := ""
	var hp := 0.0
	var max_hp := 0.0
	var flags := 0
	var extra_s := ""
	var extra_f := 0.0
	var extra_i := 0
	var pos: Vector2 = (node as Node2D).global_position
	if dim:
		hp = float(frozen.get("hp", 0.0))
		if bool(frozen.get("destroyed", false)):
			flags |= NetProtocol.F_DESTROYED
		if bool(frozen.get("constructed", false)):
			flags |= NetProtocol.F_CONSTRUCTED
		flags |= NetProtocol.F_DIM
	match kind:
		"castle":
			var c := node as Castle
			owner = c.owner_pid
			if not dim:
				hp = c.hp
				max_hp = c.max_hp
				if c.destroyed:
					flags |= NetProtocol.F_DESTROYED
				flags |= NetProtocol.F_CONSTRUCTED
			else:
				max_hp = c.max_hp
		"building":
			var b := node as Building
			owner = b.owner_pid
			sub = b.building_type
			if not dim:
				hp = b.hp
				max_hp = b.max_hp
				if b.destroyed:
					flags |= NetProtocol.F_DESTROYED
				if b.constructed:
					flags |= NetProtocol.F_CONSTRUCTED
				extra_f = 1.0 - clampf(b.build_left / b.build_total, 0.0, 1.0) if b.build_total > 0.0 else 1.0
			else:
				max_hp = b.max_hp
		"unit":
			var u := node as Unit
			owner = u.owner_pid
			sub = u.unit_type
			hp = u.hp
			max_hp = u.max_hp
		"villager":
			var v := node as Villager
			owner = v.owner_pid
			sub = "pawn"
			hp = v.hp
			max_hp = v.max_hp
			extra_s = v.carrying_type
			extra_i = v.carrying
		"sheep":
			var sh := node as Sheep
			hp = sh.hp
			max_hp = sh.max_hp
		"node":
			var rn := node as ResourceNode
			sub = rn.res_type
			if rn.is_big:
				flags |= NetProtocol.F_BIG
			if rn.is_stump():
				flags |= NetProtocol.F_STUMP
			if rn.is_depleted():
				flags |= NetProtocol.F_DEPLETED
			extra_f = rn.remaining_fraction()
			extra_i = rn.variant
	return [game.net_id_of(node), owner, kind, sub, pos.x, pos.y, hp, max_hp, flags, extra_s, extra_f, extra_i]

func _audit(viewer: int, kind: String, owner: int, pos: Vector2, dim: bool, fog: FogOfWar) -> void:
	# Đối chiếu 1 upsert ĐÃ ĐÓNG GÓI với lưới sương mù của người nhận.
	# Đếm để báo cáo/bài kiểm chứng đọc — vi phạm phải luôn = 0.
	if owner == viewer or owner == -1 and kind == "node":
		# Của mình: luôn hợp lệ. Node trung lập: phải đã khám phá.
		if kind == "node":
			_audit_checked += 1
			if not fog.is_explored_pos(pos):
				_audit_violations += 1
		return
	if kind == "node":
		_audit_checked += 1
		if not fog.is_explored_pos(pos):
			_audit_violations += 1
		return
	_audit_checked += 1
	if dim:
		if not fog.is_explored_pos(pos):
			_audit_violations += 1
	elif kind == "castle" or kind == "building":
		if fog.state_at(pos) != 2:
			_audit_violations += 1
	else:
		if not fog.is_visible_pos(pos):
			_audit_violations += 1

func _send_snapshot(slot: int) -> void:
	var fog: FogOfWar = game.fogs[slot]
	var upserts: Array = []
	var current: Dictionary = {}
	var entities := _collect_entities()
	if not _struct_seen.has(slot):
		_struct_seen[slot] = {}
	var seen: Dictionary = _struct_seen[slot]
	for pair in entities:
		var node: Node = pair[0]
		var kind := String(pair[1])
		var pos: Vector2 = (node as Node2D).global_position
		var owner := -1
		if node is Structure:
			owner = (node as Structure).owner_pid
		elif node is Unit:
			owner = (node as Unit).owner_pid
		elif node is Villager:
			owner = (node as Villager).owner_pid
		var id: int = game.net_id_of(node)
		if kind == "castle" or kind == "building":
			if owner == slot:
				upserts.append(_entity_record(node, kind, false, {}))
				current[id] = true
			else:
				var state := fog.state_at(pos)
				if state == 2:
					var rec := _entity_record(node, kind, false, {})
					upserts.append(rec)
					current[id] = true
					seen[id] = {"hp": (node as Structure).hp, "destroyed": (node as Structure).destroyed,
						"constructed": (node as Building).constructed if node is Building else true}
					_audit(slot, kind, owner, pos, false, fog)
				elif state == 1 and seen.has(id):
					upserts.append(_entity_record(node, kind, true, seen[id]))
					current[id] = true
					_audit(slot, kind, owner, pos, true, fog)
		elif kind == "node":
			if fog.is_explored_pos(pos):
				upserts.append(_entity_record(node, kind, false, {}))
				current[id] = true
				_audit(slot, kind, -1, pos, false, fog)
		elif kind == "sheep":
			if fog.is_visible_pos(pos):
				upserts.append(_entity_record(node, kind, false, {}))
				current[id] = true
				_audit(slot, kind, -1, pos, false, fog)
		else: # unit / villager
			if owner == slot:
				upserts.append(_entity_record(node, kind, false, {}))
				current[id] = true
			elif fog.is_visible_pos(pos):
				upserts.append(_entity_record(node, kind, false, {}))
				current[id] = true
				_audit(slot, kind, owner, pos, false, fog)
	var removals: Array = []
	var prev: Dictionary = _last_sent.get(slot, {})
	for id in prev.keys():
		if not current.has(id):
			removals.append(id)
	_last_sent[slot] = current
	var msg := {"tick": _tick, "upserts": upserts, "removals": removals, "you": _player_state(slot)}
	session.rpc_id(int(slots[slot]["peer"]), "apply_snapshot", msg)
	# Đồng bộ lưới explored của chính người nhận (bitmap 60x30 = 1800 byte):
	# gửi khi thay đổi — nối lại cũng đi đường này (đã xoá bản đã gửi lúc reclaim).
	var explored: PackedByteArray = fog.explored
	if _explored_sent.get(slot, PackedByteArray()) != explored:
		_explored_sent[slot] = explored.duplicate()
		session.rpc_id(int(slots[slot]["peer"]), "sync_explored", explored)
	_snap_count[slot] = int(_snap_count.get(slot, 0)) + 1
	if int(_snap_count[slot]) % 50 == 0:
		_logline("SNAP slot=%d n=%d sent=%d audit_checked=%d audit_violations=%d" % [
			slot, int(_snap_count[slot]), upserts.size(), _audit_checked, _audit_violations])

func _player_state(slot: int) -> Dictionary:
	var player: PlayerState = game.players[slot]
	var queues := {}
	for n in get_tree().get_nodes_in_group("structures"):
		var s := n as Structure
		if s != null and s.owner_pid == slot and s.queue_count() > 0:
			queues[str(game.net_id_of(s))] = s.queue_count()
	return {
		"resources": player.resources.duplicate(),
		"allocation": player.allocation.duplicate(),
		"pop_used": game.pop_used(slot), "pop_cap": game.pop_cap(slot),
		"army_used": game.army_used(slot), "army_cap": game.army_cap(slot),
		"alive": player.alive, "stance": player.stance, "target_pid": player.target_pid,
		"villagers": game.villager_count(slot), "military": game.military_count(slot),
		"queues": queues, "elapsed": game.elapsed,
	}

# ============================ VÒNG ĐỜI / GRACE ============================

func _process(delta: float) -> void:
	_sweep_acc += delta
	if _sweep_acc >= 1.0:
		_sweep_acc = 0.0
		_grace_sweep()
	if not match_running or _end_sent:
		return
	if game.match_over:
		_finish_match("castle")
	elif duration_sec > 0.0 and game.elapsed >= duration_sec:
		game.match_over = true # dừng sim cho log cuối trận sạch (chế độ test)
		_finish_match("duration")

func _grace_sweep() -> void:
	var now := Time.get_unix_time_from_system()
	var changed := false
	for slot in slots.keys():
		var s: Dictionary = slots[slot]
		if bool(s["connected"]) or float(s["gone_at"]) <= 0.0:
			continue
		if now - float(s["gone_at"]) > NetProtocol.RECONNECT_GRACE_SEC:
			if match_running and not bool(s.get("bot", false)):
				# Quá hạn giữa trận: bot tiếp quản phe để trận không treo.
				s["bot"] = true
				slots[slot] = s
				game.spawn_bots_for([slot])
				_logline("SLOT_TO_BOT slot=%d" % slot)
				changed = true
			elif not match_running:
				slots.erase(slot)
				_logline("SLOT_FREED slot=%d" % slot)
				changed = true
	if changed:
		_broadcast_lobby()

func _finish_match(reason: String) -> void:
	_end_sent = true
	match_running = false
	var payload := {"winner": game.net_winner_pid, "reason": reason}
	for slot in slots.keys():
		if bool(slots[slot]["connected"]):
			session.rpc_id(int(slots[slot]["peer"]), "match_ended", payload)
	_logline("MATCH_END reason=%s winner=%d audit_checked=%d audit_violations=%d" % [
		reason, game.net_winner_pid, _audit_checked, _audit_violations])
	_logline("SUMMARY snapshots=%s" % str(_snap_count))
	print("NET_MATCH_END reason=", reason, " winner=", game.net_winner_pid,
		" audit_checked=", _audit_checked, " audit_violations=", _audit_violations)
	if netlog_path != "" and _log_file != null:
		_log_file.close()
		_log_file = null
	if duration_sec > 0.0:
		_quit_in = 3.0
