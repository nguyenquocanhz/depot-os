#!/bin/bash
# Depot OS — chạy lại hook 1000 trong chroot với sh -x để bắt lỗi gốc
LB=/root/depot-os/build/live-build
cp /etc/resolv.conf "$LB/chroot/etc/resolv.conf" 2>/dev/null
cp "$LB/config/hooks/normal/1000-depot-whitesur.hook.chroot" "$LB/chroot/root/wh.sh"

echo "== môi trường hook (mô phỏng live-build):"
chroot "$LB/chroot" /bin/sh -c 'echo PATH=$PATH; echo HOME=$HOME; ls /usr/bin/bash'

echo "== chạy hook với sh -x:"
chroot "$LB/chroot" /bin/sh -x /root/wh.sh 2>&1 | tail -45
