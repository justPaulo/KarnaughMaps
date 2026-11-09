#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/build/KarnaughMaps.app"
CONTENTS_DIR="$APP_DIR/Contents"

mkdir -p "$CONTENTS_DIR/MacOS"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

swiftc \
  -parse-as-library \
  -swift-version 5 \
  -framework SwiftUI \
  -framework AppKit \
  "$ROOT_DIR/KarnaughLogic.swift" \
  "$ROOT_DIR/KarnaughMapsApp.swift" \
  -o "$CONTENTS_DIR/MacOS/KarnaughMaps"

printf 'Built %s\n' "$APP_DIR"
