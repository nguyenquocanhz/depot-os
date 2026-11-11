# Kết quả đo — Depot OS

Số đo thật, không phải ước lượng. Mỗi lần đo là một thư mục `results/<phiên-bản>/<máy>/`, sinh ra bởi
`depot-results` (có sẵn trong ISO từ v0.11, nguồn: `build/live-build/config/includes.chroot/usr/bin/depot-results`).

## Cách đo

1. Boot Depot OS (live hoặc đã cài), đăng nhập phiên cần đo (XFCE hoặc i3).
2. Để máy **rảnh 3–5 phút**, không mở app nào.
3. Mở terminal:

   ```bash
   depot-results i3gen2-ssd --version v0.11
   ```

   Đo luôn video 1080p (tải sẵn một file H.264 `.mp4`):

   ```bash
   depot-results i3gen2-ssd --version v0.11 --video ~/Videos/test-1080p.mp4 --seconds 30
   ```

4. Kết quả nằm ở `~/depot-results/v0.11/i3gen2-ssd/` — chép nguyên thư mục về đây
   (`results/v0.11/i3gen2-ssd/`) và điền phần **Điều kiện** trong `SUMMARY.md`.

Tên máy chỉ gồm `[a-z0-9-]`, nên ghi rõ máy + ổ đĩa + phiên: `i3gen2-ssd-xfce`, `i3gen2-ssd-i3`, `vmware-bios`.

## Mỗi file nói gì

| File | Nội dung |
|---|---|
| `SUMMARY.md` | Bảng so với thông số mục tiêu trong README gốc (RAM, boot, VA-API, CPU video) |
| `sysinfo.txt` | CPU, GPU + driver, RAM, kernel cmdline, phiên desktop, live/đã cài, zram, compositor |
| `memory.txt` | `free -m` + RAM từng tiến trình (PSS) — biết ngay ai ăn RAM |
| `boot.txt` | `systemd-analyze`, 20 unit chậm nhất, critical-chain, và `ldconfig.service` có bị bỏ qua không |
| `gpu.txt` | `vainfo` + `glxinfo -B` |
| `video.txt` | mpv có dùng vaapi không, CPU trung bình toàn máy khi phát |

Script không gửi gì ra ngoài. RAM từng tiến trình đủ cả root khi `sudo` không cần mật khẩu (user live mặc định có).
