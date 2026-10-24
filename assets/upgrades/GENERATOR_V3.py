#!/usr/bin/env python3
"""
GENERATOR_V3 — MAU VONG 3 (cho duyet, chi phe XANH).

Khac vong 1/2 (chi doi mau + trang tri): vong 3 VE LAI CAU TRUC tren nen
ban vong 2 — bong dang (silhouette) khac han theo cap:
- Nha: nang slab tuong/thap (cat ngang vung tuong cua CHINH sprite, chen
  them hang tuong cua no de thap cao len that), ghep tang mai thu 2,
  mai mai keo dai, cua so gac xep, mai che cong, ban cong go, thap goc.
- Quan: ao choang sau lung (kiem si), bao ten sau vai (cung thu), ba lo
  (nong dan), khien tron gan tay + chom mu (linh giao), khien kiem si
  phong to, giap vai.

Nen = file vong 2 trong assets/upgrades/ (blue). Xuat vao preview_v3/.
Rang buoc giu nguyen: cung canvas, cung so frame, chan de khong doi
(moi thay doi deu day pixel LEN TREN hoac ra ngang vao khoang trong).
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
UP = os.path.join(HERE, "preview_v3")
sys.path.insert(0, HERE)
import GENERATOR as G  # noqa: E402  (ham ve co/chop + bang mau vong 2)

FACTION = "blue"
SH_D, SH_M, SH_L = (0x1F, 0x3A, 0x6E), (0x2E, 0x5F, 0xA8), (0x5B, 0x9B, 0xD9)  # se thay bang shades that ben duoi


# ----------------------------------------------------------------------
# Toolkit cau truc
# ----------------------------------------------------------------------

def slab_raise(im, x0, x1, y_cut, raise_px, fill_src="below", fill_h=8, fill_off=0):
    """Nang khoi pixel trong cot doc [x0..x1] phia tren y_cut len raise_px,
    chen vao khoang trong hang pixel lay tu chinh sprite (tren/duoi duong
    cat, lech fill_off hang). Chan de (hang duoi y_cut) giu nguyen."""
    arr = np.asarray(im).copy()
    slab = arr[:, x0:x1 + 1]
    solid = slab[..., 3] > 10
    rows = np.nonzero(solid.any(axis=1))[0]
    if len(rows) == 0:
        return im
    top = int(rows.min())
    if raise_px <= 0 or top - raise_px < 0:
        return im
    new = np.zeros_like(slab)
    new[top - raise_px:y_cut - raise_px] = slab[top:y_cut]
    if fill_src == "below":
        src = slab[y_cut + fill_off:y_cut + fill_off + fill_h]
    else:
        src = slab[y_cut - fill_off - fill_h:y_cut - fill_off]
    for i in range(raise_px):
        new[y_cut - raise_px + i] = src[i % len(src)]
    new[y_cut:] = slab[y_cut:]
    arr[:, x0:x1 + 1] = new
    return Image.fromarray(arr, "RGBA").copy()


def v_stretch(im, y_cut, add, fill_src="below", fill_h=8, fill_off=0):
    return slab_raise(im, 0, im.width - 1, y_cut, add, fill_src, fill_h, fill_off)


def paste(dst, part, dx, dy):
    dst.alpha_composite(part, (dx, dy))
    return dst


def crop_scaled(im, box, scale):
    part = im.crop(box)
    nw, nh = max(1, int(part.width * scale)), max(1, int(part.height * scale))
    return part.resize((nw, nh), Image.NEAREST)


def solid_bbox(im):
    a = np.asarray(im)[..., 3] > 10
    ys, xs = np.nonzero(a)
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def col_top(im, x):
    a = np.asarray(im)[..., 3] > 10
    col = np.nonzero(a[:, x])[0]
    return int(col.min()) if len(col) else -1


# ----------------------------------------------------------------------
# Nha - vong 3
# ----------------------------------------------------------------------

def b_castle(im, level):
    # Thap hai ben cao vuot tuong (slab raise vung thap), cat o vung tuong
    # duoi san go (y=128), lap bang hang TUONG THUONG o y 150-160 (tranh
    # vung cot go/bieu ngu sat duong cat gay vet soc).
    r = 12 if level == 2 else 22
    im = slab_raise(im, 26, 122, 128, r, "below", 10, fill_off=22)
    im = slab_raise(im, 196, 292, 128, r, "below", 10, fill_off=22)
    if level == 3:
        # Thap giu trung tam (keep) nhon cao giua hai thap: lap bang hang
        # san go phia tren duong cat.
        im = slab_raise(im, 126, 192, 128, 14, "above", 7, fill_off=2)
    return im


def b_tower(im, level):
    # Than thap keo dai bang hang da thuong cua chinh than (tren cua vom)
    add = 14 if level == 2 else 20
    im = v_stretch(im, 148, add, "above", 9, fill_off=2)
    # Thap canh giua san: nang slab giua cua dinh thap (lo chau mai + san
    # go o giua nhon len) — ky thuat slab nhu thap giu cua thanh, khong
    # ghep roi nen khong bao gio "bay". Co/non vang vong 2 o giua se tu
    # nhon theo slab.
    step = 10 if level == 2 else 14
    im = slab_raise(im, 36, 92, 118 - add, step, "above", 6, fill_off=2)
    return im


def b_barracks(im, level):
    # Thap goc hai ben + thap canh giua dinh mai (slab raise): doanh trai
    # thanh khoi co 3 thap nho tren duong dinh, khac han khoi 1 mai cua goc.
    cr = 10 if level == 2 else 16
    im = slab_raise(im, 2, 46, 132, cr, "below", 8)
    im = slab_raise(im, 146, 190, 132, cr, "below", 8)
    mr = 12 if level == 2 else 18
    im = slab_raise(im, 68, 124, 102, mr, "above", 6, fill_off=2)
    if level == 3:
        px = im.load()
        W, H = im.size
        tops = G.col_tops(np.asarray(im))
        cx = W // 2
        if tops[cx] >= 0:
            G.draw_spire(px, W, H, cx, tops[cx] + 2, 4, 11, FACTION, 3)
    else:
        # Mai che cong (cap 2)
        d = ImageDraw.Draw(im, "RGBA")
        wood_d, wood_m = (0x6E, 0x4A, 0x26), (0x9A, 0x6B, 0x36)
        gx0, gx1, gy = 62, 130, 186
        d.polygon([(gx0, gy + 8), (gx1, gy + 8), (gx1 - 8, gy), (gx0 + 8, gy)], fill=wood_m + (255,))
        d.line([gx0 + 8, gy, gx1 - 8, gy], fill=(0xC0, 0x8C, 0x4E, 255))
        d.rectangle([gx0 + 4, gy + 8, gx0 + 7, gy + 34], fill=wood_d + (255,))
        d.rectangle([gx1 - 7, gy + 8, gx1 - 4, gy + 34], fill=wood_d + (255,))
    return im


def _dormer(im, cx, cy, level, big=False):
    """Cua so gac xep ve theo net pack: khung go nau, kinh thep xanh, mai nho."""
    d = ImageDraw.Draw(im, "RGBA")
    w = 19 if big else 15
    h = 20 if big else 16
    x0, y0 = cx - w // 2, cy - h
    wood_d, wood_m = (0x6E, 0x4A, 0x26), (0x9A, 0x6B, 0x36)
    glass = (0x9F, 0xC8, 0xD8)
    out = G.OUTLINE_DARK
    d.rectangle([x0 - 1, y0 + 5, x0 + w, y0 + h], fill=out + (255,))
    d.rectangle([x0, y0 + 6, x0 + w - 1, y0 + h - 1], fill=wood_m + (255,))
    d.rectangle([x0 + 2, y0 + 8, x0 + w - 3, y0 + h - 3], fill=glass + (255,))
    d.line([cx, y0 + 8, cx, y0 + h - 3], fill=wood_d + (255,))
    d.line([x0 + 2, y0 + (h + 6) // 2, x0 + w - 3, y0 + (h + 6) // 2], fill=wood_d + (255,))
    # mai gac xep: tam giac go + vien
    d.polygon([(x0 - 3, y0 + 6), (x0 + w + 2, y0 + 6), (cx, y0 - 2)], fill=wood_m + (255,))
    d.line([x0 - 3, y0 + 6, cx, y0 - 2], fill=wood_d + (255,))
    d.line([cx, y0 - 2, x0 + w + 2, y0 + 6], fill=wood_d + (255,))
    if level == 3:
        d.line([x0 - 3, y0 + 6, cx, y0 - 2], fill=G.GOLD + (255,))
        d.line([cx, y0 - 2, x0 + w + 2, y0 + 6], fill=G.GOLD + (255,))
    return im


def _awning(im, cx, top_y, width, level):
    d = ImageDraw.Draw(im, "RGBA")
    wood_d, wood_m, wood_l = (0x6E, 0x4A, 0x26), (0x9A, 0x6B, 0x36), (0xC0, 0x8C, 0x4E)
    x0, x1 = cx - width // 2, cx + width // 2
    d.polygon([(x0, top_y + 7), (x1, top_y + 7), (x1 - 7, top_y), (x0 + 7, top_y)], fill=wood_m + (255,))
    d.line([x0 + 7, top_y, x1 - 7, top_y], fill=wood_l + (255,))
    if level == 3:
        d.line([x0, top_y + 7, x1, top_y + 7], fill=G.GOLD + (255,))
    d.rectangle([x0 + 3, top_y + 7, x0 + 5, top_y + 26], fill=wood_d + (255,))
    d.rectangle([x1 - 5, top_y + 7, x1 - 3, top_y + 26], fill=wood_d + (255,))
    return im


def b_house(im, level):
    add = 8 if level == 2 else 14
    im = v_stretch(im, 72, add, "above", 7)  # mai cao hon han
    # cua so gac xep tren mai phai + mai che cua
    im = _dormer(im, 88, 84 - add, level, big=(level == 3))
    door_top = col_top(im, 64)
    im = _awning(im, 64, 128 - add, 42, level)
    if level == 3:
        # ong khoi keo dai them
        im = slab_raise(im, 86, 100, 60, 5, "below", 4)
    return im


def b_storehouse(im, level):
    add = 8 if level == 2 else 14
    im = v_stretch(im, 84, add, "above", 7)
    im = _dormer(im, 84, 92 - add, level, big=(level == 3))
    im = _awning(im, 30, 128 - add, 36, level)
    return im


BUILDERS_V3 = {
    "castle": b_castle, "tower": b_tower, "barracks": b_barracks,
    "house": b_house, "storehouse": b_storehouse,
}


# ----------------------------------------------------------------------
# Quan - vong 3 (xu ly tung frame, nen = ban vong 2)
# ----------------------------------------------------------------------

LEATHER = (0x8A, 0x5F, 0x36)
LEATHER_D = (0x5E, 0x3E, 0x20)


def _frame_bbox(fr):
    a = np.asarray(fr)[..., 3] > 10
    if not a.any():
        return None
    ys, xs = np.nonzero(a)
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def _behind(fr, draw_fn):
    """Ve 1 lop SAU lung nhan vat roi dan frame len tren."""
    back = Image.new("RGBA", fr.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(back, "RGBA"))
    back.alpha_composite(fr)
    return back


def u_warrior(fr, l1fr, level, shades):
    bb = _frame_bbox(fr)
    if bb is None:
        return fr
    x0, y0, x1, y1 = bb
    cx = x0 + int(0.38 * (x1 - x0))
    sy = y0 + int(0.20 * (y1 - y0))
    dark, mid, light = shades

    def cape(d):
        if level == 2:
            pts = [(cx - 24, sy), (cx + 6, sy), (cx - 2, y1 - 2), (cx - 33, y1 - 2)]
        else:
            pts = [(cx - 28, sy), (cx + 8, sy), (cx + 1, y1), (cx - 38, y1)]
        d.polygon(pts, fill=dark + (255,))
        d.line([pts[0], pts[3]], fill=G.OUTLINE_DARK + (255,), width=2)
        d.line([pts[3], pts[2]], fill=(G.GOLD if level == 3 else G.OUTLINE_DARK) + (255,), width=2)
        if level == 3:
            d.ellipse([cx - 16, sy - 2, cx - 10, sy + 4], fill=G.GOLD_LIGHT + (255,))

    fr = _behind(fr, cape)
    # Khien phong to quanh tam, co dinh mep phai (noi ap vao than)
    roles = G.role_map(l1fr, FACTION)
    sub = roles
    fc = (sub == G.R_FACTION) | (sub == G.R_CREAM)
    if fc.any():
        lab, comps = G.components(fc)
        body = max(range(len(comps)), key=lambda i: comps[i][0])
        top_f = int(np.nonzero((sub == G.R_FACTION).any(axis=1))[0][0])
        for cid, c in enumerate(comps):
            if cid == body or c[0] < 30:
                continue
            if not (c[1] < fr.width / 2 - 8 and c[2] > top_f + 16):
                continue
            cmask = lab == cid
            # gom ca vong outline sat khien
            ring = np.zeros_like(cmask)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ring |= np.roll(np.roll(cmask, dy, axis=0), dx, axis=1)
            smask = cmask | (ring & (sub == G.R_OUTLINE))
            ys, xs = np.nonzero(smask)
            bx0, by0, bx1, by1 = int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())
            patch = fr.crop((bx0, by0, bx1 + 1, by1 + 1))
            pmask = Image.fromarray((smask[by0:by1 + 1, bx0:bx1 + 1] * 255).astype(np.uint8))
            patch.putalpha(pmask)
            sc = 1.35 if level == 2 else 1.60
            big = patch.resize((int(patch.width * sc), int(patch.height * sc)), Image.NEAREST)
            arra = np.asarray(fr).copy()
            arra[smask] = (0, 0, 0, 0)
            fr = Image.fromarray(arra, "RGBA").copy()
            nx = bx1 + 3 - big.width
            ny = int(c[2] - big.height / 2)
            fr.alpha_composite(big, (nx, ny))
            break
    # (Da thu giap vai ve tu do — neo theo bbox lech o frame tan cong,
    # bo. Kiem si dua vao ao choang + khien to + chum mu de khac bong dang.)
    return fr


def u_archer(fr, l1fr, level, shades):
    bb = _frame_bbox(fr)
    if bb is None:
        return fr
    x0, y0, x1, y1 = bb
    # Bao ten nap sau vai trai: day bao bi mu che, chi lo dau ten + than
    # bao ben trai mu (neo vao trong bbox than, khong dung ngoai).
    lx, ty = x0 + 8, y0 + 14

    def quiver(d):
        d.polygon([(lx, ty + 30), (lx + 10, ty + 27), (lx + 15, ty + 4), (lx + 5, ty + 1)],
                  fill=LEATHER + (255,))
        d.line([(lx, ty + 30), (lx + 5, ty + 1)], fill=LEATHER_D + (255,), width=2)
        band = G.GOLD if level == 3 else shades[1]
        d.line([(lx + 2, ty + 20), (lx + 12, ty + 18)], fill=band + (255,), width=2)
        for i, ax in enumerate((lx + 6, lx + 10, lx + 13)):
            tip = G.GOLD_LIGHT if level == 3 else G.STEEL_RAMP[3]
            d.line([(ax, ty + 4), (ax - 1, ty - 5)], fill=(0xC8, 0xB0, 0x88, 255))
            d.polygon([(ax - 3, ty - 3), (ax + 1, ty - 3), (ax - 1, ty - 8)], fill=tip + (255,))
            d.rectangle([ax - 3, ty + 2, ax, ty + 5], fill=shades[2] + (255,))

    return _behind(fr, quiver)


def u_pawn(fr, l1fr, level, shades):
    bb = _frame_bbox(fr)
    if bb is None:
        return fr
    x0, y0, x1, y1 = bb
    pw, ph = (19, 24) if level == 2 else (23, 30)
    # Ba lo o ngang torso phia sau ben phai (khong de len dau)
    bx, by = x1 - pw + 6, y0 + int(0.34 * (y1 - y0))

    def pack(d):
        d.rectangle([bx, by, bx + pw, by + ph], outline=G.OUTLINE_DARK + (255,), width=2)
        d.rectangle([bx, by, bx + pw, by + ph], fill=LEATHER + (255,))
        d.rectangle([bx, by, bx + pw, by + 5], fill=LEATHER_D + (255,))
        d.line([(bx, by + ph // 2), (bx + pw, by + ph // 2)], fill=LEATHER_D + (255,), width=2)
        if level == 3:
            # cuon chan tren ba lo + khoa vang
            d.rectangle([bx - 1, by - 6, bx + pw + 1, by - 1], fill=shades[1] + (255,))
            d.line([(bx - 1, by - 6), (bx + pw + 1, by - 6)], fill=shades[2] + (255,))
            ccx, ccy = bx + pw // 2, by + ph // 2
            d.rectangle([ccx - 2, ccy - 2, ccx + 2, ccy + 2], fill=G.GOLD + (255,))

    return _behind(fr, pack)


def u_lancer(fr, l1fr, level, shades):
    roles = G.role_map(l1fr, FACTION)
    fmask = roles == G.R_FACTION
    if not fmask.any():
        return fr
    lab, comps = G.components(fmask)
    body = max(comps, key=lambda c: c[0])
    bcx, bcy = body[1], body[2]
    bx0 = body[3]
    # Chom mu: moc tu dinh cum thep lon nhat (mu) len tren
    outa = np.asarray(fr).copy()
    origa = np.asarray(l1fr)
    steel = roles == G.R_STEEL
    if steel.any():
        slab, scomps = G.components(steel)
        helm = max(scomps, key=lambda c: c[0])
        hmask = slab == scomps.index(helm)
        H = hmask.shape[0]
        top_s = int(np.nonzero(hmask.any(axis=1))[0][0])
        seed = hmask & (np.arange(H)[:, None] <= top_s + 5)
        if level == 3:
            golds = G._gold_arr(G._vmap(origa), FACTION, level)
            ys, xs = np.nonzero(seed)
            for y, x in zip(ys.tolist(), xs.tolist()):
                outa[y, x] = (int(golds[y, x][0]), int(golds[y, x][1]), int(golds[y, x][2]), 255)
            G.dilate_paint(outa, 0, seed, 3, ((-1, -1), (-1, 0), (-1, 1)))
        else:
            G.dilate_paint(outa, 0, seed, 2, ((-1, -1), (-1, 0), (-1, 1)))
        fr = Image.fromarray(outa, "RGBA").copy()
    # Khien tron gan o tay trai than
    d = ImageDraw.Draw(fr, "RGBA")
    r = 10 if level == 2 else 13
    ccx, ccy = int(bx0) + 1, int(bcy) + 2
    rim = G.STEEL_RAMP[3] if level == 2 else G.GOLD
    d.ellipse([ccx - r - 1, ccy - r - 1, ccx + r + 1, ccy + r + 1], fill=G.OUTLINE_DARK + (255,))
    d.ellipse([ccx - r, ccy - r, ccx + r, ccy + r], fill=rim + (255,))
    d.ellipse([ccx - r + 2, ccy - r + 2, ccx + r - 2, ccy + r - 2], fill=shades[1] + (255,))
    d.ellipse([ccx - 3, ccy - 3, ccx + 3, ccy + 3], fill=rim + (255,))
    d.point((ccx - 1, ccy - 1), fill=(G.GOLD_PALE if level == 3 else G.STEEL_RAMP[4]) + (255,))
    return fr


UNIT_V3 = {"warrior": u_warrior, "archer": u_archer, "pawn": u_pawn, "lancer": u_lancer}


# ----------------------------------------------------------------------
# Sinh mau + anh so sanh
# ----------------------------------------------------------------------

def gen_building(name, level):
    src = os.path.join(HERE, "buildings", f"{name}_{FACTION}_lv{level}.png")
    base = Image.open(src).convert("RGBA")
    out = BUILDERS_V3[name](base, level)
    dst = os.path.join(UP, "buildings", f"{name}_{FACTION}_lv{level}.png")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    out.save(dst)
    return out


def gen_unit_strip(utype, strip, level):
    src = os.path.join(HERE, "units", FACTION, f"{strip}_lv{level}.png")
    base = Image.open(src).convert("RGBA")
    l1 = Image.open(G.l1_path("unit", FACTION, strip)).convert("RGBA")
    fw = G.FRAME_W[utype]
    shades = G.faction_shades(l1, FACTION)
    out = Image.new("RGBA", base.size, (0, 0, 0, 0))
    n = base.width // fw
    for f in range(n):
        fr = base.crop((f * fw, 0, (f + 1) * fw, fw))
        l1fr = l1.crop((f * fw, 0, (f + 1) * fw, fw))
        out.alpha_composite(UNIT_V3[utype](fr, l1fr, level, shades), (f * fw, 0))
    dst = os.path.join(UP, "units", FACTION, f"{strip}_lv{level}.png")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    out.save(dst)
    return out


def _label_row(cells, caps, scale=2, cell_pad=10):
    """cells: list PIL (cung chieu cao chuan hoa theo o), caps: nhan cot."""
    cw = max(c.width * scale for c in cells)
    ch = max(c.height * scale for c in cells)
    W = cw * len(cells) + cell_pad * (len(cells) + 1)
    H = ch + 30 + cell_pad
    sheet = Image.new("RGB", (W, H), (40, 42, 54))
    d = ImageDraw.Draw(sheet)
    for i, (img, cap) in enumerate(zip(cells, caps)):
        r = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        x = cell_pad + i * (cw + cell_pad) + (cw - r.width) // 2
        y = 24 + (ch - r.height)
        d.text((x + 2, 6), cap, fill=(255, 230, 130))
        sheet.paste(r, (x, y), r)
    return sheet


def comparisons(gen):
    caps = ["CAP 1 (goc)", "CAP 2 (v3)", "CAP 3 (v3)"]
    for name in BUILDERS_V3:
        l1 = Image.open(os.path.join(ROOT, "assets", "buildings", f"{name}_{FACTION}.png")).convert("RGBA")
        sheet = _label_row([l1, gen[("b", name, 2)], gen[("b", name, 3)]], caps, scale=2)
        sheet.save(os.path.join(UP, f"cmp_{name}.png"))
    rep = {"warrior": ("warrior_idle", 192), "archer": ("archer_idle", 192),
           "pawn": ("pawn_idle", 192), "lancer": ("lancer_idle", 320)}
    for utype, (strip, fw) in rep.items():
        l1 = Image.open(G.l1_path("unit", FACTION, strip)).convert("RGBA").crop((0, 0, fw, fw))
        sheet = _label_row([l1, gen[("u", strip, 2)].crop((0, 0, fw, fw)),
                            gen[("u", strip, 3)].crop((0, 0, fw, fw))], caps, scale=2)
        sheet.save(os.path.join(UP, f"cmp_{utype}.png"))
    # anh tong: moi hang 1 loai, 3 cot cap, o 300px
    rows = []
    for name in ["castle", "barracks", "tower", "house", "storehouse"]:
        l1 = Image.open(os.path.join(ROOT, "assets", "buildings", f"{name}_{FACTION}.png")).convert("RGBA")
        rows.append((name, [l1, gen[("b", name, 2)], gen[("b", name, 3)]]))
    for utype, (strip, fw) in rep.items():
        l1 = Image.open(G.l1_path("unit", FACTION, strip)).convert("RGBA").crop((0, 0, fw, fw))
        rows.append((utype, [l1, gen[("u", strip, 2)].crop((0, 0, fw, fw)),
                             gen[("u", strip, 3)].crop((0, 0, fw, fw))]))
    CELL = 300
    sheet = Image.new("RGB", (CELL * 3 + 110, CELL * len(rows) + 30), (40, 42, 54))
    d = ImageDraw.Draw(sheet)
    for j, cap in enumerate(caps):
        d.text((110 + j * CELL + 8, 8), cap, fill=(160, 200, 255))
    for i, (name, cells) in enumerate(rows):
        d.text((6, 30 + i * CELL + 8), name, fill=(255, 230, 130))
        for j, img in enumerate(cells):
            sc = min((CELL - 12) / img.width, (CELL - 12) / img.height)
            r = img.resize((int(img.width * sc), int(img.height * sc)), Image.NEAREST)
            sheet.paste(r, (110 + j * CELL + (CELL - r.width) // 2, 30 + i * CELL + (CELL - r.height) // 2), r)
    sheet.save(os.path.join(UP, "cmp_all.png"))


def main():
    os.makedirs(UP, exist_ok=True)
    gen = {}
    for name in BUILDERS_V3:
        for lv in (2, 3):
            gen[("b", name, lv)] = gen_building(name, lv)
    for utype, strips in G.UNIT_STRIPS.items():
        if utype not in UNIT_V3:
            continue
        for strip in strips:
            if strip == "arrow":
                continue
            for lv in (2, 3):
                gen[("u", strip, lv)] = gen_unit_strip(utype, strip, lv)
    comparisons(gen)
    print("Da sinh mau v3 (blue) vao", UP)


if __name__ == "__main__":
    main()
