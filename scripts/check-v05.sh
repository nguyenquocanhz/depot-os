#!/bin/bash
# Depot OS — kiểm chứng v0.5: chroot + squashfs (chạy trong WSL Debian)
LB=/root/depot-os/build/live-build

echo "== sassc trong chroot:"
ls "$LB/chroot/usr/bin/sassc" 2>&1

echo "== themes trong chroot:"
ls "$LB/chroot/usr/share/themes" 2>&1 | head -8

echo "== icons WhiteSur trong chroot:"
ls "$LB/chroot/usr/share/icons" 2>/dev/null | grep -i whitesur

echo "== resolv.conf trong chroot:"
head -c 100 "$LB/chroot/etc/resolv.conf" 2>&1
echo

echo "== WhiteSur icons trong squashfs:"
unsquashfs -f -d /tmp/sqv6 "$LB/binary/live/filesystem.squashfs" usr/share/icons >/dev/null 2>&1
ls /tmp/sqv6/usr/share/icons 2>/dev/null | grep -i whitesur

echo "== skel trong squashfs:"
unsquashfs -f -d /tmp/sqv6 "$LB/binary/live/filesystem.squashfs" etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml >/dev/null 2>&1
grep -hE 'ThemeName|IconThemeName|CursorThemeName' /tmp/sqv6/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml 2>/dev/null

echo DONE
