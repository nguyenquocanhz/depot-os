#!/bin/bash
# Depot OS — kiểm chứng v0.16 (chạy trong WSL Debian, sau ./auto/build)
# Chạy check-v15.sh trước (gồm v14, v12, v11), rồi kiểm boot animation, tốc độ boot, ISO cơ bản + cài app lúc cài
# đặt + cập nhật kiểu Windows. Từ v0.16 Telegram/Claude/Discord/Antigravity/GNOME Software không còn trong ISO:
# DEPOT_APPS_AT_INSTALL=1 để v14/v15 bỏ qua các mục đó (kiểm lại ở đây dưới dạng depot-install-apps).
LB=/root/depot-os/build/live-build
cd "$LB" || exit 1
DEPOT_APPS_AT_INSTALL=1 bash /root/depot-os/scripts/check-v15.sh || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
chk() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

S=/tmp/sqv16; rm -rf $S
unsquashfs -f -d $S binary/live/filesystem.squashfs \
  usr/share/plymouth/themes/depot etc/plymouth/plymouthd.conf \
  etc/initramfs-tools/hooks/depot-plymouth-duration >/dev/null 2>&1
P=$S/usr/share/plymouth/themes/depot
INITRD=$(ls binary/live/initrd.img* | head -1)
N=$(sed -n 's/^FRAMES = \([0-9]*\);.*/\1/p' $P/depot.script)

echo "== BOOT ANIMATION (video → khung hình):"
# v0.10–v0.15 ghi "[plymouth Theme]" (p thường): Plymouth 24 không nhận, luôn hiện theme Debian
chk "theme khai báo đúng nhóm [Plymouth Theme]" "head -1 $P/depot.plymouth | grep -qx '\[Plymouth Theme\]'"
chk "Plymouth chọn theme depot" "grep -qx 'Theme=depot' $S/etc/plymouth/plymouthd.conf"
chk "script sinh từ template, không còn @…@" "[ -n \"$N\" ] && ! grep -q '@[A-Z_]*@' $P/depot.script"
chk "không dùng Window.GetMaxWidth (trả NULL ở Plymouth 24)" "! grep -q 'Window[.]GetMax' $P/depot.script"
chk "đủ $N khung hình + bar.png" "[ \$(ls $P/frame-*.png | wc -l) -eq $N ] && [ -f $P/bar.png ]"
chk "khung hình nhỏ (< 3 MB, ≤ 150 khung)" "[ \$(du -ck $P/frame-*.png | tail -1 | cut -f1) -lt 3072 ] && [ $N -le 150 ]"
chk "initramfs mang theme (script + khung cuối)" "lsinitramfs $INITRD | grep -q 'plymouth/themes/depot/depot.script' && lsinitramfs $INITRD | grep -q \"plymouth/themes/depot/frame-\$(printf %03d \$(($N - 1))).png\""
chk "initramfs có plugin script.so" "lsinitramfs $INITRD | grep -q 'plymouth/script.so'"
chk "hook initramfs chép boot-duration (chạy được, không CRLF)" "[ -x $S/etc/initramfs-tools/hooks/depot-plymouth-duration ] && sh -n $S/etc/initramfs-tools/hooks/depot-plymouth-duration && ! grep -q \$'\r' $S/etc/initramfs-tools/hooks/depot-plymouth-duration"
unsquashfs -f -d $S binary/live/filesystem.squashfs \
  etc/initramfs-tools/hooks/depot-slim etc/systemd/system >/dev/null 2>&1
lsinitramfs $INITRD > /tmp/initrd-v16.txt

echo "== TỐC ĐỘ BOOT:"
# v0.15: initrd nén 134 MB / giải nén ~300 MB — firmware amdgpu 78 MB, nvidia 62 MB, card mạng máy chủ ~35 MB
chk "initrd nén < 80 MB (v0.15: 134 MB)" "[ \$(stat -c %s $INITRD) -lt 83886080 ]"
chk "initrd không còn amdgpu/nouveau/xe + firmware NVIDIA/Xe (firmware amdgpu/ nhỏ còn lại là của radeon)" "! grep -qE 'drm/(amd|nouveau|xe)/|firmware/(nvidia|xe)/' /tmp/initrd-v16.txt"
chk "initrd không còn card mạng máy chủ" "! grep -qE 'ethernet/(netronome|cavium|chelsio|mellanox|qlogic)/|firmware/(netronome|liquidio|cxgb4|bnx2x|qed)/' /tmp/initrd-v16.txt"
chk "initrd vẫn có i915 + radeon (máy đích Intel HD 3000, card AMD cũ)" "grep -q 'drm/i915/i915.ko' /tmp/initrd-v16.txt && grep -q 'drm/radeon/radeon.ko' /tmp/initrd-v16.txt"
chk "initrd vẫn có driver mở ổ đĩa (ahci, usb-storage, squashfs, overlay)" "grep -q 'ahci.ko' /tmp/initrd-v16.txt && grep -q 'usb-storage.ko' /tmp/initrd-v16.txt && grep -q 'squashfs.ko' /tmp/initrd-v16.txt && grep -q 'overlay.ko' /tmp/initrd-v16.txt"
chk "hook depot-slim chạy được, không CRLF" "[ -x $S/etc/initramfs-tools/hooks/depot-slim ] && sh -n $S/etc/initramfs-tools/hooks/depot-slim && ! grep -q \$'\r' $S/etc/initramfs-tools/hooks/depot-slim"
chk "squashfs nén zstd (v0.15: xz, giải nén chậm trên CPU cũ)" "unsquashfs -s binary/live/filesystem.squashfs 2>/dev/null | grep -qi 'compression zstd'"
chk "menu boot chờ 3 giây (BIOS + UEFI)" "grep -qx 'timeout 30' binary/isolinux/isolinux.cfg && grep -qx 'set timeout=3' binary/boot/grub/config.cfg"
chk "phiên live bỏ timer nặng (man-db, apt-daily, fwupd…)" "( for t in man-db apt-daily apt-daily-upgrade fwupd-refresh e2scrub_all; do grep -qx 'ConditionPathExists=!/run/live/medium' $S/etc/systemd/system/\$t.timer.d/depot-live.conf || exit 1; done )"
echo "  initrd: $(du -h $INITRD | cut -f1) nén · squashfs: $(du -h binary/live/filesystem.squashfs | cut -f1)"

unsquashfs -f -d $S binary/live/filesystem.squashfs \
  var/lib/dpkg/status usr/bin/depot-install-apps usr/bin/depot-update usr/bin/google-chrome-stable \
  usr/lib/systemd/system/depot-update.service usr/lib/systemd/system/depot-update.timer \
  usr/lib/systemd/system/depot-offline-update.service etc/systemd/system/timers.target.wants \
  etc/systemd/system/system-update.target.wants etc/calamares etc/xdg/autostart/depot-update-notify.desktop \
  etc/skel/.config/i3/config usr/share/applications usr/bin/depot-plank usr/share/depot-os/layouts >/dev/null 2>&1
A=$S/usr/share/applications
W=$S/usr/share/depot-os/layouts/windows/xfce4-panel.xml
W11=$S/usr/share/depot-os/layouts/windows11/xfce4-panel.xml
installed() { awk -v p="$1" '$0 == "Package: " p { f = 1; next } /^Package:/ { f = 0 } f && /^Status: install ok installed/ { ok = 1 } END { exit !ok }' $S/var/lib/dpkg/status; }
CAL=$S/etc/calamares/settings.conf

echo "== ISO CƠ BẢN (app khác tải lúc cài đặt):"
chk "có sẵn: Firefox, Chrome, LocalSend, mpv" "installed firefox-esr && installed google-chrome-stable && installed localsend && installed mpv"
chk "Chrome: nguồn của Google do chính gói ghi (không trùng nguồn tạm)" "[ -f $A/google-chrome.desktop ] && ! ls $S/etc/apt/sources.list.d/ 2>/dev/null | grep -q depot-google-tmp"
chk "dock + taskbar + menu Start ghim Chrome" "grep -q ' google-chrome ' $S/usr/bin/depot-plank && grep -q 'google-chrome.desktop' $W && grep -q 'google-chrome.desktop' $W11"
chk "không còn trong ISO: GNOME Software, VLC, GParted, CUPS, Telegram, Claude, Discord, Antigravity" \
    "( for p in gnome-software vlc gparted cups telegram-desktop claude-desktop discord antigravity; do installed \$p && exit 1; done; exit 0 )"
chk "depot-install-apps chạy được, không CRLF, lo đủ app" "sh -n $S/usr/bin/depot-install-apps && ! grep -q \$'\r' $S/usr/bin/depot-install-apps && ( for f in debian_apps telegram claude discord antigravity; do grep -q \"^\$f() {\" $S/usr/bin/depot-install-apps || exit 1; done )"
chk "depot-install-apps: sửa nguồn apt thiếu contrib/non-free của Calamares" "grep -q 'main contrib non-free non-free-firmware' $S/usr/bin/depot-install-apps"
chk "Calamares: bước tải app ngay sau sources-final" "grep -A1 '^  - sources-final\$' $CAL | grep -q 'shellprocess@depotapps' && grep -q 'depot-install-apps --target' $S/etc/calamares/modules/shellprocess-depotapps.conf"
chk "Calamares: lỗi tải app không làm hỏng bản cài (lệnh có dấu -)" "grep -q '\"-/usr/bin/depot-install-apps' $S/etc/calamares/modules/shellprocess-depotapps.conf"

echo "== CẬP NHẬT (tải ngầm, cài lúc khởi động lại có màn chờ):"
chk "depot-update chạy được, không CRLF" "sh -n $S/usr/bin/depot-update && ! grep -q \$'\r' $S/usr/bin/depot-update"
chk "timer tải ngầm bật, đứng yên ở phiên live" "[ -L $S/etc/systemd/system/timers.target.wants/depot-update.timer ] && grep -qx 'ConditionPathExists=!/run/live/medium' $S/usr/lib/systemd/system/depot-update.service"
chk "dịch vụ cài lúc khởi động lại gắn system-update.target" "[ -L $S/etc/systemd/system/system-update.target.wants/depot-offline-update.service ] && grep -qx 'ConditionPathExists=/system-update' $S/usr/lib/systemd/system/depot-offline-update.service && grep -qx 'FailureAction=reboot' $S/usr/lib/systemd/system/depot-offline-update.service"
chk "PackageKit không giành cờ /system-update của depot-update" "grep -qx 'ConditionPathExists=/var/lib/PackageKit/prepared-update' $S/etc/systemd/system/packagekit-offline-update.service.d/depot.conf 2>/dev/null || unsquashfs -cat binary/live/filesystem.squashfs etc/systemd/system/packagekit-offline-update.service.d/depot.conf 2>/dev/null | grep -qx 'ConditionPathExists=/var/lib/PackageKit/prepared-update'"
chk "thông báo 'Khởi động lại để cập nhật' (XFCE + i3)" "grep -qx 'Exec=depot-update notify' $S/etc/xdg/autostart/depot-update-notify.desktop && grep -q 'exec --no-startup-id depot-update notify' $S/etc/skel/.config/i3/config"
chk "màn chờ cập nhật trong theme (chế độ updates + %)" "grep -q 'SetSystemUpdateFunction' $P/depot.script && grep -q 'Đang cập nhật Depot OS' $P/depot.script"
chk "hook 1230 đã chạy" "grep -q '>> Depot update: timer enabled, offline enabled' build.log"

unsquashfs -f -d $S binary/live/filesystem.squashfs \
  usr/share/sounds/depot usr/bin/depot-sounds etc/xdg/autostart/depot-sounds.desktop \
  etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml etc/skel/.config/gtk-3.0/settings.ini \
  usr/lib/firmware/intel/sof usr/share/alsa/ucm2 >/dev/null 2>&1
echo "== ÂM THANH:"
chk "driver: PipeWire đủ (ALSA + Bluetooth), SOF, UCM, alsa-utils, pactl" "( for p in pipewire-audio pipewire-alsa libspa-0.2-bluetooth firmware-sof-signed alsa-ucm-conf alsa-utils pulseaudio-utils; do installed \$p || exit 1; done )"
chk "firmware SOF có trong hệ thống (loa laptop Intel đời mới)" "[ -n \"\$(ls $S/usr/lib/firmware/intel/sof* 2>/dev/null | head -1)\" ] || ls -d $S/usr/lib/firmware/intel/sof* >/dev/null 2>&1"
chk "bộ âm depot: index.theme + đủ âm chính" "grep -qx 'Inherits=freedesktop' $S/usr/share/sounds/depot/index.theme && ( for e in desktop-login message-new-instant dialog-warning dialog-error device-added device-removed audio-volume-change audio-channel-front-left audio-channel-front-right; do [ -s $S/usr/share/sounds/depot/stereo/\$e.oga ] || exit 1; done )"
chk "depot-sounds chạy được, không CRLF" "sh -n $S/usr/bin/depot-sounds && ! grep -q \$'\r' $S/usr/bin/depot-sounds"
chk "âm sự kiện bật, bộ âm depot (XFCE + GTK + i3)" "grep -q 'name=\"EnableEventSounds\" type=\"bool\" value=\"true\"' $S/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml && grep -q 'name=\"SoundThemeName\" type=\"string\" value=\"depot\"' $S/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml && grep -qx 'gtk-sound-theme-name = depot' $S/etc/skel/.config/gtk-3.0/settings.ini && grep -q 'exec --no-startup-id depot-sounds session' $S/etc/skel/.config/i3/config"
chk "chuông khởi động + âm báo chạy cùng phiên (autostart)" "grep -qx 'Exec=depot-sounds session' $S/etc/xdg/autostart/depot-sounds.desktop"
chk "menu: Thử âm thanh" "grep -qx 'Exec=depot-sounds test' $A/depot-sound-test.desktop"

unsquashfs -f -d $S binary/live/filesystem.squashfs usr/bin/depot-clock usr/bin/depot-layout >/dev/null 2>&1
echo "== VỊ TRÍ ĐỒNG HỒ:"
chk "depot-clock chạy được, không CRLF" "sh -n $S/usr/bin/depot-clock && ! grep -q \$'\r' $S/usr/bin/depot-clock"
chk "đồng hồ giữa: panel riêng ở giữa cạnh TRÊN (p=9), nền trong suốt" "grep -q 'p=9;x=0;y=0' $S/usr/bin/depot-clock && grep -q 'background-rgba -n -a -t double -s 0 -t double -s 0 -t double -s 0 -t double -s 0' $S/usr/bin/depot-clock"
chk "đổi bố cục giữ vị trí đồng hồ (depot-layout gọi depot-clock apply)" "grep -q '^ *depot-clock apply' $S/usr/bin/depot-layout"
chk "menu: Vị trí đồng hồ" "grep -qx 'Exec=depot-clock' $A/depot-clock.desktop"

echo
echo "KẾT QUẢ v0.16 (phần mới): $PASS đạt, $FAIL hỏng"
[ $FAIL -eq 0 ]
