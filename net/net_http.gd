class_name NetHttpServer
extends Node

## Server HTTP tĩnh tối giản của GÓI CHỦ NHÀ: phục vụ thư mục bản web client
## ở cổng 8911 để bạn bè cùng LAN mở http://IP-CHU-NHA:8911/?lan=1 là vào
## chơi — KHÔNG cần cài thêm gì trên máy chủ nhà (NET_DESIGN.md mục 8).
## Việc phục vụ từ chính máy chủ nhà là BẮT BUỘC theo thiết kế: trang HTTPS
## bên ngoài (Pages/itch) bị mixed-content chặn khi nối ws:// tới IP LAN.
##
## Chỉ cài đúng mức cần: GET 1 file mỗi kết nối, HTTP/1.0, đóng kết nối ngay.
## Mọi file đều kèm "Cache-Control: no-store" — client luôn tươi từ gói chủ
## nhà, tránh lệch phiên bản vì cache trình duyệt (rủi ro R6, INTEGRATION).

const MIME := {
	"html": "text/html; charset=utf-8",
	"js": "application/javascript",
	"mjs": "application/javascript",
	"wasm": "application/wasm",
	"pck": "application/octet-stream",
	"png": "image/png",
	"jpg": "image/jpeg",
	"jpeg": "image/jpeg",
	"ico": "image/x-icon",
	"svg": "image/svg+xml",
	"json": "application/json",
	"css": "text/css",
	"txt": "text/plain; charset=utf-8",
}

var _tcp: TCPServer = null
var _root: String = ""
var _conns: Array = [] # [{peer: StreamPeerTCP, buf: PackedByteArray}]

## Trả true nếu nghe được cổng. web_root phải là đường dẫn TUYỆT ĐỐI tới thư
## mục chứa index.html của bản web (trong gói chủ nhà là thư mục web/ cạnh
## server). Thư mục không tồn tại -> không bật HTTP (game vẫn chạy).
func start_server(port: int, web_root: String) -> bool:
	_root = web_root
	if not DirAccess.dir_exists_absolute(_root):
		print("NET_HTTP: web root khong ton tai: ", _root, " — bo qua HTTP tinh")
		return false
	_tcp = TCPServer.new()
	var err := _tcp.listen(port, "*")
	if err != OK:
		push_warning("NET_HTTP: listen %d that bai: %s" % [port, err])
		_tcp = null
		return false
	print("NET_HTTP_UP port=", port, " root=", _root)
	return true

func _process(_delta: float) -> void:
	if _tcp == null:
		return
	while _tcp.is_connection_available():
		var peer := _tcp.take_connection()
		if peer != null:
			_conns.append({"peer": peer, "buf": PackedByteArray()})
	var done: Array = []
	for c in _conns:
		var peer: StreamPeerTCP = c["peer"]
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_ERROR or peer.get_status() == StreamPeerTCP.STATUS_NONE:
			done.append(c)
			continue
		var avail := peer.get_available_bytes()
		if avail > 0:
			var chunk := peer.get_data(avail)
			if chunk[0] == OK:
				var buf: PackedByteArray = c["buf"]
				buf.append_array(chunk[1])
				c["buf"] = buf
				if _find_header_end(buf) >= 0:
					_respond(peer, buf)
					done.append(c)
	for c in done:
		_conns.erase(c)

func _find_header_end(buf: PackedByteArray) -> int:
	# Tìm \r\n\r\n
	for i in range(maxi(0, buf.size() - 3)):
		if buf[i] == 13 and buf[i + 1] == 10 and buf[i + 2] == 13 and buf[i + 3] == 10:
			return i
	return -1

func _respond(peer: StreamPeerTCP, raw: PackedByteArray) -> void:
	var head := raw.slice(0, _find_header_end(raw)).get_string_from_utf8()
	var lines := head.split("\r\n")
	if lines.is_empty():
		peer.disconnect_from_host()
		return
	var parts := lines[0].split(" ")
	if parts.size() < 2 or parts[0] != "GET":
		_send(peer, 405, "text/plain", "Method Not Allowed".to_utf8_buffer())
		return
	var path := parts[1]
	var q := path.find("?")
	if q >= 0:
		path = path.substr(0, q)
	path = path.uri_decode()
	if path == "/" or path == "":
		path = "/index.html"
	# An toàn đường dẫn: cấm thoát khỏi web root.
	if path.contains(".."):
		_send(peer, 403, "text/plain", "Forbidden".to_utf8_buffer())
		return
	var full := _root.path_join(path.trim_prefix("/"))
	if not FileAccess.file_exists(full):
		_send(peer, 404, "text/plain", "Not Found".to_utf8_buffer())
		return
	var f := FileAccess.open(full, FileAccess.READ)
	if f == null:
		_send(peer, 404, "text/plain", "Not Found".to_utf8_buffer())
		return
	var body := f.get_buffer(f.get_length())
	f.close()
	var ext := full.get_extension().to_lower()
	_send(peer, 200, String(MIME.get(ext, "application/octet-stream")), body)

func _send(peer: StreamPeerTCP, code: int, mime: String, body: PackedByteArray) -> void:
	var reason: String = {200: "OK", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed"}.get(code, "OK")
	var header := "HTTP/1.0 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" % [code, reason, mime, body.size()]
	peer.put_data(header.to_utf8_buffer())
	if body.size() > 0:
		peer.put_data(body)
	peer.disconnect_from_host()
