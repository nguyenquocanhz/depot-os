#!/bin/bash
# Sinh bộ dữ liệu mẫu GIẢ LẬP cho depot-bootdiag --sample (định dạng giống dmidecode 3.x / lspci -nn / /proc/cpuinfo).
# Máy ảo VMware/WSL không có chipset thật nên kiểm bảng tra bằng các mẫu này. Số liệu (BIOS, mã RAM…) là dựng lại
# cho giống thật, KHÔNG phải dump từ máy thật — dump thật: sudo depot-bootdiag --dump THƯ_MỤC.
# Chạy: bash make-samples.sh [THƯ_MỤC]   (mặc định: samples/ cạnh file này)
set -eu
OUT=${1:-$(dirname "$0")/samples}
T=$'\t'
H=0

hdl() { H=$((H + 1)); printf 'Handle 0x%04X, DMI type %s, %s bytes\n' "$H" "$1" "$2"; }
head_() { printf '# dmidecode 3.6\nGetting SMBIOS data from sysfs.\nSMBIOS 2.7 present.\n\n'; H=0; }
bios()  { hdl 0 24; printf 'BIOS Information\n%sVendor: %s\n%sVersion: %s\n%sRelease Date: %s\n%sROM Size: 8 MB\n\n' "$T" "$1" "$T" "$2" "$T" "$3" "$T"; }
sys()   { hdl 1 27; printf 'System Information\n%sManufacturer: %s\n%sProduct Name: %s\n%sVersion: %s\n%sSerial Number: To be filled by O.E.M.\n\n' "$T" "$1" "$T" "$2" "$T" "$3" "$T"; }
board() { hdl 2 15; printf 'Base Board Information\n%sManufacturer: %s\n%sProduct Name: %s\n%sVersion: %s\n%sSerial Number: To be filled by O.E.M.\n\n' "$T" "$1" "$T" "$2" "$T" "$3" "$T"; }
proc()  {   # SOCKET_DES UPGRADE VERSION CORES THREADS MAXMHZ
    hdl 4 42
    printf 'Processor Information\n%sSocket Designation: %s\n%sType: Central Processor\n%sManufacturer: Intel\n%sVersion: %s\n%sMax Speed: %s MHz\n%sStatus: Populated, Enabled\n%sUpgrade: %s\n%sCore Count: %s\n%sThread Count: %s\n\n' \
        "$T" "$1" "$T" "$T" "$T" "$3" "$T" "$6" "$T" "$T" "$2" "$T" "$4" "$T" "$5"
}
slot()  { hdl 9 17; printf 'System Slot Information\n%sDesignation: %s\n%sType: %s\n%sCurrent Usage: Available\n\n' "$T" "$1" "$T" "$2" "$T"; }
arr()   { hdl 16 23; printf 'Physical Memory Array\n%sLocation: System Board Or Motherboard\n%sUse: System Memory\n%sError Correction Type: None\n%sMaximum Capacity: %s\n%sNumber Of Devices: %s\n\n' "$T" "$T" "$T" "$T" "$1" "$T" "$2"; }
mem()   {   # LOCATOR BANK SIZE(MB|0) SPEED MANUF PART
    hdl 17 34
    if [ "$3" = 0 ]; then
        printf 'Memory Device\n%sTotal Width: Unknown\n%sSize: No Module Installed\n%sForm Factor: DIMM\n%sLocator: %s\n%sBank Locator: %s\n%sType: Unknown\n%sSpeed: Unknown\n\n' "$T" "$T" "$T" "$T" "$1" "$T" "$2" "$T" "$T"
    else
        printf 'Memory Device\n%sTotal Width: 64 bits\n%sSize: %s MB\n%sForm Factor: DIMM\n%sLocator: %s\n%sBank Locator: %s\n%sType: DDR3\n%sType Detail: Synchronous\n%sSpeed: %s MT/s\n%sManufacturer: %s\n%sPart Number: %s\n%sConfigured Memory Speed: %s MT/s\n\n' \
            "$T" "$T" "$3" "$T" "$T" "$1" "$T" "$2" "$T" "$T" "$T" "$4" "$T" "$5" "$T" "$6" "$T" "$4"
    fi
}
cpuinfo() {  # NAME MODEL THREADS CORES MHZ
    local i
    for ((i = 0; i < $3; i++)); do
        printf 'processor\t: %d\nvendor_id\t: GenuineIntel\ncpu family\t: 6\nmodel\t\t: %s\nmodel name\t: %s\nstepping\t: 7\ncpu MHz\t\t: %s\nsiblings\t: %s\ncpu cores\t: %s\nflags\t\t: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr sse sse2 ht lm avx\n\n' \
            "$i" "$2" "$1" "$5" "$3" "$4"
    done
}
meminfo() { printf 'MemTotal:       %s kB\n' "$1"; }

SNB_HOST='00:00.0 Host bridge [0600]: Intel Corporation 2nd Generation Core Processor Family DRAM Controller [8086:0100] (rev 09)'
IVB_HOST='00:00.0 Host bridge [0600]: Intel Corporation Xeon E3-1200 v2/3rd Gen Core processor DRAM Controller [8086:0150] (rev 09)'
HD2000='00:02.0 VGA compatible controller [0300]: Intel Corporation 2nd Generation Core Processor Family Integrated Graphics Controller [8086:0102] (rev 09)'
HD4000='00:02.0 VGA compatible controller [0300]: Intel Corporation Xeon E3-1200 v2/3rd Gen Core processor Graphics Controller [8086:0162] (rev 09)'
CPT_SATA='00:1f.2 SATA controller [0106]: Intel Corporation 6 Series/C200 Series Chipset Family 6 port Desktop SATA AHCI Controller [8086:1c02] (rev 05)'
PPT_SATA='00:1f.2 SATA controller [0106]: Intel Corporation 7 Series/C210 Series Chipset Family 6-port SATA Controller [AHCI mode] [8086:1e02] (rev 04)'
lpc() { printf '00:1f.0 ISA bridge [0601]: Intel Corporation %s [8086:%s] (rev %s)\n' "$1" "$2" "$3"; }

mk() { D=$OUT/$1; rm -rf "$D"; mkdir -p "$D"; echo "none" >"$D/virt.txt"; }

# 1. Máy của người dùng: NEC Mate J (main MSI MS-7770, B65), i3-2120, RAM 2+4+2+4 = 12 GB
mk nec-mate-ms7770-b65
{ head_; bios "American Megatrends Inc." "R1.06" "03/27/2012"; sys "NEC" "PC-MJ33LLZCD" "FAB-1"
  board "NEC" "MS-7770" "1.0"; proc "CPU 1" "Socket LGA1155" "Intel(R) Core(TM) i3-2120 CPU @ 3.30GHz" 2 4 3300
  slot "PCIE1" "x1 PCI Express"; slot "PCIE2" "x1 PCI Express"; slot "PCI1" "32-bit PCI"
  arr "32 GB" 4
  mem DIMM1 BANK0 2048 1333 Elpida EBJ21UE8BDF0-DJ-F; mem DIMM2 BANK1 4096 1333 Samsung M378B5273DH0-CH9
  mem DIMM3 BANK2 2048 1333 Elpida EBJ21UE8BDF0-DJ-F; mem DIMM4 BANK3 4096 1333 Samsung M378B5273DH0-CH9
} >"$D/dmidecode.txt"
{ echo "$SNB_HOST"; echo "$HD2000"; lpc "B65 Express Chipset LPC Controller" 1c50 05; echo "$CPT_SATA"; } >"$D/lspci.txt"
cpuinfo "Intel(R) Core(TM) i3-2120 CPU @ 3.30GHz" 42 4 2 3300 >"$D/cpuinfo.txt"; meminfo 12189340 >"$D/meminfo.txt"

# 2. ASUS P8H61-M LE (H61), i3-2100, BIOS 2011 → Ivy cần BIOS, BIOS quá cũ
mk asus-p8h61-m-le-h61
{ head_; bios "American Megatrends Inc." "0403" "07/22/2011"; sys "System manufacturer" "System Product Name" "System Version"
  board "ASUSTeK Computer INC." "P8H61-M LE" "Rev X.0x"; proc "LGA1155" "Socket LGA1155" "Intel(R) Core(TM) i3-2100 CPU @ 3.10GHz" 2 4 3800
  slot "PCIEX16_1" "x16 PCI Express"; slot "PCIEX1_1" "x1 PCI Express"
  arr "16 GB" 2
  mem DIMM_A1 BANK0 4096 1333 Kingston 99U5471-012.A00LF; mem DIMM_B1 BANK2 4096 1333 Kingston 99U5471-012.A00LF
} >"$D/dmidecode.txt"
{ echo "$SNB_HOST"; echo "$HD2000"; lpc "H61 Express Chipset LPC Controller" 1c5c 05; echo "$CPT_SATA"; } >"$D/lspci.txt"
cpuinfo "Intel(R) Core(TM) i3-2100 CPU @ 3.10GHz" 42 4 2 3100 >"$D/cpuinfo.txt"

# 3. Gigabyte GA-B75M-D3H (B75), i3-2120, RAM 2+4 | 2+4 → Ivy được, PCIe 3.0, dual channel đều
mk gigabyte-b75m-d3h-b75
{ head_; bios "American Megatrends Inc." "F15" "09/10/2013"; sys "Gigabyte Technology Co., Ltd." "To be filled by O.E.M." "To be filled by O.E.M."
  board "Gigabyte Technology Co., Ltd." "B75M-D3H" "x.x"; proc "Intel(R) Core(TM) i3-2120 CPU @ 3.30GHz" "Socket LGA1155" "Intel(R) Core(TM) i3-2120 CPU @ 3.30GHz" 2 4 3300
  slot "PCIEX16" "x16 PCI Express"; slot "PCIEX4" "x4 PCI Express"
  arr "32 GB" 4
  mem ChannelA-DIMM0 "BANK 0" 2048 1333 Kingston 99U5471-001.A00LF; mem ChannelA-DIMM1 "BANK 1" 4096 1333 Kingston 99U5471-012.A00LF
  mem ChannelB-DIMM0 "BANK 2" 2048 1333 Kingston 99U5471-001.A00LF; mem ChannelB-DIMM1 "BANK 3" 4096 1333 Kingston 99U5471-012.A00LF
} >"$D/dmidecode.txt"
{ echo "$SNB_HOST"; echo "$HD2000"; lpc "B75 Express Chipset LPC Controller" 1e49 04; echo "$PPT_SATA"; } >"$D/lspci.txt"
cpuinfo "Intel(R) Core(TM) i3-2120 CPU @ 3.30GHz" 42 4 2 3300 >"$D/cpuinfo.txt"

# 4. Dell OptiPlex 990 (Q67), i5-2400 → Ivy KHÔNG (hãng không ra BIOS)
mk dell-optiplex-990-q67
{ head_; bios "Dell Inc." "A18" "09/23/2013"; sys "Dell Inc." "OptiPlex 990" "01"
  board "Dell Inc." "0VNP2H" "A01"; proc "CPU 1" "Socket LGA1155" "Intel(R) Core(TM) i5-2400 CPU @ 3.10GHz" 4 4 3400
  slot "SLOT1" "x16 PCI Express"; slot "SLOT2" "x1 PCI Express"
  arr "32 GB" 4
  mem DIMM1 "Not Specified" 4096 1333 "Hynix/Hyundai" HMT351U6CFR8C-H9; mem DIMM2 "Not Specified" 0
  mem DIMM3 "Not Specified" 4096 1333 "Hynix/Hyundai" HMT351U6CFR8C-H9; mem DIMM4 "Not Specified" 0
} >"$D/dmidecode.txt"
{ echo "$SNB_HOST"; echo "$HD2000"; lpc "Q67 Express Chipset LPC Controller" 1c4e 05; echo "$CPT_SATA"; } >"$D/lspci.txt"
cpuinfo "Intel(R) Core(TM) i5-2400 CPU @ 3.10GHz" 42 4 4 3100 >"$D/cpuinfo.txt"

# 5. MSI Z68A-G43 (B3) (Z68) đang chạy i7-3770 → BIOS đã hỗ trợ Ivy, CPU đã gần mạnh nhất; chipset rev 04
mk msi-z68a-g43-ivy
{ head_; bios "American Megatrends Inc." "V1.12" "05/16/2012"; sys "MSI" "MS-7676" "2.0"
  board "MSI" "Z68A-G43 (G3) (MS-7676)" "2.0"; proc "CPU 1" "Socket LGA1155" "Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz" 4 8 3900
  slot "PCI_E2" "x16 PCI Express"; slot "PCI_E1" "x1 PCI Express"
  arr "32 GB" 4
  mem DIMM0 BANK0 8192 1333 Kingston KHX1600C10D3/8G; mem DIMM1 BANK1 8192 1333 Kingston KHX1600C10D3/8G
  mem DIMM2 BANK2 0; mem DIMM3 BANK3 0
} >"$D/dmidecode.txt"
{ echo "$IVB_HOST"; echo "$HD4000"; lpc "Z68 Express Chipset LPC Controller" 1c44 04; echo "$CPT_SATA";
  echo '01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GK107 [GeForce GT 640] [10de:0fc1] (rev a1)'; } >"$D/lspci.txt"
cpuinfo "Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz" 58 8 4 3400 >"$D/cpuinfo.txt"

# 6. Gigabyte GA-H81M-S2H (H81, LGA1150) → chưa có bảng tra
mk gigabyte-h81m-s2h-lga1150
{ head_; bios "American Megatrends Inc." "F8" "11/07/2014"; sys "Gigabyte Technology Co., Ltd." "To be filled by O.E.M." "To be filled by O.E.M."
  board "Gigabyte Technology Co., Ltd." "H81M-S2H" "x.x"; proc "SOCKET 0" "Socket LGA1150" "Intel(R) Core(TM) i5-4570 CPU @ 3.20GHz" 4 4 3600
  arr "16 GB" 2; mem ChannelA-DIMM0 "BANK 0" 4096 1600 Kingston 99U5471-052.A00LF; mem ChannelB-DIMM0 "BANK 2" 0
} >"$D/dmidecode.txt"
{ echo '00:00.0 Host bridge [0600]: Intel Corporation 4th Gen Core Processor DRAM Controller [8086:0c00] (rev 06)'
  echo '00:02.0 VGA compatible controller [0300]: Intel Corporation Xeon E3-1200 v3/4th Gen Core Processor Integrated Graphics Controller [8086:0412] (rev 06)'
  lpc "H81 Express LPC Controller" 8c5c 05; } >"$D/lspci.txt"
cpuinfo "Intel(R) Core(TM) i5-4570 CPU @ 3.20GHz" 60 4 4 3200 >"$D/cpuinfo.txt"

# 7. Máy ảo VMware Workstation → cảnh báo máy ảo, không có bảng tra
mk vmware-workstation
{ head_; bios "Phoenix Technologies LTD" "6.00" "11/12/2020"; sys "VMware, Inc." "VMware Virtual Platform" "None"
  board "Intel Corporation" "440BX Desktop Reference Platform" "None"; proc "CPU #000" "ZIF Socket" "Intel(R) Core(TM) i5-8250U CPU @ 1.60GHz" 2 2 4000
  arr "4 GB" 64; mem "RAM slot #0" "RAM slot #0" 4096 0 "VMware Virtual RAM" "VMW-4096MB"
} >"$D/dmidecode.txt"
echo vmware >"$D/virt.txt"
{ echo '00:00.0 Host bridge [0600]: Intel Corporation 440BX/ZX/DX - 82443BX/ZX/DX Host bridge [8086:7190] (rev 01)'
  echo '00:07.0 ISA bridge [0601]: Intel Corporation 82371AB/EB/MB PIIX4 ISA [8086:7110] (rev 08)'
  echo '00:0f.0 VGA compatible controller [0300]: VMware SVGA II Adapter [15ad:0405]'; } >"$D/lspci.txt"
cpuinfo "Intel(R) Core(TM) i5-8250U CPU @ 1.60GHz" 142 2 2 1800 >"$D/cpuinfo.txt"

echo "Đã sinh mẫu vào $OUT:"; ls "$OUT"
