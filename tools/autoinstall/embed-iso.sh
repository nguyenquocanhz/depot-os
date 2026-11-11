#!/bin/bash
# Depot OS — nhúng depot-autoinstall.conf vào gốc một ISO Depot OS có sẵn, KHÔNG build lại (giống chép
# autounattend.xml vào ISO Windows). ISO gốc giữ nguyên; boot UEFI + BIOS + hybrid USB được giữ (xorriso replay).
# By WrenEvil.tech & nguyenquocanhz (nqatech)
#
#   bash embed-iso.sh ISO_GỐC depot-autoinstall.conf ISO_MỚI
#   (WSL: sudo apt install xorriso; đường dẫn Windows dùng /mnt/d/...)
#
# Thư mục depot-files/ cạnh file cấu hình (nếu có) cũng được nhúng theo.
# ⚠ ISO mới mang file có AUTO_START=yes thì máy nào boot nó cũng TỰ XOÁ Ổ sau khi đếm ngược — dán nhãn USB cẩn thận.
set -eu

die() { echo "!! $*" >&2; exit 1; }
[ $# -eq 3 ] || die "cách dùng: bash $0 ISO_GỐC depot-autoinstall.conf ISO_MỚI"
in=$1 conf=$2 out=$3
command -v xorriso >/dev/null || die "thiếu xorriso — cài: sudo apt install xorriso"
[ -f "$in" ] || die "không có $in"
[ -f "$conf" ] || die "không có $conf"
[ "$(readlink -f "$in")" != "$(readlink -f "$out")" ] || die "ISO_MỚI phải khác ISO_GỐC (không ghi đè ISO gốc)"
[ -e "$out" ] && die "$out đã có — xoá trước hoặc chọn tên khác"

# kiểm file trước khi nhúng: dùng chính trình cài nếu có (repo), không thì chỉ kiểm cú pháp cơ bản
here=$(cd "$(dirname "$0")" && pwd)
ai="$here/../../build/live-build/config/includes.chroot/usr/bin/depot-autoinstall"
if [ -f "$ai" ]; then
    bash "$ai" --check "$conf" | head -1
    bash "$ai" --check "$conf" >/dev/null 2>&1 || die "file cấu hình có lỗi — chạy: bash $ai --check $conf"
fi
grep -qiE '^[[:space:]]*AUTO_START[[:space:]]*=[[:space:]]*"?(yes|y|true|1)' "$conf" &&
    echo "⚠  AUTO_START=yes: máy nào boot ISO này cũng tự xoá ổ và cài sau khi đếm ngược."

need=$(( $(stat -c %s "$in") / 1048576 + 64 ))
free=$(df -Pm "$(dirname "$(readlink -f "$out")")" | awk 'NR==2{print $4}')
[ "$free" -gt "$need" ] || die "không đủ chỗ: cần ~${need} MB, còn ${free} MB"

maps=(-map "$conf" /depot-autoinstall.conf)
[ -d "$(dirname "$conf")/depot-files" ] && maps+=(-map "$(dirname "$conf")/depot-files" /depot-files)

xorriso -indev "$in" -outdev "$out" -boot_image any replay "${maps[@]}" -commit 2>&1 | grep -vE '^xorriso : UPDATE' | tail -4
echo ">> xong: $out ($(du -h "$out" | cut -f1)). Ghi ra USB như ISO thường (Rufus chế độ DD, Ventoy, Etcher)."
