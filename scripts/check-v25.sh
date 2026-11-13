#!/bin/bash
# Depot OS — kiểm chứng v0.25 (chạy trong WSL Debian, sau ./auto/build): bố cục Windows viết lại cho người vừa chuyển từ
# Windows sang — phím Windows (xcape), hộp Chạy (depot-run), phím tắt Windows của cửa sổ, khung cửa sổ Depot-Win11,
# icon Papirus, đồng hồ taskbar có chuột phải "Điều chỉnh ngày giờ" (plugin depot-clock), ghim app (depot-pin),
# icon taskbar dồn trái / ở giữa (depot-layout align).
# Chạy thêm scripts/check-v24.sh … check-v19.sh cho phần cũ.
LB=${LB:-/root/depot-os/build/live-build}
cd "$LB" || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
chk() { if eval "$2" 2>/dev/null; then ok "$1"; else bad "$1"; fi; }

ISO=live-image-amd64.hybrid.iso
SQ=binary/live/filesystem.squashfs
S=/tmp/sqv25; rm -rf $S
INC=config/includes.chroot
PL=usr/lib/x86_64-linux-gnu/xfce4/panel/plugins
unsquashfs -f -d $S $SQ usr/bin/depot-run usr/bin/depot-pin usr/bin/depot-winkey usr/bin/depot-layout usr/bin/depot-clock \
  usr/bin/xcape usr/bin/galculator etc/xdg/autostart/depot-winkey.desktop etc/apt/apt.conf.d/90depot-uninstall \
  $PL/libdepot-clock.so $PL/libclock.so usr/share/xfce4/panel/plugins/depot-clock.desktop \
  usr/share/themes/Depot-Win11 usr/share/icons/Papirus-Dark/index.theme usr/share/depot-os/layouts \
  usr/share/applications/thunar.desktop usr/share/applications/firefox-esr.desktop \
  etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml var/lib/dpkg/status >/dev/null 2>&1
# Từ v0.25 depot-pin gắn mục chuột phải "Ghim / bỏ ghim trên taskbar" vào mọi file .desktop có trong menu lúc build:
# file .desktop trong ISO dài hơn bản trong repo đúng phần đó — so thì bỏ phần đó ra.
nopin() { awk '/^\[Desktop Action depot-pin\]/ { skip = 1 } !skip' "$1" | sed -e 's/^\(Actions=.*\)depot-pin;$/\1/' -e '/^Actions=$/d'; }
same() { cmp -s "$S/$1" "$INC/$1" && return 0; case "$1" in *.desktop) [ "$(nopin "$S/$1")" = "$(cat "$INC/$1")" ] ;; *) return 1 ;; esac; }
installed() { awk -v p="$1" '$0 == "Package: " p { f = 1; next } /^Package:/ { f = 0 } f && /^Status: install ok installed/ { ok = 1 } END { exit !ok }' $S/var/lib/dpkg/status; }
KB=$S/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml
W=$S/usr/share/themes/Depot-Win11/xfwm4
L11=$S/usr/share/depot-os/layouts/windows11/xfce4-panel.xml
L10=$S/usr/share/depot-os/layouts/windows/xfce4-panel.xml

echo "== ISO:"
chk "ISO tồn tại, đóng sau squashfs (không phải ISO cũ)" "[ -s $ISO ] && [ \$(stat -c %Z $ISO) -ge \$(stat -c %Z $SQ) ]"

echo "== PHÍM WINDOWS + HỘP CHẠY:"
chk "gói xcape, depot-winkey giống repo, tự chạy ở phiên XFCE" "installed xcape && [ -x $S/usr/bin/xcape ] && same usr/bin/depot-winkey && sh -n $S/usr/bin/depot-winkey && grep -qx 'Exec=depot-winkey' $S/etc/xdg/autostart/depot-winkey.desktop && grep -qx 'OnlyShowIn=XFCE;' $S/etc/xdg/autostart/depot-winkey.desktop"
chk "chạm phím Windows → Alt+F1 → menu Start (xcape đổi cú chạm, Alt+F1 gán cho whiskermenu)" "grep -q \"Super_L=Alt_L|F1\" $S/usr/bin/depot-winkey && grep -q 'Alt&gt;F1\" type=\"string\" value=\"xfce4-popup-whiskermenu\"' $KB && ! grep -q 'name=\"Super_L\"' $KB"
chk "Win+R = depot-run (giống repo, đúng cú pháp Python)" "same usr/bin/depot-run && grep -q 'Super&gt;r\" type=\"string\" value=\"depot-run\"' $KB && python3 -c \"import ast; ast.parse(open('$S/usr/bin/depot-run', encoding='utf-8').read())\""
rr() { python3 $S/usr/bin/depot-run --resolve "$1" 2>/dev/null | cut -f1,2 | tr '\t' ' '; }
chk "hộp Chạy hiểu: %temp%, địa chỉ web, C:, đường dẫn không có" "[ \"\$(rr '%temp%')\" = 'open /tmp' ] && [ \"\$(rr google.com)\" = 'open https://google.com' ] && [ \"\$(rr 'C:')\" = 'open /' ] && [ \"\$(rr /khong/co/that | cut -d' ' -f1)\" = none ]"
chk "hộp Chạy có bảng lệnh quen của Windows (cmd, explorer, control, notepad, calc, taskmgr, ncpa.cpl, devmgmt.msc, winver)" "for k in cmd explorer control notepad calc taskmgr ncpa.cpl devmgmt.msc winver; do grep -q \"'\$k': \" $S/usr/bin/depot-run || exit 1; done"
chk "gói galculator (gõ calc trong hộp Chạy)" "installed galculator && [ -x $S/usr/bin/galculator ]"
chk "phím lệnh kiểu Windows: Win+E, Win+I, Win+L, Win+V, Win+S, Win+A, Win+Shift+S, Ctrl+Shift+Esc" "for k in 'Super&gt;e' 'Super&gt;i' 'Super&gt;l' 'Super&gt;v' 'Super&gt;s' 'Super&gt;a' 'Shift&gt;&lt;Super&gt;s' 'Primary&gt;&lt;Shift&gt;Escape'; do grep -q \"name=\\\"&lt;\$k\\\"\" $KB || exit 1; done"

echo "== PHÍM CỦA CỬA SỔ (xfwm4):"
XW=$(sed -n '/<property name="xfwm4"/,$p' $KB)
chk "có cờ override ở cả hai phần (thiếu là XFCE chép đè bằng bộ mặc định)" "[ \$(grep -c 'name=\"override\" type=\"bool\" value=\"true\"' $KB) = 2 ]"
chk "Win+D hiện desktop, Win+←/→ xếp nửa màn, Win+↑ phóng to, Win+↓ thu nhỏ" "echo \"\$XW\" | grep -q 'Super&gt;d\" type=\"string\" value=\"show_desktop_key\"' && echo \"\$XW\" | grep -q 'Super&gt;Left\" type=\"string\" value=\"tile_left_key\"' && echo \"\$XW\" | grep -q 'Super&gt;Right\" type=\"string\" value=\"tile_right_key\"' && echo \"\$XW\" | grep -q 'Super&gt;Up\" type=\"string\" value=\"maximize_window_key\"' && echo \"\$XW\" | grep -q 'Super&gt;Down\" type=\"string\" value=\"hide_window_key\"'"
chk "mỗi việc của xfwm4 chỉ một phím (xfwm4 chỉ nhận một — lỗi gặp khi thử: Win+D không chạy vì trùng Ctrl+Alt+D)" "[ -z \"\$(echo \"\$XW\" | grep -o 'value=\"[a-z_0-9]*_key\"' | sort | uniq -d)\" ]"
chk "giữ đủ phím cơ bản: Alt+Tab, Alt+F4, Alt+F11, Win+Tab, phím mũi tên / Esc khi kéo cửa sổ" "for v in cycle_windows_key close_window_key fullscreen_key switch_window_key cancel_key up_key down_key left_key right_key; do echo \"\$XW\" | grep -q \"value=\\\"\$v\\\"\" || exit 1; done"

echo "== GIAO DIỆN KIỂU WINDOWS:"
chk "khung cửa sổ Depot-Win11: themerc + 60 ảnh, giống repo" "[ -s $W/themerc ] && [ \$(ls $W/*.png | wc -l) = 60 ] && cmp -s $W/themerc $INC/usr/share/themes/Depot-Win11/xfwm4/themerc && cmp -s $W/close-prelight.png $INC/usr/share/themes/Depot-Win11/xfwm4/close-prelight.png"
chk "nút đóng / thu nhỏ / phóng to đủ 4 trạng thái, cỡ 46x32" "for b in close hide maximize maximize-toggled; do for s in active inactive prelight pressed; do file $W/\$b-\$s.png | grep -q '46 x 32' || exit 1; done; done"
chk "bộ icon Papirus-Dark có trong ISO" "[ -s $S/usr/share/icons/Papirus-Dark/index.theme ]"
chk "depot-layout giống repo: đổi khung + icon theo bố cục, có lệnh align" "same usr/bin/depot-layout && sh -n $S/usr/bin/depot-layout && grep -q 'wm=Depot-Win11; icons=Papirus-Dark' $S/usr/bin/depot-layout && grep -q 'wm=WhiteSur-Dark; icons=WhiteSur' $S/usr/bin/depot-layout && grep -q 'set_align' $S/usr/bin/depot-layout"
chk "icon taskbar dồn trái: bỏ đúng vạch co giãn 11 của bố cục Windows 11 (số 11 chỉ có một lần)" "[ \$(grep -c '<value type=\"int\" value=\"11\"/>' $L11) = 1 ] && grep -q 'value=\"11\"' $S/usr/bin/depot-layout"
chk "đổi bố cục không xoá app người dùng đã ghim (chỉ ghi mặc định khi chưa có)" "grep -q \"grep -qs '^pinned=.'\" $S/usr/bin/depot-layout && grep -q 'keyComboActive=true' $S/usr/bin/depot-layout"

echo "== ĐỒNG HỒ TASKBAR (plugin depot-clock):"
chk "plugin có trong ISO, giống repo, là thư viện ELF 64-bit có điểm đăng ký plugin" "same $PL/libdepot-clock.so && file $S/$PL/libdepot-clock.so | grep -q 'ELF 64-bit.*shared object' && nm -D $S/$PL/libdepot-clock.so | grep -q xfce_panel_module_construct"
chk "plugin dùng đúng thư viện panel của ISO (libxfce4panel-2.0.so.4, GTK 3)" "objdump -p $S/$PL/libdepot-clock.so | grep -q 'NEEDED.*libxfce4panel-2.0.so.4' && objdump -p $S/$PL/libdepot-clock.so | grep -q 'NEEDED.*libgtk-3.so.0' && installed libxfce4panel-2.0-4"
chk "khai báo plugin: X-XFCE-Module=depot-clock" "same usr/share/xfce4/panel/plugins/depot-clock.desktop && grep -qx 'X-XFCE-Module=depot-clock' $S/usr/share/xfce4/panel/plugins/depot-clock.desktop"
chk "chuột phải có mục 'Điều chỉnh ngày giờ' mở depot-region" "grep -aq 'Điều chỉnh ngày giờ' $S/$PL/libdepot-clock.so && strings $S/$PL/libdepot-clock.so | grep -qx 'depot-region'"
chk "hai bố cục Windows dùng depot-clock làm plugin-8; mã nguồn plugin có trong repo" "grep -q 'plugin-8\" type=\"string\" value=\"depot-clock\"' $L11 && grep -q 'plugin-8\" type=\"string\" value=\"depot-clock\"' $L10 && [ -s \${REPO:-/root/depot-os}/tools/depot-clock-plugin/depot-clock-plugin.c ]"
chk "công cụ vị trí đồng hồ (depot-clock) nhận cả đồng hồ mới" "same usr/bin/depot-clock && grep -q 'clock | depot-clock)' $S/usr/bin/depot-clock"

echo "== GHIM APP LÊN TASKBAR:"
chk "depot-pin giống repo, đúng cú pháp" "same usr/bin/depot-pin && sh -n $S/usr/bin/depot-pin"
chk "app trong ISO có mục chuột phải 'Ghim / bỏ ghim trên taskbar' (Thunar, Firefox)" "grep -q '^\\[Desktop Action depot-pin\\]' $S/usr/share/applications/thunar.desktop && grep -qx 'Exec=depot-pin thunar.desktop' $S/usr/share/applications/thunar.desktop && grep -q '^\\[Desktop Action depot-pin\\]' $S/usr/share/applications/firefox-esr.desktop"
chk "mục 'Gỡ cài đặt' cũ vẫn còn cạnh mục ghim, dòng Actions= có cả hai" "grep -q '^Actions=.*depot-pin;' $S/usr/share/applications/firefox-esr.desktop"
chk "app cài sau cũng được gắn mục ghim (hook apt)" "grep -q 'depot-pin --refresh' $S/etc/apt/apt.conf.d/90depot-uninstall"

echo "== CHƯƠNG TRÌNH VÀ TÍNH NĂNG (depot-programs) + bấm đúp .deb:"
unsquashfs -f -d $S $SQ usr/bin/depot-programs usr/libexec/depot-programs-helper usr/share/applications/depot-programs.desktop \
  usr/share/polkit-1/actions/tech.wrenevil.depot.programs.policy etc/xdg/mimeapps.list etc/xdg/menus/xfce-settings-manager.menu \
  etc/skel/.config/gtk-3.0/gtk.css usr/bin/depot-uninstall >/dev/null 2>&1
H=$S/usr/libexec/depot-programs-helper
chk "depot-programs giống repo, đúng cú pháp Python; helper giống repo, đúng cú pháp sh, chạy được" "same usr/bin/depot-programs && python3 -c \"import ast; ast.parse(open('$S/usr/bin/depot-programs', encoding='utf-8').read())\" && same usr/libexec/depot-programs-helper && sh -n $H && [ -x $H ] && [ -x $S/usr/bin/depot-programs ]"
chk "polkit: hỏi mật khẩu quản trị, đúng đường dẫn helper" "same usr/share/polkit-1/actions/tech.wrenevil.depot.programs.policy && grep -q '>/usr/libexec/depot-programs-helper<' $S/usr/share/polkit-1/actions/tech.wrenevil.depot.programs.policy && python3 -c \"import xml.dom.minidom; xml.dom.minidom.parse('$S/usr/share/polkit-1/actions/tech.wrenevil.depot.programs.policy')\""
chk "helper kiểm tên gói và đường dẫn .deb trước khi dùng; cài .deb bằng apt (kéo gói phụ thuộc)" "grep -q 'valid_pkg' $H && grep -q '/\\*.deb) ;;' $H && grep -q 'apt-get install -y \"\$d/\$pkg.deb\"' $H"
chk "tệp .deb mặc định mở bằng depot-programs (GNOME Software là lựa chọn thứ hai)" "grep -qx 'application/vnd.debian.binary-package=depot-programs.desktop;gnome-software-local-file-packagekit.desktop' $S/etc/xdg/mimeapps.list && grep -q '^MimeType=application/vnd.debian.binary-package;' $S/usr/share/applications/depot-programs.desktop && grep -qx 'Exec=depot-programs %f' $S/usr/share/applications/depot-programs.desktop"
chk "có trong Cài đặt > Ứng dụng; hộp Chạy: appwiz.cpl mở nó" "grep -q '<Filename>depot-programs.desktop</Filename>' $S/etc/xdg/menus/xfce-settings-manager.menu && grep -q \"'appwiz.cpl': (lambda: first('depot-programs'\" $S/usr/bin/depot-run"
chk "gỡ app dùng chung danh sách gói hệ thống được bảo vệ với depot-uninstall" "grep -q \"^PROTECT='\" $S/usr/bin/depot-uninstall && grep -q 'depot-uninstall' $S/usr/bin/depot-programs"

echo "== TƯƠNG TÁC KHI RÊ CHUỘT:"
chk "taskbar / panel: nút đổi nền mềm trong 0,3 giây khi rê chuột (gtk.css của người dùng)" "grep -q '^\\.xfce4-panel button {' $S/etc/skel/.config/gtk-3.0/gtk.css && grep -q 'transition: background-color 300ms ease' $S/etc/skel/.config/gtk-3.0/gtk.css && grep -q '^\\.xfce4-panel button:hover {' $S/etc/skel/.config/gtk-3.0/gtk.css"

echo "== BỎ ZALO WEB (người dùng yêu cầu 13/11/2026):"
unsquashfs -f -d $S $SQ usr/bin/depot-plank usr/bin/depot-webapp >/dev/null 2>&1
ZL=$(unsquashfs -l $SQ usr/share/applications/zalo.desktop usr/share/icons/hicolor/scalable/apps/zalo.svg 2>/dev/null | grep -c 'zalo')
chk "ISO không còn mục Zalo và icon Zalo (đồng bộ D: → WSL không tự xoá file: phải xoá cả ở /root/depot-os)" "[ \"$ZL\" = 0 ]"
chk "dock, taskbar, menu Start không còn ghim Zalo" "! grep -q ' zalo ' $S/usr/bin/depot-plank && ! grep -q ' zalo ' $S/usr/bin/depot-layout && ! grep -q 'zalo.desktop' $L11 && ! grep -q 'zalo.desktop' $L10"
chk "công cụ depot-webapp vẫn còn (ai cần thì tự tạo web app)" "sh -n $S/usr/bin/depot-webapp"

echo
echo "v0.25: $PASS đạt, $FAIL lỗi"
[ $FAIL = 0 ]
