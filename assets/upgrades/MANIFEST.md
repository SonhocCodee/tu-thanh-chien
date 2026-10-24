# MANIFEST — Asset nâng cấp cấp 2 + cấp 3 (đợt vẽ asset, CHƯA nối vào game)

Nhánh: `asset-nang-cap` (nền `100bc65`). Thư mục: `assets/upgrades/`.
Tổng sản xuất: **184/184 file, kiểm chứng tự động 184/184 PASS** (xem mục 5).

---

## VÒNG 2 — Thêm chi tiết cấu trúc (sau khi user chê vòng 1 "nhìn không khác gì nhau")

Vòng 1 chủ yếu đổi bảng màu → vòng 2 giữ nền đó nhưng **vẽ thêm chi tiết
cấu trúc thật** vào GENERATOR.py (vẫn sinh lại được toàn bộ, không sửa tay
file rời). Tiêu chuẩn: thu nhỏ 50% vẫn đọc ra cấp. Ảnh đối chiếu:
`screenshots/upgrades_before_after.png` (cấp 2/3 vòng 1 cạnh vòng 2).

**Nhà — cấp 2:** móng đá CAO (20% chiều cao, có gờ sáng + mạch vữa, thay
móng mỏng vòng 1) • cờ tam giác màu phe (lấy dải SÁNG của phe cho dễ đọc)
ở mọi nhà • ống khói đá cho nhà dân/kho • xà đỉnh mái cho nhà dân/kho •
2 biểu ngữ treo xẻ én ở doanh trại • 2 vành đai thép có đinh tán quanh
thân tháp • thành: râu thép dọc mép lỗ châu mai.
**Nhà — cấp 3:** viền vàng thành DẢI LIỀN 3px dọc mép mái (chế độ "window"
chống rắc vàng vào sàn trong) • CHÓP NÓN vàng lớn ở tháp bên của thành,
góc doanh trại, đỉnh tháp (tháp thêm cọc cờ mọc từ đỉnh nón) • huy hiệu
khiên+gươm vàng trên cổng (chọn cụm cổng ở giữa ảnh; doanh trại thay bằng
chữ X vàng trên cổng vì đã có sẵn phù hiệu) • tua vàng ở chân biểu ngữ sẵn
có của thành • móng đá 24% + nắp ống khói vàng.
**Quân — cấp 2:** chùm mũ kiếm sĩ mọc cao theo hình nón (giãn nở lên trên)
• khiên kiếm sĩ thành BẠC (ô phe → thép, ô kem pha thép lạnh) • vũ khí
mỏng đánh bóng thép sáng nhất • vành mũ cung thủ thép sáng + 1 hàng màu
phe • cờ giáo phình to (mọc đè qua vòng outline của chính lá cờ rồi vẽ lại
outline) • nông dân: băng đầu 3 hàng màu phe + thắt lưng da 3 hàng có
khoá + miếng vá kim cương màu phe trên mũ.
**Quân — cấp 3:** chùm mũ mọc to hơn + nhuộm vàng • khiên vàng (ô kem ánh
vàng) • lưỡi/cán vũ khí vàng • cờ giáo vàng và to hơn • mũ cung thủ vàng +
vành mũ vàng • nông dân: mũ nhuộm vàng nhạt + băng đầu + thắt lưng khoá
vàng + viền cổ vàng + công cụ mạ vàng toàn bộ phần thép.
**Phe vàng cấp 3:** ramp vàng riêng sáng/trắng hơn (vàng của pack) + gỗ
walnut sẫm + thép gunmetal để tách khỏi màu phe (xem điểm chưa ưng 2).

Hai lỗi vòng 1/đầu vòng 2 đã sửa trong dịp này: (a) file tạm lancer mang
tên `{phe}_lancer_*` khiến khâu nhận diện loại quân trượt → cờ giáo/chùm
vàng của lancer thực ra chưa từng chạy ở vòng 1, vòng 2 mới có thật;
(b) pixel mới phải DÍNH silhouette gốc — VERIFY.py đã đổi luật: BFS từ
pixel gốc qua vùng gốc∪mới, pixel mới lơ lửng = FAIL (chóp/cờ mọc dính
vào thân qua cọc/thân nên vẫn hợp lệ).

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
- PNG RGBA nền trong suốt; không pixel đặc nào của cấp 1 bị mất. Vòng 2 có
  thêm pixel đặc MỚI (cờ, chóp nón, chùm mũ/cờ giáo mọc) nhưng tất cả đều
  nằm TRONG canvas gốc và DÍNH vào silhouette gốc (VERIFY kiểm bằng BFS);
  điểm neo/mặt đất không đổi vì không pixel mới nào vượt quá biên dưới/trái/phải của hình gốc ngoài vùng đầu/mái vốn còn headroom.
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
  không mất pixel đặc nào, số màu không bùng nổ (chống lem màu), không
  trùng nguyên xi cấp 1. **Vòng 2 đổi luật pixel mới:** pixel mới phải
  DÍNH silhouette gốc (BFS 8 hướng từ pixel gốc qua vùng gốc∪mới — pixel
  lơ lửng không chạm gốc = FAIL), trần màu nới 2.2x+80 vì chi tiết thật
  cần màu mới. **Kết quả vòng 2: 184/184 PASS, 0 FAIL.** File ít thay đổi
  nhất cũng đổi 33,7% pixel đặc (nông dân vác thịt cấp 3 — phần thịt được
  bảo vệ nên tỉ lệ trần thấp là đúng bản chất); mũi tên cấp 2 đổi 43,5%.
- Contact sheet trong `screenshots/` của worktree: `upgrades_<loại>.png`
  (9 ảnh, xanh dương đại diện, 3 cấp cạnh nhau) + bản `_50` thu nhỏ 50%
  của từng ảnh + `upgrades_matrix.png` (toàn bộ 36 tổ hợp loại × màu ×
  3 cấp thu nhỏ) + `upgrades_before_after.png` (trước/sau vòng 1→2) —
  đã soi bằng mắt cả 100% lẫn 50%, đủ 4 phe (phe vàng soi riêng).

## 6. Điểm chưa hoàn hảo đã biết (trung thực) — cập nhật sau vòng 2

1. **Quân cấp 2 vẫn là nhóm tinh tế nhất:** sprite quân chỉ ~50px, dấu
   hiệu cấp 2 (khiên bạc, vành mũ, cờ phình, băng đầu/thắt lưng nông dân)
   đọc rõ ở 100% nhưng lên xuống ở mức "thấy được" khi thu nhỏ 50%.
   Cấp 3 của quân thì không thể nhầm. Nhà cấp 2/3 đọc tốt ở cả 50%.
2. **Phe vàng cấp 3:** màu phe vốn là vàng nên "vàng tinh nhuệ" phải dựa
   vào vàng TRẮNG sáng + chóp nón/móng đá/cờ làm dấu phân biệt chính;
   kiếm sĩ vàng cấp 3 dựa vào chùm mũ to + sáng hơn hẳn cấp 1. Vẫn là phe
   có độ tương phản cấp thấp nhất trong 4 phe (bản chất palette của pack).
3. **Cửa nhà dân/tháp cấp 2-3** bị bảng màu xếp vào thép → đọc như cửa
   thép/lưới cổng — hợp vai "củng cố" nhưng khác cửa gỗ cấp 1 khá rõ;
   nếu không ưng thì đợt sau khoá riêng vai trò cho cửa.
4. **Vệt chém (swoosh) của kiếm sĩ/nông dân cấp 3 ngả vàng toàn bộ** (ánh
   sáng → vàng nhạt theo quy tắc chung): đọc như chiêu mạ vàng, hầm hố
   nhưng là hiệu ứng chứ không còn là vệt trắng như cấp 1.
5. Móng đá của thành áp lên hàng cọc nhọn: cọc thành đá sẫm ở đoạn dưới —
   đọc như móng gia cố, còn hơi cảm giác "viền răng cưa" ở sát đất.
6. Vành thép quanh thân tháp cấp 2 vẫn là chi tiết lặng nhất trong nhóm
   nhà (tháp vốn nhiều dải ngang sẵn); dấu hiệu chính của tháp cấp 2 là
   cờ + cửa thép, cấp 3 là nón vàng + viền vàng + huy hiệu cổng.

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
