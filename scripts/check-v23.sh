#!/bin/bash
# Depot OS — kiểm chứng v0.23 (chạy trong WSL Debian, sau ./auto/build): Bộ nhớ tạm (Clipboard Manager) —
# Clipman của XFCE + depot-clipboard (autostart, mặc định kiểu Windows, Win+V).
# Chạy thêm scripts/check-v22.sh, check-v21.sh, check-v20.sh, check-v19.sh cho phần cũ.
LB=${LB:-/root/depot-os/build/live-build}
cd "$LB" || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
chk() { if eval "$2" 2>/dev/null; then ok "$1"; else bad "$1"; fi; }

ISO=live-image-amd64.hybrid.iso
SQ=binary/live/filesystem.squashfs
S=/tmp/sqv23; rm -rf $S
INC=config/includes.chroot
unsquashfs -f -d $S $SQ usr/bin/depot-clipboard usr/bin/depot-layout usr/bin/xfce4-clipman usr/bin/xfce4-popup-clipman \
  etc/xdg/autostart/depot-clipboard.desktop etc/xdg/autostart/xfce4-clipman-plugin-autostart.desktop \
  etc/xdg/menus/xfce-settings-manager.menu usr/local/share/applications/xfce4-clipman-settings.desktop \
  etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml etc/skel/.config/i3/config \
  var/lib/dpkg/status >/dev/null 2>&1
# Từ v0.25 depot-pin gắn mục chuột phải "Ghim / bỏ ghim trên taskbar" vào mọi file .desktop có trong menu lúc build:
# file .desktop trong ISO dài hơn bản trong repo đúng phần đó — so thì bỏ phần đó ra.
nopin() { awk '/^\[Desktop Action depot-pin\]/ { skip = 1 } !skip' "$1" | sed -e 's/^\(Actions=.*\)depot-pin;$/\1/' -e '/^Actions=$/d'; }
same() { cmp -s "$S/$1" "$INC/$1" && return 0; case "$1" in *.desktop) [ "$(nopin "$S/$1")" = "$(cat "$INC/$1")" ] ;; *) return 1 ;; esac; }
installed() { awk -v p="$1" '$0 == "Package: " p { f = 1; next } /^Package:/ { f = 0 } f && /^Status: install ok installed/ { ok = 1 } END { exit !ok }' $S/var/lib/dpkg/status; }
SK=$S/etc/skel/.config

echo "== ISO:"
chk "ISO tồn tại, đóng sau squashfs (không phải ISO cũ)" "[ -s $ISO ] && [ \$(stat -c %Z $ISO) -ge \$(stat -c %Z $SQ) ]"

echo "== BỘ NHỚ TẠM:"
chk "gói xfce4-clipman, có lệnh xfce4-clipman và xfce4-popup-clipman" "installed xfce4-clipman && [ -x $S/usr/bin/xfce4-clipman ] && [ -x $S/usr/bin/xfce4-popup-clipman ]"
chk "depot-clipboard có trong ISO, giống repo, đúng cú pháp" "[ -x $S/usr/bin/depot-clipboard ] && same usr/bin/depot-clipboard && sh -n $S/usr/bin/depot-clipboard"
chk "tự chạy lúc đăng nhập XFCE (autostart của Depot; bản của gói vẫn Hidden)" "same etc/xdg/autostart/depot-clipboard.desktop && grep -qx 'Exec=depot-clipboard start' $S/etc/xdg/autostart/depot-clipboard.desktop && grep -qx 'Hidden=true' $S/etc/xdg/autostart/xfce4-clipman-plugin-autostart.desktop"
chk "Win+V mở lịch sử (XFCE)" "grep -q 'Super&gt;v\" type=\"string\" value=\"depot-clipboard show\"' $SK/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml"
chk "i3: chạy lúc vào phiên, \$mod+Shift+v" "grep -q '^exec --no-startup-id depot-clipboard start\$' $SK/i3/config && grep -q 'mod+Shift+v exec --no-startup-id depot-clipboard show' $SK/i3/config"
chk "mặc định: không ghi lịch sử xuống đĩa, chọn là dán" "grep -q 'def settings/save-on-quit bool false' $S/usr/bin/depot-clipboard && grep -q 'def tweaks/paste-on-activate uint 1' $S/usr/bin/depot-clipboard"
chk "đổi bố cục panel vẫn giữ mặc định Clipman (depot-layout gọi depot-clipboard defaults)" "same usr/bin/depot-layout && grep -q 'depot-clipboard defaults' $S/usr/bin/depot-layout"
chk "Cài đặt: mục 'Bộ nhớ tạm (Clipboard)' ở nhóm Cá nhân hoá, tên tiếng Việt" "grep -q '<Filename>xfce4-clipman-settings.desktop</Filename>' $S/etc/xdg/menus/xfce-settings-manager.menu && grep -qx 'Name\\[vi\\]=Bộ nhớ tạm (Clipboard)' $S/usr/local/share/applications/xfce4-clipman-settings.desktop"

echo "== UNIKEY (bảng điều khiển bộ gõ, mặc định VNI):"
unsquashfs -f -d $S $SQ usr/bin/depot-unikey usr/share/applications/depot-unikey.desktop \
  usr/local/share/fcitx5/inputmethod/unikey.conf usr/share/fcitx5/inputmethod/unikey.conf \
  etc/skel/.config/fcitx5 usr/local/share/applications/fcitx5-configtool.desktop >/dev/null 2>&1
FX=$SK/fcitx5
for p in fcitx5 fcitx5-unikey fcitx5-frontend-gtk3 fcitx5-frontend-qt5 python3-gi gir1.2-gtk-3.0; do chk "gói $p" "installed $p"; done
chk "depot-unikey có trong ISO, giống repo, đúng cú pháp" "[ -x $S/usr/bin/depot-unikey ] && same usr/bin/depot-unikey && python3 -c \"import ast; ast.parse(open('$S/usr/bin/depot-unikey', encoding='utf-8').read())\""
chk "mục 'Unikey' trong menu và Cài đặt > Hệ thống" "same usr/share/applications/depot-unikey.desktop && grep -q '<Filename>depot-unikey.desktop</Filename>' $S/etc/xdg/menus/xfce-settings-manager.menu"
chk "Ctrl+Shift+F5 mở bảng điều khiển" "grep -q 'Primary&gt;&lt;Shift&gt;F5\" type=\"string\" value=\"depot-unikey\"' $SK/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml"
chk "mặc định: kiểu gõ VNI (phím số), bảng mã Unicode" "grep -qx 'InputMethod=VNI' $FX/conf/unikey.conf && grep -qx 'OutputCharset=Unicode' $FX/conf/unikey.conf"
chk "khay hiện chữ en / vi: PreferTextIcon + nhãn vi (hook 0727)" "grep -qx 'PreferTextIcon=True' $FX/conf/classicui.conf && grep -qx 'Label=vi' $S/usr/local/share/fcitx5/inputmethod/unikey.conf"
chk "bản đè khai báo Unikey vẫn đủ nội dung của gói (Addon, Icon)" "grep -qx 'Addon=unikey' $S/usr/local/share/fcitx5/inputmethod/unikey.conf && [ \$(grep -c . $S/usr/local/share/fcitx5/inputmethod/unikey.conf) -ge \$(grep -c . $S/usr/share/fcitx5/inputmethod/unikey.conf) ]"
chk "biểu tượng khay của fcitx5 không bị tắt (chỉ có một biểu tượng bộ gõ)" "! grep -q 'DisabledAddons' $FX/config"
chk "phím chuyển Ctrl+Space + Ctrl+Shift, mặc định tắt tiếng Việt" "grep -qx '0=Control+space' $FX/config && grep -qx '1=Control+Shift+Shift_L' $FX/config && grep -qx 'ActiveByDefault=False' $FX/config"
chk "chạm Shift trái một mình KHÔNG đổi bộ gõ (từ v0.23.1; lỗi 'mất chữ khi gõ @')" "grep -qx 'AltTriggerKeys=' $FX/config && grep -q \"'AltTriggerKeys': ''\" $S/usr/bin/depot-unikey"
unsquashfs -f -d $S $SQ etc/xdg/autostart/depot-fcitx5.desktop etc/environment >/dev/null 2>&1
chk "bộ gõ tự chạy lúc đăng nhập XFCE (autostart depot-fcitx5; từ v0.23.2 — im-config không chạy fcitx5 vì /etc/environment đặt sẵn biến)" "grep -qx 'Exec=fcitx5 -d' $S/etc/xdg/autostart/depot-fcitx5.desktop && grep -qx 'GTK_IM_MODULE=fcitx' $S/etc/environment"
chk "i3 tự chạy fcitx5" "grep -q '^exec --no-startup-id fcitx5$' $SK/i3/config"
chk "công cụ fcitx5 đổi tên thành 'Bộ gõ nâng cao'" "grep -qx 'Name\\[vi\\]=Bộ gõ nâng cao (Fcitx 5)' $S/usr/local/share/applications/fcitx5-configtool.desktop"

echo
echo "v0.23: $PASS đạt, $FAIL lỗi"
[ $FAIL = 0 ]
