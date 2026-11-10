#!/usr/bin/env bash
# Smoke-test the game as it ships: export the release preset's data pack, then run the safehouse and a
# gig from that pack (not from the repo) and fail on any script error or a missing screenshot.
# The unit tests run from the repo, where tools/, tests/ and docs/ exist; the export leaves them out,
# so code that leans on them only breaks here (v0.10.0-playtest: a dark safehouse and grey gigs).
# The safehouse needs --base: with --shot it would otherwise hand straight on to a gig.
# Needs Godot, the export templates and xvfb-run. Usage: tools/export_smoke.sh [out_dir]
set -uo pipefail
cd "$(dirname "$0")/.."
OUT="$(realpath -m "${1:-build/smoke}")"
rm -rf "$OUT" && mkdir -p "$OUT"
PCK="$OUT/game.pck"
if ! timeout 900 godot --headless --export-pack "Windows Desktop" "$PCK" >"$OUT/export.log" 2>&1; then
  echo "FAIL: export"; tail -20 "$OUT/export.log"; exit 1
fi
fail=0
run() {   # name, scene, args...
  local name="$1" scene="$2"; shift 2
  local shot="$OUT/$name.png"
  # Run outside the repo so nothing but the pack can be loaded.
  (cd "$OUT" && timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-method gl_compatibility \
    --resolution 1280x720 --main-pack "$PCK" "$scene" -- "$@" --shot="$shot") >"$OUT/$name.log" 2>&1
  if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Compile Error" "$OUT/$name.log"; then
    echo "FAIL: $name: script errors in the exported build"; grep -E "SCRIPT ERROR|Parse Error|Failed to load|Compile Error" "$OUT/$name.log" | sort -u | head -10; fail=1
  elif [ ! -s "$shot" ]; then
    echo "FAIL: $name: no screenshot (hung or crashed)"; tail -10 "$OUT/$name.log"; fail=1
  else
    echo "ok: $name"
  fi
}
run safehouse res://scenes/base.tscn --demo --base
run jobs res://scenes/base.tscn --demo --screen=jobs
run gig res://scenes/greybox.tscn --scene=lone_building --seed=11
exit $fail
