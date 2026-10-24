#!/usr/bin/env python3
"""Vá bản web trong GÓI CHỦ NHÀ để chơi được qua HTTP trên IP LAN.

Vấn đề: Godot 4.3 từ chối khởi động khi `window.isSecureContext == false`
(mục kiểm tra "Secure Context" trong Engine.getMissingFeatures của index.js).
Trang phục vụ từ http://<IP-LAN>:8911 không phải HTTPS và không phải
localhost nên bị chặn oan — game không hề dùng tính năng nào cần secure
context cho phần chơi LAN (WebSocket ws:// tới cùng máy chủ nhà vẫn chạy).

Cách vá (tối thiểu, đúng 1 điểm): trong index.js của BẢN SAO trong gói chủ
nhà, hàm `Features.isSecureContext` trả về true. Các kiểm tra khác
(WebGL2, Fetch) GIỮ NGUYÊN. TUYỆT ĐỐI không đụng cơ chế eval —
`JavaScriptBridge` phải sống thật vì client LAN dùng nó đọc hostname
để tự suy ra địa chỉ ws:// của chủ nhà.

Chỉ áp lên thư mục web của gói chủ nhà. Bản GitHub Pages (HTTPS) không cần
và không dùng bản vá này.

Cách dùng: python3 host/patch_web.py <thư mục web chứa index.js>
Thoát lỗi (exit 1) nếu không tìm thấy đúng mẫu — khi đó đừng đoán, kiểm tra
lại glue của bản xuất.
"""
import re
import sys
from pathlib import Path

PATTERN = re.compile(
    r"(isSecureContext:\s*function\s*\(\)\s*\{\s*return\s+)window\['isSecureContext'\]\s*===\s*true;"
)


def main() -> int:
    web_dir = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    js_path = web_dir / "index.js"
    src = js_path.read_text(encoding="utf-8")
    if "_godot_js_eval" in src and "LAN-PATCH" in src:
        print("Đã vá từ trước — bỏ qua.")
        return 0
    new_src, n = PATTERN.subn(r"\g<1>true; /* LAN-PATCH: bo qua kiem tra Secure Context cho buoi choi LAN qua HTTP */", src)
    if n != 1:
        print(f"LỖI: tìm thấy {n} mẫu isSecureContext (cần đúng 1). KHÔNG vá — kiểm tra lại bản xuất.")
        return 1
    if "_godot_js_eval" in new_src and "return true" not in new_src:
        print("LỖI: bất thường sau vá.")
        return 1
    js_path.write_text(new_src, encoding="utf-8")
    print(f"Đã vá {js_path}: isSecureContext -> true (giữ nguyên WebGL2/Fetch, giữ nguyên JavaScriptBridge).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
