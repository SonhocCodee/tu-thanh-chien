#!/usr/bin/env python3
"""
GENERATOR.py — sinh asset cấp 2 + cấp 3 cho game Tứ Thành Chiến từ asset cấp 1.

Phương pháp: BIÊN TẬP TRÊN CHÍNH FILE CẤP 1 bằng ánh xạ bảng màu theo VAI TRÒ
(outline / màu phe / thép / gỗ / kem-da / ánh sáng) trong không gian HSV +
vẽ thêm chi tiết cấu trúc cho nhà (nền đá cấp 2/3, viền mái vàng + chóp vàng
cấp 3) và vùng chùm mũ vàng cấp 3 cho quân. Kích thước / số frame / điểm neo
giữ nguyên 100% so với cấp 1 — game chỉ việc đổi texture theo cấp.

Chạy:  python3 assets/upgrades/GENERATOR.py [--sample]
  (không tham số = sinh toàn bộ ma trận; --sample = chỉ bộ mẫu xanh dương)

Nguồn cấp 1:
  - nhà + pawn/warrior/archer: assets/buildings/, assets/units/ trong repo.
  - lancer: nhánh `nha-linh` của repo chính (git show) — giải nén vào
    /tmp/lancer_src/ nếu chưa có, vì ở commit nền 100bc65 lancer chưa vào main.
"""
import colorsys
import os
import subprocess
import sys
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "upgrades")
MAIN_REPO = os.path.expanduser("~/workspace/thu-thanh-4v4")
LANCER_SRC = "/tmp/lancer_src"

COLORS = ["blue", "purple", "red", "yellow"]
BUILDINGS = ["castle", "house", "barracks", "tower", "storehouse"]
UNIT_STRIPS = {
    "pawn": ["pawn_idle", "pawn_run", "pawn_axe", "pawn_pick", "pawn_knife",
             "pawn_run_wood", "pawn_run_gold", "pawn_run_meat"],
    "warrior": ["warrior_idle", "warrior_run", "warrior_attack"],
    "archer": ["archer_idle", "archer_run", "archer_shoot", "arrow"],
    "lancer": ["lancer_idle", "lancer_run", "lancer_attack"],
}
FRAME_W = {"pawn": 192, "warrior": 192, "archer": 192, "lancer": 320}

# Hàng vác (cục vàng / thịt) — màu giống hệt mọi phe, KHÔNG phải đồ của phe:
# giữ nguyên ở mọi cấp (xem MANIFEST).
PROTECTED = {(0xCE, 0xA5, 0x54), (0xB4, 0x50, 0x76), (0xEF, 0x51, 0x5C), (0xF9, 0x85, 0x6C)}

# Ramp vàng cấp 3 (họ vàng Tiny Swords)
GOLD_SHADOW = (0xA8, 0x6E, 0x14)
GOLD = (0xEA, 0xA7, 0x2E)
GOLD_LIGHT = (0xFF, 0xCF, 0x4D)
GOLD_PALE = (0xFF, 0xE8, 0x9A)

# Ramp đá cho nền móng (theo độ sáng tăng dần)
STONE_RAMP = [(0x4A, 0x50, 0x60), (0x5E, 0x65, 0x76), (0x7D, 0x84, 0x95), (0x9A, 0xA1, 0xAE), (0xB7, 0xBD, 0xC7)]


def gold_by_v(v):
    if v < 0.80:
        return GOLD
    if v < 0.90:
        return GOLD_LIGHT
    return GOLD_PALE


def in_band(h, bands):
    return any(lo <= h <= hi for lo, hi in bands)


FACTION_BANDS = {
    "blue": [(142, 205), (212, 262)],
    "purple": [(245, 282), (305, 352)],
    "red": [(315, 360), (0, 18)],
    "yellow": [(36, 64)],
}


def is_faction(h, s, v, faction):
    """Màu phe theo phe. Vài nới lỏng riêng đã căn theo palette thật của pack."""
    if faction == "yellow":
        return in_band(h, FACTION_BANDS["yellow"]) and s > 0.40 and v > 0.45
    if faction == "purple" and in_band(h, [(318, 352)]) and s > 0.17 and v > 0.75:
        return True  # tầng sáng hồng của mái tím (S thấp hơn ngưỡng chung)
    return in_band(h, FACTION_BANDS[faction]) and s > 0.30 and v > 0.30


def classify(r, g, b, faction):
    """Trả về vai trò của 1 màu. Thứ tự kiểm tra quan trọng."""
    if (r, g, b) in PROTECTED:
        return "protected"
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    H = h * 360.0
    if v <= 0.20:
        return "outline"
    if s <= 0.16 and v >= 0.80:
        return "shine"          # ánh trắng: lưỡi kiếm bóng, lông tên, điểm sáng
    if is_faction(H, s, v, faction):
        return "faction"
    if 30 <= H <= 62 and s <= 0.38 and v >= 0.72:
        return "cream"          # da / tường kem / vải sáng
    if 10 <= H <= 44 and s > 0.17 and v > 0.18:
        return "wood"           # gỗ + da nâu + mũ nâu của nông dân (trước steel:
                                # nâu ấm ít bão hoà không phải thép)
    if s <= 0.32 and 0.28 < v < 0.97:
        return "steel"          # thép + đá xám-teal phong hoá (cùng họ xám lạnh)
    return "keep"


def shift_hsv(r, g, b, dh=0.0, s_mul=1.0, v_mul=1.0, h_target=None, h_blend=0.0):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if h_target is not None and 120.0 <= h * 360.0 <= 280.0:
        # Chỉ xoay hue cho màu đã lạnh; màu ấm ít bão hoà (da thuộc, xám ấm)
        # mà xoay sẽ vòng qua 0/360 thành tím-hồng (lỗi đã gặp ở mũ nông dân).
        th = h_target / 360.0
        d = (th - h + 0.5) % 1.0 - 0.5
        h = (h + d * h_blend) % 1.0
    h = (h + dh / 360.0) % 1.0
    s = max(0.0, min(1.0, s * s_mul))
    v = max(0.0, min(1.0, v * v_mul))
    rr, gg, bb = colorsys.hsv_to_rgb(h, s, v)
    return (round(rr * 255), round(gg * 255), round(bb * 255))


def transform_color(r, g, b, role, level, kind):
    """kind: 'unit' | 'building'. level: 2 | 3."""
    if role in ("outline", "protected", "keep"):
        return (r, g, b)
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if level == 2:
        if role == "faction":
            return shift_hsv(r, g, b, s_mul=1.10, v_mul=0.94 if v < 0.5 else 0.905)
        if role == "steel":
            return shift_hsv(r, g, b, s_mul=0.85, v_mul=1.04 if v >= 0.72 else (1.0 if v >= 0.5 else 0.96),
                             h_target=212, h_blend=0.35)
        if role == "wood":
            return shift_hsv(r, g, b, s_mul=0.62, v_mul=0.94)
        if role == "cream":
            return shift_hsv(r, g, b, s_mul=0.82 if kind == "building" else 1.0, v_mul=0.99)
        if role == "shine":
            return shift_hsv(r, g, b, v_mul=1.02)
    else:  # level 3
        if role == "faction":
            if v >= 0.72 and kind == "unit":
                return gold_by_v(v)             # tầng sáng của quân -> vàng (chùm mũ, viền khiên, cờ)
            if v < 0.5:
                return shift_hsv(r, g, b, s_mul=1.15, v_mul=0.86)
            if v < 0.72:
                return shift_hsv(r, g, b, s_mul=1.22, v_mul=0.90)
            return shift_hsv(r, g, b, s_mul=1.18, v_mul=1.00)  # nhà: tầng sáng giữ màu phe, đậm hơn
        if role == "steel":
            if v >= 0.72:
                return GOLD if v < 0.85 else GOLD_LIGHT   # thép sáng -> vàng (lưỡi/mũi giáo/nón)
            if v >= 0.5:
                return shift_hsv(r, g, b, s_mul=0.80, v_mul=0.90, h_target=215, h_blend=0.5)
            return shift_hsv(r, g, b, s_mul=0.70, v_mul=0.82, h_target=218, h_blend=0.5)  # gunmetal
        if role == "wood":
            return shift_hsv(r, g, b, dh=-3, s_mul=0.78, v_mul=0.80 if v >= 0.45 else 0.85)
        if role == "cream":
            return shift_hsv(r, g, b, s_mul=0.90 if kind == "building" else 1.0, v_mul=1.00)
        if role == "shine":
            return GOLD_PALE    # giữ thật nhạt: vệt sáng vũ khí / vệt vung rìu
    return (r, g, b)


def palette_pass(im, faction, level, kind):
    """Ánh xạ màu theo vai trò cho toàn ảnh (cache theo màu -> quyết định nhất quán)."""
    cache = {}
    out = Image.new("RGBA", im.size)
    src = im.load()
    dst = out.load()
    W, H = im.size
    for y in range(H):
        for x in range(W):
            r, g, b, a = src[x, y]
            if a == 0:
                dst[x, y] = (r, g, b, a)
                continue
            key = (r, g, b)
            nv = cache.get(key)
            if nv is None:
                nv = transform_color(r, g, b, classify(r, g, b, faction), level, kind)
                cache[key] = nv
            dst[x, y] = (nv[0], nv[1], nv[2], a)
    return out


def stone_base(orig, im, faction, level):
    """Nền móng đá cho nhà. Mặt nạ tính trên ảnh GỐC (vai trò gỗ/kem/màu phe),
    áp lên ảnh đã qua palette. Chỉ cột "đặc" (cao >= 55% trung vị) mới làm —
    tránh cột bóng đổ/cọc nhọn lơ lửng thành vệt đá rời; bỏ 2 pixel đáy nhất
    của mỗi cột để mép silhouette chạm đất giữ nguyên như cấp 1."""
    W, H = im.size
    op = orig.load()
    px = im.load()
    mul = (0.94 if level == 3 else 1.0) * 0.88  # nén ramp về phía sẫm: đá nền
    # phải đọc như móng chìm, không phải vệt sáng (cọc nhọn của thành bị trắng
    # như sương khi lấy các bậc sáng nhất của ramp).
    counts = []
    cols = []
    for x in range(W):
        col = [y for y in range(H) if op[x, y][3] == 255]
        cols.append(col)
        if col:
            counts.append(len(col))
    if not counts:
        return im
    counts.sort()
    median = counts[len(counts) // 2]
    for x in range(W):
        col = cols[x]
        if len(col) < max(6, 0.55 * median):
            continue
        k = max(2, min(14, round(len(col) * 0.11)))
        for y in col[-(k + 2):-2] if len(col) > k + 2 else []:
            r, g, b, a = op[x, y]
            if classify(r, g, b, faction) not in ("wood", "cream", "faction"):
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            idx = min(3, int(v * 3.4))
            sr, sg, sb = STONE_RAMP[idx]
            px[x, y] = (round(sr * mul), round(sg * mul), round(sb * mul), a)
    return im


def gold_roofline(im):
    """Nhà cấp 3: 2 pixel đặc trên cùng của mỗi cột (mép mái / đỉnh tường
    thành) nếu không phải outline -> vàng."""
    W, H = im.size
    px = im.load()
    for x in range(W):
        done = 0
        for y in range(H):
            r, g, b, a = px[x, y]
            if a > 200:
                h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                if v > 0.20:
                    px[x, y] = gold_by_v(v) + (a,)
                    done += 1
                    if done >= 2:
                        break
    return im


def gold_finial(im):
    """Nhà cấp 3: chóp vàng ở đỉnh cao nhất giữa nhà (kim cương + thân nối mái)."""
    W, H = im.size
    px = im.load()
    xs = [x for x in range(W) if any(px[x, y][3] > 200 for y in range(H))]
    if not xs:
        return im
    cx = (min(xs) + max(xs)) // 2
    topy = None
    for y in range(H):
        if any(px[x, y][3] > 200 for x in range(max(0, cx - 2), min(W, cx + 3))):
            topy = y
            break
    if topy is None or topy < 7:
        return im
    def put(x, y, col):
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = col + (255,)
    put(cx, topy - 1, GOLD_SHADOW)
    put(cx, topy - 2, GOLD_SHADOW)
    put(cx, topy - 3, GOLD)
    put(cx - 2, topy - 4, GOLD_SHADOW)
    put(cx - 1, topy - 4, GOLD)
    put(cx, topy - 4, GOLD_LIGHT)
    put(cx + 1, topy - 4, GOLD)
    put(cx + 2, topy - 4, GOLD_SHADOW)
    put(cx, topy - 5, GOLD)
    put(cx, topy - 7, GOLD_PALE)
    return im


def process_building(src_path, faction, level, dst_path):
    im = Image.open(src_path).convert("RGBA")
    out = palette_pass(im, faction, level, "building")
    out = stone_base(im, out, faction, level)
    if level == 3:
        out = gold_roofline(out)
        out = gold_finial(out)
    out.save(dst_path)


def process_unit(src_path, faction, level, frame_w, dst_path):
    im = Image.open(src_path).convert("RGBA")
    out = palette_pass(im, faction, level, "unit")
    # Nông dân không có chùm mũ/huy hiệu -> bỏ qua vùng chóp vàng (tránh nhuộm
    # cả áo vì thân hình nhỏ, dải 12px phủ gần hết người).
    is_pawn = os.path.basename(src_path).startswith("pawn")
    if level == 3 and frame_w and im.width % frame_w == 0 and not is_pawn:
        # Vùng chùm mũ: trong từng frame, các pixel MÀU PHE (trên ảnh gốc) nằm ở
        # dải 10px đầu tiên tính từ pixel màu phe cao nhất của nhân vật -> vàng.
        src = im.load()
        dst = out.load()
        n = im.width // frame_w
        for f in range(n):
            x0 = f * frame_w
            ftop = None
            for y in range(im.height):
                hit = False
                for x in range(x0, x0 + frame_w):
                    r, g, b, a = src[x, y]
                    if a > 200 and classify(r, g, b, faction) == "faction":
                        hit = True
                        break
                if hit:
                    ftop = y
                    break
            if ftop is None:
                continue
            for y in range(ftop, min(im.height, ftop + 12)):
                for x in range(x0, x0 + frame_w):
                    r, g, b, a = src[x, y]
                    if a > 200 and classify(r, g, b, faction) == "faction":
                        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                        dst[x, y] = gold_by_v(v) + (a,)
    out.save(dst_path)


def ensure_lancer_src():
    if os.path.isdir(LANCER_SRC) and len(os.listdir(LANCER_SRC)) >= 12:
        return
    os.makedirs(LANCER_SRC, exist_ok=True)
    for c in COLORS:
        for s in ("idle", "run", "attack"):
            data = subprocess.run(
                ["git", "-C", MAIN_REPO, "show", f"nha-linh:assets/units/{c}/lancer_{s}.png"],
                capture_output=True, check=True).stdout
            with open(os.path.join(LANCER_SRC, f"{c}_lancer_{s}.png"), "wb") as fp:
                fp.write(data)


def l1_path(kind, faction, name):
    if kind == "building":
        return os.path.join(ROOT, "assets", "buildings", f"{name}_{faction}.png")
    if name.startswith("lancer"):
        return os.path.join(LANCER_SRC, f"{faction}_{name}.png")
    return os.path.join(ROOT, "assets", "units", faction, f"{name}.png")


def main():
    sample = "--sample" in sys.argv
    ensure_lancer_src()
    factions = ["blue"] if sample else COLORS
    btypes = BUILDINGS if not sample else ["house", "castle", "tower"]
    utypes = UNIT_STRIPS if not sample else {"warrior": UNIT_STRIPS["warrior"],
                                             "pawn": ["pawn_idle", "pawn_axe"],
                                             "archer": ["archer_idle"],
                                             "lancer": ["lancer_idle", "lancer_attack"]}
    made = []
    for faction in factions:
        for b in btypes:
            for lv in (2, 3):
                dst = os.path.join(OUT, "buildings", f"{b}_{faction}_lv{lv}.png")
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                process_building(l1_path("building", faction, b), faction, lv, dst)
                made.append(dst)
        for utype, strips in utypes.items():
            for name in strips:
                fw = None if name == "arrow" else FRAME_W[utype]
                for lv in (2, 3):
                    dst = os.path.join(OUT, "units", faction, f"{name}_lv{lv}.png")
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    process_unit(l1_path("unit", faction, name), faction, lv, fw, dst)
                    made.append(dst)
    print(f"Đã sinh {len(made)} file vào {OUT}")


if __name__ == "__main__":
    main()
