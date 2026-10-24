#!/usr/bin/env python3
"""
VERIFY.py — kiểm chứng tự động toàn bộ asset nâng cấp trong assets/upgrades/.

Mỗi file lv2/lv3 phải:
  1. Cùng kích thước (== cùng số frame) với file cấp 1 tương ứng.
  2. Kênh alpha: không mất pixel đặc nào của cấp 1; pixel đặc MỚI chỉ được
     nằm trong vùng cho phép (nhà cấp 3: dải chóp vàng phía trên đỉnh nhà,
     x trong [cx-2, cx+2]).
  3. Không có màu "lạ" ngoài họ palette: mọi màu mới phải truy được về
     phép biến đổi (kiểm tra gần đúng: màu xuất hiện trong bản đồ màu của
     GENERATOR hoặc thuộc ramp vàng/đá) — ở đây kiểm tra thực dụng: số màu
     duy nhất không bùng nổ (> 1.6x số màu cấp 1 là nghi ngờ lem màu).
  4. Thực sự KHÁC cấp 1 (không phải bản sao nguyên xi).

Chạy: python3 assets/upgrades/VERIFY.py  -> in bảng PASS/FAIL từng file.
"""
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import GENERATOR as G  # noqa: E402


def alpha_mask(im):
    return im.getchannel("A")


def check(l1_path, lv_path, kind):
    problems = []
    a = Image.open(l1_path).convert("RGBA")
    b = Image.open(lv_path).convert("RGBA")
    if a.size != b.size:
        problems.append(f"kích thước {b.size} != gốc {a.size}")
        return problems
    aa, ba = a.load(), b.load()
    W, H = a.size
    # vùng chóp cho phép (chỉ nhà lv3)
    allow = None
    if kind == "building" and "_lv3" in lv_path:
        xs = [x for x in range(W) if any(aa[x, y][3] > 200 for y in range(H))]
        if xs:
            cx = (min(xs) + max(xs)) // 2
            topy = min(y for y in range(H) if any(aa[x, y][3] > 200 for x in range(max(0, cx - 2), min(W, cx + 3))))
            allow = (cx, topy)
    new_px = 0
    lost_px = 0
    bad_new = []
    for y in range(H):
        for x in range(W):
            o = aa[x, y][3]
            n = ba[x, y][3]
            if o > 0 and n == 0:
                lost_px += 1
            elif o == 0 and n > 0:
                new_px += 1
                if allow is None or not (allow[0] - 2 <= x <= allow[0] + 2 and y < allow[1]):
                    bad_new.append((x, y))
    if lost_px:
        problems.append(f"mất {lost_px} pixel đặc của cấp 1")
    if bad_new:
        problems.append(f"{len(bad_new)} pixel đặc MỚI ngoài vùng cho phép, vd {bad_new[:3]}")
    ca = len(set(a.getdata()))
    cb = len(set(b.getdata()))
    if cb > ca * 1.6 + 40:
        problems.append(f"số màu bùng nổ: {cb} vs gốc {ca}")
    if a.tobytes() == b.tobytes():
        problems.append("giống hệt cấp 1 (chưa biến đổi)")
    return problems


def main():
    G.ensure_lancer_src()
    total = 0
    failed = 0
    for faction in G.COLORS:
        for bname in G.BUILDINGS:
            for lv in (2, 3):
                p = os.path.join(G.OUT, "buildings", f"{bname}_{faction}_lv{lv}.png")
                total += 1
                probs = check(G.l1_path("building", faction, bname), p, "building") if os.path.exists(p) else ["THIẾU FILE"]
                if probs:
                    failed += 1
                    print(f"FAIL {os.path.relpath(p, G.ROOT)}: {'; '.join(probs)}")
        for utype, strips in G.UNIT_STRIPS.items():
            for name in strips:
                for lv in (2, 3):
                    p = os.path.join(G.OUT, "units", faction, f"{name}_lv{lv}.png")
                    total += 1
                    probs = check(G.l1_path("unit", faction, name), p, "unit") if os.path.exists(p) else ["THIẾU FILE"]
                    if probs:
                        failed += 1
                        print(f"FAIL {os.path.relpath(p, G.ROOT)}: {'; '.join(probs)}")
    print(f"\n== {total - failed}/{total} file PASS, {failed} FAIL ==")


if __name__ == "__main__":
    main()
