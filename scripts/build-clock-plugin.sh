#!/bin/bash
# Depot OS — build plugin đồng hồ taskbar (tools/depot-clock-plugin) cho xfce4-panel của ISO.
# Chạy trong WSL Debian (root), SAU một lần ./auto/build (cần build/live-build/chroot để khớp đúng thư viện Debian 13):
#   bash scripts/build-clock-plugin.sh
# Dựng overlay trên chroot của ISO, cài gói -dev vào overlay (không đụng chroot thật), biên dịch, chép file .so về repo:
#   build/live-build/config/includes.chroot/usr/lib/x86_64-linux-gnu/xfce4/panel/plugins/libdepot-clock.so
# File .so được commit kèm mã nguồn (như picom-animated): build ISO không phải cài ~300 MB gói -dev mỗi lần.
# không dùng set -e: các lệnh umount dọn dẹp được phép lỗi; bước quan trọng tự kiểm bên dưới
REPO=${REPO:-$(cd "$(dirname "$0")/.." && pwd)}
C=${CHROOT:-/root/depot-os/build/live-build/chroot}
SRC=$REPO/tools/depot-clock-plugin/depot-clock-plugin.c
DST=$REPO/build/live-build/config/includes.chroot/usr/lib/x86_64-linux-gnu/xfce4/panel/plugins
OV=/tmp/depot-clockbuild; M=$OV/m
[ -x "$C/usr/bin/gcc" ] || { echo "!! không thấy chroot của ISO ($C) hoặc chroot không có gcc"; exit 1; }
[ -f "$SRC" ] || { echo "!! thiếu $SRC"; exit 1; }

down() {
    for p in $(ls /proc | grep -E '^[0-9]+$'); do r=$(readlink /proc/$p/root 2>/dev/null); [ "$r" = "$M" ] && kill -9 $p 2>/dev/null; done
    sleep 0.4; umount $M/dev/pts 2>/dev/null; umount $M/dev 2>/dev/null; umount $M/sys $M/proc $M/tmp $M/run 2>/dev/null; umount $M 2>/dev/null
    return 0
}
cd /; down; rm -rf $OV/up $OV/work; mkdir -p $OV/up $OV/work $M
mount -t overlay overlay -o lowerdir=$C,upperdir=$OV/up,workdir=$OV/work $M || { echo "!! không dựng được overlay"; exit 1; }
mount -t proc proc $M/proc; mount -t sysfs sysfs $M/sys; mount --bind /dev $M/dev; mount --make-private $M/dev
mount -t devpts -o newinstance,ptmxmode=0666,mode=0620,gid=5 devpts $M/dev/pts; mount -t tmpfs tmpfs $M/tmp; mount -t tmpfs tmpfs $M/run
rm -f $M/etc/resolv.conf; cp -L /etc/resolv.conf $M/etc/resolv.conf
printf '#!/bin/sh\nexit 101\n' > $M/usr/sbin/policy-rc.d; chmod 755 $M/usr/sbin/policy-rc.d
cx() { chroot $M env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root LC_ALL=C DEBIAN_FRONTEND=noninteractive "$@"; }

echo ">> cài gói -dev vào overlay…"
cx apt-get update >/dev/null 2>&1
cx apt-get install -y --no-install-recommends pkg-config libxfce4panel-2.0-dev libxfce4ui-2-dev libxfce4util-dev libgtk-3-dev >/dev/null 2>&1 || { echo "!! cài gói -dev lỗi"; down; exit 1; }
cp "$SRC" $M/tmp/depot-clock-plugin.c
echo ">> biên dịch…"
cx sh -c 'cd /tmp && gcc -O2 -Wall -Wextra -Wno-unused-parameter -fPIC -shared -o libdepot-clock.so depot-clock-plugin.c $(pkg-config --cflags --libs libxfce4panel-2.0 gtk+-3.0) && strip --strip-unneeded libdepot-clock.so' || { echo "!! biên dịch lỗi"; down; exit 1; }
mkdir -p "$DST"
cp $M/tmp/libdepot-clock.so "$DST/libdepot-clock.so"
ls -la "$DST/libdepot-clock.so" | awk '{ print ">> " $NF, $5, "byte" }'
echo ">> ký hiệu đăng ký plugin: $(nm -D "$DST/libdepot-clock.so" | grep -c 'xfce_panel_module_construct\|xfce_panel_module_init')"
echo ">> thư viện cần lúc chạy:"; objdump -p "$DST/libdepot-clock.so" | awk '/NEEDED/ { print "   " $2 }'
down; rm -rf $OV/up $OV/work
echo ">> xong"
