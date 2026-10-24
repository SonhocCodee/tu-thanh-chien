#!/usr/bin/env bash
# GOI CHU NHA — TU THANH CHIEN (choi qua mang LAN)
# Chay file nay: server game se mo o cong 8910 (WebSocket) + 8911 (web),
# in ra dia chi IP LAN de gui cho ban be.
cd "$(dirname "$0")"
echo "=================================================="
echo " TU THANH CHIEN — MAY CHU NHA DANG KHOI DONG"
echo "=================================================="
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo ""
echo " Gui cho ban be cung mang LAN duong dan nay:"
echo "        http://$IP:8911/?lan=1"
echo ""
echo " Ban (chu nha) muon choi cung thi mo trinh duyet tren"
echo " chinh may nay toi:  http://localhost:8911/?lan=1"
echo ""
echo " Lan chay dau, Windows/Linux co the hoi quyen tuong lua"
echo " -> bam Allow / Cho phep truy cap mang rieng (Private)."
echo " Dung tat cua so nay giua tran — tat la tran dung."
echo "=================================================="
./server/tu-thanh-chien.x86_64 --headless -- --netrole=server --webroot="$PWD/web"
