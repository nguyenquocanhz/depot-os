#!/usr/bin/env python3
# Depot OS — sinh trang chọn logo: design/identity/logo-options.html
# Ba phương án cho hướng A "Kiện hàng đêm" (khối hộp nhìn nghiêng, navy), mỗi cái có dấu chữ D để không lẫn
# với khối hộp xanh trơn (kiểu VirtualBox) hay hộp mở (kiểu Dropbox):
#   1  Hộp khắc D      khối hộp 3 mặt như concept A, mặt trái khắc chữ D
#   2  Chữ D khối      chính chữ D được đùn thành khối 3 mặt — kiện hàng có hình chữ D
#   3  Kiện trong kho  chữ D phẳng (cái kho) ôm một kiện hàng nhỏ trong lòng   ĐÃ CHỌN (rõ nhất ở 16 px)
# Mỗi logo có bản màu (3 tông navy) và bản một màu (thanh menu 16 px, chỗ chỉ có một màu chữ).
# Chạy: python design/identity/gen-logo-options.py  → trang chọn + logo đã chọn ở design/identity/logo/*.svg
import math, os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logo-options.html")

BG, CRATE, ACCENT, LIGHT, DARK, TEXT = "#0f1420", "#16203a", "#3d6db5", "#a9c1ea", "#26487f", "#e8eefb"
C30, S30 = math.cos(math.pi / 6), 0.5
X, Y, Z = (C30, S30), (-C30, S30), (0.0, -1.0)   # trục isometric trên màn hình (Z hướng lên)

def proj(p):
    x, y, z = p
    return (x * X[0] + y * Y[0] + z * Z[0], x * X[1] + y * Y[1] + z * Z[1])

def d_contours(w, h, stem, n=24):
    """Chữ D trong mặt phẳng (u ngang, v lên): viền ngoài + lỗ trong, nửa tròn bên phải."""
    r = h / 2
    outer = [(0, 0), (w - r, 0)]
    outer += [(w - r + r * math.cos(a), r + r * math.sin(a))
              for a in [(-math.pi / 2) + math.pi * k / n for k in range(1, n)]]
    outer += [(w - r, h), (0, h)]
    ri = r - stem
    inner = [(stem, stem), (w - r, stem)]
    inner += [(w - r + ri * math.cos(a), r + ri * math.sin(a))
              for a in [(-math.pi / 2) + math.pi * k / n for k in range(1, n)]]
    inner += [(w - r, h - stem), (stem, h - stem)]
    return outer, inner

def pts(poly):
    return " ".join("%.2f,%.2f" % p for p in poly)

def shade(n):
    """Màu theo hướng pháp tuyến: trên sáng, trái (mặt trước chữ) vừa, phải tối."""
    nx, ny, nz = n
    l = math.sqrt(nx * nx + ny * ny + nz * nz) or 1
    nx, ny, nz = nx / l, ny / l, nz / l
    if nz > 0.6:
        return LIGHT
    return DARK if nx >= ny else ACCENT

def fit(polys, size=160, pad=30):
    xs = [x for p in polys for x, _ in p["pts"]]
    ys = [y for p in polys for _, y in p["pts"]]
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    s = (size - 2 * pad) / max(w, h)
    ox = size / 2 - (min(xs) + w / 2) * s
    oy = size / 2 - (min(ys) + h / 2) * s
    for p in polys:
        p["pts"] = [(x * s + ox, y * s + oy) for x, y in p["pts"]]
        if p.get("hole") is not None:   # lòng chữ D co giãn cùng viền ngoài
            p["hole"] = [(x * s + ox, y * s + oy) for x, y in p["hole"]]
    return s

def render(polys, mono, fg):
    out = []
    for p in polys:
        fill = fg if mono else p["fill"]
        if p.get("hole") is not None:
            d = "M" + " L".join("%.2f %.2f" % q for q in p["pts"]) + " Z M" + \
                " L".join("%.2f %.2f" % q for q in p["hole"]) + " Z"
            out.append('<path d="%s" fill-rule="evenodd" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>'
                       % (d, fill, p.get("stroke", CRATE), p.get("sw", 2.4)))
        else:
            out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>'
                       % (pts(p["pts"]), p.get("cut", fill) if not mono else (CRATE if p.get("cut") else fill),
                          p.get("stroke", CRATE), p.get("sw", 2.4)))
    return "".join(out)

# ---------- 1. Hộp khắc D: khối hộp 3 mặt, mặt trái khắc chữ D
def logo_box_d():
    a = 1.0
    top = [proj(p) for p in [(0, 0, a), (a, 0, a), (a, -a, a), (0, -a, a)]]
    left = [proj(p) for p in [(0, 0, 0), (a, 0, 0), (a, 0, a), (0, 0, a)]]     # mặt trước (pháp tuyến +Y)
    right = [proj(p) for p in [(a, 0, 0), (a, -a, 0), (a, -a, a), (a, 0, a)]]  # mặt phải (+X)
    outer, inner = d_contours(0.5, 0.56, 0.15)
    off_u, off_v = 0.24, 0.22
    d_out = [proj((off_u + u, 0, off_v + v)) for u, v in outer]
    d_in = [proj((off_u + u, 0, off_v + v)) for u, v in inner]
    polys = [
        {"pts": top, "fill": LIGHT},
        {"pts": left, "fill": ACCENT},
        {"pts": right, "fill": DARK},
        {"pts": d_out, "hole": d_in, "fill": CRATE, "sw": 0},
    ]
    fit(polys)
    return polys

# ---------- 2. Chữ D khối: chữ D đùn sâu thành khối 3 mặt
def logo_d_block():
    outer, inner = d_contours(0.9, 1.0, 0.22)   # nét mảnh + đùn nông: lòng chữ D còn thấy ở 16 px
    depth = 0.28
    polys = []
    sides = []
    for contour, is_hole in ((outer, False), (inner, True)):
        n = len(contour)
        for i in range(n):
            (u1, v1), (u2, v2) = contour[i], contour[(i + 1) % n]
            # pháp tuyến ngoài trong mặt phẳng chữ (u,v): viền ngoài đi ngược chiều kim đồng hồ
            nu, nv = (v2 - v1), -(u2 - u1)
            if is_hole:
                nu, nv = -nu, -nv
            normal = (nu, 0.0, nv)                         # u→X, v→Z
            if normal[0] + normal[2] <= 1e-9:               # quay đi khỏi người nhìn (người nhìn ở (1,1,1))
                continue
            q = [(u1, 0, v1), (u2, 0, v2), (u2, -depth, v2), (u1, -depth, v1)]
            depthkey = sum(x + y + z for x, y, z in q) / 4
            sides.append((depthkey, {"pts": [proj(p) for p in q], "fill": shade(normal), "sw": 0.6, "stroke": None}))
    sides.sort(key=lambda s: s[0])
    for _, p in sides:
        p["stroke"] = p["fill"]
        polys.append(p)
    front = {"pts": [proj((u, 0, v)) for u, v in outer], "hole": [proj((u, 0, v)) for u, v in inner],
             "fill": ACCENT, "sw": 2.4}
    polys.append(front)
    fit(polys)
    return polys

# ---------- 3. Kiện trong kho: chữ D phẳng ôm một kiện nhỏ
def logo_d_crate():
    outer, inner = d_contours(0.86, 1.0, 0.17)
    flip = lambda c: [(u, 1.0 - v) for u, v in c]     # v lên → y xuống của SVG
    d = {"pts": flip(outer), "hole": flip(inner), "fill": LIGHT, "sw": 0}
    a = 0.3
    cx, cy = 0.44, 0.5
    def cube(p):
        x, y = proj(p)
        return (cx + x, cy + y)
    top = [cube(p) for p in [(0, 0, a), (a, 0, a), (a, -a, a), (0, -a, a)]]
    left = [cube(p) for p in [(0, 0, 0), (a, 0, 0), (a, 0, a), (0, 0, a)]]
    right = [cube(p) for p in [(a, 0, 0), (a, -a, 0), (a, -a, a), (a, 0, a)]]
    # căn khối giữa lòng chữ D
    xs = [x for x, _ in top + left + right]; ys = [y for _, y in top + left + right]
    dx = 0.17 + (0.86 - 0.5 - 0.17) * 0.5 + 0.08 - (min(xs) + max(xs)) / 2
    dy = 0.5 - (min(ys) + max(ys)) / 2
    mv = lambda q: [(x + dx, y + dy) for x, y in q]
    polys = [d, {"pts": mv(top), "fill": LIGHT, "sw": 1.6}, {"pts": mv(left), "fill": ACCENT, "sw": 1.6},
             {"pts": mv(right), "fill": DARK, "sw": 1.6}]
    fit(polys, pad=30)
    return polys

# ---------- hình dễ lẫn (không phải logo thật của hãng nào): khối hộp trơn, hộp mở nắp
def lookalike_cube():
    a = 1.0
    blue = ["#7fb2ff", "#2f6fd6", "#1d4fa6"]
    polys = [{"pts": [proj(p) for p in [(0, 0, a), (a, 0, a), (a, -a, a), (0, -a, a)]], "fill": blue[0]},
             {"pts": [proj(p) for p in [(0, 0, 0), (a, 0, 0), (a, 0, a), (0, 0, a)]], "fill": blue[1]},
             {"pts": [proj(p) for p in [(a, 0, 0), (a, -a, 0), (a, -a, a), (a, 0, a)]], "fill": blue[2]}]
    fit(polys)
    return polys

def lookalike_open_box():
    a = 1.0
    f = 0.55
    polys = [{"pts": [proj(p) for p in [(0, 0, 0), (a, 0, 0), (a, 0, a), (0, 0, a)]], "fill": "#2f7cf6"},
             {"pts": [proj(p) for p in [(a, 0, 0), (a, -a, 0), (a, -a, a), (a, 0, a)]], "fill": "#1f5fcf"},
             {"pts": [proj(p) for p in [(0, 0, a), (a, 0, a), (a + f * 0.3, f, a + f), (f * 0.3, f, a + f)]], "fill": "#6aa6ff"},
             {"pts": [proj(p) for p in [(a, 0, a), (a, -a, a), (a + f, -a, a + f * 0.6), (a + f, 0, a + f * 0.6)]], "fill": "#4d8ff9"}]
    fit(polys)
    return polys

LOGOS = {
    "1": ("Hộp khắc D", logo_box_d(),
          "Giữ nguyên khối hộp 3 mặt của concept A, chỉ khắc chữ D vào mặt trước: đổi ít nhất. "
          "Nhưng hình bao vẫn là một khối lục giác, ở cỡ 16–24 px dễ lẫn với khối hộp xanh khác."),
    "2": ("Chữ D khối", logo_d_block(),
          "Chính chữ D được đùn thành khối 3 mặt: vừa là kiện hàng (ba tông navy của hướng A), vừa là chữ D. "
          "Đẹp nhất ở cỡ lớn (boot, đăng nhập), nhưng chữ nghiêng nên ở 16–24 px chỉ còn một vệt, khó đọc ra D."),
    "3": ("Kiện trong kho", logo_d_crate(),
          "Chữ D phẳng là cái kho (depot), trong lòng là kiện hàng 3 mặt của hướng A: kể đúng ý nghĩa tên. "
          "Hình bao là chữ D đứng thẳng nên ở 16 px vẫn đọc ra D, không lẫn với khối hộp trơn hay hộp mở. Khuyên dùng."),
}
LOOK = {"cube": ("Khối hộp trơn", lookalike_cube()), "open": ("Hộp mở nắp", lookalike_open_box())}

def svg(polys, mono=False, fg=TEXT, tile=True, tile_fill=CRATE, size=None, cls=""):
    body = render(polys, mono, fg)
    if mono:  # nét tách mặt dùng màu nền nơi đặt logo
        body = body.replace('stroke="%s"' % CRATE, 'stroke="var(--mono-gap, %s)"' % CRATE)
    t = '<rect width="160" height="160" rx="36" fill="%s"/>' % tile_fill if tile else ""
    sz = ' width="%d" height="%d"' % (size, size) if size else ""
    return '<svg class="%s" viewBox="0 0 160 160"%s xmlns="http://www.w3.org/2000/svg">%s%s</svg>' % (cls, sz, t, body)

def logo_block(k):
    name, polys, why = LOGOS[k]
    color = {
        "tile": svg(polys),
        "bare": svg(polys, tile=False),
        "mono_w": svg(polys, mono=True, fg="#ffffff", tile=False),
        "mono_d": svg(polys, mono=True, fg="#15171c", tile=False),
    }
    return name, why, color

def app_tile(glyph, bg):
    return ('<svg viewBox="0 0 160 160"><rect x="8" y="8" width="144" height="144" rx="34" fill="%s"/>%s</svg>' % (bg, glyph))

FOLDER = '<path d="M38 56h30l10 10h44v50H38z" fill="#fff" opacity=".92"/>'
TERM = '<path d="M50 66l18 14-18 14" stroke="#7CFC9A" stroke-width="9" fill="none" stroke-linecap="round" stroke-linejoin="round"/><path d="M78 98h30" stroke="#ddd" stroke-width="9" stroke-linecap="round"/>'
WEB = '<circle cx="80" cy="80" r="40" fill="#fff" opacity=".92"/><path d="M40 80h80M80 40c-18 22-18 58 0 80M80 40c18 22 18 58 0 80" stroke="#e8642c" stroke-width="5" fill="none"/>'
GEAR = '<circle cx="80" cy="80" r="34" fill="none" stroke="#fff" stroke-width="12" stroke-dasharray="14 9"/><circle cx="80" cy="80" r="14" fill="#fff"/>'
CHAT = '<path d="M44 52h72a10 10 0 0 1 10 10v36a10 10 0 0 1-10 10H74l-20 16v-16H44a10 10 0 0 1-10-10V62a10 10 0 0 1 10-10z" fill="#fff"/>'
MEDIA = '<path d="M66 54l42 26-42 26z" fill="#fff"/>'

def page():
    blocks = {k: logo_block(k) for k in LOGOS}
    data_js = "{" + ",".join(
        '"%s":{name:%s,why:%s,tile:%s,bare:%s,monoW:%s,monoD:%s}' % (
            k, json(v[0]), json(v[1]), json(v[2]["tile"]), json(v[2]["bare"]), json(v[2]["mono_w"]), json(v[2]["mono_d"]))
        for k, v in blocks.items()) + "}"
    look_tiles = "".join(
        '<figure class="dk"><div class="ic">%s</div><figcaption>%s</figcaption></figure>' % (svg(p, tile_fill="#e9eef7"), n)
        for n, p in LOOK.values())
    apps = [("Tệp", FOLDER, "#3b82f6"), ("Trình duyệt", WEB, "#1f2937"), ("Terminal", TERM, "#111318"),
            ("Telegram", CHAT, "#2aa3e0"), ("VLC", MEDIA, "#f08a24"), ("Cài đặt", GEAR, "#6b7280")]
    app_tiles = "".join('<figure class="dk"><div class="ic">%s</div><figcaption>%s</figcaption></figure>'
                        % (app_tile(g, b), n) for n, g, b in apps)
    compare = "".join(
        '<div class="cmp"><span class="cmp-n">%s</span>%s%s%s</div>' % (
            k, svg(LOGOS[k][1], size=16), svg(LOGOS[k][1], size=24), svg(LOGOS[k][1], size=32))
        for k in LOGOS)
    compare += "".join('<div class="cmp"><span class="cmp-n" title="%s">≈</span>%s%s%s</div>' % (
        n, svg(p, tile_fill="#e9eef7", size=16), svg(p, tile_fill="#e9eef7", size=24), svg(p, tile_fill="#e9eef7", size=32))
        for n, p in LOOK.values())
    return TEMPLATE.replace("@DATA@", data_js).replace("@LOOK@", look_tiles).replace("@APPS@", app_tiles) \
        .replace("@COMPARE@", compare)

def json(s):
    import json as j
    return j.dumps(s, ensure_ascii=False)

TEMPLATE = r"""<!doctype html>
<html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Depot OS — chọn logo</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
:root { --bg:#f4f5f7; --card:#fff; --text:#15171c; --muted:#5d6370; --line:#e3e5ea; --accent:#3d6db5; }
@media (prefers-color-scheme: dark) { :root { --bg:#0e0f12; --card:#17191e; --text:#eceef2; --muted:#9aa0ab; --line:#262931; } }
* { box-sizing:border-box; }
body { margin:0; background:var(--bg); color:var(--text); font:14px/1.55 Inter, system-ui, sans-serif; }
main { max-width:1120px; margin:0 auto; padding:24px 16px 56px; }
h1 { font-size:20px; font-weight:600; margin:0 0 2px; }
.lead { color:var(--muted); margin:0 0 16px; }
.bar { display:flex; flex-wrap:wrap; gap:12px; align-items:center; padding:8px 10px; background:var(--card);
       border:1px solid var(--line); border-radius:12px; margin-bottom:16px; position:sticky; top:8px; z-index:5; }
.seg { display:inline-flex; background:var(--bg); border:1px solid var(--line); border-radius:9px; padding:2px; }
.seg button { font:500 13px Inter, sans-serif; color:var(--muted); background:none; border:0; border-radius:7px;
              padding:5px 12px; cursor:pointer; display:inline-flex; gap:6px; align-items:center; }
.seg button[aria-pressed=true] { background:var(--card); color:var(--text); box-shadow:0 0 0 1px var(--line); }
.dot { width:6px; height:6px; border-radius:50%; background:var(--accent); }
.lbl { color:var(--muted); font-size:13px; }
.why { background:var(--card); border:1px solid var(--line); border-radius:12px; padding:12px 14px; margin-bottom:16px; }
.why b { font-weight:600; }
.tag { font-size:12px; font-weight:600; color:#fff; background:var(--accent); border-radius:999px; padding:1px 8px; margin-left:6px; }
.grid { display:grid; grid-template-columns:repeat(2, minmax(0,1fr)); gap:16px; }
@media (max-width:820px) { .grid { grid-template-columns:minmax(0,1fr); } }
.card { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:14px; min-width:0; }
.card h2 { font-size:13px; font-weight:600; margin:0 0 10px; color:var(--muted); }
/* màn boot */
.boot { background:#0e121f; border-radius:10px; aspect-ratio:16/9; display:flex; flex-direction:column;
        align-items:center; justify-content:center; gap:22px; }
.boot .mk svg { width:96px; height:96px; display:block; }
.boot .pb { width:150px; height:3px; background:rgba(255,255,255,.18); border-radius:2px; overflow:hidden; }
.boot .pb i { display:block; width:38%; height:100%; background:rgba(255,255,255,.9); }
/* desktop: thanh menu + dock */
.desk { border-radius:10px; overflow:hidden; aspect-ratio:16/9; position:relative;
        background:radial-gradient(120% 90% at 30% 20%, #1d2f52 0%, #0f1420 70%); }
.menubar { height:24px; background:rgba(15,20,32,.72); display:flex; align-items:center; gap:14px; padding:0 10px;
           color:#e8eefb; font-size:12px; }
.menubar .mk { display:flex; --mono-gap:#141a29; }
.menubar .mk svg { width:16px; height:16px; }
.menubar b { font-weight:600; }
.dock { position:absolute; left:50%; bottom:10px; transform:translateX(-50%); display:flex; gap:8px; padding:6px 8px;
        background:rgba(255,255,255,.14); border:1px solid rgba(255,255,255,.18); border-radius:16px; max-width:96%; overflow:hidden; }
.dk { margin:0; display:flex; flex-direction:column; align-items:center; gap:2px; }
.dk .ic svg { width:40px; height:40px; display:block; }
.dk figcaption { font-size:9.5px; color:rgba(255,255,255,.75); white-space:nowrap; }
.dock .sep { width:1px; background:rgba(255,255,255,.25); margin:4px 2px; }
/* taskbar kiểu Windows */
.task { background:#141925; border-radius:10px; height:44px; display:flex; align-items:center; gap:10px; padding:0 10px; }
.start { width:34px; height:34px; border-radius:8px; display:flex; align-items:center; justify-content:center; background:rgba(255,255,255,.06); --mono-gap:#1b2130; }
.start svg { width:22px; height:22px; }
.task .fake { width:26px; height:26px; border-radius:6px; background:rgba(255,255,255,.12); }
.task .clock { margin-left:auto; color:#cfd6e4; font-size:11px; text-align:right; line-height:1.25; }
/* đăng nhập */
.login { background:radial-gradient(120% 90% at 50% 10%, #1d2f52 0%, #0f1420 75%); border-radius:10px; aspect-ratio:16/9;
         display:flex; flex-direction:column; align-items:center; justify-content:center; gap:10px; color:#e8eefb; }
.login .mk svg { width:64px; height:64px; display:block; }
.login .who { font-weight:600; font-size:15px; }
.login .pw { width:180px; height:28px; border-radius:8px; background:rgba(255,255,255,.12); border:1px solid rgba(255,255,255,.2);
             color:rgba(232,238,251,.6); font-size:12px; display:flex; align-items:center; padding:0 10px; }
/* hàng cỡ */
.sizes { display:flex; flex-wrap:wrap; gap:14px; align-items:flex-end; padding:12px; border-radius:10px; }
.sizes.dark { background:#0f1420; --mono-gap:#0f1420; }
.sizes.light { background:#ffffff; border:1px solid var(--line); --mono-gap:#ffffff; }
.sizes figure { margin:0; display:flex; flex-direction:column; align-items:center; gap:4px; }
.sizes figcaption { font-size:11px; color:#8a93a3; }
.cmpwrap { display:flex; flex-direction:column; gap:8px; }
.cmp { display:flex; align-items:center; gap:12px; }
.cmp-n { width:18px; text-align:center; font-weight:600; color:var(--muted); }
.note { color:var(--muted); font-size:12.5px; margin:8px 0 0; }
</style></head>
<body><main>
<h1>Depot OS — chọn logo</h1>
<p class="lead">Hướng A "Kiện hàng đêm": khối hộp 3 mặt, bảng màu navy. Ba cách thêm dấu chữ D để logo không lẫn với các khối hộp xanh khác. Mỗi logo đặt đúng chỗ nó sẽ xuất hiện trong Depot OS.</p>
<div class="bar" role="toolbar" aria-label="Tuỳ chọn xem">
  <span class="lbl">Logo</span>
  <div class="seg" id="seg-logo">
    <button data-k="1">1 · Hộp khắc D</button><button data-k="2">2 · Chữ D khối</button><button data-k="3"><span class="dot"></span>3 · Kiện trong kho</button>
  </div>
  <span class="lbl">Thanh menu</span>
  <div class="seg" id="seg-mono"><button data-m="1">Một màu</button><button data-m="0">Màu</button></div>
</div>
<div class="why" id="why"></div>
<div class="grid">
  <section class="card"><h2>Màn boot (Plymouth)</h2>
    <div class="boot"><div class="mk" data-slot="bare"></div><div class="pb"><i></i></div></div></section>
  <section class="card"><h2>Màn đăng nhập (LightDM)</h2>
    <div class="login"><div class="mk" data-slot="tile"></div><div class="who">Depot</div><div class="pw">Mật khẩu</div></div></section>
  <section class="card"><h2>Desktop kiểu macOS: thanh menu (16 px) + dock cạnh app khác</h2>
    <div class="desk">
      <div class="menubar"><span class="mk" data-slot="menu"></span><b>Tệp</b><span>Chỉnh sửa</span><span>Xem</span><span style="margin-left:auto">T3 14:05</span></div>
      <div class="dock">@APPS@<figure class="dk"><div class="ic" data-slot="tile"></div><figcaption>Cài Depot OS</figcaption></figure><span class="sep"></span>@LOOK@</div>
    </div>
    <p class="note">Hai ô cuối là hình dễ lẫn (khối hộp trơn, hộp mở nắp) — không phải logo của hãng nào, chỉ để thử độ khác biệt.</p></section>
  <section class="card"><h2>Taskbar kiểu Windows: nút Start (22 px)</h2>
    <div class="task"><div class="start" data-slot="menu"></div><span class="fake"></span><span class="fake"></span><span class="fake"></span><span class="fake"></span>
      <div class="clock">14:05<br>03/11/2026</div></div>
    <h2 style="margin-top:16px">Cỡ 16 · 24 · 32 · 64 · 128 px</h2>
    <div class="sizes dark" id="sizes-dark"></div>
    <div class="sizes light" id="sizes-light" style="margin-top:8px"></div></section>
  <section class="card" style="grid-column:1/-1"><h2>So ba logo ở cỡ nhỏ (16 · 24 · 32 px), hai hàng cuối là hình dễ lẫn</h2>
    <div class="cmpwrap">@COMPARE@</div></section>
</div>
</main>
<script>
const L = @DATA@;
const q = new URLSearchParams(location.search);
let k = L[q.get("logo")] ? q.get("logo") : "3";
let mono = q.get("mono") !== "0";
function sized(svg, px) { return svg.replace("<svg ", `<svg width="${px}" height="${px}" `); }
function draw() {
  const d = L[k];
  document.getElementById("why").innerHTML = `<b>${k} · ${d.name}</b>${k === "3" ? '<span class="tag">Khuyên dùng</span>' : ""}<br>${d.why}`;
  document.querySelectorAll("[data-slot=bare]").forEach(e => e.innerHTML = d.bare);
  document.querySelectorAll("[data-slot=tile]").forEach(e => e.innerHTML = d.tile);
  document.querySelectorAll("[data-slot=menu]").forEach(e => e.innerHTML = mono ? d.monoW : d.bare);
  document.getElementById("sizes-dark").innerHTML = [16, 24, 32, 64, 128].map(px =>
    `<figure>${sized(px <= 24 ? (mono ? d.monoW : d.bare) : d.tile, px)}<figcaption>${px}</figcaption></figure>`).join("");
  document.getElementById("sizes-light").innerHTML = [16, 24, 32, 64, 128].map(px =>
    `<figure>${sized(px <= 24 ? (mono ? d.monoD : d.bare) : d.tile, px)}<figcaption>${px}</figcaption></figure>`).join("");
  document.querySelectorAll("#seg-logo button").forEach(b => b.setAttribute("aria-pressed", b.dataset.k === k));
  document.querySelectorAll("#seg-mono button").forEach(b => b.setAttribute("aria-pressed", (b.dataset.m === "1") === mono));
  const u = new URL(location); u.searchParams.set("logo", k); u.searchParams.set("mono", mono ? "1" : "0");
  try { history.replaceState(null, "", u); } catch (e) {}
}
document.querySelectorAll("#seg-logo button").forEach(b => b.onclick = () => { k = b.dataset.k; draw(); });
document.querySelectorAll("#seg-mono button").forEach(b => b.onclick = () => { mono = b.dataset.m === "1"; draw(); });
draw();
</script>
</body></html>
"""

CHOSEN = "3"   # logo đã chọn: "Kiện trong kho"

def export_logo():
    """Logo đã chọn → design/identity/logo/: bản màu trần, bản trong ô nền, bản một màu trắng/đen."""
    d = os.path.join(os.path.dirname(OUT), "logo")
    os.makedirs(d, exist_ok=True)
    polys = LOGOS[CHOSEN][1]
    files = {
        "depot-logo.svg": svg(polys, tile=False),
        "depot-logo-tile.svg": svg(polys),
        "depot-logo-mono-white.svg": svg(polys, mono=True, fg="#ffffff", tile=False).replace(
            "var(--mono-gap, %s)" % CRATE, BG),
        "depot-logo-mono-dark.svg": svg(polys, mono=True, fg="#15171c", tile=False).replace(
            "var(--mono-gap, %s)" % CRATE, "#ffffff"),
    }
    for name, body in files.items():
        with open(os.path.join(d, name), "w", encoding="utf-8", newline="\n") as f:
            f.write(body)
    return d

if __name__ == "__main__":
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(page())
    print("Đã ghi:", OUT)
    print("Logo đã chọn:", export_logo())
