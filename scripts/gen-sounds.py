#!/usr/bin/env python3
# Depot OS — sinh bộ âm thanh hệ thống "depot" (chuẩn freedesktop sound theme):
#   build/live-build/config/includes.chroot/usr/share/sounds/depot/{index.theme, stereo/*.oga}
# Âm tự tổng hợp (không lấy file của ai → không vướng bản quyền): tiếng chuông mềm, nốt trong thang ngũ cung
# Rê trưởng (D E F# A B — chữ D của Depot). Âm khởi động là hợp âm rải đi lên, ứng với logo "kiện hàng trong kho".
# Âm nào không có ở đây thì kế thừa bộ freedesktop (Inherits=freedesktop).
# Chạy trong WSL: python3 scripts/gen-sounds.py   (cần ffmpeg có libvorbis)
import math, os, random, shutil, struct, subprocess, sys, tempfile, wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "live-build", "config", "includes.chroot", "usr", "share", "sounds", "depot")
SR = 48000

def hz(note):
    """'D4', 'F#5' → tần số (A4 = 440)."""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    n = names[note[0]] + (1 if "#" in note else 0)
    octave = int(note[-1])
    return 440.0 * 2 ** ((n - 9) / 12 + (octave - 4))

def bell(f, dur, amp=1.0, bright=1.0):
    """Tiếng chuông mềm: vài hoạ âm, hoạ âm cao tắt nhanh hơn, vào tiếng 4 ms."""
    partials = [(1.0, 1.0, 1.0), (2.0, 0.42 * bright, 0.55), (3.01, 0.18 * bright, 0.35), (4.17, 0.08 * bright, 0.22)]
    n = int(dur * SR)
    out = [0.0] * n
    for k in range(n):
        t = k / SR
        env = min(1.0, t / 0.004)
        s = 0.0
        for ratio, a, life in partials:
            s += a * math.exp(-t / (dur * life)) * math.sin(2 * math.pi * f * ratio * t)
        out[k] = amp * env * s
    return out

def noise_burst(dur, amp=1.0, decay=0.02, hp=0.92):
    random.seed(7)
    n = int(dur * SR)
    out, prev_in, prev_out = [0.0] * n, 0.0, 0.0
    for k in range(n):
        x = random.uniform(-1, 1)
        y = hp * (prev_out + x - prev_in)   # lọc thông cao: tiếng "tách" gọn, không ù
        prev_in, prev_out = x, y
        out[k] = amp * math.exp(-(k / SR) / decay) * y
    return out

def place(track, clip, at, pan=0.0):
    """Đặt clip (mono) vào track stereo tại giây `at`, pan -1 (trái) … 1 (phải)."""
    i0 = int(at * SR)
    gl, gr = math.cos((pan + 1) * math.pi / 4), math.sin((pan + 1) * math.pi / 4)
    need = i0 + len(clip)
    if len(track) < need:
        track.extend([(0.0, 0.0)] * (need - len(track)))
    for k, v in enumerate(clip):
        l, r = track[i0 + k]
        track[i0 + k] = (l + v * gl, r + v * gr)
    return track

def reverb(track, mix=0.18):
    """Vang nhẹ: vài đường trễ, đủ để âm không khô."""
    taps = [(0.043, 0.5), (0.067, 0.35), (0.101, 0.25), (0.149, 0.15)]
    tail = int(0.4 * SR)
    out = list(track) + [(0.0, 0.0)] * tail
    for d, g in taps:
        dl, dr = int(d * SR), int(d * 1.07 * SR)
        for k in range(len(track)):
            l, r = track[k]
            if k + dl < len(out):
                ol, orr = out[k + dl]; out[k + dl] = (ol + mix * g * r, orr)   # chéo kênh cho rộng
            if k + dr < len(out):
                ol, orr = out[k + dr]; out[k + dr] = (ol, orr + mix * g * l)
    return out

def finish(track, peak_db):
    """Chuẩn hoá đỉnh, tắt dần 30 ms cuối, cắt đuôi im lặng."""
    peak = max(max(abs(l), abs(r)) for l, r in track) or 1.0
    g = 10 ** (peak_db / 20) / peak
    track = [(l * g, r * g) for l, r in track]
    while track and max(abs(track[-1][0]), abs(track[-1][1])) < 1e-4:
        track.pop()
    fade = min(len(track), int(0.03 * SR))
    for k in range(fade):
        i = len(track) - fade + k
        f = 1 - k / fade
        track[i] = (track[i][0] * f, track[i][1] * f)
    return track

# ---------- từng âm: (tên sự kiện freedesktop, mô tả, hàm dựng, đỉnh dB)
def login():
    t = []
    for i, (note, pan) in enumerate([("D4", -0.35), ("A4", -0.1), ("D5", 0.1), ("F#5", 0.35)]):
        place(t, bell(hz(note), 2.2 - i * 0.2, amp=1.0 - i * 0.12), i * 0.16, pan)
    place(t, bell(hz("A5"), 1.6, amp=0.35, bright=0.5), 0.64, 0.0)
    return reverb(t, 0.22)

def logout():
    t = []
    for i, note in enumerate(["F#5", "D5", "A4", "D4"]):
        place(t, bell(hz(note), 1.2, amp=0.9), i * 0.12, 0.25 - i * 0.15)
    return reverb(t)

def message():
    t = place([], bell(hz("A5"), 0.7, amp=0.8), 0.0, -0.1)
    return reverb(place(t, bell(hz("D6"), 0.9, amp=0.9), 0.09, 0.1), 0.12)

def complete():
    t = []
    for i, note in enumerate(["D5", "F#5", "A5"]):
        place(t, bell(hz(note), 0.8, amp=0.85), i * 0.07, -0.2 + i * 0.2)
    return reverb(t, 0.12)

def warning():
    t = place([], bell(hz("F#4"), 0.9, amp=0.9, bright=0.7), 0.0)
    return reverb(place(t, bell(hz("D4"), 1.1, amp=0.9, bright=0.7), 0.16), 0.1)

def error():
    t = place([], bell(hz("D3"), 0.6, amp=1.0, bright=0.5), 0.0)
    return reverb(place(t, bell(hz("D3"), 0.8, amp=1.0, bright=0.5), 0.14), 0.08)

def info():
    return reverb(place([], bell(hz("A5"), 0.8, amp=0.8), 0.0), 0.12)

def question():
    t = place([], bell(hz("D5"), 0.6, amp=0.8), 0.0)
    return reverb(place(t, bell(hz("B5"), 0.8, amp=0.8), 0.12), 0.12)

def device_added():
    t = place([], bell(hz("A4"), 0.35, amp=0.8, bright=0.6), 0.0)
    return place(t, bell(hz("D5"), 0.5, amp=0.9, bright=0.6), 0.08)

def device_removed():
    t = place([], bell(hz("D5"), 0.35, amp=0.8, bright=0.6), 0.0)
    return place(t, bell(hz("A4"), 0.5, amp=0.9, bright=0.6), 0.08)

def volume():
    return place([], bell(hz("D6"), 0.12, amp=1.0, bright=0.3), 0.0)

def bell_sound():
    return reverb(place([], bell(hz("D5"), 0.6, amp=0.9), 0.0), 0.1)

def shutter():
    t = place([], noise_burst(0.06, amp=1.0, decay=0.008), 0.0)
    return place(t, noise_burst(0.08, amp=0.8, decay=0.012), 0.07)

def channel(pan):
    """Thử loa (depot-sounds test): hợp âm khởi động rút gọn, chỉ phát ở một kênh."""
    t = []
    for i, note in enumerate(["D5", "F#5", "A5"]):
        place(t, bell(hz(note), 0.9, amp=0.9), i * 0.1, pan)
    return t

def trash():
    t = place([], noise_burst(0.35, amp=0.6, decay=0.12, hp=0.6), 0.0, -0.3)
    return place(t, bell(hz("D4"), 0.3, amp=0.3, bright=0.3), 0.05, 0.3)

SOUNDS = [
    ("desktop-login", "khởi động / đăng nhập", login, -3),
    ("desktop-logout", "đăng xuất", logout, -5),
    ("message-new-instant", "thông báo mới", message, -6),
    ("message", "thông báo", message, -6),
    ("complete", "xong việc", complete, -6),
    ("dialog-warning", "cảnh báo", warning, -6),
    ("dialog-error", "lỗi", error, -5),
    ("dialog-information", "thông tin", info, -8),
    ("dialog-question", "câu hỏi", question, -8),
    ("device-added", "cắm thiết bị (USB…)", device_added, -6),
    ("device-removed", "rút thiết bị", device_removed, -6),
    ("power-plug", "cắm sạc", device_added, -8),
    ("power-unplug", "rút sạc", device_removed, -8),
    ("audio-volume-change", "đổi âm lượng", volume, -10),
    ("bell", "chuông terminal", bell_sound, -8),
    ("screen-capture", "chụp màn hình", shutter, -8),
    ("trash-empty", "dọn thùng rác", trash, -8),
    ("audio-channel-front-left", "thử loa trái", lambda: channel(-1.0), -4),
    ("audio-channel-front-right", "thử loa phải", lambda: channel(1.0), -4),
]

def write_wav(path, track):
    with wave.open(path, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<hh", int(max(-1, min(1, l)) * 32767), int(max(-1, min(1, r)) * 32767))
                               for l, r in track))

def main():
    if not shutil.which("ffmpeg"):
        sys.exit("thiếu ffmpeg")
    st = os.path.join(OUT, "stereo")
    os.makedirs(st, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="depot-sounds-")
    try:
        cache = {}
        for name, desc, fn, db in SOUNDS:
            key = (fn, db)
            if key not in cache:
                cache[key] = finish(fn(), db)
            wav = os.path.join(tmp, name + ".wav")
            write_wav(wav, cache[key])
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5",
                            os.path.join(st, name + ".oga")], check=True)
            print("  %-22s %4.2f s  %s" % (name, len(cache[key]) / SR, desc))
    finally:
        shutil.rmtree(tmp)
    with open(os.path.join(OUT, "index.theme"), "w", encoding="utf-8", newline="\n") as f:
        f.write("[Sound Theme]\nName=Depot\nComment=Bộ âm thanh của Depot OS (tự tổng hợp, scripts/gen-sounds.py)\n"
                "Inherits=freedesktop\nDirectories=stereo\n\n[stereo]\nOutputProfile=stereo\n")
    kb = sum(os.path.getsize(os.path.join(st, x)) for x in os.listdir(st)) / 1024
    print("Đã ghi %d âm vào %s (%.0f KB)" % (len(SOUNDS), OUT, kb))

if __name__ == "__main__":
    main()
