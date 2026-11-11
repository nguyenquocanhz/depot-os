# Mã hoá đĩa LUKS + TPM 2.0 (kiểu BitLocker)

## Tư duy thiết kế

**TPM 2.0 là tính năng tuỳ chọn, không phải điều kiện sống.** Máy đích chính của Depot OS (i3 Gen 2) không có TPM 2.0 — nên mọi thứ liên quan TPM phải **tự kích hoạt khi có, im lặng khi không có**, và hệ thống luôn khởi động bình thường.

| Máy | Hành vi |
|---|---|
| Có TPM 2.0 (máy từ ~Gen 8 trở lên) | LUKS auto-unlock qua TPM — bật máy vào thẳng desktop, không gõ mật khẩu đĩa |
| Không có TPM (i3 Gen 2...) | LUKS hỏi passphrase như thường, hoặc không mã hoá — không sao cả |

Kernel Debian đã có sẵn driver TPM (`tpm_crb`/`tpm_tis`, tự load). Package list chỉ thêm userspace: `tpm2-tools` (kéo theo libtss2) + `systemd-cryptsetup` (hỗ trợ option `tpm2-device` trong crypttab).

## TPM 2.0 cho được gì?

- **Auto-unlock LUKS**: key mã hoá được *seal* vào TPM, gắn với PCR (dấu vân tay của chuỗi boot). Firmware/bootloader/grub bị can thiệp → PCR đổi → TPM từ chối mở key. Đúng cơ chế BitLocker của Windows.
- **Measured boot + Secure Boot**: kết hợp với shim-signed đã có, chuỗi boot được kiểm tra hết.
- **Nơi cất secrets**: tương lai có thể dùng cho VPN cert, password manager key...

## Quy trình sau khi cài (máy CÓ TPM 2.0)

```bash
# 0. Kiểm tra TPM
ls /dev/tpm*                       # thấy /dev/tpm0 và /dev/tpmrm0
systemd-cryptenroll --tpm2-device=list

# 1. Enroll key TPM vào partition LUKS (đã mã hoá lúc cài bằng Calamares)
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+12 /dev/sdXN

# 2. Báo crypttab dùng TPM
# /etc/crypttab:  thêm option  tpm2-device=auto  vào dòng crypt
sudo nano /etc/crypttab

# 3. Cập nhật initramfs
sudo update-initramfs -u
```

PCR dùng: `0` firmware, `2` option ROM, `7` Secure Boot state, `12` kernel cmdline — combo chuẩn chống lại boot-kit.

## Test KHÔNG cần máy có TPM thật

- **VirtualBox 7**: Settings → System → **TPM** → chọn v2.0 → máy ảo có TPM 2.0 ảo để test trọn quy trình.
- **QEMU/KVM**: `-device tpm-tis,tpmdev=emu` + `swtpm socket`.
- Máy thật i3 Gen 2: kiểm chứng nhánh "không có TPM" — hệ vẫn boot, LUKS passphrase bình thường.

## Đang ở đâu trong roadmap

- v0: stack TPM + tài liệu quy trình tay (mục này).
- Phase 3 (planned): checkbox mã hoá trong Calamares được kiểm chứng, và first-boot wizard tự enroll TPM khi phát hiện `/dev/tpmrm0` — người dùng không cần gõ lệnh nào ở trên.
