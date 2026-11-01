#!/usr/bin/env bash
# Runs the headless unit tests. Optional arg: substring filter on test file names.
# Fails if any assertion fails OR Godot reports a script/parse error.
set -uo pipefail
cd "$(dirname "$0")/.."
# Refresh the import cache so class_name globals resolve.
godot --headless --path . --import >/dev/null 2>&1
out=$(timeout 900 godot --headless --path . -s tests/run_tests.gd -- "${1:-}" 2>&1)
code=$?
echo "$out"
if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error|Failed to load script"; then
  echo "FAIL: script errors detected"; exit 1
fi
exit $code
