using System.Text;
using System.Text.RegularExpressions;

namespace DepotUnattend;

/// <summary>
/// Nội dung file depot-autoinstall.conf (đọc bởi /usr/bin/depot-autoinstall trong ISO Depot OS).
/// Quy tắc kiểm tra giữ giống hàm validate() của script để lỗi lộ ra ngay trên Windows.
/// </summary>
public sealed class UnattendConfig
{
    public bool AutoStart { get; set; }
    public int ConfirmTimeout { get; set; } = 15;
    public string Target { get; set; } = "disk";            // disk | partition
    public string Disk { get; set; } = "auto";
    public bool WipeDisk { get; set; }
    public string Partition { get; set; } = "ask";
    public bool FormatPartition { get; set; }
    public string Confirm { get; set; } = "countdown";      // countdown | ask
    public string BootMode { get; set; } = "auto";
    public string FileSystem { get; set; } = "ext4";
    public int SwapSize { get; set; }
    public string Locale { get; set; } = "vi_VN.UTF-8";
    public string KeyboardLayout { get; set; } = "us";
    public string KeyboardVariant { get; set; } = "";
    public string KeyboardModel { get; set; } = "pc105";
    public string KeyboardOptions { get; set; } = "";
    public string TimeZone { get; set; } = "Asia/Ho_Chi_Minh";
    public string Rtc { get; set; } = "auto";
    public string HostName { get; set; } = "depot-pc";
    public string FullName { get; set; } = "";
    public string UserName { get; set; } = "";
    public string Password { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public bool AutoLogin { get; set; }
    public string WifiSsid { get; set; } = "";
    public string WifiPassword { get; set; } = "";
    public bool InstallApps { get; set; } = true;
    public string ExtraPackages { get; set; } = "";
    public bool Ssh { get; set; }
    public int SshPort { get; set; } = 22;
    public string SshUser { get; set; } = "";
    public string SshPassword { get; set; } = "";
    public string SshPasswordHash { get; set; } = "";
    public string SshAuthorizedKey { get; set; } = "";
    public bool SshPasswordAuth { get; set; } = true;
    public bool SshSudo { get; set; }
    public string SshStorage { get; set; } = "";
    public bool SshStorageFormat { get; set; }
    public bool Firewall { get; set; } = true;
    public List<string> PostInstall { get; set; } = new();
    public List<string> FirstBoot { get; set; } = new();
    public string Finish { get; set; } = "reboot";

    private static readonly string[] Reserved =
    {
        "root", "daemon", "bin", "sys", "sync", "games", "man", "lp", "mail", "news", "uucp", "proxy", "www-data",
        "backup", "list", "irc", "nobody", "messagebus", "lightdm", "depot",
    };

    public List<string> Validate()
    {
        var e = new List<string>();
        if (Target == "disk")
        {
            if (!WipeDisk) e.Add("Chưa tích \"Đồng ý XOÁ SẠCH cả ổ\" — trình cài sẽ từ chối chạy.");
            if (!(Disk is "auto" or "largest" or "smallest" || Disk.StartsWith("/dev/")))
                e.Add("Ổ cài: auto / largest / smallest hoặc đường dẫn /dev/... (vd /dev/sda, /dev/nvme0n1).");
            if (IsPartitionPath(Disk))
                e.Add("Ổ cài phải là cả ổ (vd /dev/sda). Muốn cài vào 1 phân vùng thì chọn \"Chỉ format 1 phân vùng\".");
        }
        else
        {
            if (!FormatPartition) e.Add("Chưa tích \"Đồng ý QUICK FORMAT phân vùng\" — trình cài sẽ từ chối chạy.");
            if (!(Partition == "ask" || Partition.StartsWith("/dev/") || Regex.IsMatch(Partition, "^(LABEL|PARTLABEL|UUID|PARTUUID)=.+")))
                e.Add("Phân vùng: ask (chọn lúc cài), /dev/sda3, LABEL=…, UUID=…");
            if (Partition.StartsWith("/dev/") && !IsPartitionPath(Partition))
                e.Add("Phân vùng phải dạng /dev/sda3, /dev/nvme0n1p5 (không phải cả ổ /dev/sda).");
        }
        if (ConfirmTimeout < 0) e.Add("Thời gian đếm ngược không được âm.");
        if (SwapSize < 0) e.Add("Swap (MB) không được âm.");
        if (!Regex.IsMatch(KeyboardLayout, "^[a-z]{2,3}$")) e.Add("Kiểu bàn phím dạng 'us', 'vn', 'fr'…");
        if (!Regex.IsMatch(TimeZone, @"^[A-Za-z_]+(/[A-Za-z0-9_+\-]+){0,2}$")) e.Add("Múi giờ dạng Khu_vực/Thành_phố, vd Asia/Ho_Chi_Minh.");
        if (!Regex.IsMatch(Locale, @"^[a-z]{2,3}_[A-Z]{2}(\.[A-Za-z0-9-]+)?(@\w+)?$")) e.Add("Ngôn ngữ dạng vi_VN.UTF-8.");
        if (!Regex.IsMatch(HostName, "^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$"))
            e.Add("Tên máy chỉ gồm chữ không dấu, số, gạch ngang (vd depot-pc).");
        if (!Regex.IsMatch(UserName, "^[a-z_][a-z0-9_-]{0,31}$"))
            e.Add("Tên đăng nhập viết thường, không dấu, không cách, bắt đầu bằng chữ (vd anh).");
        else if (Reserved.Contains(UserName) || UserName.StartsWith("systemd-"))
            e.Add($"Tên đăng nhập '{UserName}' trùng tài khoản hệ thống.");
        if (string.IsNullOrEmpty(Password) && string.IsNullOrEmpty(PasswordHash)) e.Add("Chưa nhập mật khẩu.");
        if (!string.IsNullOrEmpty(PasswordHash) && !Regex.IsMatch(PasswordHash, @"^\$(6|5|y|2[aby]|gy)\$"))
            e.Add("Mật khẩu đã mã hoá phải dạng $6$...");
        if (!string.IsNullOrEmpty(WifiPassword) && string.IsNullOrEmpty(WifiSsid)) e.Add("Có mật khẩu Wi-Fi mà thiếu tên Wi-Fi.");
        if (Ssh)
        {
            if (SshPort < 1 || SshPort > 65535) e.Add("Cổng SSH là số 1–65535.");
            if (SshUser.Length > 0)
            {
                if (!Regex.IsMatch(SshUser, "^[a-z_][a-z0-9_-]{0,31}$") || Reserved.Contains(SshUser)) e.Add("User SSH viết thường, không dấu (vd remote).");
                if (SshUser == UserName) e.Add("User SSH phải khác tên đăng nhập chính (để trống nếu muốn SSH bằng user chính).");
                if (SshPassword.Length == 0 && SshPasswordHash.Length == 0 && SshAuthorizedKey.Length == 0)
                    e.Add("User SSH cần mật khẩu hoặc public key.");
            }
            if (!SshPasswordAuth && SshAuthorizedKey.Length == 0) e.Add("Tắt đăng nhập SSH bằng mật khẩu thì phải có public key.");
            if (SshAuthorizedKey.Length > 0 && !Regex.IsMatch(SshAuthorizedKey, @"^(ssh-(ed25519|rsa)|ecdsa-sha2-nistp\d+|sk-[a-z0-9@.-]+) "))
                e.Add("Public key SSH phải là 1 dòng ssh-ed25519 AAAA… / ssh-rsa …");
            if (SshStorage.Length > 0 && !(SshStorage.StartsWith('/') || Regex.IsMatch(SshStorage, "^(LABEL|PARTLABEL|UUID|PARTUUID)=.+")))
                e.Add("Lưu trữ SSH: thư mục (/srv/remote) hoặc phân vùng (/dev/sdb1, LABEL=…).");
        }
        if (!Regex.IsMatch(ExtraPackages, @"^[a-z0-9.+:\s-]*$")) e.Add("Gói cài thêm chỉ gồm tên gói cách nhau bằng dấu cách.");
        foreach (var (name, v) in Fields())
            if (v.Contains('\n') || v.Contains('\r')) e.Add($"{name} không được xuống dòng.");
        return e;
    }

    private IEnumerable<(string, string)> Fields() => new[]
    {
        ("FULLNAME", FullName), ("PASSWORD", Password), ("WIFI_SSID", WifiSsid), ("WIFI_PASSWORD", WifiPassword),
        ("KEYBOARD_VARIANT", KeyboardVariant), ("KEYBOARD_OPTIONS", KeyboardOptions), ("SSH_PASSWORD", SshPassword),
        ("SSH_AUTHORIZED_KEY", SshAuthorizedKey), ("SSH_STORAGE", SshStorage), ("PARTITION", Partition), ("DISK", Disk),
    };

    public static bool IsPartitionPath(string v) =>
        Regex.IsMatch(v, @"^/dev/(sd[a-z]+|vd[a-z]+|hd[a-z]+)\d+$|^/dev/(nvme\d+n\d+|mmcblk\d+)p\d+$");

    // ------------------------------------------------------------ ghi file
    private static string Q(string v)
    {
        if (v.Length == 0) return "";
        if (Regex.IsMatch(v, @"^[A-Za-z0-9_./:+@,-]+$")) return v;
        return "\"" + v + "\"";   // script lấy tới dấu " cuối cùng nên giữa chuỗi có " vẫn được
    }

    private static string YN(bool b) => b ? "yes" : "no";

    public string ToText()
    {
        var sb = new StringBuilder();
        void L(string s = "") => sb.Append(s).Append('\n');
        L("# depot-autoinstall.conf — cài Depot OS tự động (giống autounattend.xml của Windows)");
        L($"# Tạo bởi Depot Unattend {DateTime.Now:yyyy-MM-dd HH:mm} — By WrenEvil.tech & nguyenquocanhz (nqatech)");
        L("# Chép vào GỐC USB, boot ISO Depot OS, chọn mục \"Cài tự động Depot OS\".");
        L("# Kiểm tra trong phiên live: sudo depot-autoinstall --check /đường/dẫn/depot-autoinstall.conf");
        L();
        L("# --- Khởi động: yes = thấy file là tự cài, không cần chọn mục boot");
        L($"AUTO_START={YN(AutoStart)}");
        L("# trước khi format: hiện bảng phân vùng + cảnh báo; countdown = đếm ngược (phím bất kỳ để huỷ), ask = hỏi Cài/Huỷ");
        L($"CONFIRM={Confirm}");
        L($"CONFIRM_TIMEOUT={ConfirmTimeout}");
        L();
        L("# --- Nơi cài: disk = xoá sạch cả ổ · partition = chỉ quick format 1 phân vùng, giữ Windows / ổ khác (dual-boot)");
        L($"TARGET={Target}");
        if (Target == "disk")
        {
            L("# ổ: auto (máy có đúng 1 ổ trong) / largest / smallest / /dev/sda …");
            L($"DISK={Q(Disk)}");
            L("# !!! yes = TOÀN BỘ DỮ LIỆU TRÊN Ổ TRÊN SẼ BỊ XOÁ SẠCH");
            L($"WIPE_DISK={YN(WipeDisk)}");
        }
        else
        {
            L("# phân vùng: ask (hiện danh sách để chọn lúc cài) / /dev/sda3 / LABEL=… / UUID=…");
            L($"PARTITION={Q(Partition)}");
            L("# !!! yes = phân vùng trên bị QUICK FORMAT, dữ liệu trên nó mất hẳn");
            L($"FORMAT_PARTITION={YN(FormatPartition)}");
        }
        L("# boot: auto / uefi / bios (Legacy) / both (cả Legacy lẫn UEFI)");
        L($"BOOT_MODE={BootMode}");
        L($"FILESYSTEM={FileSystem}");
        L("# swap (MB): phân vùng (disk) hoặc /swapfile (partition); 0 = không tạo (Depot OS đã có zram)");
        L($"SWAP_SIZE={SwapSize}");
        L();
        L("# --- Ngôn ngữ, bàn phím, giờ");
        L($"LOCALE={Q(Locale)}");
        L($"KEYBOARD_LAYOUT={Q(KeyboardLayout)}");
        L($"KEYBOARD_VARIANT={Q(KeyboardVariant)}");
        L($"KEYBOARD_MODEL={Q(KeyboardModel)}");
        L($"KEYBOARD_OPTIONS={Q(KeyboardOptions)}");
        L($"TIMEZONE={Q(TimeZone)}");
        L($"RTC={Rtc}");
        L();
        L("# --- Máy và người dùng");
        L($"HOSTNAME={Q(HostName)}");
        L($"FULLNAME={Q(FullName)}");
        L($"USERNAME={Q(UserName)}");
        if (!string.IsNullOrEmpty(PasswordHash))
        {
            L("# mật khẩu đã mã hoá (SHA-512) — không đọc ngược ra được");
            L($"PASSWORD_HASH='{PasswordHash}'");
        }
        else
        {
            L("# CẢNH BÁO: mật khẩu chữ thường, ai cầm USB cũng đọc được");
            L($"PASSWORD={Q(Password)}");
        }
        L($"AUTOLOGIN={YN(AutoLogin)}");
        L();
        L("# --- Mạng (Wi-Fi để tải app lúc cài; dây LAN thì bỏ trống)");
        L($"WIFI_SSID={Q(WifiSsid)}");
        L($"WIFI_PASSWORD={Q(WifiPassword)}");
        L();
        L("# --- Phần mềm");
        L($"INSTALL_APPS={YN(InstallApps)}");
        L($"EXTRA_PACKAGES={Q(ExtraPackages.Trim())}");
        L();
        L("# --- Truy cập từ xa: OpenSSH + tường lửa ufw (chặn vào, chỉ mở SSH, LocalSend, mDNS)");
        L($"SSH={YN(Ssh)}");
        if (Ssh)
        {
            L($"SSH_PORT={SshPort}");
            L("# user SSH riêng (trống = dùng user chính)");
            L($"SSH_USER={Q(SshUser)}");
            if (SshPasswordHash.Length > 0) L($"SSH_PASSWORD_HASH='{SshPasswordHash}'");
            else L($"SSH_PASSWORD={Q(SshPassword)}");
            L($"SSH_AUTHORIZED_KEY={Q(SshAuthorizedKey)}");
            L($"SSH_PASSWORD_AUTH={YN(SshPasswordAuth)}");
            L($"SSH_SUDO={YN(SshSudo)}");
            L("# lưu trữ riêng: trống = /srv/<user> · thư mục · phân vùng (/dev/sdb1, LABEL=…) gắn vào /srv/<user>");
            L($"SSH_STORAGE={Q(SshStorage)}");
            L("# yes = quick format phân vùng lưu trữ (mất dữ liệu trên đó)");
            L($"SSH_STORAGE_FORMAT={YN(SshStorageFormat)}");
        }
        L($"FIREWALL={YN(Firewall)}");
        L();
        L("# --- Lệnh sau khi cài (chạy trong máy mới, quyền root; có $DEPOT_USER, $DEPOT_HOSTNAME)");
        foreach (var c in PostInstall.Where(c => c.Trim().Length > 0)) L($"POST_INSTALL=\"{c.Trim()}\"");
        L("# --- Lệnh chạy 1 lần ở lần khởi động đầu (có mạng), log: /var/log/depot/firstboot.log");
        foreach (var c in FirstBoot.Where(c => c.Trim().Length > 0)) L($"FIRSTBOOT=\"{c.Trim()}\"");
        L();
        L("# --- Xong: reboot / poweroff / none");
        L($"FINISH={Finish}");
        return sb.ToString();
    }

    // ------------------------------------------------------------ đọc file (cùng quy tắc với parse_config của script)
    private static readonly Regex KeyRe = new(@"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$");
    private static readonly Regex QuotedD = new("^\"(.*)\"\\s*(#.*)?$");
    private static readonly Regex QuotedS = new(@"^'(.*)'\s*(#.*)?$");

    public static UnattendConfig Parse(string text, out List<string> warnings)
    {
        warnings = new List<string>();
        var c = new UnattendConfig();
        int n = 0;
        foreach (var raw in text.TrimStart('﻿').Split('\n'))
        {
            n++;
            var line = raw.TrimEnd('\r');
            var t = line.TrimStart();
            if (t.Length == 0 || t.StartsWith('#') || t.StartsWith(';')) continue;
            var m = KeyRe.Match(line);
            if (!m.Success) { warnings.Add($"Dòng {n} sai dạng KEY=giá trị: {line}"); continue; }
            string key = m.Groups[1].Value.ToUpperInvariant();
            string val = m.Groups[2].Value.TrimStart();
            Match q;
            if ((q = QuotedD.Match(val)).Success || (q = QuotedS.Match(val)).Success) val = q.Groups[1].Value;
            else
            {
                int h = Regex.Match(val, @"\s#").Index;
                if (Regex.IsMatch(val, @"\s#")) val = val[..h];
                val = val.TrimEnd();
            }
            bool yes = val.ToLowerInvariant() is "yes" or "y" or "true" or "1" or "co" or "có";
            int.TryParse(val, out int num);
            switch (key)
            {
                case "AUTO_START": c.AutoStart = yes; break;
                case "CONFIRM_TIMEOUT": c.ConfirmTimeout = num; break;
                case "TARGET": c.Target = val; break;
                case "DISK": c.Disk = val; break;
                case "WIPE_DISK": c.WipeDisk = yes; break;
                case "PARTITION": c.Partition = val; break;
                case "FORMAT_PARTITION": c.FormatPartition = yes; break;
                case "CONFIRM": c.Confirm = val; break;
                case "SSH": c.Ssh = yes; break;
                case "SSH_PORT": c.SshPort = num; break;
                case "SSH_USER": c.SshUser = val; break;
                case "SSH_PASSWORD": c.SshPassword = val; break;
                case "SSH_PASSWORD_HASH": c.SshPasswordHash = val; break;
                case "SSH_AUTHORIZED_KEY": c.SshAuthorizedKey = val; break;
                case "SSH_PASSWORD_AUTH": c.SshPasswordAuth = yes; break;
                case "SSH_SUDO": c.SshSudo = yes; break;
                case "SSH_STORAGE": c.SshStorage = val; break;
                case "SSH_STORAGE_FORMAT": c.SshStorageFormat = yes; break;
                case "FIREWALL": c.Firewall = yes; break;
                case "BOOT_MODE": c.BootMode = val; break;
                case "FILESYSTEM": c.FileSystem = val; break;
                case "SWAP_SIZE": c.SwapSize = num; break;
                case "LOCALE": c.Locale = val; break;
                case "KEYBOARD_LAYOUT": c.KeyboardLayout = val; break;
                case "KEYBOARD_VARIANT": c.KeyboardVariant = val; break;
                case "KEYBOARD_MODEL": c.KeyboardModel = val; break;
                case "KEYBOARD_OPTIONS": c.KeyboardOptions = val; break;
                case "TIMEZONE": c.TimeZone = val; break;
                case "RTC": c.Rtc = val; break;
                case "HOSTNAME": c.HostName = val; break;
                case "FULLNAME": c.FullName = val; break;
                case "USERNAME": c.UserName = val; break;
                case "PASSWORD": c.Password = val; break;
                case "PASSWORD_HASH": c.PasswordHash = val; break;
                case "AUTOLOGIN": c.AutoLogin = yes; break;
                case "WIFI_SSID": c.WifiSsid = val; break;
                case "WIFI_PASSWORD": c.WifiPassword = val; break;
                case "INSTALL_APPS": c.InstallApps = yes; break;
                case "EXTRA_PACKAGES": c.ExtraPackages = val; break;
                case "POST_INSTALL": if (val.Length > 0) c.PostInstall.Add(val); break;
                case "FIRSTBOOT": if (val.Length > 0) c.FirstBoot.Add(val); break;
                case "FINISH": c.Finish = val; break;
                default: warnings.Add($"Dòng {n}: không biết khoá '{key}' (bỏ qua)"); break;
            }
        }
        return c;
    }
}
