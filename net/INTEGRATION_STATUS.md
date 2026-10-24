# TRẠNG THÁI TÍCH HỢP LAN (M3) — nhánh `lan-m3`

Cập nhật: 2026-10-24. Nền: `origin/main @ d07b7b8`. Đối chiếu theo 6 bước
trong `~/workspace/thu-thanh-4v4-netproto/INTEGRATION.md` mục 2.

## Trạng thái từng bước

| Bước | Nội dung | Trạng thái |
|---|---|---|
| 1 | Registry net_id trong Main | ✅ XONG — `tests/test_net_ids.gd` 5/5; mọi bộ test cũ xanh |
| 2 | NetSession + cổng lệnh qua PlayerController | ✅ XONG — đủ 8 lệnh (alloc/build/train/stance/order_move/move/farm/attack), vượt yêu cầu 3 lệnh đầu |
| 3 | Snapshot lọc sương mù + gương + nội suy 120ms | ✅ XONG — kiểm toán tại nguồn trên payload thật: 5.854 lượt đối chiếu, **0 vi phạm** (số của lần chạy PASS toàn bộ gần nhất); gương 2 client tự kiểm tra: 0 vi phạm |
| 4 | Công trình + node tài nguyên + lệnh trực tiếp + kịch bản trinh sát | ✅ XONG — tấn công thành chưa lộ bị server từ chối `FOG`; trinh sát tới nơi → lệnh được chấp nhận |
| 5 | HUD mạng + phòng chờ | ✅ XONG về code + kiểm chứng bằng 2 client thật (ảnh chụp phòng chờ & trong trận ở `reports/net/shots/`). Chơi tay 2 MÁY THẬT: chưa làm được trong máy ảo này |
| 6 | Nối lại token/grace + gói chủ nhà + test trình duyệt thật | ⚠️ MỘT PHẦN — nối lại ✅ (B bị giết giữa trận, nối lại bằng token trong grace 60s, vào đúng slot, đồng bộ lại, ra lệnh mới được chấp nhận); gói chủ nhà ✅ (xem dưới); **client web trong Chrome thật mở từ IP LAN: CHƯA XONG** — bị chặn bởi môi trường (xem "Giới hạn môi trường") |

## Bằng chứng đã chạy (lệnh + kết quả)

- `tools/run_net_test.sh` → `tools/check_net_reports.py`: **26/26 PASS**
  ("TONG KET: PASS TOAN BO"). Kịch bản: server (tiến trình Godot riêng,
  WS 8917/HTTP 8918, webroot giả) + client A (xvfb, có hình) + client B
  (headless). Log đầy đủ ở `reports/net/` (thư mục này không commit).
  - Kiểm toán sương mù TẠI NGUỒN: server đối chiếu từng thực thể trong
    payload với lưới sương mù của đúng người nhận — 5.854 lượt, 0 vi phạm.
  - Client A: train/build/alloc/move đều ACCEPT; thấy quân mình trong gương.
  - Client B: tấn công thành chưa lộ → REJECT FOG; order_move trinh sát →
    thấy thành → stance attack ACCEPT.
  - Ngắt B giữa trận, chạy lại với cùng token → HELLO_RECLAIM đúng slot,
    resync OK, lệnh alloc sau nối lại ACCEPT.
  - Ảnh: `reports/net/shots/net_lobby_A.png` (phòng chờ hiện đúng 4 slot,
    chủ phòng = người nối đầu tiên), `net_match_A.png` (gương phía A:
    thành vàng, sương mù 3 lớp, thẻ xây, phân bổ 2/1/1/0 đã áp).
- Hồi quy chơi đơn trong worktree: test_net_ids 5/5, test_cursor ALL PASS,
  test_ai ALL PASS, test_pop ALL PASS, test_m2 ALL PASS, test_g2 ALL PASS,
  test_battle ALL PASS (lần chạy đầu song song với tiến trình xuất bản bị
  fail mục e "0 tấn công/1800s" — chạy lại một mình thì PASS, trận kết
  505s; đúng họ flake đã biết của bộ này khi máy bị tải nặng).
- Gói chủ nhà: `host/build_package.sh` chạy trọn (xuất Linux + Web, vá
  web, lắp gói). Binary trong gói chạy thật: SERVER_UP 8910 + HTTP_UP 8911,
  phục vụ đúng webroot của gói (curl index.html → 200).

## Giới hạn môi trường (đã đo, không phải phỏng đoán)

1. **Máy ảo này chặn connect() tới mọi địa chỉ không phải loopback**
   ("Operation not permitted" ở mức syscall): cả IP host0 `198.19.0.2`
   lẫn alias tự gắn trên `lo` đều bị chặn, dù iptables rỗng và route
   local có sẵn; chỉ `127.0.0.0/8` đi được. Harness vì vậy nối qua
   127.0.0.1; server vẫn nghe `*` trên cả 2 cổng (đã kiểm bằng `ss`).
   Trên LAN thật ở nhà, bạn bè nối tới IP LAN của chủ nhà bằng đúng các
   đường code này.
2. **Trình duyệt Chromium đóng gói trong máy ảo chặn điều hướng tới
   127.0.0.1** bằng `ERR_BLOCKED_BY_LOCAL_NETWORK_ACCESS_CHECKS` (kể cả
   khi đã tắt các cờ feature LNA/PNA và gỡ proxy), và các lệnh
   `--screenshot/--print-to-pdf` tự chạy đều treo không kết thúc. Vì vậy
   chưa chụp được ảnh client web trong Chrome tại máy này.

### Việc cần làm ở buổi kiểm chứng thật (máy chủ nhà + 1 máy/bạn thứ hai)

1. Trên máy chủ nhà: giải nén gói, chạy `start_host.sh`/`start_host.bat`.
2. Chủ nhà mở `http://localhost:8911/?lan=1` — phải thấy phòng chờ,
   log server có dòng HELLO.
3. Máy thứ hai cùng LAN mở `http://<IP-LAN-chủ-nhà>:8911/?lan=1` —
   kiểm tra 3 điểm: (a) trang có qua được chốt Secure Context không
   (bản trong gói ĐÃ vá đúng 1 điểm đó, giữ nguyên JavaScriptBridge —
   nếu vẫn bị chặn thì dùng cờ Chrome ghi trong HUONG_DAN_CHU_NHA.txt);
   (b) WebSocket `ws://<IP>:8910` có nối được không (Chrome đời mới có
   thể hỏi quyền "truy cập mạng cục bộ" — bấm cho phép); (c) vào được
   phòng chờ, thấy đúng slot.
4. Chơi thử 1 trận ngắn 2 người + 2 bot; thử ngắt mạng máy khách giữa
   trận rồi nối lại trong 60s.

## Điểm chạm file chung (để đợt gộp cuối rà nhanh)

Chỉ 2 file sẵn có bị sửa:

- `scripts/main.gd` — mọi đoạn đều gắn nhãn `M3 LAN`:
  (1) biến `net_role`/`net_params`/`net_winner_pid` + registry net_id
  (`net_id_of`/`node_by_net_id`; thành = slot+1, id động từ 1000);
  (2) đầu `_ready`: đọc tham số `--netrole=...`; web + query `lan=1` →
  client, URL suy từ hostname trang; server → tắt bot + giữ sim đứng
  yên trong phòng chờ; (3) client bỏ qua dựng thế giới thật + HUD thật;
  cuối `_ready` gắn node `NetSession` khi có vai mạng;
  (4) `_build_bots` tách `_add_bot(pid)` + thêm `spawn_bots_for(pids)`;
  (5) client: `_update_fog` và `_unhandled_input` thoát sớm;
  (6) `_eliminate_player`: nhánh kết trận cho server mạng.
- `export_presets.cfg` — thêm preset "Linux" (cho binary chủ nhà).

Toàn bộ phần còn lại là FILE MỚI: `net/` (9 file .gd + tài liệu này),
`host/` (script đóng gói/khởi động + hướng dẫn + `patch_web.py`),
`tools/run_net_test.sh`, `tools/check_net_reports.py`,
`tests/test_net_ids.gd`.

## Sai lệch & giới hạn đã biết (so với NET_DESIGN/INTEGRATION)

1. Phòng chờ giản lược: không có nút bật/tắt bot — slot trống tự lấp bot
   lúc bắt đầu; chủ phòng = người nối đầu tiên (không chọn/chuyển được).
2. Slot có người rớt mạng NGAY lúc bắt đầu trận: phe đó đứng thụ động
   tới hết grace 60s mới có bot tiếp quản.
3. Người chơi nối lại SAU khi bot đã tiếp quản (quá grace): bot vẫn lái
   song song phe đó (Main chưa có API gỡ bot) — cần xử lý khi gộp.
4. Đạn bay (projectile) không đồng bộ — chỉ là hiệu ứng phía server,
   không có trong snapshot; client không thấy đường đạn của phát bắn xa.
5. Client dùng NetHud + xử lý input riêng thay vì hoán đổi
   `human_controller()` như INTEGRATION mục 1.2 gợi ý: HUD thật đọc
   trạng thái thật từ Main, mà phía client không có Main thật.
6. Chưa có kênh sự kiện rời rạc: chết/khởi công/cháy nhà suy ra từ
   removals + cờ trạng thái trong snapshot.
7. Gói chủ nhà hiện mới có binary Linux x86_64; chủ nhà dùng Windows
   cần xuất thêm preset Windows (template đã có sẵn trong bộ cài
   templates đầy đủ; máy ảo này lúc đầu chỉ có template Web — đã tải
   bổ sung bản Linux để kiểm chứng đường xuất).

## Cách chạy nhanh

- Test tích hợp: `./tools/run_net_test.sh` (tự dựng server + 2 client,
  in bảng PASS/FAIL; cần `xvfb-run`, `curl`, `ss`).
- Đóng gói chủ nhà: `./host/build_package.sh` → `host/goi-chu-nha/`.
- Chơi đơn như cũ: không truyền `--netrole` thì game chạy y hệt trước
  (đã kiểm: `net_role=''`, không có node NetSession).
