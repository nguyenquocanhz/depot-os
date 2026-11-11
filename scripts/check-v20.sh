#!/bin/bash
# Depot OS — kiểm chứng v0.20 (chạy trong WSL Debian, sau ./auto/build): sửa driver Wi-Fi/LAN (pkexec không bị gỡ sau khi
# cài, kho driver offline, depot-drivers mới), album 5 hình nền + "Hình nền", "Ngôn ngữ và ngày giờ" (ngôn ngữ, múi giờ,
# đồng bộ giờ với time.windows.com). Chạy thêm scripts/check-v19.sh cho phần cũ.
LB=${LB:-/root/depot-os/build/live-build}
cd "$LB" || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
chk() { if eval "$2" 2>/dev/null; then ok "$1"; else bad "$1"; fi; }

ISO=live-image-amd64.hybrid.iso
SQ=binary/live/filesystem.squashfs
S=/tmp/sqv20; rm -rf $S
INC=config/includes.chroot
FILES="usr/bin/depot-drivers usr/bin/depot-wallpaper usr/bin/depot-region usr/libexec/depot-region-helper
usr/libexec/depot-power-helper usr/bin/depot-wallpaper-init usr/bin/depot-update"
unsquashfs -f -d $S $SQ var/lib/dpkg/status var/lib/apt/extended_states etc/skel etc/default/locale etc/locale.conf \
  etc/locale.gen etc/systemd/timesyncd.conf.d etc/polkit-1/rules.d etc/lightdm usr/share/depot-os/driver-pool \
  etc/NetworkManager/dispatcher.d/90-depot-timesync etc/udev/rules.d etc/systemd/system/graphical.target.wants \
  usr/lib/systemd/system/depot-drivers-auto.service \
  usr/share/backgrounds/depot-os usr/share/applications usr/share/polkit-1/actions/tech.wrenevil.depot.region.policy \
  $FILES >/dev/null 2>&1
installed() { awk -v p="$1" '$0 == "Package: " p { f = 1; next } /^Package:/ { f = 0 } f && /^Status: install ok installed/ { ok = 1 } END { exit !ok }' $S/var/lib/dpkg/status; }
manual() { ! awk -v p="$1" '$0 == "Package: " p { f = 1; next } /^Package:/ { f = 0 } f && /^Auto-Installed: 1/ { a = 1 } END { exit !a }' $S/var/lib/apt/extended_states; }
same() { cmp -s "$S/$1" "$INC/$1"; }

echo "== ISO:"
chk "ISO tồn tại, đóng sau squashfs (không phải ISO cũ)" "[ -s $ISO ] && [ \$(stat -c %Z $ISO) -ge \$(stat -c %Z $SQ) ]"
echo "  ISO: $(stat -c %s $ISO) byte · squashfs $(du -h $SQ | cut -f1)"

echo "== FILE DEPOT (có trong ISO, giống repo, chạy được):"
for f in $FILES; do chk "$f" "[ -x $S/$f ] && same $f"; done

echo "== DRIVER WI-FI / LAN:"
chk "pkexec có trong ISO và là gói cài tay (autoremove không gỡ)" "installed pkexec && manual pkexec"
# đúng lệnh bước 'packages' của Calamares: gỡ gói live + calamares-settings-debian rồi autoremove --purge
PURGED=$(apt-get -s -o Dir::State=$S/var/lib/apt -o Dir::State::status=$S/var/lib/dpkg/status -o Dir::Cache=/tmp/sqv20-cache \
    -o Dir::Etc::sourcelist=/dev/null -o Dir::Etc::sourceparts=/dev/null -o Debug::NoLocking=1 --purge --auto-remove remove \
    live-boot live-boot-doc live-config live-config-doc live-config-systemd live-tools calamares-settings-debian 2>/dev/null | awk '/^Purg/ { print $2 }')
chk "mô phỏng bước gỡ gói của Calamares: pkexec, mokutil, usb-modeswitch, network-manager, wpasupplicant còn nguyên" \
    "[ -n \"\$PURGED\" ] && ! echo \"\$PURGED\" | grep -qxE 'pkexec|mokutil|usb-modeswitch|network-manager|wpasupplicant|firmware-.*|gcc|make|dkms'"
echo "  (Calamares sẽ gỡ: $(echo $PURGED))"
for p in mokutil usb-modeswitch wpasupplicant network-manager firmware-iwlwifi firmware-realtek firmware-atheros firmware-brcm80211 firmware-mediatek gcc make; do
    chk "gói $p" "installed $p"
done
KV=$(ls binary/live/vmlinuz-* 2>/dev/null | sed 's|.*/vmlinuz-||' | head -1)
P=$S/usr/share/depot-os/driver-pool
chk "kho driver offline làm cho đúng kernel của ISO ($KV)" "[ -n \"$KV\" ] && [ \"\$(cat $P/kernel 2>/dev/null)\" = \"$KV\" ]"
chk "kho: dkms + linux-headers-$KV (hoặc header đã cài sẵn)" "ls $P/base/dkms_*.deb >/dev/null 2>&1 && { ls $P/base/linux-headers-${KV}_*.deb >/dev/null 2>&1 || installed linux-headers-$KV; }"
chk "kho: broadcom-sta-dkms + r8168-dkms" "ls $P/drivers/broadcom-sta-dkms_*.deb >/dev/null 2>&1 && ls $P/drivers/r8168-dkms_*.deb >/dev/null 2>&1"
chk "broadcom-sta-dkms / r8168-dkms KHÔNG cài sẵn (chúng chặn b43, bcma, r8169)" "! installed broadcom-sta-dkms && ! installed r8168-dkms"
chk "hook 1240 đã chạy" "grep -q '>> Depot driver pool:' build.log"
echo "  kho: $(du -sh $P 2>/dev/null | cut -f1), $(ls $P/base 2>/dev/null | wc -l) gói nền"
chk "depot-drivers: cài header kernel đang chạy, kho offline, sửa mạng, báo cáo" "grep -q 'ensure_headers' $S/usr/bin/depot-drivers && grep -q 'driver-pool' $S/usr/bin/depot-drivers && grep -q '^repair()' $S/usr/bin/depot-drivers && grep -q '^report()' $S/usr/bin/depot-drivers"
chk "Chế độ pin không cho card mạng USB ngủ" "grep -qF 'TRỪ card mạng USB' $S/usr/libexec/depot-power-helper"

echo "== TỰ ĐỘNG CÀI / CẬP NHẬT DRIVER (v0.20.2):"
chk "depot-drivers có lệnh auto, auto-set, nút Tự động" "grep -q '^auto_run()' $S/usr/bin/depot-drivers && grep -q '^auto_set()' $S/usr/bin/depot-drivers && grep -q 'Tự động: Bật' $S/usr/bin/depot-drivers"
R=$S/etc/udev/rules.d/91-depot-drivers-auto.rules
chk "udev: cắm USB → hẹn depot-drivers auto (giống repo, quyền 644)" "cmp -s $R $INC/etc/udev/rules.d/91-depot-drivers-auto.rules && [ \"\$(stat -c %a $R)\" = 644 ] && grep -q 'depot-drivers auto' $R"
chk "depot-drivers-auto.service bật lúc khởi động (cùng depot-drivers-scan)" "[ -L $S/etc/systemd/system/graphical.target.wants/depot-drivers-auto.service ] && [ -L $S/etc/systemd/system/graphical.target.wants/depot-drivers-scan.service ] && grep -q 'depot-drivers auto --boot' $S/usr/lib/systemd/system/depot-drivers-auto.service"
chk "depot-update mỗi ngày gọi depot-drivers auto" "grep -q 'depot-drivers auto' $S/usr/bin/depot-update"
chk "hook 0970 đã bật cả hai service" "grep -q '>> Depot drivers: scan enabled, auto enabled, udev 644' build.log"

echo "== HÌNH NỀN (album 5 tấm):"
B=$S/usr/share/backgrounds/depot-os
chk "5 tấm SVG + album.list 5 dòng" "[ \$(ls $B/*.svg | wc -l) = 5 ] && [ \$(grep -vc '^#' $B/album.list) = 5 ]"
album_ok() {
    grep -v '^#' $B/album.list 2>/dev/null | cut -d'|' -f1 | { n=0; while read -r f; do
        [ -s "$B/$f" ] && ! grep -q '<text' "$B/$f" || return 1; n=$((n+1)); done; [ $n -gt 0 ]; }
}
chk "mọi tấm trong album.list đều có file, không tấm nào có chữ" "album_ok"
chk "không còn wallpaper.png (i3 dùng depot-wallpaper --restore)" "[ ! -e $B/wallpaper.png ] && grep -q 'depot-wallpaper --restore' $S/etc/skel/.config/i3/config"
chk "LightDM vẫn trỏ wallpaper.svg" "grep -q 'background = /usr/share/backgrounds/depot-os/wallpaper.svg' $S/etc/lightdm/lightdm-gtk-greeter.conf"
chk "lối tắt Hình nền" "grep -q '^Exec=depot-wallpaper' $S/usr/share/applications/depot-wallpaper.desktop"
chk "depot-wallpaper đúng cú pháp Python" "python3 -m py_compile $S/usr/bin/depot-wallpaper"

echo "== NGÔN NGỮ VÀ NGÀY GIỜ:"
chk "lối tắt + polkit (action + rule nhóm sudo)" "grep -q '^Exec=depot-region' $S/usr/share/applications/depot-region.desktop && grep -q 'exec.path\">/usr/libexec/depot-region-helper' $S/usr/share/polkit-1/actions/tech.wrenevil.depot.region.policy && grep -q tech.wrenevil.depot.region $S/etc/polkit-1/rules.d/50-depot-region.rules"
chk "đồng bộ giờ: time.windows.com + dự phòng Debian" "grep -qx 'NTP=time.windows.com 0.debian.pool.ntp.org 1.debian.pool.ntp.org' $S/etc/systemd/timesyncd.conf.d/50-depot.conf"
# v0.20.1: boot thử v0.20 thấy timesyncd chốt máy dự phòng dù time.windows.com trả lời → dispatcher đưa về máy chủ đầu
D=$S/etc/NetworkManager/dispatcher.d/90-depot-timesync
chk "dispatcher đưa timesyncd về máy chủ đầu: giống repo, root, quyền 755 (NetworkManager bỏ qua file người khác ghi được)" "cmp -s $D $INC/etc/NetworkManager/dispatcher.d/90-depot-timesync && [ \"\$(stat -c '%a %u' $D)\" = '755 0' ]"
chk "file cấu hình timesyncd quyền 644 (777 thì timesyncd cảnh báo) + hook 0961 đã chạy" "[ \"\$(stat -c %a $S/etc/systemd/timesyncd.conf.d/50-depot.conf)\" = 644 ] && grep -q '>> Depot timesync: 755 root' build.log"
chk "systemd-timesyncd có trong ISO" "installed systemd-timesyncd"
chk "ngôn ngữ mặc định vi_VN ở CẢ /etc/locale.conf và /etc/default/locale (v0.19.3 ra C.UTF-8)" "grep -qx 'LANG=vi_VN.UTF-8' $S/etc/locale.conf && { [ -L $S/etc/default/locale ] || grep -qx 'LANG=vi_VN.UTF-8' $S/etc/default/locale; }"
chk "hook 1025 đã đặt ngôn ngữ (sau hook 1020 của live-build)" "grep -q '>> Depot locale: LANG=vi_VN.UTF-8' build.log"
chk "Firefox tiếng Việt" "installed firefox-esr-l10n-vi"
chk "depot-region + helper đúng cú pháp sh" "sh -n $S/usr/bin/depot-region && sh -n $S/usr/libexec/depot-region-helper && sh -n $S/usr/bin/depot-drivers"

echo
echo "== $PASS đạt, $FAIL trượt"
[ $FAIL = 0 ]
