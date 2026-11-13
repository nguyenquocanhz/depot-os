#!/bin/bash
# Depot OS — kiểm chứng v0.26 (chạy trong WSL Debian, sau ./auto/build): depot-notify hết lỗi "ô đen" — compositor
# (picom) tắt giữa chừng thì ô báo Caps Lock vẽ ra ô đen trơn, khung Thông báo bên cạnh tối còn 30 %.
# Nguyên nhân và cách sửa: xem ROADMAP, mục 14/11/2026. Phần chạy thật (bật / tắt picom, bấm Caps Lock) thử trong
# phiên XFCE overlay và trên máy ảo; script này chỉ kiểm ISO mang đúng bản đã sửa.
# Chạy thêm scripts/check-v25.sh … check-v19.sh cho phần cũ.
LB=${LB:-/root/depot-os/build/live-build}
cd "$LB" || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
chk() { if eval "$2" 2>/dev/null; then ok "$1"; else bad "$1"; fi; }

ISO=live-image-amd64.hybrid.iso
SQ=binary/live/filesystem.squashfs
S=/tmp/sqv26; rm -rf $S
INC=config/includes.chroot
unsquashfs -f -d $S $SQ usr/bin/depot-notify usr/bin/picom etc/xdg/autostart/depot-notify.desktop var/lib/dpkg/status >/dev/null 2>&1
N=$S/usr/bin/depot-notify

echo "== ISO:"
chk "ISO tồn tại, đóng sau squashfs (không phải ISO cũ)" "[ -s $ISO ] && [ \$(stat -c %Z $ISO) -ge \$(stat -c %Z $SQ) ]"

echo "== DEPOT-NOTIFY HẾT LỖI Ô ĐEN:"
chk "depot-notify trong ISO giống repo, chạy được, đúng cú pháp Python" "cmp -s $N $INC/usr/bin/depot-notify && [ -x $N ] && python3 -c \"import ast; ast.parse(open('$N', encoding='utf-8').read())\""
chk "độ mờ cửa sổ đặt ở MỘT chỗ (WinBase.fade): không có compositor thì luôn 1.0" "[ \$(grep -c 'def fade(self, a):' $N) = 1 ] && grep -q 'Gtk.Widget.set_opacity(self, a if self.composited() else 1.0)' $N && [ \$(grep -c 'Gtk.Widget.set_opacity(self' $N) = 1 ]"
chk "fade nằm trong lớp WinBase (thẻ thông báo, khung bên cạnh, ô báo Caps Lock dùng chung)" "awk '/^class /{c=\$2} /def fade\\(self, a\\):/{print c}' $N | grep -q '^WinBase('"
chk "compositor bật / tắt giữa chừng → đổi cách bo góc VÀ đặt lại độ mờ (on_composited)" "grep -q \"scr.connect('composited-changed', lambda \\*_: self.on_composited())\" $N && awk '/def on_composited/{f=1;next} f&&/def /{f=0} f' $N | grep -q 'self.fade(self.alpha)'"
chk "khung bên cạnh mở / đóng qua fade() (trước đây tự gọi set_opacity sau khi hỏi compositor)" "[ \$(grep -c 'self.fade(0.3 + 0.7 \\* k)' $N) = 1 ] && [ \$(grep -c 'self.fade(1 - 0.7 \\* k)' $N) = 1 ]"
chk "depot-notify vẫn tự chạy cùng phiên, picom vẫn có trong ISO" "[ -s $S/etc/xdg/autostart/depot-notify.desktop ] && [ -x $S/usr/bin/picom ]"

echo
echo "v0.26: $PASS đạt, $FAIL lỗi"
[ $FAIL = 0 ]
