#!/usr/bin/env python3
# Depot OS — sinh boot animation mặc định của Plymouth (theme "depot") từ logo "Depot by WrenEvil" — Bóng ma.
# Hình học VÀ bố cục lấy thẳng từ design/identity/wrenevil/wrenevil_logo.py: đổi logo hay đổi chỗ đặt logo ở menu boot
# thì chạy lại file này, animation đổi theo.
#
# ĐỒNG BỘ VỚI LOGO Ở MENU BOOT (từ v0.24): khung đầu tiên của animation LÀ logo tĩnh, đặt đúng chỗ, đúng cỡ, trên đúng
# quầng đỏ và hai dòng chữ của ảnh menu GRUB — lúc máy chuyển từ menu sang animation, logo đứng yên rồi "tỉnh dậy".
# (Trước đó animation bắt đầu từ màn đen, logo nằm giữa màn, cỡ tính bằng pixel, nền phẳng không quầng không chữ.)
#   0.0–0.2 s  đứng yên = logo tĩnh (chỗ nối với ảnh menu boot)
#   0.2–1.2 s  tỉnh dậy: mắt loé sáng, thân chữ D tan gần hết về bên phải như bóng ma rồi đặc lại, sừng mờ đi rồi rõ lại
#   1.2–2.8 s  đoạn lặp: chữ D "thở" — phần tan bên phải lúc đậm lúc mờ, mắt sáng lên rồi chớp một lần
#              (đầu = cuối = logo tĩnh, nối không giật)
# Ghi ra:
#   themes/depot/frame-NNN.png   khung hình PNG nền TRONG SUỐT, cạnh FRAME px = hộp logo (không qua video nén nên không
#                                lệch màu); depot.script co giãn theo chiều cao màn hình
#   themes/depot/halo.png, wordmark.png, bar.png, depot.script (từ scripts/plymouth/depot.script.in, bố cục "logo")
#   design/boot/depot-boot.mp4   bản xem trước (logo trên nền đặc) — chỉ để xem, theme không dùng
# Muốn dùng một video BẤT KỲ làm animation: scripts/video-to-plymouth.sh VIDEO (bố cục "video": giữa màn, cỡ gốc).
# Chạy trong WSL: python3 scripts/gen-boot-video.py   — cần rsvg-convert (librsvg2-bin), convert (imagemagick), ffmpeg,
# font Inter. Bản cũ (logo "Kiện trong kho"): design/identity/logo/cu-kien-trong-kho/gen-boot-video-kien.py
# By WrenEvil.tech & nguyenquocanhz (nqatech)
import glob, importlib.util, math, os, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "design", "boot", "depot-boot.mp4")
THEME = os.path.join(ROOT, "build", "live-build", "config", "includes.chroot", "usr", "share", "plymouth", "themes", "depot")
TEMPLATE = os.path.join(ROOT, "scripts", "plymouth", "depot.script.in")
FPS = 25
WAKE, LOOP = 1.2, 1.6
HOLD = 0.2            # đầu đoạn tỉnh dậy đứng yên chừng này giây
FRAME = 256           # cạnh khung hình (px) = hộp logo 160 đơn vị. Màn 1080 cần 230 px, màn 768 cần 164 px.

_spec = importlib.util.spec_from_file_location(
    "wl", os.path.join(ROOT, "design", "identity", "wrenevil", "wrenevil_logo.py"))
wl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(wl)


def clamp(x, a=0.0, b=1.0): return max(a, min(b, x))
def bump(u, start, width):
    """0 → 1 → 0 trong khoảng [start, start+width] của chu kỳ u ∈ [0,1)."""
    x = (u - start) / width
    return math.sin(math.pi * x) ** 2 if 0 <= x <= 1 else 0.0


def state(t):
    """Trạng thái logo ở giây t. Ở t = 0, cuối đoạn tỉnh dậy và hai đầu đoạn lặp, mọi số = logo tĩnh (wl.defs / wl.mark)."""
    if t < WAKE:
        w = bump(clamp((t - HOLD) / (WAKE - HOLD)), 0.0, 1.0)      # 0 → 1 → 0
        return dict(eye=1.0, horn=1 - 0.75 * w, mid=0.45 - 0.27 * w, mid_op=0.85 - 0.60 * w, glow=2.2 + 4.0 * w)
    u = ((t - WAKE) % LOOP) / LOOP
    breathe = (1 - math.cos(2 * math.pi * u)) / 2                  # 0 ở đầu/cuối chu kỳ
    blink = bump(u, 0.62, 0.12)                                    # chớp mắt
    return dict(eye=1 - 0.9 * blink, horn=1.0, mid=0.45 - 0.12 * breathe, mid_op=0.85 - 0.35 * breathe,
                glow=2.2 + 1.6 * breathe)


def frame_svg(t, size, bg=None):
    s = state(t)
    rect = '<rect width="160" height="160" fill="%s"/>' % bg if bg else ''
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 160 160">'
            '<defs>{d}</defs>{r}{m}</svg>'
            ).format(S=size, d=wl.defs(fade_mid=s['mid'], fade_mid_op=s['mid_op'], glow=s['glow']), r=rect,
                     m=wl.mark(eye_op=s['eye'], horn_op=s['horn']))


def render(svg_text, png, tmp):
    svg = os.path.join(tmp, "f.svg")
    with open(svg, "w") as f:
        f.write(svg_text)
    subprocess.run(["rsvg-convert", "-o", png, svg], check=True)


def write_script(n, loop):
    r, g, b = (int(wl.BG[i:i + 2], 16) for i in (1, 3, 5))
    with open(TEMPLATE, encoding="utf-8") as f:
        s = f.read()
    for k, v in (("FRAMES", n), ("LOOP", loop), ("FPS", FPS), ("BG_R", r), ("BG_G", g), ("BG_B", b),
                 ("LAYOUT_LOGO", 1), ("LOGO_FRAC", wl.BOOT_LOGO), ("TOP_FRAC", wl.BOOT_TOP),
                 ("HALO_CY", wl.BOOT_HALO_CY), ("HALO_R", wl.BOOT_HALO_R), ("WORD_W", wl.BOOT_WORD_BOX[0]),
                 ("WORD_H", wl.BOOT_WORD_BOX[1]), ("MENU_TOP", wl.BOOT_MENU_TOP)):
        s = s.replace("@%s@" % k, str(v))
    assert "@" not in "".join(l for l in s.splitlines() if not l.lstrip().startswith("//")), "còn chỗ @…@ chưa thay"
    with open(os.path.join(THEME, "depot.script"), "w", encoding="utf-8", newline="\n") as f:
        f.write(s)


def main():
    for tool in ("rsvg-convert", "convert", "ffmpeg"):
        if not shutil.which(tool):
            sys.exit("thiếu %s (apt-get install librsvg2-bin imagemagick ffmpeg)" % tool)
    n = round((WAKE + LOOP) * FPS)
    loop = round(WAKE * FPS)
    tmp = tempfile.mkdtemp(prefix="depot-boot-")
    try:
        # --- khung hình của theme: nền trong suốt
        for old in glob.glob(os.path.join(THEME, "frame-*.png")):
            os.remove(old)
        for k in range(n):
            raw = os.path.join(tmp, "t%03d.png" % k)
            render(frame_svg(k / FPS, FRAME), raw, tmp)
            subprocess.run(["convert", raw, "-strip", "-define", "png:compression-level=9",
                            os.path.join(THEME, "frame-%03d.png" % k)], check=True)
        wl.plymouth_assets(THEME, ref=FRAME)
        subprocess.run(["convert", "-size", "4x4", "xc:white", "-alpha", "off", "PNG24:" + os.path.join(THEME, "bar.png")],
                       check=True)
        write_script(n, loop)
        # --- bản xem trước: logo trên nền đặc
        for k in range(n):
            render(frame_svg(k / FPS, 240, bg=wl.BG), os.path.join(tmp, "f%03d.png" % k), tmp)
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", str(FPS),
                        "-i", os.path.join(tmp, "f%03d.png"), "-c:v", "libx264", "-crf", "8",
                        "-pix_fmt", "yuv420p", "-movflags", "+faststart", OUT], check=True)
    finally:
        shutil.rmtree(tmp)
    kb = sum(os.path.getsize(p) for p in glob.glob(os.path.join(THEME, "*.png"))) / 1024
    print("Theme Plymouth: %d khung %d px nền trong suốt, lặp từ khung %d, %.0f KB vào initramfs" % (n, FRAME, loop, kb))
    print("Xem trước: %s (%.1f s, %.0f KB)" % (os.path.relpath(OUT, ROOT), n / FPS, os.path.getsize(OUT) / 1024))


if __name__ == "__main__":
    main()
