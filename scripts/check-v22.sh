#!/bin/bash
# Depot OS — kiểm chứng v0.22 (chạy trong WSL Debian, sau ./auto/build): vùng lưu mã hoá trên USB kiểu Tails
# (depot-persist + depot-persist-helper, cryptsetup trong initramfs, tham số persistence ở menu boot).
# Chạy thêm scripts/check-v21.sh, check-v20.sh, check-v19.sh cho phần cũ.
LB=${LB:-/root/depot-os/build/live-build}
cd "$LB" || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
chk() { if eval "$2" 2>/dev/null; then ok "$1"; else bad "$1"; fi; }

ISO=live-image-amd64.hybrid.iso
SQ=binary/live/filesystem.squashfs
S=/tmp/sqv22; rm -rf $S
INC=config/includes.chroot
FILES="usr/bin/depot-persist usr/libexec/depot-persist-helper usr/bin/depot-live-setup"
DATA="usr/share/polkit-1/actions/tech.wrenevil.depot.persist.policy etc/polkit-1/rules.d/50-depot-persist.rules
usr/share/applications/depot-persist.desktop"
unsquashfs -f -d $S $SQ $FILES $DATA usr/lib/live/boot/9990-misc-helpers.sh var/lib/dpkg/status >/dev/null 2>&1
# Từ v0.25 depot-pin gắn mục chuột phải "Ghim / bỏ ghim trên taskbar" vào mọi file .desktop có trong menu lúc build:
# file .desktop trong ISO dài hơn bản trong repo đúng phần đó — so thì bỏ phần đó ra.
nopin() { awk '/^\[Desktop Action depot-pin\]/ { skip = 1 } !skip' "$1" | sed -e 's/^\(Actions=.*\)depot-pin;$/\1/' -e '/^Actions=$/d'; }
same() { cmp -s "$S/$1" "$INC/$1" && return 0; case "$1" in *.desktop) [ "$(nopin "$S/$1")" = "$(cat "$INC/$1")" ] ;; *) return 1 ;; esac; }
installed() { awk -v p="$1" '$0 == "Package: " p { f = 1; next } /^Package:/ { f = 0 } f && /^Status: install ok installed/ { ok = 1 } END { exit !ok }' $S/var/lib/dpkg/status; }
INITRD=$(ls binary/live/initrd.img* 2>/dev/null | head -1)
LIST=/tmp/sqv22-initrd.list; lsinitramfs "$INITRD" > $LIST 2>/dev/null
G=binary/boot/grub/grub.cfg
L=binary/isolinux/live.cfg

echo "== ISO:"
chk "ISO tồn tại, đóng sau squashfs (không phải ISO cũ)" "[ -s $ISO ] && [ \$(stat -c %Z $ISO) -ge \$(stat -c %Z $SQ) ]"
chk "ISO kiểu hybrid: bảng phân vùng dos, còn số phân vùng trống cho vùng lưu" "sfdisk -d $ISO | grep -q '^label: dos' && [ \$(sfdisk -d $ISO | grep -c ' : ') -le 3 ]"

echo "== CÔNG CỤ (có trong ISO, giống repo):"
for f in $FILES; do chk "$f" "[ -x $S/$f ] && same $f && sh -n $S/$f"; done
for f in $DATA; do chk "$f" "same $f"; done
chk "launcher ẩn trên máy đã cài (NoDisplay), phiên USB mới hiện" "grep -qx 'NoDisplay=true' $S/usr/share/applications/depot-persist.desktop && grep -q \"sed '/^NoDisplay=/d'\" $S/usr/bin/depot-live-setup"
chk "polkit: helper đúng đường dẫn" "grep -q '/usr/libexec/depot-persist-helper' $S/usr/share/polkit-1/actions/tech.wrenevil.depot.persist.policy"
for p in cryptsetup-bin cryptsetup-initramfs e2fsprogs fdisk util-linux yad; do chk "gói $p" "installed $p"; done

unsquashfs -f -d $S $SQ etc/udev/rules.d/61-depot-persist-hide.rules >/dev/null 2>&1
chk "udev: phân vùng vùng lưu không hiện thành icon ổ đĩa trên desktop (từ v0.22.1)" "grep -q 'ID_FS_LABEL}==\"persistence\", ENV{UDISKS_IGNORE}=\"1\"' $S/etc/udev/rules.d/61-depot-persist-hide.rules"

echo "== INITRAMFS (mở khoá vùng lưu lúc boot):"
chk "initrd có lệnh cryptsetup" "grep -qE '(^|/)sbin/cryptsetup\$' $LIST"
chk "initrd có dm-crypt" "grep -q 'dm-crypt\\.ko' $LIST"
chk "initrd có thuật toán mã hoá xts (LUKS2 mặc định aes-xts)" "grep -q '/xts\\.ko' $LIST"
chk "initrd có 9990-misc-helpers.sh của live-boot" "grep -q 'usr/lib/live/boot/9990-misc-helpers.sh' $LIST"
chk "live-boot hỗ trợ lukslabel" "grep -q lukslabel $S/usr/lib/live/boot/9990-misc-helpers.sh"
chk "câu hỏi mật khẩu đã Việt hoá (hook 0726)" "grep -q 'Nhập mật khẩu vùng lưu trên USB' $S/usr/lib/live/boot/9990-misc-helpers.sh && grep -q 'Sai mật khẩu vùng lưu' $S/usr/lib/live/boot/9990-misc-helpers.sh"
chk "boot không splash không kẹt ở bước hỏi mật khẩu (chỉ dùng plymouth khi --ping được)" "grep -q 'if \\[ -x /bin/plymouth \\] && plymouth --ping' $S/usr/lib/live/boot/9990-misc-helpers.sh"
chk "9990-misc-helpers.sh còn đúng cú pháp sau khi sửa" "sh -n $S/usr/lib/live/boot/9990-misc-helpers.sh"

echo "== MENU BOOT:"
chk "GRUB: mục mặc định mở vùng lưu (none,lukslabel)" "awk '/^menuentry \"Chạy Depot OS \\(thử/ { f = 1 } f && /linux/ { print; exit }' $G | grep -q 'persistence persistence-encryption=none,lukslabel'"
chk "GRUB: có mục không mở vùng lưu (nopersistence)" "awk '/^menuentry \"Chạy Depot OS — không mở vùng lưu trên USB\"/ { f = 1 } f && /linux/ { print; exit }' $G | grep -q ' nopersistence\$'"
chk "GRUB: Cài tự động, Chẩn đoán, chế độ an toàn KHÔNG mở vùng lưu" "[ \$(grep -c 'persistence-encryption' $G) = 1 ]"
chk "isolinux: mục mặc định mở vùng lưu, có mục nopersistence" "[ \$(grep -c 'persistence-encryption=none,lukslabel' $L) = 1 ] && grep -q '^label live-amd64-nopersist\$' $L && grep -q ' nopersistence\$' $L"
chk "isolinux: mục mặc định vẫn là live-amd64" "awk '/^label live-amd64\$/ { f = 1 } f && /menu default/ { ok = 1 } /^label / && !/live-amd64\$/ { f = 0 } END { exit !ok }' $L"

echo "== THÔNG BÁO:"
unsquashfs -f -d $S $SQ usr/bin/depot-notify >/dev/null 2>&1
chk "depot-notify giống repo, đúng cú pháp" "same usr/bin/depot-notify && python3 -c \"import ast; ast.parse(open('$S/usr/bin/depot-notify', encoding='utf-8').read())\""
chk "bấm vào thông báo mở app / trang web đã gửi" "grep -q 'def open_source' $S/usr/bin/depot-notify && grep -q 'def find_app' $S/usr/bin/depot-notify"

echo
echo "v0.22: $PASS đạt, $FAIL lỗi"
[ $FAIL = 0 ]
