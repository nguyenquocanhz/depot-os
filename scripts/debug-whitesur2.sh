#!/bin/bash
# Depot OS — debug sâu WhiteSur gtk: OOM? exit code thật?
LB=/root/depot-os/build/live-build

echo 'nameserver 1.1.1.1' > "$LB/chroot/etc/resolv.conf"

echo '== WSL memory:'
free -m | head -2

echo '== dmesg OOM kills gần đây:'
dmesg 2>/dev/null | grep -iE 'killed process|out of memory|oom' | tail -5

echo '== clone + chạy installer trong chroot:'
chroot "$LB/chroot" git clone --depth 1 -q https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/wsg2 && echo "CLONE_OK"

chroot "$LB/chroot" /bin/bash -c 'cd /tmp/wsg2 && bash ./ins*.sh -d /usr/share/themes -c Dark --silent-mode; echo "INSTALL_EXIT=$?"' 2>&1 | tail -25

echo '== kết quả:'
ls "$LB/chroot/usr/share/themes/" | grep -i whitesur || echo '(không có WhiteSur-Dark)'
