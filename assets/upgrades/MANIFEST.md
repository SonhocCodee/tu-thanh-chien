# MANIFEST — Asset nâng cấp cấp 2 + cấp 3 (đợt vẽ asset, CHƯA nối vào game)

Nhánh: `asset-nang-cap` (nền `100bc65`). Thư mục: `assets/upgrades/`.
Tổng sản xuất: **184/184 file, kiểm chứng tự động 184/184 PASS** (xem mục 5).

---

## 1. Ngôn ngữ thiết kế 3 cấp (áp nhất quán cho mọi nhà + quân)

- **Cấp 1 — như hiện tại:** gỗ + vải màu phe, giáp nhẹ, màu tươi vừa.
- **Cấp 2 — "Củng cố":** vật liệu cứng hơn thấy rõ:
  - Gỗ xám lại (giảm bão hoà ~40%) — đọc như gỗ thay bằng đá/thép ở điểm chịu lực.
  - Thép được "đánh bóng": hue kéo về xanh thép, tầng sáng sáng hơn.
  - Màu phe đậm hơn (bão hoà +10%, sáng −7~9%).
  - Nhà có thêm **nền móng đá xám** ở chân công trình; tường kem xám lại như vữa đá.
- **Cấp 3 — "Tinh nhuệ":** viền VÀNG là dấu hiệu nhận biết từ xa:
  - Ramp vàng dùng chung: `#a86e14` (bóng) / `#eaa72e` / `#ffcf4d` / `#ffe89a` (sáng nhất).
  - Quân: tầng sáng của thép → vàng (lưỡi kiếm, mũi giáo, **mũ cung thủ mạ vàng**);
    tầng sáng của màu phe → vàng; **chùm mũ kiếm sĩ + cờ nhỏ lính giáo → vàng**
    (quy tắc vùng chóp theo từng frame); thép trung → gunmetal sẫm để vàng nổi lên.
  - Nhà: **viền vàng 2px dọc mép mái/đỉnh tường thành** + **chóp vàng hình kim cương**
    ở đỉnh cao nhất giữa nhà; nền móng đá sẫm hơn cấp 2; màu phe đậm/bão hoà hơn nữa.
  - Gỗ → nâu hạt dẻ sẫm (walnut); tường kem giữ sáng sạch để tương phản vàng.

## 2. Ràng buộc kỹ thuật (đã giữ tuyệt đối)

- Mọi file lv2/lv3 **cùng kích thước pixel, cùng số frame + kích thước frame,
  cùng điểm neo/mặt đất** với file cấp 1 tương ứng → code nâng cấp sau này chỉ
  đổi texture, không căn lại: nhà (ảnh đơn) castle 320×256, house/storehouse
  128×192, barracks 192×256, tower 128×256; quân frame 192×192 (pawn/warrior/
  archer), lancer frame 320×320 (idle 12, run 6, attack 3 frame).
- PNG RGBA nền trong suốt; kênh alpha của cấp 1 được giữ nguyên 100% (pixel
  đặc mới duy nhất = chóp vàng của nhà cấp 3, nằm trong dải 5px phía trên đỉnh).
- Quy ước tên: cùng tên file cấp 1 + hậu tố `_lv2` / `_lv3`, đặt ở
  `assets/upgrades/buildings/` và `assets/upgrades/units/<màu>/`.

## 3. Phương pháp (theo nhóm)

- **Tất cả (nền tảng):** biên tập TRÊN CHÍNH file cấp 1 bằng ánh xạ bảng màu
  theo vai trò trong không gian HSV — phân loại từng màu gốc thành: outline /
  màu phe (theo dải hue riêng của từng phe, căn từ palette thật của pack) /
  thép-xám lạnh / gỗ-da nâu / kem-da / ánh sáng — rồi biến đổi theo cấp.
  Không vẽ lại đơn vị nào từ 0; bố cục frame, tư thế, outline giữ nguyên xi.
  Script sinh: `assets/upgrades/GENERATOR.py` (chạy lại được, xác định —
  sửa thông số trong đó rồi chạy lại là ra bản mới đồng bộ toàn ma trận).
- **Nhà:** thêm nền móng đá bằng mặt nạ theo cột (chỉ cột "đặc", bỏ 2px đáy
  nhất để mép chạm đất không đổi); cấp 3 thêm viền mái vàng (2 pixel đặc trên
  cùng mỗi cột) + chóp vàng vẽ tay bằng code ở đỉnh giữa nhà.
- **Quân:** chỉ ánh xạ bảng màu + quy tắc vùng chóp cấp 3 (pixel màu phe trong
  dải 12px đầu của nhân vật từng frame → vàng). Nông dân KHÔNG áp quy tắc chóp
  (thân nhỏ, sẽ nhuộm cả áo) — dấu hiệu cấp 3 của nông dân là đầu công cụ
  (rìu/cuốc/dao) mạ vàng trong các dải làm việc + mũ nâu sẫm + áo đậm.
- **Hàng vác của nông dân** (cục vàng `#cea554`, thịt `#b45076/#ef515c/#f9856c`):
  màu giống hệt mọi phe nên được **bảo vệ — giữ nguyên ở mọi cấp** (đó là hàng
  hoá, không phải trang bị của phe).
- **Lancer:** file cấp 1 chưa có ở commit nền — lấy đúng 12 file game đang
  dùng trên nhánh `nha-linh` (`lancer_idle/run/attack` × 4 màu) làm nguồn biên
  tập, để khi gộp nhánh không lệch kích thước/frame.

## 4. Bảng phủ ma trận

| Loại | Dải/file mỗi màu | × 4 màu × 2 cấp | Trạng thái |
| --- | --- | --- | --- |
| castle | 1 | 8 | ✅ xong |
| house | 1 | 8 | ✅ xong |
| barracks | 1 | 8 | ✅ xong |
| tower | 1 | 8 | ✅ xong |
| storehouse | 1 | 8 | ✅ xong |
| pawn | 8 (idle, run, axe, pick, knife, run_wood, run_gold, run_meat) | 64 | ✅ xong |
| warrior | 3 (idle, run, attack) | 24 | ✅ xong |
| archer | 4 (idle, run, shoot, arrow) | 32 | ✅ xong |
| lancer | 3 (idle, run, attack) | 24 | ✅ xong |
| **Tổng** | | **184** | ✅ **184/184** |

Không thuộc đợt này (đúng phạm vi): cừu, goblin, monk, nhà trung lập,
bản construction/destroyed của nhà.

## 5. Kiểm chứng

- `assets/upgrades/VERIFY.py`: kiểm từng file — cùng kích thước với cấp 1,
  không mất pixel đặc nào, pixel đặc mới chỉ trong vùng chóp cho phép,
  số màu không bùng nổ (chống lem màu), không trùng nguyên xi cấp 1.
  **Kết quả: 184/184 PASS.**
- Contact sheet trong `screenshots/` của worktree: `upgrades_<loại>.png`
  (9 ảnh, xanh dương đại diện, 3 cấp cạnh nhau) + `upgrades_matrix.png`
  (toàn bộ 36 tổ hợp loại × màu × 3 cấp thu nhỏ) — đã soi bằng mắt cả 4 phe.

## 6. Điểm chưa hoàn hảo đã biết (trung thực)

1. **Doanh trại/thành cấp 3:** quy tắc viền mái áp cả cho các cột trống lỗ
   châu mai → có vài vệt vàng ngắn trên mặt sàn gỗ phía sau lỗ châu mai
   (đọc như khảm vàng trên mép sàn; không vỡ hình nhưng chưa thật "sạch").
2. **Phe vàng cấp 3:** viền vàng trùng họ với màu phe (vàng) → độ tương phản
   cấp 2→3 của phe vàng dựa nhiều vào gỗ walnut + thép gunmetal + chóp vàng
   hơn là viền. Áo nông dân vàng cấp 3 ngả vàng kim (tầng sáng màu phe → vàng
   theo đúng quy tắc chung).
3. **Nông dân** là loại có độ phân biệt cấp tinh tế nhất (không chùm mũ/huy
   hiệu; chỉ mũ + áo đậm dần và đầu công cụ mạ vàng ở dải làm việc).
4. **Cung thủ cấp 3:** mũ mạ vàng gần như toàn bộ (tầng thép sáng của pack
   chiếm phần lớn mũ) — chủ đích để nhận diện từ xa, nhưng là cách đọc
   "toàn mũ vàng" chứ không phải "viền vàng".
5. Móng đá của thành áp lên hàng cọc nhọn: cọc thành đá sẫm ở đoạn dưới —
   đọc như móng gia cố, còn hơi cảm giác "viền răng cưa" ở sát đất.

## 7. Ghi chú cho đợt sau

- **Chưa làm (đợt asset kế tiếp):** Nhà Lính (sprite House3 trên nhánh
  `nha-linh`) và 4 kho chuyên dụng Gỗ/Đá/Vàng/Thịt (nhánh `kho-chuyen-dung`)
  — cả hai chưa gộp vào main lúc làm đợt này; khi chúng vào main, chạy lại
  `GENERATOR.py` sau khi bổ sung 2 nhóm đó vào `BUILDINGS`/ma trận là phủ đủ.
  Tương tự nếu muốn có bản construction/destroyed theo cấp.
- **Cách nối code hệ thống nâng cấp (đề xuất):** `building.gd`/`unit.gd`/
  `villager.gd` khi nạp texture theo cấp `n`: cấp 1 giữ đường dẫn cũ;
  cấp 2/3 đổi sang `assets/upgrades/.../<tên>_lv<n>.png` — vì hình học frame
  giống hệt, các hàm cắt frame (`FRAME`, `frame_size`) dùng nguyên thông số.
  Lancer chú ý frame 320 và số frame 12/6/3 như nhánh `nha-linh` đã khai.
