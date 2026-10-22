import AppKit
import AVFoundation

final class VideoView: NSView {
    let playerLayer = AVPlayerLayer()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = playerLayer
        playerLayer.backgroundColor = NSColor.black.cgColor
        playerLayer.needsDisplayOnBoundsChange = true
        playerLayer.videoGravity = .resizeAspectFill
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

final class WallpaperWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let wallpaperDirectory = "/Users/user/Documents/Wallpapers"
    private var windows: [WallpaperWindow] = []
    private var players: [AVQueuePlayer] = []
    private var loopers: [AVPlayerLooper] = []
    private var statusItem: NSStatusItem!
    private var currentWallpaper: URL!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let wallpapers = availableWallpapers()
        guard let url = wallpapers.first else { NSApp.terminate(nil); return }
        currentWallpaper = url
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "🎞️"
        updateMenu()
        installWallpaper(url)
    }

    private func availableWallpapers() -> [URL] {
        let fm = FileManager.default
        let folder = URL(fileURLWithPath: wallpaperDirectory)
        let bundled = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension.lowercased() == "mp4" } ?? []
        return bundled.sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    private func updateMenu() {
        let menu = NSMenu()
        let heading = NSMenuItem(title: "Live Wallpaper", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        for url in availableWallpapers() {
            let item = NSMenuItem(title: url.deletingPathExtension().lastPathComponent,
                                  action: #selector(selectWallpaper(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = url
            item.state = (url == currentWallpaper) ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let refresh = NSMenuItem(title: "Rescan Wallpaper Folder", action: #selector(rescan), keyEquivalent: "")
        refresh.target = self
        menu.addItem(refresh)
        let quit = NSMenuItem(title: "Quit Live Wallpaper", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func selectWallpaper(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        currentWallpaper = url
        installWallpaper(url)
        updateMenu()
    }

    @objc private func rescan() { updateMenu() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func installWallpaper(_ url: URL) {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        players.removeAll()
        loopers.removeAll()

        for screen in NSScreen.screens {
            let window = WallpaperWindow(contentRect: screen.frame, styleMask: .borderless,
                                         backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: true)
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.isOpaque = true
            window.backgroundColor = .black
            window.ignoresMouseEvents = true
            let root = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            root.wantsLayer = true
            root.layer?.backgroundColor = NSColor.black.cgColor
            root.autoresizingMask = [.width, .height]
            let item = AVPlayerItem(url: url)
            let player = AVQueuePlayer(items: [item])
            let looper = AVPlayerLooper(player: player, templateItem: item)
            let view = VideoView(frame: root.bounds)
            view.playerLayer.player = player
            view.autoresizingMask = [.width, .height]
            root.addSubview(view)
            window.contentView = root
            window.orderFrontRegardless()
            player.play()
            players.append(player)
            loopers.append(looper)
            windows.append(window)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
