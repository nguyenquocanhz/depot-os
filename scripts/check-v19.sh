#!/bin/bash
# Depot OS — kiểm chứng v0.19 (chạy trong WSL Debian, sau ./auto/build): logo "Depot by WrenEvil" (Bóng ma) ở boot,
# menu boot, Calamares; widget + app cảm biến; thanh menu CPU/RAM/mạng, icon desktop, Giới thiệu máy này;
# Dynamic Island; Phiên bản Home/Pro/Workstation; Chế độ pin + Ngủ sâu; Terminal mới.
# Không gọi chuỗi check cũ: check-v12 (execi sensors) và check-v18 (tên mục "Live system") báo trượt giả trên bản này.
LB=/root/depot-os/build/live-build
cd "$LB" || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
chk() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

ISO=live-image-amd64.hybrid.iso
SQ=binary/live/filesystem.squashfs
S=/tmp/sqv19; rm -rf $S
INC=config/includes.chroot
FILES="usr/bin/depot-island usr/bin/depot-edition usr/bin/depot-power usr/bin/depot-powerd usr/bin/depot-about
usr/bin/depot-statusbar usr/bin/depot-hwmon usr/bin/depot-effects usr/bin/depot-update usr/libexec/depot-power-helper
usr/bin/depot-wallpaper-init usr/bin/depot-live-setup usr/bin/depot-dns-proxy usr/libexec/depot-dns-helper"
unsquashfs -f -d $S $SQ var/lib/dpkg/status etc/alternatives etc/skel etc/calamares etc/default/grub etc/xdg/fastfetch \
  etc/xdg/autostart etc/systemd/system etc/udev/rules.d etc/lightdm usr/share/depot-os usr/share/pixmaps usr/share/images/depot usr/share/backgrounds/depot-os \
  usr/share/icons/hicolor/scalable/apps/depot-logo.svg usr/share/polkit-1/actions/tech.wrenevil.depot.power.policy usr/share/polkit-1/actions/tech.wrenevil.depot.dns.policy etc/resolv.conf etc/polkit-1/rules.d etc/NetworkManager \
  usr/share/applications usr/local/share/applications usr/share/plymouth/themes/depot $FILES >/dev/null 2>&1
installed() { awk -v p="$1" '$0 == "Package: " p { f = 1; next } /^Package:/ { f = 0 } f && /^Status: install ok installed/ { ok = 1 } END { exit !ok }' $S/var/lib/dpkg/status; }
same() { cmp -s "$S/$1" "$INC/$1"; }

echo "== ISO:"
chk "ISO tồn tại, đóng sau squashfs (không phải ISO cũ)" "[ -s $ISO ] && [ \$(stat -c %Z $ISO) -ge \$(stat -c %Z $SQ) ]"
echo "  ISO: $(stat -c %s $ISO) byte · squashfs $(du -h $SQ | cut -f1)"
rm -rf /tmp/isov19; mkdir -p /tmp/isov19
xorriso -osirrox on -indev $ISO -extract /boot/grub/grub.cfg /tmp/isov19/grub.cfg -extract /isolinux/live.cfg /tmp/isov19/live.cfg \
  -extract /isolinux/menu.cfg /tmp/isov19/menu.cfg -extract /boot/grub/live-theme/theme.txt /tmp/isov19/theme.txt \
  -extract /boot/grub/splash.png /tmp/isov19/splash.png -extract /isolinux/splash.png /tmp/isov19/isosplash.png >/dev/null 2>&1

echo "== MENU BOOT (logo Bóng ma):"
chk "GRUB: mục đầu = Chạy Depot OS (mặc định), còn Cài tự động + Chẩn đoán" "grep -m1 '^menuentry' /tmp/isov19/grub.cfg | grep -q 'Chạy Depot OS' && grep -q depot.autoinstall /tmp/isov19/grub.cfg && grep -q depot.bootdiag /tmp/isov19/grub.cfg"
chk "GRUB: không còn tên 'Live system'" "! grep -q 'Live system' /tmp/isov19/grub.cfg"
# từ v0.24 ảnh nền là 1280x720 (GRUB co theo chiều cao màn hình, cùng bố cục với Plymouth); trước đó 800x600
chk "GRUB: theme Depot (đếm ngược tiếng Việt) + nền RGB 1280x720 (hoặc 800x600 ở ISO cũ)" "grep -q 'Tự chạy mục đang chọn' /tmp/isov19/theme.txt && file /tmp/isov19/splash.png | grep -qE '(1280 x 720|800 x 600), 8-bit/color RGB'"
chk "isolinux: tiêu đề Depot OS by WrenEvil, mặc định vẫn live-amd64, nền 640x480" "grep -q 'menu title Depot OS by WrenEvil' /tmp/isov19/menu.cfg && awk '/^label /{l=\$2} /menu default/{print l}' /tmp/isov19/live.cfg | grep -qx live-amd64 && file /tmp/isov19/isosplash.png | grep -q '640 x 480'"
chk "hook 1330 đã chạy" "grep -q '>> boot menu: đổi tên mục GRUB' build.log"
# số khung lấy theo FRAMES trong depot.script (v0.19–v0.23: 90 khung; từ v0.24: 70 khung nền trong suốt)
chk "Plymouth: đủ khung logo mới theo depot.script" "n=\$(sed -n 's/^FRAMES = \\([0-9]*\\);.*/\\1/p' $S/usr/share/plymouth/themes/depot/depot.script); [ -n \"\$n\" ] && [ \$(ls $S/usr/share/plymouth/themes/depot/frame-*.png 2>/dev/null | wc -l) = \"\$n\" ]"
chk "GRUB máy đã cài: nền Depot" "grep -q '^GRUB_BACKGROUND=\"/usr/share/images/depot/grub.png\"' $S/etc/default/grub && [ -s $S/usr/share/images/depot/grub.png ]"

echo "== CALAMARES:"
chk "branding depot + hook 0965" "grep -qx 'branding: depot' $S/etc/calamares/settings.conf && [ -s $S/etc/calamares/branding/depot/depot-logo.png ] && [ -s $S/etc/calamares/branding/depot/show.qml ] && grep -q '>> Depot Calamares: branding: depot' build.log"
chk "giữ bootloaderEntryName Debian (Secure Boot)" "grep -q 'bootloaderEntryName: Debian' $S/etc/calamares/branding/depot/branding.desc"
chk "bước depotedition ngay sau depotapps" "grep -A1 '^  - shellprocess@depotapps\$' $S/etc/calamares/settings.conf | grep -q 'shellprocess@depotedition'"
chk "LightDM: ảnh đại diện mặc định = logo" "grep -q 'default-user-image = /usr/share/pixmaps/depot-logo.svg' $S/etc/lightdm/lightdm-gtk-greeter.conf"

echo "== FILE DEPOT (có trong ISO, giống repo, chạy được):"
for f in $FILES; do chk "$f" "[ -x $S/$f ] && same $f"; done
chk "logo: pixmaps + menu + icon hicolor" "[ -s $S/usr/share/pixmaps/depot-logo.svg ] && [ -s $S/usr/share/pixmaps/depot-logo-menu.svg ] && [ -s $S/usr/share/icons/hicolor/scalable/apps/depot-logo.svg ]"
chk "polkit Chế độ pin (không cần mật khẩu khi ngồi máy)" "grep -q '<allow_active>yes</allow_active>' $S/usr/share/polkit-1/actions/tech.wrenevil.depot.power.policy"
chk "phiên bản: 3 bản sẵn + 4 bản lộ trình" "[ \$(grep -l '^STATUS=ready' $S/usr/share/depot-os/editions/*.conf | wc -l) = 3 ] && [ \$(grep -l '^STATUS=planned' $S/usr/share/depot-os/editions/*.conf | wc -l) = 4 ]"
chk "service tinh chỉnh Workstation có, chưa bật" "[ -f $S/etc/systemd/system/depot-edition-tune.service ] && [ ! -e $S/etc/systemd/system/multi-user.target.wants/depot-edition-tune.service ]"
chk "depot-powerd tự chạy (XFCE) + lối tắt Chế độ pin, Phiên bản, Giới thiệu" "[ -f $S/etc/xdg/autostart/depot-powerd.desktop ] && [ -f $S/usr/share/applications/depot-power.desktop ] && [ -f $S/usr/share/applications/depot-edition.desktop ] && [ -f $S/usr/share/applications/depot-about.desktop ]"

echo "== GÓI:"
for p in xfce4-terminal fastfetch fonts-jetbrains-mono xfce4-genmon-plugin lm-sensors iw python3-gi python3-gi-cairo gir1.2-gtk-3.0 conky-all yad; do
    chk "$p" "installed $p"
done

echo "== TERMINAL + GIAO DIỆN (skel):"
K=$S/etc/skel/.config
chk "terminal mặc định = xfce4-terminal" "[ \"\$(readlink $S/etc/alternatives/x-terminal-emulator)\" = /usr/bin/xfce4-terminal.wrapper ]"
chk "skel .bashrc gọi depot.bashrc + fastfetch cấu hình Depot" "grep -q 'depot-os/bash/depot.bashrc' $S/etc/skel/.bashrc && [ -f $S/usr/share/depot-os/bash/depot.bashrc ] && grep -q depot-logo.txt $S/etc/xdg/fastfetch/config.jsonc"
chk "xterm ẩn khỏi menu" "grep -q NoDisplay=true $S/usr/local/share/applications/debian-xterm.desktop"
chk "xfce4-terminal.xml (màu Bóng ma, JetBrains Mono)" "grep -q 'JetBrains Mono' $K/xfce4/xfconf/xfce-perchannel-xml/xfce4-terminal.xml"
chk "thanh menu: genmon depot-statusbar + nút menu logo" "grep -q 'value=\"genmon\"' $K/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml && grep -q depot-logo-menu.svg $K/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml && grep -q 'Command=depot-statusbar' $K/xfce4/panel/genmon-11.rc"
chk "icon Home/Trash ngoài desktop" "grep -q 'show-home' $K/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
chk "widget conky dùng depot-hwmon.lua" "grep -q 'lua_parse depot_hw' $K/conky/conky.conf && [ -f $K/conky/depot-hwmon.lua ]"
chk "i3 chạy depot-powerd" "grep -q 'exec --no-startup-id depot-powerd' $K/i3/config"

echo "== SỬA LỖI v0.19.1:"
chk "hình nền theo tên màn hình: depot-wallpaper-init + autostart XFCE" "[ -x $S/usr/bin/depot-wallpaper-init ] && grep -q 'OnlyShowIn=XFCE' $S/etc/xdg/autostart/depot-wallpaper-init.desktop"
chk "icon Cài Depot OS vào thư mục desktop theo ngôn ngữ (xdg-user-dir)" "grep -q 'xdg-user-dir DESKTOP' $S/usr/bin/depot-live-setup && same usr/bin/depot-live-setup"
chk "Giới thiệu máy này: bỏ dấu phẩy sau tên hãng" "grep -q \"rstrip(',')\" $S/usr/bin/depot-about"
chk "Phiên bản (live): đóng bằng X không bật hộp thông báo" "grep -q '\[ \$rc = 0 \] || \[ \$rc = 3 \]' $S/usr/bin/depot-edition"
chk "hình nền không còn chữ \"Depot OS / Smooth. Beautiful. Yours.\"" "[ -s $S/usr/share/backgrounds/depot-os/wallpaper.svg ] && ! grep -q '<text' $S/usr/share/backgrounds/depot-os/wallpaper.svg"

echo "== DNS MÃ HOÁ (NextDNS / Cloudflare / Quad9 / AdGuard qua DNS-over-TLS):"
chk "gói systemd-resolved có trong ISO" "installed systemd-resolved"
chk "systemd-resolved TẮT sẵn (hook 0450), resolv.conf không trỏ sang stub" "[ ! -e $S/etc/systemd/system/sysinit.target.wants/systemd-resolved.service ] && [ ! -L $S/etc/resolv.conf ] && grep -q '>> systemd-resolved: tắt sẵn' build.log"
chk "depot-dns-helper + polkit (action + rule nhóm sudo/netdev)" "[ -x $S/usr/libexec/depot-dns-helper ] && same usr/libexec/depot-dns-helper && grep -q 'exec.path\">/usr/libexec/depot-dns-helper' $S/usr/share/polkit-1/actions/tech.wrenevil.depot.dns.policy && grep -q tech.wrenevil.depot.dns $S/etc/polkit-1/rules.d/50-depot-dns.rules"
chk "DNS và Proxy có mục NextDNS mã hoá + ô ID" "grep -q 'private:nextdns' $S/usr/bin/depot-dns-proxy && grep -q 'ID NextDNS' $S/usr/bin/depot-dns-proxy"
chk "NetworkManager tự ghi resolv.conf (rc-manager=file) — không thì resolvconf của systemd-resolved làm mất DNS" "grep -qx 'rc-manager=file' $S/etc/NetworkManager/conf.d/10-depot-rc-manager.conf"

echo
echo "== $PASS đạt, $FAIL trượt"
[ $FAIL = 0 ]
