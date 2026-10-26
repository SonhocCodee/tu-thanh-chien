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
c_out = read("client_c_stdout.log")
c2_log = read("client_c2.log")
e_log = read("client_e.log")
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
slot_c = hello_slot("C")
check("hello_slots", slot_a >= 0 and slot_b >= 0 and slot_c >= 0
      and len({slot_a, slot_b, slot_c}) == 3,
      f"A=slot {slot_a}, B=slot {slot_b}, C=slot {slot_c} (3 người, 3 slot khác nhau)")
check("match_start", "MATCH_START" in srv, "trận bắt đầu (bot lấp slot trống)")

# --- Phòng chờ v3: tạo phòng / mã phòng / quyền chủ phòng / slot đóng ---
CODE_CHARS = set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
m_code = re.search(r"ROOM_CREATED code=([A-Z0-9]{6})\b", srv)
check("room_code_format", m_code is not None and set(m_code.group(1)) <= CODE_CHARS,
      f"mã phòng 6 ký tự, bỏ ký tự dễ nhầm 0/O/1/I: {m_code.group(1) if m_code else 'không thấy'}")
check("join_wrong_code", "JOIN_REJECT" in srv and "reason=WRONG_CODE" in srv
      and "AUTOTEST wrong_code_reject=1" in c_out,
      "C vào bằng MÃ SAI -> server từ chối WRONG_CODE, client nhận đúng hồi báo")
check("guest_start_reject", "START_REJECT reason=NOT_HOST" in srv
      and "AUTOTEST start_guest_reject=1" in c_out,
      "C (khách) thử bấm BẮT ĐẦU -> bị từ chối NOT_HOST")
m_closed = re.search(r"SET_SLOT slot=(\d+) mode=closed", srv)
closed_slot = int(m_closed.group(1)) if m_closed else -1
check("host_set_slot_closed", closed_slot >= 0 and closed_slot not in (slot_a, slot_b, slot_c),
      f"chủ phòng đóng slot trống {closed_slot} (không đụng slot người)")
check("a_slot_closed_ok", "FLAG slot_closed_ok true" in a_log,
      "A thấy lệnh đóng slot của mình có hiệu lực qua lobby_update")
m_bots = re.search(r"MATCH_START bots=\[([^\]]*)\]", srv)
bot_list = [int(x) for x in m_bots.group(1).split(",") if x.strip() != ""] if m_bots else []
check("closed_faction_out", f"SLOT_CLOSED_ELIMINATED slot={closed_slot}" in srv
      and closed_slot not in bot_list,
      f"slot đóng {closed_slot} bị loại khỏi trận, danh sách bot lấp: {bot_list}")
c2_reclaim_at = srv.find("HELLO_RECLAIM")
match_start_at = srv.find("MATCH_START")
check("lobby_reclaim", c2_reclaim_at >= 0 and match_start_at >= 0 and c2_reclaim_at < match_start_at
      and f"slot={slot_c} " in srv[c2_reclaim_at:c2_reclaim_at + 80]
      and "FLAG lobby_reclaim true" in c2_log and "FLAG slot_closed_seen true" in c2_log,
      f"C rớt mạng Ở LOBBY -> nối lại đúng slot {slot_c} trước khi trận bắt đầu, thấy slot đã đóng")
check("late_join_reject", "FLAG late_reject true" in e_log,
      "E nối vào GIỮA TRẬN (không token) -> bị từ chối IN_MATCH")

# --- Đường lệnh qua PlayerController (server log) ---
def cmd(op, slot, result, reason=""):
    pat = rf"CMD slot={slot} op={op} result={result}" + (rf" reason={reason}" if reason else "")
    return re.search(pat, srv) is not None


check("cmd_a_train", cmd("train", slot_a, "ACCEPT"), "A luyện kiếm sĩ được chấp nhận")
check("cmd_a_build", cmd("build", slot_a, "ACCEPT"), "A đặt Nhà dân được chấp nhận")
check("cmd_a_alloc", cmd("alloc", slot_a, "ACCEPT"), "A phân bổ nông dân được chấp nhận")
check("cmd_a_move", cmd("move", slot_a, "ACCEPT"), "A ra lệnh di chuyển được chấp nhận")

# --- Lệnh mới của plan Đế Chế hoá qua mạng (giao thức v2, log phía server) ---
def cmd_detail(op, slot, result, reason="", detail=""):
    pat = rf"CMD slot={slot} op={op} result={result}" + (rf" reason={reason}" if reason else "") + (rf" .* {detail}" if detail else "")
    return re.search(pat, srv) is not None


check("cmd_a_market_sell", cmd("market_sell", slot_a, "ACCEPT"), "A bán 1 gói gỗ ở chợ qua mạng được chấp nhận")
check("cmd_a_market_buy", cmd("market_buy", slot_a, "ACCEPT"), "A mua 1 gói đá ở chợ qua mạng được chấp nhận")
check("cmd_a_train_monk", cmd_detail("train", slot_a, "ACCEPT", detail="unit=monk"),
      "A luyện TU SĨ tại Thành qua mạng được chấp nhận")
check("cmd_a_build_barracks", cmd_detail("build", slot_a, "ACCEPT", detail="type=barracks"),
      "A đặt Doanh trại qua mạng được chấp nhận")
check("cmd_a_build_farm", cmd_detail("build", slot_a, "ACCEPT", detail="type=farm"),
      "A đặt RUỘNG qua mạng được chấp nhận")
check("cmd_a_age_up", cmd("age_up", slot_a, "ACCEPT"), "A lên Đời 2 qua mạng được chấp nhận")
check("cmd_a_age_up_busy", cmd("age_up", slot_a, "REJECT", "BUSY"),
      "A lên Đời lần 2 khi Thành đang nghiên cứu -> BUSY")
check("cmd_a_upgrade_farm_reject", cmd("building_upgrade", slot_a, "REJECT", "NOT_UPGRADEABLE"),
      "A nâng cấp RUỘNG -> bị chặn NOT_UPGRADEABLE ở server")
check("cmd_a_research_gate", cmd("unit_research", slot_a, "REJECT", "AGE_GATE"),
      "A nghiên cứu quân cấp 2 khi còn Đời 1 -> AGE_GATE")
check("cmd_a_research", cmd("unit_research", slot_a, "ACCEPT"),
      "A nghiên cứu nông dân cấp 2 sau khi lên Đời 2 -> được chấp nhận")
check("cmd_a_upgrade", cmd("building_upgrade", slot_a, "ACCEPT"),
      "A nâng cấp Nhà dân lên cấp 2 qua mạng được chấp nhận")
check("cmd_a_attack_move", cmd("attack_move", slot_a, "ACCEPT"), "A attack-move qua mạng được chấp nhận")
check("cmd_a_patrol", cmd("patrol", slot_a, "ACCEPT"), "A tuần tra qua mạng được chấp nhận")
check("cmd_a_guard", cmd("guard", slot_a, "ACCEPT"), "A hộ vệ thành qua mạng được chấp nhận")
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
check("a_flags_v2", all(f"FLAG {k} true" in a_log for k in
                        ("market_sell_ok", "market_buy_ok", "train_monk_ok",
                         "build_barracks_ok", "build_farm_ok", "age_up_ok", "age_up_busy",
                         "upgrade_farm_reject", "research_gate", "research_ok", "upgrade_ok",
                         "attack_move_ok", "patrol_ok", "guard_ok")),
      "A: toàn bộ chuỗi lệnh v2 (chợ/tu sĩ/ruộng/lên đời/nghiên cứu/nâng cấp/RTS) đúng kỳ vọng")
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
