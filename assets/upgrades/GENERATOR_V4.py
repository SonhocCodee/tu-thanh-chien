# -*- coding: utf-8 -*-
"""
GENERATOR V4 — MAU asset nang cap VONG 4 (chi phe BLUE, cho user duyet).

Doi han phuong phap theo lenh user: CAM chinh sua tren cung 1 sprite goc
(doi mau / them chi tiet / keo slab nhu vong 1-3). Vong 4 chi dung:
  NGUON 1: thiet ke GOC KHAC HAN cua chinh pack (Free Pack + Update 010
           la 2 the he thiet ke khac nhau — da doi chieu pixel de xac nhan).
  NGUON 2: ghep NHIEU cong trinh/quan khac nhau thanh 1 khoi moi
           (dan lop sau/truoc, noi ngang tai duong cat tu nhien),
           hoac strip goc khac cua cung loai quan (Guard/Attack2/
           Defence cua pack), hoac ve lai ty le (chi pawn/archer lv3 —
           ghi ro trong README preview_v4).

Rang buoc: cung canvas, cung so frame/strip nhu file cap 1 cua game,
chan de/diem neo giu nguyen (moi thao tac neo theo day bbox cua chinh
frame, khong day chan de).

Chay: python3 GENERATOR_V4.py  (tu dong doc 2 zip nguon, khong can giai nen)
Ket qua -> assets/upgrades/preview_v4/ (buildings/, units/blue/, cmp_*.png)
"""
import io
import os
import zipfile

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GAME_ASSETS = os.path.dirname(HERE)  # .../assets
OUT = os.path.join(HERE, "preview_v4")
OUT_B = os.path.join(OUT, "buildings")
OUT_U = os.path.join(OUT, "units", "blue")

FP_ZIP = os.path.expanduser("~/workspace/user/files/Tiny_Swords__Free_Pack.zip")
U010_ZIP = os.path.expanduser("~/workspace/user/files/Tiny_Swords.zip")
FP_PRE = "Tiny Swords (Free Pack)/"
U010_PRE = "Tiny Swords (Update 010)/"


def load_zip(zpath, inner):
    with zipfile.ZipFile(zpath) as z:
        names = z.namelist()
        if inner not in names:  # fallback: tim theo hau to
            cand = [n for n in names if n.endswith(inner.split("/")[-1])
                    and inner.split("/")[-2] in n]
            if not cand:
                raise FileNotFoundError(inner)
            inner = cand[0]
        data = z.read(inner)
    return Image.open(io.BytesIO(data)).convert("RGBA")


def fp(rel):
    return load_zip(FP_ZIP, FP_PRE + rel)


def u010(rel):
    return load_zip(U010_ZIP, U010_PRE + rel)


def game(rel):
    return Image.open(os.path.join(GAME_ASSETS, rel)).convert("RGBA")


# ---------------- helpers ----------------

def frames_of(strip, fw):
    return [strip.crop((i * fw, 0, (i + 1) * fw, strip.height))
            for i in range(strip.width // fw)]


def row_of(sheet, r, fw=192, fh=192):
    cols = sheet.width // fw
    return [sheet.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh))
            for c in range(cols)]


def strip(frames):
    w = sum(f.width for f in frames)
    h = max(f.height for f in frames)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = 0
    for f in frames:
        out.alpha_composite(f, (x, 0))
        x += f.width
    return out


def pingpong(frames, n):
    if len(frames) >= n:
        return frames[:n]
    seq = list(frames) + list(reversed(frames[1:-1] if len(frames) > 2 else frames))
    out = []
    i = 0
    while len(out) < n:
        out.append(seq[i % len(seq)])
        i += 1
    return out


def scale_frame(frame, factor):
    """Phong toan bo noi dung frame quanh neo day bbox (chan khong doi)."""
    bbox = frame.getchannel("A").getbbox()
    if bbox is None:
        return frame.copy()
    x0, y0, x1, y1 = bbox
    w, h = x1 - x0, y1 - y0
    f = min(factor, frame.width / w, frame.height / h)
    nw, nh = max(1, round(w * f)), max(1, round(h * f))
    content = frame.crop(bbox).resize((nw, nh), Image.NEAREST)
    out = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    cx = (x0 + x1) // 2
    out.alpha_composite(content, (cx - nw // 2, y1 - nh))
    return out


def scale_strip(strip_img, fw, factor):
    return strip([scale_frame(fr, factor) for fr in frames_of(strip_img, fw)])


def splice_h(top_img, bot_img, y):
    """Noi ngang: tren = top_img [0..y), duoi = bot_img [y..H). Cung canvas."""
    assert top_img.size == bot_img.size
    out = bot_img.copy()
    out.alpha_composite(top_img.crop((0, 0, top_img.width, y)), (0, 0))
    return out


def behind(base, layer, dx, dy):
    """Dan layer PHIA SAU base, cung canvas voi base (layer co the tran)."""
    out = Image.new("RGBA", base.size, (0, 0, 0, 0))
    out.alpha_composite(layer, (dx, dy))
    out.alpha_composite(base, (0, 0))
    return out


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("  ->", os.path.relpath(path, OUT), img.size)


# ---------------- tai nguon ----------------
print("== Tai sprite nguon ==")
B = {  # buildings Free Pack (Blue)
    "castle": fp("Buildings/Blue Buildings/Castle.png"),
    "house1": fp("Buildings/Blue Buildings/House1.png"),
    "house2": fp("Buildings/Blue Buildings/House2.png"),
    "house3": fp("Buildings/Blue Buildings/House3.png"),
    "barracks": fp("Buildings/Blue Buildings/Barracks.png"),
    "archery": fp("Buildings/Blue Buildings/Archery.png"),
    "tower": fp("Buildings/Blue Buildings/Tower.png"),
    "monastery": fp("Buildings/Blue Buildings/Monastery.png"),
}
B10 = {  # buildings Update 010
    "castle": u010("Factions/Knights/Buildings/Castle/Castle_Blue.png"),
    "house": u010("Factions/Knights/Buildings/House/House_Blue.png"),
    "tower": u010("Factions/Knights/Buildings/Tower/Tower_Blue.png"),
}
W_FP = {  # warrior Free Pack
    "idle": fp("Units/Blue Units/Warrior/Warrior_Idle.png"),
    "run": fp("Units/Blue Units/Warrior/Warrior_Run.png"),
    "attack1": fp("Units/Blue Units/Warrior/Warrior_Attack1.png"),
    "attack2": fp("Units/Blue Units/Warrior/Warrior_Attack2.png"),
    "guard": fp("Units/Blue Units/Warrior/Warrior_Guard.png"),
}
L_FP = {  # lancer Free Pack (frame 320)
    "idle": fp("Units/Blue Units/Lancer/Lancer_Idle.png"),
    "run": fp("Units/Blue Units/Lancer/Lancer_Run.png"),
    "atk_right": fp("Units/Blue Units/Lancer/Lancer_Right_Attack.png"),
    "atk_down": fp("Units/Blue Units/Lancer/Lancer_Down_Attack.png"),
    "atk_downright": fp("Units/Blue Units/Lancer/Lancer_DownRight_Attack.png"),
    "def_right": fp("Units/Blue Units/Lancer/Lancer_Right_Defence.png"),
    "def_up": fp("Units/Blue Units/Lancer/Lancer_Up_Defence.png"),
    "def_down": fp("Units/Blue Units/Lancer/Lancer_Down_Defence.png"),
}
PAWN10 = u010("Factions/Knights/Troops/Pawn/Blue/Pawn_Blue.png")
WARR10 = u010("Factions/Knights/Troops/Warrior/Blue/Warrior_Blue.png")
ARCH10 = u010("Factions/Knights/Troops/Archer/Blue/Archer_Blue.png")
ARROW10 = u010("Factions/Knights/Troops/Archer/Arrow/Arrow.png")

# ---------------- BUILDINGS ----------------
print("== Buildings ==")
# castle: lv2 = FP Castle (thiet ke goc khac); lv3 = FP Castle + thap giu
# Monastery phia sau giua + 2 dinh Tower FP 2 ben sau (khoi phao dai moi)
save(B["castle"], os.path.join(OUT_B, "castle_blue_lv2.png"))
castle = B["castle"].copy()
spire = B["monastery"].crop((24, 36, 168, 196))          # 144x160: chop + mai
crown = B["tower"].crop((0, 30, 128, 140))                # dinh thap FP 128x110
tmp = Image.new("RGBA", castle.size, (0, 0, 0, 0))
tmp = behind(tmp, crown, 2, 2)
tmp = behind(tmp, crown, 190, 2)
tmp = behind(tmp, spire, (320 - 144) // 2, 2)
castle3 = behind(castle, tmp, 0, 0)
save(castle3, os.path.join(OUT_B, "castle_blue_lv3.png"))

# barracks: lv2 = FP Archery (thiet ke goc khac); lv3 = Barracks + dinh
# Monastery (chop + dong ho + mai) moc phia sau — khoi doanh trai co thap
save(B["archery"], os.path.join(OUT_B, "barracks_blue_lv2.png"))
mon_top = B["monastery"].crop((8, 40, 184, 195))          # 176x155
barr3 = behind(B["barracks"].copy(), mon_top, 8, 0)
save(barr3, os.path.join(OUT_B, "barracks_blue_lv3.png"))

# tower: lv2 = U010 Tower (thiet ke goc khac); lv3 = noi ngang: nua tren
# FP Tower (dinh + san + tuong tren) + nua duoi U010 Tower (tuong duoi +
# chan go + cua) tai y=150
save(B10["tower"], os.path.join(OUT_B, "tower_blue_lv2.png"))
save(splice_h(B["tower"], B10["tower"], 150), os.path.join(OUT_B, "tower_blue_lv3.png"))

# house: lv2 = FP House3 (thiet ke goc khac); lv3 = mai House3 (lay sau
# xuong y=118, gom ca dai cua so gac) + than/cua House1 — da thu nhieu
# diem noi, y=118 la diem sach nhat (dai khung duoi mai nam ngay tren
# vom cua House1)
save(B["house3"], os.path.join(OUT_B, "house_blue_lv2.png"))
save(splice_h(B["house3"], B["house1"], 118), os.path.join(OUT_B, "house_blue_lv3.png"))

# storehouse: lv2 = U010 House (nha tranh — thiet ke goc khac han);
# lv3 = mai House3 + than House2, noi tai y=104 (khung go 2 sprite khop
# nhau o duong nay, cua vom + cua so House2 con nguyen)
save(B10["house"], os.path.join(OUT_B, "storehouse_blue_lv2.png"))
save(splice_h(B["house3"], B["house2"], 104), os.path.join(OUT_B, "storehouse_blue_lv3.png"))

# ---------------- UNITS ----------------
print("== Units ==")
FW, LW = 192, 320  # frame width: thuong 192, lancer 320

# --- PAWN: lv2 = Pawn Update 010 (toc vang, khac han FP) ---
pr = [row_of(PAWN10, r) for r in range(6)]
pawn_lv2 = {
    "pawn_idle": strip(pingpong(pr[0], 8)),
    "pawn_run": strip(pr[1]),
    "pawn_axe": strip(pr[2]),
    "pawn_knife": strip(pr[2][:4]),
    "pawn_pick": strip(pr[3]),
    "pawn_run_wood": strip(pr[4]),
    "pawn_run_gold": strip(pr[5]),
    "pawn_run_meat": strip(pr[1]),
}
for name, img in pawn_lv2.items():
    save(img, os.path.join(OUT_U, f"{name}_lv2.png"))
    save(scale_strip(img, FW, 1.25), os.path.join(OUT_U, f"{name}_lv3.png"))

# --- WARRIOR ---
# lv2 = combo strip goc khac cua pack: chay bang Guard (khien truoc),
# danh bang Attack2 (chem nang khac Attack1); idle giu nguyen FP
save(W_FP["idle"], os.path.join(OUT_U, "warrior_idle_lv2.png"))
save(W_FP["guard"], os.path.join(OUT_U, "warrior_run_lv2.png"))
save(W_FP["attack2"], os.path.join(OUT_U, "warrior_attack_lv2.png"))
# lv3 = Warrior Update 010 (mu vang, kiem vang — thiet ke goc khac)
wr = [row_of(WARR10, r) for r in range(8)]
save(strip(pingpong(wr[0], 8)), os.path.join(OUT_U, "warrior_idle_lv3.png"))
save(strip(wr[1]), os.path.join(OUT_U, "warrior_run_lv3.png"))
atk3 = [wr[2][0], wr[2][3], wr[2][4], wr[2][5]]
save(strip(atk3), os.path.join(OUT_U, "warrior_attack_lv3.png"))

# --- ARCHER ---
# lv2 = Archer Update 010 (mu rom rong vanh — thiet ke goc khac han)
ar = [row_of(ARCH10, r) for r in range(7)]
arch_lv2 = {
    "archer_idle": strip(ar[0][:6]),
    "archer_run": strip(ar[1][:4]),
    "archer_shoot": strip(ar[4][:8]),
}
for name, img in arch_lv2.items():
    save(img, os.path.join(OUT_U, f"{name}_lv2.png"))
# lv3 = ban U010 phong 1.2x (neo chan), shoot lay hang 3 (huong ban khac)
save(scale_strip(arch_lv2["archer_idle"], FW, 1.2), os.path.join(OUT_U, "archer_idle_lv3.png"))
save(scale_strip(arch_lv2["archer_run"], FW, 1.2), os.path.join(OUT_U, "archer_run_lv3.png"))
save(scale_strip(strip(ar[3][:8]), FW, 1.2), os.path.join(OUT_U, "archer_shoot_lv3.png"))
# arrow: U010 Arrow.png la 64x128 (2 nua) — lay nua chua mui ten tron
top = ARROW10.crop((0, 0, 64, 64))
bot = ARROW10.crop((0, 64, 64, 128))
def _ink(im):
    bb = im.getchannel("A").getbbox()
    return 0 if bb is None else (bb[3] - bb[1])
arrow = top if _ink(top) >= _ink(bot) else bot
save(arrow, os.path.join(OUT_U, "arrow_lv2.png"))
save(arrow.copy(), os.path.join(OUT_U, "arrow_lv3.png"))

# --- LANCER ---
# lv2: tan cong bang DownRight_Attack (goc dam khac), idle/run giu nguyen
save(L_FP["idle"], os.path.join(OUT_U, "lancer_idle_lv2.png"))
save(L_FP["run"], os.path.join(OUT_U, "lancer_run_lv2.png"))
save(L_FP["atk_downright"], os.path.join(OUT_U, "lancer_attack_lv2.png"))
# lv3: idle = Down_Defence (the thu nhin thang, giao chong xuong truoc —
# pingpong 6->12; KHONG dung Up_Defence vi do la lung nhan vat),
# run = Right_Defence (giao nam ngang, lao nhu ky binh), attack = Down_Attack
save(strip(pingpong(frames_of(L_FP["def_down"], LW), 12)), os.path.join(OUT_U, "lancer_idle_lv3.png"))
save(L_FP["def_right"], os.path.join(OUT_U, "lancer_run_lv3.png"))
save(L_FP["atk_down"], os.path.join(OUT_U, "lancer_attack_lv3.png"))

print("Xong phan sinh file mau. Buoc tiep theo: GENERATOR_V4 lam anh cmp + verify.")

# ---------------- ANH SO SANH 3 CAP ----------------
print("== Anh so sanh ==")
BG = (24, 24, 32, 255)
LAB = 26


def label(draw, x, y, text):
    draw.text((x + 4, y + 5), text, fill=(255, 220, 120, 255))


def cmp_row(images, scale=1):
    """1 hang: [lv1, lv2, lv3] canh nhau, nen toi, co nhan."""
    cells = []
    for im in images:
        c = im if scale == 1 else im.resize(
            (im.width * scale, im.height * scale), Image.NEAREST)
        cells.append(c)
    w = sum(c.width for c in cells) + 16 * (len(cells) + 1)
    h = max(c.height for c in cells) + LAB + 12
    sh = Image.new("RGBA", (w, h), BG)
    d = ImageDraw.Draw(sh)
    x = 16
    for i, c in enumerate(cells):
        sh.alpha_composite(c, (x, LAB))
        label(d, x, 0, f"CAP {i + 1}" + (" (goc)" if i == 0 else f" (v4)"))
        x += c.width + 16
    return sh


def unit_frames(strip_img, fw, picks):
    fr = frames_of(strip_img, fw)
    return [fr[i] for i in picks]


def cmp_unit(level_imgs, fw, scale=2):
    """level_imgs: list 3 cap, moi cap = list strip [idle, run/hanh dong].
    Moi o: 3 frame dai dien (idle f0, run f0, hanh dong frame giua)."""
    rows = []
    for stripset in level_imgs:
        cells = []
        for si, st in enumerate(stripset):
            fr = frames_of(st, fw)
            pick = 0 if si < 2 else len(fr) // 2
            im = fr[pick]
            if scale != 1:
                im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
            cells.append(im)
        rows.append(cells)
    cw = max(c.width for r in rows for c in r)
    ch = max(c.height for r in rows for c in r)
    W = cw * 3 + 16 * 4
    H = (ch + LAB) * 3 + 12
    sh = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(sh)
    for li, cells in enumerate(rows):
        y = 12 + li * (ch + LAB)
        label(d, 16, y, f"CAP {li + 1}" + (" (goc)" if li == 0 else " (v4)"))
        for ci, im in enumerate(cells):
            sh.alpha_composite(im, (16 + ci * (cw + 16), y + LAB))
    return sh


def gp(rel):  # game lv1 (phe blue)
    return game(rel)


def op(rel):  # file mau v4 vua sinh
    return Image.open(os.path.join(OUT, rel)).convert("RGBA")


cmp_jobs = []
for t, sc in [("castle", 1), ("barracks", 2), ("tower", 2), ("house", 2), ("storehouse", 2)]:
    img = cmp_row([gp(f"buildings/{t}_blue.png"),
                   op(f"buildings/{t}_blue_lv2.png"),
                   op(f"buildings/{t}_blue_lv3.png")], scale=sc)
    img.convert("RGB").save(os.path.join(OUT, f"cmp_{t}.png"))
    cmp_jobs.append((t, img))
    print("  cmp", t, img.size)

unit_sets = {
    "pawn": (["pawn_idle", "pawn_run", "pawn_axe"], FW, 2),
    "warrior": (["warrior_idle", "warrior_run", "warrior_attack"], FW, 2),
    "archer": (["archer_idle", "archer_run", "archer_shoot"], FW, 2),
    "lancer": (["lancer_idle", "lancer_run", "lancer_attack"], LW, 1),
}
lancer_lv1 = {"lancer_idle": L_FP["idle"], "lancer_run": L_FP["run"],
              "lancer_attack": L_FP["atk_right"]}
for t, (strips, fw, sc) in unit_sets.items():
    levels = []
    for lv in (1, 2, 3):
        ss = []
        for s in strips:
            if lv == 1:
                ss.append(lancer_lv1[s] if t == "lancer" else gp(f"units/blue/{s}.png"))
            else:
                ss.append(op(f"units/blue/{s}_lv{lv}.png"))
        levels.append(ss)
    img = cmp_unit(levels, fw, scale=sc)
    img.convert("RGB").save(os.path.join(OUT, f"cmp_{t}.png"))
    cmp_jobs.append((t, img))
    print("  cmp", t, img.size)

# cmp_all: moi loai 1 hang (idle dai dien cho quan), thu nho vua 1 anh
print("== cmp_all ==")
thumbs = []
for t, sc in [("castle", 1), ("barracks", 1), ("tower", 1), ("house", 1), ("storehouse", 1)]:
    thumbs.append((t, [gp(f"buildings/{t}_blue.png"), op(f"buildings/{t}_blue_lv2.png"),
                       op(f"buildings/{t}_blue_lv3.png")]))
for t, (strips, fw, sc) in unit_sets.items():
    lv1 = lancer_lv1["lancer_idle"] if t == "lancer" else gp(f"units/blue/{strips[0]}.png")
    thumbs.append((t, [frames_of(lv1, fw)[0],
                       frames_of(op(f"units/blue/{strips[0]}_lv2.png"), fw)[0],
                       frames_of(op(f"units/blue/{strips[0]}_lv3.png"), fw)[0]]))
cellw = max(im.width for _, ims in thumbs for im in ims) + 20
cellh = max(im.height for _, ims in thumbs for im in ims) + LAB
W, H = cellw * 3 + 90, cellh * len(thumbs) + 10
sh = Image.new("RGBA", (W, H), BG)
d = ImageDraw.Draw(sh)
for ri, (t, ims) in enumerate(thumbs):
    y = 10 + ri * cellh
    d.text((4, y + 4), t, fill=(255, 220, 120, 255))
    for ci, im in enumerate(ims):
        sh.alpha_composite(im, (90 + ci * cellw, y + LAB))
sh.convert("RGB").save(os.path.join(OUT, "cmp_all.png"))
print("  cmp_all", sh.size)

# ---------------- VERIFY ----------------
print("== VERIFY: kich thuoc file mau phai bang file cap 1 cua game ==")
fails = []
def chk(out_rel, ref_img):
    p = os.path.join(OUT, out_rel)
    im = Image.open(p)
    ok = im.size == ref_img.size
    if not ok:
        fails.append((out_rel, im.size, ref_img.size))
    print(("  OK  " if ok else "  FAIL"), out_rel, im.size,
          "vs goc" , ref_img.size)

for t in ["castle", "barracks", "tower", "house", "storehouse"]:
    for lv in (2, 3):
        chk(f"buildings/{t}_blue_lv{lv}.png", gp(f"buildings/{t}_blue.png"))
for t, (strips, fw, sc) in unit_sets.items():
    for s in strips:
        ref = lancer_lv1[s] if t == "lancer" else gp(f"units/blue/{s}.png")
        for lv in (2, 3):
            chk(f"units/blue/{s}_lv{lv}.png", ref)
for lv in (2, 3):
    chk(f"units/blue/arrow_lv{lv}.png", gp("units/blue/arrow.png"))
print("VERIFY:", "TAT CA PASS" if not fails else f"{len(fails)} FAIL: {fails}")
