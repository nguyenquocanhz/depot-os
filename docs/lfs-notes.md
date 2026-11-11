# Ghi chú học Linux From Scratch (LFS) — cho người làm Depot OS

> Mục đích: LFS là **trường học** (hiểu Linux từ đáy), live-build là **nhà máy** (sản xuất ISO).
> Học LFS song song với Depot OS — lấy kiến thức áp ngược để debug boot/Calamares/kernel.

## 1. LFS 12.4 — con số thực tế

| Hạng mục | Con số |
|---|---|
| Bản stable hiện tại | **LFS 12.4** (có 2 biến thể: SysVinit và systemd — học branch **systemd** vì khớp Depot OS) |
| Số gói build tay | ~90–100 gói (binutils, gcc, glibc, kernel...) |
| Host tối thiểu | 4 core, 8GB RAM, toolchain đúng phiên bản (`version-check.sh` kiểm tra hộ) |
| Đĩa | ~15–20GB (sources + build tree + system) |
| Thời gian build thuần | máy hiện đại 1–3h với `-j4+`; **i3 Gen 2: 6–15h machine time** |
| Thời gian thực tế | vài tuần buổi tối (đọc + gõ + sửa lỗi từng chương) |

**Host trên Windows**: build được trong **WSL2 Debian** nhưng WSL không boot kernel được — kết quả phải boot bằng **VirtualBox** (gắn đĩa ảo chứa LFS) hoặc máy thật. Vì vậy: build trong WSL2, cài grub vào đĩa ảo, test boot trong VirtualBox.

## 2. Lộ trình sách (chương nào học được gì)

| Chương | Nội dung | Khớp với phần nào của Depot OS |
|---|---|---|
| 1–2 | Chuẩn bị host, partition đĩa ảo, tải sources | Hiểu partition — nền để hiểu Calamares |
| 3 | Tải gói + patch | Reproducible build |
| 4–5 | Temp toolchain (binutils/glibc/gcc pass 1–2, cross-compile) | Vì sao có file `filesystem.squashfs` đúng kiến trúc |
| 6 | Chroot + build hệ thống cơ bản | Cái live-build làm hộ bạn trong `chroot/` |
| 7 | Cấu hình system, bootscripts | /etc/fstab, hostname, locale |
| 8 | **Kernel + grub** | Chính là `grub-pc-bin`, initramfs, boot EFI/Legacy đã làm |
| 9–10 | The End — boot lần đầu | "Bung ra" hoàn chỉnh không qua Calamares |

Sau LFS → **BLFS** nếu muốn đi tiếp (X/Wayland, XFCE, network, browser...) — đọc sẽ nhận ra: đó chính là hàng trăm gói live-build đã tự động hoá.

## 3. Triết lý Linus Torvalds — 6 nguyên tắc ứng vào Depot OS

1. **"Talk is cheap. Show me the code."**
   → ISO chạy được > thiết kế đẹp. Phase 0 xong phải boot thật; không bàn thêm tính năng khi chưa có ISO đầu tiên.

2. **"WE DO NOT BREAK USERSPACE"** — quy luật lớn nhất của kernel.
   → Đừng bao giờ làm vỡ cái đang hoạt động: đổi theme/dotfiles phải test trên live trước khi sync; update kernel phải giữ app người dùng chạy ngon; config mới phải tương thích bản cũ.

3. **Pragmatism > purity** — Linus chửi các giải pháp "đẹp về lý thuyết, không giải quyết vấn đề thật".
   → Tối ưu phải đo trước (Phase 2): bật zram/swappiness vì có lý do, không vì "nghe pro". TPM để **tuỳ chọn** vì máy đích không có — không bắt buộc cái người dùng không cần.

4. **Solve the problem at hand** — Git sinh ra trong 2 tuần vì BitKeeper đứt, Linus cần tool ngay.
   → Không build trước tính năng cho tương lai tưởng tượng (YAGNI). Roadmap có là đủ, code khi đến lượt.

5. **"Good code is its own best documentation."**
   → Config/comment viết cho người đọc sau: ghi **vì sao** (đã làm trong dotfiles — mỗi dòng setting lạ đều có chú thích lý do).

6. **Release early, release often.**
   → ISO mộc với branding Debian vẫn chia được cho bạn bè test ngay; sửa dần theo phản hồi. Đừng đợi hoàn hảo rồi mới ra mắt.

## 4. Tài nguyên (link đã bấm kiểm tra 2026-10-29)

### Tiếng Việt
- **Hướng dẫn LFS tiếng Việt (Tim99-LFS)** — https://linuxfromscratch.vn — sách LFS dịch + làm lại theo kiểu hướng dẫn, kèm **image VirtualBox cho từng bước** để hồi phục khi làm hỏng. Không chính thức nhưng là tài liệu LFS tiếng Việt tốt nhất hiện có
- Giới thiệu LFS trên Wikipedia tiếng Việt — https://vi.wikipedia.org/wiki/Linux_From_Scratch

### Tiếng Anh (chính thức)
- Sách LFS online — https://www.linuxfromscratch.org/lfs/view/stable/ (BLFS: https://www.linuxfromscratch.org/blfs/)
- **"Kernel management style" — chính văn Linus Torvalds** — https://www.kernel.org/doc/html/latest/process/management-style.html
- **"HOWTO do Linux kernel development"** — https://www.kernel.org/doc/html/latest/process/howto.html
- Archivo LKML tìm cụm **"we do not break userspace"** (53 kết quả, 2011–2025) — https://lore.kernel.org/lkml/?q=%22we+do+not+break+userspace%22
- TED 2016 *"The mind behind Linux"* — https://www.ted.com/talks/linus_torvalds_the_mind_behind_linux (có transcript; bật phụ đề trong nút CC)

### Thẳng thắn về cái KHÔNG có
- **Không có bản dịch tiếng Việt chính thức của LFS** (bản .vn là của cá nhân/cộng đồng) — luôn đối chiếu bản gốc khi lệnh khác nhau giữa các phiên bản
- **Sách *Just for Fun* của Linus chưa có bản dịch tiếng Việt** — chỉ có bản gốc tiếng Anh
- **Debian chưa có trang chính thức tiếng Việt** (debian.org/vi không tồn tại)
- Wiki ubuntu-vn.org cũ đã chết — không truy cập được nữa

## 5. Thứ tự đề xuất cho bạn

1. Tuần này: đọc Chương 1–3 + chuẩn bị VM (đĩa 30GB, 4 core, 8GB) — không build vội
2. Song song: **đừng dừng Depot OS** — cứ build ISO đầu tiên (Phase 0) bằng live-build
3. Buổi tối rảnh: theo LFS chương 4–6 (toolchain + chroot) — phần "ma thuật" nhất
4. Khi LFS boot được trong VirtualBox → quay lại Depot OS sẽ thấy mọi mảnh (initramfs, grub, squashfs, fstab) quen như chữ viết tay
