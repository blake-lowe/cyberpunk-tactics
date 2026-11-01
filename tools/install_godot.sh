#!/usr/bin/env bash
# Installs the pinned Godot version to /opt/godot and links it as `godot`.
set -euo pipefail
VERSION="${GODOT_VERSION:-4.7.2}"
if command -v godot >/dev/null && godot --headless --version 2>/dev/null | grep -q "^${VERSION}\."; then
  echo "Godot ${VERSION} already installed"; exit 0
fi
mkdir -p /opt/godot
cd /opt/godot
curl -sSL -o g.zip "https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_linux.x86_64.zip"
unzip -oq g.zip && rm g.zip
ln -sf "/opt/godot/Godot_v${VERSION}-stable_linux.x86_64" /usr/local/bin/godot
godot --headless --version
