#!/bin/zsh
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
USER_HOME="${HOME}"
SYSTEM_APP="/Applications/Wallpaper Studio.app"
USER_APP="${USER_HOME}/Applications/Wallpaper Studio.app"
if [[ -d "/Applications" && -w "/Applications" ]]; then
  APP="$SYSTEM_APP"
else
  APP="$USER_APP"
fi

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O "$ROOT/WallpaperStudio.swift" -o "$APP/Contents/MacOS/BatmanLiveWallpaper"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/BatmanLiveWallpaper.icns" "$APP/Contents/Resources/BatmanLiveWallpaper.icns"

pkill -f "$APP/Contents/MacOS/BatmanLiveWallpaper" 2>/dev/null || true
open "$APP"
echo "Built and launched: $APP"
