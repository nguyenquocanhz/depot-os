#!/bin/bash
# Depot OS — kiểm chứng v0.14 (chạy trong WSL Debian, sau ./auto/build)
# Chạy check-v12.sh trước (gồm cả check-v11), rồi kiểm phần dò driver
LB=/root/depot-os/build/live-build
cd "$LB" || exit 1
bash /root/depot-os/scripts/check-v12.sh || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
chk() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

S=/tmp/sqv14; rm -rf $S
unsquashfs -f -d $S binary/live/filesystem.squashfs \
  usr/bin/depot-drivers usr/bin/isenkram-lookup usr/sbin/isenkram-autoinstall-firmware \
  usr/bin/nvidia-detect usr/bin/lsusb usr/bin/lspci usr/bin/column usr/bin/pkexec \
  usr/lib/systemd/system/depot-drivers-scan.service etc/systemd/system/graphical.target.wants \
  etc/xdg/autostart/depot-drivers.desktop usr/share/applications/depot-drivers.desktop \
  usr/libexec/polkit-mate-authentication-agent-1 etc/skel/.config/i3/config \
  usr/lib/firmware/iwlwifi-6000g2a-6.ucode >/dev/null 2>&1

echo "== 8/8 DÒ DRIVER:"
chk "depot-drivers chạy được, cú pháp sh" "[ -x $S/usr/bin/depot-drivers ] && sh -n $S/usr/bin/depot-drivers"
chk "depot-drivers không CRLF" "! grep -q \$'\r' $S/usr/bin/depot-drivers"
for b in usr/bin/isenkram-lookup usr/sbin/isenkram-autoinstall-firmware usr/bin/nvidia-detect usr/bin/lsusb usr/bin/lspci usr/bin/column usr/bin/pkexec; do
    chk "$(basename $b)" "[ -e $S/$b ]"
done
chk "depot-drivers-scan.service" "[ -f $S/usr/lib/systemd/system/depot-drivers-scan.service ]"
chk "depot-drivers-scan.service bật" "[ -L $S/etc/systemd/system/graphical.target.wants/depot-drivers-scan.service ]"
chk "XFCE autostart: depot-drivers --notify" "grep -qx 'Exec=depot-drivers --notify' $S/etc/xdg/autostart/depot-drivers.desktop"
chk "menu: Driver phần cứng" "[ -f $S/usr/share/applications/depot-drivers.desktop ]"
chk "i3: polkit agent" "grep -q 'polkit-mate-authentication-agent-1' $S/etc/skel/.config/i3/config && [ -x $S/usr/libexec/polkit-mate-authentication-agent-1 ]"
chk "i3: depot-drivers --notify" "grep -q 'exec --no-startup-id depot-drivers --notify' $S/etc/skel/.config/i3/config"
chk "firmware non-free vẫn có (mẫu iwlwifi)" "[ -e $S/usr/lib/firmware/iwlwifi-6000g2a-6.ucode ]"
chk "hook 0970 đã chạy" "grep -q 'Depot drivers: depot-drivers-scan.service bật' build.log"

unsquashfs -f -d $S binary/live/filesystem.squashfs \
  usr/bin/depot-effects usr/share/applications/depot-effects.desktop \
  etc/xdg/autostart etc/skel/.config/picom >/dev/null 2>&1
echo "== HIỆU ỨNG HÌNH ẢNH:"
chk "depot-effects chạy được, cú pháp sh" "[ -x $S/usr/bin/depot-effects ] && sh -n $S/usr/bin/depot-effects"
chk "menu: Hiệu ứng hình ảnh" "[ -f $S/usr/share/applications/depot-effects.desktop ]"
chk "không còn autostart Conky riêng (tránh 2 bản)" "[ ! -e $S/etc/xdg/autostart/depot-conky.desktop ]"
chk "picom-animations.conf có đủ khối đánh dấu" "( for b in shadow fade anim; do grep -q \"^# \\[\$b\\]\" $S/etc/skel/.config/picom/picom-animations.conf || exit 1; done )"
chk "skel không còn picom.conf thừa" "[ ! -e $S/etc/skel/.config/picom/picom.conf ]"

unsquashfs -f -d $S binary/live/filesystem.squashfs \
  usr/bin/depot-layout usr/bin/depot-plank usr/share/applications/depot-layout.desktop \
  usr/share/depot-os/layouts usr/share/depot-os/dotfiles/config/xfce4 \
  etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml \
  usr/share/xfce4/panel/plugins/docklike.desktop usr/share/xfce4/panel/plugins/showdesktop.desktop >/dev/null 2>&1
P=$S/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
W=$S/usr/share/depot-os/layouts/windows/xfce4-panel.xml
echo "== BỐ CỤC macOS / Windows:"
# v0.10–v0.13 ghi panels là uint 1: panel bỏ cấu hình, hiện panel-0 rỗng (hộp đen 2 vạch chấm)
chk "panel macOS: /panels là array int" "grep -q '<property name=\"panels\" type=\"array\">' $P && ! grep -q '<value type=\"uint\"' $P"
chk "panel Windows: /panels là array int" "grep -q '<property name=\"panels\" type=\"array\">' $W && ! grep -q '<value type=\"uint\"' $W"
chk "panel Windows ở dưới, có docklike + showdesktop" "grep -q 'p=8;' $W && grep -q 'value=\"docklike\"' $W && grep -q 'value=\"showdesktop\"' $W"
chk "bản macOS cho depot-layout nằm ở dotfiles trong ISO" "cmp -s $P $S/usr/share/depot-os/dotfiles/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
chk "depot-layout chạy được, cú pháp sh" "[ -x $S/usr/bin/depot-layout ] && sh -n $S/usr/bin/depot-layout"
chk "depot-plank tự thoát khi bố cục Windows 10/11" "grep -qF 'windows*) exit 0' $S/usr/bin/depot-plank"
chk "menu: Bố cục desktop" "[ -f $S/usr/share/applications/depot-layout.desktop ]"
chk "menu Start Windows: danh mục bên trái, mở ra Tất cả ứng dụng" "grep -q 'position-categories-alternate\" type=\"bool\" value=\"true' $W && grep -q 'default-category\" type=\"int\" value=\"2' $W"
chk "menu Start Windows không dùng logo Apple (start-here của WhiteSur)" "! grep -q 'value=\"start-here\"' $W"
chk "plugin docklike + showdesktop có trong ISO" "[ -f $S/usr/share/xfce4/panel/plugins/docklike.desktop ] && [ -f $S/usr/share/xfce4/panel/plugins/showdesktop.desktop ]"
W11=$S/usr/share/depot-os/layouts/windows11/xfce4-panel.xml
chk "Windows 11: 2 panel, docklike ở panel KHÔNG nằm đè (panel-1)" "[ -f $W11 ] && awk '/name=\"panel-1\"/,/name=\"panel-2\"/' $W11 | grep -q 'value=\"3\"'"
chk "Windows 11: không panel nào nền trong suốt (alpha 0)" "! awk '/background-rgba/,/<\/property>/' $W11 | grep -q 'value=\"0\"/>\$'"
chk "Windows 11: menu Start dạng lưới, mở ra mục Ưa thích" "grep -q 'view-mode\" type=\"int\" value=\"0' $W11 && grep -q 'default-category\" type=\"int\" value=\"0' $W11"
chk "picom use-damage = false (không thì icon ghim mất sau khi đóng menu)" "grep -q '^use-damage = false;' $S/etc/skel/.config/picom/picom-animations.conf"
chk "depot-layout biết windows11" "grep -q 'windows11)' $S/usr/bin/depot-layout"

unsquashfs -f -d $S binary/live/filesystem.squashfs \
  etc/skel/.config/fcitx5 etc/default/im-config etc/X11/Xsession.d/70im-config_launch \
  usr/lib/x86_64-linux-gnu/gtk-3.0/3.0.0/immodules/im-fcitx5.so \
  usr/lib/x86_64-linux-gnu/qt6/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so \
  usr/lib/x86_64-linux-gnu/fcitx5/libunikey.so >/dev/null 2>&1
F5=$S/etc/skel/.config/fcitx5
echo "== BỘ GÕ TIẾNG VIỆT:"
chk "im-config chọn hẳn fcitx5 (XFCE không có autostart fcitx5 riêng)" "grep -q '^IM_CONFIG_DEFAULT_MODE=fcitx5\$' $S/etc/default/im-config && [ -f $S/etc/X11/Xsession.d/70im-config_launch ]"
chk "hook 0710 đã chạy" "grep -q 'Depot input: im-config = fcitx5' build.log"
chk "danh sách bộ gõ có sẵn Unikey" "grep -q '^Name=unikey\$' $F5/profile && grep -q '^DefaultIM=unikey\$' $F5/profile"
chk "phím bật/tắt Ctrl+Space và Ctrl+Shift" "grep -q '=Control+space\$' $F5/config && grep -q '=Control+Shift+Shift_L\$' $F5/config"
chk "bật một lần cho mọi cửa sổ (ShareInputState=All)" "grep -q '^ShareInputState=All\$' $F5/config"
chk "Unikey: Telex, kiểu mới, tự trả lại từ tiếng Anh" "grep -q '^InputMethod=Telex\$' $F5/conf/unikey.conf && grep -q '^ModernStyle=True\$' $F5/conf/unikey.conf && grep -q '^AutoNonVnRestore=True\$' $F5/conf/unikey.conf"
chk "module fcitx5 cho GTK3, Qt6 và Unikey" "[ -f $S/usr/lib/x86_64-linux-gnu/gtk-3.0/3.0.0/immodules/im-fcitx5.so ] && [ -f $S/usr/lib/x86_64-linux-gnu/qt6/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so ] && [ -f $S/usr/lib/x86_64-linux-gnu/fcitx5/libunikey.so ]"

unsquashfs -f -d $S binary/live/filesystem.squashfs \
  usr/bin/telegram-desktop usr/bin/claude-desktop usr/bin/discord usr/share/discord \
  opt/antigravity/antigravity opt/antigravity/chrome-sandbox usr/share/applications \
  etc/apt/sources.list.d usr/share/keyrings/claude-desktop-archive-keyring.asc \
  usr/bin/depot-webapp usr/share/icons/hicolor/scalable/apps/zalo.svg usr/bin/depot-plank \
  usr/share/icons/WhiteSur/apps/scalable/claude.svg usr/share/icons/WhiteSur/apps/scalable/claude-desktop.svg \
  usr/share/icons/WhiteSur/apps/scalable/antigravity.svg >/dev/null 2>&1
A=$S/usr/share/applications
echo "== APP CÀI SẴN:"
if [ -z "${DEPOT_APPS_AT_INSTALL:-}" ]; then
    chk "Telegram (trixie-backports)" "[ -x $S/usr/bin/telegram-desktop ] && [ -f $A/org.telegram.desktop.desktop ]"
    chk "Telegram: nguồn backports giữ lại để cập nhật" "grep -q 'trixie-backports' $S/etc/apt/sources.list.d/debian-backports.sources"
    chk "Claude (kho apt Anthropic)" "[ -L $S/usr/bin/claude-desktop ] && [ -f $A/com.anthropic.Claude.desktop ]"
    chk "Claude: nguồn apt + khoá ký giữ lại để cập nhật" "grep -q 'downloads.claude.ai' $S/etc/apt/sources.list.d/claude-desktop.list && [ -f $S/usr/share/keyrings/claude-desktop-archive-keyring.asc ]"
    chk "Discord (bộ khởi động chính thức)" "[ -x $S/usr/bin/discord ] && [ -x $S/usr/share/discord/updater_bootstrap ] && [ -f $A/discord.desktop ]"
    chk "Antigravity ở /opt, chrome-sandbox setuid root" "[ -x $S/opt/antigravity/antigravity ] && [ -u $S/opt/antigravity/chrome-sandbox ] && [ -f $A/antigravity.desktop ]"
else
    echo "  (từ v0.16 cài lúc cài đặt bằng depot-install-apps — check-v16.sh kiểm)"
fi
chk "Zalo: web app (depot-webapp) + icon" "sh -n $S/usr/bin/depot-webapp && grep -q 'depot-webapp Zalo' $A/zalo.desktop && [ -f $S/usr/share/icons/hicolor/scalable/apps/zalo.svg ]"
if [ -z "${DEPOT_APPS_AT_INSTALL:-}" ]; then
    chk "icon Claude (claude-desktop → WhiteSur) + Antigravity" "[ -L $S/usr/share/icons/WhiteSur/apps/scalable/claude-desktop.svg ] && [ -f $S/usr/share/icons/WhiteSur/apps/scalable/claude.svg ] && [ -f $S/usr/share/icons/WhiteSur/apps/scalable/antigravity.svg ]"
    chk "Antigravity: StartupWMClass khớp cửa sổ (antigravity)" "grep -qx 'StartupWMClass=antigravity' $A/antigravity.desktop"
else
    echo "  (từ v0.16 cài lúc cài đặt bằng depot-install-apps — check-v16.sh kiểm)"
fi
chk "dock + taskbar + menu Start ghim đủ 5 app" "( for a in com.anthropic.Claude org.telegram.desktop zalo discord antigravity; do grep -q \" \$a \" $S/usr/bin/depot-plank && grep -q \"\$a.desktop\" $W && grep -q \"\$a.desktop\" $W11 || exit 1; done )"
if [ -z "${DEPOT_APPS_AT_INSTALL:-}" ]; then
    chk "hook 1210 cài đủ 4 app" "[ \$(grep -c '>> App cài sẵn:' build.log) -ge 4 ] && ! grep -q 'App cài sẵn: .* KHÔNG cài được' build.log"
else
    echo "  (từ v0.16 cài lúc cài đặt bằng depot-install-apps — check-v16.sh kiểm)"
fi

echo
echo "KẾT QUẢ v0.14 (phần mới): $PASS đạt, $FAIL hỏng"
[ $FAIL -eq 0 ]
