#!/usr/bin/env bash
# Record review videos of combat beats (greybox --reel=NAME) with Godot's movie writer, then
# encode small MP4s. Usage: tools/review_videos.sh OUT_DIR [reel ...]
set -u
OUT=${1:?out dir}; shift
REELS=${*:-"move single auto kill headshot armor pistol cover enemy jack melee suppress shell grenade stabilize reload"}
mkdir -p "$OUT"
cd "$(dirname "$0")/.."
for r in $REELS; do
	(
	timeout 1500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-method gl_compatibility --path . \
		--write-movie "$OUT/${PREFIX:-}$r.avi" --fixed-fps 24 -- --scene=${SCENE:-skirmish} --reveal=1 --fog=0 --zoom=${ZOOM:-11} --reel="$r" >"$OUT/${PREFIX:-}$r.log" 2>&1
	ffmpeg -y -loglevel error -i "$OUT/${PREFIX:-}$r.avi" -vf "scale=1280:-2:flags=neighbor" -c:v libx264 -pix_fmt yuv420p -crf 23 -preset slow -movflags +faststart "$OUT/${PREFIX:-}$r.mp4" && rm -f "$OUT/${PREFIX:-}$r.avi"
	echo "done $r"
	) &
	while [ "$(jobs -r | wc -l)" -ge "${JOBS:-4}" ]; do sleep 2; done
done
wait
