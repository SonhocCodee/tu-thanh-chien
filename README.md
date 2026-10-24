# TỨ THÀNH CHIẾN — Đế Chế 4 Phe (M2: Điều Khiển Chuẩn Đế Chế)

Game web kiểu Đế Chế thu nhỏ: 4 phe ở 4 góc map (map 1920x960, thành cách nhau
tối thiểu 600px nên đầu trận không chạm nhau sớm), nông dân farm Gỗ/Đá/Vàng,
xây Nhà Dân/Doanh Trại/Tháp Canh, huấn luyện quân, cử quân mở sương mù đi tìm
thành địch và tổng tấn công. Phá thành chính của cả 3 phe địch = thắng.

## Cách chạy
- Chơi bản web: mở thư mục `build/web/` qua 1 máy chủ tĩnh bất kỳ (vd `python3 -m http.server` trong thư mục đó) rồi vào `index.html`. Preset Web đã **tắt hỗ trợ đa luồng** (`variant/thread_support=false`) nên bản web là biến thể đơn luồng, chạy trên host tĩnh thông thường — không cần header COOP/COEP.
- Chạy trong Godot 4.2.2: mở `project.godot` → F5.
- ⚠️ **Xuất bản Web phải dùng Godot 4.3 trở lên.** Godot 4.2.2 không hề đọc tùy chọn `variant/thread_support` (tùy chọn này chỉ có từ 4.3): plugin xuất web của 4.2.2 không khai báo/không dùng khóa đó, và template web của 4.2.2 chỉ có đúng một biến thể đa luồng (wasm import bộ nhớ dạng shared, bắt buộc SharedArrayBuffer + Cross-Origin Isolation). Hệ quả: xuất bằng 4.2.2 thì dù preset ghi `false`, bản ra vẫn là đa luồng và game báo lỗi thiếu tính năng trên host tĩnh thường. Bản `build/web/` hiện tại được xuất bằng Godot 4.3 (template `web_nothreads_release.zip`), đã kiểm chứng bằng file: không tạo `WebAssembly.Memory` dạng shared, `index.html` mang `GODOT_THREADS_ENABLED = false`, bước kiểm tra tính năng không đòi Cross-Origin Isolation/SharedArrayBuffer, và mọi file đều tải 200 qua `python3 -m http.server` thuần.
- Chế độ demo tự chơi (để chụp ảnh kiểm chứng): chạy game với tham số `-- --demo`.

## Cách chơi
1. **Chọn quân**: kéo chuột trái vẽ khung chọn quân + nông dân của mình trong khung (vòng xanh = đã chọn); click trái 1 đơn vị để chọn riêng nó; bấm đất trống / quân địch để bỏ chọn.
2. **Click phải ra lệnh** (theo thứ bấm vào): đất trống = di chuyển tới đó; cây/mỏ = nông dân đã chọn đi farm đúng loại đó (lệnh trực tiếp ưu tiên hơn phân bổ; hết mỏ hoặc có lệnh mới thì nông dân quay lại làm theo phân bổ); quân/công trình địch = tấn công (chỉ mục tiêu đã lộ diện — chưa lộ thì game từ chối, cần trinh sát trước).
3. **Lia camera**: đưa chuột ra mép màn hình, phím WASD / mũi tên, hoặc bấm vào bản đồ nhỏ để nhảy tới (bản đồ nhỏ hiện khung vùng đang nhìn). Camera kẹp trong biên map.
4. **Phân bổ nông dân**: dùng nút −/+ ở panel dưới cho từng loại Gỗ/Đá/Vàng. Nông dân chưa có lệnh trực tiếp tự chạy tới điểm tài nguyên gần nhất đã khám phá, khai thác rồi mang về thành.
5. **Xây dựng**: bấm nút công trình (Nhà dân / Doanh trại / Tháp canh) rồi bấm vào vùng quanh thành của mình. Xây xong mới có hiệu lực. Công trình dưới 50% máu sẽ cháy, hết máu thì sập thành tàn tích.
6. **Huấn luyện**: Thành chính đẻ Nông dân + Kiếm sĩ; Doanh trại đẻ Kiếm sĩ + Cung thủ (nhanh hơn). Bị chặn bởi giới hạn dân số — xây thêm Nhà Dân để tăng giới hạn.
7. **Thái độ quân (nút cũ, vẫn dùng được)**: `GIỮ NHÀ`: quân tập kết trước thành, đánh chặn địch vào gần. `TẤN CÔNG…`: bấm vào **thành địch đã lộ diện** để tổng tấn công; bấm vào 1 điểm bất kỳ trên map để quân đi **trinh sát** tới đó (mở sương mù).
8. **Sương mù**: vùng đen = chưa khám phá (không thấy gì), vùng mờ = đã khám phá (thấy địa hình + công trình theo trạng thái lần cuối nhìn thấy, không thấy quân — vùng đã khám phá CHỈ MỜ ĐI, không bao giờ đen lại), vùng sáng = đang có tầm nhìn (thấy mọi thứ). Minimap ở góc phải trên áp dụng đúng sương mù này. Giữa map có mỏ vàng lớn, rừng gỗ lớn, mỏ đá lớn — phải trinh sát mới khai thác được.
9. **Trợ giúp**: panel hướng dẫn tự mở khi vào trận, bấm "Đã hiểu" để tắt, mở lại bằng nút "Trợ giúp" trên thanh trên.

## Kiến trúc (cho các mốc sau)
- Mọi lệnh (phân bổ / xây / huấn luyện / thái độ / di chuyển) đi qua **PlayerController** (`scripts/player_controller.gd`) — HUD, bot và sau này là người chơi qua mạng LAN đều cắm lệnh vào cùng một cửa; Main (`scripts/main.gd`) là lớp thực thi và kiểm tra hợp lệ (kể cả luật lộ diện của sương mù).
- Toàn bộ chỉ số nằm trong `scripts/stats.gd`.
- Sương mù là dữ liệu riêng từng phe: `scripts/fog.gd` (lưới ô 3 trạng thái, cập nhật mỗi 0,25s).

## Kiểm chứng
- Test tự động: `godot --headless --script tests/test_battle.gd` (8 mục M1: khai thác, xây nhà tăng dân số, huấn luyện trừ đúng tài nguyên + chặn dân số, tổng tấn công phá thành sau trinh sát, bot trọn trận, 3 mục sương mù) và `godot --headless --script tests/test_m2.gd` (8 mục M2: khung chọn, click phải di chuyển, click phải farm + về phân bổ, tấn công địch chưa lộ diện bị từ chối, camera kẹp biên, trận bot trên map lớn, thành xa nhau + sương mù chỉ mờ, lệnh trực tiếp ưu tiên hơn phân bổ).
- Ảnh kiểm chứng: thư mục `screenshots/` (`m2_*.png` chụp bằng chế độ `-- --m2demo`).
