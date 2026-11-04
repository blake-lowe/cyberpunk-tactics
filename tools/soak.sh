#!/usr/bin/env bash
# Integration soak over the whole gig loop (tools/soak.gd). Args go to the script, e.g.
#   tools/soak.sh --campaigns=30 --gigs=5
# Output streams as it goes. Fails on any invariant breach, on a timeout (SOAK_TIMEOUT seconds,
# default 3600: a hang is a stuck state), and on script errors or game-code ERROR: lines in
# Godot's output (the engine's leak reports at exit don't count).
set -uo pipefail
cd "$(dirname "$0")/.."
godot --headless --path . --import >/dev/null 2>&1
log=$(mktemp)
trap 'rm -f "$log"' EXIT
timeout "${SOAK_TIMEOUT:-3600}" godot --headless --path . -s tools/soak.gd -- "$@" 2>&1 | tee "$log"
code=${PIPESTATUS[0]}
if [ "$code" -eq 124 ]; then echo "FAIL: timed out (a stuck state?)"; exit 1; fi
if ! tools/godot_errors.sh < "$log"; then exit 1; fi
exit "$code"
