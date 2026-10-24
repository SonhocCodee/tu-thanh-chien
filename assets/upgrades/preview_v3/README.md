# MAU VONG 3 — cho duyet (chi phe XANH, chua nhan rong)

Vong 3 doi han cach lam theo lenh user: **ve lai CAU TRUC tung cap tren
nen ban vong 2** — cap sau khac cap truoc o muc HINH KHOI/BONG DANG,
khong chi mau/trang tri. Script: `assets/upgrades/GENERATOR_V3.py`
(chay lai duoc; nen = file vong 2, them lop cau truc). Rang buoc giu
nguyen: cung canvas, cung so frame, chan de khong doi (pixel chi day
LEN TREN / ra ngang vao khoang trong cua canvas).

## Anh de duyet
- `cmp_all.png` — tong 9 loai x 3 cap (nhin thumbnail).
- `cmp_<loai>.png` — tung loai phong 2x: castle, barracks, tower,
  house, storehouse, warrior, archer, pawn, lancer.
- File mau: `buildings/*_blue_lv{2,3}.png`, `units/blue/*_lv{2,3}.png`
  (du moi strip cua 4 loai quan).

## Thay doi cau truc theo loai
- **Castle:** lv2 hai thap ben NHON CAO vuot tuong thanh (+12px, nang
  slab tuong cua chinh sprite, lap bang hang tuong that); lv3 thap ben
  +22 va them THAP GIU trung tam +14, non vang o thap ben, co lon.
- **Barracks:** lv2 thap goc 2 ben +10 va thap canh giua dinh mai +12
  (duong dinh thanh 3 khoi), mai che cong; lv3 thap goc +16, thap giua
  +18, non vang giua + non goc.
- **Tower:** lv2 than keo dai +14 va bac giua san nhon +10; lv3 than
  +20, bac giua +14, non vang + co tren dinh (thap cao dan ro ret).
- **House:** lv2 mai keo CAO +8 (mai doc dai hon han), cua so gac xep,
  mai che cua; lv3 mai +14, gac xep to hon vien vang, ong khoi dai them.
- **Storehouse:** nhu nha dan: mai +8/+14, gac xep, mai che cua.
- **Warrior:** lv2 AO CHOANG sau lung xoe xuong tan chan + khien phong
  to 1.35x; lv3 choang dai/rong hon co vien vang + khoa vang, khien
  1.6x vang, chum mu vang to (vong 2).
- **Archer:** lv2 BAO TEN sau vai (lo dau ten + than bao sau mu); lv3
  bao ten vien/dau ten vang + mu vang (vong 2).
- **Pawn:** lv2 BA LO sau lung ngang torso; lv3 ba lo to hon + cuon
  chan tren ba lo + khoa vang, mu vang (vong 2).
- **Lancer:** lv2 KHIEN TRON gan tay (moi — cap 1 khong co khien), co
  giao phinh to; lv3 khien tron vien vang to hon, chom mu vang moc cao,
  giao + co vang (vong 2).

## Diem chua uoc (trung thuc)
1. Thap canh: o duong cat cua lop keo dai than con 2 vet sang manh
   (hang lap cua chinh sprite) — doc nhu dai trang tri, chua sach 100%.
2. Doanh trai: duong dinh 3 khoi hoi "rang cua" o cap 2 — dung chu dich
   phao dai, nhung la mau tho nhat trong 5 nha.
3. Ba lo nong dan bi mu lon che mot phan (sprite nhin thang, mu chum
   gan het torso) — chi loi duong vien ben phai + cuon chan cap 3.
4. Cung thu chua to cung (chi them bao ten); kiem si da bo giap vai
   (neo theo bbox lech o frame tan cong) — dua vao choang + khien to.

## Trang thai
MAU cho duyet — CHUA nhan rong 4 phe, chua thay bo file vong 2 trong
`assets/upgrades/` (vong 3 dang nam rieng o preview_v3/). Neu duoc
duyet: chay GENERATOR_V3 cho 4 phe ghi de bo lv2/lv3 chinh thuc + chay
lai VERIFY.
