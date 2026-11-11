#!/bin/bash
# Depot OS — kiểm chứng v0.6 (chạy trong WSL Debian)
LB=/root/depot-os/build/live-build
cd "$LB" || exit 1

echo "== ISO:"
ls -la live-image-amd64.hybrid.iso
tail -1 build.log

echo "== BOOTMENU hook debug:"
grep -E 'bootmenu hook|bootmenu: đã patch' build.log
echo "-- isolinux.cfg hiện tại:"
grep '^timeout' binary/isolinux/isolinux.cfg
echo "-- grub timeout:"
grep 'set timeout' binary/boot/grub/config.cfg 2>/dev/null || echo '(không có)'

echo "== WHITESUR:"
grep -E 'WhiteSur GTK|WhiteSur không cài đủ' build.log
ls chroot/usr/share/themes 2>/dev/null | grep -i whitesur
unsquashfs -f -d /tmp/sqv7 binary/live/filesystem.squashfs \
  etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
  usr/share/depot-os/whitesur-gtk.log >/dev/null 2>&1
echo "-- skel xsettings trong squashfs:"
grep -hE 'ThemeName|IconThemeName|CursorThemeName' /tmp/sqv7/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml 2>/dev/null
echo "-- whitesur-gtk.log (nếu fail):"
head -15 /tmp/sqv7/usr/share/depot-os/whitesur-gtk.log 2>/dev/null || echo '(không có log = gtk cài thành công)'

echo "== PICOM/LOCALSEND:"
unsquashfs -f -d /tmp/sqv7 binary/live/filesystem.squashfs usr/bin/picom-animated usr/bin/localsend >/dev/null 2>&1
ls /tmp/sqv7/usr/bin/picom-animated /tmp/sqv7/usr/bin/localsend 2>&1 | head -2

echo DONE
