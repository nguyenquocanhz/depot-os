#!/usr/bin/env python3
# Depot OS — sinh theme khung cửa sổ "Depot-Win11" cho xfwm4: thanh tiêu đề phẳng, nút — ☐ ✕ kiểu Windows 11 ở bên phải
# (rê chuột lên nút đóng thì đỏ), viền 1 điểm ảnh. Dùng cho hai bố cục Windows của depot-layout; bố cục macOS vẫn dùng
# khung WhiteSur (nút tròn bên trái).
#   python3 scripts/gen-win-xfwm.py      (chạy trong WSL; cần rsvg-convert — gói librsvg2-bin)
# Ghi vào build/live-build/config/includes.chroot/usr/share/themes/Depot-Win11/xfwm4/ (PNG + themerc).
# Góc vuông có chủ ý: nút đóng nằm sát mép phải, rê chuột là đỏ kín tới viền. Bo góc trên thì phải thêm một miếng góc
# bên phải nút đóng, miếng đó không đổi màu theo nút — lộ một dải không đỏ.
# By WrenEvil.tech & nguyenquocanhz (nqatech)
import os, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "live-build", "config", "includes.chroot", "usr", "share", "themes", "Depot-Win11", "xfwm4")

TITLE_H = 32          # cao thanh tiêu đề
BTN_W = 46            # rộng mỗi nút (Windows 11: 46 x 32)
BG = "#202020"        # nền thanh tiêu đề — cùng màu taskbar của bố cục Windows
BORDER = {"active": "#4a4a4a", "inactive": "#333333"}
GLYPH = {"active": "#ffffff", "inactive": "#8a8a8a", "prelight": "#ffffff", "pressed": "#ffffff"}
HOVER = {"prelight": "#353535", "pressed": "#2b2b2b"}           # nền nút thu nhỏ / phóng to khi rê, khi nhấn
CLOSE = {"prelight": "#c42b1c", "pressed": "#b3271a"}           # nền nút đóng khi rê, khi nhấn (đỏ Windows)
STATES = ("active", "inactive", "prelight", "pressed")


def svg(w, h, body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" '
            'shape-rendering="geometricPrecision">%s</svg>' % (w, h, w, h, body))


def rect(x, y, w, h, fill):
    return '<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>' % (x, y, w, h, fill)


def glyph(kind, color):
    """Hình trong ô 10x10 đặt giữa nút 46x32: tâm (23, 16)."""
    s = 'stroke="%s" stroke-width="1" fill="none" stroke-linecap="square"' % color
    if kind == "hide":
        return '<path d="M18 16.5 H28" %s/>' % s
    if kind == "maximize":
        return '<rect x="18.5" y="11.5" width="9" height="9" rx="1.2" %s/>' % s
    if kind == "maximize-toggled":      # hai ô chồng: khôi phục kích thước
        return ('<path d="M20.5 13.5 V12.5 a1 1 0 0 1 1 -1 H26.5 a1 1 0 0 1 1 1 V18.5 a1 1 0 0 1 -1 1 H25.5" %s/>'
                '<rect x="18.5" y="13.5" width="7" height="7" rx="1.2" %s/>' % (s, s))
    if kind == "close":
        return ('<path d="M18.4 11.4 L27.6 20.6 M27.6 11.4 L18.4 20.6" stroke="%s" stroke-width="1.1" fill="none" '
                'stroke-linecap="round"/>' % color)
    if kind == "shade":                 # mũi tên lên: cuộn cửa sổ
        return '<path d="M18.5 18.5 L23 13.5 L27.5 18.5" %s/>' % s
    if kind == "shade-toggled":
        return '<path d="M18.5 13.5 L23 18.5 L27.5 13.5" %s/>' % s
    if kind == "stick":                 # ghim trên mọi desktop
        return '<circle cx="23" cy="16" r="3.5" %s/>' % s
    if kind == "stick-toggled":
        return '<circle cx="23" cy="16" r="3.5" stroke="%s" stroke-width="1" fill="%s"/>' % (color, color)
    if kind == "menu":                  # ba gạch
        return '<path d="M18 12.5 H28 M18 16.5 H28 M18 20.5 H28" %s/>' % s
    raise ValueError(kind)


def button(kind, state):
    base = "close" if kind == "close" else "other"
    bg = BG
    if state in ("prelight", "pressed"):
        bg = CLOSE[state] if base == "close" else HOVER[state]
    # viền trên 1 điểm ảnh chạy liền qua mọi nút; nút đang rê / nhấn thuộc cửa sổ đang chọn
    line = BORDER["inactive" if state == "inactive" else "active"]
    return svg(BTN_W, TITLE_H, rect(0, 0, BTN_W, TITLE_H, bg) + rect(0, 0, BTN_W, 1, line) + glyph(kind, GLYPH[state]))


def pieces():
    out = {}
    for st in ("active", "inactive"):
        b = BORDER[st]
        # thanh tiêu đề: 5 mảnh, mảnh 3 lát dưới chữ; tất cả cùng một nền + viền trên
        for n in range(1, 6):
            out["title-%d-%s" % (n, st)] = svg(2, TITLE_H, rect(0, 0, 2, TITLE_H, BG) + rect(0, 0, 2, 1, b))
        # góc trên = một cột viền; cạnh trái / phải / dưới = viền 1 điểm ảnh
        out["top-left-" + st] = svg(1, TITLE_H, rect(0, 0, 1, TITLE_H, b))
        out["top-right-" + st] = svg(1, TITLE_H, rect(0, 0, 1, TITLE_H, b))
        out["left-" + st] = svg(1, 16, rect(0, 0, 1, 16, b))
        out["right-" + st] = svg(1, 16, rect(0, 0, 1, 16, b))
        out["bottom-" + st] = svg(16, 1, rect(0, 0, 16, 1, b))
        out["bottom-left-" + st] = svg(1, 1, rect(0, 0, 1, 1, b))
        out["bottom-right-" + st] = svg(1, 1, rect(0, 0, 1, 1, b))
    for kind in ("close", "hide", "maximize", "maximize-toggled", "menu", "shade", "shade-toggled", "stick", "stick-toggled"):
        for st in STATES:
            out["%s-%s" % (kind, st)] = button(kind, st)
    return out


THEMERC = """# Depot OS — khung cửa sổ kiểu Windows 11 (FILE SINH RA bởi scripts/gen-win-xfwm.py — sửa script, đừng sửa file này)
active_text_color=#ffffff
inactive_text_color=#8a8a8a
active_text_shadow_color=#202020
inactive_text_shadow_color=#202020
title_shadow_active=false
title_shadow_inactive=false
full_width_title=true
title_horizontal_offset=10
title_vertical_offset_active=0
title_vertical_offset_inactive=0
button_offset=0
button_spacing=0
maximized_offset=0
show_app_icon=false
shadow_delta_height=2
shadow_delta_width=0
shadow_delta_x=0
shadow_delta_y=-5
shadow_opacity=40
"""


def main():
    if not shutil.which("rsvg-convert"):
        sys.exit("thiếu rsvg-convert (apt-get install librsvg2-bin)")
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        if old.endswith(".png"):
            os.remove(os.path.join(OUT, old))
    tmp = tempfile.mkdtemp(prefix="depot-win-xfwm-")
    try:
        items = pieces()
        for name, s in sorted(items.items()):
            src = os.path.join(tmp, name + ".svg")
            with open(src, "w") as f:
                f.write(s)
            subprocess.run(["rsvg-convert", "-o", os.path.join(OUT, name + ".png"), src], check=True)
    finally:
        shutil.rmtree(tmp)
    with open(os.path.join(OUT, "themerc"), "w", encoding="utf-8", newline="\n") as f:
        f.write(THEMERC)
    print("Đã ghi %d ảnh + themerc vào %s" % (len(items), os.path.relpath(OUT, ROOT)))


if __name__ == "__main__":
    main()
