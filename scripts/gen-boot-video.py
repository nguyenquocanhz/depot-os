#!/usr/bin/env python3
# Depot OS — dựng video boot animation mặc định: design/boot/depot-boot.mp4
# Theo logo "Depot by WrenEvil" — Bóng ma (design/identity/wrenevil/wrenevil_logo.py): hình học lấy thẳng từ file đó,
# đổi logo là video đổi theo. Ý: vô tung vô ảnh như quỷ dữ.
#   0.0–2.0 s  intro: màn tối, đôi mắt đỏ loé lên trước; chữ D hiện dần từ trái sang phải như bóng ma bước ra;
#              hai sừng hiện sau cùng
#   2.0–3.6 s  đoạn lặp: chữ D "thở" — phần tan bên phải lúc đậm lúc mờ, mắt sáng lên rồi chớp một lần
#              (đầu = cuối, nối không giật)
# Video chỉ là NGUỒN: scripts/video-to-plymouth.sh cắt nó thành khung hình cho Plymouth
#   scripts/video-to-plymouth.sh design/boot/depot-boot.mp4 --loop-from 2.0
# Chạy trong WSL: python3 scripts/gen-boot-video.py   — cần rsvg-convert (librsvg2-bin), ffmpeg.
# Bản cũ (logo "Kiện trong kho"): design/identity/logo/cu-kien-trong-kho/gen-boot-video-kien.py
# By WrenEvil.tech & nguyenquocanhz (nqatech)
import importlib.util, math, os, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "design", "boot", "depot-boot.mp4")
FPS = 25
INTRO, LOOP = 2.0, 1.6
SIZE = 240            # cạnh khung hình (px)
SCALE = 1.3           # logo vẽ trong hộp 160 → phóng cho khung 240

_spec = importlib.util.spec_from_file_location(
    "wl", os.path.join(ROOT, "design", "identity", "wrenevil", "wrenevil_logo.py"))
wl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(wl)


def clamp(x, a=0.0, b=1.0): return max(a, min(b, x))
def ease_out(p): return 1 - (1 - p) ** 3
def smooth(p): return p * p * (3 - 2 * p)
def bump(u, start, width):
    """0 → 1 → 0 trong khoảng [start, start+width] của chu kỳ u ∈ [0,1)."""
    x = (u - start) / width
    return math.sin(math.pi * x) ** 2 if 0 <= x <= 1 else 0.0


def frame_svg(t):
    if t < INTRO:
        eye = ease_out(clamp(t / 0.5))                         # mắt loé trước
        reveal = smooth(clamp((t - 0.35) / 1.1))               # D hiện từ trái sang phải
        horn = ease_out(clamp((t - 1.2) / 0.6))
        glow, mid, mid_op = 2.2 + 2.5 * (1 - eye), 0.45, 0.85
        blink = 0.0
    else:
        u = ((t - INTRO) % LOOP) / LOOP
        eye, reveal, horn = 1.0, 1.0, 1.0
        breathe = (1 - math.cos(2 * math.pi * u)) / 2          # 0 ở đầu/cuối chu kỳ
        mid = 0.45 - 0.12 * breathe                            # phần đặc co lại → D tan nhiều hơn
        mid_op = 0.85 - 0.35 * breathe
        glow = 2.2 + 1.6 * breathe
        blink = bump(u, 0.62, 0.12)                            # chớp mắt
    # mặt nạ hé lộ: dải trắng → đen chạy từ trái sang phải
    edge = 30 + 130 * reveal
    mask = ('<mask id="rv"><rect width="160" height="160" fill="url(#rvg)"/></mask>'
            '<linearGradient id="rvg" gradientUnits="userSpaceOnUse" x1="%.1f" y1="0" x2="%.1f" y2="0">'
            '<stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#000"/></linearGradient>'
            % (edge - 30, edge))
    body = wl.mark(eye_op=eye * (1 - 0.9 * blink), horn_op=horn)
    # mắt nằm ngoài mặt nạ (hiện trước cả chữ D): tách lớp mắt ra khỏi phần thân
    head, eyes = body.split('</g>', 1)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">'
            '<defs>{defs}{mask}</defs><rect width="{S}" height="{S}" fill="{bg}"/>'
            '<g transform="translate({c} {c}) scale({s}) translate(-80 -80)">'
            '<g mask="url(#rv)">{head}</g></g>{eyes_g}</g>'
            '</svg>').format(S=SIZE, defs=wl.defs(fade_mid=mid, fade_mid_op=mid_op, glow=glow), mask=mask,
                             bg=wl.BG, c=SIZE / 2, s=SCALE, head=head + '</g>',
                             eyes_g='<g transform="translate({c} {c}) scale({s}) translate(-80 -80)">{e}'.format(
                                 c=SIZE / 2, s=SCALE, e=eyes))


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
        if os.environ.get("DEPOT_KEEP_FRAMES"):
            keep = os.environ["DEPOT_KEEP_FRAMES"]
            os.makedirs(keep, exist_ok=True)
            for k in range(n):
                shutil.copy(os.path.join(tmp, "f%03d.png" % k), keep)
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
