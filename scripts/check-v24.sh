#!/bin/bash
# Depot OS — kiểm chứng v0.24 (chạy trong WSL Debian, sau ./auto/build): "Driver NVIDIA" (depot-nvidia) —
# dò card, chọn kênh driver theo tài liệu Debian + NVIDIA, cài bằng một nút; nối vào "Driver phần cứng".
# Chạy thêm scripts/check-v23.sh, check-v22.sh, check-v21.sh, check-v20.sh, check-v19.sh cho phần cũ.
# Không thay được việc thử trên máy có card NVIDIA thật: ở đây chỉ kiểm file trong ISO và phần chọn driver (lspci giả).
LB=${LB:-/root/depot-os/build/live-build}
cd "$LB" || exit 1
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
chk() { if eval "$2" 2>/dev/null; then ok "$1"; else bad "$1"; fi; }

ISO=live-image-amd64.hybrid.iso
SQ=binary/live/filesystem.squashfs
S=/tmp/sqv24; rm -rf $S
INC=config/includes.chroot
unsquashfs -f -d $S $SQ usr/bin/depot-nvidia usr/bin/depot-drivers usr/share/applications/depot-nvidia.desktop \
  etc/xdg/autostart/depot-nvidia.desktop usr/share/polkit-1/actions/tech.wrenevil.depot.nvidia.policy \
  etc/xdg/menus/xfce-settings-manager.menu etc/skel/.config/i3/config etc/apt/sources.list \
  usr/share/depot-os/driver-pool/kernel usr/share/depot-os/driver-pool/base var/lib/dpkg/status >/dev/null 2>&1
# Từ v0.25 depot-pin gắn mục chuột phải "Ghim / bỏ ghim trên taskbar" vào mọi file .desktop có trong menu lúc build:
# file .desktop trong ISO dài hơn bản trong repo đúng phần đó — so thì bỏ phần đó ra.
nopin() { awk '/^\[Desktop Action depot-pin\]/ { skip = 1 } !skip' "$1" | sed -e 's/^\(Actions=.*\)depot-pin;$/\1/' -e '/^Actions=$/d'; }
same() { cmp -s "$S/$1" "$INC/$1" && return 0; case "$1" in *.desktop) [ "$(nopin "$S/$1")" = "$(cat "$INC/$1")" ] ;; *) return 1 ;; esac; }
installed() { awk -v p="$1" '$0 == "Package: " p { f = 1; next } /^Package:/ { f = 0 } f && /^Status: install ok installed/ { ok = 1 } END { exit !ok }' $S/var/lib/dpkg/status; }
N=$S/usr/bin/depot-nvidia

echo "== ISO:"
chk "ISO tồn tại, đóng sau squashfs (không phải ISO cũ)" "[ -s $ISO ] && [ \$(stat -c %Z $ISO) -ge \$(stat -c %Z $SQ) ]"

echo "== DRIVER NVIDIA (file trong ISO):"
chk "depot-nvidia có trong ISO, chạy được, giống repo, đúng cú pháp" "[ -x $N ] && same usr/bin/depot-nvidia && sh -n $N"
chk "mục 'Driver NVIDIA' trong menu và Cài đặt > Thiết bị" "same usr/share/applications/depot-nvidia.desktop && grep -q '<Filename>depot-nvidia.desktop</Filename>' $S/etc/xdg/menus/xfce-settings-manager.menu"
chk "tự kiểm lúc đăng nhập (XFCE autostart, i3 exec)" "grep -qx 'Exec=depot-nvidia --notify' $S/etc/xdg/autostart/depot-nvidia.desktop && grep -q '^exec --no-startup-id depot-nvidia --notify\$' $S/etc/skel/.config/i3/config"
chk "polkit: hỏi mật khẩu quản trị, đúng đường dẫn lệnh" "same usr/share/polkit-1/actions/tech.wrenevil.depot.nvidia.policy && grep -q '>/usr/bin/depot-nvidia<' $S/usr/share/polkit-1/actions/tech.wrenevil.depot.nvidia.policy && python3 -c \"import xml.dom.minidom; xml.dom.minidom.parse('$S/usr/share/polkit-1/actions/tech.wrenevil.depot.nvidia.policy')\""
chk "'Driver phần cứng' gọi depot-nvidia (đề xuất @nvidia, không còn hỏi nvidia-detect)" "same usr/bin/depot-drivers && grep -q 'depot-nvidia recommend' $S/usr/bin/depot-drivers && grep -q '@nvidia) nvidia=1' $S/usr/bin/depot-drivers && ! grep -q 'nvidia-detect 2>/dev/null' $S/usr/bin/depot-drivers"
for p in pciutils curl yad pkexec mokutil gcc make; do chk "gói $p (depot-nvidia cần)" "installed $p"; done
chk "kho của ISO có contrib + non-free (gói nvidia-driver của Debian nằm ở đó)" "grep -qE '^deb .* trixie main contrib non-free non-free-firmware' $S/etc/apt/sources.list"
# kernel của ISO: lấy theo tên vmlinuz ở binary/live (trong squashfs /lib là symlink tới usr/lib, không bung riêng lib/modules được)
KV=$(ls binary/live/vmlinuz-* 2>/dev/null | sed "s#.*/vmlinuz-##" | sort -V | tail -1)
chk "kho driver trong máy có header đúng kernel của ISO ($KV) — build module không phải chờ tải header" "[ \"\$(cat $S/usr/share/depot-os/driver-pool/kernel)\" = \"$KV\" ] && ls $S/usr/share/depot-os/driver-pool/base/linux-headers-${KV}_*.deb >/dev/null"
chk "đọc apt-cache bằng LC_ALL=C (máy tiếng Việt in 'Ứng cử:' — lỗi gặp khi thử v0.24)" "grep -q 'LC_ALL=C apt-cache policy' $N"
chk "kho NVIDIA đúng bản Debian 13, gói khoá đúng tên" "grep -qx 'NV_REPO=https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64' $N && grep -qx 'NV_KEYRING=cuda-keyring_1.1-1_all.deb' $N"

echo "== CHỌN DRIVER theo thế hệ card (lspci giả, chạy depot-nvidia của ISO):"
F=/tmp/sqv24-fake; rm -rf $F; mkdir -p $F
cat > $F/lspci <<'IN'
#!/bin/sh
vga() { echo "0000:01:00.0 VGA compatible controller [0300]: NVIDIA Corporation $1 [10de:$2] (rev a1)"; }
case "$FAKE" in
    tu117) echo '0000:00:02.0 VGA compatible controller [0300]: Intel Corporation UHD Graphics 630 (Mobile) [8086:3e9b]'
           echo '0000:01:00.0 3D controller [0302]: NVIDIA Corporation TU117M [GeForce GTX 1650 Mobile / Max-Q] [10de:1f91] (rev a1)' ;;
    gp107) vga "GP107 [GeForce GTX 1050 Ti]" 1c82 ;;
    gm107) vga "GM107 [GeForce GTX 750 Ti]" 1380 ;;
    gk107) vga "GK107 [GeForce GTX 650]" 0fc6 ;;
    gf108) vga "GF108 [GeForce GT 430]" 0de1 ;;
    ad107) vga "AD107 [GeForce RTX 4060]" 2882 ;;
    gb205) vga "GB205 [GeForce RTX 5070]" 2f04 ;;
    new)   vga "Device 2c05" 2c05 ;;
    intel) echo '0000:00:02.0 VGA compatible controller [0300]: Intel Corporation HD Graphics 3000 [8086:0102]' ;;
esac
IN
chmod 755 $F/lspci
rec() { FAKE=$1 DEPOT_NVIDIA_LAPTOP=1 PATH=$F:$PATH sh $N recommend 2>/dev/null; }
st() { FAKE=$1 DEPOT_NVIDIA_LAPTOP=1 PATH=$F:$PATH sh $N status 2>/dev/null; }
chk "GTX 1650 (Turing, laptop hai card) → kho NVIDIA, kho Debian là lựa chọn phụ" "[ \"\$(rec tu117)\" = nvidia ] && st tu117 | grep -q 'Cũng dùng được:  kho Debian' && st tu117 | grep -qi 'laptop hai card'"
chk "RTX 4060 (Ada) → kho NVIDIA" "[ \"\$(rec ad107)\" = nvidia ]"
chk "RTX 5070 (Blackwell) → kho NVIDIA, KHÔNG có kênh Debian (dòng 550 không đỡ)" "[ \"\$(rec gb205)\" = nvidia ] && ! st gb205 | grep -q 'Cũng dùng được'"
chk "card mới hơn pci.ids của máy (Device 2c05) → xét theo mã thiết bị → kho NVIDIA" "[ \"\$(rec new)\" = nvidia ]"
chk "GTX 1050 Ti (Pascal) → kho Debian (dòng 550)" "[ \"\$(rec gp107)\" = debian ]"
chk "GTX 750 Ti (Maxwell) → kho Debian (dòng 550)" "[ \"\$(rec gm107)\" = debian ]"
chk "GTX 650 (Kepler) → không đề xuất gì, giữ nouveau" "[ -z \"\$(rec gk107)\" ] && st gk107 | grep -q 'giữ driver nouveau'"
chk "GT 430 (Fermi) → không đề xuất gì" "[ -z \"\$(rec gf108)\" ]"
chk "máy không có card NVIDIA → không đề xuất gì" "[ -z \"\$(rec intel)\" ] && st intel | grep -q 'không có card đồ hoạ NVIDIA'"
chk "depot-nvidia run đặt biến PRIME render offload" "[ \"\$(sh $N run sh -c 'echo \$__NV_PRIME_RENDER_OFFLOAD\$__GLX_VENDOR_LIBRARY_NAME')\" = 1nvidia ]"

echo "== MÀN BOOT ĐỒNG BỘ (logo ở menu boot = khung đầu animation Plymouth, cùng chỗ, cùng cỡ):"
REPO=${REPO:-/root/depot-os}
I=/tmp/isov24; rm -rf $I; mkdir -p $I
xorriso -osirrox on -indev $ISO -extract /boot/grub/config.cfg $I/config.cfg -extract /boot/grub/live-theme/theme.txt $I/theme.txt \
  -extract /boot/grub/splash.png $I/splash.png -extract /isolinux/splash.png $I/isosplash.png >/dev/null 2>&1
unsquashfs -f -d $S $SQ usr/share/plymouth/themes/depot boot/grub/themes/depot etc/default/grub >/dev/null 2>&1
P=$S/usr/share/plymouth/themes/depot
G=$S/boot/grub/themes/depot
INITRD=$(ls binary/live/initrd.img-* 2>/dev/null | head -1)
chk "menu GRUB của ISO chạy ở độ phân giải gốc (gfxmode=auto, không còn 800x600)" "grep -q '^    set gfxmode=auto' $I/config.cfg && ! grep -q 'gfxmode=800x600' $I/config.cfg && grep -q 'gfxpayload=keep' $I/config.cfg"
chk "theme GRUB co ảnh theo chiều cao màn hình (fitheight), ảnh nền 1280x720 RGB" "grep -qx 'desktop-image-scale-method: \"fitheight\"' $I/theme.txt && file $I/splash.png | grep -q '1280 x 720, 8-bit/color RGB'"
chk "ảnh nền isolinux 640x480 RGB" "file $I/isosplash.png | grep -q '640 x 480, 8-bit/color RGB'"
chk "Plymouth: bố cục 'logo', script + quầng đỏ + chữ giống repo" "grep -qx 'LAYOUT_LOGO = 1;.*' $P/depot.script && same usr/share/plymouth/themes/depot/depot.script && same usr/share/plymouth/themes/depot/halo.png && same usr/share/plymouth/themes/depot/wordmark.png"
NF=$(sed -n 's/^FRAMES = \([0-9]*\);.*/\1/p' $P/depot.script)
chk "Plymouth: đủ $NF khung hình, nền trong suốt (RGBA)" "[ \$(ls $P/frame-*.png | wc -l) = \"$NF\" ] && file $P/frame-000.png | grep -q 'RGBA'"
# các tỉ lệ bố cục trong depot.script phải đúng bằng BOOT_* của wrenevil_logo.py — cũng là số dùng để vẽ ảnh menu GRUB
chk "bố cục Plymouth lấy đúng số của ảnh menu boot (BOOT_* trong wrenevil_logo.py)" "python3 - $REPO/design/identity/wrenevil/wrenevil_logo.py $P/depot.script <<'PY'
import re, sys
py = open(sys.argv[1], encoding='utf-8').read(); sc = open(sys.argv[2], encoding='utf-8').read()
def a(n): return float(re.search(r'^%s = ([0-9.]+)' % n, py, re.M).group(1))
def b(n): return float(re.search(r'^%s = ([0-9.]+);' % n, sc, re.M).group(1))
pairs = [('BOOT_LOGO', 'LOGO_FRAC'), ('BOOT_TOP', 'TOP_FRAC'), ('BOOT_HALO_CY', 'HALO_CY'), ('BOOT_HALO_R', 'HALO_R'), ('BOOT_MENU_TOP', 'MENU_TOP')]
sys.exit(0 if all(abs(a(x) - b(y)) < 1e-9 for x, y in pairs) else 1)
PY"
chk "initramfs mang đủ phần mới của theme (halo.png, wordmark.png, khung cuối)" "lsinitramfs $INITRD | grep -q 'themes/depot/halo.png' && lsinitramfs $INITRD | grep -q 'themes/depot/wordmark.png' && lsinitramfs $INITRD | grep -q \"themes/depot/frame-\$(printf %03d \$(($NF - 1))).png\""
chk "GRUB máy đã cài: GRUB_THEME trỏ theme Depot trong /boot, ảnh nền y hệt menu của ISO" "grep -qx 'GRUB_THEME=\"/boot/grub/themes/depot/theme.txt\"' $S/etc/default/grub && grep -qx 'desktop-image: \"splash.png\"' $G/theme.txt && grep -qx 'desktop-image-scale-method: \"fitheight\"' $G/theme.txt && cmp -s $G/splash.png $I/splash.png && [ \$(ls $G/select_*.png | wc -l) = 9 ]"
# boot thử lần đầu trên VMware: lúc nạp nhân GRUB vẽ ô dòng lệnh đen che logo; "quiet" vẫn để lọt dòng lỗi của nhân
xorriso -osirrox on -indev $ISO -extract /boot/grub/grub.cfg $I/grub.cfg >/dev/null 2>&1
chk "ô dòng lệnh của GRUB neo sát đáy màn hình, không che logo lúc nạp nhân (ISO + máy đã cài)" "grep -qx 'terminal-top: \"100%-416\"' $I/theme.txt && grep -qx 'terminal-height: \"400\"' $I/theme.txt && grep -qx 'terminal-top: \"100%-416\"' $G/theme.txt"
chk "mục chạy mặc định: quiet splash + loglevel=3 (không lọt dòng lỗi của nhân ra màn hình); chế độ an toàn không có" "awk '/^menuentry \"Chạy Depot OS \\(thử/{f=1} f && /^\\tlinux/{print; exit}' $I/grub.cfg | grep -q 'quiet splash.* loglevel=3' && ! awk '/chế độ an toàn/{f=1} f && /^\\tlinux/{print; exit}' $I/grub.cfg | grep -q 'loglevel=3'"
chk "máy đã cài: GRUB_CMDLINE_LINUX_DEFAULT có loglevel=3" "grep -qx 'GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash loglevel=3\"' $S/etc/default/grub"
chk "GRUB máy đã cài: vẫn có ảnh nền dự phòng khi không nạp được theme" "grep -q '^GRUB_BACKGROUND=\"/usr/share/images/depot/grub.png\"' $S/etc/default/grub"

echo "== WEBKITGTK trong ISO (v0.24.1: Telegram ở phiên USB báo 'Please install WebKitGTK' khi mở Mini Game):"
unsquashfs -f -d $S $SQ usr/lib/x86_64-linux-gnu/webkit2gtk-4.1 >/dev/null 2>&1
LS=$(unsquashfs -l $SQ usr/lib/x86_64-linux-gnu/libwebkit2gtk-4.1.so.0 usr/lib/x86_64-linux-gnu/libjavascriptcoregtk-4.1.so.0 usr/lib/x86_64-linux-gnu/libgtk-3.so.0 2>/dev/null)
chk "thư viện Telegram tự nạp có trong ISO: libwebkit2gtk-4.1.so.0 (+ javascriptcore, gtk-3)" "echo \"\$LS\" | grep -q 'libwebkit2gtk-4.1.so.0\$' && echo \"\$LS\" | grep -q 'libjavascriptcoregtk-4.1.so.0\$' && echo \"\$LS\" | grep -q 'libgtk-3.so.0\$'"
for p in libwebkit2gtk-4.1-0 libjavascriptcoregtk-4.1-0 bubblewrap xdg-dbus-proxy gstreamer1.0-libav gstreamer1.0-plugins-good; do chk "gói $p (WebKitGTK cần)" "installed $p"; done
chk "tiến trình con của WebKit (WebKitWebProcess, WebKitNetworkProcess) chạy được" "[ -x $S/usr/lib/x86_64-linux-gnu/webkit2gtk-4.1/WebKitWebProcess ] && [ -x $S/usr/lib/x86_64-linux-gnu/webkit2gtk-4.1/WebKitNetworkProcess ]"
chk "cài gọn: không kéo gstreamer1.0-plugins-bad, không thêm bản GTK 4 (libwebkitgtk-6.0-4)" "! installed gstreamer1.0-plugins-bad && ! installed libwebkitgtk-6.0-4"
chk "hook 0728 có trong repo, đúng cú pháp" "sh -n config/hooks/normal/0728-depot-webkit.hook.chroot && grep -q 'no-install-recommends' config/hooks/normal/0728-depot-webkit.hook.chroot"

echo
echo "v0.24: $PASS đạt, $FAIL lỗi"
[ $FAIL = 0 ]
