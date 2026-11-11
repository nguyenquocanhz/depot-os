# Tinh chỉnh phần mềm cho i3 Gen 2 (Sandy Bridge)

Mục tiêu phần cứng: **Core i3-2xxx** (2C/4T), **HD Graphics 3000**, **16GB RAM**.
Điểm yếu = CPU & GPU. Điểm dư = RAM. Mọi quyết định tối ưu xoay quanh điều đó.

## 1. GPU — HD Graphics 3000

| Lớp | Chọn | Chi tiết |
|---|---|---|
| Driver X | `xserver-xorg-video-intel` (DDX `intel`, accel SNA) | Nhanh hơn modesetting trên GPU cũ; file cấu hình `20-intel.conf` bật TearFree |
| OpenGL | Mesa **crocus** | DDX crocus cho Gen6 → OpenGL 3.3 |
| Giải mã video | VA-API qua **`i965-va-driver`** | HD 3000 giải mã được H.264 (YouTube chủ yếu H.264) — bật được |
| Lưu ý | KHÔNG dùng `intel-media-va-driver` | Đó là driver cho Gen8+ (Broadwell trở lên), vô dụng trên SNB |

- Firefox cần bật bằng tay (hook Phase 2): `media.ffmpeg.vaapi.enabled=true`, `media.hardware-video-decoding.enabled=true`.
- mpv: `hwdec=vaapi` trong `~/.config/mpv/mpv.conf`.
- Nếu driver `intel` lỗi gì đó: xóa `20-intel.conf` là quay về modesetting (an toàn).

## 2. RAM & swap

- 16GB là rất dư. Dùng **zram (zstd, 50% = 8GB)** thay swap đĩa — khi cần swap, nén vào RAM nhanh hơn trăm lần so với HDD.
- `vm.swappiness=100` (trên zram thì swap nhiều cũng không sao), `vm.vfs_cache_pressure=50` (giữ cache inode/dentry, mở file nhanh hơn).
- Nếu máy có SSD nhỏ: gần như không cần swap đĩa.

## 3. CPU

- Không dùng "tối ưu" kiểu prelink/preload — hiệu ứng ảo, thêm phức tạp.
- Kernel: mặc định Debian trước. Nếu muốn thử: **zen/Liquorix** (preempt cao hơn → desktop mượt khi multitask) — so sánh bằng cảm giác thực tế + `systemd-analyze` rồi mới giữ.
- `intel-microcode` bắt buộc (bản vá microcode cho SNB vẫn đang phát hành).

## 4. Desktop nhẹ nhưng đẹp

- XFCE idle ~600–700MB; Plasma 6 ~1.1GB; GNOME ~1.5GB+ → XFCE.
- Hiệu ứng đẹp mà rẻ: picom (fade, shadow, vsync) — không chạy hiệu ứng animation nặng.
- Font **Inter** render mịn, Noto cho đầy đủ tiếng Việt.
- xfwm4 tắt compositor nội bộ (để picom đảm nhiệm — tránh 2 compositor đánh nhau).

## 5. Kỳ vọng hiệu năng thực tế

| Hạng mục | Kỳ vọng |
|---|---|
| RAM sau đăng nhập | 600–750MB |
| Boot → desktop (SSD) | 20–40s (HDD: 60–90s) |
| YouTube 1080p H.264 | CPU 25–40% (VA-API), không xé màn |
| Lướt 20 tab + LibreOffice | Vẫn còn ~8–10GB RAM trống |

## 6. Đề xuất phần cứng

- **SSD là nâng cấp đáng giá nhất** nếu máy còn HDD — hơn mọi tinh chỉnh phần mềm.
- Quạt/vệ sinh tản nhiệt: i3 Gen 2 cũ, throttle nhiệt là nguyên nhân "giật" phổ biến nhất.
