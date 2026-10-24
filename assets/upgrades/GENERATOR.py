#!/usr/bin/env python3
"""
GENERATOR.py — sinh asset cấp 2 + cấp 3 cho game Tứ Thành Chiến từ asset cấp 1.

VÒNG 2 (đậm tay): vòng 1 chỉ ánh xạ bảng màu nên các cấp nhìn gần như nhau.
Vòng 2 giữ nền ánh xạ màu theo vai trò (HSV) của vòng 1 nhưng CỘNG THÊM
chi tiết CẤU TRÚC vẽ bằng code theo đúng nét/bảng màu pack:

NHÀ:
- Móng đá CAO gấp đôi (20-24% chiều cao cột) + gờ sáng trên móng + mạch vữa.
- Cờ tam giác màu phe cắm ở đỉnh (cấp 2 nhỏ; cấp 3 to hơn, viền vàng, chóp
  cầu vàng trên cọc).
- Cấp 3: dải vàng LIỀN 3px dọc mép mái/tường (chỉ cột "vành", không rắc
  vào sàn trong), chóp nhọn vàng lớn ở đỉnh chính (+2 chóp phụ cho thành),
  huy hiệu khiên vàng trên cổng, ống khói đá (nhà dân/kho — cấp 3 nắp vàng),
  tháp: vành đai thép quanh thân (cấp 3 viền vàng), doanh trại: 2 biểu ngữ
  treo hai bên cổng, thành: tua vàng ở chân 2 biểu ngữ sẵn có.
QUÂN (theo từng frame, mặt nạ tính trên ảnh gốc):
- Kiếm sĩ/cung thủ: chùm mũ MỌC CAO thêm (cấp 2 +3px màu phe; cấp 3 +5px và
  nhuộm vàng toàn bộ chùm). Lính giáo: cờ giáo PHÌNH to (giãn nở theo mặt nạ
  cờ — cụm màu phe tách rời nằm sát giáo), cấp 3 cờ vàng.
- Cấp 3: vũ khí mỏng (lưỡi kiếm/mũi giáo/đầu tên — pixel thép "mỏng") mạ
  vàng toàn bộ; khiên kiếm sĩ: phần màu phe -> vàng, phần kem -> ánh vàng;
  cung của cung thủ (đường cong tối mỏng) -> vàng đồng.
- Nông dân (nhóm nhạt nhất vòng 1 — kéo lên): băng đầu màu phe ở mép mũ
  (cấp 2+), thắt lưng da + khoá thép (cấp 2) / khoá vàng (cấp 3), cấp 3 mũ
  rơm -> vàng nhạt + viền cổ áo vàng + đầu công cụ mạ vàng toàn bộ.

Ràng buộc giữ nguyên: cùng kích thước/số frame/điểm neo như cấp 1; pixel
đặc mới chỉ nằm trong canvas và phải DÍNH vào silhouette gốc (cờ/chóp mọc
từ đỉnh, chùm mũ mọc từ mũ...). Hàng vác của nông dân được bảo vệ.

Chạy:  python3 assets/upgrades/GENERATOR.py [--sample]
Nguồn lancer: nhánh `nha-linh` của repo chính (git show) -> /tmp/lancer_src/.
"""
import colorsys
import os
import subprocess
import sys
from collections import deque

import numpy as np
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

PROTECTED = {(0xCE, 0xA5, 0x54), (0xB4, 0x50, 0x76), (0xEF, 0x51, 0x5C), (0xF9, 0x85, 0x6C)}

GOLD_SHADOW = (0xA8, 0x6E, 0x14)
GOLD = (0xEA, 0xA7, 0x2E)
GOLD_LIGHT = (0xFF, 0xCF, 0x4D)
GOLD_PALE = (0xFF, 0xE8, 0x9A)
# Phe vàng cấp 3: vàng trắng sáng hơn để tách khỏi màu phe + bóng đồng sâu.
GOLD_Y = {"shadow": (0x8A, 0x5A, 0x10), "mid": (0xF2, 0xC1, 0x4E),
          "light": (0xFF, 0xE8, 0x9A), "pale": (0xFF, 0xF6, 0xD8)}

STONE_RAMP = [(0x4A, 0x50, 0x60), (0x5E, 0x65, 0x76), (0x7D, 0x84, 0x95), (0x9A, 0xA1, 0xAE), (0xB7, 0xBD, 0xC7)]
STEEL_RAMP = [(0x3E, 0x46, 0x54), (0x62, 0x6E, 0x7E), (0x93, 0xA1, 0xB1), (0xC3, 0xCD, 0xD9), (0xE8, 0xEE, 0xF4)]
OUTLINE_DARK = (0x2A, 0x2E, 0x3A)


def gold_ramp(faction, level):
    if faction == "yellow" and level == 3:
        return GOLD_Y["shadow"], GOLD_Y["mid"], GOLD_Y["light"], GOLD_Y["pale"]
    return GOLD_SHADOW, GOLD, GOLD_LIGHT, GOLD_PALE


def gold_by_v(v, faction="blue", level=3):
    sh, mid, light, pale = gold_ramp(faction, level)
    if v < 0.80:
        return mid
    if v < 0.90:
        return light
    return pale


def in_band(h, bands):
    return any(lo <= h <= hi for lo, hi in bands)


FACTION_BANDS = {
    "blue": [(142, 205), (212, 262)],
    "purple": [(245, 282), (305, 352)],
    "red": [(315, 360), (0, 18)],
    "yellow": [(36, 64)],
}


def is_faction(h, s, v, faction):
    if faction == "yellow":
        return in_band(h, FACTION_BANDS["yellow"]) and s > 0.40 and v > 0.45
    if faction == "purple" and in_band(h, [(318, 352)]) and s > 0.17 and v > 0.75:
        return True
    return in_band(h, FACTION_BANDS[faction]) and s > 0.30 and v > 0.30


def classify(r, g, b, faction):
    if (r, g, b) in PROTECTED:
        return "protected"
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    H = h * 360.0
    if v <= 0.20:
        return "outline"
    if s <= 0.16 and v >= 0.80:
        return "shine"
    if is_faction(H, s, v, faction):
        return "faction"
    if 30 <= H <= 62 and s <= 0.38 and v >= 0.72:
        return "cream"
    if 10 <= H <= 44 and s > 0.17 and v > 0.18:
        return "wood"
    if s <= 0.32 and 0.28 < v < 0.97:
        return "steel"
    return "keep"


def shift_hsv(r, g, b, dh=0.0, s_mul=1.0, v_mul=1.0, h_target=None, h_blend=0.0):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if h_target is not None and 120.0 <= h * 360.0 <= 280.0:
        th = h_target / 360.0
        d = (th - h + 0.5) % 1.0 - 0.5
        h = (h + d * h_blend) % 1.0
    h = (h + dh / 360.0) % 1.0
    s = max(0.0, min(1.0, s * s_mul))
    v = max(0.0, min(1.0, v * v_mul))
    rr, gg, bb = colorsys.hsv_to_rgb(h, s, v)
    return (round(rr * 255), round(gg * 255), round(bb * 255))


def transform_color(r, g, b, role, level, kind, faction="blue"):
    if role in ("outline", "protected", "keep"):
        return (r, g, b)
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if level == 2:
        if role == "faction":
            return shift_hsv(r, g, b, s_mul=1.10, v_mul=0.94 if v < 0.5 else 0.905)
        if role == "steel":
            # Vòng 2: tăng tương phản thép — mảng tối sẫm hơn, mảng sáng vọt
            # lên như thép đánh bóng (giáp đọc thành từng mảng rõ).
            if v >= 0.72:
                return shift_hsv(r, g, b, s_mul=0.80, v_mul=1.10, h_target=212, h_blend=0.35)
            if v >= 0.5:
                return shift_hsv(r, g, b, s_mul=0.85, v_mul=1.02, h_target=212, h_blend=0.35)
            return shift_hsv(r, g, b, s_mul=0.85, v_mul=0.90, h_target=212, h_blend=0.35)
        if role == "wood":
            return shift_hsv(r, g, b, s_mul=0.62, v_mul=0.94)
        if role == "cream":
            return shift_hsv(r, g, b, s_mul=0.82 if kind == "building" else 1.0, v_mul=0.99)
        if role == "shine":
            return shift_hsv(r, g, b, v_mul=1.02)
    else:  # level 3
        if role == "faction":
            if v >= 0.72 and kind == "unit":
                return gold_by_v(v, faction, 3)
            if v < 0.5:
                return shift_hsv(r, g, b, s_mul=1.15, v_mul=0.86)
            if v < 0.72:
                return shift_hsv(r, g, b, s_mul=1.22, v_mul=0.90)
            return shift_hsv(r, g, b, s_mul=1.18, v_mul=1.00)
        if role == "steel":
            if v >= 0.72:
                sh, mid, light, pale = gold_ramp(faction, 3)
                return mid if v < 0.85 else light
            if v >= 0.5:
                return shift_hsv(r, g, b, s_mul=0.80, v_mul=0.90, h_target=215, h_blend=0.5)
            return shift_hsv(r, g, b, s_mul=0.70, v_mul=0.82, h_target=218, h_blend=0.5)
        if role == "wood":
            return shift_hsv(r, g, b, dh=-3, s_mul=0.78, v_mul=0.80 if v >= 0.45 else 0.85)
        if role == "cream":
            return shift_hsv(r, g, b, s_mul=0.90 if kind == "building" else 1.0, v_mul=1.00)
        if role == "shine":
            return gold_ramp(faction, 3)[3]
    return (r, g, b)


def palette_pass(im, faction, level, kind):
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
                nv = transform_color(r, g, b, classify(r, g, b, faction), level, kind, faction)
                cache[key] = nv
            dst[x, y] = (nv[0], nv[1], nv[2], a)
    return out


# ---------------------------------------------------------------- numpy masks
R_OUTLINE, R_FACTION, R_STEEL, R_WOOD, R_CREAM, R_SHINE, R_PROT, R_KEEP = range(8)


def role_map(im, faction):
    """Bản đồ vai trò bằng numpy (xấp xỉ classify() scalar — chỉ dùng làm
    mặt nạ cho các phép cấu trúc; màu thật vẫn do palette_pass quyết)."""
    a = np.asarray(im).astype(np.float32) / 255.0
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    mx = np.max(a[..., :3], axis=-1)
    mn = np.min(a[..., :3], axis=-1)
    d = mx - mn
    h = np.zeros_like(mx)
    nz = d > 1e-6
    idx = nz & (mx == r)
    h[idx] = ((g - b)[idx] / d[idx]) % 6
    idx = nz & (mx == g)
    h[idx] = (b - r)[idx] / d[idx] + 2
    idx = nz & (mx == b)
    h[idx] = (r - g)[idx] / d[idx] + 4
    H = h * 60.0
    S = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    V = mx
    solid = al > 0.78
    role = np.full(mx.shape, R_KEEP, dtype=np.uint8)
    role[solid & (V <= 0.20)] = R_OUTLINE
    role[solid & (S <= 0.16) & (V >= 0.80)] = R_SHINE
    fac = np.zeros_like(solid)
    for lo, hi in FACTION_BANDS[faction]:
        fac |= (H >= lo) & (H <= hi)
    if faction == "yellow":
        fac &= (S > 0.40) & (V > 0.45)
    else:
        fac &= (S > 0.30) & (V > 0.30)
        if faction == "purple":
            fac |= (H >= 318) & (H <= 352) & (S > 0.17) & (V > 0.75)
    role[solid & fac & (role == R_KEEP)] = R_FACTION
    role[solid & (H >= 30) & (H <= 62) & (S <= 0.38) & (V >= 0.72) & (role == R_KEEP)] = R_CREAM
    role[solid & (H >= 10) & (H <= 44) & (S > 0.17) & (V > 0.18) & (role == R_KEEP)] = R_WOOD
    role[solid & (S <= 0.32) & (V > 0.28) & (V < 0.97) & (role == R_KEEP)] = R_STEEL
    prot = np.zeros_like(solid)
    for pr, pg, pb in PROTECTED:
        prot |= (np.asarray(im)[..., 0] == pr) & (np.asarray(im)[..., 1] == pg) & (np.asarray(im)[..., 2] == pb)
    role[solid & prot] = R_PROT
    role[~solid] = R_KEEP
    return role


def components(mask):
    """Gán nhãn thành phần liên thông 4 hướng của mặt nạ bool. Trả về
    (labels, list[(area, cx, cy, x0, y0, x1, y1)])."""
    H, W = mask.shape
    lab = -np.ones((H, W), dtype=np.int32)
    comps = []
    ys, xs = np.nonzero(mask)
    for sy, sx in zip(ys.tolist(), xs.tolist()):
        if lab[sy, sx] >= 0:
            continue
        cid = len(comps)
        q = deque([(sy, sx)])
        lab[sy, sx] = cid
        pts = []
        while q:
            y, x = q.popleft()
            pts.append((y, x))
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < H and 0 <= nx < W and lab[ny, nx] < 0 and mask[ny, nx]:
                    lab[ny, nx] = cid
                    q.append((ny, nx))
        arr = np.array(pts)
        comps.append((len(pts), float(arr[:, 1].mean()), float(arr[:, 0].mean()),
                      int(arr[:, 1].min()), int(arr[:, 0].min()),
                      int(arr[:, 1].max()), int(arr[:, 0].max())))
    return lab, comps


def faction_shades(im, faction, qs=(0.18, 0.5, 0.88)):
    """3 tầng màu phe (sẫm/trung/sáng) trích từ chính ảnh gốc — vẽ chi tiết
    mới bằng đúng màu của phe đó."""
    roles = role_map(im, faction)
    arr = np.asarray(im)
    cols, counts = np.unique(arr[roles == R_FACTION].reshape(-1, 4), axis=0, return_counts=True)
    if len(cols) == 0:
        return (60, 60, 160), (90, 90, 210), (140, 160, 255)
    v = cols[:, :3].max(axis=1).astype(np.float32)
    order = np.argsort(v)
    cols, v = cols[order], v[order]
    w = counts[order].astype(np.float32)
    cw = np.cumsum(w) / w.sum()
    def pick(q):
        i = int(np.searchsorted(cw, q))
        c = cols[min(i, len(cols) - 1)]
        return (int(c[0]), int(c[1]), int(c[2]))
    return pick(qs[0]), pick(qs[1]), pick(qs[2])


def col_tops(arr):
    """y đặc đầu tiên của mỗi cột (alpha > 200), -1 nếu cột trống."""
    solid = arr[..., 3] > 200
    H, W = solid.shape
    tops = np.full(W, -1, dtype=int)
    for x in range(W):
        col = np.nonzero(solid[:, x])[0]
        if len(col):
            tops[x] = int(col[0])
    return tops


# ---------------------------------------------------------------- vẽ chi tiết
def put(px, W, H, x, y, col):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = (col[0], col[1], col[2], 255)


def draw_flag(px, W, H, pole_x, base_y, pole_h, flag_len, flag_h, shades, faction, level):
    """Cờ tam giác màu phe trên cọc gỗ, ngọn hướng phải. Cấp 3: viền vàng +
    cầu vàng trên đỉnh cọc. base_y = y đỉnh công trình (cọc mọc lên trên)."""
    dark, mid, light = shades
    sh, gm, gl, gp = gold_ramp(faction, level)
    top = base_y - pole_h
    # cọc: 2px — trái outline, phải gỗ sẫm
    for y in range(top, base_y + 2):
        put(px, W, H, pole_x, y, OUTLINE_DARK)
        put(px, W, H, pole_x + 1, y, (0x6E, 0x4F, 0x30) if level < 3 else (0x59, 0x40, 0x24))
    if level == 3:
        for yy in (top - 2, top - 1):
            for xx in (pole_x, pole_x + 1):
                put(px, W, H, xx, yy, gl if yy == top - 2 else gm)
    # lá cờ: tam giác, cạnh đứng sát cọc, nhọn sang phải ở hàng giữa
    fy = top + (2 if level == 3 else 1)
    mid_row = (flag_h - 1) / 2.0
    for dy in range(flag_h):
        frac = 1.0 - abs(dy - mid_row) / (mid_row + 0.55)
        ln = max(1, int(round(flag_len * frac)))
        for dx in range(ln):
            x = pole_x + 2 + dx
            y = fy + dy
            edge = dx >= ln - 1 or dy == 0 or dy == flag_h - 1
            if level == 3 and edge:
                col = gm if dy > mid_row else gl
            elif dy == 0:
                col = light
            elif dy >= flag_h - 2:
                col = dark
            else:
                col = mid
            put(px, W, H, x, y, col)


def draw_spire(px, W, H, cx, base_y, stem_h, dia_w, faction, level):
    """Chóp nón vàng (vòng 2 sửa: kim cương nhỏ đọc như tia lửa — thay bằng
    NÓN tam giác đặc): chân rộng dia_w, cao ~dia_w+4, trái sẫm/giữa sáng/
    phải trung, cầu sáng ở đỉnh, thân 3px cắm vào mái."""
    sh, gm, gl, gp = gold_ramp(faction, level)
    for y in range(base_y - stem_h, base_y + 2):
        put(px, W, H, cx - 1, y, sh)
        put(px, W, H, cx, y, gm)
        put(px, W, H, cx + 1, y, sh)
    cone_h = dia_w + 4
    tip_y = base_y - stem_h - cone_h + 1
    for i in range(cone_h):
        y = tip_y + i
        wid = int(round((i / max(1, cone_h - 1)) * (dia_w // 2)))
        for dx in range(-wid, wid + 1):
            if dx <= -wid + (1 if wid > 1 else 0):
                col = sh
            elif dx == 0:
                col = gl
            elif dx >= wid - (1 if wid > 2 else 0):
                col = gm
            else:
                col = gm if i % 2 else gl
            put(px, W, H, cx + dx, y, col)
    put(px, W, H, cx, tip_y - 1, gp)


def draw_shield(px, W, H, cx, cy, shades, faction, level, w=11, h=13):
    """Huy hiệu khiên: viền vàng, ruột màu phe, gươm vàng dọc giữa."""
    dark, mid, light = shades
    sh, gm, gl, gp = gold_ramp(faction, level)
    widths = []
    for i in range(h):
        t = i / max(1, h - 1)
        widths.append(max(1, int(round((w / 2) * (1.0 if t < 0.55 else 1.0 - (t - 0.55) / 0.45 * 0.92)))))
    for i, hw in enumerate(widths):
        y = cy - h // 2 + i
        for dx in range(-hw, hw + 1):
            edge = abs(dx) >= hw - (0 if i < 2 else 0) or i == 0
            if dx == 0 and 1 <= i <= h - 3:
                col = gl  # lưỡi gươm
            elif edge or i == 0:
                col = gm if i % 2 == 0 else sh
            else:
                col = mid if (dx + i) % 2 == 0 else dark
            put(px, W, H, cx + dx, y, col)
    # chuôi gươm ngang
    for dx in range(-2, 3):
        put(px, W, H, cx + dx, cy - h // 2 + 2, gl)


def draw_chimney(px, W, H, tops, cx, faction, level):
    """Ống khói đá ngồi trên sườn mái (nhà dân/kho). Cấp 3 thêm nắp vàng."""
    w2 = 4
    xs = [x for x in range(cx - w2, cx + w2 + 1) if 0 <= x < W and tops[x] >= 0]
    if not xs:
        return
    base = min(tops[x] for x in xs)
    top = base - 11
    for x in range(cx - w2, cx + w2 + 1):
        for y in range(top, base + 3):
            if y == top or y == top + 1:
                col = (0x33, 0x2E, 0x28)  # miệng khói
            elif level == 3 and y == top + 2:
                col = gold_ramp(faction, 3)[1]
            elif x in (cx - w2, cx + w2):
                col = STONE_RAMP[0]
            else:
                col = STONE_RAMP[1 + ((x + y) % 3 == 0)]
            put(px, W, H, x, y, col)


# ---------------------------------------------------------------- nhà
def stone_base2(orig, im, faction, level):
    """Móng đá CAO (vòng 2): 20% (cấp 2) / 24% (cấp 3) chiều cao cột, gờ
    sáng ở mép trên, mạch vữa sẫm mỗi 6 hàng. Như vòng 1: chỉ cột đủ cao,
    trừ 2px đáy nhất để mép chạm đất không đổi."""
    W, H = im.size
    op = orig.load()
    px = im.load()
    mul = (0.94 if level == 3 else 1.0) * 0.88
    frac = 0.24 if level == 3 else 0.20
    counts, cols = [], []
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
        k = max(3, min(30, round(len(col) * frac)))
        zone = col[-(k + 2):-2] if len(col) > k + 2 else []
        for i, y in enumerate(zone):
            r, g, b, a = op[x, y]
            if classify(r, g, b, faction) not in ("wood", "cream", "faction"):
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            idx = min(3, int(v * 3.4))
            sr, sg, sb = STONE_RAMP[idx]
            f = mul
            if i == 0:
                sr, sg, sb = STONE_RAMP[4]  # gờ móng sáng
                f = 1.0
            elif (y % 6) == 3:
                f = mul * 0.74  # mạch vữa
            px[x, y] = (round(sr * f), round(sg * f), round(sb * f), a)
    return im


def gold_rim(im, orig, faction, level, mode):
    """Dải vàng LIỀN dọc mép mái/đỉnh: mỗi cột lấy 3 pixel đặc trên cùng.
    Đỉnh cột tính trên ảnh GỐC (chi tiết vẽ trước như ống khói không bị
    nhuộm). mode 'window': chỉ cột có đỉnh trong 30px dưới đỉnh cao nhất
    (tránh sàn trong sau lỗ châu mai bị rắc vàng — lỗi vòng 1). mode 'all':
    mọi cột (mái dốc nhà/kho — toàn bộ profile trên là mép mái)."""
    arr = np.asarray(im).copy()
    tops = col_tops(np.asarray(orig))
    ymin = min(t for t in tops if t >= 0)
    px = im.load()
    W, H = im.size
    sh, gm, gl, gp = gold_ramp(faction, level)
    band_cols = [gm, gl, sh]
    for x in range(W):
        if tops[x] < 0:
            continue
        if mode == "window" and tops[x] > ymin + 30:
            continue
        y = tops[x]
        for i in range(3):
            if y + i < H and arr[y + i, x][3] > 200:
                px[x, y + i] = band_cols[i] + (255,)
    return im


def ridge_beam(im, faction):
    """Nhà/kho cấp 2: xà nóc sẫm — 2 hàng trên cùng của mái (pixel màu phe
    ở đỉnh cột) -> gỗ sẫm, mái đọc như được lợp lại dày hơn."""
    arr = np.asarray(im)
    tops = col_tops(arr)
    px = im.load()
    W, H = im.size
    for x in range(W):
        y = tops[x]
        if y < 0:
            continue
        r, g, b, a = (int(v) for v in arr[y, x])
        if classify(r, g, b, faction) == "faction":
            for i in range(2):
                if y + i < H and arr[y + i, x][3] > 200:
                    px[x, y + i] = ((0x5A, 0x3D, 0x24) if i == 0 else (0x6E, 0x4F, 0x30)) + (255,)
    return im


def tower_bands(im, faction, level):
    """Tháp: 2 vành đai thép quanh thân (cấp 3 viền vàng ở mép trên vành)."""
    arr = np.asarray(im)
    solid = arr[..., 3] > 200
    ys = np.nonzero(solid.any(axis=1))[0]
    top, bot = int(ys.min()), int(ys.max())
    px = im.load()
    roles = role_map(im, faction)
    for fb in (0.58, 0.74):
        y0 = top + int((bot - top) * fb)
        for yy in range(y0, y0 + 4):
            for x in range(im.size[0]):
                if not solid[yy, x] or roles[yy, x] not in (R_STEEL, R_FACTION, R_CREAM):
                    continue
                if yy == y0:
                    col = gold_ramp(faction, 3)[1] if level == 3 else STEEL_RAMP[4]
                elif yy == y0 + 1:
                    col = STEEL_RAMP[2]
                elif yy == y0 + 2:
                    col = STEEL_RAMP[1] if x % 8 != 3 else STEEL_RAMP[0]  # đinh tán
                else:
                    col = STEEL_RAMP[0]
                px[x, yy] = col + (255,)
    return im


def barracks_banners(im, orig, faction, level):
    """Doanh trại: 2 biểu ngữ vải màu phe treo trên tường hai bên cổng
    (vẽ đè trên pixel tường đặc; chân xẻ én giữ nguyên pixel gốc)."""
    px = im.load()
    W, H = im.size
    shades = faction_shades(orig, faction)
    dark, mid, light = shades
    for x0 in (14, W - 27):
        # thanh treo
        for x in range(x0 - 2, x0 + 15):
            col = gold_ramp(faction, 3)[1] if level == 3 else (0x6E, 0x4F, 0x30)
            px[x, 148] = col + (255,)
            px[x, 149] = ((0x4A, 0x32, 0x1C) if level < 3 else gold_ramp(faction, 3)[0]) + (255,)
        for dy in range(34):
            y = 150 + dy
            for dx in range(13):
                if dy >= 30 and 4 <= dx <= 8:
                    continue  # xẻ én: giữ pixel gốc
                x = x0 + dx
                if px[x, y][3] == 0:
                    continue
                if dx in (0, 12):
                    col = dark
                elif dy >= 28:
                    col = gold_ramp(faction, 3)[1] if level == 3 else dark
                else:
                    col = mid if (dx // 3 + dy // 5) % 2 == 0 else dark
                px[x, y] = col + (255,)
    return im


def castle_banner_trim(im, orig, faction, level):
    """Thành: 2 biểu ngữ sẵn có hai bên cổng — cấp 2 chân sẫm + cấp 3 tua
    vàng ở chân và thanh treo vàng."""
    arr = np.asarray(orig)
    roles = role_map(orig, faction)
    px = im.load()
    H, W = roles.shape
    for x in range(W):
        colmask = (roles[:, x] == R_FACTION)
        ys = np.nonzero(colmask & (np.arange(H) >= 125) & (np.arange(H) <= 208) &
                         (np.abs(np.arange(W)[x] - 159) >= 13) & (np.abs(np.arange(W)[x] - 159) <= 36))[0]
        if len(ys) < 8:
            continue
        yb = int(ys.max())
        for yy in (yb - 1, yb):
            if level == 3:
                px[x, yy] = gold_ramp(faction, 3)[1] + (255,)
            else:
                r, g, b, a = (int(v) for v in arr[yy, x])
                px[x, yy] = shift_hsv(r, g, b, s_mul=1.15, v_mul=0.8) + (255,)
    return im


def door_emblem(im, orig, faction, level, size=11):
    """Huy hiệu khiên vàng trên cổng: cổng = cụm pixel màu phe ở 30% dưới
    của ảnh; khiên đặt ở tâm cụm. Không thấy cụm thì bỏ qua."""
    roles = role_map(orig, faction)
    H, W = roles.shape
    mask = (roles == R_FACTION) & (np.arange(H)[:, None] >= int(H * 0.68))
    lab, comps = components(mask)
    # Cổng nằm ở GIỮA ảnh: chọn cụm có tâm x gần trục giữa nhất (vòng 2 sửa —
    # vòng 1 chọn cụm to nhất nên khiên rơi lên tường/biểu ngữ bên trái).
    comps = [c for c in comps if c[0] >= 60 and abs(c[1] - W / 2) <= W * 0.14]
    if not comps:
        return im
    c = min(comps, key=lambda c: abs(c[1] - W / 2))
    cx = int(round(c[1]))
    cy = int(round((c[4] + c[6]) / 2))
    px = im.load()
    draw_shield(px, W, H, cx, cy, faction_shades(orig, faction), faction, level,
                w=size, h=size + 2)
    return im


# Neo chi tiết theo loại nhà (toạ độ tuyệt đối — canvas cố định theo loại,
# hình học 4 phe giống hệt nhau, đã đo trên bản xanh dương).
B_ANCHORS = {
    "castle":     {"flag": [(159, "big")], "spires": [92, 226], "rim": "window"},
    "tower":      {"flag": [(63, "spireflag")], "spires": [], "rim": "window"},
    "barracks":   {"flag": [(95, "big")], "spires": [16, 174], "rim": "window"},
    "house":      {"flag": [(63, "std")], "spires": [], "rim": "all", "chimney": 93, "ridge": True},
    "storehouse": {"flag": [(94, "std")], "spires": [], "rim": "all", "chimney": 30, "ridge": True},
}


def process_building(src_path, name, faction, level, dst_path):
    im = Image.open(src_path).convert("RGBA")
    out = palette_pass(im, faction, level, "building")
    out = stone_base2(im, out, faction, level)
    shades = faction_shades(im, faction)
    cfg = B_ANCHORS[name]
    arr0 = np.asarray(im)
    tops = col_tops(arr0)
    W, H = im.size
    px = out.load()
    if cfg.get("ridge") and level == 2:
        out = ridge_beam(out, faction)
        px = out.load()
    if cfg.get("chimney"):
        draw_chimney(px, W, H, tops, cfg["chimney"], faction, level)
    if name == "tower":
        out = tower_bands(out, faction, level)
        px = out.load()
    if name == "barracks":
        out = barracks_banners(out, im, faction, level)
        px = out.load()
    if name == "castle":
        out = castle_banner_trim(out, im, faction, level)
        px = out.load()
    if level == 3:
        out = gold_rim(out, im, faction, level, cfg["rim"])
        px = out.load()
        for sx in cfg["spires"]:
            if 0 <= sx < W and tops[sx] >= 0:
                draw_spire(px, W, H, sx, tops[sx], 4, 13 if name == "castle" else 9, faction, level)
        if name == "barracks":
            # chữ X trên cổng -> vàng (cổng doanh trại có sẵn thanh chéo gỗ)
            roles_b = role_map(im, faction)
            arr_b = np.asarray(im)
            for yy in range(196, min(H, 246)):
                for xx in range(74, 118):
                    if roles_b[yy, xx] == R_WOOD:
                        v = int(arr_b[yy, xx][:3].max())
                        px[xx, yy] = gold_by_v(v / 255.0, faction, 3) + (255,)
        if name != "barracks":  # doanh trại đã có sẵn phù hiệu + chữ X vàng
            out = door_emblem(out, im, faction, level, size=13 if name in ("castle", "tower") else 11)
        px = out.load()
    # cờ (cả 2 cấp): màu lấy ở dải SÁNG của phe cho dễ đọc từ xa
    shades_flag = faction_shades(im, faction, qs=(0.45, 0.75, 0.97))
    for fx, kind in cfg["flag"]:
        if not (0 <= fx < W) or tops[fx] < 0:
            continue
        base = tops[fx]
        if kind == "spireflag":
            # tháp cấp 3: nón vàng ở đỉnh + cọc cờ ngắn mọc từ đỉnh nón
            if level == 3:
                draw_spire(px, W, H, fx, base, 3, 11, faction, level)
                draw_flag(px, W, H, fx, base - 15, 9, 13, 7, shades_flag, faction, level)
            else:
                draw_flag(px, W, H, fx, base, 14, 15, 8, shades_flag, faction, level)
        elif level == 3:
            draw_flag(px, W, H, fx, base, 18, 19, 10, shades_flag, faction, level)
        else:
            draw_flag(px, W, H, fx, base, 13, 15, 8, shades_flag, faction, level)
    out.save(dst_path)


# ---------------------------------------------------------------- quân
def _vmap(orig_arr):
    return orig_arr[..., :3].max(axis=2).astype(np.float32) / 255.0


def _gold_arr(v, faction, level):
    sh, mid, light, pale = gold_ramp(faction, level)
    out = np.zeros(v.shape + (3,), dtype=np.uint8)
    m1 = v < 0.80
    m2 = (v >= 0.80) & (v < 0.90)
    m3 = v >= 0.90
    for m, c in ((m1, mid), (m2, light), (m3, pale)):
        out[m] = c
    return out


def dilate_paint(outa, x0, seed, steps, dirs, alpha_ok=200, extra_ok=None, outline_after=False):
    """Mọc vùng seed ra pixel trống/halo (alpha < alpha_ok) theo các hướng
    cho trước, màu lấy từ pixel seed kề nhất (đọc từ chính ảnh đích).
    extra_ok: mặt nạ pixel được phép vẽ đè dù đặc (vd vòng outline của
    chính chi tiết). outline_after: vẽ lại 1px outline quanh hình đã mọc."""
    region = seed.copy()
    frontier = seed.copy()
    H, W = seed.shape
    for _ in range(steps):
        newf = np.zeros_like(frontier)
        for dy, dx in dirs:
            sh = np.roll(np.roll(frontier, dy, axis=0), dx, axis=1)
            if dy == -1:
                sh[-1, :] = False
            if dy == 1:
                sh[0, :] = False
            if dx == -1:
                sh[:, -1] = False
            if dx == 1:
                sh[:, 0] = False
            newf |= sh & ~region
        ys, xs = np.nonzero(newf)
        if len(ys) == 0:
            break
        painted = np.zeros_like(newf)
        for y, lx in zip(ys.tolist(), xs.tolist()):
            if outa[y, x0 + lx][3] >= alpha_ok and not (extra_ok is not None and extra_ok[y, lx]):
                continue
            for dy, dx in dirs:
                sy, sx = y - dy, lx - dx
                if 0 <= sy < H and 0 <= sx < W and region[sy, sx]:
                    outa[y, x0 + lx] = outa[sy, x0 + sx]
                    painted[y, lx] = True
                    break
        region |= painted
        frontier = painted
    if outline_after:
        ring = np.zeros_like(region)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            sh = np.roll(np.roll(region, dy, axis=0), dx, axis=1)
            if dy == -1:
                sh[-1, :] = False
            if dy == 1:
                sh[0, :] = False
            if dx == -1:
                sh[:, -1] = False
            if dx == 1:
                sh[:, 0] = False
            ring |= sh & ~region
        ys, xs = np.nonzero(ring)
        for y, lx in zip(ys.tolist(), xs.tolist()):
            if outa[y, x0 + lx][3] < alpha_ok:
                outa[y, x0 + lx] = OUTLINE_DARK + (255,)


def crest_op(outa, origa, roles, x0, fw, faction, level, band, grow):
    """Chùm mũ mọc cao: giãn vùng chùm (pixel màu phe ở dải đầu nhân vật)
    lên trên theo hình nón. Cấp 3 nhuộm vàng cả chùm trước khi mọc."""
    fmask = roles[:, x0:x0 + fw] == R_FACTION
    if not fmask.any():
        return
    H = fmask.shape[0]
    top_f = int(np.nonzero(fmask.any(axis=1))[0][0])
    seed = fmask & (np.arange(H)[:, None] <= top_f + band)
    if level == 3:
        golds = _gold_arr(_vmap(origa), faction, level)
        ys, xs = np.nonzero(seed)
        for y, lx in zip(ys.tolist(), xs.tolist()):
            outa[y, x0 + lx] = (int(golds[y, x0 + lx][0]), int(golds[y, x0 + lx][1]),
                                int(golds[y, x0 + lx][2]), 255)
    dilate_paint(outa, x0, seed, grow, ((-1, -1), (-1, 0), (-1, 1)))


def pennant_op(outa, origa, roles, x0, fw, faction, level, grow_r):
    """Cờ giáo phình to: cụm màu phe TÁCH RỜI khỏi thân, nằm sát phần thép
    mỏng (giáo) = lá cờ. Giãn nở chỉ vào pixel trong suốt. Cấp 3 cờ vàng."""
    fmask = roles[:, x0:x0 + fw] == R_FACTION
    if not fmask.any():
        return
    lab, comps = components(fmask)
    if not comps:
        return
    body = max(range(len(comps)), key=lambda i: comps[i][0])
    bcy = comps[body][2]
    steel = roles[:, x0:x0 + fw] == R_STEEL
    golds = _gold_arr(_vmap(origa), faction, level)
    H = fmask.shape[0]
    for cid, c in enumerate(comps):
        if cid == body or c[0] < 6 or c[2] > bcy + 20:
            continue
        cmask = lab == cid
        # cờ phải nằm sát giáo (thép) trong vòng 4px
        near = np.zeros_like(cmask)
        for dy in range(-4, 5):
            for dx in range(-4, 5):
                near |= np.roll(np.roll(cmask, dy, axis=0), dx, axis=1)
        if not (near & steel).any():
            continue
        if level == 3:
            ys, xs = np.nonzero(cmask)
            for y, lx in zip(ys.tolist(), xs.tolist()):
                outa[y, x0 + lx] = (int(golds[y, x0 + lx][0]), int(golds[y, x0 + lx][1]),
                                    int(golds[y, x0 + lx][2]), 255)
        # Cờ/nơ bị vòng outline của chính nó bịt kín: cho phép mọc ĐÈ qua
        # vòng outline kề (<=2px) rồi vẽ lại outline quanh hình mới.
        oring = np.zeros_like(cmask)
        omask = roles[:, x0:x0 + fw] == R_OUTLINE
        grow = cmask.copy()
        for _ in range(2):
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                sh = np.roll(np.roll(grow, dy, axis=0), dx, axis=1)
                if dy == -1:
                    sh[-1, :] = False
                if dy == 1:
                    sh[0, :] = False
                if dx == -1:
                    sh[:, -1] = False
                if dx == 1:
                    sh[:, 0] = False
                oring |= sh & omask
            grow |= oring
        dilate_paint(outa, x0, cmask, grow_r, ((-1, 0), (1, 0), (0, -1), (0, 1)),
                     extra_ok=oring, outline_after=True)


def thin_gold_op(outa, origa, roles, faction, level, all_steel=False):
    """Vũ khí mỏng -> vàng: pixel thép có ít kề thép (lưỡi/mũi/đầu tên)
    hoặc TOÀN BỘ thép nếu all_steel (đầu công cụ nông dân)."""
    steel = roles == R_STEEL
    if not steel.any():
        return
    if all_steel:
        thin = steel
    else:
        cnt = np.zeros(steel.shape, dtype=np.int32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy or dx:
                    cnt += np.roll(np.roll(steel, dy, axis=0), dx, axis=1)
        thin = steel & (cnt <= 4)
    golds = _gold_arr(_vmap(origa), faction, level)
    ys, xs = np.nonzero(thin)
    for y, x in zip(ys.tolist(), xs.tolist()):
        outa[y, x] = (int(golds[y, x][0]), int(golds[y, x][1]), int(golds[y, x][2]), 255)
    # vệt sáng kề vũ khí mỏng -> vàng nhạt
    if not all_steel:
        adj = np.zeros(thin.shape, dtype=bool)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            adj |= np.roll(thin, (dy, dx), axis=(0, 1))
        shine = (roles == R_SHINE) & adj
        pale = gold_ramp(faction, level)[3]
        ys, xs = np.nonzero(shine)
        for y, x in zip(ys.tolist(), xs.tolist()):
            outa[y, x] = (pale[0], pale[1], pale[2], 255)


def bow_gold_op(outa, origa, roles, x0, fw, faction, level):
    """Cung của cung thủ (đường cong tối, mỏng, tách khỏi thân) -> vàng đồng."""
    sub = roles[:, x0:x0 + fw]
    cand = (sub == R_OUTLINE) | (sub == R_WOOD)
    if not cand.any():
        return
    near_body = np.zeros_like(cand)
    core = (sub == R_FACTION) | (sub == R_CREAM)
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            near_body |= np.roll(np.roll(core, dy, axis=0), dx, axis=1)
    cnt = np.zeros(cand.shape, dtype=np.int32)
    solid = origa[:, x0:x0 + fw][..., 3] > 0
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy or dx:
                cnt += np.roll(np.roll(solid, dy, axis=0), dx, axis=1)
    bow = cand & ~near_body & (cnt <= 5)
    sh, gm, gl, gp = gold_ramp(faction, level)
    v = _vmap(origa)[:, x0:x0 + fw]
    ys, xs = np.nonzero(bow)
    for y, lx in zip(ys.tolist(), xs.tolist()):
        outa[y, x0 + lx] = (gm if v[y, lx] >= 0.3 else sh) + (255,)


def shield_gold_op(outa, origa, roles, x0, fw, faction, level):
    """Khiên kiếm sĩ: cụm (màu phe|kem) tách rời ở phía trái thân.
    Cấp 2: ô màu phe -> THÉP BẠC (khiên bạc khác hẳn khiên xanh ở cấp 1).
    Cấp 3: màu phe -> vàng, kem -> ánh vàng."""
    sub = roles[:, x0:x0 + fw]
    fc = (sub == R_FACTION) | (sub == R_CREAM)
    if not fc.any():
        return
    lab, comps = components(fc)
    if not comps:
        return
    body = max(range(len(comps)), key=lambda i: comps[i][0])
    fmask = sub == R_FACTION
    top_f = int(np.nonzero(fmask.any(axis=1))[0][0]) if fmask.any() else 0
    cx_frame = fw / 2.0
    golds = _gold_arr(_vmap(origa), faction, level)
    pale = np.array(gold_ramp(faction, level)[3], dtype=np.float32)
    vmap = _vmap(origa)
    for cid, c in enumerate(comps):
        if cid == body or c[0] < 30:
            continue
        if not (c[1] < cx_frame - 8 and c[2] > top_f + 16):
            continue
        cmask = lab == cid
        ys, xs = np.nonzero(cmask)
        for y, lx in zip(ys.tolist(), xs.tolist()):
            gx = x0 + lx
            if sub[y, lx] == R_FACTION:
                if level == 3:
                    outa[y, gx] = (int(golds[y, gx][0]), int(golds[y, gx][1]), int(golds[y, gx][2]), 255)
                else:
                    v = vmap[y, gx]
                    outa[y, gx] = (STEEL_RAMP[1] if v < 0.5 else STEEL_RAMP[2] if v < 0.75 else STEEL_RAMP[3]) + (255,)
            elif level == 3:
                cur = outa[y, gx][:3].astype(np.float32)
                nv = (cur * 0.55 + pale * 0.45).astype(np.uint8)
                outa[y, gx] = (int(nv[0]), int(nv[1]), int(nv[2]), 255)
            else:
                # cấp 2: kem pha thép -> cả khiên ngả bạc lạnh, khác hẳn kem ấm
                cur = outa[y, gx][:3].astype(np.float32)
                steel = np.array(STEEL_RAMP[3], dtype=np.float32)
                nv = np.clip(cur * 0.55 + steel * 0.45, 0, 255).astype(np.uint8)
                outa[y, gx] = (int(nv[0]), int(nv[1]), int(nv[2]), 255)


def thin_polish_op(outa, origa, roles, faction):
    """Cấp 2: vũ khí mỏng (thép ít kề) -> thép sáng nhất như vừa mài."""
    steel = roles == R_STEEL
    if not steel.any():
        return
    cnt = np.zeros(steel.shape, dtype=np.int32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy or dx:
                cnt += np.roll(np.roll(steel, dy, axis=0), dx, axis=1)
    thin = steel & (cnt <= 4)
    v = _vmap(origa)
    ys, xs = np.nonzero(thin)
    for y, x in zip(ys.tolist(), xs.tolist()):
        outa[y, x] = (STEEL_RAMP[4] if v[y, x] >= 0.6 else STEEL_RAMP[3]) + (255,)


def helmet_band_op(outa, origa, roles, x0, fw, faction, level, shades):
    """Cung thủ: vành mũ — 2 hàng thép thấp nhất của cụm mũ (cụm thép lớn
    nhất ở nửa trên frame): cấp 2 thép sáng + 1 hàng màu phe phía trên;
    cấp 3 vành vàng."""
    sub = roles[:, x0:x0 + fw]
    steel = sub == R_STEEL
    if not steel.any():
        return
    lab, comps = components(steel)
    comps = [(i, c) for i, c in enumerate(comps) if c[0] >= 40 and c[2] < sub.shape[0] * 0.55]
    if not comps:
        return
    hid, hc = max(comps, key=lambda t: t[1][0])
    hmask = lab == hid
    for lx in range(hc[3], hc[5] + 1):
        col = np.nonzero(hmask[:, lx])[0]
        if len(col) == 0:
            continue
        yb = int(col.max())
        if level == 3:
            outa[yb, x0 + lx] = gold_ramp(faction, 3)[0] + (255,)
            if hmask[yb - 1, lx]:
                outa[yb - 1, x0 + lx] = gold_ramp(faction, 3)[1] + (255,)
        else:
            outa[yb, x0 + lx] = STEEL_RAMP[3] + (255,)
            if hmask[yb - 1, lx]:
                outa[yb - 1, x0 + lx] = STEEL_RAMP[4] + (255,)
            if yb - 2 >= 0 and hmask[yb - 2, lx]:
                outa[yb - 2, x0 + lx] = shades[1] + (255,)


def pawn_op(outa, origa, roles, x0, fw, faction, level, shades, strip):
    """Nông dân: băng đầu màu phe ở mép mũ + thắt lưng có khoá; cấp 3 mũ
    vàng nhạt + viền cổ vàng. Mặt nạ theo từng frame."""
    sub = roles[:, x0:x0 + fw]
    cream = sub == R_CREAM
    if not cream.any():
        return
    lab, comps = components(cream)
    face = max(comps, key=lambda c: c[0])
    if face[0] < 20:
        return
    fx0, fx1, ftop = max(0, face[3] - 5), min(fw - 1, face[5] + 5), face[4]
    golds = _gold_arr(_vmap(origa), faction, level)
    dark, mid, light = shades
    # --- mũ: pixel gỗ trong dải cột mặt, phía trên mặt
    hat = (sub == R_WOOD) & (np.arange(sub.shape[0])[:, None] < ftop + 3)
    hat[:, :fx0] = False
    hat[:, fx1 + 1:] = False
    if level == 3 and hat.any():
        ys, xs = np.nonzero(hat)
        for y, lx in zip(ys.tolist(), xs.tolist()):
            g = golds[y, x0 + lx].astype(np.float32)
            cur = outa[y, x0 + lx][:3].astype(np.float32)
            nv = (g * 0.78 + cur * 0.22).astype(np.uint8)
            outa[y, x0 + lx] = (int(nv[0]), int(nv[1]), int(nv[2]), 255)
    # --- miếng vá màu phe trên mũ (chỉ khi mũ phủ đủ diện kim cương 5x5)
    pcx, pcy = int(round(face[1])), ftop - 7
    dia = [(dx, dy) for dy in range(-2, 3) for dx in range(-2, 3) if abs(dx) + abs(dy) <= 2]
    if pcy - 2 >= 0 and all(0 <= pcx + dx < fw and hat[pcy + dy, pcx + dx] for dx, dy in dia if abs(dx) + abs(dy) == 2) \
            and sum(1 for dx, dy in dia if hat[pcy + dy, pcx + dx]) >= 9:
        for dx, dy in dia:
            col = shades[0] if abs(dx) + abs(dy) == 2 else shades[2]
            outa[pcy + dy, x0 + pcx + dx] = col + (255,)
    # --- băng đầu: 3 hàng gỗ thấp nhất của mũ trong từng cột -> màu phe
    for lx in range(fx0, fx1 + 1):
        col = np.nonzero(hat[:, lx])[0]
        if len(col) == 0:
            continue
        yb = int(col.max())
        outa[yb, x0 + lx] = dark + (255,)
        if yb - 1 >= 0 and hat[yb - 1, lx]:
            outa[yb - 1, x0 + lx] = mid + (255,)
        if yb - 2 >= 0 and hat[yb - 2, lx]:
            outa[yb - 2, x0 + lx] = light + (255,)
    # --- áo (cụm màu phe thấp nhất) + thắt lưng + viền cổ
    fmask = sub == R_FACTION
    if not fmask.any():
        return
    lab2, comps2 = components(fmask)
    shirt = max(comps2, key=lambda c: c[6])  # cụm chạm đáy nhất
    if shirt[0] < 15:
        return
    sid = comps2.index(shirt)
    smask = lab2 == sid
    sh_top, sh_bot = shirt[4], shirt[6]
    sh_h = max(4, sh_bot - sh_top)
    belt_y = sh_top + int(sh_h * 0.45)
    buckle = gold_ramp(faction, level)[2] if level == 3 else STEEL_RAMP[3]
    for lx in range(shirt[3], shirt[5] + 1):
        col = np.nonzero(smask[:, lx])[0]
        if len(col) == 0:
            continue
        if level == 3:
            outa[int(col.min()), x0 + lx] = gold_ramp(faction, level)[1] + (255,)  # viền cổ
        for yy in (belt_y - 1, belt_y, belt_y + 1):
            if 0 <= yy < sub.shape[0] and smask[yy, lx]:
                outa[yy, x0 + lx] = (0x4A, 0x32, 0x1C, 255)
    scx = int(round(shirt[1]))
    for lx in range(scx - 2, scx + 3):
        if 0 <= lx < fw and smask[belt_y, lx]:
            outa[belt_y, x0 + lx] = buckle + (255,)


def process_unit(src_path, faction, level, frame_w, dst_path):
    im = Image.open(src_path).convert("RGBA")
    out = palette_pass(im, faction, level, "unit")
    name = os.path.basename(src_path)
    # file tạm lancer đặt tên {phe}_lancer_*.png -> dò theo tên loại quân
    utype = next((u for u in ("warrior", "archer", "lancer", "pawn") if u in name), name.split("_")[0])
    is_pawn = utype == "pawn"
    if frame_w and im.width % frame_w == 0:
        outa = np.asarray(out).copy()
        origa = np.asarray(im)
        roles = role_map(im, faction)
        shades = faction_shades(im, faction)
        n = im.width // frame_w
        for f in range(n):
            x0 = f * frame_w
            if utype == "warrior":
                crest_op(outa, origa, roles, x0, frame_w, faction, level, band=15, grow=3 if level == 2 else 5)
            elif utype == "archer":
                crest_op(outa, origa, roles, x0, frame_w, faction, level, band=9, grow=2 if level == 2 else 3)
                helmet_band_op(outa, origa, roles, x0, frame_w, faction, level, shades)
            elif utype == "lancer":
                pennant_op(outa, origa, roles, x0, frame_w, faction, level, grow_r=2 if level == 2 else 3)
            elif is_pawn:
                pawn_op(outa, origa, roles, x0, frame_w, faction, level, shades, name)
        if utype == "warrior":
            for f in range(n):
                shield_gold_op(outa, origa, roles, f * frame_w, frame_w, faction, level)
        if level == 2:
            if utype in ("warrior", "archer", "lancer"):
                thin_polish_op(outa, origa, roles, faction)
            if is_pawn and any(k in name for k in ("axe", "pick", "knife")):
                thin_polish_op(outa, origa, roles, faction)
        if level == 3:
            if utype in ("warrior", "archer", "lancer"):
                thin_gold_op(outa, origa, roles, faction, level)
            if is_pawn and any(k in name for k in ("axe", "pick", "knife")):
                thin_gold_op(outa, origa, roles, faction, level, all_steel=True)
            if utype == "archer" and name != "arrow":
                for f in range(n):
                    bow_gold_op(outa, origa, roles, f * frame_w, frame_w, faction, level)
        out = Image.fromarray(outa, "RGBA")
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
    made = []
    for faction in factions:
        for b in BUILDINGS:
            for lv in (2, 3):
                dst = os.path.join(OUT, "buildings", f"{b}_{faction}_lv{lv}.png")
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                process_building(l1_path("building", faction, b), b, faction, lv, dst)
                made.append(dst)
        for utype, strips in UNIT_STRIPS.items():
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
