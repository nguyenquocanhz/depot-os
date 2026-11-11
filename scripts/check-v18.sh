#!/bin/bash
# Depot OS — kiểm chứng v0.18 (chạy trong WSL Debian, sau ./auto/build): Boot Diag (depot-bootdiag + mục boot
# "Chẩn đoán phần cứng"), app/widget cảm biến depot-hwmon, và cài tự động (v0.17) vẫn còn.
# Không gọi chuỗi check cũ: check-v12.sh còn grep "execi 10 sensors" mà widget mới đã bỏ (báo trượt giả).
LB=/root/depot-os/build/live-build
cd "$LB" || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
chk() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

ISO=live-image-amd64.hybrid.iso
SQ=binary/live/filesystem.squashfs
S=/tmp/sqv18; rm -rf $S
unsquashfs -f -d $S $SQ var/lib/dpkg/status usr/bin/depot-bootdiag usr/bin/depot-hwmon usr/bin/depot-autoinstall \
  usr/lib/systemd/system/depot-bootdiag.service usr/lib/systemd/system/depot-autoinstall.service \
  etc/systemd/system/multi-user.target.wants usr/share/applications etc/modules-load.d \
  usr/share/depot-os/dotfiles/config/conky usr/sbin/dmidecode usr/bin/lspci >/dev/null 2>&1
installed() { awk -v p="$1" '$0 == "Package: " p { f = 1; next } /^Package:/ { f = 0 } f && /^Status: install ok installed/ { ok = 1 } END { exit !ok }' $S/var/lib/dpkg/status; }
same() { cmp -s "$S/$1" "/root/depot-os/build/live-build/config/includes.chroot/$1"; }
noCR() { ! grep -q $'\r' "$S/$1"; }

echo "== ISO:"
# mtime ISO = SOURCE_DATE_EPOCH (≈ lúc bắt đầu) nên so ctime
chk "ISO tồn tại, đóng sau squashfs (không phải ISO cũ)" "[ -s $ISO ] && [ \$(stat -c %Z $ISO) -ge \$(stat -c %Z $SQ) ]"
rm -rf /tmp/isov18; mkdir -p /tmp/isov18
xorriso -osirrox on -indev $ISO -extract /boot/grub/grub.cfg /tmp/isov18/grub.cfg -extract /isolinux/live.cfg /tmp/isov18/live.cfg >/dev/null 2>&1
chk "file ISO mang mục boot chẩn đoán (GRUB + isolinux)" "grep -q 'depot.bootdiag' /tmp/isov18/grub.cfg && grep -q 'depot.bootdiag' /tmp/isov18/live.cfg"
echo "  ISO: $(stat -c %s $ISO) byte · squashfs $(du -h $SQ | cut -f1)"

echo "== BOOT DIAG:"
chk "depot-bootdiag có trong ISO, chạy được, giống repo, không CRLF" "[ -x $S/usr/bin/depot-bootdiag ] && bash -n $S/usr/bin/depot-bootdiag && same usr/bin/depot-bootdiag && noCR usr/bin/depot-bootdiag"
chk "dmidecode + pciutils + less cài sẵn" "installed dmidecode && installed pciutils && installed less"
chk "service bật, chỉ chạy với depot.bootdiag, trước màn đăng nhập" "[ -L $S/etc/systemd/system/multi-user.target.wants/depot-bootdiag.service ] && grep -qx 'ConditionKernelCommandLine=depot.bootdiag' $S/usr/lib/systemd/system/depot-bootdiag.service && grep -q '^Before=display-manager.service' $S/usr/lib/systemd/system/depot-bootdiag.service"
chk "lối tắt menu ứng dụng" "grep -qx 'Exec=depot-bootdiag --pause' $S/usr/share/applications/depot-bootdiag.desktop"
chk "hook 1320 đã chạy" "grep -q '>> Depot bootdiag: service enabled' build.log"
for f in binary/boot/grub/grub.cfg binary/isolinux/live.cfg; do
    chk "mục boot chẩn đoán trong $(basename $f): 1 mục, không splash, không autoinstall" \
        "[ \$(grep -c 'depot.bootdiag depot.noautoinstall' $f) = 1 ] && ! grep 'depot.bootdiag' $f | grep -qw splash"
done
chk "GRUB: mục Live vẫn đứng đầu (mặc định)" "grep -m1 '^menuentry' binary/boot/grub/grub.cfg | grep -q 'Live system (amd64)'"
chk "isolinux: menu default vẫn là Live" "awk '/^label /{l=\$2} /menu default/{print l}' binary/isolinux/live.cfg | grep -qx live-amd64"
chk "chạy depot-bootdiag trong ISO trên mẫu NEC MS-7770 ra đúng kết luận" \
    "bash /root/depot-os/tools/bootdiag/make-samples.sh /tmp/bdv18 >/dev/null && TERM=xterm bash $S/usr/bin/depot-bootdiag --sample /tmp/bdv18/nec-mate-ms7770-b65 | grep -q 'Intel KHÔNG hỗ trợ Ivy Bridge trên B65'"

echo "== CẢM BIẾN (depot-hwmon):"
chk "lm-sensors, python3-gi, gir1.2-gtk-3.0 cài sẵn" "installed lm-sensors && installed python3-gi && installed gir1.2-gtk-3.0"
chk "app depot-hwmon có trong ISO, giống repo" "[ -x $S/usr/bin/depot-hwmon ] && same usr/bin/depot-hwmon"
chk "widget conky dùng depot-hwmon.lua" "[ -f $S/usr/share/depot-os/dotfiles/config/conky/depot-hwmon.lua ] && grep -q 'lua_load' $S/usr/share/depot-os/dotfiles/config/conky/conky.conf"
chk "nạp drivetemp lúc boot" "grep -qx drivetemp $S/etc/modules-load.d/depot-sensors.conf"

echo "== CÀI TỰ ĐỘNG (v0.17) còn nguyên:"
chk "depot-autoinstall + service + mục boot" "same usr/bin/depot-autoinstall && [ -L $S/etc/systemd/system/multi-user.target.wants/depot-autoinstall.service ] && grep -q 'depot.autoinstall\$' binary/isolinux/live.cfg"

echo
echo "KẾT QUẢ v0.18: $PASS đạt, $FAIL hỏng"
[ $FAIL -eq 0 ]
