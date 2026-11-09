#!/usr/bin/env bash
# Runs the headless unit tests. Optional arg: substring filter on test file names.
# Fails if any assertion fails OR Godot reports a script/parse error.
set -uo pipefail
cd "$(dirname "$0")/.."
# data/world/ is generated from docs/world/: fail if someone edited one without the other.
if command -v python3 >/dev/null 2>&1; then
  if ! python3 tools/gen_world_data.py --check; then
    echo "FAIL: data/world is out of date with docs/world (run python3 tools/gen_world_data.py)"; exit 1
  fi
fi
# TEST_TIMEOUT (seconds, default 900): raise it when other Godot jobs share the machine.
# Refresh the import cache so class_name globals resolve.
godot --headless --path . --import >/dev/null 2>&1
out=$(timeout "${TEST_TIMEOUT:-900}" godot --headless --path . -s tests/run_tests.gd -- "${1:-}" 2>&1)
code=$?
echo "$out"
if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error|Failed to load script"; then
  echo "FAIL: script errors detected"; exit 1
fi
exit $code
