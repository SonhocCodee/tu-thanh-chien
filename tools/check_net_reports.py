#!/usr/bin/env python3
"""Đối chiếu báo cáo của vòng kiểm chứng LAN (tools/run_net_test.sh).

Đọc: server.log (netlog của NetServer — gồm cả kiểm toán sương mù tại
nguồn trên payload snapshot), client_a.log (báo cáo autotest A),
client_b_stdout.log (B vòng 1 — bị giết giữa trận nên không có báo cáo
cuối, đọc cờ in ra stdout), client_b2.log (B vòng nối lại), http_check.txt.

Mọi khẳng định đều từ log thật của phiên chạy. Thoát 0 = đạt hết.
"""
import re
import sys
from pathlib import Path

RPT = Path(sys.argv[1] if len(sys.argv) > 1 else "reports/net")
failures = []


def check(name, ok, detail=""):
    print(f"NETTEST {name}: {'PASS' if ok else 'FAIL'} — {detail}")
    if not ok:
        failures.append(name)


def read(name):
    p = RPT / name
    return p.read_text(errors="replace") if p.exists() else ""


srv = read("server.log")
a_log = read("client_a.log")
a_out = read("client_a_stdout.log")
b_out = read("client_b_stdout.log")
b2_log = read("client_b2.log")
b2_out = read("client_b2_stdout.log")
http = read("http_check.txt")

# --- Hạ tầng ---
check("http_index_local", "HTTP_INDEX_LOCAL 200" in http, "server tĩnh trả index.html")
check("server_bind_all", "SERVER_BIND_ALL 2" in http,
      "server nghe '*' cả 2 cổng (WS + HTTP) — sẵn sàng nhận nối từ IP LAN thật")
check("http_mime_js", "javascript" in http, "MIME .js đúng")
check("http_nostore", "no-store" in http, "Cache-Control: no-store (chống client cũ lệch phiên bản)")
check("server_up", "SERVER_UP" in srv and "HTTP_UP" in srv, "server WS + HTTP cùng lên")

# --- Phòng chờ / bắt đầu trận ---
# Slot do THỨ TỰ KẾT NỐI quyết định (ai nối trước lấy slot thấp + làm chủ
# phòng) nên phải đọc slot thật của từng client từ log, không giả định.
def hello_slot(name):
    m = re.search(rf"^HELLO peer=\d+ slot=(\d+) name={name} ", srv, re.M)
    return int(m.group(1)) if m else -1


slot_a, slot_b = hello_slot("A"), hello_slot("B")
check("hello_slots", slot_a >= 0 and slot_b >= 0 and slot_a != slot_b,
      f"A=slot {slot_a}, B=slot {slot_b} (theo thứ tự kết nối)")
check("match_start", "MATCH_START" in srv, "trận bắt đầu (bot lấp slot trống)")

# --- Đường lệnh qua PlayerController (server log) ---
def cmd(op, slot, result, reason=""):
    pat = rf"CMD slot={slot} op={op} result={result}" + (rf" reason={reason}" if reason else "")
    return re.search(pat, srv) is not None


check("cmd_a_train", cmd("train", slot_a, "ACCEPT"), "A luyện kiếm sĩ được chấp nhận")
check("cmd_a_build", cmd("build", slot_a, "ACCEPT"), "A đặt Nhà dân được chấp nhận")
check("cmd_a_alloc", cmd("alloc", slot_a, "ACCEPT"), "A phân bổ nông dân được chấp nhận")
check("cmd_a_move", cmd("move", slot_a, "ACCEPT"), "A ra lệnh di chuyển được chấp nhận")
check("cmd_b_train", cmd("train", slot_b, "ACCEPT"), "B luyện kiếm sĩ được chấp nhận")
check("cmd_b_fog_reject", cmd("stance", slot_b, "REJECT", "FOG"),
      "B tấn công thành CHƯA lộ diện -> bị FOG từ chối ở server")
check("cmd_b_attack_accept", cmd("stance", slot_b, "ACCEPT"),
      "B tấn công thành ĐÃ lộ diện (sau trinh sát) -> được chấp nhận")

# --- Snapshot + kiểm toán sương mù tại nguồn (trên payload thật) ---
snap_slots = set(re.findall(r"SNAP slot=(\d+)", srv))
check("snapshots_both", {str(slot_a), str(slot_b)} <= snap_slots,
      f"snapshot đã gửi cho các slot: {sorted(snap_slots)}")
m = re.search(r"MATCH_END .*audit_checked=(\d+) audit_violations=(\d+)", srv)
if m:
    checked_n, viol_n = int(m.group(1)), int(m.group(2))
    check("fog_audit_source", viol_n == 0 and checked_n > 500,
          f"đối chiếu payload vs lưới sương mù người nhận: {checked_n} lượt, {viol_n} vi phạm")
else:
    check("fog_audit_source", False, "không thấy dòng MATCH_END kèm số liệu kiểm toán")

# --- Client A: lệnh có hiệu lực thật + gương sạch ---
check("a_flags", all(f"FLAG {k} true" in a_log for k in
                     ("train_ok", "build_ok", "alloc_ok", "warrior_seen")),
      "A: train/build/alloc đều ok, thấy quân mình xuất hiện trong gương")
check("a_fog_clean", "FOG_VIOLATIONS 0" in a_log, "gương của A: 0 vi phạm sương mù")

# --- Client B vòng 1: kịch bản sương mù chạy tới nơi ---
check("b_fog_reject_flag", "AUTOTEST fog_reject=1" in b_out, "B nhận đúng hồi báo FOG từ server")
check("b_castle_attack_flag", "AUTOTEST castle_attack_ok=1" in b_out,
      "B trinh sát tới nơi -> lệnh tấn công thành được chấp nhận")

# --- Nối lại bằng token trong grace ---
check("reclaim_server", re.search(rf"HELLO_RECLAIM .* slot={slot_b} ", srv) is not None,
      f"server nhận diện token, trả B đúng slot {slot_b} của mình")
check("b2_flags", all(f"FLAG {k} true" in b2_log for k in
                      ("reclaim", "resync", "post_reconnect_cmd")),
      "B2: reclaim + đồng bộ lại + ra lệnh mới được chấp nhận")
check("b2_fog_clean", "FOG_VIOLATIONS 0" in b2_log, "gương của B sau nối lại: 0 vi phạm sương mù")

# --- Ảnh kiểm chứng của client A ---
shots = RPT / "shots"
for name in ("net_lobby_A.png", "net_match_A.png"):
    p = shots / name
    check(f"shot_{name}", p.exists() and p.stat().st_size > 15000,
          f"{name}: {'có, %d byte' % p.stat().st_size if p.exists() else 'thiếu'}")

check("match_end", "MATCH_END reason=duration" in srv, "server kết thúc phiên test đúng hạn")

print(f"\nTONG KET: {'PASS TOAN BO' if not failures else 'FAIL: ' + ', '.join(failures)}")
sys.exit(1 if failures else 0)
