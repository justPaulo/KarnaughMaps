#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/build/KarnaughMaps.app"
CONTENTS_DIR="$APP_DIR/Contents"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/build/AppIcon.iconset"

mkdir -p "$CONTENTS_DIR/MacOS" "$RESOURCES_DIR" "$ROOT_DIR/build"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

swiftc \
  -parse-as-library \
  -swift-version 5 \
  -framework AppKit \
  "$ROOT_DIR/AppIcon.swift" \
  -o "$ROOT_DIR/build/AppIconGenerator"

"$ROOT_DIR/build/AppIconGenerator" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

swiftc \
  -parse-as-library \
  -swift-version 5 \
  -framework SwiftUI \
  -framework AppKit \
  "$ROOT_DIR/KarnaughLogic.swift" \
  "$ROOT_DIR/KarnaughMapsApp.swift" \
  -o "$CONTENTS_DIR/MacOS/KarnaughMaps"

printf 'Built %s\n' "$APP_DIR"
