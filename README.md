# Depot OS

Distro Linux riêng làm máy hàng ngày, thay thế Windows — tối ưu **mượt và đẹp trên cấu hình yếu**: Intel Core i3 Gen 2 (Sandy Bridge, 2 nhân/4 luồng, HD Graphics 3000) + 16GB RAM.

## Triết lý thiết kế

1. **Mượt là ưu tiên số 1** — mọi thành phần phải nhẹ: XFCE thay GNOME, picom thay compositor nặng, PipeWire với latency thấp, zram thay swap trên đĩa.
2. **Đẹp không phải đắt** — theme tối hiện đại (Arc-Dark + Papirus + Inter), boot sạch sẽ, desktop gọn như Windows (menu + taskbar dock).
3. **Nguồn ổn định** — base Debian 13 (trixie) stable: kho mềm khổng lồ, không bao giờ "update xong vỡ máy".
4. **Build được lại 100%** — toàn bộ ISO sinh ra từ config trong repo này (live-build), không remaster tay.
5. **Rice qua dotfiles** — toàn bộ giao diện nằm trong `dotfiles/`, version control được, sync tự động vào ISO lúc build, và share độc lập cho máy Linux khác bằng một lệnh.

## Quyết định công nghệ

| Thành phần | Chọn | Lý do |
|---|---|---|
| Base | Debian 13 (trixie) | Ổn định, kho lớn, live-build chuẩn |
| Desktop | XFCE 4.20 | ~600–700MB RAM idle, nhẹ nhất trong nhóm "đầy đủ" |
| WM thay thế | i3 + i3bar/i3status + rofi | Phiên "Depot OS (i3)" chọn lúc đăng nhập: idle ~250–350MB, thao tác bàn phím, vua ricing |
| In ấn | CUPS + Gutenprint/HPLIP/Brother/Samsung + AirPrint | GUI `system-config-printer`; in PDF như Windows; quét bằng Simple Scan |
| Bộ gõ tiếng Việt | fcitx5 + Unikey | `fcitx5-unikey` (Unikey chính chủ cho Linux), sẵn cả hai phiên XFCE & i3 |
| Compositor | picom (GLX + vsync) | Bỏ chữ xé màn hình, mượt video, fade đẹp |
| Display manager | LightDM + gtk-greeter | Nhẹ hơn GDM/SDDM |
| Âm thanh | PipeWire + WirePlumber | Thay PulseAudio, latency thấp |
| GPU (HD 3000) | driver `intel` (SNA) + Mesa crocus + VA-API i965 | Giải mã video bằng phần cứng, không xé màn |
| RAM/swap | zram (zstd, 50% RAM) | 16GB RAM + zram = gần như không cần swap đĩa |
| Bảo mật | LUKS + TPM 2.0 auto-unlock (kiểu BitLocker) | Tự bật trên máy có TPM 2.0; máy cũ không TPM vẫn chạy như thường |
| Boot | ISO hybrid: UEFI (+ Secure Boot qua shim) & Legacy BIOS | Calamares tự chọn GPT+ESP hay MBR theo firmware; dual-boot Windows qua os-prober |
| Installer | Calamares 3.3 + calamares-settings-debian | Trình cài đồ hoạ kiểu Windows; branding riêng ở Phase 3 |
| Kernel | mặc định Debian → cân nhắc zen/Liquorix sau | Đo trước, tối ưu sau |

> KDE Plasma 6 *rất đẹp* nhưng yêu cầu OpenGL 3.x mà HD 3000 chạy qua driver crocus thì gần giới hạn — để làm thí nghiệm ở Phase 2, không dùng làm mặc định.

## Cấu trúc repo

```
depot-os/
├── README.md                  ← file này
├── ROADMAP.md                 ← lộ trình 5 phase
├── dotfiles/                  ← NGUỒN DUY NHẤT của rice giao diện (share riêng được)
│   ├── install.sh             ← cài vào $HOME trên máy Linux bất kỳ, tự backup
│   └── config/                ← XFCE, i3, i3status, rofi, dunst, picom, fontconfig, GTK, mpv, terminal
├── docs/
│   └── hardware-tuning.md     ← chi tiết tinh chỉnh Sandy Bridge
├── results/                   ← số đo thật theo phiên bản/máy (sinh bởi `depot-results`)
├── packages/                  ← phần của Depot đóng thành gói .deb cài riêng được trên Debian / Ubuntu
│   └── depot-capslock/        ← ô báo Caps Lock: nguồn (pkg/), build.sh, tệp .deb đã build
└── build/live-build/          ← cấu hình live-build (build trong WSL2)
    ├── auto/                  ← config/build/clean — build tự sync dotfiles
    ├── config/
    │   ├── package-lists/     ← danh sách gói cài vào ISO
    │   ├── hooks/             ← vd: cài dotfiles vào /etc/skel cho user mới
    │   └── includes.chroot/   ← file tĩnh + usr/share/depot-os/ (sinh ra lúc build)
    └── README.md              ← hướng dẫn build ISO từng bước
```

## Luồng rice giao diện

1. Sửa trong `dotfiles/` (theme, panel, picom, font...).
2. Chạy build — `auto/build` tự sync `dotfiles/` vào ISO, hook chép vào `/etc/skel` cho mọi user mới.
3. Muốn share rice cho ai: push thư mục `dotfiles/` lên GitHub — đối tác chỉ cần `bash install.sh`.

## Build ISO đầu tiên (tóm tắt)

Cần WSL2 với Debian — hướng dẫn đầy đủ: [build/live-build/README.md](build/live-build/README.md)

```bash
cd build/live-build
lb config
sudo ./auto/build     # tự sync dotfiles + chmod hooks rồi build; ~30–60 phút lần đầu
# kết quả: live-image-amd64.hybrid.iso (~1.7GB)
```

## Lấy mã từ kho git

- **Nên clone trong WSL/Linux.** Theme WhiteSur có 56 liên kết tượng trưng (symlink). Git trên Windows mặc định chép chúng thành tệp chữ chứa đường dẫn, build ra theme hỏng; muốn clone trên Windows thì bật Developer Mode rồi `git clone -c core.symlinks=true …`.
- Mọi tệp chữ giữ xuống dòng LF (`.gitattributes`) — script và hook dính CRLF thì build trong WSL hỏng.
- Kho **không** chứa ISO đã build, bản nén `.7z` và thư mục máy ảo `vmware/` (xem `.gitignore`).
- Trên máy gốc (cây nguồn nằm ở ổ NTFS, symlink do WSL tạo): 56 symlink được đánh dấu `skip-worktree` để git trên Windows không đụng tới. Cần sửa chúng thì bỏ dấu (`git update-index --no-skip-worktree <tệp>`) rồi làm bằng git trong WSL.

## Thông số mục tiêu

- RAM khi vừa đăng nhập: **< 700MB (XFCE) · ~350MB (i3) / 16GB**
- Boot đến desktop (SSD): **< 40 giây**
- Video YouTube 1080p: giải mã bằng VA-API, CPU < 40%
- Size ISO: **~1.5–2GB**

## Giấy phép

Mã của Depot OS trong kho này — script, công cụ `depot-*`, hook và cấu hình live-build, dotfiles, tài liệu — phát hành theo
**GNU General Public License phiên bản 3** (GPL-3.0); nguyên văn ở tệp [LICENSE](LICENSE).

Phần của bên thứ ba chép sẵn vào kho giữ giấy phép của tác giả gốc:

- Theme **WhiteSur** (`usr/share/themes/WhiteSur-Dark*`) — của vinceliuice, GPL-3.0.
- Tệp chạy **`picom-animated`** (`usr/bin/picom-animated`) — bản picom của pijulius, MPL-2.0 và MIT.

Các gói Debian và ứng dụng mà ISO cài thêm lúc build không nằm trong kho này và theo giấy phép riêng của từng gói.
