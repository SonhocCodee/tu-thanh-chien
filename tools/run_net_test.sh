#!/usr/bin/env bash
# Vòng kiểm chứng LAN M3 — chạy 1 phiên THẬT trên máy này:
#   server headless (game thật) + client A (xvfb, chụp ảnh) + client B
#   (headless) qua địa chỉ loopback; B bị GIẾT giữa trận rồi chạy lại
#   bằng token để kiểm chứng nối lại trong grace 60s.
# Giao thức v3 (phòng chờ đầy đủ) thêm các ca:
#   - A TẠO PHÒNG: server sinh MÃ PHÒNG 6 ký tự (script trích mã từ
#     server log rồi mới phát cho B/C — đúng như bạn bè nhận mã từ chủ).
#   - C vào bằng MÃ SAI trước (phải bị WRONG_CODE), rồi mã đúng; C thử
#     bấm BẮT ĐẦU (phải bị NOT_HOST); C bị giết NGAY Ở LOBBY rồi chạy
#     lại bằng token (nối lại đúng slot khi trận chưa bắt đầu).
#   - A (chủ phòng) ĐÓNG slot trống còn lại -> phe đó bị loại khỏi trận.
#   - E nối vào GIỮA TRẬN không token -> bị từ chối IN_MATCH.
# Đối chiếu bằng tools/check_net_reports.py. Dùng: ./tools/run_net_test.sh
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/workspace/thu-thanh-4v4/tools_bin/Godot_v4.3-stable_linux.x86_64}"
PORT="${PORT:-8917}"
HTTPPORT="${HTTPPORT:-8918}"
# ĐỊA CHỈ NỐI: mac dinh 127.0.0.1. Ly do (da do that 2026-10-24): sandbox
# cua may ao nay chan connect() toi MOI dia chi khong phai loopback
# ("Operation not permitted" o muc syscall — ca IP host0 198.19.0.2 lan
# alias tu gan tren lo deu bi chan, du iptables rong va route local co san).
# Server van nghe "*" tren moi giao dien (kiem chung bang dong SERVER_BIND
# o duoi); tren LAN that o nha, ban be noi toi IP LAN cua chu nha bang dung
# cac duong code nay. Dat HOST_ADDR=<IP> de chay lai o moi truong khong chan.
HOST_ADDR="${HOST_ADDR:-127.0.0.1}"
LAN_IP="$HOST_ADDR"
RPT="$PWD/reports/net"
mkdir -p "$RPT/web" "$RPT/shots"
rm -f "$RPT"/*.log "$RPT"/*.txt "$RPT/shots"/*.png
echo '<!doctype html><title>dummy</title>goi chu nha' > "$RPT/web/index.html"
echo 'console.log("dummy")' > "$RPT/web/app.js"

if [ ! -f .godot/global_script_class_cache.cfg ]; then
  echo "== import lan dau =="
  timeout 180 "$GODOT" --headless --import --path . > /dev/null 2>&1 || true
fi

echo "== server (ws $PORT, http $HTTPPORT, webroot dummy) =="
# --duration=170: phiên đủ dài cho chuỗi kiểm chứng lệnh đắt của A (lên
# Đời 2 mất 60s nghiên cứu -> nghiên cứu/nâng cấp ACCEPT ở ~t=78-84).
# --testgrant: cấp vốn cho slot người để các lệnh đó đi hết được trong
# phiên (chỉ harness dùng; gói chủ nhà không truyền 2 tham số này).
timeout 700 "$GODOT" --headless --path . -- --netrole=server --port="$PORT" \
  --httpport="$HTTPPORT" --webroot="$RPT/web" --duration=170 --testgrant \
  --netlog="$RPT/server.log" > "$RPT/server_stdout.log" 2>&1 &
SRV=$!
for i in $(seq 1 40); do
  grep -q "NET_SERVER_UP" "$RPT/server_stdout.log" 2>/dev/null && break
  sleep 1
done
grep -q "NET_SERVER_UP" "$RPT/server_stdout.log" || { echo "SERVER KHONG LEN"; tail -20 "$RPT/server_stdout.log"; exit 1; }

echo "== kiem tra HTTP tinh + bind cua server =="
{
  code1=$(curl -s --noproxy '*' -o /dev/null -w "%{http_code}" "http://$HOST_ADDR:$HTTPPORT/index.html")
  mime=$(curl -s --noproxy '*' -o /dev/null -w "%{content_type}" "http://$HOST_ADDR:$HTTPPORT/app.js")
  cache=$(curl -sI --noproxy '*' "http://$HOST_ADDR:$HTTPPORT/index.html" | grep -i "cache-control" | tr -d '\r')
  bind=$(ss -ltn | grep -E ":($PORT|$HTTPPORT)[[:space:]]" | grep -c '\*')
  echo "HTTP_INDEX_LOCAL $code1"
  echo "HTTP_MIME_JS $mime"
  echo "HTTP_CACHE $cache"
  echo "SERVER_BIND_ALL $bind"
} > "$RPT/http_check.txt"
cat "$RPT/http_check.txt"

echo "== client A (xvfb, autotest A — chu phong, TAO PHONG) =="
timeout 620 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --resolution 1280x720 -- \
  --netrole=client --url="ws://$LAN_IP:$PORT" --name=A --autotest=A \
  --netlog="$RPT/client_a.log" --shotdir="$RPT/shots" > "$RPT/client_a_stdout.log" 2>&1 &
CA=$!

echo "== cho A tao phong, trich MA PHONG tu server log =="
CODE=""
for i in $(seq 1 40); do
  CODE=$(grep -o "ROOM_CREATED code=[A-Z0-9]*" "$RPT/server.log" 2>/dev/null | head -1 | cut -d= -f2)
  [ -n "$CODE" ] && break
  sleep 1
done
[ -n "$CODE" ] || { echo "A CHUA TAO DUOC PHONG"; tail -20 "$RPT/server_stdout.log"; exit 1; }
echo "MA PHONG: $CODE"

echo "== client B (headless, autotest B — vao phong bang ma) =="
timeout 480 "$GODOT" --headless --path . -- --netrole=client --url="ws://$LAN_IP:$PORT" \
  --name=B --autotest=B --roomcode="$CODE" --reportdir="$RPT" --tokenfile="$RPT/token_b.txt" \
  --netlog="$RPT/client_b1.log" > "$RPT/client_b_stdout.log" 2>&1 &
CB=$!

echo "== client C (headless, autotest C — ma sai truoc, thu bat dau, bi giet o lobby) =="
timeout 480 "$GODOT" --headless --path . -- --netrole=client --url="ws://$LAN_IP:$PORT" \
  --name=C --autotest=C --roomcode="$CODE" --wrongcode=000000 --tokenfile="$RPT/token_c.txt" \
  --netlog="$RPT/client_c1.log" > "$RPT/client_c_stdout.log" 2>&1 &
CC=$!

echo "== cho C vao dung slot + thu bat dau bi tu choi (toi da 60s) =="
for i in $(seq 1 60); do
  grep -q "START_REJECT reason=NOT_HOST" "$RPT/server.log" 2>/dev/null && break
  sleep 1
done
grep -q "START_REJECT reason=NOT_HOST" "$RPT/server.log" \
  && echo "C da vao phong + bi tu choi bat dau" || echo "CANH BAO: chua thay C bi tu choi bat dau"

echo "== GIET C ngay o lobby, chay lai C2 bang token (grace 60s) =="
sleep 3
pkill -f "token_c.txt" 2>/dev/null
sleep 3
timeout 480 "$GODOT" --headless --path . -- --netrole=client --url="ws://$LAN_IP:$PORT" \
  --name=C --autotest=C2 --expect_reclaim=true --tokenfile="$RPT/token_c.txt" \
  --netlog="$RPT/client_c2.log" > "$RPT/client_c2_stdout.log" 2>&1 &
CC2=$!

echo "== cho B danh thanh da lo dien duoc chap nhan (toi da 150s) =="
for i in $(seq 1 150); do
  grep -q "AUTOTEST castle_attack_ok=1" "$RPT/client_b_stdout.log" 2>/dev/null && break
  sleep 1
done
grep -q "AUTOTEST castle_attack_ok=1" "$RPT/client_b_stdout.log" \
  && echo "B dat moc tan cong thanh" || echo "CANH BAO: B chua dat moc tan cong thanh"

echo "== client E noi vao GIUA TRAN (khong token) — phai bi tu choi IN_MATCH =="
timeout 90 "$GODOT" --headless --path . -- --netrole=client --url="ws://$LAN_IP:$PORT" \
  --name=E --autotest=E --netlog="$RPT/client_e.log" > "$RPT/client_e_stdout.log" 2>&1 &
CE=$!
wait $CE 2>/dev/null; echo "client E exit=$?"

echo "== GIET B giua tran, chay lai bang token (grace 60s) =="
sleep 2
pkill -f "token_b.txt" 2>/dev/null
sleep 3
timeout 240 "$GODOT" --headless --path . -- --netrole=client --url="ws://$LAN_IP:$PORT" \
  --name=B --autotest=B2 --reportdir="$RPT" --tokenfile="$RPT/token_b.txt" --expect_reclaim=true \
  --netlog="$RPT/client_b2.log" > "$RPT/client_b2_stdout.log" 2>&1 &
CB2=$!

wait $CB2 2>/dev/null; echo "client B2 exit=$?"
wait $CC2 2>/dev/null; echo "client C2 exit=$?"
wait $CA 2>/dev/null; echo "client A exit=$?"
wait $SRV 2>/dev/null; echo "server exit=$?"

echo "== doi chieu bao cao =="
python3 tools/check_net_reports.py "$RPT"
