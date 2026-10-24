# TRẠNG THÁI TÍCH HỢP LAN (M3) — ĐÃ GỘP VÀO MAIN

Cập nhật: 2026-10-24 (đợt gộp CUỐI). Nguồn: nhánh `lan-m3` (`83fc7dc`, neo
`d07b7b8`) được PORT TAY lên main sau khi plan Đế Chế hoá đợt 1 đã đủ 5/5
(nền khi gộp: `ed5c173` — thợ xây, cân bằng cung/cận chiến, nông trại, chợ,
lệnh RTS, tu sĩ, lên đời/nâng cấp). Kiến trúc giữ nguyên của nhánh:
WebSocket (không ENet), server-authoritative, snapshot 10Hz lọc sương mù
từng người, sim 60Hz, nội suy 120ms, cổng thật **8910 WS / 8911 HTTP**,
nối lại grace 60s bằng token, client do GÓI CHỦ NHÀ tự phục vụ.

## Adapt giao thức: PROTOCOL_VERSION 1 → 2

Main sau nền `d07b7b8` có nhiều lệnh nhánh chưa biết; đợt gộp đã chở đủ
qua mạng, mọi lệnh đều qua đúng cửa luật của PlayerController/Main hiện
hành (server không có đường tắt riêng):

- **Lệnh RTS**: `attack_move` / `patrol` / `guard` (qua
  `exec_attack_move/exec_patrol/exec_guard`); chọn toàn quân là thao tác
  local phía client từ gương. Tìm nông dân nhàn KHÔNG có bản phía client
  (trạng thái nhàn không nằm trong snapshot — giới hạn đã biết).
- **Chợ**: `market_sell` / `market_buy` — server kiểm
  `market_block_reason` rồi trừ/cộng sổ qua `spend_resources/deposit_to`
  như local; mã REJECT map từ lý do luật (NO_RESOURCES / NO_SPACE...).
- **Lên đời / nghiên cứu quân / nâng cấp nhà**: `age_up` /
  `unit_research` / `building_upgrade` qua
  `exec_start_age_up / exec_start_unit_research /
  exec_start_building_upgrade` — gồm cổng Đời (AGE_GATE), MAXED, BUSY và
  **chặn ruộng không nâng cấp** (NOT_UPGRADEABLE, kiểm UPGRADE_TEX trước).
- **Tu sĩ**: luyện tại Thành qua PRODUCERS.castle chung (100 vàng/20s),
  hành vi chữa chạy trong sim server như chơi đơn.
- **Ruộng**: đặt như 1 loại nhà (size small, thợ xây phía server xây như
  mọi nhà — mô hình "đặt móng + thợ tới xây" của main, KHÔNG mọc theo
  timer). Snapshot tôn trọng sương mù với node có chủ: ruộng địch ngoài
  tầm nhìn bị đóng băng lượng chứa (dict `_node_seen` phía server: SÁNG
  gửi thật + ghi nhớ, MỜ gửi bản đóng băng, ĐEN không gửi).
- **Đặt nhà qua mạng** vẫn là 1 lệnh đặt; phần cử thợ/tiến độ xây là sim
  phía server.

Snapshot bản ghi 12 trường: `extra_i` mang cấp quân (unit), Đời (thành),
cấp nhà (building; riêng ruộng = giai đoạn cây 0..2). `_player_state`
("you") thêm: `age`, `unit_levels`, `market` (bảng giá chợ của phe),
`research` đang chạy theo công trình. Gương client (net_ghost) đã nâng
lên mặt bằng main: frames quân theo cấp, nhánh monk, thành theo Đời +
tháp nhỏ cạnh, texture đủ 9 loại nhà + cấp nâng, ruộng 3 giai đoạn,
cung thủ trực trên tháp, node cây cắt region 192 + gốc cây STUMP_ART.

## Sửa lỗi gốc rễ phát hiện khi gộp (không có ở nhánh)

Registry net_id trong Main + `_node_watch` của NetServer KHÔNG giữ tham
chiếu Node nữa mà giữ **instance_id**, tra qua `instance_from_id()`. Bản
nhánh giữ Node trực tiếp: gán instance đã freed vào biến có kiểu gây lỗi
runtime "Trying to assign invalid previously freed instance" làm
`_collect_entities` chết giữa chừng → snapshot rỗng + removal hàng loạt
quét sạch gương client. Phiên test 80s của nhánh không có node nào bị
freed nên không lộ; bản main hiện tại + phiên 170s thì lộ. Sau sửa:
0 lỗi script trong toàn bộ harness.

## Bằng chứng đã chạy trên main sau gộp

- **Harness mạng** `tools/run_net_test.sh` + `tools/check_net_reports.py`:
  **42/42 PASS** (bản nhánh 26 mục + 14 mục mới cho lệnh đợt 1: chợ
  bán/mua ACCEPT, train monk, build barracks/farm, age_up ACCEPT + BUSY,
  building_upgrade NOT_UPGRADEABLE (ruộng) + ACCEPT, unit_research
  AGE_GATE + ACCEPT, attack_move/patrol/guard ACCEPT; harness chạy cổng
  test 8917/8918, server có cờ `--testgrant` CHỈ harness dùng — cấp
  2000×4 tài nguyên cho slot người lúc bắt đầu trận; gói chủ nhà không
  có cờ này).
  - Kiểm toán sương mù TẠI NGUỒN trên payload thật: **14.632 lượt đối
    chiếu, 0 vi phạm**; server 0 lỗi script.
  - Kịch bản cũ giữ nguyên: tấn công thành chưa lộ → REJECT FOG; trinh
    sát lộ thành → ACCEPT; B rớt mạng giữa trận → nối lại bằng token
    trong grace 60s, đúng slot, ra lệnh mới ACCEPT.
  - Ảnh: `reports/net/shots/net_lobby_A.png`, `net_match_A.png`
    (thư mục `reports/` không commit).
- **Hồi quy chơi đơn đủ bộ 17 test × 2 vòng TUẦN TỰ**: vòng 1 — 16 PASS
  + test_shake verdict FAIL do script tự `quit(1)` dù in ALL PASS (chạy
  riêng xác nhận "shake: ALL PASS", fails=0); vòng 2 — 16 bộ PASS quan
  sát trực tiếp + test_tower (xem dưới). Chế độ LAN là opt-in
  (`--netrole` / `?lan=1`); không truyền thì `net_role=""`, không có node
  NetSession, hành vi y hệt trước.
  - **test_tower ca tc là race CÓ SẴN trên nền sạch, không phải hồi quy
    đợt này**: đối chứng worktree sạch `ed5c173` chạy xen kẽ cùng điều
    kiện: nền sạch fail cùng chữ ký 2/10 lượt (tổng 14/16 PASS), tree sau
    gộp 10/18 PASS, và PASS nhiều lần trong cả 2 vòng hồi quy. Cơ chế:
    địch phá tháp ĐANG XÂY trong lúc thợ chưa xây xong — kết quả lật
    theo nhịp máy/headless. Mọi thay đổi của đợt gộp trong main.gd đều
    gated sau `net_role` (rà diff trực tiếp).
- **probe_stall2: 12/12 seed kết thúc** (246–403s/seed).
- **Gói chủ nhà** đóng lại từ main hiện tại (`./host/build_package.sh`):
  binary trong gói boot thật — nghe `*:8910` (WS) + `*:8911` (HTTP),
  `GET /index.html` → 200, `GET /index.pck` → 200. PCK trong gói: server
  4.581.264B, web 4.581.200B.
- **Bản web Pages**: xuất Godot 4.3, `GODOT_THREADS_ENABLED = false`,
  không `index.worker.js`, grep `"shared": true` = 0, pck 4.595.056B.

## Giới hạn môi trường (đã đo, không phải phỏng đoán)

1. VM này chặn connect() tới mọi địa chỉ không phải loopback ở mức
   syscall — harness nối qua 127.0.0.1; server vẫn nghe `*` trên cả 2
   cổng (kiểm bằng `ss`). Chromium đóng gói chặn điều hướng localhost
   (LNA). → **Client web thật qua IP LAN KHÔNG kiểm chứng được trong
   VM**; buổi test máy thật do user chủ trì (xem dưới).
2. `/tmp` của VM bị dọn khi service restart — log hồi quy vòng 1/2 để ở
   /tmp đã mất 1 phần; các verdict đã về qua thông báo tiến trình nền và
   được ghi lại tại đây.

## Việc cần làm ở buổi kiểm chứng thật (máy chủ nhà + 1 máy thứ hai)

1. Máy chủ nhà: giải nén gói `host/goi-chu-nha/`, chạy
   `start_host.sh`/`start_host.bat`.
2. Chủ nhà mở `http://localhost:8911/?lan=1` — thấy phòng chờ, log
   server có dòng HELLO.
3. Máy thứ hai cùng LAN mở `http://<IP-LAN-chủ-nhà>:8911/?lan=1` — kiểm:
   (a) chốt Secure Context (bản trong gói ĐÃ vá 1 điểm bằng
   `host/patch_web.py`: ép `Features.isSecureContext` → true, GIỮ
   NGUYÊN JavaScriptBridge vì client LAN dùng nó đọc hostname);
   (b) `ws://<IP>:8910` nối được (Chrome có thể hỏi quyền mạng cục bộ —
   bấm cho phép); (c) vào phòng chờ đúng slot.
4. Chơi 1 trận ngắn 2 người + 2 bot; ngắt mạng máy khách giữa trận rồi
   nối lại trong 60s.

## Điểm chạm file chung

- `scripts/main.gd` — điểm móc M3 (đều gắn nhãn `M3 LAN`): biến
  `net_role`/`net_params`/`net_winner_pid` + registry net_id bằng
  instance_id (thành = slot+1, id động từ 1000); `_ready` đọc
  `--netrole` (web `?lan=1` → client); server → `bots_enabled=false` +
  `match_over=true` giữ sim trong phòng chờ; client → không dựng thực
  thể/HUD thật; gắn node NetSession khi có vai mạng; `_build_bots` tách
  `_add_bot(pid)` + `spawn_bots_for(pids)`; `_update_fog` +
  `_unhandled_input` thoát sớm cho client; `_eliminate_player` có nhánh
  server (đếm phe còn sống → match_over + net_winner_pid).
- `export_presets.cfg` — thêm preset "Linux" (binary chủ nhà).
- `.gitignore` — thêm `reports/`, `host/goi-chu-nha/`.
- Còn lại là FILE MỚI: `net/` (9 file .gd + tài liệu này), `host/`,
  `tools/run_net_test.sh`, `tools/check_net_reports.py`,
  `tests/test_net_ids.gd`.

## Giới hạn đã biết

1. Phòng chờ giản lược: slot trống tự lấp bot lúc bắt đầu; chủ phòng =
   người nối đầu tiên (không chọn/chuyển được).
2. Slot rớt mạng NGAY lúc bắt đầu trận: đứng thụ động tới hết grace 60s
   mới có bot tiếp quản; nối lại SAU khi bot đã tiếp quản thì bot lái
   song song (Main chưa có API gỡ bot).
3. Đạn bay (projectile) không đồng bộ — hiệu ứng phía server, client
   không thấy đường đạn của phát bắn xa.
4. Client dùng NetHud riêng thay vì HUD chơi đơn (HUD thật đọc trạng
   thái thật từ Main, phía client không có Main thật).
5. Tìm nông dân nhàn (phím `.`) không có phía client: trạng thái nhàn
   không nằm trong snapshot.
6. Nhãn lượng chứa trên ruộng ("n/250") không vẽ trên gương client.
7. Gói chủ nhà mới có binary Linux x86_64; chủ nhà dùng Windows cần
   xuất thêm preset Windows (start_host.bat hiện trỏ bản .exe chưa có
   trong gói).

## Cách chạy nhanh

- Test tích hợp mạng: `./tools/run_net_test.sh` (cần xvfb-run, curl, ss).
- Đóng gói chủ nhà: `./host/build_package.sh` → `host/goi-chu-nha/`.
- Chơi đơn như cũ: không truyền `--netrole` thì game chạy y hệt trước.
