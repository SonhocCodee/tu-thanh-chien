# MỤC LỤC ASSET — Tứ Thành Chiến

> Tài liệu này là **nguồn tham khảo duy nhất** khi thêm asset vào game hoặc code tính năng
> liên quan tới asset. **ĐỌC FILE NÀY TRƯỚC** khi chọn sprite cho bất cứ thứ gì mới.
> Mọi sprite trong game đều từ 2 file zip user gửi (xem §1). Không tự bịa sprite,
> không đoán tên file — đối chiếu với mục lục đầy đủ ở cuối file.

## 1. Nguồn asset (2 file zip user gửi)

| File zip | Nội dung | File thật (đã lọc rác) |
| --- | --- | --- |
| `Tiny_Swords.zip` | Tiny Swords **Update 010** (bản CC0) | 234 file: 197 PNG + 36 `.aseprite` + 1 zip lồng |
| `Tiny_Swords__Free_Pack.zip` | Tiny Swords **Free Pack** (bản free trên itch) | 428 file: 410 PNG + 18 `.aseprite` |

- "File thật" = đã loại `__MACOSX/`, file `._*` và `.DS_Store` (rác của macOS, không phải asset).
- File gốc nằm ở `~/workspace/user/files/` và bản giải nén ở `~/workspace/user/assets/tiny-swords/`.
- File zip lồng trong Update 010: `Factions/Knights/Troops/Archer/Archer + Bow.zip` (59 KB)
  — chứa sprite cung thủ kèm cung, cần giải nén riêng nếu dùng.
- File `.aseprite` là file nguồn mở bằng phần mềm Aseprite để sửa/xuất frame, không dùng
  trực tiếp trong game.

## 2. CẢNH BÁO NHẦM LẪN — ĐỌC KỸ TRƯỚC KHI DÙNG SPRITE

### 2.1. Node "đá" trong project đang dùng nhầm sprite THỊT (lỗi đã bị user chửi)

- File `assets/resources/stone.png` trong project có pixels **giống hệt icon thịt**
  `Resources/Resources/M_Idle.png` của Update 010 (M = Meat).
- Vì vậy trên map, node đá hiện ra như **cục thịt màu hồng** — dân chạy ra "lấy thịt".
- **CẤM dùng&#32;`stone.png`&#32;làm đá nữa.** Đá đúng phải dùng sprite đá xám, ví dụ
  `Terrain/Decorations/Rocks/Rock1.png`, `Rock2.png` của Free Pack (project đã có
  sẵn `assets/deco/rock1.png`, `rock2.png` chính là 2 file này).
- Chưa có sprite "mỏ đá" chuyên dụng trong 2 zip — nếu cần mỏ đá thì dùng cụm đá xám,
  không dùng icon thịt, không dùng đá hồng.

### 2.2. Mỏ vàng KHÔNG phải nhà (lỗi đã bị user chửi)

- File `assets/resources/goldmine.png` trong project là **CỬA MỎ VÀNG**
  (`Resources/Gold Mine/GoldMine_Active.png` của Update 010): khung gỗ + cửa vàng,
  nhìn thoáng qua giống cái nhà nhỏ — nhưng nó là **mỏ**, không phải nhà.
- Hành vi đúng: dân tới mỏ, dùng cuốc chim (**pickaxe**) **ĐÀO** quặng, mỏ cạn thì
  chuyển sang `GoldMine_Destroyed.png` (đống đổ nát) rồi biến mất, vàng **vác về kho**
  mới được cộng. **CẤM cho dân "đập nhà" lấy vàng.**
- Phương án sprite vàng khác, đọc rõ là quặng hơn: \`Terrain/Resources/Gold/Gold Stones/
  Gold Stone 1–6.png`&#32;(cục quặng vàng) + bản highlight;&#32;`Gold Resource/Gold\_Resource.png\`.
- Trạng thái mỏ: `GoldMine_Active.png` (đang khai thác) / `GoldMine_Inactive.png`
  (chưa khai thác) / `GoldMine_Destroyed.png` (đã cạn).

### 2.3. Icon tài nguyên nhỏ KHÔNG phải node trên map

- `Resources/Resources/W_Idle.png`, `G_Idle.png`, `M_Idle.png` (+ bản `_Spawn`,
  `_NoShadow`) của Update 010 là **icon tài nguyên nhỏ** (W = gỗ, G = vàng, M = thịt),
  dùng cho UI / chỉ báo vật đang vác — **không đặt làm node tài nguyên trên map**.
- Node tài nguyên trên map phải dùng: cây `Tree1–4.png`, quặng `Gold Stone 1–6.png`
  hoặc `GoldMine_*.png`, đá xám `Rock1/2.png`, cừu `Sheep_*.png`, thịt `Meat Resource.png`.

### 2.4. Nhiều file PNG là dải nhiều frame, không phải 1 hình

- Ví dụ: `Sheep_Idle.png` (Free Pack) là dải 6 frame cừu, `Lancer_Idle.png` là dải
  10 frame lính giáo, `HappySheep_Idle.png` là dải 8 frame. Khi dùng phải \*\*cắt theo
  frame\*\* (như code game đang cắt sprite sheet theo `FRAME`), không hiển thị nguyên dải.

### 2.5. Màu phe và phe Goblin

- Game 4 phe dùng màu: **blue, purple, red, yellow**. Free Pack còn có thêm màu **Black**
  — Black chỉ là màu phụ của pack, **không phải phe thứ 5** trong game, đừng nhầm.
- **Goblins** (Update 010) là phe quái/trung lập: nhà gỗ `Goblin_House`, tháp gỗ
  `Wood_Tower_*`, lính `Barrel` (thùng), `TNT` (thuốc nổ), `Torch` (đuốc) theo 4 màu.
  Goblin **không phải phe người chơi**.

### 2.6. UI của pack: TẬN DỤNG chỗ nào đẹp để đồng bộ game (user lệnh 2026-10-24)

- Bố cục UI giai đoạn 3 vẫn theo **bản mẫu C tối giản nổi** đã chốt, nhưng "chất liệu"
  chrome UI **lấy từ pack chỗ nào đẹp** cho đồng bộ phong cách pixel của game — chỉ
  render/vẽ mới khi pack không có món tương ứng.
- **Con trỏ (bắt buộc dùng đồ pack, đã soi ảnh thật):**
- Mặc định: Free Pack `UI Elements/UI Elements/Cursors/Cursor_01.png` (mũi tên trắng).
- Tay chỉ (hover nút/thẻ): `Cursors/Cursor_02.png` (bàn tay chỉ).
- Cấm (mục tiêu không hợp lệ, VD tấn công mục tiêu chưa lộ diện): `Cursors/Cursor_03.png`
    (vòng tròn gạch chéo).
- Khung chọn/dấu mục tiêu: Update 010 `UI/Pointers/02.png` (4 góc vàng) hoặc Free Pack
    `Cursors/Cursor_04.png` (4 góc trắng); mũi tên vàng `UI/Pointers/01.png` chỉ dùng nếu
    chọn theme vàng toàn bộ. **Không trộn trắng + vàng cho cùng 1 vai trò.**
- Nút: Update 010 `UI/Buttons/` (xanh/đỏ, thường/hover/pressed/disable) hoặc Free Pack
  `UI Elements/Buttons/` — chọn 1 bộ. Tiêu đề panel/tab: `UI/Banners/`, `UI/Ribbons/`.
  Icon nhỏ: `UI/Icons/` và Free Pack `UI Elements/Icons/`. Thanh máu/tiến trình: Free Pack
  `UI Elements/Bars/`. Nền panel: `UI Elements/Papers/`, `Wood Table/`.

## 3. Tài nguyên (Resources) — dùng cho hệ farm M2 giai đoạn 2

| Loại | Sprite dùng được | Ghi chú |
| --- | --- | --- |
| Gỗ | Free Pack `Terrain/Resources/Wood/Trees/Tree1–4.png` | Cây trên map; project đang dùng `Tree1.png` làm `assets/deco/tree.png` |
| Gốc cây | Free Pack `Terrain/Resources/Wood/Trees/Stump 1–4.png` | Cây chặt cạn thì đổ, **chỉ còn gốc** |
| Gỗ (icon/vác) | Free Pack `Terrain/Resources/Wood/Wood Resource/Wood Resource.png`; Pawn `Pawn_Idle Wood.png`, `Pawn_Run Wood.png` | Dân vác gỗ về kho |
| Vàng (quặng) | Free Pack `Terrain/Resources/Gold/Gold Stones/Gold Stone 1–6.png` (+ bản `_Highlight`) | Cục quặng vàng, đọc rõ là mỏ |
| Vàng (mỏ) | Update 010 `Resources/Gold Mine/GoldMine_Active/Inactive/Destroyed.png` | Cửa mỏ 3 trạng thái (xem §2.2) |
| Vàng (icon/vác) | Free Pack `Terrain/Resources/Gold/Gold Resource/Gold_Resource.png` (+ `_Highlight`); Pawn `Pawn_Idle Gold.png`, `Pawn_Run Gold.png` | Dân vác vàng về kho |
| Thịt (thú) | Free Pack `Terrain/Resources/Meat/Sheep/Sheep_Idle.png` (6 frame), `Sheep_Move.png`, `Sheep_Grass.png`, `Sheep.aseprite`; Update 010 `Resources/Sheep/HappySheep_Idle.png` (8 frame), `HappySheep_Bouncing.png`, `HappySheep_All.png` | **Cừu là nguồn thịt chính** |
| Thịt (cục thịt) | Free Pack `Terrain/Resources/Meat/Meat Resource/Meat Resource.png` (miếng bít tết) | Thịt sau khi giết cừu / dân vác thịt |
| Thịt (dân vác) | Free Pack Pawn `Pawn_Idle Meat.png`, `Pawn_Run Meat.png` (đủ 5 màu) | Dân vác thịt về kho — đã có sẵn, khỏi vẽ |
| Đá | Free Pack `Terrain/Decorations/Rocks/Rock1.png`, `Rock2.png` (xám) | Xem §2.1 — cấm dùng `stone.png` cũ |
| Đá (trang trí) | Free Pack `Terrain/Decorations/Rocks in the Water/` (8 file); Update 010 `Terrain/Water/Rocks/Rocks_01–04.png` | Đá cảnh, không phải node farm |

## 4. Quân (Units)

### 4.1. Phe Knights — 5 màu trong Free Pack (Blue, Purple, Red, Yellow, Black)

| Loại | File mỗi màu | Ghi chú |
| --- | --- | --- |
| Pawn (nông dân) | 20 file: `Pawn_Idle.png`, `Pawn_Run.png`, `Pawn_Idle/Run Axe`, `Hammer`, `Knife`, `Pickaxe`, `Wood`, `Gold`, `Meat`, `Pawn_Interact Axe/Hammer/Knife/Pickaxe` | Đủ hoạt ảnh: đi, chặt (axe), đào (pickaxe), vác gỗ/vàng/thịt, tương tác |
| Warrior (chiến binh) | 5 file | Quân cận chiến của game |
| Archer (cung thủ) | 4 file | Quân tầm xa; bản Update 010 có thêm `Archer + Bow.zip` (cung riêng từng màu) và `Archer_Blue_(NoArms).png` |
| **Lancer (lính giáo)** | 12 file: `Lancer_Idle.png`, `Lancer_Run.png`, `Lancer_Up/Down/Right/DownRight_Attack.png`, `Lancer_Up/Down/Right/DownRight_Defence.png` | **CHƯA có trong game** — lính giáo user từng nhắc tới, có sẵn đủ bộ để thêm sau |
| **Monk (thầy tu)** | 4 file: `Idle.png`, `Run.png`, `Heal.png`, `Heal_Effect.png` | **CHƯA có trong game** — đơn vị hồi máu, để dành |
| Dead | Update 010 `Factions/Knights/Troops/Dead/Dead.png` (+ `.aseprite`) | Xác lính (dùng cho hiệu ứng chết nếu cần) |

### 4.2. Phe Goblins — trung lập (Update 010)

- Nhà: `Goblin_House.png`, `Goblin_House_Destroyed.png`; tháp gỗ \`Wood\_Tower\_Blue/
  Purple/Red/Yellow.png`&#32;+&#32;`Wood\_Tower\_Destroyed.png`,&#32;`Wood\_Tower\_InConstruction.png\`.
- Lính theo 4 màu: `Barrel` (ôm thùng), `TNT` (thuốc nổ/Dynamite), `Torch` (đuốc).

## 5. Nhà (Buildings)

| Nguồn | Mỗi màu gồm |
| --- | --- |
| Free Pack `Buildings/<Màu> Buildings/` (Blue, Purple, Red, Yellow, Black) | 8 nhà: `Castle.png`, `House1.png`, `House2.png`, `House3.png`, `Barracks.png`, `Archery.png`, `Tower.png`, `Monastery.png` |
| Update 010 `Factions/Knights/Buildings/` | `Castle/`: `Castle_<Màu>.png` + `Castle_Construction.png` + `Castle_Destroyed.png`; `House/` và `Tower/` tương tự (nhà/tháp có bản đang xây + tàn tích) |
| Project đang dùng | `castle_<màu>.png`, `house_<màu>.png`, `barracks_<màu>.png`, `tower_<màu>.png` + `house_construction.png`, `tower_construction.png`, `castle_destroyed.png`, `house_destroyed.png`, `tower_destroyed.png` |

- `House1/2/3` của Free Pack = 3 cấp nhà dân; `Archery` = trường bắn (chưa có trong game);
  `Monastery` = tu viện (đi với Monk, để dành).
- **Ruộng (farm)** (nhánh `nong-trai`): KHÔNG có sprite ruộng sẵn trong 2 pack Tiny
  Swords. Project dùng bản GHÉP ở `assets/buildings/farm.png` / `farm_mid.png` /
  `farm_low.png` / `farm_bare.png` (sinh bởi `tools/make_farm_art.py`): đất = tile
  cỏ `assets/terrain/tilemap.png` (1,1) nhuộm nâu giữ texture; cây = Farm RPG FREE
  demo (Maeve) `Objects/Spring Crops.png` theo giai đoạn mầm/lá/chín khớp tỉ lệ
  thịt còn trong ruộng.

## 6. Địa hình (Terrain) và trang trí (Decorations)

- **Tileset** (Free Pack `Terrain/Tileset/`): `Tilemap_color1–5.png` (5 tông nền đất),
  `Water Background color.png`, `Water Foam.png` (+ `.aseprite`), `Shadow.png`.
  Project đang dùng `assets/terrain/tilemap.png` và `assets/terrain/water.png`.
- **Nền đất** (Update 010 `Terrain/Ground/`): `Tilemap_Flat.png`, `Tilemap_Elevation.png`,
  `Shadows.png`.
- **Cầu** (Update 010 `Terrain/Bridge/`): `Bridge_All.png`.
- **Nước** (Update 010 `Terrain/Water/`): `Water.png`, `Foam.png` (+ `.aseprite`),
  `Rocks_01–04.png`.
- **Trang trí** (Free Pack `Terrain/Decorations/`): `Bushes/` (5), `Clouds/` (9),
  `Rocks/` (4: Rock1–4), `Rocks in the Water/` (8), `Rubber Duck/` (2: vịt cao su trang trí).
- **Trang trí** (Update 010 `Deco/`): `01–18.png` (18 vật trang trí, tên file chỉ là số —
  muốn dùng phải mở ảnh xem trước, không đoán từ tên).

## 7. Hiệu ứng (FX)

- Free Pack `Particle FX/`: `Dust_01/02.png`, `Explosion_01/02.png`, `Fire_01/02/03.png`,
  `Water Splash.png` (+ `Particle FX.aseprite`).
- Update 010 `Effects/Explosion/` (2 file), `Effects/Fire/` (2 file).
- Project đang dùng `assets/fx/explosion.png`, `assets/fx/fire.png`.

## 8. UI có sẵn trong pack (chỉ tham khảo — xem §2.6)

- Update 010 `UI/`: `Banners/` (9: banner ngang/dọc, nối 4 hướng, khắc), `Buttons/` (18:
  xanh/đỏ, thường/hover/pressed/disable, bản 3Slides/9Slides), `Icons/` (30: Regular/
  Pressed/Disable × 10), `Pointers/` (6 con trỏ), `Ribbons/` (27: ribbon xanh/đỏ/vàng,
  nối 4 hướng, thường/pressed).
- Free Pack `UI Elements/UI Elements/`: `Banners/` (2), `Bars/` (4), `Buttons/` (16),
  `Cursors/` (4), `Human Avatars/` (25 chân dung người), `Icons/` (12), `Papers/` (2),
  `Ribbons/` (2), `Swords/` (1), `Wood Table/` (2); và `UI Banners from the store page/`
  (banner/ribbon trang trí trang bán hàng, không phải UI trong game).

## 9. Đối chiếu: project đang dùng gì, zip còn gì chưa dùng

- Project đã dùng (đối chiếu theo pixels/tên): cây = Free Pack `Tree1.png`; đá cảnh =
  Free Pack `Rock1/2.png`; mỏ vàng ≈ Update 010 `GoldMine_Active.png` (khớp hình ảnh,
  khác byte — có thể đã lưu lại); quân/nhà 4 màu = subset của Free Pack + Update 010
  (castle/house/barracks/tower, pawn/warrior/archer + hoạt ảnh vác gỗ/vàng);
  hiệu ứng nổ/lửa; tilemap/nước.
- **Chưa đưa vào project — lấy được ngay khi cần:** Lancer (lính giáo, đủ 12 file/màu),
  Monk + Monastery + Archery, cừu (2 bộ: Free Pack + HappySheep), gốc cây Stump 1–4,
  quặng vàng Gold Stone 1–6, thịt (Meat Resource + Pawn vác thịt), nhà cấp House1/2/3,
  Goblins (nhà gỗ, tháp gỗ, lính Barrel/TNT/Torch), tileset 5 màu, cầu, bộ UI pack,
  Deco 01–18, vịt cao su.
- **CẤM dùng lại:** `assets/resources/stone.png` (thực chất là icon thịt — xem §2.1).

---

## 10. MỤC LỤC ĐẦY ĐỦ — mọi file thật trong 2 zip (theo thư mục)

### Tiny\_Swords.zip — 234 file

**Tiny Swords (Update 010)/Deco**

- 01.png
- 02.png
- 03.png
- 04.png
- 05.png
- 06.png
- 07.png
- 08.png
- 09.png
- 10.png
- 11.png
- 12.png
- 13.png
- 14.png
- 15.png
- 16.png
- 17.png
- 18.png

**Tiny Swords (Update 010)/Effects/Explosion**

- Explosions.aseprite
- Explosions.png

**Tiny Swords (Update 010)/Effects/Fire**

- Fire.aseprite
- Fire.png

**Tiny Swords (Update 010)/Factions/Goblins/Buildings/Wood\_House**

- Goblin\_House.png
- Goblin\_House\_Destroyed.png

**Tiny Swords (Update 010)/Factions/Goblins/Buildings/Wood\_Tower**

- Wood\_Tower\_Blue.aseprite
- Wood\_Tower\_Blue.png
- Wood\_Tower\_Destroyed.png
- Wood\_Tower\_InConstruction.png
- Wood\_Tower\_Purple.aseprite
- Wood\_Tower\_Purple.png
- Wood\_Tower\_Red.aseprite
- Wood\_Tower\_Red.png
- Wood\_Tower\_Yellow.aseprite
- Wood\_Tower\_Yellow.png

**Tiny Swords (Update 010)/Factions/Goblins/Troops/Barrel/Blue**

- Barrel\_Blue.aseprite
- Barrel\_Blue.png

**Tiny Swords (Update 010)/Factions/Goblins/Troops/Barrel/Purple**

- Barrel\_Purple.aseprite
- Barrel\_Purple.png

**Tiny Swords (Update 010)/Factions/Goblins/Troops/Barrel/Red**

- Barrel\_Red.aseprite
- Barrel\_Red.png

**Tiny Swords (Update 010)/Factions/Goblins/Troops/Barrel/Yellow**

- Barrel\_Yellow.aseprite
- Barrel\_Yellow.png

**Tiny Swords (Update 010)/Factions/Goblins/Troops/TNT/Blue**

- TNT\_Blue.aseprite
- TNT\_Blue.png

**Tiny Swords (Update 010)/Factions/Goblins/Troops/TNT/Dynamite**

- Dynamite.png

**Tiny Swords (Update 010)/Factions/Goblins/Troops/TNT/Purple**

- TNT\_Purple.aseprite
- TNT\_Purple.png

**Tiny Swords (Update 010)/Factions/Goblins/Troops/TNT/Red**

- TNT\_Red.aseprite
- TNT\_Red.png

**Tiny Swords (Update 010)/Factions/Goblins/Troops/TNT/Yellow**

- TNT\_Yellow.aseprite
- TNT\_Yellow.png

**Tiny Swords (Update 010)/Factions/Goblins/Troops/Torch/Blue**

- Torch\_Blue.aseprite
- Torch\_Blue.png

**Tiny Swords (Update 010)/Factions/Goblins/Troops/Torch/Purple**

- Torch\_Purple.aseprite
- Torch\_Purple.png

**Tiny Swords (Update 010)/Factions/Goblins/Troops/Torch/Red**

- Torch\_Red.aseprite
- Torch\_Red.png

**Tiny Swords (Update 010)/Factions/Goblins/Troops/Torch/Yellow**

- Torch\_Yellow.aseprite
- Torch\_Yellow.png

**Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle**

- Castle\_Blue.png
- Castle\_Construction.png
- Castle\_Destroyed.png
- Castle\_Purple.png
- Castle\_Red.png
- Castle\_Yellow.png

**Tiny Swords (Update 010)/Factions/Knights/Buildings/House**

- House\_Blue.png
- House\_Construction.png
- House\_Destroyed.png
- House\_Purple.png
- House\_Red.png
- House\_Yellow.png

**Tiny Swords (Update 010)/Factions/Knights/Buildings/Tower**

- Tower\_Blue.png
- Tower\_Construction.png
- Tower\_Destroyed.png
- Tower\_Purple.png
- Tower\_Red.png
- Tower\_Yellow.png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Archer**

- Archer + Bow.zip

**Tiny Swords (Update 010)/Factions/Knights/Troops/Archer/Archer + Bow**

- Archer\_Blue\_(NoArms).png
- Archer\_Bow\_Blue.png
- Archer\_Bow\_Purple.png
- Archer\_Bow\_Red.png
- Archer\_Bow\_Yellow.png
- Archer\_Purple\_(NoArms).png
- Archer\_Red\_(NoArms).png
- Archer\_Yellow\_(NoArms).png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Archer/Arrow**

- Arrow.png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Archer/Blue**

- Archer\_Blue.aseprite
- Archer\_Blue.png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Archer/Purple**

- Archer\_Purlple.aseprite
- Archer\_Purlple.png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Archer/Red**

- Archer\_Red.aseprite
- Archer\_Red.png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Archer/Yellow**

- Archer\_Yellow.aseprite
- Archer\_Yellow.png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Dead**

- Dead.aseprite
- Dead.png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Pawn/Blue**

- Pawn\_Blue.aseprite
- Pawn\_Blue.png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Pawn/Purple**

- Pawn\_Purple.aseprite
- Pawn\_Purple.png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Pawn/Red**

- Pawn\_Red.aseprite
- Pawn\_Red.png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Pawn/Yellow**

- Pawn\_Yellow.aseprite
- Pawn\_Yellow.png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Warrior/Blue**

- Warrior\_Blue.aseprite
- Warrior\_Blue.png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Warrior/Purple**

- Warrior\_Purple.aseprite
- Warrior\_Purple.png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Warrior/Red**

- Warrior\_Red.aseprite
- Warrior\_Red.png

**Tiny Swords (Update 010)/Factions/Knights/Troops/Warrior/Yellow**

- Warrior\_Yellow.aseprite
- Warrior\_Yellow.png

**Tiny Swords (Update 010)/Resources/Gold Mine**

- GoldMine\_Active.png
- GoldMine\_Destroyed.png
- GoldMine\_Inactive.png

**Tiny Swords (Update 010)/Resources/Resources**

- G\_Idle.png
- G\_Idle\_(NoShadow).png
- G\_Spawn.png
- M\_Idle.png
- M\_Idle\_(NoShadow).png
- M\_Spawn.png
- Resources.aseprite
- W\_Idle.png
- W\_Idle\_(NoShadow).png
- W\_Spawn.png

**Tiny Swords (Update 010)/Resources/Sheep**

- HappySheep\_All.png
- HappySheep\_Bouncing.png
- HappySheep\_Idle.png
- Happy\_Sheep.aseprite

**Tiny Swords (Update 010)/Resources/Trees**

- Tree.aseprite
- Tree.png

**Tiny Swords (Update 010)/Terrain/Bridge**

- Bridge\_All.png

**Tiny Swords (Update 010)/Terrain/Ground**

- Shadows.png
- Tilemap\_Elevation.png
- Tilemap\_Flat.png

**Tiny Swords (Update 010)/Terrain/Water/Foam**

- Foam.aseprite
- Foam.png

**Tiny Swords (Update 010)/Terrain/Water/Rocks**

- Rocks.aseprite
- Rocks\_01.png
- Rocks\_02.png
- Rocks\_03.png
- Rocks\_04.png

**Tiny Swords (Update 010)/Terrain/Water**

- Water.png

**Tiny Swords (Update 010)/UI/Banners**

- Banner\_Connection\_Down.png
- Banner\_Connection\_Left.png
- Banner\_Connection\_Right.png
- Banner\_Connection\_Up.png
- Banner\_Horizontal.png
- Banner\_Vertical.png
- Carved\_3Slides.png
- Carved\_9Slides.png
- Carved\_Regular.png

**Tiny Swords (Update 010)/UI/Buttons**

- Button\_Blue.png
- Button\_Blue\_3Slides.png
- Button\_Blue\_3Slides\_Pressed.png
- Button\_Blue\_9Slides.png
- Button\_Blue\_9Slides\_Pressed.png
- Button\_Blue\_Pressed.png
- Button\_Disable.png
- Button\_Disable\_3Slides.png
- Button\_Disable\_9Slides.png
- Button\_Hover.png
- Button\_Hover\_3Slides.png
- Button\_Hover\_9Slides.png
- Button\_Red.png
- Button\_Red\_3Slides.png
- Button\_Red\_3Slides\_Pressed.png
- Button\_Red\_9Slides.png
- Button\_Red\_9Slides\_Pressed.png
- Button\_Red\_Pressed.png

**Tiny Swords (Update 010)/UI/Icons**

- Disable\_01.png
- Disable\_02.png
- Disable\_03.png
- Disable\_04.png
- Disable\_05.png
- Disable\_06.png
- Disable\_07.png
- Disable\_08.png
- Disable\_09.png
- Disable\_10.png
- Pressed\_01.png
- Pressed\_02.png
- Pressed\_03.png
- Pressed\_04.png
- Pressed\_05.png
- Pressed\_06.png
- Pressed\_07.png
- Pressed\_08.png
- Pressed\_09.png
- Pressed\_10.png
- Regular\_01.png
- Regular\_02.png
- Regular\_03.png
- Regular\_04.png
- Regular\_05.png
- Regular\_06.png
- Regular\_07.png
- Regular\_08.png
- Regular\_09.png
- Regular\_10.png

**Tiny Swords (Update 010)/UI/Pointers**

- 01.png
- 02.png
- 03.png
- 04.png
- 05.png
- 06.png

**Tiny Swords (Update 010)/UI/Ribbons**

- Ribbon\_Blue\_3Slides.png
- Ribbon\_Blue\_Connection\_Down.png
- Ribbon\_Blue\_Connection\_Down\_Pressed.png
- Ribbon\_Blue\_Connection\_Left.png
- Ribbon\_Blue\_Connection\_Left\_Pressed.png
- Ribbon\_Blue\_Connection\_Right.png
- Ribbon\_Blue\_Connection\_Right\_Pressed.png
- Ribbon\_Blue\_Connection\_Up.png
- Ribbon\_Blue\_Connection\_Up\_Pressed.png
- Ribbon\_Red\_3Slides.png
- Ribbon\_Red\_Connection\_Down.png
- Ribbon\_Red\_Connection\_Down\_Pressed.png
- Ribbon\_Red\_Connection\_Left.png
- Ribbon\_Red\_Connection\_Left\_Pressed.png
- Ribbon\_Red\_Connection\_Right.png
- Ribbon\_Red\_Connection\_Right\_Pressed.png
- Ribbon\_Red\_Connection\_Up.png
- Ribbon\_Red\_Connection\_Up\_Pressed.png
- Ribbon\_Yellow\_3Slides.png
- Ribbon\_Yellow\_Connection\_Down.png
- Ribbon\_Yellow\_Connection\_Down\_Pressed.png
- Ribbon\_Yellow\_Connection\_Left.png
- Ribbon\_Yellow\_Connection\_Left\_Pressed.png
- Ribbon\_Yellow\_Connection\_Right.png
- Ribbon\_Yellow\_Connection\_Right\_Pressed.png
- Ribbon\_Yellow\_Connection\_Up.png
- Ribbon\_Yellow\_Connection\_Up\_Pressed.png

### Tiny\_Swords\_\_Free\_Pack.zip — 428 file

**Tiny Swords (Free Pack)/Buildings/Black Buildings**

- Archery.png
- Barracks.png
- Castle.png
- House1.png
- House2.png
- House3.png
- Monastery.png
- Tower.png

**Tiny Swords (Free Pack)/Buildings/Blue Buildings**

- Archery.png
- Barracks.png
- Castle.png
- House1.png
- House2.png
- House3.png
- Monastery.png
- Tower.png

**Tiny Swords (Free Pack)/Buildings/Purple Buildings**

- Archery.png
- Barracks.png
- Castle.png
- House1.png
- House2.png
- House3.png
- Monastery.png
- Tower.png

**Tiny Swords (Free Pack)/Buildings/Red Buildings**

- Archery.png
- Barracks.png
- Castle.png
- House1.png
- House2.png
- House3.png
- Monastery.png
- Tower.png

**Tiny Swords (Free Pack)/Buildings/Yellow Buildings**

- Archery.png
- Barracks.png
- Castle.png
- House1.png
- House2.png
- House3.png
- Monastery.png
- Tower.png

**Tiny Swords (Free Pack)/Particle FX**

- Dust\_01.png
- Dust\_02.png
- Explosion\_01.png
- Explosion\_02.png
- Fire\_01.png
- Fire\_02.png
- Fire\_03.png
- Particle FX.aseprite
- Water Splash.png

**Tiny Swords (Free Pack)/Terrain/Decorations/Bushes**

- Bushe1.png
- Bushe2.png
- Bushe3.png
- Bushe4.png
- Bushes.aseprite

**Tiny Swords (Free Pack)/Terrain/Decorations/Clouds**

- Clouds.aseprite
- Clouds\_01.png
- Clouds\_02.png
- Clouds\_03.png
- Clouds\_04.png
- Clouds\_05.png
- Clouds\_06.png
- Clouds\_07.png
- Clouds\_08.png

**Tiny Swords (Free Pack)/Terrain/Decorations/Rocks in the Water**

- Water Rocks\_01.aseprite
- Water Rocks\_01.png
- Water Rocks\_02.aseprite
- Water Rocks\_02.png
- Water Rocks\_03.aseprite
- Water Rocks\_03.png
- Water Rocks\_04.aseprite
- Water Rocks\_04.png

**Tiny Swords (Free Pack)/Terrain/Decorations/Rocks**

- Rock1.png
- Rock2.png
- Rock3.png
- Rock4.png

**Tiny Swords (Free Pack)/Terrain/Decorations/Rubber Duck**

- Rubber Duck.aseprite
- Rubber duck.png

**Tiny Swords (Free Pack)/Terrain/Resources/Gold/Gold Resource**

- Gold Resource.aseprite
- Gold\_Resource.png
- Gold\_Resource\_Highlight.png

**Tiny Swords (Free Pack)/Terrain/Resources/Gold/Gold Stones**

- Gold Stone 1.png
- Gold Stone 1\_Highlight.png
- Gold Stone 2.png
- Gold Stone 2\_Highlight.png
- Gold Stone 3.png
- Gold Stone 3\_Highlight.png
- Gold Stone 4.png
- Gold Stone 4\_Highlight.png
- Gold Stone 5.png
- Gold Stone 5\_Highlight.png
- Gold Stone 6.png
- Gold Stone 6\_Highlight.png
- Gold Stones.aseprite

**Tiny Swords (Free Pack)/Terrain/Resources/Meat/Meat Resource**

- Meat Resource.png

**Tiny Swords (Free Pack)/Terrain/Resources/Meat/Sheep**

- Sheep.aseprite
- Sheep\_Grass.png
- Sheep\_Idle.png
- Sheep\_Move.png

**Tiny Swords (Free Pack)/Terrain/Resources/Tools**

- Tool\_01.png
- Tool\_02.png
- Tool\_03.png
- Tool\_04.png

**Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees**

- Stump 1.png
- Stump 2.png
- Stump 3.png
- Stump 4.png
- Tree1.png
- Tree2.png
- Tree3.png
- Tree4.png
- Trees.aseprite

**Tiny Swords (Free Pack)/Terrain/Resources/Wood/Wood Resource**

- Wood Resource.png

**Tiny Swords (Free Pack)/Terrain/Tileset**

- Shadow.png
- Tilemap\_color1.png
- Tilemap\_color2.png
- Tilemap\_color3.png
- Tilemap\_color4.png
- Tilemap\_color5.png
- Water Background color.png
- Water Foam.aseprite
- Water Foam.png

**Tiny Swords (Free Pack)/UI Elements/UI Banners from the store page/Banner**

- Banner.png
- Slots.png

**Tiny Swords (Free Pack)/UI Elements/UI Banners from the store page/Ribbons**

- Ribbon\_Black.png
- Ribbon\_Blue.png
- Ribbon\_Purple.png
- Ribbon\_Red.png
- Ribbon\_Yellow.png

**Tiny Swords (Free Pack)/UI Elements/UI Elements/Banners**

- Banner.png
- Banner\_Slots.png

**Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars**

- BigBar\_Base.png
- BigBar\_Fill.png
- SmallBar\_Base.png
- SmallBar\_Fill.png

**Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons**

- BigBlueButton\_Pressed.png
- BigBlueButton\_Regular.png
- BigRedButton\_Pressed.png
- BigRedButton\_Regular.png
- SmallBlueRoundButton\_Pressed.png
- SmallBlueRoundButton\_Regular.png
- SmallBlueSquareButton\_Pressed.png
- SmallBlueSquareButton\_Regular.png
- SmallRedRoundButton\_Pressed.png
- SmallRedRoundButton\_Regular.png
- SmallRedSquareButton\_Pressed.png
- SmallRedSquareButton\_Regular.png
- TinyRoundBlueButton.png
- TinyRoundRedButton.png
- TinySquareBlueButton.png
- TinySquareRedButton.png

**Tiny Swords (Free Pack)/UI Elements/UI Elements/Cursors**

- Cursor\_01.png
- Cursor\_02.png
- Cursor\_03.png
- Cursor\_04.png

**Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars**

- Avatars\_01.png
- Avatars\_02.png
- Avatars\_03.png
- Avatars\_04.png
- Avatars\_05.png
- Avatars\_06.png
- Avatars\_07.png
- Avatars\_08.png
- Avatars\_09.png
- Avatars\_10.png
- Avatars\_11.png
- Avatars\_12.png
- Avatars\_13.png
- Avatars\_14.png
- Avatars\_15.png
- Avatars\_16.png
- Avatars\_17.png
- Avatars\_18.png
- Avatars\_19.png
- Avatars\_20.png
- Avatars\_21.png
- Avatars\_22.png
- Avatars\_23.png
- Avatars\_24.png
- Avatars\_25.png

**Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons**

- Icon\_01.png
- Icon\_02.png
- Icon\_03.png
- Icon\_04.png
- Icon\_05.png
- Icon\_06.png
- Icon\_07.png
- Icon\_08.png
- Icon\_09.png
- Icon\_10.png
- Icon\_11.png
- Icon\_12.png

**Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers**

- RegularPaper.png
- SpecialPaper.png

**Tiny Swords (Free Pack)/UI Elements/UI Elements/Ribbons**

- BigRibbons.png
- SmallRibbons.png

**Tiny Swords (Free Pack)/UI Elements/UI Elements/Swords**

- Swords.png

**Tiny Swords (Free Pack)/UI Elements/UI Elements/Wood Table**

- WoodTable.png
- WoodTable\_Slots.png

**Tiny Swords (Free Pack)/Units/Black Units/Archer**

- Archer\_Idle.png
- Archer\_Run.png
- Archer\_Shoot.png
- Arrow.png

**Tiny Swords (Free Pack)/Units/Black Units/Lancer**

- Lancer\_DownRight\_Attack.png
- Lancer\_DownRight\_Defence.png
- Lancer\_Down\_Attack.png
- Lancer\_Down\_Defence.png
- Lancer\_Idle.png
- Lancer\_Right\_Attack.png
- Lancer\_Right\_Defence.png
- Lancer\_Run.png
- Lancer\_UpRight\_Attack.png
- Lancer\_UpRight\_Defence.png
- Lancer\_Up\_Attack.png
- Lancer\_Up\_Defence.png

**Tiny Swords (Free Pack)/Units/Black Units/Monk**

- Heal.png
- Heal\_Effect.png
- Idle.png
- Run.png

**Tiny Swords (Free Pack)/Units/Black Units/Pawn**

- Pawn\_Idle Axe.png
- Pawn\_Idle Gold.png
- Pawn\_Idle Hammer.png
- Pawn\_Idle Knife.png
- Pawn\_Idle Meat.png
- Pawn\_Idle Pickaxe.png
- Pawn\_Idle Wood.png
- Pawn\_Idle.png
- Pawn\_Interact Axe.png
- Pawn\_Interact Hammer.png
- Pawn\_Interact Knife.png
- Pawn\_Interact Pickaxe.png
- Pawn\_Run Axe.png
- Pawn\_Run Gold.png
- Pawn\_Run Hammer.png
- Pawn\_Run Knife.png
- Pawn\_Run Meat.png
- Pawn\_Run Pickaxe.png
- Pawn\_Run Wood.png
- Pawn\_Run.png

**Tiny Swords (Free Pack)/Units/Black Units/Warrior**

- Warrior\_Attack1.png
- Warrior\_Attack2.png
- Warrior\_Guard.png
- Warrior\_Idle.png
- Warrior\_Run.png

**Tiny Swords (Free Pack)/Units/Blue Units/Archer**

- Archer\_Idle.png
- Archer\_Run.png
- Archer\_Shoot.png
- Arrow.png

**Tiny Swords (Free Pack)/Units/Blue Units/Lancer**

- Lancer\_DownRight\_Attack.png
- Lancer\_DownRight\_Defence.png
- Lancer\_Down\_Attack.png
- Lancer\_Down\_Defence.png
- Lancer\_Idle.png
- Lancer\_Right\_Attack.png
- Lancer\_Right\_Defence.png
- Lancer\_Run.png
- Lancer\_UpRight\_Attack.png
- Lancer\_UpRight\_Defence.png
- Lancer\_Up\_Attack.png
- Lancer\_Up\_Defence.png

**Tiny Swords (Free Pack)/Units/Blue Units/Monk**

- Heal.png
- Heal\_Effect.png
- Idle.png
- Run.png

**Tiny Swords (Free Pack)/Units/Blue Units/Pawn**

- Pawn\_Idle Axe.png
- Pawn\_Idle Gold.png
- Pawn\_Idle Hammer.png
- Pawn\_Idle Knife.png
- Pawn\_Idle Meat.png
- Pawn\_Idle Pickaxe.png
- Pawn\_Idle Wood.png
- Pawn\_Idle.png
- Pawn\_Interact Axe.png
- Pawn\_Interact Hammer.png
- Pawn\_Interact Knife.png
- Pawn\_Interact Pickaxe.png
- Pawn\_Run Axe.png
- Pawn\_Run Gold.png
- Pawn\_Run Hammer.png
- Pawn\_Run Knife.png
- Pawn\_Run Meat.png
- Pawn\_Run Pickaxe.png
- Pawn\_Run Wood.png
- Pawn\_Run.png

**Tiny Swords (Free Pack)/Units/Blue Units/Warrior**

- Warrior\_Attack1.png
- Warrior\_Attack2.png
- Warrior\_Guard.png
- Warrior\_Idle.png
- Warrior\_Run.png

**Tiny Swords (Free Pack)/Units/Purple Units/Archer**

- Archer\_Idle.png
- Archer\_Run.png
- Archer\_Shoot.png
- Arrow.png

**Tiny Swords (Free Pack)/Units/Purple Units/Lancer**

- Lancer\_DownRight\_Attack.png
- Lancer\_DownRight\_Defence.png
- Lancer\_Down\_Attack.png
- Lancer\_Down\_Defence.png
- Lancer\_Idle.png
- Lancer\_Right\_Attack.png
- Lancer\_Right\_Defence.png
- Lancer\_Run.png
- Lancer\_UpRight\_Attack.png
- Lancer\_UpRight\_Defence.png
- Lancer\_Up\_Attack.png
- Lancer\_Up\_Defence.png

**Tiny Swords (Free Pack)/Units/Purple Units/Monk**

- Heal.png
- Heal\_Effect.png
- Idle.png
- Run.png

**Tiny Swords (Free Pack)/Units/Purple Units/Pawn**

- Pawn\_Idle Axe.png
- Pawn\_Idle Gold.png
- Pawn\_Idle Hammer.png
- Pawn\_Idle Knife.png
- Pawn\_Idle Meat.png
- Pawn\_Idle Pickaxe.png
- Pawn\_Idle Wood.png
- Pawn\_Idle.png
- Pawn\_Interact Axe.png
- Pawn\_Interact Hammer.png
- Pawn\_Interact Knife.png
- Pawn\_Interact Pickaxe.png
- Pawn\_Run Axe.png
- Pawn\_Run Gold.png
- Pawn\_Run Hammer.png
- Pawn\_Run Knife.png
- Pawn\_Run Meat.png
- Pawn\_Run Pickaxe.png
- Pawn\_Run Wood.png
- Pawn\_Run.png

**Tiny Swords (Free Pack)/Units/Purple Units/Warrior**

- Warrior\_Attack1.png
- Warrior\_Attack2.png
- Warrior\_Guard.png
- Warrior\_Idle.png
- Warrior\_Run.png

**Tiny Swords (Free Pack)/Units/Red Units/Archer**

- Archer\_Idle.png
- Archer\_Run.png
- Archer\_Shoot.png
- Arrow.png

**Tiny Swords (Free Pack)/Units/Red Units/Lancer**

- Lancer\_DownRight\_Attack.png
- Lancer\_DownRight\_Defence.png
- Lancer\_Down\_Attack.png
- Lancer\_Down\_Defence.png
- Lancer\_Idle.png
- Lancer\_Right\_Attack.png
- Lancer\_Right\_Defence.png
- Lancer\_Run.png
- Lancer\_UpRight\_Attack.png
- Lancer\_UpRight\_Defence.png
- Lancer\_Up\_Attack.png
- Lancer\_Up\_Defence.png

**Tiny Swords (Free Pack)/Units/Red Units/Monk**

- Heal.png
- Heal\_Effect.png
- Idle.png
- Run.png

**Tiny Swords (Free Pack)/Units/Red Units/Pawn**

- Pawn\_Idle Axe.png
- Pawn\_Idle Gold.png
- Pawn\_Idle Hammer.png
- Pawn\_Idle Knife.png
- Pawn\_Idle Meat.png
- Pawn\_Idle Pickaxe.png
- Pawn\_Idle Wood.png
- Pawn\_Idle.png
- Pawn\_Interact Axe.png
- Pawn\_Interact Hammer.png
- Pawn\_Interact Knife.png
- Pawn\_Interact Pickaxe.png
- Pawn\_Run Axe.png
- Pawn\_Run Gold.png
- Pawn\_Run Hammer.png
- Pawn\_Run Knife.png
- Pawn\_Run Meat.png
- Pawn\_Run Pickaxe.png
- Pawn\_Run Wood.png
- Pawn\_Run.png

**Tiny Swords (Free Pack)/Units/Red Units/Warrior**

- Warrior\_Attack1.png
- Warrior\_Attack2.png
- Warrior\_Guard.png
- Warrior\_Idle.png
- Warrior\_Run.png

**Tiny Swords (Free Pack)/Units/Units (aseprite in Blue only)**

- Archer.aseprite
- Lancer.aseprite
- Monk.aseprite
- Pawn.aseprite
- Warrior.aseprite

**Tiny Swords (Free Pack)/Units/Yellow Units/Archer**

- Archer\_Idle.png
- Archer\_Run.png
- Archer\_Shoot.png
- Arrow.png

**Tiny Swords (Free Pack)/Units/Yellow Units/Lancer**

- Lancer\_DownRight\_Attack.png
- Lancer\_DownRight\_Defence.png
- Lancer\_Down\_Attack.png
- Lancer\_Down\_Defence.png
- Lancer\_Idle.png
- Lancer\_Right\_Attack.png
- Lancer\_Right\_Defence.png
- Lancer\_Run.png
- Lancer\_UpRight\_Attack.png
- Lancer\_UpRight\_Defence.png
- Lancer\_Up\_Attack.png
- Lancer\_Up\_Defence.png

**Tiny Swords (Free Pack)/Units/Yellow Units/Monk**

- Heal.png
- Heal\_Effect.png
- Idle.png
- Run.png

**Tiny Swords (Free Pack)/Units/Yellow Units/Pawn**

- Pawn\_Idle Axe.png
- Pawn\_Idle Gold.png
- Pawn\_Idle Hammer.png
- Pawn\_Idle Knife.png
- Pawn\_Idle Meat.png
- Pawn\_Idle Pickaxe.png
- Pawn\_Idle Wood.png
- Pawn\_Idle.png
- Pawn\_Interact Axe.png
- Pawn\_Interact Hammer.png
- Pawn\_Interact Knife.png
- Pawn\_Interact Pickaxe.png
- Pawn\_Run Axe.png
- Pawn\_Run Gold.png
- Pawn\_Run Hammer.png
- Pawn\_Run Knife.png
- Pawn\_Run Meat.png
- Pawn\_Run Pickaxe.png
- Pawn\_Run Wood.png
- Pawn\_Run.png

**Tiny Swords (Free Pack)/Units/Yellow Units/Warrior**

- Warrior\_Attack1.png
- Warrior\_Attack2.png
- Warrior\_Guard.png
- Warrior\_Idle.png
- Warrior\_Run.png

## 11. Đối chiếu file project hiện tại với 2 zip (khớp tên không phân biệt hoa/thường)

### File project khớp tên trong zip

- `buildings/castle_blue.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle\_Blue.png
- `buildings/castle_destroyed.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle\_Destroyed.png
- `buildings/castle_purple.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle\_Purple.png
- `buildings/castle_red.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle\_Red.png
- `buildings/castle_yellow.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle\_Yellow.png
- `buildings/house_blue.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House\_Blue.png
- `buildings/house_construction.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House\_Construction.png
- `buildings/house_destroyed.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House\_Destroyed.png
- `buildings/house_purple.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House\_Purple.png
- `buildings/house_red.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House\_Red.png
- `buildings/house_yellow.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House\_Yellow.png
- `buildings/tower_blue.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/Tower/Tower\_Blue.png
- `buildings/tower_construction.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/Tower/Tower\_Construction.png
- `buildings/tower_destroyed.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/Tower/Tower\_Destroyed.png
- `buildings/tower_purple.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/Tower/Tower\_Purple.png
- `buildings/tower_red.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/Tower/Tower\_Red.png
- `buildings/tower_yellow.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Buildings/Tower/Tower\_Yellow.png
- `deco/rock1.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Terrain/Decorations/Rocks/Rock1.png
- `deco/rock2.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Terrain/Decorations/Rocks/Rock2.png
- `deco/tree.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Resources/Trees/Tree.png
- `fx/fire.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Effects/Fire/Fire.png
- `terrain/water.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Terrain/Water/Water.png
- `units/blue/archer_idle.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Archer\_Idle.png
- `units/blue/archer_run.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Archer\_Run.png
- `units/blue/archer_shoot.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Archer\_Shoot.png
- `units/blue/arrow.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Troops/Archer/Arrow/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Arrow.png
- `units/blue/pawn_idle.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn\_Idle.png
- `units/blue/pawn_run.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn\_Run.png
- `units/blue/warrior_idle.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior\_Idle.png
- `units/blue/warrior_run.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior\_Run.png
- `units/purple/archer_idle.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Archer\_Idle.png
- `units/purple/archer_run.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Archer\_Run.png
- `units/purple/archer_shoot.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Archer\_Shoot.png
- `units/purple/arrow.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Troops/Archer/Arrow/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Arrow.png
- `units/purple/pawn_idle.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn\_Idle.png
- `units/purple/pawn_run.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn\_Run.png
- `units/purple/warrior_idle.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior\_Idle.png
- `units/purple/warrior_run.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior\_Run.png
- `units/red/archer_idle.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Archer\_Idle.png
- `units/red/archer_run.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Archer\_Run.png
- `units/red/archer_shoot.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Archer\_Shoot.png
- `units/red/arrow.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Troops/Archer/Arrow/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Arrow.png
- `units/red/pawn_idle.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn\_Idle.png
- `units/red/pawn_run.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn\_Run.png
- `units/red/warrior_idle.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior\_Idle.png
- `units/red/warrior_run.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior\_Run.png
- `units/yellow/archer_idle.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Archer\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Archer\_Idle.png
- `units/yellow/archer_run.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Archer\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Archer\_Run.png
- `units/yellow/archer_shoot.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Archer\_Shoot.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Archer\_Shoot.png
- `units/yellow/arrow.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords.zip) Tiny Swords (Update 010)/Factions/Knights/Troops/Archer/Arrow/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Archer/Arrow.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Archer/Arrow.png
- `units/yellow/pawn_idle.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Pawn/Pawn\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn\_Idle.png
- `units/yellow/pawn_run.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Pawn/Pawn\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn\_Run.png
- `units/yellow/warrior_idle.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior\_Idle.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior\_Idle.png
- `units/yellow/warrior_run.png` — khớp tên (không phân biệt hoa/thường) với: (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Black Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior\_Run.png; (Tiny\_Swords\_\_Free\_Pack.zip) Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior\_Run.png

### File project KHÔNG khớp tên trong 2 zip

- `buildings/barracks_blue.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `buildings/barracks_purple.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `buildings/barracks_red.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `buildings/barracks_yellow.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `fx/explosion.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `resources/goldmine.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `resources/stone.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `terrain/tilemap.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/blue/pawn_axe.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/blue/pawn_pick.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/blue/pawn_run_gold.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/blue/pawn_run_wood.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/blue/warrior_attack.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/purple/pawn_axe.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/purple/pawn_pick.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/purple/pawn_run_gold.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/purple/pawn_run_wood.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/purple/warrior_attack.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/red/pawn_axe.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/red/pawn_pick.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/red/pawn_run_gold.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/red/pawn_run_wood.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/red/warrior_attack.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/yellow/pawn_axe.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/yellow/pawn_pick.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/yellow/pawn_run_gold.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/yellow/pawn_run_wood.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)
- `units/yellow/warrior_attack.png` — không khớp tên file nào trong 2 zip (đã đổi tên, cắt lại hoặc xử lý lại khi đưa vào project)