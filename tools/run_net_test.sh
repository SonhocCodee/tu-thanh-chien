#!/usr/bin/env bash
# Vòng kiểm chứng LAN M3 — chạy 1 phiên THẬT trên máy này:
#   server headless (game thật) + client A (xvfb, chụp ảnh) + client B
#   (headless) qua địa chỉ IP LAN của máy; B bị GIẾT giữa trận rồi chạy lại
#   bằng token để kiểm chứng nối lại trong grace 60s.
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
timeout 280 "$GODOT" --headless --path . -- --netrole=server --port="$PORT" \
  --httpport="$HTTPPORT" --webroot="$RPT/web" --duration=80 \
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

echo "== client A (xvfb, autotest A) =="
timeout 200 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --resolution 1280x720 -- \
  --netrole=client --url="ws://$LAN_IP:$PORT" --name=A --autotest=A \
  --netlog="$RPT/client_a.log" --shotdir="$RPT/shots" > "$RPT/client_a_stdout.log" 2>&1 &
CA=$!

echo "== client B (headless, autotest B) =="
timeout 240 "$GODOT" --headless --path . -- --netrole=client --url="ws://$LAN_IP:$PORT" \
  --name=B --autotest=B --reportdir="$RPT" --tokenfile="$RPT/token_b.txt" \
  --netlog="$RPT/client_b1.log" > "$RPT/client_b_stdout.log" 2>&1 &
CB=$!

echo "== cho B danh thanh da lo dien duoc chap nhan (toi da 100s) =="
for i in $(seq 1 100); do
  grep -q "AUTOTEST castle_attack_ok=1" "$RPT/client_b_stdout.log" 2>/dev/null && break
  sleep 1
done
grep -q "AUTOTEST castle_attack_ok=1" "$RPT/client_b_stdout.log" \
  && echo "B dat moc tan cong thanh" || echo "CANH BAO: B chua dat moc tan cong thanh"

echo "== GIEU B giua tran, chay lai bang token (grace 60s) =="
sleep 2
pkill -f "token_b.txt" 2>/dev/null
sleep 3
timeout 120 "$GODOT" --headless --path . -- --netrole=client --url="ws://$LAN_IP:$PORT" \
  --name=B --autotest=B2 --reportdir="$RPT" --tokenfile="$RPT/token_b.txt" --expect_reclaim=true \
  --netlog="$RPT/client_b2.log" > "$RPT/client_b2_stdout.log" 2>&1 &
CB2=$!

wait $CB2 2>/dev/null; echo "client B2 exit=$?"
wait $CA 2>/dev/null; echo "client A exit=$?"
wait $SRV 2>/dev/null; echo "server exit=$?"

echo "== doi chieu bao cao =="
python3 tools/check_net_reports.py "$RPT"
