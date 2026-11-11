#!/bin/bash
# Depot OS — cài WhiteSur (gtk + icons + cursors) trên HOST vào staging rồi vendor ra includes
# (gtk installer thất bại âm thầm trong chroot-hook — làm trên host 1 lần, kết quả thành file tĩnh)
set -e
STAGE=/root/staging
DEST=/mnt/d/SteathOS/depot-os/build/live-build/config/includes.chroot/usr/share
mkdir -p "$STAGE/themes" "$STAGE/icons" "$DEST/themes" "$DEST/icons"

apt-get install -y -qq sassc libglib2.0-dev-bin libxml2-utils git >/dev/null 2>&1

echo "== GTK theme:"
[ -d /tmp/wsgtk ] || git clone --depth 1 -q https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/wsgtk
cd /tmp/wsgtk && cp ins*.sh run.sh && bash run.sh -d "$STAGE/themes" -c Dark --silent-mode 2>&1 | tail -3

echo "== Icons:"
[ -d /tmp/wsicons ] || git clone --depth 1 -q https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/wsicons
cd /tmp/wsicons && cp ins*.sh run.sh && bash run.sh -d "$STAGE/icons" 2>&1 | tail -2

echo "== Cursors:"
[ -d /tmp/wscursors ] || git clone --depth 1 -q https://github.com/vinceliuice/WhiteSur-cursors.git /tmp/wscursors
cd /tmp/wscursors && cp ins*.sh run.sh && bash run.sh -d "$STAGE/icons" 2>&1 | tail -2

echo "== Kết quả staging:"
ls "$STAGE/themes" | head -8
ls "$STAGE/icons" | grep -i whitesur
