#!/bin/zsh
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
USER_HOME="${HOME}"
APP="${USER_HOME}/Applications/Wallpaper Studio.app"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O "$ROOT/WallpaperStudio.swift" -o "$APP/Contents/MacOS/BatmanLiveWallpaper"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/BatmanLiveWallpaper.icns" "$APP/Contents/Resources/BatmanLiveWallpaper.icns"

pkill -f "$APP/Contents/MacOS/BatmanLiveWallpaper" 2>/dev/null || true
open "$APP"
echo "Built and launched: $APP"
