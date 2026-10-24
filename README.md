# TỨ THÀNH CHIẾN — Đế Chế 4 Phe (M1: Lõi Đế Chế + Sương Mù)

Game web kiểu Đế Chế thu nhỏ: 4 phe ở 4 góc map, nông dân farm Gỗ/Đá/Vàng,
xây Nhà Dân/Doanh Trại/Tháp Canh, huấn luyện quân, cử quân mở sương mù đi tìm
thành địch và tổng tấn công. Phá thành chính của cả 3 phe địch = thắng.

## Cách chạy
- Chơi bản web: mở thư mục `build/web/` qua 1 máy chủ tĩnh bất kỳ (vd `python3 -m http.server` trong thư mục đó) rồi vào `index.html`. Preset Web đã **tắt hỗ trợ đa luồng** nên chạy trên host tĩnh thông thường.
- Chạy trong Godot 4.2.2: mở `project.godot` → F5.
- Chế độ demo tự chơi (để chụp ảnh kiểm chứng): chạy game với tham số `-- --demo`.

## Cách chơi
1. **Phân bổ nông dân**: dùng nút −/+ ở panel dưới cho từng loại Gỗ/Đá/Vàng. Nông dân tự chạy tới điểm tài nguyên gần nhất đã khám phá, khai thác rồi mang về thành.
2. **Xây dựng**: bấm nút công trình (Nhà dân / Doanh trại / Tháp canh) rồi bấm vào vùng quanh thành của mình. Xây xong mới có hiệu lực. Công trình dưới 50% máu sẽ cháy, hết máu thì sập thành tàn tích.
3. **Huấn luyện**: Thành chính đẻ Nông dân + Kiếm sĩ; Doanh trại đẻ Kiếm sĩ + Cung thủ (nhanh hơn). Bị chặn bởi giới hạn dân số — xây thêm Nhà Dân để tăng giới hạn.
4. **Điều quân**: 
   - `GIỮ NHÀ`: quân tập kết trước thành, đánh chặn địch vào gần.
   - `TẤN CÔNG…`: bấm vào **thành địch đã lộ diện** để tổng tấn công; bấm vào 1 điểm bất kỳ trên map để quân đi **trinh sát** tới đó (mở sương mù).
5. **Sương mù**: vùng đen = chưa khám phá (không thấy gì), vùng mờ = đã khám phá (thấy địa hình + công trình theo trạng thái lần cuối nhìn thấy, không thấy quân), vùng sáng = đang có tầm nhìn (thấy mọi thứ). Minimap ở góc phải trên áp dụng đúng sương mù này. Giữa map có mỏ vàng lớn, rừng gỗ lớn, mỏ đá lớn — phải trinh sát mới khai thác được.

## Kiến trúc (cho các mốc sau)
- Mọi lệnh (phân bổ / xây / huấn luyện / thái độ / di chuyển) đi qua **PlayerController** (`scripts/player_controller.gd`) — HUD, bot và sau này là người chơi qua mạng LAN đều cắm lệnh vào cùng một cửa; Main (`scripts/main.gd`) là lớp thực thi và kiểm tra hợp lệ (kể cả luật lộ diện của sương mù).
- Toàn bộ chỉ số nằm trong `scripts/stats.gd`.
- Sương mù là dữ liệu riêng từng phe: `scripts/fog.gd` (lưới ô 3 trạng thái, cập nhật mỗi 0,25s).

## Kiểm chứng
- Test tự động: `godot --headless --script tests/test_battle.gd` (8 mục: khai thác, xây nhà tăng dân số, huấn luyện trừ đúng tài nguyên + chặn dân số, tổng tấn công phá thành sau trinh sát, bot trọn trận, 3 mục sương mù).
- Ảnh kiểm chứng: thư mục `screenshots/`.
