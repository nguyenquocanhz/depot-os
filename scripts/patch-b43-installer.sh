#!/bin/sh
# Depot OS — đóng lại firmware-b43-installer để build ISO không chết khi nguồn firmware Broadcom hỏng.
# By WrenEvil.tech & nguyenquocanhz (nqatech)
#
# live-build tự cài MỌI gói firmware của Debian (kể cả contrib/firmware-b43-installer). Script cài của gói này tải
# broadcom-wl-6.30.163.46.tar.bz2 từ MỘT bản phát hành GitHub (minios-linux/b43-firmware); tải lỗi → exit 1 → dpkg lỗi →
# cả lb build thất bại (08/11/2026: GitHub trả 504 liên tục, OpenWrt đã gỡ file). live-build không cho loại gói
# firmware qua cấu hình (BLOCKLIST_FIRMWARE viết cứng trong functions/firmwarelists.sh).
# Bản đóng lại "+depot1": tải lỗi thì CHỈ CẢNH BÁO, exit 0 — ISO không có firmware b43 (Wi-Fi Broadcom BCM43xx đời cũ);
# máy cần thì có mạng chạy: sudo dpkg-reconfigure firmware-b43-installer. Debian ra bản mới hơn thì apt tự thay.
# Chạy trong WSL (cần dpkg-deb, apt): sh scripts/patch-b43-installer.sh → config/packages.chroot/*.deb
# Hết sự cố: xoá file .deb đó là về gói gốc.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/build/live-build/config/packages.chroot"
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
cd "$W"
apt-get download firmware-b43-installer >/dev/null
deb=$(ls firmware-b43-installer_*.deb)
dpkg-deb -R "$deb" pkg
ver=$(sed -n 's/^Version: //p' pkg/DEBIAN/control)
case $ver in *+depot*) echo "!! đã là bản depot"; exit 1 ;; esac
grep -q 'Some problem occurred during the firmware download' pkg/DEBIAN/postinst || { echo "!! postinst đã đổi — kiểm lại trước khi vá"; exit 1; }
# chỉ khối "tải lỗi": exit 1 → cảnh báo + exit 0 (checksum sai vẫn dừng như cũ)
awk '
    /Some problem occurred during the firmware download/ { print; inb = 1; next }
    inb && /^[ \t]*exit 1$/ { print "\techo \"$0: Depot OS: bỏ qua — chạy lại khi có mạng: dpkg-reconfigure firmware-b43-installer\" 1>&2"; print "\texit 0"; inb = 0; next }
    { print }' pkg/DEBIAN/postinst > postinst.new
cmp -s postinst.new pkg/DEBIAN/postinst && { echo "!! không vá được postinst"; exit 1; }
cat postinst.new > pkg/DEBIAN/postinst
sed -i "s/^Version: .*/Version: ${ver}+depot1/" pkg/DEBIAN/control
sed -i 's/^Maintainer: .*/Maintainer: Depot OS (WrenEvil.tech \& nqatech) — đóng lại từ gói Debian/' pkg/DEBIAN/control
mkdir -p "$OUT"
rm -f "$OUT"/firmware-b43-installer_*.deb
dpkg-deb --root-owner-group -b pkg "$OUT/firmware-b43-installer_${ver#*:}+depot1_all.deb" >/dev/null
echo ">> $OUT/firmware-b43-installer_${ver#*:}+depot1_all.deb (gốc $ver)"
diff -u "$(dpkg-deb -R "$deb" orig >/dev/null; echo orig/DEBIAN/postinst)" pkg/DEBIAN/postinst | sed -n '1,20p'
