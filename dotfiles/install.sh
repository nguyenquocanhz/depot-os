#!/usr/bin/env bash
# Depot OS dotfiles — cài vào $HOME/.config, tự backup phần bị ghi đè
# Dùng: bash install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/config"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}"

if [ ! -d "$SRC" ]; then
    echo "Lỗi: không tìm thấy thư mục $SRC" >&2
    exit 1
fi

BACKUP="$HOME/.config/depot-os-backup-$(date +%Y%m%d-%H%M%S)"
MADE_BACKUP=0

for item in "$SRC"/*; do
    name="$(basename "$item")"
    target="$DEST/$name"
    if [ -e "$target" ] || [ -L "$target" ]; then
        mkdir -p "$BACKUP"
        mv "$target" "$BACKUP/$name"
        MADE_BACKUP=1
        echo "backup: $target"
    fi
    mkdir -p "$(dirname "$target")"
    cp -a "$item" "$target"
    echo "cài:    $target"
done

echo
if [ "$MADE_BACKUP" = 1 ]; then
    echo "Cấu hình cũ đã được giữ ở: $BACKUP"
    echo "Khôi phục nếu muốn: cp -a \"$BACKUP/.\" \"$HOME/.config/\""
fi
echo "Xong! Đăng xuất/đăng nhập lại để áp dụng (hoặc: xfce4-panel -r)."
