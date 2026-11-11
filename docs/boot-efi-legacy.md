# Boot đa chuẩn: UEFI + Legacy BIOS & Dual-boot Windows

## 1. File ISO boot được cả hai chuẩn (iso-hybrid)

Một file ISO duy nhất, ghi USB thẳng được (Rufus chế độ DD / balenaEtcher / Ventoy):

| Firmware | Đường boot | Cơ chế |
|---|---|---|
| UEFI (chuẩn EFI) | grub-efi trên ESP ảo của ISO | Hỗ trợ cả **Secure Boot** qua shim (ký bởi Microsoft) |
| Legacy BIOS | isolinux/syslinux | MBR boot, cho máy cũ |

live-build tạo sẵn cả hai đường khi dùng `--binary-images iso-hybrid` — không cần chọn gì lúc build.

## 2. Khi cài: Calamares tự dò firmware

Calamares kiểm tra đang chạy ở chế độ UEFI hay BIOS rồi chọn schema phù hợp:

| Chế độ | Bố cục đĩa | Bootloader cài vào |
|---|---|---|
| UEFI | **GPT** + ESP (FAT32 ~512MB → `/boot/efi`) | `grub-efi-amd64-signed` + shim vào ESP — **không đụng Windows Boot Manager** của bạn, chỉ thêm entry riêng vào UEFI NVRAM |
| Legacy | **MBR (msdos)** | `grub-pc` vào MBR |

Điều kiện đã lo trong package list: trên live phải có **cả hai** `grub-pc-bin` + `grub-efi-amd64-bin` (+ bản signed cho Secure Boot) — thiếu cái nào là cài fail đúng chế độ đó.

## 3. "Bung ra" như thế nào?

1. Live boot: hệ điều hành chạy nguyên từ `filesystem.squashfs` trong ISO (RAM) — **không đụng ổ cứng**.
2. Bấm "Cài Depot OS" → Calamares:
   - Partition module: chia/format đĩa đích theo schema ở trên
   - `unpackfs`: **giải nén `filesystem.squashfs` sang partition đích** — cài offline, không cần mạng
   - `fstab`, `users`, `locale`, `displaymanager`... cấu hình hệ đích
   - `bootloader`: grub-install đúng loại (EFI/BIOS) + `update-grub`
3. Khởi động lại → rút USB → menu grub hiện **Depot OS** và **Windows** (nếu có).

## 4. Dual-boot menu với Windows

grub 2.06+ **tắt os-prober mặc định** — đã bật sẵn trong `/etc/default/grub` (ship vào cả hệ live và hệ cài):

```
GRUB_TIMEOUT=5            # 5 giây chọn hệ, như Windows Boot Manager
GRUB_TIMEOUT_STYLE=menu
GRUB_DISABLE_OS_PROBER=false   # bắt buộc để thấy Windows
GRUB_DISTRIBUTOR="Depot OS"
```

`os-prober` trong package list giúp dò Windows 10/11 + các Linux khác.

## 5. Ma trận test bắt buộc trước khi giao

| Test | Cách |
|---|---|
| BIOS (legacy) | VirtualBox mặc định (không bật EFI) |
| UEFI | VirtualBox: Settings → System → **Enable EFI** |
| UEFI + Secure Boot | Máy thật bật Secure Boot, hoặc QEMU + OVMF với keys |
| Dual-boot EFI | Giả lập: cài Windows lên đĩa ảo trước, rồi cài Depot alongside |
| Dual-boot Legacy | Windows trên MBR, cài alongside |

## 6. Lưu ý thực chiến

- **Chế độ phải khớp đĩa**: đang Legacy + đĩa MBR thì cài Legacy; đang UEFI + đĩa GPT thì cài UEFI. Cài Legacy lên đĩa GPT sẽ cần partition `bios_grub` — Calamares không tự tạo tốt trong mọi trường hợp, tránh đường này.
- Máy mới (Gen 6+) thường tắt CSM: nếu muốn Legacy phải bật CSM trong BIOS setup — nhưng khuyến nghị dùng UEFI luôn, mượt và an toàn hơn.
- Sau cài, nếu Windows không hiện trong menu: boot vào Depot OS, chạy `sudo update-grub` — os-prober sẽ quét lại.
- Boot order sau cài chỉnh trong UEFI Setup (Boot Order) hoặc `efibootmgr` — entry Windows không bị xoá.
