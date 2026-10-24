#!/usr/bin/env bash
# Đóng gói CHỦ NHÀ (M3): xuất bản server (Linux + Windows) + bản Web (client)
# từ chính cây mã này, lắp thành thư mục goi-chu-nha/ sẵn gửi cho chủ nhà.
#   goi-chu-nha/
#     server/  tu-thanh-chien.x86_64 + .pck          (server cho máy Linux)
#              tu-thanh-chien-win.exe + .console.exe (server cho máy Windows)
#              + tu-thanh-chien-win.pck
#              (exe Windows đặt tên -win để .pck không đè .pck của Linux)
#     web/     bản web client (server tự phục vụ ở cổng 8911)
#     start_host.sh / start_host.bat / HUONG_DAN_CHU_NHA.txt
# Chạy: ./host/build_package.sh   (từ thư mục gốc của project)
set -eu
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/workspace/thu-thanh-4v4/tools_bin/Godot_v4.3-stable_linux.x86_64}"
OUT="host/goi-chu-nha"
rm -rf "$OUT"
mkdir -p "$OUT/server" "$OUT/web"

if [ ! -f .godot/global_script_class_cache.cfg ]; then
  echo "== import lan dau =="
  "$GODOT" --headless --import --path . > /dev/null 2>&1 || true
fi

echo "== xuat ban Linux (server chu nha) =="
"$GODOT" --headless --export-release "Linux" "$OUT/server/tu-thanh-chien.x86_64"
chmod +x "$OUT/server/tu-thanh-chien.x86_64"

echo "== xuat ban Windows (server chu nha tren may Windows) =="
"$GODOT" --headless --export-release "Windows Desktop" "$OUT/server/tu-thanh-chien-win.exe"
# Godot 4.3 chi xuat kem console wrapper o ban DEBUG (ban release khong co),
# ma may chu can wrapper de log hien trong cua so .bat. Wrapper la launcher
# dung chung (tu tim file .exe cung ten bo hau to .console), Godot xuat ra
# bang cach copy nguyen template — nen o day copy template release cho khop.
TPL_DIR="${TPL_DIR:-$HOME/.local/share/godot/export_templates/4.3.stable}"
if [ -f "$TPL_DIR/windows_release_x86_64_console.exe" ]; then
  cp "$TPL_DIR/windows_release_x86_64_console.exe" "$OUT/server/tu-thanh-chien-win.console.exe"
  echo "Da kem console wrapper cho ban Windows."
else
  echo "CANH BAO: khong thay template console wrapper o $TPL_DIR — goi thieu file .console.exe (start_host.bat se chay thang .exe, mat log trong cua so)."
fi
ls -la "$OUT/server/"

echo "== xuat ban Web (client cho ban be) =="
"$GODOT" --headless --export-release "Web" "$OUT/web/index.html"

echo "== va ban web cho buoi choi LAN (Secure Context) =="
python3 host/patch_web.py "$OUT/web"

cp host/start_host.sh host/start_host.bat host/HUONG_DAN_CHU_NHA.txt "$OUT/"
chmod +x "$OUT/start_host.sh"
echo ""
echo "XONG. Goi chu nha o: $OUT"
echo "Chu nha Windows chay start_host.bat, Linux chay start_host.sh la mo phong."
