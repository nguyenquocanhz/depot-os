using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using Microsoft.Win32;

namespace DepotUnattend;

public partial class MainWindow : Window
{
    private const string FileName = "depot-autoinstall.conf";
    private readonly string _salt = Sha512Crypt.NewSalt();
    private string _loadedHash = "";      // PASSWORD_HASH từ file đã mở (không đọc ngược được)
    private string _cachedPwd = "";
    private string _cachedHash = "";
    private bool _loading;

    public MainWindow()
    {
        InitializeComponent();
        LoadIntoForm(Defaults());
        HookEvents(this);
        Refresh();

        // DepotUnattend.exe [file.conf] [--screenshot out.png] — mở sẵn file; chụp cửa sổ rồi thoát (làm tài liệu)
        var args = Environment.GetCommandLineArgs().Skip(1).ToList();
        var open = args.FirstOrDefault(a => !a.StartsWith("--") && File.Exists(a));
        if (open != null) OpenFile(open);
        int si = args.IndexOf("--screenshot");
        if (si >= 0 && si + 1 < args.Count)
        {
            string png = Path.GetFullPath(args[si + 1]);
            ContentRendered += (_, _) => Dispatcher.BeginInvoke(() =>
            {
                var root = (FrameworkElement)Content;
                var bmp = new System.Windows.Media.Imaging.RenderTargetBitmap(
                    (int)root.ActualWidth, (int)root.ActualHeight, 96, 96, System.Windows.Media.PixelFormats.Pbgra32);
                bmp.Render(root);
                var enc = new System.Windows.Media.Imaging.PngBitmapEncoder();
                enc.Frames.Add(System.Windows.Media.Imaging.BitmapFrame.Create(bmp));
                using (var fs = File.Create(png)) enc.Save(fs);
                Close();
            }, System.Windows.Threading.DispatcherPriority.ApplicationIdle);
        }
    }

    private static UnattendConfig Defaults()
    {
        var c = new UnattendConfig { FullName = "", UserName = "" };
        // múi giờ mặc định theo Windows đang chạy
        if (TimeZoneInfo.TryConvertWindowsIdToIanaId(TimeZoneInfo.Local.Id, out var iana) && iana.Contains('/'))
            c.TimeZone = iana;
        return c;
    }

    // ---------------------------------------------------------------- form <-> model
    private static void SetCombo(ComboBox box, string value)
    {
        foreach (var it in box.Items)
            if (it is ComboBoxItem ci && (string)ci.Content == value) { box.SelectedItem = ci; return; }
        if (box.IsEditable) box.Text = value;
        else if (box.Items.Count > 0) box.SelectedIndex = 0;
    }

    private static string GetCombo(ComboBox box) =>
        box.IsEditable ? box.Text.Trim() : (box.SelectedItem as ComboBoxItem)?.Content as string ?? "";

    private static int Int(TextBox t) => int.TryParse(t.Text.Trim(), out var v) ? v : -1;

    private void LoadIntoForm(UnattendConfig c)
    {
        _loading = true;
        SetCombo(DiskBox, c.Disk);
        WipeBox.IsChecked = c.WipeDisk;
        SetCombo(BootModeBox, c.BootMode);
        SetCombo(FsBox, c.FileSystem);
        SwapBox.Text = c.SwapSize.ToString();
        SetCombo(LocaleBox, c.Locale);
        SetCombo(KbBox, c.KeyboardLayout);
        KbVariantBox.Text = c.KeyboardVariant;
        KbOptionsBox.Text = c.KeyboardOptions;
        SetCombo(TzBox, c.TimeZone);
        SetCombo(RtcBox, c.Rtc);
        HostBox.Text = c.HostName;
        FullNameBox.Text = c.FullName;
        UserBox.Text = c.UserName;
        Pwd1.Password = c.Password;
        Pwd2.Password = c.Password;
        _loadedHash = c.PasswordHash;
        HashBox.IsChecked = string.IsNullOrEmpty(c.Password) || !string.IsNullOrEmpty(c.PasswordHash);
        AutoLoginBox.IsChecked = c.AutoLogin;
        WifiBox.Text = c.WifiSsid;
        WifiPwd.Password = c.WifiPassword;
        AppsBox.IsChecked = c.InstallApps;
        PkgBox.Text = c.ExtraPackages;
        PostBox.Text = string.Join(Environment.NewLine, c.PostInstall);
        FirstBox.Text = string.Join(Environment.NewLine, c.FirstBoot);
        AutoStartBox.IsChecked = c.AutoStart;
        CountdownBox.Text = c.ConfirmTimeout.ToString();
        SetCombo(FinishBox, c.Finish);
        TargetPart.IsChecked = c.Target == "partition";
        TargetDisk.IsChecked = c.Target != "partition";
        SetCombo(PartBox, c.Partition);
        FormatBox.IsChecked = c.FormatPartition;
        SetCombo(ConfirmBox, c.Confirm);
        SshBox.IsChecked = c.Ssh;
        SshPortBox.Text = c.SshPort.ToString();
        SshUserBox.Text = c.SshUser;
        SshPwd.Password = c.SshPassword;
        _loadedSshHash = c.SshPasswordHash;
        SshKeyBox.Text = c.SshAuthorizedKey;
        SshPwAuthBox.IsChecked = c.SshPasswordAuth;
        SshSudoBox.IsChecked = c.SshSudo;
        SshStorageBox.Text = c.SshStorage;
        SshStorageFormatBox.IsChecked = c.SshStorageFormat;
        FirewallBox.IsChecked = c.Firewall;
        _loading = false;
        SyncVisibility();
    }

    private string _loadedSshHash = "";
    private string _cachedSshPwd = "";
    private string _cachedSshHash = "";

    private void SyncVisibility()
    {
        bool part = TargetPart.IsChecked == true;
        DiskPanel.Visibility = part ? Visibility.Collapsed : Visibility.Visible;
        PartPanel.Visibility = part ? Visibility.Visible : Visibility.Collapsed;
        WipeBox.Visibility = part ? Visibility.Collapsed : Visibility.Visible;
        FormatBox.Visibility = part ? Visibility.Visible : Visibility.Collapsed;
        DangerText.Text = part
            ? "⚠ Phân vùng được chọn sẽ bị QUICK FORMAT — dữ liệu trên nó mất hẳn. Các phân vùng khác (Windows, ổ D:, EFI) giữ nguyên."
            : "⚠ TOÀN BỘ DỮ LIỆU TRÊN Ổ ĐÃ CHỌN SẼ BỊ XOÁ SẠCH — kể cả Windows, ổ D:, ảnh, tài liệu.";
        SshPanel.IsEnabled = SshBox.IsChecked == true;
    }

    private static List<string> Lines(string s) =>
        s.Split('\n').Select(l => l.TrimEnd('\r').Trim()).Where(l => l.Length > 0).ToList();

    private UnattendConfig FromForm(List<string> extraErrors)
    {
        var c = new UnattendConfig
        {
            Disk = GetCombo(DiskBox),
            WipeDisk = WipeBox.IsChecked == true,
            BootMode = GetCombo(BootModeBox),
            FileSystem = GetCombo(FsBox),
            SwapSize = Int(SwapBox),
            Locale = GetCombo(LocaleBox),
            KeyboardLayout = GetCombo(KbBox),
            KeyboardVariant = KbVariantBox.Text.Trim(),
            KeyboardOptions = KbOptionsBox.Text.Trim(),
            TimeZone = GetCombo(TzBox),
            Rtc = GetCombo(RtcBox),
            HostName = HostBox.Text.Trim(),
            FullName = FullNameBox.Text.Trim(),
            UserName = UserBox.Text.Trim(),
            AutoLogin = AutoLoginBox.IsChecked == true,
            WifiSsid = WifiBox.Text.Trim(),
            WifiPassword = WifiPwd.Password,
            InstallApps = AppsBox.IsChecked == true,
            ExtraPackages = PkgBox.Text.Trim(),
            PostInstall = Lines(PostBox.Text),
            FirstBoot = Lines(FirstBox.Text),
            AutoStart = AutoStartBox.IsChecked == true,
            ConfirmTimeout = Int(CountdownBox),
            Finish = GetCombo(FinishBox),
            Target = TargetPart.IsChecked == true ? "partition" : "disk",
            Partition = GetCombo(PartBox),
            FormatPartition = FormatBox.IsChecked == true,
            Confirm = GetCombo(ConfirmBox),
            Ssh = SshBox.IsChecked == true,
            SshPort = Int(SshPortBox),
            SshUser = SshUserBox.Text.Trim(),
            SshAuthorizedKey = SshKeyBox.Text.Trim(),
            SshPasswordAuth = SshPwAuthBox.IsChecked == true,
            SshSudo = SshSudoBox.IsChecked == true,
            SshStorage = SshStorageBox.Text.Trim(),
            SshStorageFormat = SshStorageFormatBox.IsChecked == true,
            Firewall = FirewallBox.IsChecked == true,
        };
        string sp = SshPwd.Password;
        if (sp.Length > 0)
        {
            if (HashBox.IsChecked == true)
            {
                if (sp != _cachedSshPwd) { _cachedSshPwd = sp; _cachedSshHash = Sha512Crypt.Hash(sp, Sha512Crypt.NewSalt()); }
                c.SshPasswordHash = _cachedSshHash;
            }
            else c.SshPassword = sp;
        }
        else c.SshPasswordHash = _loadedSshHash;
        if (string.IsNullOrEmpty(c.FullName)) c.FullName = c.UserName;
        if (c.SwapSize < 0) extraErrors.Add("Swap phải là số MB (0 = không tạo).");
        if (c.ConfirmTimeout < 0) extraErrors.Add("Đếm ngược phải là số giây.");

        string p1 = Pwd1.Password, p2 = Pwd2.Password;
        if (p1.Length > 0)
        {
            if (p1 != p2) extraErrors.Add("Hai ô mật khẩu không khớp.");
            if (HashBox.IsChecked == true)
            {
                if (p1 != _cachedPwd) { _cachedPwd = p1; _cachedHash = Sha512Crypt.Hash(p1, _salt); }
                c.PasswordHash = _cachedHash;
                PwdNote.Text = "Sẽ ghi dạng mã hoá $6$… — trình cài đặt đúng mật khẩu này.";
            }
            else
            {
                c.Password = p1;
                PwdNote.Text = "Mật khẩu ghi dạng chữ thường trong file.";
            }
        }
        else if (!string.IsNullOrEmpty(_loadedHash))
        {
            c.PasswordHash = _loadedHash;
            PwdNote.Text = "Đang giữ mật khẩu đã mã hoá từ file vừa mở. Gõ mật khẩu mới để thay.";
        }
        else PwdNote.Text = "";
        return c;
    }

    // ---------------------------------------------------------------- cập nhật xem trước + lỗi
    private void HookEvents(DependencyObject root)
    {
        foreach (var child in LogicalTreeHelper.GetChildren(root).OfType<DependencyObject>())
        {
            switch (child)
            {
                case TextBox t: t.TextChanged += (_, _) => Refresh(); break;
                case PasswordBox p: p.PasswordChanged += (_, _) => Refresh(); break;
                case ComboBox cb:
                    cb.SelectionChanged += (_, _) => Dispatcher.BeginInvoke(Refresh);
                    cb.AddHandler(TextBoxBase.TextChangedEvent, new TextChangedEventHandler((_, _) => Refresh()));
                    break;
                case CheckBox ck: ck.Click += (_, _) => { SyncVisibility(); Refresh(); }; break;
                case RadioButton rb: rb.Checked += (_, _) => { if (!_loading) { SyncVisibility(); Refresh(); } }; break;
            }
            HookEvents(child);
        }
    }

    private (UnattendConfig cfg, List<string> errors) Build()
    {
        var extra = new List<string>();
        var c = FromForm(extra);
        var errors = extra.Concat(c.Validate()).Distinct().ToList();
        return (c, errors);
    }

    private void Refresh()
    {
        if (_loading || Preview == null) return;
        var (c, errors) = Build();
        Preview.Text = c.ToText();
        if (errors.Count == 0)
        {
            StatusCard.Background = (System.Windows.Media.Brush)FindResource("OkBgBrush");
            StatusTitle.Foreground = (System.Windows.Media.Brush)FindResource("OkBrush");
            StatusTitle.Text = "✓ Hợp lệ — sẵn sàng lưu vào USB";
            StatusList.Foreground = StatusTitle.Foreground;
            StatusList.Text = c.AutoStart
                ? "AUTO_START=yes: cứ boot USB là máy tự " + (c.Target == "partition" ? "format phân vùng" : "xoá ổ") +
                  " và cài (sau " + c.ConfirmTimeout + " giây đếm ngược, có bảng phân vùng để xem trước)."
                : "Boot ISO → chọn mục \"Cài tự động Depot OS\" ở menu boot.";
        }
        else
        {
            StatusCard.Background = (System.Windows.Media.Brush)FindResource("WarnBgBrush");
            StatusTitle.Foreground = (System.Windows.Media.Brush)FindResource("WarnBrush");
            StatusTitle.Text = $"Còn {errors.Count} chỗ cần sửa";
            StatusList.Foreground = StatusTitle.Foreground;
            StatusList.Text = "• " + string.Join("\n• ", errors);
        }
    }

    // ---------------------------------------------------------------- lưu / mở
    private bool ConfirmIfInvalid()
    {
        var (_, errors) = Build();
        if (errors.Count == 0) return true;
        return MessageBox.Show(this,
                   "File còn lỗi, trình cài sẽ từ chối chạy:\n\n• " + string.Join("\n• ", errors) + "\n\nVẫn lưu (bản nháp)?",
                   "Depot Unattend", MessageBoxButton.YesNo, MessageBoxImage.Warning) == MessageBoxResult.Yes;
    }

    private void WriteTo(string path)
    {
        var (c, _) = Build();
        File.WriteAllText(path, c.ToText(), new UTF8Encoding(false));   // UTF-8 không BOM, xuống dòng LF
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        if (!ConfirmIfInvalid()) return;
        var dlg = new SaveFileDialog
        {
            FileName = FileName,
            Filter = "Cấu hình cài tự động (*.conf)|*.conf|Mọi file (*.*)|*.*",
            Title = "Lưu file cài tự động",
        };
        if (dlg.ShowDialog(this) != true) return;
        try
        {
            WriteTo(dlg.FileName);
            if (!string.Equals(Path.GetFileName(dlg.FileName), FileName, StringComparison.OrdinalIgnoreCase))
                MessageBox.Show(this, $"Đã lưu. Lưu ý: trên USB file phải tên đúng {FileName} thì trình cài mới tìm thấy.",
                    "Depot Unattend", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, "Không lưu được: " + ex.Message, "Depot Unattend", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void SaveUsb_Click(object sender, RoutedEventArgs e)
    {
        var drives = DriveInfo.GetDrives().Where(d => d.DriveType == DriveType.Removable && d.IsReady).ToList();
        var menu = new ContextMenu { PlacementTarget = UsbButton, Placement = PlacementMode.Top };
        if (drives.Count == 0)
        {
            menu.Items.Add(new MenuItem { Header = "Không thấy USB nào — cắm USB rồi bấm lại (hoặc dùng \"Lưu file…\")", IsEnabled = false });
        }
        foreach (var d in drives)
        {
            string label = string.IsNullOrEmpty(d.VolumeLabel) ? "USB" : d.VolumeLabel;
            var item = new MenuItem
            {
                Header = $"{d.Name}  {label}  ({d.DriveFormat}, trống {d.AvailableFreeSpace / 1e9:0.#} GB)",
                Tag = d.RootDirectory.FullName,
            };
            item.Click += (_, _) => SaveToUsb((string)item.Tag);
            menu.Items.Add(item);
        }
        menu.IsOpen = true;
    }

    private void SaveToUsb(string root)
    {
        if (!ConfirmIfInvalid()) return;
        string path = Path.Combine(root, FileName);
        if (File.Exists(path) && MessageBox.Show(this, $"{path} đã có. Ghi đè?", "Depot Unattend",
                MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes) return;
        try
        {
            WriteTo(path);
            var (c, _) = Build();
            MessageBox.Show(this,
                $"Đã lưu {path}.\n\nBước tiếp: boot máy cần cài từ ISO Depot OS " +
                (c.AutoStart ? "— máy sẽ TỰ XOÁ Ổ và cài sau " + c.ConfirmTimeout + " giây đếm ngược."
                             : "và chọn mục \"Cài tự động Depot OS\" ở menu boot."),
                "Depot Unattend", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, "Không ghi được vào USB: " + ex.Message, "Depot Unattend", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void Open_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new OpenFileDialog
        {
            Filter = "Cấu hình cài tự động (*.conf)|*.conf|Mọi file (*.*)|*.*",
            Title = "Mở depot-autoinstall.conf",
        };
        if (dlg.ShowDialog(this) != true) return;
        OpenFile(dlg.FileName);
    }

    private void OpenFile(string path)
    {
        try
        {
            var c = UnattendConfig.Parse(File.ReadAllText(path, Encoding.UTF8), out var warnings);
            LoadIntoForm(c);
            _cachedPwd = "";
            Refresh();
            if (warnings.Count > 0)
                MessageBox.Show(this, "Đã mở, có vài dòng bị bỏ qua:\n\n• " + string.Join("\n• ", warnings),
                    "Depot Unattend", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, "Không mở được: " + ex.Message, "Depot Unattend", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void New_Click(object sender, RoutedEventArgs e)
    {
        LoadIntoForm(Defaults());
        _cachedPwd = "";
        Refresh();
    }

    private void Copy_Click(object sender, RoutedEventArgs e) => Clipboard.SetText(Preview.Text);
}
