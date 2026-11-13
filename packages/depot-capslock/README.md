# depot-capslock — ô báo Caps Lock của Depot OS, đóng thành gói `.deb`

Mỗi lần bấm Caps Lock, một ô vuông bo góc hiện trên màn hình hơn một giây rồi tự tắt:

- **bật** → ổ khoá đóng + chữ `A`
- **tắt** → ổ khoá mở + chữ `a`

Ô báo vẽ bằng cairo (không cần bộ icon nào), không chiếm bàn phím, chuột bấm xuyên qua được.
Đây là ô báo có sẵn trong Depot OS (`depot-notify`), tách ra để cài được trên máy Debian / Ubuntu bất kỳ.

| | |
|---|---|
| Tệp cài | [`depot-capslock_1.0_all.deb`](depot-capslock_1.0_all.deb) (kèm [`.sha256`](depot-capslock_1.0_all.deb.sha256)) — cũng có ở [GitHub Releases, bản `depot-capslock-1.0`](https://github.com/nguyenquocanhz/depot-os/releases/tag/depot-capslock-1.0) |
| Viết cho | Debian, Ubuntu và các bản dựa trên chúng có GTK 3.22 trở lên — phiên **X11**: XFCE, MATE, Cinnamon, LXQt, i3, Openbox (mới thử trên Debian 13 + XFCE, xem cuối trang) |
| Cần | `python3`, `python3-gi`, `python3-gi-cairo`, `gir1.2-gtk-3.0` (apt tự kéo); nên có `fonts-inter` |
| Không chạy | phiên Wayland (GNOME / KDE mặc định): Wayland không báo trạng thái Caps Lock cho chương trình X11 |

## Cài

Tải `depot-capslock_1.0_all.deb` ở mục Assets của [bản phát hành `depot-capslock-1.0`](https://github.com/nguyenquocanhz/depot-os/releases/tag/depot-capslock-1.0)
(hoặc lấy tệp nằm ngay trong thư mục này), rồi:

```bash
sudo apt install ./depot-capslock_1.0_all.deb
```

Trên Depot OS: bấm đúp tệp `.deb` → **Chương trình và tính năng** → Cài.

Gói tự chạy cùng phiên làm việc từ lần đăng nhập sau. Muốn có ngay, không cần đăng xuất:

```bash
depot-capslock &
```

i3 không đọc thư mục tự khởi động — thêm vào `~/.config/i3/config`:

```
exec --no-startup-id depot-capslock
```

## Dùng

```
depot-capslock            chạy nền, hiện ô báo mỗi khi bật / tắt Caps Lock
depot-capslock --test     hiện thử "bật" rồi "tắt", xong thoát
depot-capslock --status   in on / off
depot-capslock --force    vẫn chạy trên Depot OS và ở phiên Wayland
depot-capslock --version
```

Tuỳ chỉnh trong `~/.config/depot-capslock.conf`, mỗi dòng `KHOÁ=giá trị`, có hiệu lực ngay lần bấm sau:

```
POSITION=top        # top (mặc định) | center | bottom
HOLD=1.3            # số giây ô báo nằm trên màn hình
ENABLED=0           # tạm tắt mà không gỡ gói
```

**Trên Depot OS** ô báo này đã có sẵn trong `depot-notify`, nên `depot-capslock` tự nhường và thoát
(không thì ra hai ô chồng nhau). Cài gói trên Depot OS vì thế không đổi gì — gói dành cho máy khác.

## Gỡ

```bash
sudo apt remove depot-capslock
```

## Đóng gói lại

Nguồn nằm trong [`pkg/`](pkg) — đúng cây thư mục sẽ nằm trên máy, cộng `DEBIAN/control`:

```
pkg/DEBIAN/control                               tên gói, phiên bản, gói phụ thuộc
pkg/DEBIAN/conffiles                             tệp tự khởi động là tệp cấu hình (xoá / sửa thì nâng cấp không ghi đè)
pkg/usr/bin/depot-capslock                       chương trình (Python + GTK 3)
pkg/etc/xdg/autostart/depot-capslock.desktop     tự chạy cùng phiên làm việc
```

Sửa xong thì tăng `Version` trong `control` và `VERSION` trong chương trình (script kiểm hai số phải khớp), rồi:

```bash
sh packages/depot-capslock/build.sh
```

Chạy trên Debian / Ubuntu hoặc trong WSL, không cần root. Script dựng cây gói ở thư mục tạm trên đĩa Linux
(để quyền file đúng dù nguồn nằm trên ổ Windows), từ chối tệp dính CRLF, tính `Installed-Size` và `md5sums`,
nén xz, ghi tệp `.deb` và `.sha256` cạnh script.

Phát hành bản mới: commit, đẩy lên `main`, rồi tạo bản phát hành với thẻ `depot-capslock-<phiên bản>` kèm hai tệp đó
(thẻ đặt theo tên gói để không lẫn với thẻ phiên bản ISO):

```bash
gh release create depot-capslock-1.1 packages/depot-capslock/depot-capslock_1.1_all.deb packages/depot-capslock/depot-capslock_1.1_all.deb.sha256 --target main --title "depot-capslock 1.1"
```

Các bản đã phát hành: <https://github.com/nguyenquocanhz/depot-os/releases>

Mã vẽ ổ khoá chép từ lớp `LockOSD` trong `usr/bin/depot-notify` của Depot OS — đổi hình ở bên nào thì đổi luôn bên kia.

## Đã thử

Trong phiên XFCE của ISO v0.25 (Xvfb, bấm phím bằng `xdotool`), 31 phép kiểm: cài bằng `apt-get install ./tệp.deb`,
quyền tệp, `dpkg --verify`, bật / tắt Caps Lock → ô báo hiện đúng hình rồi tự tắt, `POSITION` / `HOLD` / `ENABLED`,
có và không có compositor, chỉ một bản chạy nền, tự nhường trên Depot OS, gỡ và purge.
**Chưa thử**: bàn phím thật, Ubuntu và Debian ngoài Depot, các môi trường khác XFCE, nhiều màn hình.
