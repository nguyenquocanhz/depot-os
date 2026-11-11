#!/bin/bash
# Depot OS — kiểm tra tên gói trước khi build (chạy trong WSL Debian)
# Dùng: bash /root/check-pkgs.sh
set -u
cd /root/depot-os-build || { echo "Không có /root/depot-os-build — cp project vào trước"; exit 1; }

PKGS=$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' config/package-lists/depot-os.list.chroot | tr -d '\r' | tr '\n' ' ')
echo "Số gói kiểm tra: $(echo $PKGS | wc -w)"

ERR=$(apt-get install --dry-run -y $PKGS 2>&1 | grep -E 'Unable to locate|^E:' || true)
if [ -n "$ERR" ]; then
    echo "GÓI SAI / KHÔNG TỒN TẠI:"
    echo "$ERR"
else
    echo "TOÀN BỘ TÊN GÓI HỢP LỆ ✓"
fi
