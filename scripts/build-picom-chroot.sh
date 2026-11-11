#!/bin/bash
# Depot OS — build picom-animated trực tiếp trong chroot (output trực tiếp)
LB=/root/depot-os/build/live-build
cp /etc/resolv.conf "$LB/chroot/etc/resolv.conf" 2>/dev/null

echo "== c deps còn thiếu:"
chroot "$LB/chroot" apt-get install -y -qq libx11-xcb-dev cmake libxcb-composite0-dev \
  libxcb-randr0-dev libxcb-present-dev libxcb-glx0-dev libxcb-sync-dev \
  libxcb-render-util0-dev libxcb-xinerama0-dev libxkbcommon-x11-dev 2>&1 | tail -1

echo "== clone:"
[ -d "$LB/chroot/tmp/picom-anim/.git" ] || chroot "$LB/chroot" git clone --depth 1 -q https://github.com/pijulius/picom.git /tmp/picom-anim
echo CLONE_OK

echo "== meson:"
chroot "$LB/chroot" /bin/bash -c 'cd /tmp/picom-anim && meson setup build --buildtype=release' 2>&1 | tail -5

echo "== ninja:"
chroot "$LB/chroot" /bin/bash -c 'cd /tmp/picom-anim && ninja -C build' 2>&1 | tail -4

echo "== install:"
chroot "$LB/chroot" install -m 755 /tmp/picom-anim/build/src/picom /usr/bin/picom-animated && echo PICOM_INSTALLED

echo "== WhiteSur trong chroot:"
ls "$LB/chroot/usr/share/themes/" | grep -i whitesur
