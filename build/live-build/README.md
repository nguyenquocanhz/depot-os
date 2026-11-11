# Build ISO Depot OS

Toàn bộ ISO được sinh ra từ thư mục này bằng **live-build** của Debian.

## Chuẩn bị (một lần, trên Windows)

1. Mở PowerShell (Admin) và cài WSL2 + Debian:
   ```powershell
   wsl --install -d Debian
   ```
   Khởi động lại máy nếu được yêu cầu.
2. Vào Debian (gõ `Debian` trong Start menu), chạy:
   ```bash
   sudo apt update && sudo apt install -y live-build
   ```

## Copy code vào WSL (quan trọng!)

KHÔNG build trực tiếp trong `/mnt/d/...` — hệ thống file 9P rất chậm và hay lỗi quyền.
Copy **cả thư mục dự án** (để `auto/build` tìm thấy `dotfiles/` cạnh nó):

```bash
cp -r /mnt/d/SteathOS/depot-os ~/depot-os
cd ~/depot-os/build/live-build
```

Cần ~15GB chỗ trống trong WSL (check: `df -h ~`).

## Build

```bash
lb config          # sinh cấu hình theo auto/config (chạy lại mỗi khi đổi auto/config)
sudo ./auto/build  # tự sync dotfiles/ vào ISO + chmod hooks, rồi lb build
                   # 30–60 phút lần đầu (tải ~2–4GB gói), các lần sau nhanh hơn
```

Kết quả: `live-image-amd64.hybrid.iso` (~1.7GB — live-build 2025 dùng tên này, không còn là `binary-hybrid.iso` cũ).

Lấy ISO về Windows:

```bash
cp live-image-amd64.hybrid.iso /mnt/d/SteathOS/depot-os/depot-os-v0.1-amd64.iso
```

## Test

| Nơi | Cách |
|---|---|
| VirtualBox/VMware | Tạo VM amd64, boot thẳng ISO — BIOS mặc định; bật **Enable EFI** để test UEFI |
| Máy thật | Rufus (chọn chế độ **DD**) hoặc Ventoy hoặc balenaEtcher ghi ISO ra USB |

Cả hai chuẩn boot (EFI + Legacy) nằm trong cùng một ISO — chi tiết cơ chế + ma trận test dual-boot: [docs/boot-efi-legacy.md](../../docs/boot-efi-legacy.md)

Đăng nhập live mặc định của Debian: user `user`, mật khẩu `live`.
Cài ra ổ cứng: menu ứng dụng → **Cài Depot OS** (icon cũng nằm trên desktop ở phiên live) — pkexec sẽ hỏi mật khẩu `live`.

## Dọn dẹp giữa các lần build

```bash
lb clean
```

**Quan trọng — live-build 2025 dùng `.build/` (thư mục ẩn) làm stage markers:**
- Sau khi build thành công, `lb build` lần sau sẽ **"Skipping ... already done"** và bỏ qua gần như mọi giai đoạn (ISO cũ giữ nguyên).
- Nếu `lb clean` không đủ (vẫn thấy Skipping), xoá thẳng: `rm -rf .build binary binary.modified_timestamps` rồi build lại. Chroot (`chroot/`) giữ nguyên — thành quả cài tay trong chroot (theme, compile) được bảo toàn.
- `auto/build` có kiểm chứng ISO phải **mới hơn thời điểm bắt đầu build** — ISO cũ sẽ bị báo lỗi thay vì qua mặt.

## Sửa cái gì, ở đâu?

| Muốn thay đổi | Sửa file |
|---|---|
| Giao diện / rice | **`dotfiles/`** (nguồn duy nhất — `auto/build` tự sync vào ISO) |
| Thêm/bỏ gói | `config/package-lists/depot-os.list.chroot` |
| File hệ thống tĩnh | `config/includes.chroot/...` |
| Tham số ISO (codename, kernel cmdline...) | `auto/config` |
| Wallpaper (album 5 tấm SVG + `album.list`) | `scripts/gen-wallpapers.py` → `config/includes.chroot/usr/share/backgrounds/depot-os/` |

Sau khi sửa, chạy lại `lb config && sudo ./auto/build`.

## Lỗi thường gặp

- **`lb build` dừng giữa chừng**: chạy `lb clean` rồi build lại; xem `build.log`.
- **Panel XFCE trống khi đăng nhập**: file `dotfiles/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml` chưa khớp — xóa file đó, dựng panel bằng tay trong live, rồi copy `~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml` từ live về `dotfiles/config/xfce4/xfconf/xfce-perchannel-xml/` (cách chuẩn, luôn khớp phiên bản XFCE).
- **Gói nào báo không tồn tại**: gỡ khỏi list hoặc đổi tên (tên gói Debian đôi khi đổi giữa các phiên bản — tra tại packages.debian.org).
