#!/usr/bin/env bash
# Export a Windows x86_64 build to build/windows/ and zip it to build/CyberpunkTactics-windows-<tag>.zip.
# Needs Godot (tools/install_godot.sh) and the 4.7.2 Windows export templates in
# ~/.local/share/godot/export_templates/4.7.2.stable/ (from the official export_templates.tpz).
set -euo pipefail
cd "$(dirname "$0")/.."
TAG="${1:-dev}"
rm -rf build/windows && mkdir -p build/windows
timeout 900 godot --headless --export-release "Windows Desktop" build/windows/CyberpunkTactics.exe
cp LICENSE* README* build/windows/ 2>/dev/null || true
mkdir -p build/windows/licenses
cp assets/fonts/OFL-*.txt build/windows/licenses/
cp assets/fonts/APACHE-*.txt build/windows/licenses/ 2>/dev/null || true
find assets/third_party -iname "LICENSE*.txt" -exec cp {} build/windows/licenses/ \;
(cd build && rm -f "CyberpunkTactics-windows-$TAG.zip" && zip -qr "CyberpunkTactics-windows-$TAG.zip" windows)
ls -la "build/CyberpunkTactics-windows-$TAG.zip"
