#!/bin/sh
# Depot OS — cắt một video thành boot animation cho Plymouth (theme "depot")
#
#   scripts/video-to-plymouth.sh VIDEO [--loop-from GIÂY] [--height PX] [--fps N]
#
#   VIDEO        mp4/webm/mov/gif… (video có kênh trong suốt thì giữ trong suốt)
#   --loop-from  chạy cả video một lượt, sau đó lặp đoạn từ giây này tới hết (mặc định 0 = lặp cả video;
#                bằng độ dài video = dừng ở khung cuối)
#   --height     chiều cao khung hình (mặc định = video, tối đa 360)
#   --fps        khung/giây (mặc định 25)
#
# Ghi vào theme: frame-NNN.png + bar.png + depot.script (sinh từ scripts/plymouth/depot.script.in).
# Nền màn hình boot lấy theo màu góc trên-trái của khung đầu, để video không lộ khung chữ nhật.
# Mọi khung hình nằm trong initramfs: giữ ít khung, ảnh nhỏ (máy cũ đọc USB chậm) — vượt 150 khung là dừng.
# Video mặc định: design/boot/depot-boot.mp4 (scripts/gen-boot-video.py), lặp từ 1.6 giây.
# Cần: ffmpeg, ffprobe. Sau đó build lại ISO (hook 0800 cập nhật initramfs).
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
THEME="$ROOT/build/live-build/config/includes.chroot/usr/share/plymouth/themes/depot"
TEMPLATE="$ROOT/scripts/plymouth/depot.script.in"
MAX_FRAMES=150

VIDEO=${1:-}
[ -n "$VIDEO" ] && [ -r "$VIDEO" ] || { sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
shift
LOOP_FROM=0 HEIGHT= FPS=25
while [ $# -gt 0 ]; do
    case "$1" in
        --loop-from) LOOP_FROM=${2:?}; shift ;;
        --height) HEIGHT=${2:?}; shift ;;
        --fps) FPS=${2:?}; shift ;;
        *) echo "tuỳ chọn lạ: $1" >&2; exit 2 ;;
    esac
    shift
done
case "$FPS" in ''|*[!0-9]*) echo "--fps cần số nguyên" >&2; exit 2 ;; esac
case "$HEIGHT" in *[!0-9]*) echo "--height cần số nguyên" >&2; exit 2 ;; esac
for t in ffmpeg ffprobe; do command -v $t >/dev/null || { echo "thiếu $t" >&2; exit 1; }; done

probe() { ffprobe -v error -select_streams v:0 -show_entries "stream=$1" -of default=nw=1:nk=1 "$VIDEO" | head -1; }
SRC_H=$(probe height)
PIX=$(probe pix_fmt)
[ -n "$HEIGHT" ] || HEIGHT=$SRC_H
[ "$HEIGHT" -gt 360 ] && HEIGHT=360
# kênh alpha (yuva420p, rgba, argb…) thì giữ, không thì PNG RGB cho nhẹ
case "$PIX" in *a*p*|rgba*|argb*|bgra*|abgr*|ya*|pal8) OUTPIX=rgba ;; *) OUTPIX=rgb24 ;; esac

rm -f "$THEME"/frame-*.png
ffmpeg -loglevel error -y -i "$VIDEO" -vf "fps=$FPS,scale=-2:$HEIGHT:flags=lanczos" -pix_fmt "$OUTPIX" \
    -compression_level 9 -start_number 0 "$THEME/frame-%03d.png"
N=$(ls "$THEME"/frame-*.png | wc -l)
if [ "$N" -gt $MAX_FRAMES ]; then
    rm -f "$THEME"/frame-*.png
    echo "!! $N khung > $MAX_FRAMES: cắt ngắn video hoặc hạ --fps (mọi khung nằm trong initramfs)" >&2
    exit 1
fi
LOOP=$(awk -v s="$LOOP_FROM" -v f="$FPS" -v n="$N" 'BEGIN { l = int(s * f + 0.5); if (l > n) l = n; if (l < 0) l = 0; print l }')

# màu nền = điểm ảnh góc trên-trái (trong suốt thì giữ nền Depot #0f1420)
set -- $(ffmpeg -loglevel error -i "$THEME/frame-000.png" -vf "crop=1:1:0:0,format=rgba" -f rawvideo - | od -An -tu1)
if [ "${4:-255}" -lt 128 ]; then set -- 15 20 32 255; fi
BG_R=$1 BG_G=$2 BG_B=$3

# ô trắng cho thanh tiến trình
ffmpeg -loglevel error -y -f lavfi -i color=white:s=4x4 -frames:v 1 "$THEME/bar.png"

sed -e "s/@FRAMES@/$N/" -e "s/@LOOP@/$LOOP/" -e "s/@FPS@/$FPS/" \
    -e "s/@BG_R@/$BG_R/" -e "s/@BG_G@/$BG_G/" -e "s/@BG_B@/$BG_B/" "$TEMPLATE" > "$THEME/depot.script"

KB=$(du -ck "$THEME"/frame-*.png | tail -1 | cut -f1)
echo ">> $N khung ${HEIGHT}px ($OUTPIX) @ ${FPS} fps, lặp từ khung $LOOP, nền rgb($BG_R,$BG_G,$BG_B), ${KB} KB vào initramfs"
