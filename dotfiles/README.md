# Depot OS — Dotfiles

Rice giao diện của **Depot OS** gom về một chỗ: XFCE (theme/panel/desktop), picom, fontconfig, GTK, mpv, terminal.

Đây là **nguồn duy nhất** — build ISO của Depot OS tự sync thư mục này vào image, còn máy Linux bất kỳ thì cài trực tiếp bằng `install.sh`.

## Ghi chú font macOS

**SF Pro của Apple không được phép đóng gói trong distro** (license cấm redistribute).
Depot OS dùng **Inter** — thay thế chuẩn được cả industry công nhận — kèm fontconfig alias:
mọi app xin `SF Pro Display`, `SF Pro Text`, `Helvetica Neue` hay `-apple-system` đều nhận Inter.
Muốn dùng SF Pro thật: tự tải từ apple.com (diện developer) rồi thả TTF vào `~/.local/share/fonts/`.

## Cài trên máy bất kỳ (Debian/Ubuntu/Fedora...)

```bash
git clone <repo-của-bạn> && cd dotfiles
bash install.sh          # tự backup cấu hình cũ vào ~/.config/depot-os-backup-<thời-gian>/
```

Đăng xuất/đăng nhập lại để áp dụng (hoặc nhanh: `xfce4-panel -r`).

## Cài trên chính Depot OS

Dotfiles nằm sẵn trong hệ thống:

```bash
/usr/share/depot-os/dotfiles/install.sh
```

## Bên trong có gì

| Thư mục | Nội dung |
|---|---|
| `config/xfce4/xfconf/` | **Rice macOS**: theme WhiteSur-Dark, icon WhiteSur, cursor WhiteSur-cursors, font Inter, panel menubar trên (dock = Plank), wallpaper |
| (Plank) | Không còn ở đây: Plank đọc gsettings, cấu hình dock nằm trong `/usr/bin/depot-plank` (tự ẩn, icon 46px, theme trong suốt) |
| `config/xfce4/terminal/` | Terminal tối, scrollback 10k dòng |
| `config/i3/` | Tiling WM: phím tắt (mod = phím Windows), gaps, palette — cho phiên "Depot OS (i3)" |
| `config/i3status/` | Nội dung i3bar: DISK/RAM/CPU/mạng/pin/giờ (polybar chưa có trong Debian 13) |
| `config/rofi/` | Launcher hiện đại (Super+D) |
| `config/dunst/` | Dự phòng: thông báo của dunst khi không chạy `depot-notify` (i3 giờ dùng depot-notify, `$mod+n` mở khung Thông báo) |
| `config/autostart/` | `xfce4-notifyd.desktop` (Hidden): không tự chạy xfce4-notifyd, thông báo do `depot-notify` lo |
| `config/xfce4/panel/genmon-7.rc`, `genmon-9.rc` | Nút chuông thông báo trên panel (genmon chạy `depot-notify-bell`) |
| `config/fcitx5/` | Bộ gõ tiếng Việt: Unikey (Telex, kiểu mới hoà/thuý, tự trả lại từ tiếng Anh). Ctrl+Space hoặc Ctrl+Shift bật/tắt, mặc định tắt, bật một lần áp dụng mọi cửa sổ |
| `config/picom/` | `picom-animations.conf`: gốc cấu hình compositor. `depot-effects` ("Hiệu ứng hình ảnh") lọc bỏ khối bóng/mờ dần/animation người dùng tắt rồi chạy bản ở `~/.cache/depot/picom.conf` |
| `config/fontconfig/` | Render chữ mịn (hintslight + rgb), ưu tiên Inter/Noto |
| `config/gtk-3.0/` | Fallback theme cho app GTK chạy ngoài XFCE (quan trọng cho i3!) |
| `config/mpv/` | Bật giải mã video VA-API (điểm vàng trên HD 3000) |

> Các cấu hình i3/i3status/rofi/dunst vô hại trên phiên XFCE (không được đọc), nên install.sh cứ cài cả bộ.
> Wallpaper: album 5 tấm SVG ở `/usr/share/backgrounds/depot-os/` (`scripts/gen-wallpapers.py`), chọn bằng "Hình nền"
> (`depot-wallpaper`). XFCE/LightDM đọc thẳng SVG; phiên i3 gọi `depot-wallpaper --restore` — vẽ SVG ra PNG đúng độ
> phân giải màn hình ở `~/.cache/depot` rồi mới đưa cho feh (feh không đọc được SVG).

## Cách Depot OS dùng thư mục này

1. `build/live-build/auto/build` sync `dotfiles/` vào `config/includes.chroot/usr/share/depot-os/dotfiles/` (được sinh ra lúc build, không commit).
2. Hook `0500-depot-dotfiles` chép `config/` vào `/etc/skel/.config/` → mọi user mới (kể cả user live) nhận đầy đủ.
3. Đổi giao diện = sửa ở đây → chạy lại build. Không sửa file sinh ra trong `build/`.

## Share & showcase

- Push repo này lên GitHub riêng cũng được — ai cần "rice XFCE giống Depot OS" chỉ cần clone + `bash install.sh`.
- Phase 1 (roadmap) sẽ thêm screenshots + wallpaper chuẩn PNG vào đây.
