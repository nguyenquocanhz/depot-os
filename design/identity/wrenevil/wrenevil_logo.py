#!/usr/bin/env python3
# Depot OS — logo "Depot by WrenEvil" (phương án 1 "Bóng ma", chọn 08/11/2026): vô tung vô ảnh như quỷ dữ.
# Chữ D của Depot đặc ở thân, tan dần sang phải như bóng ma đang biến mất; hai sừng (sừng sau mờ); mắt đỏ trong lòng D.
# By WrenEvil.tech & nguyenquocanhz (nqatech)
#
# Một nguồn hình học cho mọi nơi: file logo (design/identity/logo/), icon trong ISO, ảnh + theme menu boot (GRUB của ISO,
# GRUB máy đã cài, isolinux), animation Plymouth (scripts/gen-boot-video.py) — các màn boot dùng chung BỐ CỤC ở dưới.
#   python3 design/identity/wrenevil/wrenevil_logo.py      ghi lại các file logo + bản sao trong includes.chroot
#   python3 scripts/gen-boot-video.py                      rồi sinh lại animation Plymouth cho khớp (chạy trong WSL)
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


# ---- BỐ CỤC CHUNG của mọi màn boot: menu GRUB của ISO, menu GRUB máy đã cài, isolinux, animation Plymouth.
# Mọi số đo tính theo CHIỀU CAO màn hình H, canh giữa theo chiều ngang → logo, chữ và quầng đỏ đứng nguyên một chỗ,
# cùng một cỡ khi máy chuyển từ menu boot sang animation (trước v0.24: menu để logo sát trên + chữ + quầng đỏ, còn
# animation để logo giữa màn, cỡ tính bằng pixel, nền phẳng, không chữ, lại bắt đầu từ màn đen).
# scripts/gen-boot-video.py đọc các số này để sinh theme Plymouth; theme GRUB để menu bắt đầu ở BOOT_MENU_TOP.
BOOT_LOGO = 0.2133      # cạnh hộp logo (hộp 160 đơn vị) / H — 128 px ở màn 600
BOOT_TOP = 0.11         # mép trên hộp logo / H
BOOT_HALO_CY = 0.55     # tâm quầng đỏ: dưới mép trên hộp logo 0.55 cạnh
BOOT_HALO_R = 2.2       # bán kính quầng đỏ = 2.2 cạnh logo
BOOT_HALO_OP = 0.10     # độ đậm quầng đỏ ở tâm
BOOT_WORD_Y = 0.28      # chân chữ DEPOT: dưới đáy hộp logo 0.28 cạnh
BOOT_WORD_FS = 0.2      # cỡ chữ DEPOT / cạnh logo
BOOT_WORD_BOX = (2.0, 0.625)  # hộp chứa hai dòng chữ (rộng, cao) / cạnh logo — ảnh wordmark.png của Plymouth (512x160)
BOOT_MENU_TOP = 0.50    # menu (GRUB) hoặc thanh tiến trình (Plymouth) bắt đầu ở đây / H


def word(cx, base, L):
    """Hai dòng chữ dưới logo: DEPOT + by WrenEvil. cx = tâm ngang, base = đáy hộp logo, L = cạnh hộp logo (px)."""
    fs = L * BOOT_WORD_FS
    y = base + L * BOOT_WORD_Y
    return ('<text x="{x:.2f}" y="{y:.2f}" text-anchor="middle" font-family="Inter, sans-serif" font-weight="800" '
            'font-size="{f:.2f}" letter-spacing="{ls:.2f}" fill="{fg}">DEPOT</text>'
            '<text x="{x:.2f}" y="{y2:.2f}" text-anchor="middle" font-family="Inter, sans-serif" font-size="{f2:.2f}" '
            'letter-spacing="{ls2:.2f}" fill="#8a90a2">by Wren<tspan fill="{red}">Evil</tspan></text>'
            ).format(x=cx, y=y, y2=y + fs * 0.95, f=fs, f2=fs * 0.5, ls=fs * 0.16, ls2=fs * 0.04, fg=FG, red=RED)


def halo_stops():
    return ('<stop offset="0" stop-color="{red}" stop-opacity="{op}"/><stop offset="1" stop-color="{red}" '
            'stop-opacity="0"/>').format(red=RED, op=BOOT_HALO_OP)


def boot_bg(w, h, title=True, corner=False, logo=None):
    """Nền menu boot: đen + quầng đỏ rất mờ + logo. Mặc định theo BỐ CỤC CHUNG (logo giữa, phần trên màn hình);
    corner=True: logo góc dưới phải — ảnh nền dự phòng của GRUB máy đã cài khi không nạp được theme."""
    if corner:
        L = logo
        lx, ly = w - L - 48, h - L - 40
    else:
        L = logo or h * BOOT_LOGO
        lx, ly = (w - L) / 2, h * BOOT_TOP
    s = L / 160.0
    glow_cx, glow_cy = lx + L / 2, ly + L * BOOT_HALO_CY
    text = ''
    if title and not corner:
        text = word(lx + L / 2, ly + L, L)
    elif title:
        fs = max(14, L * 0.2)
        ty = ly + L * 0.62
        text = ('<text x="{x:.0f}" y="{y:.0f}" text-anchor="end" font-family="Inter, sans-serif" font-weight="800" '
                'font-size="{f:.0f}" letter-spacing="{ls:.1f}" fill="{fg}">DEPOT</text>'
                '<text x="{x:.0f}" y="{y2:.0f}" text-anchor="end" font-family="Inter, sans-serif" font-size="{f2:.0f}" '
                'letter-spacing="1" fill="#8a90a2">by Wren<tspan fill="{red}">Evil</tspan></text>'
                ).format(x=lx - 18, y=ty, y2=ty + fs * 0.95, f=fs, f2=fs * 0.5, ls=fs * 0.16, fg=FG, red=RED)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            '<defs>{d}<radialGradient id="halo" gradientUnits="userSpaceOnUse" cx="{gx:.2f}" cy="{gy:.2f}" r="{gr:.2f}">'
            '{st}</radialGradient></defs><rect width="{w}" height="{h}" fill="{bg}"/>'
            '<rect width="{w}" height="{h}" fill="url(#halo)"/>'
            '<g transform="translate({lx:.2f} {ly:.2f}) scale({s:.5f})">{m}</g>{t}</svg>\n'
            ).format(w=w, h=h, d=defs(), gx=glow_cx, gy=glow_cy, gr=L * BOOT_HALO_R, st=halo_stops(), bg=BG,
                     lx=lx, ly=ly, s=s, m=mark(), t=text)


def plymouth_assets(theme, ref=256):
    """Phần đứng yên của animation Plymouth, cùng hình với ảnh menu boot: quầng đỏ (halo.png) và hai dòng chữ
    (wordmark.png), PNG nền trong suốt vẽ cho logo cạnh `ref` px — depot.script co giãn theo màn hình."""
    bw, bh = BOOT_WORD_BOX
    jobs = {
        'halo.png': ('<svg xmlns="http://www.w3.org/2000/svg" width="{r}" height="{r}" viewBox="0 0 {r} {r}"><defs>'
                     '<radialGradient id="halo" gradientUnits="userSpaceOnUse" cx="{c}" cy="{c}" r="{c}">{st}'
                     '</radialGradient></defs><rect width="{r}" height="{r}" fill="url(#halo)"/></svg>\n'
                     ).format(r=ref, c=ref / 2.0, st=halo_stops()),
        'wordmark.png': ('<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0f}" height="{h:.0f}" '
                         'viewBox="0 0 {w:.0f} {h:.0f}">{t}</svg>\n'
                         ).format(w=ref * bw, h=ref * bh, t=word(ref * bw / 2.0, 0, ref)),
    }
    for name, svg_s in jobs.items():
        tmp = os.path.join(theme, '.' + name + '.svg')
        with open(tmp, 'w', encoding='utf-8') as f:
            f.write(svg_s)
        subprocess.run(['rsvg-convert', '-o', os.path.join(theme, name), tmp], check=True)
        os.remove(tmp)
        print('ghi', os.path.join(os.path.basename(theme), name))


def grub_theme_installed(root):
    """Theme GRUB cho MÁY ĐÃ CÀI (/boot/grub/themes/depot, /etc/default/grub: GRUB_THEME): cùng ảnh nền, cùng bố cục
    với theme menu của ISO — chỉ khác đường dẫn ảnh (theme của ISO nằm trong live-theme/, ảnh ở thư mục cha)."""
    lb = os.path.join(root, 'build', 'live-build', 'config')
    src = os.path.join(lb, 'includes.binary', 'boot', 'grub')
    dst = os.path.join(lb, 'includes.chroot', 'boot', 'grub', 'themes', 'depot')
    os.makedirs(dst, exist_ok=True)
    shutil.copyfile(os.path.join(src, 'splash.png'), os.path.join(dst, 'splash.png'))
    for part in ('c', 'n', 's', 'e', 'w', 'ne', 'nw', 'se', 'sw'):
        shutil.copyfile(os.path.join(src, 'live-theme', 'select_%s.png' % part), os.path.join(dst, 'select_%s.png' % part))
    with open(os.path.join(src, 'live-theme', 'theme.txt'), encoding='utf-8') as f:
        txt = f.read()
    assert 'desktop-image: "../splash.png"' in txt
    body = txt.split('\n', 4)[4] if txt.startswith('#') else txt
    head = ('# Depot OS — theme menu GRUB của MÁY ĐÃ CÀI: cùng ảnh nền, cùng bố cục với menu boot của ISO và animation\n'
            '# Plymouth (logo "Depot by WrenEvil" đứng nguyên một chỗ từ menu sang animation).\n'
            '# FILE SINH RA bởi design/identity/wrenevil/wrenevil_logo.py từ includes.binary/boot/grub/live-theme/theme.txt\n'
            '# — sửa file đó rồi chạy lại script. Bật bằng GRUB_THEME trong /etc/default/grub.\n')
    with open(os.path.join(dst, 'theme.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(head + body.replace('desktop-image: "../splash.png"', 'desktop-image: "splash.png"'))
    print('ghi', os.path.relpath(dst, root) + '/ (theme.txt, splash.png, select_*.png)')


def boot_images(root, logo):
    """Ảnh menu boot: GRUB của ISO và của máy đã cài (1280x720, GRUB co theo chiều cao màn hình), isolinux BIOS
    (640x480), ảnh nền dự phòng của GRUB máy đã cài (1920x1080, logo ở góc)."""
    if not (shutil.which('rsvg-convert') and shutil.which('convert')):
        print('!! bỏ qua ảnh menu boot (thiếu rsvg-convert / convert)')
        return
    lb = os.path.join(root, 'build', 'live-build', 'config')
    jobs = [
        # menu GRUB: ảnh 16:9, theme đặt desktop-image-scale-method "fitheight" → mọi tỉ lệ màn hình đều giữ đúng
        # bố cục theo chiều cao; boot_menu bắt đầu ở BOOT_MENU_TOP
        (boot_bg(1280, 720), os.path.join(lb, 'includes.binary', 'boot', 'grub', 'splash.png')),
        # isolinux (vesamenu 640x480 cố định): cùng tỉ lệ, không chữ (chữ đã có ở tiêu đề menu, menu vshift 12 dòng ≈ y 192)
        (boot_bg(640, 480, title=False), os.path.join(lb, 'includes.binary', 'isolinux', 'splash.png')),
        # GRUB máy đã cài, khi KHÔNG nạp được theme: chữ menu chạy từ góc trên trái → logo góc dưới phải
        (boot_bg(1920, 1080, corner=True, logo=180), os.path.join(lb, 'includes.chroot', 'usr', 'share', 'images',
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
    grub_theme_installed(root)


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
