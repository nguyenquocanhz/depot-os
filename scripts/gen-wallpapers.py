#!/usr/bin/env python3
# Depot OS — sinh album hình nền (4 tấm mới; tấm thứ 5 là wallpaper.svg "Kho đêm" có sẵn, giữ nguyên).
# By WrenEvil.tech & nguyenquocanhz (nqatech)
#
# SVG thuần gradient + path, KHÔNG dùng filter (blur, turbulence): librsvg vẽ nhanh trên máy yếu và sắc nét ở mọi
# độ phân giải. Hạt ngẫu nhiên cố định nên chạy lại ra đúng file cũ.
#   python3 scripts/gen-wallpapers.py   → build/live-build/config/includes.chroot/usr/share/backgrounds/depot-os/
# Tên hiển thị trong "Hình nền" (depot-wallpaper) nằm ở album.list cùng thư mục.
import math
import os
import random

W, H = 1920, 1080
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build', 'live-build', 'config',
                   'includes.chroot', 'usr', 'share', 'backgrounds', 'depot-os')


def svg(defs, body):
    # width/height 2560x1440: xfdesktop vẽ SVG theo kích thước gốc rồi mới co giãn — màn 2K vẫn nét
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="2560" height="1440" viewBox="0 0 %d %d" '
            'preserveAspectRatio="xMidYMid slice">\n<defs>\n%s</defs>\n%s</svg>\n' % (W, H, defs, body))


def lin(i, x1, y1, x2, y2, stops, units=''):
    s = ''.join('<stop offset="%s" stop-color="%s" stop-opacity="%s"/>' % (o, c, a) for o, c, a in stops)
    return '<linearGradient id="%s" x1="%s" y1="%s" x2="%s" y2="%s"%s>%s</linearGradient>\n' % (i, x1, y1, x2, y2, units, s)


def rad(i, cx, cy, r, stops):
    s = ''.join('<stop offset="%s" stop-color="%s" stop-opacity="%s"/>' % (o, c, a) for o, c, a in stops)
    return ('<radialGradient id="%s" gradientUnits="userSpaceOnUse" cx="%s" cy="%s" r="%s">%s</radialGradient>\n'
            % (i, cx, cy, r, s))


def smooth(points):
    """Đường cong mượt qua các điểm (Catmull-Rom → Bézier bậc ba)."""
    d = 'M%.1f,%.1f' % points[0]
    for i in range(len(points) - 1):
        p0 = points[max(i - 1, 0)]
        p1, p2 = points[i], points[i + 1]
        p3 = points[min(i + 2, len(points) - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += ' C%.1f,%.1f %.1f,%.1f %.1f,%.1f' % (c1 + c2 + p2)
    return d


def wave(y, amp, n, phase, rnd, jitter=0.0):
    pts = []
    for i in range(n + 1):
        x = -120 + (W + 240) * i / n
        pts.append((x, y + amp * math.sin(phase + i * 2 * math.pi / n * 1.35) + rnd.uniform(-jitter, jitter)))
    return pts


def fill_down(pts, color, opacity=1.0, extra=''):
    return '<path d="%s L%d,%d L%d,%d Z" fill="%s" fill-opacity="%s"%s/>\n' % (
        smooth(pts), W + 120, H + 20, -120, H + 20, color, opacity, extra)


# ---------------------------------------------------------------- 1. Bóng ma (theo logo Depot by WrenEvil)
def bong_ma():
    defs = lin('bg', 0, 0, 1, 1, [(0, '#07080c', 1), (0.6, '#0b0d14', 1), (1, '#12090d', 1)])
    defs += rad('glow', 1420, 600, 760, [(0, '#c0182b', 0.34), (0.45, '#7a0f1c', 0.14), (1, '#7a0f1c', 0)])
    defs += rad('eye', 1090, 478, 120, [(0, '#ff3048', 0.55), (0.3, '#ff3048', 0.16), (1, '#ff3048', 0)])
    defs += rad('vig', 960, 540, 1150, [(0.55, '#000000', 0), (1, '#000000', 0.62)])
    defs += lin('shard', 0, 0, 1, 1, [(0, '#ffffff', 0.05), (1, '#ffffff', 0)])
    body = '<rect width="%d" height="%d" fill="url(#bg)"/>\n<rect width="%d" height="%d" fill="url(#glow)"/>\n' % (W, H, W, H)
    for x in (-260, 240, 820):                      # vệt sáng chéo rất mờ
        body += '<polygon points="%d,0 %d,0 %d,%d %d,%d" fill="url(#shard)"/>\n' % (x + 520, x + 760, x + 240, H, x, H)
    # chữ D tan dần sang phải: nét D lặp lại, mờ và ngả đỏ dần
    d = 'M-96,-230 H0 A230,230 0 0 1 0,230 H-96 Z'
    n = 11
    for i in range(n):
        t = i / (n - 1)
        r = int(233 + (192 - 233) * t); g = int(234 + (24 - 234) * t); b = int(240 + (43 - 240) * t)
        op = 0.42 * (1 - t) ** 1.6 + 0.02
        body += ('<path d="%s" transform="translate(%d,540)" fill="none" stroke="#%02x%02x%02x" stroke-opacity="%.3f" '
                 'stroke-width="%.1f"/>\n' % (d, 1090 + i * 66, r, g, b, op, 3.2 - 1.6 * t))
    body += '<path d="%s" transform="translate(1090,540)" fill="#e9eaf0" fill-opacity="0.045"/>\n' % d
    body += '<circle cx="1090" cy="478" r="120" fill="url(#eye)"/>\n<circle cx="1090" cy="478" r="6.5" fill="#ff3048"/>\n'
    body += '<rect width="%d" height="%d" fill="url(#vig)"/>\n' % (W, H)
    return svg(defs, body)


# ---------------------------------------------------------------- 2. Cực quang
def cuc_quang():
    rnd = random.Random(2026)
    defs = lin('bg', 0, 0, 0, 1, [(0, '#04060e', 1), (0.55, '#081226', 1), (1, '#0b1a2e', 1)])
    cols = ['#2ee6a6', '#38c8ff', '#8a63ff']
    for i, c in enumerate(cols):
        # mỗi tia là một hình chữ nhật hẹp: gradient tính theo từng tia nên đầu và chân tia đều tan hẳn (không cần blur)
        defs += lin('a%d' % i, 0, 0, 0, 1, [(0, c, 0), (0.3, c, 0.5), (0.78, c, 1), (0.92, '#d8fff0', 0.9), (1, c, 0)])
    defs += rad('halo', 960, 700, 1000, [(0, '#2ee6a6', 0.13), (1, '#2ee6a6', 0)])
    body = '<rect width="%d" height="%d" fill="url(#bg)"/>\n' % (W, H)
    for _ in range(190):                              # sao
        x, y = rnd.uniform(0, W), rnd.uniform(0, 760)
        body += '<circle cx="%.1f" cy="%.1f" r="%.2f" fill="#ffffff" fill-opacity="%.2f"/>\n' % (
            x, y, rnd.choice((0.6, 0.8, 0.8, 1.0, 1.3, 1.7)), rnd.uniform(0.15, 0.85) * (1 - y / 950))
    body += '<rect width="%d" height="%d" fill="url(#halo)"/>\n' % (W, H)
    # rèm cực quang: chân rèm uốn theo vài sóng sin, tia cao thấp và đậm nhạt đổi dần theo x
    step = 6
    curtains = [(2, 520, 70, 0.0031, 0.4, 260, 0.20), (1, 610, 90, 0.0024, 2.1, 330, 0.26),
                (0, 700, 80, 0.0036, 4.0, 420, 0.34), (0, 560, 60, 0.0052, 1.2, 300, 0.16)]
    for col, base, amp, freq, ph, height, op in curtains:
        body += '<g fill="url(#a%d)" style="mix-blend-mode:screen">\n' % col
        for x in range(-step, W + step, step):
            foot = base + amp * math.sin(ph + x * freq) + 0.45 * amp * math.sin(1.7 * ph + x * freq * 2.3)
            ray = 0.5 + 0.5 * math.sin(x * 0.013 + ph * 3) * math.sin(x * 0.0041 + ph) + 0.25 * math.sin(x * 0.071 + ph)
            ray = max(0.0, min(1.0, ray))
            h = height * (0.55 + 0.45 * ray) * (0.75 + 0.25 * math.sin(x * 0.0019 + ph * 2))
            o = op * (0.25 + 0.75 * ray)
            if o < 0.02:
                continue
            body += '<rect x="%d" y="%.1f" width="%d" height="%.1f" fill-opacity="%.3f"/>\n' % (x, foot - h, step + 1, h, o)
        body += '</g>\n'
    body += fill_down(wave(905, 34, 7, 0.8, rnd, 16), '#060c18', 1)
    body += fill_down(wave(960, 26, 6, 2.6, rnd, 12), '#03060d', 1)
    return svg(defs, body)


# ---------------------------------------------------------------- 3. Hoàng hôn
def ridge(rnd, base, amp, n=64, rough=0.55):
    """Dãy núi: dịch chuyển trung điểm, rồi làm mượt nhẹ."""
    ys = [0.0, 0.0]
    scale = amp
    while len(ys) < n:
        nxt = []
        for a, b in zip(ys, ys[1:]):
            nxt += [a, (a + b) / 2 + rnd.uniform(-scale, scale)]
        ys = nxt + [ys[-1]]
        scale *= rough
    return [(-120 + (W + 240) * i / (len(ys) - 1), base + y) for i, y in enumerate(ys)]


def hoang_hon():
    rnd = random.Random(715)
    defs = lin('sky', 0, 0, 0, 1, [(0, '#120b2b', 1), (0.3, '#3a1e5e', 1), (0.52, '#8f3a6e', 1),
                                  (0.66, '#e0686a', 1), (0.76, '#ffb070', 1), (1, '#ffd9a0', 1)])
    defs += rad('sun', 1310, 742, 520, [(0, '#fff3cf', 0.95), (0.16, '#ffd58f', 0.6), (0.5, '#ff9a6a', 0.18), (1, '#ff9a6a', 0)])
    defs += lin('haze', 0, 0, 0, 1, [(0, '#ffc9a0', 0), (0.55, '#ffc9a0', 0.13), (1, '#ffc9a0', 0)])
    body = '<rect width="%d" height="%d" fill="url(#sky)"/>\n' % (W, H)
    for _ in range(70):
        x, y = rnd.uniform(0, W), rnd.uniform(0, 330)
        body += '<circle cx="%.1f" cy="%.1f" r="%.2f" fill="#ffffff" fill-opacity="%.2f"/>\n' % (
            x, y, rnd.choice((0.6, 0.8, 1.0, 1.3)), rnd.uniform(0.1, 0.6) * (1 - y / 360))
    body += '<rect width="%d" height="%d" fill="url(#sun)"/>\n<circle cx="1310" cy="742" r="78" fill="#fff1c9"/>\n' % (W, H)
    layers = [(700, 120, '#7a3f78', 0.8), (770, 110, '#55285f', 0.92), (835, 95, '#381a4c', 1),
              (905, 80, '#22103a', 1), (975, 60, '#120824', 1)]
    for base, amp, col, op in layers:
        pts = ridge(rnd, base, amp)
        body += '<path d="M%s L%d,%d L%d,%d Z" fill="%s" fill-opacity="%s"/>\n' % (
            ' L'.join('%.1f,%.1f' % p for p in pts), W + 120, H + 20, -120, H + 20, col, op)
        if base < 950:                                # sương giữa các dãy núi xa; dãy gần nhất để đặc
            body += '<rect y="%d" width="%d" height="%d" fill="url(#haze)"/>\n' % (base - 30, W, 170)
    return svg(defs, body)


# ---------------------------------------------------------------- 4. Ban mai (tấm sáng)
def ban_mai():
    rnd = random.Random(48)
    defs = lin('bg', 0, 0, 1, 1, [(0, '#f6f8fd', 1), (0.5, '#e7eefb', 1), (1, '#fbece6', 1)])
    defs += rad('b1', 380, 220, 900, [(0, '#9fc2ff', 0.6), (1, '#9fc2ff', 0)])
    defs += rad('b2', 1620, 300, 760, [(0, '#c9b6ff', 0.42), (1, '#c9b6ff', 0)])
    defs += rad('b3', 1500, 1000, 900, [(0, '#ffc2ad', 0.55), (1, '#ffc2ad', 0)])
    defs += lin('w1', 0, 0, 0, 1, [(0, '#bcd3f7', 0.85), (1, '#d9e6fb', 0.55)])
    defs += lin('w2', 0, 0, 0, 1, [(0, '#a7c3f2', 0.8), (1, '#c6d8f7', 0.6)])
    defs += lin('w3', 0, 0, 0, 1, [(0, '#8fb0ea', 0.82), (1, '#b4caf3', 0.7)])
    body = '<rect width="%d" height="%d" fill="url(#bg)"/>\n' % (W, H)
    for g in ('b1', 'b2', 'b3'):
        body += '<rect width="%d" height="%d" fill="url(#%s)"/>\n' % (W, H, g)
    for y, amp, ph, g in ((690, 60, 0.4, 'w1'), (790, 52, 2.2, 'w2'), (890, 44, 4.1, 'w3')):
        body += '<path d="%s L%d,%d L%d,%d Z" fill="url(#%s)"/>\n' % (
            smooth(wave(y, amp, 6, ph, rnd, 14)), W + 120, H + 20, -120, H + 20, g)
    return svg(defs, body)


ALBUM = [
    ('wallpaper.svg', 'Kho đêm', 'Night depot', None),
    ('depot-bong-ma.svg', 'Bóng ma', 'Phantom', bong_ma),
    ('depot-cuc-quang.svg', 'Cực quang', 'Aurora', cuc_quang),
    ('depot-hoang-hon.svg', 'Hoàng hôn', 'Dusk', hoang_hon),
    ('depot-ban-mai.svg', 'Ban mai', 'Daybreak', ban_mai),
]

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for name, title, _en, fn in ALBUM:
        if fn:
            with open(os.path.join(OUT, name), 'w', encoding='utf-8', newline='\n') as f:
                f.write(fn())
        print('%-22s %s (%d byte)' % (name, title, os.path.getsize(os.path.join(OUT, name))))
    with open(os.path.join(OUT, 'album.list'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('# Depot OS — album hình nền: tên-file|tên tiếng Việt|tên tiếng Anh (scripts/gen-wallpapers.py sinh)\n')
        f.writelines('%s|%s|%s\n' % (n, t, e) for n, t, e, _ in ALBUM)
