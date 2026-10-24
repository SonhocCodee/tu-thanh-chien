# MAU VONG 4 — cho duyet (chi phe XANH, chua nhan rong)

Vong 4 DOI HAN PHUONG PHAP theo lenh user ("khac han chu k phai ve them
mau vao"). Cam hoan toan chinh sua tren cung 1 sprite goc (doi mau /
them chi tiet / keo slab — cach cua vong 1-3). Vong 4 chi dung:

1. **Thiet ke GOC KHAC HAN cua chinh pack** — Free Pack va Update 010 la
   HAI THE HE thiet ke khac nhau (da doi chieu pixel tung file de xac
   nhan file nao trung het, file nao la ban ve khac).
2. **Ghep nhieu cong trinh/quan KHAC NHAU thanh 1 khoi moi** (dan lop
   phia sau, noi ngang tai duong cat tu nhien), hoac **strip goc khac**
   cua pack (Guard / Attack2 / Defence...), hoac **ve lai ty le**
   (chi 2 o ghi ro ben duoi — phuong an du phong brief cho phep).

Script: `assets/upgrades/GENERATOR_V4.py` (chay lai duoc, doc thang 2
zip nguon, khong can giai nen). Rang buoc giu nguyen: cung canvas, cung
so frame/strip nhu cap 1, chan de giu nguyen. VERIFY kich thuoc trong
generator: **TAT CA PASS** (46 file mau + 10 file strip pawn phu).

## Anh de duyet
- `cmp_all.png` — tong 9 loai x 3 cap (thumbnail).
- `cmp_<loai>.png` — tung loai: nha phong 2x; quan 3 hang cap x 3 frame
  dai dien (idle / chay / hanh dong).
- File mau: `buildings/*_blue_lv{2,3}.png`, `units/blue/*_lv{2,3}.png`.

## Kiem ke: moi loai co bao nhieu THIET KE GOC khac nhau that?

| Loai | So thiet ke goc | Chi tiet |
| --- | --- | --- |
| Castle | **2** | Update 010 Castle (= cap 1 game) + Free Pack Castle. Monastery (192x320) sai canvas, chi dung lam nguon ghep chop. |
| Barracks | **2** | Free Pack Barracks (= cap 1) + Free Pack Archery. |
| Tower | **2** | Free Pack Tower (= cap 1) + Update 010 Tower. Wood_Tower Goblin la strip 4 frame 256x192 (ngang) — sai huong canvas 128x256, KHONG dung duoc. |
| House + Storehouse | **4** | Free Pack House1 (= nha dan cap 1), House2 (= kho cap 1), House3, Update 010 House (nha tranh). Goblin_House dung 128x192 nhung la nha Goblin (xuong, vai do) — KHONG dung cho phe Knight. |
| Pawn | **2 nhan vat** | Free Pack (mu trum nau, = cap 1) + Update 010 (toc vang xoa mat — nhan vat khac han; sheet 6 hang x 6 frame). |
| Warrior | **2 ban ve** | Free Pack (mu thep, = cap 1) + Update 010 (mu/kiem VANG). Free Pack con co 2 strip chua dung: Attack2, Guard. |
| Archer | **2 nhan vat** | Free Pack (mu thep, = cap 1) + Update 010 (mu rom rong vanh — nhan vat khac han; sheet day du 7 hang: idle/run/5 huong ban). Ban Archer+Bow (NoArms) la cung nhan vat mu rom tach lop. |
| Lancer | **1** | Chi Free Pack co Lancer, DUNG 1 thiet ke — nhung co 12 strip (Idle/Run, Attack + Defence theo 4 huong). |
| (Monk) | 1 | Nhan vat khac han (ao choang, chua co trong game) nhung chi co Idle 6f / Run 4f / Heal 11f — khong du bo strip cho bat ky quan nao cua game, KHONG dung vong nay. |

## Anh xa da dung cho mau blue

**Nha:**
- **Castle** lv2 = Free Pack Castle nguyen ban. lv3 = Free Pack Castle +
  chop thap Monastery moc phia sau giua + 2 dinh Tower Free Pack 2 ben
  sau → khoi phao dai co thap giu (ghep 3 cong trinh khac nhau).
- **Barracks** lv2 = Free Pack Archery nguyen ban. lv3 = Barracks + dinh
  Monastery (chop + mat dong ho + mai) moc phia sau.
- **Tower** lv2 = Update 010 Tower nguyen ban. lv3 = NOI NGANG y=150:
  nua tren Free Pack Tower (dinh + san + tuong tren) + nua duoi Update
  010 Tower (tuong duoi + chan go + cua).
- **House** lv2 = Free Pack House3 nguyen ban. lv3 = mai House3 (lay sau
  toi y=118, gom dai cua so gac) + than/cua vom House1. (Da thu 5 diem
  noi/phoi khac nhau — ban nay sach nhat.)
- **Storehouse** lv2 = Update 010 House (nha tranh) nguyen ban. lv3 = mai
  House3 + than House2, noi tai y=104 (khung go 2 sprite khop nhau).

**Quan:**
- **Pawn** lv2 = nhan vat Update 010 (toc vang): idle = hang 0 (6f, nhep
  ping-pong thanh 8f), run = hang 1, axe = hang 2, pick = hang 3,
  knife = 4 frame dau hang 2, run_wood = hang 4 (the bung do, tay giang
  cao), run_gold = hang 5, run_meat = hang 1. lv3 = ban lv2 phong 1.25x
  neo chan (ve lai ty le — xem diem yeu 3).
- **Warrior** lv2 = combo strip goc chua dung cua Free Pack: chay =
  **Guard** (khien giu truoc, the thu tien quan), danh = **Attack2**
  (chem nang, cung vet chem khac han Attack1); idle giu Free Pack.
  lv3 = Warrior Update 010 (mu vang, kiem vang, khien cheo) — idle hang
  0 ping-pong thanh 8f, run hang 1, attack = frame 0/3/4/5 hang 2.
- **Archer** lv2 = nhan vat Update 010 (mu rom): idle = hang 0 (6f),
  run = hang 1 (4f), shoot = hang 4 (8f). lv3 = ban lv2 phong 1.2x neo
  chan + shoot lay hang 3 (huong giuong cung khac). Mui ten = Arrow
  Update 010 (nua chua mui ten tron trong file 64x128).
- **Lancer** lv2 = attack doi sang **DownRight_Attack** (dam cheo xuong —
  strip goc khac), idle/run giu nguyen. lv3 = ca 3 strip doi the:
  idle = **Down_Defence** (the thu nhin thang, giao chong xuong —
  ping-pong 6→12f), run = **Right_Defence** (giao nam ngang, lao nhu
  ky binh), attack = **Down_Attack** (dam xuong).

## Diem chua khac han / chua uoc (noi thang)

1. **Lancer la o yeu nhat**: toan bo pack chi co DUNG 1 thiet ke lancer.
   lv2 chi khac strip tan cong; lv3 doi ca 3 the (thu/chay/dam) nhung
   van la CUNG 1 nhan vat — khong co cach nao khac bang do goc cua pack.
2. **Warrior lv2 idle giong het cap 1** (khac biet nam o strip chay
   Guard + danh Attack2 — phai xem cmp_warrior/co animation moi thay).
   Warrior lv3 (Update 010) cung PHOM DANG voi cap 1, khac ban ve/mau
   sac ban goc (mu vang kiem vang) — muc "khac" yeu hon pawn/archer.
3. **Pawn lv3 va Archer lv3 dung ve lai ty le** (phong 1.25x / 1.2x len
   ban lv2, neo chan day bbox): nhan vat to hon that nhung pixel cung
   "be" hon theo. Day la phuong an du phong brief cho phep khi het do
   ghep — ghi ro de user quyet.
4. **Pawn**: sheet Update 010 chi co 2 hang interact → strip knife phai
   dung chung frame voi axe (chi khac ngu canh game gan); run_meat
   khong thay vat bung (2 hang the bung 4/5 da gan cho go/vang).
   Idle 6 frame phai lap ping-pong thanh 8 — nhip anim hoi khac goc.
5. **Mai House3 bi tai dung 3 o**: nha dan lv2 (nguyen House3), nha dan
   lv3 (mai House3 + than House1), kho lv3 (mai House3 + than House2) —
   tong the 3 o khac nhau nhung mai nhin quen mat.
6. **Barracks lv2 (Archery)** doc nhu TRUONG BAN/xuong hon la doanh
   trai — khac han ve hinh khoi nhung lech ngu nghia cong trinh.
7. **Castle lv3**: 2 dinh thap 2 ben bi tuong sau cua Free Pack Castle
   che gan het, chi loi vong ren nho — thay doi khoi chinh doc duoc la
   chop thap giu Monastery o giua.

## Trang thai
MAU cho duyet — CHUA nhan rong 4 phe, chua dong vao bo file lv2/lv3
chinh thuc trong `assets/upgrades/` (bo chinh thuc van la vong 2).
Neu duoc duyet: chay GENERATOR_V4 cho 4 mau (moi nguon deu co du 4 mau
trong pack) ghi de bo chinh thuc + chay lai VERIFY.
