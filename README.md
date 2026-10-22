# Wallpaper Studio

Wallpaper Studio is a lightweight, local-only macOS live wallpaper player. It runs as a menu-bar utility, supports multiple monitors, and lets you switch between MP4 wallpapers without restarting the app.

## Features

- One live wallpaper window per connected display.
- Loops MP4 videos continuously using AVFoundation.
- Supports separate monitor resolutions and arrangements.
- Menu-bar selector with the 🎞️ icon.
- Automatically scans `~/Documents/Wallpapers`.
- “Rescan Wallpaper Folder” for newly added videos.
- No upload, account, subscription, or network service required.

## Requirements

- macOS 15 or newer.
- Swift compiler and AppKit/AVFoundation frameworks (Xcode Command Line Tools).
- At least one MP4 file in `~/Documents/Wallpapers`.

## Install the packaged app

GitHub Actions produces `Wallpaper-Studio-macos.zip` and `Wallpaper-Studio-macos.dmg`:

1. Open the DMG, or unzip the archive.
2. Drag `Wallpaper Studio.app` to the `Applications` shortcut in the DMG window.
3. Create `~/Documents/Wallpapers` and copy MP4 files there.
4. Open the app and look for the 🎞️ icon in the menu bar.
5. Select any wallpaper from the menu.

If macOS shows a security warning for an unsigned build, use Finder’s Open command from the app’s context menu once.

## Build locally

```sh
./build.sh
```

The script compiles the Swift source, assembles the app bundle, installs it at `~/Applications/Wallpaper Studio.app`, and launches it.

## Wallpaper folder

Put wallpapers here:

```text
~/Documents/Wallpapers
```

Only `.mp4` files are shown. Add a video, click the 🎞️ menu-bar icon, and choose **Rescan Wallpaper Folder**.

## Repository layout

```text
WallpaperStudio.swift              App source
Info.plist                         macOS app metadata
Resources/BatmanLiveWallpaper.icns App icon
build.sh                           Local build and launch script
.github/workflows/build.yml        GitHub Actions packaging workflow
```

## GitHub Actions packaging

The workflow runs on `macos-latest` for pushes to `main`, version tags, or manual runs. It compiles the app, creates `Wallpaper Studio.app`, packages it as both a ZIP and a DMG with an Applications shortcut, and uploads both files as workflow artifacts.

Create a versioned build with:

```sh
git tag v1.0.0
git push origin v1.0.0
```

## Limitations

- Wallpaper videos are supplied by the user and are not bundled.
- The app is unsigned and not notarized.
- The app does not yet install itself as a login item.

## License

This repository contains the Wallpaper Studio application code. Wallpaper videos remain the property of their respective creators and are not included in the distributable app.
