# Boot Diag — main lên được CPU đời nào

`depot-bootdiag` đọc main, chipset, BIOS, CPU và khe RAM bằng công cụ có sẵn (dmidecode, lspci, /proc/cpuinfo,
/sys/class/dmi), rồi kết luận bằng tiếng Việt: lên được Core i 2xxx (Sandy Bridge) / 3xxx (Ivy Bridge) không,
nên mua CPU nào, RAM tối đa bao nhiêu. Bảng tra hiện chỉ có **socket LGA1155** (chipset Intel dòng 6 và dòng 7).
Socket khác thì in ra socket/chipset và báo chưa có bảng tra. Tool chỉ đọc: ngoài 1 file báo cáo `.txt` thì không ghi gì.

## 3 cách chạy

| Cách | Làm gì |
|---|---|
| Trong desktop (live hoặc máy đã cài) | Menu ứng dụng → **Chẩn đoán main (Boot Diag)**, hoặc gõ `depot-bootdiag` (tool tự xin sudo để đọc dmidecode) |
| Mục boot của USB | Ở menu boot chọn **Chẩn đoán phần cứng (main, CPU nâng cấp được)** (phím `p`). Máy vào màn chữ, in báo cáo, lưu ra USB rồi chờ phím: `Enter` xem lại · `D` vào desktop live · `R` khởi động lại · `T` tắt máy · `L` lưu lại |
| Lưu báo cáo | `depot-bootdiag --save` (lưu vào gốc USB FAT32/exFAT/NTFS nếu ghi được, không thì vào thư mục nhà) · `depot-bootdiag --save ~/Desktop` |

Tên file: `depot-bootdiag-<model main>-<ngày giờ>.txt`. Nếu USB được ghi bằng `dd`/Rufus kiểu ISO thì phân vùng của
nó chỉ đọc được, không ghi được: khi đó cắm thêm một USB FAT32 khác. USB Ventoy thì tool sẽ thử ghi vào phân vùng exFAT.
Khi boot bằng mục chẩn đoán mà không có USB nào ghi được, báo cáo nằm ở `/var/log/depot/` (trong RAM, tắt máy là mất).

Gửi dữ liệu thô cho người khác xem, hoặc để bổ sung bảng tra:

```bash
sudo depot-bootdiag --dump ~/bootdiag-may-nay
```

```bash
depot-bootdiag --sample ~/bootdiag-may-nay
```

## Cách đọc kết luận

- **[ĐƯỢC]**: lắp CPU đó là chạy.
- **[CẦN BIOS]**: main H61/H67/P67/Z68 lên Ivy (Core i 3xxx) được nhưng phải có BIOS hỗ trợ Ivy. Tool đoán theo
  ngày BIOS: trước 9/2011 thì chắc chắn chưa có, 9/2011–5/2012 thì chưa chắc, từ 6/2012 thì nhiều khả năng đã có.
  Bản BIOS tối thiểu chính xác phải xem trong **CPU Support List** của main trên trang hãng. Nhớ nâng BIOS
  **trước** khi tháo CPU cũ, vì muốn nạp BIOS thì main phải đang chạy được với CPU đời 2.
- **[KHÓ]**: B65/Q65/Q67 không được Intel hỗ trợ Ivy. Một vài main bán lẻ vẫn có BIOS chạy Ivy, còn máy đồng bộ thì
  gần như không có.
- **[KHÔNG]**: main có trong bảng "main đã biết", và hãng không ra BIOS Ivy cho nó.
- PCIe 3.0 và RAM DDR3-1600 chính thức chỉ có khi lắp CPU Ivy trên main dòng 7. iGPU đời 2 là HD 2000/3000,
  đời 3 là HD 2500/4000. Xeon E3-1230 / 1230 v2 không có iGPU nên phải có card màn hình rời.

## Máy NEC Mate J (main MSI MS-7770)

Đây là main MSI làm riêng cho NEC. Bản Mate J MJ33L/L-D (10/2011) dùng chipset **B65**, có 4 khe DDR3, NEC bán kèm
i3-2120. Thùng máy mỏng, card low-profile, không có khe PCIe x16. Kết luận của tool cho main này:

- Lên **i7-2600S** (4 nhân/8 luồng, 65 W) hoặc i5-2500S là hợp lý nhất. i7-2600 (95 W) thì phải kiểm nhiệt
  sau khi lắp: chạy `depot-hwmon --kiem-tra 5`.
- Ivy (i7-3770…) **chưa xác nhận** chạy được, vì B65 không được Intel hỗ trợ và NEC không có BIOS Ivy công khai.
  File BIOS trên forum sửa main là bản dump dùng để cứu main, không nên nạp để "mở" Ivy. MS-7770 và MS-7770N1 là
  hai bản khác nhau.
- RAM đang có 2+4+2+4 = 12 GB. Cắm hai thanh giống nhau vào 2 khe cùng màu thì hai kênh bằng nhau (6 | 6 GB).
  Lên 16 GB: thay hai thanh 2 GB bằng hai thanh 4 GB. Tối đa 4×8 GB = 32 GB. NEC ghi tối đa 4 GB, nhưng đó chỉ là
  giới hạn của cấu hình lúc bán.

## Đã kiểm / chưa kiểm

- Đã kiểm bằng bộ test: 7 bộ dữ liệu **giả lập** (`tools/bootdiag/make-samples.sh`) cộng một dump **thật** lấy từ máy
  ảo VMware (`tools/bootdiag/dump-vmware-that/`). Chạy `bash tools/bootdiag/test.sh` trong WSL/Linux: 60/60 đạt.
  Các bộ giả lập gồm NEC MS-7770 B65, ASUS H61, Gigabyte B75, Dell OptiPlex 990 Q67, MSI Z68 đang chạy i7-3770,
  Gigabyte H81 (LGA1150) và máy ảo VMware.
- Đã kiểm trên ISO v0.18, máy ảo VMware Workstation, cả boot **BIOS** (isolinux) lẫn **UEFI** (GRUB):
  - Mục boot chạy đúng: kernel nhận `depot.bootdiag depot.noautoinstall`, không có Plymouth, service chiếm tty1
    trước màn đăng nhập, in báo cáo không dấu qua `less`.
  - Không có USB nên báo cáo được lưu vào `/var/log/depot`; phím L lưu thêm một bản.
  - Phím D vào desktop phiên live; service kết thúc `success`, cài tự động không chạy.
  - Phím được gửi vào máy ảo bằng TIOCSTI, vì VMware không nhận phím giả lập từ Windows.
  - Mục boot được chọn bằng một bản ISO **thử** có mục chẩn đoán làm mặc định. Trên ISO thật, phím `p`/mũi tên ở
    menu chưa thử được, cũng vì VMware không nhận phím giả lập.
  - Lỗi tìm ra khi thử và đã sửa: ô RAM rỗng làm lệch cột (hiện "? MT/s"); máy ảo khai báo 128 khe thì danh sách
    quá dài (nay chỉ in khe có RAM và số khe trống); dòng nhắc của `less` bị cắt.
- Ngoài ra: đã chạy trong WSL, `--dump`, `--save`, chạy bằng user không có sudo. Hook menu chạy 2 lần không bị nhân
  đôi mục; `grub-script-check` báo hợp lệ.
- **Chưa kiểm**: trên main thật (chưa có dump dmidecode của máy NEC), ghi file ra USB thật (cả USB thường lẫn
  Ventoy), bấm chọn mục boot bằng tay trên menu thật.

## File

- `build/live-build/config/includes.chroot/usr/bin/depot-bootdiag`: tool chính, gồm cả bảng tra chipset, CPU và main đã biết
- `.../usr/lib/systemd/system/depot-bootdiag.service`: chạy khi kernel có tham số `depot.bootdiag`
- `.../usr/share/applications/depot-bootdiag.desktop`: lối tắt trên menu ứng dụng
- `config/hooks/normal/1320-depot-bootdiag.hook.chroot`: bật service, kiểm có đủ dmidecode/lspci
- `config/hooks/normal/1321-depot-bootdiag-menu.hook.binary`: thêm mục boot vào GRUB và isolinux
- `config/package-lists/depot-os.list.chroot`: thêm `dmidecode`, `pciutils`
- `tools/bootdiag/`: bộ mẫu giả lập và test

Bổ sung main đã biết: sửa biến `KNOWN_BOARDS` trong `depot-bootdiag`. Mỗi dòng có các cột ngăn bằng `#`:
regex khớp tên máy/main, có lên Ivy không (no/?/yes), thùng mỏng, không có khe x16, ghi chú.

By WrenEvil.tech & nguyenquocanhz (nqatech)
