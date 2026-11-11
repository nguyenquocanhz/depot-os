-- Depot OS — depot-hwmon.lua: bảng cảm biến kiểu HWMonitor cho Widget Board (Conky)
-- By WrenEvil.tech & nguyenquocanhz (nqatech)
--
-- Mỗi giá trị hiện: hiện tại · min · max (tính từ lúc conky chạy, giống HWMonitor).
-- Đọc thẳng /sys (hwmon, cpufreq, power_supply, drm) bằng io.open — không fork lệnh mỗi lần cập nhật;
-- chỉ dò lại danh sách cảm biến mỗi RESCAN giây (1 lần ls). Nhóm nào không có cảm biến thì tự ẩn
-- (máy ảo thường chỉ còn dòng xung nhịp).
--
-- Gọi trong conky.text:  ${lua_parse depot_hw}
-- Thử với /sys giả:      DEPOT_HW_ROOT=/đường/dẫn/gốc-giả conky -c ...

local ROOT     = os.getenv('DEPOT_HW_ROOT') or ''
local RESCAN   = 300   -- giây giữa hai lần dò lại cảm biến (cắm pin, nạp module drivetemp...)
local DISK_INT = 30    -- ổ cứng đọc thưa hơn: SMART liên tục có thể giữ HDD không được nghỉ
local NV_INT   = 10    -- nvidia-smi (chỉ khi có driver NVIDIA riêng) là lệnh ngoài -> đọc thưa
local MAX_VOLT = 8     -- tối đa số dòng điện áp (chip Super I/O máy bàn có cả chục kênh)
local LABEL_W  = 16    -- ký tự tối đa của nhãn (vừa cột đến X_CUR)

-- cột (pixel) — khớp với các thanh CPU/RAM phía trên
local X_CUR, X_MIN, X_MAX = 128, 200, 262
local C_TXT, C_DIM, C_HEAD, C_CUR = 'e8eefb', '8fa7cf', '8fa7cf', 'e8eefb'
local C_WARM, C_HOT = 'f0b35a', 'ff6b6b'

---------------------------------------------------------------- tiện ích đọc file
local function rd(p)
    local f = io.open(ROOT .. p, 'r')
    if not f then return nil end
    local s = f:read('l')
    f:close()
    if s then s = s:gsub('%s+$', '') end
    return s
end

local function num(p)
    local s = rd(p)
    return s and tonumber(s) or nil
end

local function cut(s, n)
    n = n or LABEL_W
    local ok, len = pcall(utf8.len, s)
    if not ok or not len then return s:sub(1, n) end
    if len <= n then return s end
    return s:sub(1, utf8.offset(s, n) - 1) .. '…'
end

-- conky.text: '$' là ký tự đặc biệt
local function esc(s) return (s:gsub('%$', '$$')) end

---------------------------------------------------------------- định dạng
local FMT = {
    temp = function(v) return string.format('%d°C', math.floor(v + 0.5)) end,
    fan  = function(v) return string.format('%d rpm', math.floor(v + 0.5)) end,
    volt = function(v) return string.format('%.3f V', v) end,
    ghz  = function(v) return string.format('%.2f GHz', v) end,
    mhz  = function(v) return string.format('%d MHz', math.floor(v + 0.5)) end,
    watt = function(v) return string.format('%.1f W', v) end,
    pct  = function(v) return string.format('%d%%', math.floor(v + 0.5)) end,
}

---------------------------------------------------------------- trạng thái
local rows      = {}   -- danh sách dòng: {grp, id, label, kind, read=function() -> số|nil, every=giây}
local stat      = {}   -- id -> {cur, mn, mx, t}
local last_scan = -1e9
local nv_cache, nv_t = nil, -1e9

local function sh_list()
    -- Một lần fork: liệt kê mọi thư mục cần dò, đánh dấu bằng dòng '@nhóm tên'
    local r = ROOT
    local cmd = string.format([[
cd "%s/sys/class/hwmon" 2>/dev/null && for h in *; do echo "@hwmon $h"; ls "$h" 2>/dev/null; done
cd "%s/sys/class/power_supply" 2>/dev/null && for p in *; do echo "@ps $p"; done
cd "%s/sys/class/drm" 2>/dev/null && for c in card[0-9]*; do case $c in *-*) ;; *) echo "@drm $c";; esac; done
cd "%s/sys/devices/system/cpu" 2>/dev/null && for c in cpu[0-9]*; do echo "@cpu $c"; done
command -v nvidia-smi >/dev/null 2>&1 && echo "@nvidia x"
true]], r, r, r, r)
    local h = io.popen(cmd)
    local out = {}
    if h then
        local cur
        for l in h:lines() do
            local g, n = l:match('^@(%S+) (.+)$')
            if g then
                cur = {g = g, n = n, files = {}}
                out[#out + 1] = cur
            elseif cur then
                cur.files[#cur.files + 1] = l
            end
        end
        h:close()
    end
    return out
end

local CPU_CHIPS  = {coretemp = 1, k10temp = 1, zenpower = 1, cpu_thermal = 1, via_cputemp = 1}
local GPU_CHIPS  = {amdgpu = 1, radeon = 1, nouveau = 1, i915 = 1, xe = 1}
local DISK_CHIPS = {nvme = 1, drivetemp = 1}
local PRETTY     = {acpitz = 'ACPI', thinkpad = 'ThinkPad', dell_smm = 'Dell', asus = 'ASUS', hp = 'HP'}

local function cpu_label(chip, lab, idx)
    if not lab then return chip == 'coretemp' and ('Nhiệt CPU ' .. idx) or 'Nhiệt CPU' end
    local p = lab:match('^Package id (%d+)')
    if p then return 'Gói CPU' .. (p ~= '0' and (' ' .. p) or '') end
    local c = lab:match('^Core (%d+)')
    if c then return 'Nhân ' .. c end
    if lab == 'Tctl' or lab == 'Tdie' then return 'Gói CPU (' .. lab .. ')' end
    return 'CPU ' .. lab
end

local function add(grp, id, label, kind, reader, every)
    rows[#rows + 1] = {grp = grp, id = id, label = label, kind = kind, read = reader, every = every or 0}
end

local function file_reader(path, scale)
    return function()
        local v = num(path)
        if v == nil then return nil end
        return v * scale
    end
end

local function temp_reader(path)
    return function()
        local v = num(path)
        if v == nil then return nil end
        v = v / 1000
        if v <= -40 or v >= 150 then return nil end -- giá trị rác (chưa nối cảm biến)
        return v
    end
end

local function sorted_idx(files, pat)
    local t = {}
    for _, f in ipairs(files) do
        local i = f:match(pat)
        if i then t[#t + 1] = tonumber(i) end
    end
    table.sort(t)
    return t
end

local function scan()
    rows = {}
    local list = sh_list()
    local cpus, nvidia = {}, false
    local volt_n = 0
    local disk_seen = {}

    for _, e in ipairs(list) do
        if e.g == 'hwmon' then
            local base = '/sys/class/hwmon/' .. e.n
            local chip = rd(base .. '/name') or e.n
            local grp
            if CPU_CHIPS[chip] then grp = 'cpu'
            elseif GPU_CHIPS[chip] then grp = 'gpu'
            elseif DISK_CHIPS[chip] then grp = 'disk'
            elseif chip:match('^BAT') or chip:match('^AC') or chip:match('^ADP') then grp = nil -- pin đọc riêng
            else grp = 'board' end

            if grp == 'disk' then
                -- tên ổ: model của controller NVMe / thiết bị SCSI
                local model = rd(base .. '/device/model') or e.n
                model = model:gsub('^%s+', ''):gsub('%s+', ' ')
                local tag = chip == 'nvme' and 'NVMe' or 'SATA'
                local name = cut(tag .. ' ' .. model)
                if disk_seen[name] then name = cut(tag .. ' ' .. model, LABEL_W - 3) .. ' ' .. e.n:gsub('hwmon', '#') end
                disk_seen[name] = true
                -- chỉ lấy temp1 (NVMe: "Composite") cho gọn
                for _, f in ipairs(e.files) do
                    if f == 'temp1_input' then
                        add('disk', base .. '/temp1', name, 'temp', temp_reader(base .. '/temp1_input'), DISK_INT)
                    end
                end
            elseif grp then
                for _, i in ipairs(sorted_idx(e.files, '^temp(%d+)_input$')) do
                    local lab = rd(base .. '/temp' .. i .. '_label')
                    local label
                    if grp == 'cpu' then label = cpu_label(chip, lab, i)
                    elseif grp == 'gpu' then label = 'GPU' .. (lab and (' ' .. lab) or '')
                    else
                        local nice = PRETTY[chip] or (chip:match('^pch_') and 'PCH') or (chip:match('^iwlwifi') and 'Wi-Fi')
                            or chip
                        label = lab and (nice .. ' ' .. lab) or (i > 1 and (nice .. ' ' .. i) or nice)
                    end
                    add(grp, base .. '/temp' .. i, cut(label), 'temp', temp_reader(base .. '/temp' .. i .. '_input'))
                end
                for _, i in ipairs(sorted_idx(e.files, '^fan(%d+)_input$')) do
                    local lab = rd(base .. '/fan' .. i .. '_label')
                    local label = grp == 'gpu' and 'Quạt GPU' or (lab or ('Quạt ' .. i))
                    if grp ~= 'gpu' and chip ~= 'thinkpad' and chip ~= 'dell_smm' and not lab then
                        label = 'Quạt ' .. i .. ' (' .. chip .. ')'
                    end
                    add(grp == 'gpu' and 'gpu' or 'fan', base .. '/fan' .. i, cut(label), 'fan',
                        file_reader(base .. '/fan' .. i .. '_input', 1))
                end
                for _, i in ipairs(sorted_idx(e.files, '^in(%d+)_input$')) do
                    if grp == 'gpu' then
                        add('gpu', base .. '/in' .. i, cut('Điện áp GPU' .. (i > 0 and (' ' .. i) or '')), 'volt',
                            file_reader(base .. '/in' .. i .. '_input', 0.001))
                    elseif volt_n < MAX_VOLT then
                        volt_n = volt_n + 1
                        local lab = rd(base .. '/in' .. i .. '_label') or ('in' .. i)
                        add('volt', base .. '/in' .. i, cut(lab), 'volt', file_reader(base .. '/in' .. i .. '_input', 0.001))
                    end
                end
                if grp == 'gpu' then
                    for _, f in ipairs(e.files) do
                        if f == 'power1_average' or f == 'power1_input' then
                            add('gpu', base .. '/power1', 'Công suất GPU', 'watt', file_reader(base .. '/' .. f, 1e-6))
                            break
                        end
                    end
                    for _, f in ipairs(e.files) do
                        if f == 'freq1_input' then -- amdgpu sclk (Hz)
                            add('gpu', base .. '/freq1', 'Xung GPU', 'mhz', file_reader(base .. '/freq1_input', 1e-6))
                        end
                    end
                end
            end
        elseif e.g == 'cpu' then
            local p = '/sys/devices/system/cpu/' .. e.n .. '/cpufreq/scaling_cur_freq'
            if num(p) then cpus[#cpus + 1] = p end
        elseif e.g == 'drm' then
            -- iGPU Intel (i915: gt_act_freq_mhz; xe: tile0/gt0/freq0/act_freq). HD 3000 không có cảm biến nhiệt
            -- riêng — nhiệt iGPU nằm chung "Gói CPU".
            local base = '/sys/class/drm/' .. e.n
            for _, rel in ipairs({'/gt_act_freq_mhz', '/gt_cur_freq_mhz', '/device/tile0/gt0/freq0/act_freq'}) do
                if num(base .. rel) then
                    add('gpu', base .. rel, cut('Xung iGPU' .. (e.n ~= 'card0' and (' ' .. e.n) or '')), 'mhz',
                        file_reader(base .. rel, 1))
                    break
                end
            end
        elseif e.g == 'ps' then
            local base = '/sys/class/power_supply/' .. e.n
            if rd(base .. '/type') == 'Battery' and rd(base .. '/scope') ~= 'Device' then
                local pre = (e.n == 'BAT0' or e.n == 'BAT1') and '' or (e.n .. ' ')
                if num(base .. '/capacity') or num(base .. '/energy_now') or num(base .. '/charge_now') then
                    add('bat', base .. '/cap', pre .. 'Mức pin', 'pct', function()
                        local c = num(base .. '/capacity')
                        if c then return c end
                        local n, f = num(base .. '/energy_now'), num(base .. '/energy_full')
                        if not n then n, f = num(base .. '/charge_now'), num(base .. '/charge_full') end
                        if n and f and f > 0 then return n * 100 / f end
                    end)
                end
                if num(base .. '/voltage_now') then
                    add('bat', base .. '/volt', pre .. 'Điện áp pin', 'volt', file_reader(base .. '/voltage_now', 1e-6))
                end
                if num(base .. '/power_now') or num(base .. '/current_now') then
                    add('bat', base .. '/pw', pre .. 'Công suất pin', 'watt', function()
                        local p = num(base .. '/power_now')
                        if p then return math.abs(p) * 1e-6 end
                        local i, v = num(base .. '/current_now'), num(base .. '/voltage_now')
                        if i and v then return math.abs(i * v) * 1e-12 end
                    end)
                end
                local full = num(base .. '/energy_full') or num(base .. '/charge_full')
                local design = num(base .. '/energy_full_design') or num(base .. '/charge_full_design')
                if full and design and design > 0 then
                    add('bat', base .. '/wear', pre .. 'Độ chai pin', 'pct', function()
                        local f2 = num(base .. '/energy_full') or num(base .. '/charge_full')
                        if f2 then return math.max(0, 100 - f2 * 100 / design) end
                    end, 600)
                end
            end
        elseif e.g == 'nvidia' then
            nvidia = true
        end
    end

    -- xung nhịp CPU: trung bình các nhân (cpufreq); máy ảo không có cpufreq -> /proc/cpuinfo
    if #cpus > 0 then
        add('cpu', 'cpufreq', 'Xung nhịp', 'ghz', function()
            local s, n = 0, 0
            for _, p in ipairs(cpus) do
                local v = num(p)
                if v then s, n = s + v, n + 1 end
            end
            if n > 0 then return s / n / 1e6 end
        end)
    else
        add('cpu', 'cpuinfo', 'Xung nhịp', 'ghz', function()
            local f = io.open(ROOT .. '/proc/cpuinfo', 'r')
            if not f then return nil end
            local s, n = 0, 0
            for l in f:lines() do
                local v = l:match('^cpu MHz%s*:%s*([%d%.]+)')
                if v then s, n = s + tonumber(v), n + 1 end
            end
            f:close()
            if n > 0 then return s / n / 1000 end
        end)
    end

    if nvidia then
        local function nv(i)
            return function()
                local now = os.time()
                if now - nv_t >= NV_INT then
                    nv_t = now
                    local h = io.popen('nvidia-smi --query-gpu=temperature.gpu,fan.speed,power.draw,clocks.gr' ..
                        ' --format=csv,noheader,nounits 2>/dev/null')
                    local l = h and h:read('l')
                    if h then h:close() end
                    nv_cache = {}
                    -- giữ đúng vị trí cột: "[N/A]" -> nil (dòng đó tự ẩn), không làm lệch các cột sau
                    local k = 0
                    for v in ((l or '') .. ','):gmatch('([^,]*),') do
                        k = k + 1
                        nv_cache[k] = tonumber((v:gsub('%s', '')))
                    end
                end
                return nv_cache and nv_cache[i]
            end
        end
        add('gpu', 'nv/temp', 'GPU NVIDIA', 'temp', nv(1))
        add('gpu', 'nv/fan', 'Quạt GPU', 'pct', nv(2))
        add('gpu', 'nv/pw', 'Công suất GPU', 'watt', nv(3))
        add('gpu', 'nv/clk', 'Xung GPU', 'mhz', nv(4))
    end
end

---------------------------------------------------------------- vẽ
local GROUPS = {
    {'cpu',   'CPU'},
    {'gpu',   'GPU'},
    {'disk',  'Ổ CỨNG'},
    {'board', 'BO MẠCH · KHÁC'},
    {'fan',   'QUẠT'},
    {'volt',  'ĐIỆN ÁP'},
    {'bat',   'PIN'},
}

local function vcolor(kind, v)
    if kind == 'temp' and v then
        if v >= 85 then return C_HOT elseif v >= 70 then return C_WARM end
    end
    return C_CUR
end

local function update(now)
    for _, r in ipairs(rows) do
        local s = stat[r.id]
        if not s then s = {t = -1e9}; stat[r.id] = s end
        if now - s.t >= r.every then
            s.t = now
            local ok, v = pcall(r.read)
            if ok and v then
                s.cur = v
                if not s.mn or v < s.mn then s.mn = v end
                if not s.mx or v > s.mx then s.mx = v end
            elseif r.every == 0 then
                s.cur = nil
            end
        end
    end
end

function conky_depot_hw()
    local now = os.time()
    if now - last_scan >= RESCAN then
        last_scan = now
        scan()
    end
    update(now)

    local out = {}
    local function line(s) out[#out + 1] = s end
    local any = false
    for _, g in ipairs(GROUPS) do
        local body = {}
        for _, r in ipairs(rows) do
            local s = stat[r.id]
            -- quạt chưa từng quay (chân cắm trống) thì ẩn
            local show = s and s.mx ~= nil and not (r.kind == 'fan' and s.mx <= 0)
            if r.grp == g[1] and show then
                local f = FMT[r.kind]
                body[#body + 1] = string.format('${color %s} %s${goto %d}${color %s}%s${goto %d}${color %s}%s${goto %d}%s',
                    C_TXT, esc(r.label), X_CUR, vcolor(r.kind, s.cur), s.cur and f(s.cur) or '—',
                    X_MIN, C_DIM, f(s.mn), X_MAX, f(s.mx))
            end
        end
        if #body > 0 then
            if not any then
                line(string.format('${font Inter:bold:pixelsize=11}${color %s}CẢM BIẾN${font}' ..
                    '${font Inter:pixelsize=9}${color %s}${goto %d}hiện tại${goto %d}min${goto %d}max${font}',
                    C_HEAD, C_DIM, X_CUR, X_MIN, X_MAX))
                any = true
            end
            line(string.format('${voffset 3}${font Inter:bold:pixelsize=9}${color %s}%s${font}', C_HEAD, g[2]))
            for _, b in ipairs(body) do line(b) end
        end
    end
    return table.concat(out, '\n')
end
