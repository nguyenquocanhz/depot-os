#!/bin/bash
# Depot OS — compile picom-animated trong chroot rồi VENDOR binary ra includes
# (hook environment thất bại âm thầm với compile nặng — làm tay 1 lần, kết quả thành file tĩnh)
LB=/root/depot-os/build/live-build
DEST=/mnt/d/SteathOS/depot-os/build/live-build/config/includes.chroot/usr/bin
cp /etc/resolv.conf "$LB/chroot/etc/resolv.conf" 2>/dev/null

echo "== deps:"
mkdir -p "$DEST"
chroot "$LB/chroot" apt-get install -y -qq meson ninja-build libev-dev libx11-xcb-dev \
  libxcb-damage0-dev libxcb-composite0-dev libxcb-randr0-dev libxcb-present-dev \
  libxcb-glx0-dev libxcb-sync-dev libxcb-render-util0-dev libxcb-xinerama0-dev \
  libxkbcommon-x11-dev libxkbcommon-dev libxcb-xkb-dev libxcb-cursor-dev \
  libconfig-dev libdrm-dev libpixman-1-dev libepoxy-dev cmake libdbus-1-dev 2>&1 | tail -1

echo "== clone:"
chroot "$LB/chroot" git clone --depth 1 -q https://github.com/pijulius/picom.git /tmp/picom-anim && echo CLONE_OK

echo "== meson:"
chroot "$LB/chroot" /bin/bash -c 'cd /tmp/picom-anim && meson setup build --buildtype=release' 2>&1 | tail -3

echo "== ninja:"
chroot "$LB/chroot" /bin/bash -c 'cd /tmp/picom-anim && ninja -C build' 2>&1 | tail -3

echo "== vendor binary ra includes:"
chroot "$LB/chroot" install -m 755 /tmp/picom-anim/build/src/picom /usr/bin/picom-animated
cp "$LB/chroot/usr/bin/picom-animated" "$DEST/picom-animated" && echo VENDORED:
ls -la "$DEST/picom-animated"
"$DEST/picom-animated" --version 2>&1 | head -1
