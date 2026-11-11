#!/bin/bash
# Depot OS — kiểm chứng v0.12 (chạy trong WSL Debian, sau ./auto/build)
# Chạy check-v11.sh trước (các mục cũ vẫn phải đạt), rồi kiểm phần chống lag
LB=/root/depot-os/build/live-build
cd "$LB" || exit 1
bash /root/depot-os/scripts/check-v11.sh || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
chk() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

S=/tmp/sqv12; rm -rf $S
unsquashfs -f -d $S binary/live/filesystem.squashfs \
  usr/bin/depot-compositor usr/bin/picom-animated usr/bin/picom \
  usr/bin/glxinfo usr/bin/glxinfo.x86_64-linux-gnu \
  etc/xdg/autostart/depot-picom.desktop etc/X11/xorg.conf.d/20-intel.conf \
  usr/bin/depot-plank etc/xdg/autostart/depot-plank.desktop \
  usr/share/glib-2.0/schemas/net.launchpad.plank.gschema.xml \
  etc/skel/.config/i3/config etc/skel/.config/conky etc/skel/.config/picom etc/skel/.config/plank >/dev/null 2>&1

echo "== 7/7 CHỐNG LAG:"
chk "depot-compositor chạy được" "[ -x $S/usr/bin/depot-compositor ]"
chk "depot-compositor cú pháp sh" "sh -n $S/usr/bin/depot-compositor"
chk "depot-compositor không CRLF" "! grep -q \$'\r' $S/usr/bin/depot-compositor"
# glxinfo là symlink tương đối -> glxinfo.x86_64-linux-gnu: phải giải nén cả hai, không thì [ -x ] báo hỏng nhầm
chk "glxinfo (để auto dò renderer)" "[ -x $S/usr/bin/glxinfo ]"
chk "picom + picom-animated" "[ -x $S/usr/bin/picom ] && [ -x $S/usr/bin/picom-animated ]"
chk "XFCE autostart gọi depot-effects apply (từ v0.14)" "grep -qx 'Exec=depot-effects apply' $S/etc/xdg/autostart/depot-picom.desktop"
chk "i3 gọi depot-effects apply (từ v0.14)" "grep -q 'exec --no-startup-id depot-effects apply' $S/etc/skel/.config/i3/config"
chk "i3 không gọi picom trực tiếp" "! grep -q 'exec --no-startup-id picom' $S/etc/skel/.config/i3/config"
chk "Intel TearFree tắt" "grep -q '\"TearFree\" *\"false\"' $S/etc/X11/xorg.conf.d/20-intel.conf"
chk "Conky đọc nhiệt độ 10 giây/lần" "grep -rq 'execi 10 sensors' $S/etc/skel/.config/conky"
chk "skel có picom-animations.conf (gốc của depot-effects)" "[ -f $S/etc/skel/.config/picom/picom-animations.conf ]"
chk "depot-compositor (tên cũ) chuyển sang depot-effects" "grep -q 'exec depot-effects apply' $S/usr/bin/depot-compositor"

echo "== DOCK (Plank đọc gsettings, không đọc file settings):"
chk "depot-plank chạy được, cú pháp sh" "[ -x $S/usr/bin/depot-plank ] && sh -n $S/usr/bin/depot-plank"
chk "XFCE autostart gọi depot-plank" "grep -qx 'Exec=depot-plank' $S/etc/xdg/autostart/depot-plank.desktop"
chk "depot-plank đặt hide-mode auto" "grep -q 'hide-mode auto' $S/usr/bin/depot-plank"
chk "schema Plank có key hide-mode" "grep -q 'name=\"hide-mode\"' $S/usr/share/glib-2.0/schemas/net.launchpad.plank.gschema.xml"
chk "skel không còn file plank settings vô dụng" "[ ! -e $S/etc/skel/.config/plank/dock1/settings ]"

echo
echo "KẾT QUẢ v0.12 (phần mới): $PASS đạt, $FAIL hỏng"
[ $FAIL -eq 0 ]
