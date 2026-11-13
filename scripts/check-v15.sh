#!/bin/bash
# Depot OS — kiểm chứng v0.15 (chạy trong WSL Debian, sau ./auto/build)
# Chạy check-v14.sh trước (gồm cả v12, v11), rồi kiểm phần cài/gỡ app
LB=/root/depot-os/build/live-build
cd "$LB" || exit 1
bash /root/depot-os/scripts/check-v14.sh || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
chk() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

S=/tmp/sqv15; rm -rf $S
unsquashfs -f -d $S binary/live/filesystem.squashfs \
  var/lib/dpkg/status var/lib/dpkg/info/antigravity.list var/lib/flatpak/repo/config \
  usr/bin/depot-software usr/bin/depot-uninstall usr/bin/depot-plank usr/bin/gnome-software usr/bin/flatpak \
  etc/apt/apt.conf.d/90depot-uninstall etc/xdg/mimeapps.list \
  usr/share/glib-2.0/schemas/90_depot-software.gschema.override usr/share/glib-2.0/schemas/gschemas.compiled \
  usr/share/applications usr/share/depot-os/layouts usr/share/discord/discord.desktop \
  usr/share/icons/WhiteSur/apps/scalable/org.gnome.Software.svg usr/share/icons/WhiteSur/apps/scalable/gnome-software.svg \
  usr/share/icons/WhiteSur/apps/scalable/softwarecenter.svg >/dev/null 2>&1
# discord.desktop và icon Phần mềm là symlink (icon: org.gnome.Software → gnome-software → softwarecenter): giải nén cả file đích
A=$S/usr/share/applications
W=$S/usr/share/depot-os/layouts/windows/xfce4-panel.xml
W11=$S/usr/share/depot-os/layouts/windows11/xfce4-panel.xml
installed() { awk -v p="$1" '$0 == "Package: " p { f = 1; next } /^Package:/ { f = 0 } f && /^Status: install ok installed/ { ok = 1 } END { exit !ok }' $S/var/lib/dpkg/status; }
action() { grep -q '^\[Desktop Action depot-uninstall\]' "$A/$1" && grep -q '^Actions=.*depot-uninstall;' "$A/$1"; }

echo "== CÀI APP (GNOME Software):"
if [ -z "${DEPOT_APPS_AT_INSTALL:-}" ]; then
    chk_gs_pkgs() { for p in gnome-software gnome-software-plugin-deb gnome-software-plugin-flatpak flatpak; do chk "gói $p" "installed $p"; done; }
    chk_gs_pkgs
    chk "Flathub có sẵn (remote hệ thống)" "grep -q '^\[remote \"flathub\"\]' $S/var/lib/flatpak/repo/config"
    chk "không tự tải cập nhật (schema override)" "grep -qx 'download-updates=false' $S/usr/share/glib-2.0/schemas/90_depot-software.gschema.override && grep -q 'Kho app' build.log"
else
    echo "  (từ v0.16 cài lúc cài đặt bằng depot-install-apps — check-v16.sh kiểm)"
fi
chk "depot-software chạy được, cú pháp sh, không CRLF" "[ -x $S/usr/bin/depot-software ] && sh -n $S/usr/bin/depot-software && ! grep -q \$'\r' $S/usr/bin/depot-software"
if [ -z "${DEPOT_APPS_AT_INSTALL:-}" ]; then
    chk "menu mở GNOME Software qua depot-software (tự tắt khi đóng)" "grep -qx 'Exec=depot-software %U' $A/org.gnome.Software.desktop && ! grep -q '^DBusActivatable' $A/org.gnome.Software.desktop"
    chk "nhấp đúp .deb → hộp cài (depot-programs từ v0.25, GNOME Software là lựa chọn thứ hai)" "grep -qE '^application/vnd.debian.binary-package=(depot-programs.desktop;)?gnome-software-local-file-packagekit.desktop$' $S/etc/xdg/mimeapps.list && grep -q '^Exec=depot-software --local-filename' $A/gnome-software-local-file-packagekit.desktop"
else
    echo "  (từ v0.16 cài lúc cài đặt bằng depot-install-apps — check-v16.sh kiểm)"
fi
chk "icon Phần mềm (WhiteSur)" "[ -f $S/usr/share/icons/WhiteSur/apps/scalable/org.gnome.Software.svg ]"
chk "dock + taskbar + menu Start ghim Phần mềm" "grep -q ' org.gnome.Software ' $S/usr/bin/depot-plank && grep -q 'org.gnome.Software.desktop' $W && grep -q 'org.gnome.Software.desktop' $W11"

echo "== GỠ APP (chuột phải):"
chk "depot-uninstall chạy được, cú pháp sh, không CRLF" "[ -x $S/usr/bin/depot-uninstall ] && sh -n $S/usr/bin/depot-uninstall && ! grep -q \$'\r' $S/usr/bin/depot-uninstall"
chk "apt tự gắn mục gỡ cho app mới cài" "grep -q 'depot-uninstall --refresh' $S/etc/apt/apt.conf.d/90depot-uninstall && grep -q 'depot-software --patch' $S/etc/apt/apt.conf.d/90depot-uninstall"
if [ -z "${DEPOT_APPS_AT_INSTALL:-}" ]; then
    chk "mục Gỡ cài đặt: 4 app chat/AI + VLC + LocalSend" "( for f in com.anthropic.Claude.desktop org.telegram.desktop.desktop discord.desktop antigravity.desktop vlc.desktop localsend_app.desktop; do action \$f || exit 1; done )"
else
    echo "  (từ v0.16 cài lúc cài đặt bằng depot-install-apps — check-v16.sh kiểm)"
fi
chk "không gắn cho phần hệ thống (Thunar, Firefox, Terminal, Phần mềm)" "( for f in thunar.desktop firefox-esr.desktop xfce4-terminal.desktop org.gnome.Software.desktop; do [ -f $A/\$f ] || continue; action \$f && exit 1; done; exit 0 )"
if command -v desktop-file-validate >/dev/null; then
    chk "file .desktop đã sửa vẫn hợp lệ" "( for f in vlc.desktop discord.desktop org.gnome.Software.desktop localsend_app.desktop google-chrome.desktop; do [ -f $A/\$f ] || continue; desktop-file-validate $A/\$f 2>&1 | grep -q 'error:' && exit 1; done; exit 0 )"
fi
if [ -z "${DEPOT_APPS_AT_INSTALL:-}" ]; then
    chk "Antigravity là gói .deb (gỡ được)" "installed antigravity && grep -qx '/opt/antigravity/chrome-sandbox' $S/var/lib/dpkg/info/antigravity.list"
    chk "hook 1220: Flathub + mục gỡ" "grep -q '>> Kho app: GNOME Software + Flathub' build.log && [ \$(sed -n 's/.*Gỡ cài đặt (chuột phải): \([0-9]*\) app.*/\1/p' build.log | tail -1) -ge 10 ]"
else
    echo "  (từ v0.16 cài lúc cài đặt bằng depot-install-apps — check-v16.sh kiểm)"
fi

echo "== PHIÊN LIVE:"
chk "user depot@depot-os (menu BIOS + UEFI)" "grep -q 'username=depot ' binary/isolinux/live.cfg && grep -rq 'hostname=depot-os' binary/boot/grub/"

echo
echo "KẾT QUẢ v0.15 (phần mới): $PASS đạt, $FAIL hỏng"
[ $FAIL -eq 0 ]
