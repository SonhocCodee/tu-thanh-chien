#!/usr/bin/env python3
"""
VERIFY.py — kiểm chứng tự động toàn bộ asset nâng cấp trong assets/upgrades/.

Mỗi file lv2/lv3 phải:
  1. Cùng kích thước (== cùng số frame) với file cấp 1 tương ứng.
  2. Không mất pixel đặc nào của cấp 1.
  3. Pixel đặc MỚI (vòng 2: cờ/chóp/ống khói/chùm mũ mọc/chân cờ giáo...) phải
     nằm TRONG canvas và DÍNH vào silhouette gốc: lan truyền 8 hướng từ
     pixel gốc qua pixel mới phải chạm được mọi pixel mới (không có chi
     tiết lơ lửng rời rạc).
  4. Số màu duy nhất không bùng nổ (> 2.2x số màu cấp 1 + 80 là nghi lem).
  5. Thực sự KHÁC cấp 1; in thêm % pixel thay đổi để soi mức phân biệt.

Chạy: python3 assets/upgrades/VERIFY.py  -> bảng PASS/FAIL + thống kê.
"""
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import GENERATOR as G  # noqa: E402


def check(l1_path, lv_path):
    problems = []
    a = Image.open(l1_path).convert("RGBA")
    b = Image.open(lv_path).convert("RGBA")
    if a.size != b.size:
        return [f"kích thước {b.size} != gốc {a.size}"], 0.0
    aa = np.asarray(a)
    ba = np.asarray(b)
    solid_a = aa[..., 3] > 0
    solid_b = ba[..., 3] > 0
    lost = int((solid_a & ~solid_b).sum())
    if lost:
        problems.append(f"mất {lost} pixel đặc của cấp 1")
    new = solid_b & ~solid_a
    n_new = int(new.sum())
    if n_new:
        # lan truyền từ silhouette gốc qua vùng (gốc ∪ mới)
        reach = solid_a.copy()
        dq = deque(map(tuple, np.argwhere(solid_a)))
        H, W = solid_a.shape
        while dq:
            y, x = dq.popleft()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < H and 0 <= nx < W and not reach[ny, nx] and solid_b[ny, nx]:
                        reach[ny, nx] = True
                        dq.append((ny, nx))
        orphans = int((new & ~reach).sum())
        if orphans:
            problems.append(f"{orphans} pixel đặc MỚI lơ lửng (không dính silhouette gốc)")
    ca = len(np.unique(aa.reshape(-1, 4), axis=0))
    cb = len(np.unique(ba.reshape(-1, 4), axis=0))
    if cb > ca * 2.2 + 80:
        problems.append(f"số màu bùng nổ: {cb} vs gốc {ca}")
    if aa.tobytes() == ba.tobytes():
        problems.append("giống hệt cấp 1 (chưa biến đổi)")
    changed = float((np.any(aa != ba, axis=2) & solid_a).sum()) / max(1, int(solid_a.sum()))
    return problems, changed


def main():
    G.ensure_lancer_src()
    total = 0
    failed = 0
    stats = []
    for faction in G.COLORS:
        for bname in G.BUILDINGS:
            for lv in (2, 3):
                p = os.path.join(G.OUT, "buildings", f"{bname}_{faction}_lv{lv}.png")
                total += 1
                if not os.path.exists(p):
                    probs, ch = ["THIẾU FILE"], 0.0
                else:
                    probs, ch = check(G.l1_path("building", faction, bname), p)
                stats.append((ch, os.path.relpath(p, G.ROOT)))
                if probs:
                    failed += 1
                    print(f"FAIL {os.path.relpath(p, G.ROOT)}: {'; '.join(probs)}")
        for utype, strips in G.UNIT_STRIPS.items():
            for name in strips:
                for lv in (2, 3):
                    p = os.path.join(G.OUT, "units", faction, f"{name}_lv{lv}.png")
                    total += 1
                    if not os.path.exists(p):
                        probs, ch = ["THIẾU FILE"], 0.0
                    else:
                        probs, ch = check(G.l1_path("unit", faction, name), p)
                    stats.append((ch, os.path.relpath(p, G.ROOT)))
                    if probs:
                        failed += 1
                        print(f"FAIL {os.path.relpath(p, G.ROOT)}: {'; '.join(probs)}")
    print(f"\n== {total - failed}/{total} file PASS, {failed} FAIL ==")
    stats.sort()
    print("\n10 file ÍT thay đổi nhất so với cấp 1 (% pixel đặc đổi màu/thêm):")
    for ch, p in stats[:10]:
        print(f"  {ch * 100:5.1f}%  {p}")


if __name__ == "__main__":
    main()
