#!/bin/bash
# Depot OS — kiểm chứng v0.21 (chạy trong WSL Debian, sau ./auto/build): depot-notify (thẻ thông báo bo góc, khung
# Thông báo bên cạnh, ô báo Caps Lock, nút chuông trên panel), Dynamic Island ẩn / tắt chủ động, Settings Manager
# 8 nhóm + tên tiếng Việt, không nhảy desktop ảo khi chuột chạm mép. Chạy thêm scripts/check-v20.sh cho phần cũ.
LB=${LB:-/root/depot-os/build/live-build}
cd "$LB" || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
chk() { if eval "$2" 2>/dev/null; then ok "$1"; else bad "$1"; fi; }

ISO=live-image-amd64.hybrid.iso
SQ=binary/live/filesystem.squashfs
S=/tmp/sqv21; rm -rf $S
INC=config/includes.chroot
FILES="usr/bin/depot-notify usr/bin/depot-notify-bell usr/bin/depot-island usr/bin/depot-effects usr/bin/depot-layout"
DATA="etc/xdg/autostart/depot-notify.desktop usr/share/applications/depot-notify.desktop
etc/xdg/menus/xfce-settings-manager.menu usr/share/depot-os/settings-names.conf
usr/share/depot-os/layouts/windows/xfce4-panel.xml usr/share/depot-os/layouts/windows11/xfce4-panel.xml"
unsquashfs -f -d $S $SQ etc/skel etc/xdg/autostart etc/xdg/menus usr/share/applications usr/local/share/applications \
  usr/share/desktop-directories usr/share/depot-os/settings-names.conf usr/share/depot-os/layouts \
  var/lib/dpkg/status $FILES >/dev/null 2>&1
# Từ v0.25 depot-pin gắn mục chuột phải "Ghim / bỏ ghim trên taskbar" vào mọi file .desktop có trong menu lúc build:
# file .desktop trong ISO dài hơn bản trong repo đúng phần đó — so thì bỏ phần đó ra.
nopin() { awk '/^\[Desktop Action depot-pin\]/ { skip = 1 } !skip' "$1" | sed -e 's/^\(Actions=.*\)depot-pin;$/\1/' -e '/^Actions=$/d'; }
same() { cmp -s "$S/$1" "$INC/$1" && return 0; case "$1" in *.desktop) [ "$(nopin "$S/$1")" = "$(cat "$INC/$1")" ] ;; *) return 1 ;; esac; }
installed() { awk -v p="$1" '$0 == "Package: " p { f = 1; next } /^Package:/ { f = 0 } f && /^Status: install ok installed/ { ok = 1 } END { exit !ok }' $S/var/lib/dpkg/status; }
SK=$S/etc/skel/.config
XF=$SK/xfce4/xfconf/xfce-perchannel-xml

echo "== ISO:"
chk "ISO tồn tại, đóng sau squashfs (không phải ISO cũ)" "[ -s $ISO ] && [ \$(stat -c %Z $ISO) -ge \$(stat -c %Z $SQ) ]"

echo "== FILE DEPOT (có trong ISO, giống repo, chạy được):"
for f in $FILES; do chk "$f" "[ -x $S/$f ] && same $f"; done
for f in $DATA; do chk "$f" "same $f"; done
chk "depot-notify, depot-island đúng cú pháp Python" "python3 -m py_compile $S/usr/bin/depot-notify $S/usr/bin/depot-island"
chk "depot-notify-bell, depot-effects, depot-layout đúng cú pháp sh" "sh -n $S/usr/bin/depot-notify-bell && sh -n $S/usr/bin/depot-effects && sh -n $S/usr/bin/depot-layout"

echo "== THÔNG BÁO (depot-notify thay xfce4-notifyd):"
for p in python3-gi python3-gi-cairo gir1.2-gtk-3.0 libnotify-bin xfce4-genmon-plugin; do chk "gói $p" "installed $p"; done
chk "xfce4-notifyd vẫn cài (dự phòng khi depot-notify hỏng)" "installed xfce4-notifyd"
chk "skel: xfce4-notifyd không tự chạy (Hidden=true)" "grep -qx 'Hidden=true' $SK/autostart/xfce4-notifyd.desktop"
chk "panel macOS: chuông là genmon, hết notification-plugin" "grep -q 'plugin-7\" type=\"string\" value=\"genmon\"' $XF/xfce4-panel.xml && ! grep -q notification-plugin $XF/xfce4-panel.xml"
chk "panel Windows 10/11: chuông là genmon" "! grep -rq notification-plugin $S/usr/share/depot-os/layouts && [ \$(grep -l 'plugin-9\" type=\"string\" value=\"genmon\"' $S/usr/share/depot-os/layouts/*/xfce4-panel.xml | wc -l) = 2 ]"
chk "skel: genmon-7.rc gọi depot-notify-bell" "grep -qx 'Command=depot-notify-bell' $SK/xfce4/panel/genmon-7.rc"
chk "depot-layout ghi file rc của chuông khi đổi bố cục" "grep -q 'write_bell \"\$1\"' $S/usr/bin/depot-layout"
chk "phím tắt Super+N (XFCE)" "grep -q 'Super&gt;n\" type=\"string\" value=\"depot-notify toggle\"' $XF/xfce4-keyboard-shortcuts.xml"
chk "i3: chạy depot-notify thay dunst, \$mod+n" "grep -q '^exec --no-startup-id depot-notify\$' $SK/i3/config && ! grep -q '^exec --no-startup-id dunst' $SK/i3/config && grep -q 'mod+n exec --no-startup-id depot-notify toggle' $SK/i3/config"
chk "picom: không đổ bóng chữ nhật quanh thẻ, khung, viên Island" "grep -q \"class_g = 'Depot-notify'\" $SK/picom/picom-animations.conf && grep -q \"class_g = 'Depot-island'\" $SK/picom/picom-animations.conf"
chk "depot-notify có ô báo Caps Lock" "grep -q 'class LockOSD' $S/usr/bin/depot-notify"

echo "== DYNAMIC ISLAND:"
chk "nút ×, menu chuột phải, tự ẩn khi tạm dừng" "grep -q \"self.buttons\\['close'\\]\" $S/usr/bin/depot-island && grep -q 'Tắt Dynamic Island' $S/usr/bin/depot-island && grep -q '^PAUSE_HIDE = ' $S/usr/bin/depot-island"
chk "depot-effects island on|off" "grep -q '^    island)' $S/usr/bin/depot-effects"

echo "== SETTINGS MANAGER:"
chk "8 tên nhóm depot-settings-*.directory" "[ \$(ls $S/usr/share/desktop-directories/depot-settings-*.directory | wc -l) = 8 ]"
chk "menu: 8 nhóm, không còn nhóm trộn của XFCE" "[ \$(grep -c '<Directory>depot-settings-' $S/etc/xdg/menus/xfce-settings-manager.menu) = 8 ]"
chk "menu là XML hợp lệ" "xmllint --noout $S/etc/xdg/menus/xfce-settings-manager.menu"
chk "hook 0725 đã chạy: ≥ 20 mục có tên tiếng Việt" "[ \$(grep -l '^Name\\[vi\\]=' $S/usr/local/share/applications/*.desktop | wc -l) -ge 20 ]"
chk "mục Mousepad hết bị ghi 'Gỡ cài đặt'" "grep -qx 'Name\\[vi\\]=Tuỳ chọn trình soạn văn bản' $S/usr/local/share/applications/org.xfce.mousepad-settings.desktop"
chk "mọi mục có tên trong menu đều có trong ISO hoặc là mục tuỳ chọn" "for f in depot-wallpaper depot-layout depot-effects depot-clock depot-notify depot-dns-proxy depot-drivers depot-power depot-region depot-edition depot-about depot-sound-test; do [ -f $S/usr/share/applications/\$f.desktop ] || exit 1; done"

echo "== PHÍM TẮT:"
chk "skel: bộ phím tắt có cờ override (không thì XFCE xoá phím của Depot ở lần đăng nhập đầu)" "grep -q 'name=\"override\" type=\"bool\" value=\"true\"' $XF/xfce4-keyboard-shortcuts.xml"
# từ v0.25 Win+R mở depot-run (hộp Chạy kiểu Windows); xfce4-appfinder vẫn còn cho Alt+F2 / Alt+F3
chk "Win+R = hộp Chạy (depot-run từ v0.25, trước đó xfce4-appfinder), có gói xfce4-appfinder" "grep -qE 'Super&gt;r\" type=\"string\" value=\"(xfce4-appfinder --collapsed|depot-run)\"' $XF/xfce4-keyboard-shortcuts.xml && installed xfce4-appfinder"
chk "Win+E, Win+I, Win+L, Win+Shift+S, Ctrl+Alt+T" "for k in 'Super&gt;e\" type=\"string\" value=\"thunar\"' 'Super&gt;i\" type=\"string\" value=\"xfce4-settings-manager\"' 'Super&gt;l\" type=\"string\" value=\"xflock4\"' 'Shift&gt;&lt;Super&gt;s\" type=\"string\" value=\"xfce4-screenshooter -r\"' 'Alt&gt;t\" type=\"string\" value=\"xfce4-terminal\"'; do grep -q \"\$k\" $XF/xfce4-keyboard-shortcuts.xml || exit 1; done"
chk "file phím tắt là XML hợp lệ" "xmllint --noout $XF/xfce4-keyboard-shortcuts.xml"

echo "== CỬA SỔ:"
chk "skel: chuột chạm mép không nhảy desktop ảo (lỗi 'Chrome biến mất khi xem phim')" "grep -q 'wrap_workspaces\" type=\"bool\" value=\"false\"' $XF/xfwm4.xml && grep -q 'wrap_windows\" type=\"bool\" value=\"false\"' $XF/xfwm4.xml"

echo
echo "v0.21: $PASS đạt, $FAIL lỗi"
[ $FAIL = 0 ]
