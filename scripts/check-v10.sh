#!/bin/bash
# Depot OS — kiểm chứng v0.10 (chạy trong WSL Debian)
LB=/root/depot-os/build/live-build
cd "$LB" || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

echo "== ISO:"
ls -la live-image-amd64.hybrid.iso
tail -1 build.log

echo "== 1/5 BOOTMENU:"
grep -q '^timeout 80' binary/isolinux/isolinux.cfg && ok "BIOS timeout 80" || bad "BIOS timeout"
grep -q 'set timeout=10' binary/boot/grub/config.cfg 2>/dev/null && ok "EFI timeout 10" || bad "EFI timeout"

echo "== 2/5 WHITESUR GTK trong squashfs:"
unsquashfs -f -d /tmp/sqv10 binary/live/filesystem.squashfs \
  usr/share/themes/WhiteSur-Dark/index.theme \
  usr/share/themes/WhiteSur-Dark/xfwm4/themerc \
  usr/bin/picom-animated usr/bin/localsend \
  etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
  etc/skel/.config/plank/dock1/settings \
  etc/skel/.config/conky/conky.conf >/dev/null 2>&1
[ -f /tmp/sqv10/usr/share/themes/WhiteSur-Dark/index.theme ] && ok "WhiteSur-Dark GTK theme" || bad "WhiteSur-Dark GTK theme"
[ -f /tmp/sqv10/usr/share/themes/WhiteSur-Dark/xfwm4/themerc ] && ok "WhiteSur xfwm4 theme" || bad "WhiteSur xfwm4"

echo "== 3/5 PICOM + LOCALSEND:"
[ -x /tmp/sqv10/usr/bin/picom-animated ] && ok "picom-animated (fork animation)" || bad "picom-animated"
[ -x /tmp/sqv10/usr/bin/localsend ] && ok "localsend" || bad "localsend"

echo "== 4/5 SKEL rice:"
grep -q 'WhiteSur-Dark' /tmp/sqv10/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml 2>/dev/null && ok "skel xsettings WhiteSur" || bad "skel xsettings"
[ -f /tmp/sqv10/etc/skel/.config/plank/dock1/settings ] && ok "skel plank" || bad "skel plank"
[ -f /tmp/sqv10/etc/skel/.config/conky/conky.conf ] && ok "skel conky widget" || bad "skel conky"

echo "== 5/5 ICONS:"
unsquashfs -f -d /tmp/sqv10 binary/live/filesystem.squashfs usr/share/icons/WhiteSur/index.theme >/dev/null 2>&1
[ -f /tmp/sqv10/usr/share/icons/WhiteSur/index.theme ] && ok "WhiteSur icons" || bad "WhiteSur icons"

echo "== TONG KET: PASS=$PASS FAIL=$FAIL"
echo DONE
