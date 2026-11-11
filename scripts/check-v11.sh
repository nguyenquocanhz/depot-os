#!/bin/bash
# Depot OS — kiểm chứng v0.11 (chạy trong WSL Debian, sau ./auto/build)
LB=/root/depot-os/build/live-build
cd "$LB" || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
# symlink bật dịch vụ trỏ /usr/lib/... tuyệt đối: dùng [ -L ], [ -e ] sẽ dò nhầm trên máy build
chk() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

echo "== ISO:"
ls -la live-image-amd64.hybrid.iso
tail -1 build.log

S=/tmp/sqv11; rm -rf $S
unsquashfs -f -d $S binary/live/filesystem.squashfs \
  usr/bin/depot-dns-proxy usr/bin/depot-rtc usr/bin/depot-results usr/bin/yad usr/sbin/hwclock \
  usr/lib/systemd/system/depot-rtc.service etc/systemd/system/basic.target.wants \
  etc/systemd/system/sysinit.target.wants \
  etc/systemd/timesyncd.conf.d etc/polkit-1/rules.d etc/X11/Xsession.d/90depot-proxy \
  etc/calamares usr/share/applications/depot-dns-proxy.desktop \
  etc/skel/.config etc/.updated var/.updated var/lib/dpkg/status >/dev/null 2>&1
has_pkg() { grep -qx "Package: $1" $S/var/lib/dpkg/status; }

echo "== 1/6 GÓI MỚI:"
for p in systemd-timesyncd util-linux-extra yad xdg-user-dirs-gtk; do chk "$p" "has_pkg $p"; done

echo "== 2/6 GIỜ:"
chk "timesyncd bật lúc boot" "[ -L $S/etc/systemd/system/sysinit.target.wants/systemd-timesyncd.service ]"
chk "timesyncd.conf.d/50-depot.conf" "[ -f $S/etc/systemd/timesyncd.conf.d/50-depot.conf ]"
chk "hwclock" "[ -x $S/usr/sbin/hwclock ]"
chk "depot-rtc chạy được" "[ -x $S/usr/bin/depot-rtc ]"
chk "depot-rtc.service bật" "[ -L $S/etc/systemd/system/basic.target.wants/depot-rtc.service ]"
chk "Calamares: bước depotrtc sau hwclock" "grep -A1 '^  - hwclock\$' $S/etc/calamares/settings.conf | grep -q shellprocess@depotrtc"
chk "Calamares: instance depotrtc" "grep -q 'id: depotrtc' $S/etc/calamares/settings.conf"
chk "Calamares: múi giờ mặc định HCM" "grep -q Ho_Chi_Minh $S/etc/calamares/modules/locale.conf"
chk "live: timezone= trong menu BIOS" "grep -q 'timezone=Asia/Ho_Chi_Minh' binary/isolinux/live.cfg binary/isolinux/*.cfg 2>/dev/null"
chk "live: timezone= trong menu UEFI" "grep -rq 'timezone=Asia/Ho_Chi_Minh' binary/boot/grub/"

echo "== 3/6 DNS + PROXY:"
chk "depot-dns-proxy chạy được" "[ -x $S/usr/bin/depot-dns-proxy ]"
chk "yad" "[ -x $S/usr/bin/yad ]"
chk "polkit 50-depot-dns.rules" "[ -f $S/etc/polkit-1/rules.d/50-depot-dns.rules ]"
chk "Xsession.d/90depot-proxy" "[ -f $S/etc/X11/Xsession.d/90depot-proxy ]"
chk "menu: DNS và Proxy" "[ -f $S/usr/share/applications/depot-dns-proxy.desktop ]"

echo "== 4/6 DOTFILES TRONG /etc/skel:"
X=$S/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
chk "thunar.xml" "[ -f $X/thunar.xml ]"
chk "Thunar uca.xml (LocalSend)" "grep -q localsend_app $S/etc/skel/.config/Thunar/uca.xml"
chk "xfce4-taskmanager.xml" "[ -f $X/xfce4-taskmanager.xml ]"
chk "xfwm4 nút CHM|" "grep -q 'CHM|' $X/xfwm4.xml"
chk "xfwm4 workspace_count kiểu int" "grep -q 'workspace_count\" type=\"int\"' $X/xfwm4.xml"
chk "i3: blueman-applet" "grep -q blueman-applet $S/etc/skel/.config/i3/config"

echo "== 5/6 HOOK ĐÃ CHẠY (build.log):"
chk "0960 depot-rtc" "grep -q 'Depot RTC: depot-rtc.service bật' build.log"
chk "9900 finalize" "grep -q 'Depot finalize' build.log"
chk "stamp /etc/.updated" "[ -f $S/etc/.updated ]"
chk "stamp /var/.updated" "[ -f $S/var/.updated ]"

echo "== 6/6 LỖI TRONG BUILD:"
n=$(grep -cE '^E: |^!! ' build.log); chk "build.log không có dòng E:/!! ($n)" "[ $n -eq 0 ]"

echo
echo "KẾT QUẢ: $PASS đạt, $FAIL hỏng"
