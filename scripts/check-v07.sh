#!/bin/bash
# Depot OS — kiểm chứng v0.7: 4 tiêu chí xanh = ISO rice macOS hoàn chỉnh
LB=/root/depot-os/build/live-build
cd "$LB" || exit 1

PASS=0; FAIL=0
ok()   { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad()  { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

echo "== ISO:"
ls -la live-image-amd64.hybrid.iso; tail -1 build.log

echo "== 1/4 BOOTMENU:"
grep '^timeout' binary/isolinux/isolinux.cfg
grep 'set timeout' binary/boot/grub/config.cfg 2>/dev/null
grep -q '^timeout 80' binary/isolinux/isolinux.cfg && ok "BIOS timeout 80" || bad "BIOS timeout"
grep -q 'set timeout=10' binary/boot/grub/config.cfg 2>/dev/null && ok "EFI timeout 10" || bad "EFI timeout"

echo "== 2/4 WHITESUR:"
ls chroot/usr/share/themes 2>/dev/null | grep -i whitesur
[ -d chroot/usr/share/themes/WhiteSur-Dark ] && ok "WhiteSur-Dark GTK trong chroot" || bad "WhiteSur-Dark GTK"
grep -E 'WhiteSur GTK|WhiteSur không cài đủ' build.log | tail -2

echo "== 3/4 SKEL trong squashfs:"
unsquashfs -f -d /tmp/sqv8 binary/live/filesystem.squashfs \
  etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
  etc/skel/.config/plank/dock1/settings \
  usr/bin/picom-animated usr/bin/localsend >/dev/null 2>&1
X=/tmp/sqv8/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
grep -h 'ThemeName' "$X" 2>/dev/null
grep -q 'WhiteSur-Dark' "$X" 2>/dev/null && ok "skel xsettings = WhiteSur-Dark" || bad "skel xsettings"
[ -f /tmp/sqv8/etc/skel/.config/plank/dock1/settings ] && ok "plank settings trong skel" || bad "plank settings"
[ -x /tmp/sqv8/usr/bin/picom-animated ] && ok "picom-animated trong ISO" || bad "picom-animated"
[ -x /tmp/sqv8/usr/bin/localsend ] && ok "localsend trong ISO" || bad "localsend"

echo "== 4/4 HOOK OUTPUT:"
grep -E '>> WhiteSur|>> picom-animated|>> LocalSend|!! WhiteSur|!! picom|!! LocalSend' build.log | tail -6

echo "== TONG KET: PASS=$PASS FAIL=$FAIL"
echo DONE
