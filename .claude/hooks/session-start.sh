#!/bin/bash
# Sesiones de Claude Code en la nube: instala Godot (headless) e importa el
# proyecto para poder correr los tests de GUT. En la PC local no hace nada.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.7.2-stable"
GODOT_DIR="$HOME/.local/godot"
GODOT_BIN="$GODOT_DIR/Godot_v${GODOT_VERSION}_linux.x86_64"

if [ ! -x "$GODOT_BIN" ]; then
  mkdir -p "$GODOT_DIR"
  curl -sSfL -o "$GODOT_DIR/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  unzip -o -q "$GODOT_DIR/godot.zip" -d "$GODOT_DIR"
  rm -f "$GODOT_DIR/godot.zip"
  chmod +x "$GODOT_BIN"
fi

mkdir -p "$HOME/.local/bin"
ln -sf "$GODOT_BIN" "$HOME/.local/bin/godot"
echo "export PATH=\"$HOME/.local/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"

# Importa los assets y arma la caché de clases (.godot/), necesaria para que
# los class_name se resuelvan en los tests. Es idempotente.
cd "$CLAUDE_PROJECT_DIR"
timeout 600 "$GODOT_BIN" --headless --import > /dev/null 2>&1 || true
