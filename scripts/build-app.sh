#!/usr/bin/env bash
# Compila em release e monta build/ClaudeTouchBar.app (assinatura ad-hoc).
# Uso: scripts/build-app.sh [--install]   (--install copia para ~/Applications)
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="ClaudeTouchBar"
APP="build/${APP_NAME}.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/${APP_NAME}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null

echo "✅ $APP"

if [[ "${1:-}" == "--install" ]]; then
  mkdir -p "$HOME/Applications"
  pkill -x "$APP_NAME" 2>/dev/null || true
  rm -rf "$HOME/Applications/${APP_NAME}.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "📦 instalado em ~/Applications/${APP_NAME}.app"
fi
