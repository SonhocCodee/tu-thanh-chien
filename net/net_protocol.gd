class_name NetProtocol
extends RefCounted

## Hằng số giao thức LAN (M3) dùng chung server/client của GAME THẬT.
## Mang từ prototype (netproto/scripts/protocol.gd) sang, giữ nguyên các con
## số đã chốt ở NET_DESIGN.md mục 6 — lý do từng con số nằm ở tài liệu đó.

# Phiên bản giao thức: hello/welcome mang theo; lệch = server từ chối kèm
# thông báo rõ (chống bạn bè mở nhầm bản client cũ — rủi ro R6 ở INTEGRATION).
# v2 (đợt gộp vào main sau plan Đế Chế hoá): thêm lệnh RTS/chợ/lên đời/
# nghiên cứu/nâng cấp + trường extra_i của bản ghi snapshot mang CẤP
# (quân/nhà/đời) + node mang owner (ruộng) — client v1 đọc sai nên chặn.
# v3 (menu phòng chờ): hello không vào thẳng slot nữa mà qua trạng thái
# "prejoin" — chủ phòng TẠO PHÒNG (server sinh MÃ PHÒNG 6 ký tự), khách
# phải JOIN bằng mã đúng mới nhận slot; chủ phòng đặt chế độ từng slot
# (open/bot/closed) + đổi tên phòng qua lobby_action.
const PROTOCOL_VERSION := 3

# Cổng chủ nhà: 8910 = WebSocket game, 8911 = HTTP tĩnh phục vụ bản web.
const PORT := 8910
const HTTP_PORT := 8911

# Nhịp snapshot server -> client: 10 Hz (sim server chạy physics 60 Hz mặc
# định của game). Client nội suy với trễ 120 ms.
const SNAPSHOT_HZ := 10
const INTERP_DELAY := 0.12

# Thời gian giữ slot khi rớt mạng (giây): trong hạn này slot + phe được giữ
# bằng token; quá hạn khi đang trận -> bot tiếp quản, trước trận -> thả slot.
const RECONNECT_GRACE_SEC := 60.0

# net_id của thành slot s = s + 1 (cố định, client tự suy ra được — cùng
# luật với prototype). Mọi thực thể khác cấp từ FIRST_DYNAMIC_ID tăng dần.
const FIRST_DYNAMIC_ID := 1000

# Cờ (bitmask) trong bản ghi upsert của snapshot — xem net_server.gd.
const F_DIM := 1 # công trình địch ở vùng MỜ: dữ liệu đóng băng lần cuối thấy
const F_DESTROYED := 2
const F_CONSTRUCTED := 4 # công trình đã xây xong (thành luôn có cờ này)
const F_BIG := 8 # node tài nguyên lớn
const F_STUMP := 16 # cây đã cạn, chỉ còn gốc
const F_DEPLETED := 32 # node tài nguyên đã cạn

# Mã lý do chuẩn cho command_result (NET_DESIGN.md mục 4).
const R_FOG := "FOG"
const R_NOT_OWNER := "NOT_OWNER"
const R_NO_TARGET := "NO_TARGET"
const R_TARGET_DEAD := "TARGET_DEAD"
const R_OWN_TARGET := "OWN_TARGET"
const R_NO_UNITS := "NO_UNITS"
const R_DEAD := "DEAD"
const R_BOUNDS := "BOUNDS"
const R_CAP := "CAP"
const R_NO_RESOURCES := "NO_RESOURCES"
const R_PLACEMENT := "PLACEMENT"
const R_NOT_IN_MATCH := "NOT_IN_MATCH"
const R_UNKNOWN_CMD := "UNKNOWN_CMD"
const R_REJECTED := "REJECTED"
# Mã cho các lệnh của plan Đế Chế hoá (chợ / lên đời / nghiên cứu / nâng cấp).
const R_AGE_GATE := "AGE_GATE" # cấp đích vượt Đời hiện tại — phải lên Đời trước
const R_MAXED := "MAXED" # đã ở Đời/cấp tối đa (3)
const R_BUSY := "BUSY" # công trình đang nghiên cứu việc khác
const R_NO_SPACE := "NO_SPACE" # kho không còn chỗ chứa (chợ)
const R_NOT_UPGRADEABLE := "NOT_UPGRADEABLE" # loại nhà không nâng cấp được (ruộng)
# Mã cho luồng phòng chờ v3 (tạo phòng / vào phòng / quyền chủ phòng).
const R_WRONG_CODE := "WRONG_CODE" # sai mã phòng
const R_NOT_HOST := "NOT_HOST" # chỉ chủ phòng mới làm được việc này
const R_ROOM_EXISTS := "ROOM_EXISTS" # phòng đã được tạo rồi
const R_NO_ROOM := "NO_ROOM" # chưa có phòng nào để vào
const R_ROOM_FULL := "ROOM_FULL" # không còn slot mở cho người
const R_NEED_RIVAL := "NEED_RIVAL" # cần ít nhất 2 phe hoạt động (người/bot) mới bắt đầu được

## Câu báo thân thiện cho người chơi theo mã lý do (client hiển thị).
static func reason_text(reason: String) -> String:
	match reason:
		R_FOG:
			return "Mục tiêu chưa lộ diện — hãy cho quân trinh sát tới gần trước!"
		R_NOT_OWNER:
			return "Đó không phải quân/công trình của bạn."
		R_NO_TARGET:
			return "Không tìm thấy mục tiêu."
		R_TARGET_DEAD:
			return "Mục tiêu đã bị phá huỷ."
		R_OWN_TARGET:
			return "Không thể tấn công quân nhà."
		R_NO_UNITS:
			return "Chưa chọn quân nào."
		R_DEAD:
			return "Phe của bạn đã bị loại."
		R_BOUNDS:
			return "Điểm đến nằm ngoài bản đồ."
		R_CAP:
			return "Đã đạt giới hạn quân/dân số — xây thêm nhà để tăng!"
		R_NO_RESOURCES:
			return "Không đủ tài nguyên."
		R_PLACEMENT:
			return "Không đặt được ở vị trí đó."
		R_NOT_IN_MATCH:
			return "Trận chưa bắt đầu."
		R_AGE_GATE:
			return "Cần LÊN ĐỜI trước mới mở được cấp này."
		R_MAXED:
			return "Đã ở cấp/Đời tối đa rồi."
		R_BUSY:
			return "Công trình đang nghiên cứu việc khác — chờ xong đã."
		R_NO_SPACE:
			return "Kho không còn chỗ chứa cho giao dịch này."
		R_NOT_UPGRADEABLE:
			return "Công trình này không nâng cấp được."
		R_WRONG_CODE:
			return "Sai mã phòng — kiểm tra lại mã chủ phòng gửi nhé."
		R_NOT_HOST:
			return "Chỉ CHỦ PHÒNG mới làm được việc này."
		R_ROOM_EXISTS:
			return "Phòng đã được tạo rồi — hãy nhập mã để vào."
		R_NO_ROOM:
			return "Chưa có phòng nào — hãy tạo phòng trước."
		R_ROOM_FULL:
			return "Phòng không còn slot trống cho người chơi."
		R_NEED_RIVAL:
			return "Cần ít nhất 2 phe hoạt động — mở thêm slot BOT hoặc chờ thêm người."
		_:
			return "Lệnh bị từ chối (%s)." % reason
