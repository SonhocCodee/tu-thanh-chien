#!/usr/bin/env bash
# Đóng gói CHỦ NHÀ (M3): xuất bản Linux (server) + bản Web (client) từ chính
# cây mã này, lắp thành thư mục goi-chu-nha/ sẵn gửi cho chủ nhà.
#   goi-chu-nha/
#     server/  tu-thanh-chien.x86_64 + .pck   (tiến trình chủ nhà)
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

echo "== xuat ban Web (client cho ban be) =="
"$GODOT" --headless --export-release "Web" "$OUT/web/index.html"

echo "== va ban web cho buoi choi LAN (Secure Context) =="
python3 host/patch_web.py "$OUT/web"

cp host/start_host.sh host/start_host.bat host/HUONG_DAN_CHU_NHA.txt "$OUT/"
chmod +x "$OUT/start_host.sh"
echo ""
echo "XONG. Goi chu nha o: $OUT"
echo "Chu nha chay start_host.sh / start_host.bat la mo phong."
