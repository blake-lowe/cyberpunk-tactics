#!/usr/bin/env bash
# Every CharAnims clip as a small MP4 for review. Usage: tools/anim_reel.sh OUT_DIR [clip ...]
set -eu
OUT=${1:?out dir}; shift
cd "$(dirname "$0")/.."
mkdir -p "$OUT/frames"
timeout 3000 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-method gl_compatibility --fixed-fps 24 --path . \
	-s tools/anim_reel.gd -- "$OUT/frames" "$@" >"$OUT/anim_reel.log" 2>&1 || true
for d in "$OUT"/frames/*/; do
	c=$(basename "$d")
	ffmpeg -y -loglevel error -framerate 24 -i "$d/%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 24 -preset slow -movflags +faststart "$OUT/$c.mp4"
done
echo "clips: $(ls "$OUT"/*.mp4 | wc -l)"
