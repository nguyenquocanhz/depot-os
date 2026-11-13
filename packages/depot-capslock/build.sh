#!/bin/sh
# Đóng gói depot-capslock thành tệp .deb nằm cạnh script này.
#   sh packages/depot-capslock/build.sh
# Chạy trên Debian / Ubuntu hoặc trong WSL (cần dpkg-deb, python3). Không cần quyền root.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
SRC="$HERE/pkg"
command -v dpkg-deb >/dev/null || { echo "build.sh: cần dpkg-deb (gói dpkg)" >&2; exit 1; }

PKG=$(sed -n 's/^Package: //p' "$SRC/DEBIAN/control")
VER=$(sed -n 's/^Version: //p' "$SRC/DEBIAN/control")
ARCH=$(sed -n 's/^Architecture: //p' "$SRC/DEBIAN/control")
DEB="${PKG}_${VER}_${ARCH}.deb"
[ "$(sed -n "s/^VERSION = '\(.*\)'$/\1/p" "$SRC/usr/bin/depot-capslock")" = "$VER" ] \
    || { echo "build.sh: VERSION trong usr/bin/depot-capslock khác Version trong DEBIAN/control ($VER)" >&2; exit 1; }

# Dựng cây gói trên đĩa Linux: thư mục nguồn có thể nằm trên NTFS (/mnt/d), nơi quyền file không dùng được.
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
P="$T/$PKG"
cp -r "$SRC" "$P"

CR=$(printf '\r')
if grep -rlI "$CR" "$P" >/dev/null 2>&1; then
    echo "build.sh: có tệp dính xuống dòng kiểu Windows (CRLF):" >&2
    grep -rlI "$CR" "$P" | sed "s|^$P|  pkg|" >&2
    exit 1
fi
python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' "$P/usr/bin/depot-capslock"

find "$P" -type d -exec chmod 755 {} +
find "$P" -type f -exec chmod 644 {} +
chmod 755 "$P/usr/bin/depot-capslock"

SIZE=$(du -sk --exclude=DEBIAN "$P" | cut -f1)
sed -i "/^Architecture:/a Installed-Size: $SIZE" "$P/DEBIAN/control"
( cd "$P" && find . -path ./DEBIAN -prune -o -type f -printf '%P\n' | LC_ALL=C sort | xargs md5sum > DEBIAN/md5sums )
chmod 644 "$P/DEBIAN/md5sums"

# -Zxz: dpkg cũ (Debian 11, Ubuntu 20.04) không đọc được gói nén zstd mà Ubuntu mới dùng làm mặc định
dpkg-deb --root-owner-group -Zxz --build "$P" "$T/$DEB" >/dev/null
cp "$T/$DEB" "$HERE/$DEB"
( cd "$HERE" && sha256sum "$DEB" > "$DEB.sha256" )

echo "== $HERE/$DEB"
dpkg-deb --info "$HERE/$DEB" | sed -n '/^ Package:/,$p'
dpkg-deb --contents "$HERE/$DEB"
cat "$HERE/$DEB.sha256"
