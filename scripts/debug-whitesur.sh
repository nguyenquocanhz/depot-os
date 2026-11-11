#!/bin/bash
# Depot OS — bắt lỗi WhiteSur gtk installer bằng bash -x trong chroot
LB=/root/depot-os/build/live-build

echo 'nameserver 1.1.1.1' > "$LB/chroot/etc/resolv.conf"
chroot "$LB/chroot" git clone --depth 1 -q https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/wsg 2>&1 | tail -2
echo "CLONE_EXIT=$?"

# đổi tên để chạy trace (đổi tên nội bộ, không thay đổi repo)
chroot "$LB/chroot" /bin/bash -c 'cd /tmp/wsg && cp ins*.sh runner.sh && bash -x ./runner.sh -d /tmp/wsgout -c Dark --tweaks solid' 2>&1 | tail -30
echo "RUN_EXIT=$?"
