#!/usr/bin/env bash
# Reads Godot output on stdin; prints game-code errors (SCRIPT ERROR, parse errors, failed loads,
# and ERROR: lines) and exits 1 if there are any. The engine's own reports at exit (leaked
# ObjectDB instances, RIDs, resources still in use, paged allocators) are not the game's and pass.
set -uo pipefail
errs=$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|^ERROR:" \
  | grep -vE "leaked at exit|still in use at exit|Pages in use exist at exit|ObjectDB instances")
if [ -n "$errs" ]; then
  echo "FAIL: script errors detected:"
  echo "$errs"
  exit 1
fi
exit 0
