#!/usr/bin/env python3
"""Sinh sprite RUỘNG (farm) cho Tứ Thành Chiến.

Nguồn (đối chiếu ASSETS.md):
- ĐẤT: tile cỏ của Tiny Swords (assets/terrain/tilemap.png, tile (1,1)) —
  nhuộm hue xanh lá -> nâu đất, GIỮ nguyên texture vẽ tay của pack để ruộng
  không lạc phong cách. Thêm rãnh luống tối giữa các hàng cây.
- CÂY TRỒNG: Farm RPG FREE demo (Maeve) — Objects/Spring Crops.png, các ô
  16x16 theo GIAI ĐOẠN sinh trưởng: mầm -> lá -> chín. Ruộng hiển thị đúng
  giai đoạn theo tỉ lệ thịt còn lại:
    farm.png      (đầy,  >66%)  cây chín/lá to
    farm_mid.png  (33-66%)      cây lá vừa
    farm_low.png  (<33%)        mầm thưa
    farm_bare.png (đang xây / đất trống sau khi cạn / tàn tích) — chỉ còn đất.

Chạy: python3 tools/make_farm_art.py   (ghi vào assets/buildings/)
"""
import random
from PIL import Image

ROOT = "/home/hatch/workspace/thu-thanh-4v4-farm"
CROPS = "/home/hatch/workspace/user/assets/farm-rpg/extracted - Farm RPG FREE demo/Objects/Spring Crops.png"
OUT = ROOT + "/assets/buildings"

W, H = 160, 112
SOIL = (6, 8, W - 6, H - 6)  # x0, y0, x1, y1 của ô đất trong canvas


def make_soil() -> Image.Image:
    tile = Image.open(ROOT + "/assets/terrain/tilemap.png").convert("RGB")
    tile = tile.crop((64, 64, 128, 128))  # tile (1,1) = cỏ nền game đang dùng
    hsv = tile.convert("HSV")
    h, s, v = hsv.split()
    # Hue cỏ ~ (55..85)/255 -> dịch về nâu cam ~22/255; giữ S, giảm V chút.
    h = h.point(lambda x: (x - 28) % 256)
    s = s.point(lambda x: int(x * 0.88))
    v = v.point(lambda x: int(x * 0.8))
    soil_tile = Image.merge("HSV", (h, s, v)).convert("RGB")
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for x in range(SOIL[0], SOIL[2], 64):
        for y in range(SOIL[1], SOIL[3], 64):
            img.paste(soil_tile, (x, y))
    px = img.load()
    # Viền đất tối + góc bo kiểu pixel (cắt 3px ở 4 góc).
    for x in range(SOIL[0], SOIL[2]):
        for y in range(SOIL[1], SOIL[3]):
            edge = x - SOIL[0] < 3 or y - SOIL[1] < 3 or SOIL[2] - 1 - x < 3 or SOIL[3] - 1 - y < 3
            corner = (x - SOIL[0] + y - SOIL[1] < 4) or (SOIL[2] - 1 - x + y - SOIL[1] < 4) \
                or (x - SOIL[0] + SOIL[3] - 1 - y < 4) or (SOIL[2] - 1 - x + SOIL[3] - 1 - y < 4)
            if corner:
                px[x, y] = (0, 0, 0, 0)
            elif edge:
                r, g, b, a = px[x, y]
                px[x, y] = (int(r * 0.55), int(g * 0.55), int(b * 0.55), 255)
    # Rãnh luống: dải tối ngang giữa các hàng cây (hàng cây ở y = 18,40,62,84 +20px).
    for gy in (36, 58, 80):
        for x in range(SOIL[0] + 3, SOIL[2] - 3):
            for y in range(gy, gy + 3):
                r, g, b, a = px[x, y]
                if a:
                    px[x, y] = (int(r * 0.62), int(g * 0.62), int(b * 0.62), a)
    return img


def cell(sheet: Image.Image, col: int, row: int) -> Image.Image:
    return sheet.crop((col * 16, row * 16, col * 16 + 16, row * 16 + 16))


def compose(soil: Image.Image, sheet: Image.Image, cells: list, density: float, seed: int) -> Image.Image:
    img = soil.copy()
    rng = random.Random(seed)
    xs = [16 + i * 21 for i in range(6)]
    ys = [18, 40, 62, 84]
    for r, y in enumerate(ys):
        for c, x in enumerate(xs):
            if rng.random() > density:
                continue
            spr = cells[rng.randrange(len(cells))]
            spr = spr.resize((20, 20), Image.NEAREST)
            img.alpha_composite(spr, (x + rng.randint(-1, 1), y + rng.randint(-1, 1)))
    return img


def main() -> None:
    sheet = Image.open(CROPS).convert("RGBA")
    soil = make_soil()
    soil.save(OUT + "/farm_bare.png")
    sprouts = [cell(sheet, 2, 1), cell(sheet, 2, 5), cell(sheet, 1, 1)]
    leafy = [cell(sheet, 3, 1), cell(sheet, 3, 5), cell(sheet, 4, 5)]
    mature = [cell(sheet, 4, 1), cell(sheet, 5, 1), cell(sheet, 5, 5), cell(sheet, 4, 5)]
    compose(soil, sheet, sprouts, 0.5, 11).save(OUT + "/farm_low.png")
    compose(soil, sheet, leafy, 0.9, 22).save(OUT + "/farm_mid.png")
    compose(soil, sheet, mature, 1.0, 33).save(OUT + "/farm.png")
    print("farm art done")


if __name__ == "__main__":
    main()
