#!/usr/bin/env python3
# Depot OS — logo "Depot by WrenEvil" (phương án 1 "Bóng ma", chọn 08/11/2026): vô tung vô ảnh như quỷ dữ.
# Chữ D của Depot đặc ở thân, tan dần sang phải như bóng ma đang biến mất; hai sừng (sừng sau mờ); mắt đỏ trong lòng D.
# By WrenEvil.tech & nguyenquocanhz (nqatech)
#
# Một nguồn hình học cho mọi nơi: file logo (design/identity/logo/), icon trong ISO, video boot (scripts/gen-boot-video.py).
#   python3 design/identity/wrenevil/wrenevil_logo.py      ghi lại các file logo + bản sao trong includes.chroot
# Logo cũ "Kiện trong kho": design/identity/logo/cu-kien-trong-kho/

import os
import shutil
import subprocess

BG = '#07080c'        # nền ô / nền màn boot
FG = '#e8ecf5'        # thân chữ
RED = '#ff2d3d'       # mắt
DARK = '#0b0c10'      # bản một màu cho nền sáng

# toạ độ trong hộp 160, đã dời 6 xuống cho cân giữa (mép trên sừng 22, đáy D 138)
HORN_FRONT = 'M44 46 C42 36 44 28 50 22 C50 32 54 39 60 46 Z'
HORN_BACK = 'M88 47 C92 37 98 31 106 28 C102 36 101 43 102 51 Z'
D_PATH = 'M40 46 H82 A46 46 0 0 1 82 138 H40 Z M62 66 H80 A26 26 0 0 1 80 118 H62 Z'
EYE_L = 'M66 88 L80 84 L78 92 Z'
EYE_R = 'M84 83 L98 87 L86 92 Z'


def defs(uid='', fade_mid=0.45, fade_mid_op=0.85, glow=2.2, color=FG, end_op=0.0):
    return ('<linearGradient id="fade{u}" gradientUnits="userSpaceOnUse" x1="40" y1="0" x2="128" y2="0">'
            '<stop offset="0" stop-color="{c}"/>'
            '<stop offset="{m:.3f}" stop-color="{c}" stop-opacity="{mo:.3f}"/>'
            '<stop offset="1" stop-color="{c}" stop-opacity="{eo:.3f}"/></linearGradient>'
            '<filter id="glow{u}" x="-80%" y="-80%" width="260%" height="260%">'
            '<feGaussianBlur stdDeviation="{g:.2f}" result="b"/>'
            '<feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>'
            ).format(u=uid, c=color, m=fade_mid, mo=fade_mid_op, g=glow, eo=end_op)


def mark(uid='', color=FG, eyes=RED, eye_op=1.0, horn_op=1.0, body_op=1.0, glow=True):
    """Phần hình (không nền): sừng + D tan dần + mắt."""
    g = ' filter="url(#glow%s)"' % uid if glow else ''
    return ('<g opacity="{bo:.3f}">'
            '<path d="{hf}" fill="{c}" opacity="{ho:.3f}"/>'
            '<path d="{hb}" fill="{c}" opacity="{hb_op:.3f}"/>'
            '<path d="{d}" fill="url(#fade{u})" fill-rule="evenodd"/></g>'
            '<g fill="{e}"{g} opacity="{eo:.3f}"><path d="{el}"/><path d="{er}" opacity=".8"/></g>'
            ).format(bo=body_op, hf=HORN_FRONT, hb=HORN_BACK, c=color, ho=horn_op, hb_op=0.55 * horn_op,
                     d=D_PATH, u=uid, e=eyes, g=g, eo=eye_op, el=EYE_L, er=EYE_R)


def svg(body, size=160, defs_=''):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="{s}" height="{s}" viewBox="0 0 160 160">'
            '<defs>{d}</defs>{b}</svg>\n').format(s=size, d=defs_, b=body)


def tile():
    return svg('<rect width="160" height="160" rx="36" fill="%s"/>' % BG + mark(), defs_=defs())


def plain():
    return svg(mark(), defs_=defs())


def mono(color):
    # một màu, không đỏ, không phát sáng — nút menu / nền sáng. Mắt nằm trong lòng D (vùng trống) nên tô cùng màu.
    return svg(mark(color=color, eyes=color, glow=False), defs_=defs(color=color, fade_mid=0.5, fade_mid_op=0.9))


def wordmark():
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="520" height="160" viewBox="0 0 520 160">'
            '<defs>{d}</defs><rect width="520" height="160" rx="36" fill="{bg}"/>{m}'
            '<text x="168" y="92" font-family="Inter, sans-serif" font-weight="800" font-size="56" '
            'letter-spacing="8" fill="{fg}">DEPOT</text>'
            '<text x="170" y="124" font-family="Inter, sans-serif" font-size="20" letter-spacing="1.5" fill="#8a90a2">'
            'by Wren<tspan fill="{red}">Evil</tspan></text></svg>\n'
            ).format(d=defs(), bg=BG, m=mark(), fg=FG, red=RED)


def boot_bg(w, h, logo, top, title=True, corner=False):
    """Nền menu boot: đen + quầng đỏ rất mờ, logo (giữa trên, hoặc góc dưới phải cho GRUB máy đã cài)."""
    s = logo / 160.0
    if corner:
        lx, ly = w - logo - 48, h - logo - 40
    else:
        lx, ly = (w - logo) / 2, top
    glow_cx, glow_cy = lx + logo / 2, ly + logo * 0.55
    text = ''
    if title:
        tx = lx + logo / 2 if not corner else lx - 18
        anchor = 'middle' if not corner else 'end'
        ty = ly + logo + logo * 0.28 if not corner else ly + logo * 0.62
        fs = max(14, logo * 0.2)
        text = ('<text x="{x:.0f}" y="{y:.0f}" text-anchor="{a}" font-family="Inter, sans-serif" font-weight="800" '
                'font-size="{f:.0f}" letter-spacing="{ls:.1f}" fill="{fg}">DEPOT</text>'
                '<text x="{x:.0f}" y="{y2:.0f}" text-anchor="{a}" font-family="Inter, sans-serif" font-size="{f2:.0f}" '
                'letter-spacing="1" fill="#8a90a2">by Wren<tspan fill="{red}">Evil</tspan></text>'
                ).format(x=tx, y=ty, y2=ty + fs * 0.95, a=anchor, f=fs, f2=fs * 0.5, ls=fs * 0.16, fg=FG, red=RED)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            '<defs>{d}<radialGradient id="halo" gradientUnits="userSpaceOnUse" cx="{gx:.0f}" cy="{gy:.0f}" r="{gr:.0f}">'
            '<stop offset="0" stop-color="{red}" stop-opacity=".10"/><stop offset="1" stop-color="{red}" stop-opacity="0"/>'
            '</radialGradient></defs><rect width="{w}" height="{h}" fill="{bg}"/>'
            '<rect width="{w}" height="{h}" fill="url(#halo)"/>'
            '<g transform="translate({lx:.1f} {ly:.1f}) scale({s:.4f})">{m}</g>{t}</svg>\n'
            ).format(w=w, h=h, d=defs(), gx=glow_cx, gy=glow_cy, gr=logo * 2.2, red=RED, bg=BG, lx=lx, ly=ly, s=s,
                     m=mark(), t=text)


def boot_images(root, logo):
    """Ảnh menu boot: GRUB của ISO (800x600, theme live-theme), isolinux BIOS (640x480), GRUB máy đã cài (1920x1080)."""
    if not (shutil.which('rsvg-convert') and shutil.which('convert')):
        print('!! bỏ qua ảnh menu boot (thiếu rsvg-convert / convert)')
        return
    lb = os.path.join(root, 'build', 'live-build', 'config')
    jobs = [
        # menu GRUB của ISO: boot_menu bắt đầu ở 50% — logo + chữ nằm phần trên
        (boot_bg(800, 600, 128, 46), os.path.join(lb, 'includes.binary', 'boot', 'grub', 'splash.png')),
        # isolinux: menu vshift 12 dòng (~ y 200) — logo nhỏ hơn, không chữ (chữ đã có ở tiêu đề menu)
        (boot_bg(640, 480, 104, 26, title=False), os.path.join(lb, 'includes.binary', 'isolinux', 'splash.png')),
        # GRUB máy đã cài: chữ menu chạy từ góc trên trái → logo góc dưới phải
        (boot_bg(1920, 1080, 180, 0, corner=True), os.path.join(lb, 'includes.chroot', 'usr', 'share', 'images',
                                                                 'depot', 'grub.png')),
    ]
    tmp = os.path.join(logo, '.boot-tmp.svg')
    for svg_s, out in jobs:
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(tmp, 'w', encoding='utf-8') as f:
            f.write(svg_s)
        # PNG 8-bit RGB không alpha: isolinux (vesamenu) và GRUB đọc chắc chắn
        subprocess.run(['rsvg-convert', '-o', out + '.rgba.png', tmp], check=True)
        subprocess.run(['convert', out + '.rgba.png', '-background', BG, '-flatten', '-alpha', 'off',
                        '-define', 'png:color-type=2', out], check=True)
        os.remove(out + '.rgba.png')
        print('ghi', os.path.relpath(out, root))
    os.remove(tmp)
    # khung mục đang chọn của theme GRUB (9 mảnh select_*.png, đỏ sẫm)
    d = os.path.join(lb, 'includes.binary', 'boot', 'grub', 'live-theme')
    os.makedirs(d, exist_ok=True)
    for part in ('c', 'n', 's', 'e', 'w', 'ne', 'nw', 'se', 'sw'):
        # PNG24: ép RGB — ảnh một màu ImageMagick lưu thành bảng màu 1-bit, GRUB không đọc được (khung chọn mất)
        subprocess.run(['convert', '-size', '4x4', 'xc:#3a0f16', '-alpha', 'off',
                        'PNG24:' + os.path.join(d, 'select_%s.png' % part)], check=True)
    print('ghi', os.path.relpath(d, root) + '/select_*.png')


def fastfetch_logo(root):
    """Logo chữ cho fastfetch: thu logo thật về 16×22 điểm, mỗi ô ký tự = 2 điểm dọc (▀ ▄ █).
    $1 trắng (thân), $3 xám (phần tan), $2 đỏ (mắt)."""
    if not (shutil.which('rsvg-convert') and shutil.which('convert')):
        print('!! bỏ qua logo fastfetch (thiếu rsvg-convert / convert)')
        return
    W, H = 16, 22
    svg_s = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="36 18 96 124">'
             '<defs>%s</defs>%s</svg>' % (W, H, defs(fade_mid=0.42, fade_mid_op=0.9, end_op=0.4),
                                          mark(glow=False)))
    tmp = os.path.join(root, 'design', 'identity', 'logo', '.ff.svg')
    with open(tmp, 'w', encoding='utf-8') as f:
        f.write(svg_s)
    png = tmp + '.png'
    subprocess.run(['rsvg-convert', '-w', str(W), '-h', str(H), '-o', png, tmp], check=True)
    txt = subprocess.run(['convert', png, 'txt:-'], capture_output=True, text=True, check=True).stdout
    os.remove(tmp)
    os.remove(png)
    px = {}
    for l in txt.splitlines():
        m = __import__('re').match(r'(\d+),(\d+):\s*\(\s*([\d.]+)%?,\s*([\d.]+)%?,\s*([\d.]+)%?,\s*([\d.]+)%?', l)
        if not m:
            continue
        x, y = int(m.group(1)), int(m.group(2))
        r, g, b, a = (float(m.group(i)) for i in range(3, 7))
        if '%' in l.split(':', 1)[1]:          # ImageMagick có bản in phần trăm
            r, g, b, a = r * 2.55, g * 2.55, b * 2.55, a / 100
        elif a > 1:
            a /= 255
        if a < 0.22:
            c = 0
        elif r > 170 and g < 110:
            c = 2                               # mắt
        elif a > 0.72:
            c = 1                               # thân đặc
        else:
            c = 3                               # phần tan dần
        px[(x, y)] = c
    lines = []
    for row in range(0, H, 2):
        out, cur = '', None
        for x in range(W):
            t, b = px.get((x, row), 0), px.get((x, row + 1), 0)
            if not t and not b:
                ch, col = ' ', None
            elif t and b:
                ch, col = '█', min(t, b, key=lambda c: {2: 0, 1: 1, 3: 2}[c])  # ưu tiên đỏ > trắng > xám
                if t != b:
                    ch, col = ('▀', t) if {2: 0, 1: 1, 3: 2}[t] < {2: 0, 1: 1, 3: 2}[b] else ('▄', b)
            elif t:
                ch, col = '▀', t
            else:
                ch, col = '▄', b
            if col and col != cur:
                out += '$%d' % col
                cur = col
            out += ch
        lines.append(out.rstrip())
    while lines and not lines[0].replace('$1', '').replace('$2', '').replace('$3', '').strip():
        lines.pop(0)
    while lines and not lines[-1].replace('$1', '').replace('$2', '').replace('$3', '').strip():
        lines.pop()
    dst = os.path.join(root, 'build', 'live-build', 'config', 'includes.chroot', 'usr', 'share', 'depot-os',
                       'fastfetch', 'depot-logo.txt')
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    print('ghi', os.path.relpath(dst, root))


def main():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    logo = os.path.join(root, 'design', 'identity', 'logo')
    inc = os.path.join(root, 'build', 'live-build', 'config', 'includes.chroot', 'usr', 'share')
    files = {
        os.path.join(logo, 'depot-logo-tile.svg'): tile(),
        os.path.join(logo, 'depot-logo.svg'): plain(),
        os.path.join(logo, 'depot-logo-mono-white.svg'): mono('#ffffff'),
        os.path.join(logo, 'depot-logo-mono-dark.svg'): mono(DARK),
        os.path.join(logo, 'depot-logo-wordmark.svg'): wordmark(),
        # trong ISO: hộp "Giới thiệu máy này", nút menu thanh trên, icon app Depot (Icon=depot-logo)
        os.path.join(inc, 'pixmaps', 'depot-logo.svg'): tile(),
        os.path.join(inc, 'pixmaps', 'depot-logo-menu.svg'): mono('#ffffff'),
        os.path.join(inc, 'icons', 'hicolor', 'scalable', 'apps', 'depot-logo.svg'): tile(),
    }
    for p, s in files.items():
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'w', encoding='utf-8', newline='\n') as f:
            f.write(s)
        print('ghi', os.path.relpath(p, root))
    # Calamares (Qt) cần PNG: logo ô nền 256 px + ảnh chào (wordmark) — cần rsvg-convert (librsvg2-bin)
    cal = os.path.join(root, 'build', 'live-build', 'config', 'includes.chroot', 'etc', 'calamares', 'branding', 'depot')
    if shutil.which('rsvg-convert') and os.path.isdir(cal):
        for src, dst, arg in ((os.path.join(logo, 'depot-logo-tile.svg'), 'depot-logo.png', ['-w', '256']),
                              (os.path.join(logo, 'depot-logo-wordmark.svg'), 'welcome.png', ['-w', '520'])):
            subprocess.run(['rsvg-convert', *arg, '-o', os.path.join(cal, dst), src], check=True)
            print('ghi', os.path.relpath(os.path.join(cal, dst), root))
    else:
        print('!! bỏ qua PNG cho Calamares (thiếu rsvg-convert)')
    boot_images(root, logo)
    fastfetch_logo(root)


if __name__ == '__main__':
    main()
