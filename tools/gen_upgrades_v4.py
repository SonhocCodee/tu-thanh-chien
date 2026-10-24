# -*- coding: utf-8 -*-
"""
GENERATOR V4 — bản NHÂN RỘNG 4 PHE cho hệ thống nâng cấp (nhánh nang-cap).

Lấy nguyên ánh xạ vòng 4 của assets/upgrades/GENERATOR_V4.py (bản mẫu chỉ
phe blue, chờ user duyệt) và chạy cho cả 4 phe blue/purple/red/yellow.
Phương pháp vòng 4 (xem preview_v4/README.md trên nhánh asset-nang-cap):
chỉ dùng THIẾT KẾ GỐC KHÁC HẲN của pack (Free Pack vs Update 010) + ghép
nhiều công trình/quân + strip gốc khác (Guard/Attack2/Defence) + phóng tỉ
lệ (pawn/archer lv3). Mọi file ra có CÙNG canvas + CÙNG số frame như file
cấp 1 của game -> code game chỉ đổi đường dẫn texture theo cấp.

Chạy: python3 tools/gen_upgrades_v4.py
Đọc thẳng 2 zip nguồn trong ~/workspace/user/files/, không cần giải nén.
Kết quả -> assets/upgrades/buildings/<loai>_<mau>_lv{2,3}.png
           assets/upgrades/units/<mau>/<strip>_lv{2,3>.png (+ arrow)
"""
import io
import os
import zipfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # project root
GAME_ASSETS = os.path.join(ROOT, "assets")
OUT_B = os.path.join(GAME_ASSETS, "upgrades", "buildings")
OUT_U = os.path.join(GAME_ASSETS, "upgrades", "units")

FP_ZIP = os.path.expanduser("~/workspace/user/files/Tiny_Swords__Free_Pack.zip")
U010_ZIP = os.path.expanduser("~/workspace/user/files/Tiny_Swords.zip")
FP_PRE = "Tiny Swords (Free Pack)/"
U010_PRE = "Tiny Swords (Update 010)/"

COLORS = [("blue", "Blue"), ("purple", "Purple"), ("red", "Red"), ("yellow", "Yellow")]


def load_zip(zpath, inner):
    with zipfile.ZipFile(zpath) as z:
        names = z.namelist()
        if inner not in names:
            # Ban Purple cua Archer trong Update 010 bi go sai ten file
            # (Archer_Purlple.png) — thu bien the go sai truoc, roi moi
            # fallback theo hau to nhu GENERATOR_V4 goc.
            typo = inner.replace("Archer_Purple", "Archer_Purlple")
            if typo in names:
                inner = typo
            else:
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


# ---------------- helpers (nguyen ban GENERATOR_V4) ----------------

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
    assert top_img.size == bot_img.size
    out = bot_img.copy()
    out.alpha_composite(top_img.crop((0, 0, top_img.width, y)), (0, 0))
    return out


def behind(base, layer, dx, dy):
    out = Image.new("RGBA", base.size, (0, 0, 0, 0))
    out.alpha_composite(layer, (dx, dy))
    out.alpha_composite(base, (0, 0))
    return out


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


FW, LW = 192, 320
fails = []


def chk(path, ref_img):
    im = Image.open(path)
    if im.size != ref_img.size:
        fails.append((path, im.size, ref_img.size))
        print("  FAIL", os.path.relpath(path, ROOT), im.size, "vs goc", ref_img.size)


def gen_color(key, cap):
    print("== Phe", key, "==")
    B = {
        "castle": fp(f"Buildings/{cap} Buildings/Castle.png"),
        "house1": fp(f"Buildings/{cap} Buildings/House1.png"),
        "house2": fp(f"Buildings/{cap} Buildings/House2.png"),
        "house3": fp(f"Buildings/{cap} Buildings/House3.png"),
        "barracks": fp(f"Buildings/{cap} Buildings/Barracks.png"),
        "archery": fp(f"Buildings/{cap} Buildings/Archery.png"),
        "tower": fp(f"Buildings/{cap} Buildings/Tower.png"),
        "monastery": fp(f"Buildings/{cap} Buildings/Monastery.png"),
    }
    B10 = {
        "castle": u010(f"Factions/Knights/Buildings/Castle/Castle_{cap}.png"),
        "house": u010(f"Factions/Knights/Buildings/House/House_{cap}.png"),
        "tower": u010(f"Factions/Knights/Buildings/Tower/Tower_{cap}.png"),
    }
    W_FP = {
        "idle": fp(f"Units/{cap} Units/Warrior/Warrior_Idle.png"),
        "run": fp(f"Units/{cap} Units/Warrior/Warrior_Run.png"),
        "attack1": fp(f"Units/{cap} Units/Warrior/Warrior_Attack1.png"),
        "attack2": fp(f"Units/{cap} Units/Warrior/Warrior_Attack2.png"),
        "guard": fp(f"Units/{cap} Units/Warrior/Warrior_Guard.png"),
    }
    L_FP = {
        "idle": fp(f"Units/{cap} Units/Lancer/Lancer_Idle.png"),
        "run": fp(f"Units/{cap} Units/Lancer/Lancer_Run.png"),
        "atk_right": fp(f"Units/{cap} Units/Lancer/Lancer_Right_Attack.png"),
        "atk_down": fp(f"Units/{cap} Units/Lancer/Lancer_Down_Attack.png"),
        "atk_downright": fp(f"Units/{cap} Units/Lancer/Lancer_DownRight_Attack.png"),
        "def_right": fp(f"Units/{cap} Units/Lancer/Lancer_Right_Defence.png"),
        "def_down": fp(f"Units/{cap} Units/Lancer/Lancer_Down_Defence.png"),
    }
    PAWN10 = u010(f"Factions/Knights/Troops/Pawn/{cap}/Pawn_{cap}.png")
    WARR10 = u010(f"Factions/Knights/Troops/Warrior/{cap}/Warrior_{cap}.png")
    ARCH10 = u010(f"Factions/Knights/Troops/Archer/{cap}/Archer_{cap}.png")
    ARROW10 = u010("Factions/Knights/Troops/Archer/Arrow/Arrow.png")

    out_u = os.path.join(OUT_U, key)

    # ---- BUILDINGS (anh xa y het ban mau blue) ----
    save(B["castle"], os.path.join(OUT_B, f"castle_{key}_lv2.png"))
    castle = B["castle"].copy()
    spire = B["monastery"].crop((24, 36, 168, 196))
    crown = B["tower"].crop((0, 30, 128, 140))
    tmp = Image.new("RGBA", castle.size, (0, 0, 0, 0))
    tmp = behind(tmp, crown, 2, 2)
    tmp = behind(tmp, crown, 190, 2)
    tmp = behind(tmp, spire, (320 - 144) // 2, 2)
    save(behind(castle, tmp, 0, 0), os.path.join(OUT_B, f"castle_{key}_lv3.png"))

    save(B["archery"], os.path.join(OUT_B, f"barracks_{key}_lv2.png"))
    mon_top = B["monastery"].crop((8, 40, 184, 195))
    save(behind(B["barracks"].copy(), mon_top, 8, 0),
         os.path.join(OUT_B, f"barracks_{key}_lv3.png"))

    save(B10["tower"], os.path.join(OUT_B, f"tower_{key}_lv2.png"))
    save(splice_h(B["tower"], B10["tower"], 150),
         os.path.join(OUT_B, f"tower_{key}_lv3.png"))

    save(B["house3"], os.path.join(OUT_B, f"house_{key}_lv2.png"))
    save(splice_h(B["house3"], B["house1"], 118),
         os.path.join(OUT_B, f"house_{key}_lv3.png"))

    save(B10["house"], os.path.join(OUT_B, f"storehouse_{key}_lv2.png"))
    save(splice_h(B["house3"], B["house2"], 104),
         os.path.join(OUT_B, f"storehouse_{key}_lv3.png"))

    # ---- PAWN: lv2 = nhan vat Update 010; lv3 = lv2 phong 1.25x ----
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
        save(img, os.path.join(out_u, f"{name}_lv2.png"))
        save(scale_strip(img, FW, 1.25), os.path.join(out_u, f"{name}_lv3.png"))

    # ---- WARRIOR: lv2 = Guard chay + Attack2 danh; lv3 = Warrior U010 ----
    save(W_FP["idle"], os.path.join(out_u, "warrior_idle_lv2.png"))
    save(W_FP["guard"], os.path.join(out_u, "warrior_run_lv2.png"))
    save(W_FP["attack2"], os.path.join(out_u, "warrior_attack_lv2.png"))
    wr = [row_of(WARR10, r) for r in range(8)]
    save(strip(pingpong(wr[0], 8)), os.path.join(out_u, "warrior_idle_lv3.png"))
    save(strip(wr[1]), os.path.join(out_u, "warrior_run_lv3.png"))
    save(strip([wr[2][0], wr[2][3], wr[2][4], wr[2][5]]),
         os.path.join(out_u, "warrior_attack_lv3.png"))

    # ---- ARCHER: lv2 = Archer U010; lv3 = phong 1.2x, shoot hang 3 ----
    ar = [row_of(ARCH10, r) for r in range(7)]
    arch_lv2 = {
        "archer_idle": strip(ar[0][:6]),
        "archer_run": strip(ar[1][:4]),
        "archer_shoot": strip(ar[4][:8]),
    }
    for name, img in arch_lv2.items():
        save(img, os.path.join(out_u, f"{name}_lv2.png"))
    save(scale_strip(arch_lv2["archer_idle"], FW, 1.2),
         os.path.join(out_u, "archer_idle_lv3.png"))
    save(scale_strip(arch_lv2["archer_run"], FW, 1.2),
         os.path.join(out_u, "archer_run_lv3.png"))
    save(scale_strip(strip(ar[3][:8]), FW, 1.2),
         os.path.join(out_u, "archer_shoot_lv3.png"))
    top = ARROW10.crop((0, 0, 64, 64))
    bot = ARROW10.crop((0, 64, 64, 128))

    def _ink(im):
        bb = im.getchannel("A").getbbox()
        return 0 if bb is None else (bb[3] - bb[1])

    arrow = top if _ink(top) >= _ink(bot) else bot
    save(arrow, os.path.join(out_u, "arrow_lv2.png"))
    save(arrow.copy(), os.path.join(out_u, "arrow_lv3.png"))

    # ---- LANCER: lv2 doi strip danh; lv3 doi ca 3 the ----
    save(L_FP["idle"], os.path.join(out_u, "lancer_idle_lv2.png"))
    save(L_FP["run"], os.path.join(out_u, "lancer_run_lv2.png"))
    save(L_FP["atk_downright"], os.path.join(out_u, "lancer_attack_lv2.png"))
    save(strip(pingpong(frames_of(L_FP["def_down"], LW), 12)),
         os.path.join(out_u, "lancer_idle_lv3.png"))
    save(L_FP["def_right"], os.path.join(out_u, "lancer_run_lv3.png"))
    save(L_FP["atk_down"], os.path.join(out_u, "lancer_attack_lv3.png"))

    # ---- VERIFY: kich thuoc phai bang file cap 1 cua game ----
    for t in ["castle", "barracks", "tower", "house", "storehouse"]:
        for lv in (2, 3):
            chk(os.path.join(OUT_B, f"{t}_{key}_lv{lv}.png"),
                game(f"buildings/{t}_{key}.png"))
    unit_refs = {
        "pawn_idle": "pawn_idle", "pawn_run": "pawn_run", "pawn_axe": "pawn_axe",
        "pawn_knife": "pawn_knife", "pawn_pick": "pawn_pick",
        "pawn_run_wood": "pawn_run_wood", "pawn_run_gold": "pawn_run_gold",
        "pawn_run_meat": "pawn_run_meat",
        "warrior_idle": "warrior_idle", "warrior_run": "warrior_run",
        "warrior_attack": "warrior_attack",
        "archer_idle": "archer_idle", "archer_run": "archer_run",
        "archer_shoot": "archer_shoot", "arrow": "arrow",
        "lancer_idle": "lancer_idle", "lancer_run": "lancer_run",
        "lancer_attack": "lancer_attack",
    }
    for name, ref in unit_refs.items():
        for lv in (2, 3):
            chk(os.path.join(out_u, f"{name}_lv{lv}.png"),
                game(f"units/{key}/{ref}.png"))


for key, cap in COLORS:
    gen_color(key, cap)

print("VERIFY:", "TAT CA PASS" if not fails else f"{len(fails)} FAIL")
if fails:
    raise SystemExit(1)
