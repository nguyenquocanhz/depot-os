#!/usr/bin/env python3
# Depot OS — dựng video boot animation mặc định: design/boot/depot-boot.mp4
# Theo logo đã chọn "Kiện trong kho" (design/identity/gen-logo-options.py, CHOSEN): chữ D là cái kho,
# kiện hàng 3 mặt navy nằm trong lòng — hình học lấy thẳng từ file đó, đổi logo là video đổi theo.
#   0.0–1.8 s  intro: nét chữ D vẽ ra, D tô đầy, kiện hàng thả vào lòng D rồi nảy nhẹ, vòng sáng loang ra
#   1.8–3.4 s  đoạn lặp: kiện hàng nổi lên chút rồi hạ, mặt trên sáng lên, chữ D thở theo (đầu = cuối, nối không giật)
# Video chỉ là NGUỒN: scripts/video-to-plymouth.sh cắt nó thành khung hình cho Plymouth
# (thay bằng video khác bất kỳ cũng được). Chạy trong WSL: python3 scripts/gen-boot-video.py
# Cần: rsvg-convert (librsvg2-bin), ffmpeg.
import importlib.util, math, os, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "design", "boot", "depot-boot.mp4")
FPS = 25
INTRO, LOOP = 1.8, 1.6
SIZE = 240            # cạnh khung hình (px)
SCALE = 1.45          # logo vẽ trong hộp 160 → phóng lên cho khung 240

_spec = importlib.util.spec_from_file_location("logo", os.path.join(ROOT, "design", "identity", "gen-logo-options.py"))
logo = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(logo)
D, TOP, LEFT, RIGHT = logo.LOGOS[logo.CHOSEN][1]   # chữ D (có lòng) + 3 mặt kiện hàng, toạ độ trong hộp 160

def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
BG = rgb(logo.BG)
WHITE = (240, 245, 255)

def clamp(x, a=0.0, b=1.0): return max(a, min(b, x))
def ease_out_cubic(p): return 1 - (1 - p) ** 3
def ease_in_out(p): return p * p * (3 - 2 * p)
def bounce(p):
    """Rơi xuống rồi nảy nhẹ một lần (0 → 1)."""
    if p < 0.7:
        q = p / 0.7
        return q * q
    q = (p - 0.7) / 0.3
    return 1 - 0.12 * math.sin(math.pi * q)
def mix(c1, c2, t): return tuple(round(a + (b - a) * t) for a, b in zip(c1, c2))
def hexc(c): return "#%02x%02x%02x" % c
def env(u, start, width):
    """Đường bao sin² bằng 0 ở hai đầu đoạn lặp → nối liền mạch."""
    return math.sin(math.pi * clamp((u - start) / width)) ** 2

def path_d(points):
    return "M" + " L".join("%.2f %.2f" % p for p in points) + " Z"

def length(points):
    return sum(math.dist(points[i], points[(i + 1) % len(points)]) for i in range(len(points)))

D_PATH = path_d(D["pts"]) + " " + path_d(D["hole"])
D_LEN = length(D["pts"]) + length(D["hole"])
CRATE_POLYS = [TOP, LEFT, RIGHT]
CRATE_Y = [y for p in CRATE_POLYS for _, y in p["pts"]]
DROP = 42   # rơi từ ngay trên chữ D (vẫn trong khung hình, không bị cắt ở mép)

def frame_svg(t):
    intro = t < INTRO
    u = 0.0 if intro else (t - INTRO) / LOOP
    parts = []
    d_col = rgb(D["fill"])
    if intro:
        draw = ease_in_out(clamp(t / 0.8))                # nét chữ D vẽ ra
        fill = ease_out_cubic(clamp((t - 0.55) / 0.45))   # rồi tô đầy
        drop = bounce(clamp((t - 0.85) / 0.6))            # kiện hàng rơi vào lòng
        crate_a = ease_out_cubic(clamp((t - 0.85) / 0.3))
        dy = -(1 - drop) * DROP
        top_glow = 0.0
    else:
        draw, fill, crate_a = 1.0, 1.0, 1.0
        dy = -4.0 * env(u, 0.0, 1.0)                      # nổi lên 4 đơn vị rồi hạ
        top_glow = 0.55 * env(u, 0.1, 0.7)
        d_col = mix(d_col, WHITE, 0.14 * env(u, 0.3, 0.7))
    # vòng sáng loang ra cuối intro
    if 1.4 <= t < INTRO:
        p = (t - 1.4) / (INTRO - 1.4)
        r = 52 + 26 * ease_out_cubic(p)
        parts.append('<circle cx="80" cy="80" r="%.1f" fill="none" stroke="%s" stroke-width="5" '
                     'opacity="%.3f" filter="url(#b)"/>' % (r, logo.ACCENT, 0.6 * (1 - p)))
    if fill > 0:
        parts.append('<path d="%s" fill-rule="evenodd" fill="%s" opacity="%.3f"/>' % (D_PATH, hexc(d_col), fill))
    if draw > 0 and fill < 1:
        parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="3" stroke-linejoin="round" '
                     'stroke-dasharray="%.1f %.1f" stroke-dashoffset="%.1f" opacity="%.3f"/>'
                     % (D_PATH, hexc(rgb(D["fill"])), D_LEN, D_LEN, D_LEN * (1 - draw), 1 - fill * 0.9))
    if crate_a > 0:
        faces = []
        for i, poly in enumerate(CRATE_POLYS):
            col = rgb(poly["fill"])
            if i == 0:
                col = mix(col, WHITE, top_glow)
            faces.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>'
                         % (logo.pts(poly["pts"]), hexc(col), logo.CRATE, poly.get("sw", 1.6)))
        parts.append('<g transform="translate(0 %.2f)" opacity="%.3f">%s</g>' % (dy, crate_a, "".join(faces)))
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">'
            '<defs><filter id="b" x="-50%" y="-50%" width="200%" height="200%">'
            '<feGaussianBlur stdDeviation="4"/></filter></defs>'
            '<rect width="{S}" height="{S}" fill="{bg}"/>'
            '<g transform="translate({c} {c}) scale({s}) translate(-80 -80)">{body}</g>'
            '</svg>').format(S=SIZE, bg=hexc(BG), c=SIZE / 2, s=SCALE, body="".join(parts))

def main():
    for tool in ("rsvg-convert", "ffmpeg"):
        if not shutil.which(tool):
            sys.exit("thiếu %s (apt-get install librsvg2-bin ffmpeg)" % tool)
    n = round((INTRO + LOOP) * FPS)
    tmp = tempfile.mkdtemp(prefix="depot-boot-")
    try:
        for k in range(n):
            svg = os.path.join(tmp, "f%03d.svg" % k)
            with open(svg, "w") as f:
                f.write(frame_svg(k / FPS))
            subprocess.run(["rsvg-convert", "-o", os.path.join(tmp, "f%03d.png" % k), svg], check=True)
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", str(FPS),
                        "-i", os.path.join(tmp, "f%03d.png"), "-c:v", "libx264", "-crf", "8",
                        "-pix_fmt", "yuv420p", "-movflags", "+faststart", OUT], check=True)
    finally:
        shutil.rmtree(tmp)
    print("Đã ghi: %s (%d khung, %.1f s, đoạn lặp từ %.1f s → --loop-from %.1f, %.0f KB)"
          % (OUT, n, n / FPS, INTRO, INTRO, os.path.getsize(OUT) / 1024))

if __name__ == "__main__":
    main()
