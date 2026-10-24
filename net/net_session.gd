class_name NetSession
extends Node

## NetSession — hub RPC của chế độ LAN, là node con của Main với CÙNG TÊN
## trên mọi peer ("Main/NetSession") nên mọi hàm @rpc dưới đây tới đúng nơi.
## Node này không chứa logic: nó uỷ cho NetServer (khi Main.net_role ==
## "server") hoặc NetClient (khi == "client"). Hình dạng này mang nguyên từ
## hub của prototype (netproto/scripts/main.gd) — xem INTEGRATION.md mục 1.4.
##
## Chỉ được Main tạo khi net_role != "" — chơi đơn không có node này, không
## tốn gì cả.

const ServerScript := preload("res://net/net_server.gd")
const ClientScript := preload("res://net/net_client.gd")

var game: Node = null # Main
var role: String = ""
var logic: Node = null # NetServer hoặc NetClient

func _ready() -> void:
	game = get_parent()
	role = String(game.net_role)
	if role == "server":
		logic = ServerScript.new()
		logic.name = "NetServer"
		add_child(logic)
		logic.start(self, game)
	elif role == "client":
		logic = ClientScript.new()
		logic.name = "NetClient"
		add_child(logic)
		logic.start(self, game)

func is_server() -> bool:
	return role == "server"

# ---------- RPC: client -> server (any_peer, server là peer 1) ----------

@rpc("any_peer", "call_remote", "reliable")
func submit_hello(p_name: String, token: int, version: int) -> void:
	if is_server() and logic != null:
		logic.handle_hello(multiplayer.get_remote_sender_id(), p_name, token, version)

@rpc("any_peer", "call_remote", "reliable")
func submit_ready() -> void:
	if is_server() and logic != null:
		logic.handle_ready(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func submit_lobby_action(action: Dictionary) -> void:
	if is_server() and logic != null:
		logic.handle_lobby_action(multiplayer.get_remote_sender_id(), action)

@rpc("any_peer", "call_remote", "reliable")
func submit_command(cmd: Dictionary) -> void:
	if is_server() and logic != null:
		logic.handle_command(multiplayer.get_remote_sender_id(), cmd)

# ---------- RPC: server -> client (authority) ----------

@rpc("authority", "call_remote", "reliable")
func welcome(data: Dictionary) -> void:
	if not is_server() and logic != null:
		logic.handle_welcome(data)

@rpc("authority", "call_remote", "reliable")
func lobby_update(state: Dictionary) -> void:
	if not is_server() and logic != null:
		logic.handle_lobby(state)

@rpc("authority", "call_remote", "reliable")
func match_started(data: Dictionary) -> void:
	if not is_server() and logic != null:
		logic.handle_match_started(data)

@rpc("authority", "call_remote", "reliable")
func apply_snapshot(msg: Dictionary) -> void:
	if not is_server() and logic != null:
		logic.handle_snapshot(msg)

@rpc("authority", "call_remote", "reliable")
func sync_explored(data: PackedByteArray) -> void:
	if not is_server() and logic != null:
		logic.handle_explored(data)

@rpc("authority", "call_remote", "reliable")
func command_result(res: Dictionary) -> void:
	if not is_server() and logic != null:
		logic.handle_result(res)

@rpc("authority", "call_remote", "reliable")
func match_ended(data: Dictionary) -> void:
	if not is_server() and logic != null:
		logic.handle_match_ended(data)
