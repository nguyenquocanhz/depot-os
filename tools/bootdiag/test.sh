#!/bin/bash
# Kiểm depot-bootdiag trên bộ mẫu giả lập (make-samples.sh) + hook menu boot trên bản sao grub.cfg/live.cfg.
# Chạy trong Linux/WSL: bash tools/bootdiag/test.sh [đường-dẫn-depot-bootdiag]
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
CFG=$HERE/../../build/live-build/config
BD=${1:-$CFG/includes.chroot/usr/bin/depot-bootdiag}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
bash "$HERE/make-samples.sh" "$TMP/s" >/dev/null
fail=0; n=0
expect() {   # expect MẪU "chuỗi phải có" [...] ; chuỗi bắt đầu bằng ! = KHÔNG được có
    local s=$1 out e; shift
    out=$(TERM=xterm bash "$BD" --sample "$TMP/s/$s" 2>&1)
    for e in "$@"; do
        n=$((n + 1))
        if [ "${e#!}" != "$e" ]; then
            printf '%s' "$out" | grep -qF -- "${e#!}" && { echo "FAIL $s: có \"${e#!}\""; fail=$((fail + 1)); }
        else
            printf '%s' "$out" | grep -qF -- "$e" || { echo "FAIL $s: thiếu \"$e\""; fail=$((fail + 1)); }
        fi
    done
    printf '%s\n' "$out" >"$TMP/$s.txt"
}

expect nec-mate-ms7770-b65 "Intel B65 (dòng 6)" "SOCKET   : LGA1155" "[KHÓ] Intel KHÔNG hỗ trợ Ivy Bridge trên B65" \
    "12 GB (2 + 4 + 2 + 4 GB)" "đang cắm 4/4 khe" "Tối đa: 32 GB = 4 khe × 8 GB" "i7-2600S" "Main không có khe PCIe x16" \
    "MS-7770 làm riêng cho máy NEC" "Lên 16 GB: thay các thanh 2 GB bằng thanh 4 GB" "!Xeon E3-1230 (" "!i7-3770 (" "!i7-3770S (" "theo ghi chú main)" "ngày 27/03/2012"
expect asus-p8h61-m-le-h61 "Intel H61 (dòng 6)" "[CẦN BIOS]" "CHẮC CHẮN phải nâng BIOS" "Tối đa: 16 GB = 2 khe" \
    "Dual channel: kênh A 4 GB = kênh B 4 GB" "H61 không có cổng SATA 6 Gb/s" "Nếu BIOS đã hỗ trợ Ivy: i7-3770 (" "1. i7-2600 ("
expect gigabyte-b75m-d3h-b75 "[ĐƯỢC] chipset dòng 7" "1. i7-3770 (" "Xeon E3-1230 v2" "PCIe 3.0 (khe x16)" \
    "kênh A 6 GB = kênh B 6 GB" "!CẦN BIOS"
expect dell-optiplex-990-q67 "[KHÔNG] hãng máy không ra BIOS" "Dell OptiPlex 790/990" "1. i7-2600 (" "Máy đồng bộ" "!i7-3770 ("
expect msi-z68a-g43-ivy "[ĐƯỢC] máy đang chạy CPU Ivy Bridge" "Ivy Bridge (Core đời 3)" "HD Graphics 4000" "GeForce GT 640" \
    "đã thuộc nhóm mạnh nhất" "rev 04 có thể là bản B2" "Muốn ép xung: bản K (i7-3770K"
expect gigabyte-h81m-s2h-lga1150 "CHƯA CÓ BẢNG TRA" "LGA1150" "H81" "!KẾT LUẬN (socket LGA1155"
expect vmware-workstation "ĐÂY LÀ MÁY ẢO (vmware)" "CHƯA CÓ BẢNG TRA" "!KẾT LUẬN (socket LGA1155" "!0 MT/s"

# dump THẬT (sudo depot-bootdiag --dump) từ máy ảo VMware chạy ISO v0.18: 128 khe ảo, Speed/Manufacturer rỗng
cp -r "$HERE/dump-vmware-that" "$TMP/s/"
expect dump-vmware-that "ĐÂY LÀ MÁY ẢO (vmware)" "(+ 127 khe trống)" "2 GB (2 GB) DRAM · đang cắm 1/128 khe" "!? MT/s" "!RAM slot #5"

# màn chữ: bỏ dấu
n=$((n + 1))
TERM=linux bash "$BD" --sample "$TMP/s/nec-mate-ms7770-b65" | grep -q 'Intel KHONG ho tro Ivy Bridge tren B65' || { echo "FAIL VT: chưa bỏ dấu"; fail=$((fail + 1)); }

# --save vào thư mục
n=$((n + 1))
TERM=xterm bash "$BD" --sample "$TMP/s/nec-mate-ms7770-b65" --save "$TMP/out" >/dev/null
ls "$TMP"/out/depot-bootdiag-MS-7770-*.txt >/dev/null 2>&1 || { echo "FAIL --save: không thấy file"; fail=$((fail + 1)); }

# hook menu boot trên bản sao cấu hình boot (lấy từ lần build trước nếu có, không thì dựng tối thiểu)
mkdir -p "$TMP/b/binary/boot/grub" "$TMP/b/binary/isolinux"
LB=/root/depot-os/build/live-build/binary
if [ -f "$LB/boot/grub/grub.cfg" ]; then
    cp "$LB/boot/grub/grub.cfg" "$TMP/b/binary/boot/grub/"; cp "$LB/isolinux/live.cfg" "$TMP/b/binary/isolinux/"
    [ -f "$LB/boot/grub/loopback.cfg" ] && cp "$LB/boot/grub/loopback.cfg" "$TMP/b/binary/boot/grub/"
else
    printf 'menuentry "Live system (amd64)" --hotkey=l {\n\tlinux\t/live/vmlinuz boot=live components quiet splash\n\tinitrd\t/live/initrd.img\n}\n' >"$TMP/b/binary/boot/grub/grub.cfg"
    printf 'label live-amd64\n\tmenu label ^Live system (amd64)\n\tmenu default\n\tlinux /live/vmlinuz\n\tinitrd /live/initrd.img\n\tappend boot=live components quiet splash\n' >"$TMP/b/binary/isolinux/live.cfg"
fi
( cd "$TMP/b" && sh "$CFG/hooks/normal/1321-depot-bootdiag-menu.hook.binary" >/dev/null && sh "$CFG/hooks/normal/1321-depot-bootdiag-menu.hook.binary" >/dev/null )
for f in "$TMP"/b/binary/boot/grub/grub.cfg "$TMP"/b/binary/isolinux/live.cfg; do
    n=$((n + 1))
    c=$(grep -c 'depot.bootdiag' "$f")
    [ "$c" = 1 ] || { echo "FAIL hook: $f có $c dòng depot.bootdiag (cần 1, chạy hook 2 lần)"; fail=$((fail + 1)); }
    n=$((n + 1))
    grep 'depot.bootdiag' "$f" | grep -qw splash && { echo "FAIL hook: $f còn splash"; fail=$((fail + 1)); }
done
if [ -n "${BD_OUT:-}" ]; then   # BD_OUT=thư-mục: giữ lại báo cáo + cấu hình boot đã patch để xem
    mkdir -p "$BD_OUT"; cp "$TMP"/*.txt "$BD_OUT/"; cp -r "$TMP/b/binary" "$BD_OUT/"
fi

echo "$((n - fail))/$n đạt"
[ "$fail" = 0 ]
