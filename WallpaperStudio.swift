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
    private var wallpaperDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Wallpapers", isDirectory: true)
    }
    private var windows: [WallpaperWindow] = []
    private var players: [AVQueuePlayer] = []
    private var loopers: [AVPlayerLooper] = []
    private var statusItem: NSStatusItem!
    private var currentWallpaper: URL!
    private var pickerWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let wallpapers = availableWallpapers()
        guard let url = wallpapers.first else { NSApp.terminate(nil); return }
        currentWallpaper = url
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "🎞️"
        updateMenu()
        installWallpaper(url)
        openPicker()
    }

    private func availableWallpapers() -> [URL] {
        let fm = FileManager.default
        let bundled = (try? fm.contentsOfDirectory(at: wallpaperDirectory, includingPropertiesForKeys: nil))?
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
        let picker = NSMenuItem(title: "Open Wallpaper Picker…", action: #selector(openPicker), keyEquivalent: "o")
        picker.target = self
        menu.addItem(picker)
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
        refreshPicker()
    }

    @objc private func rescan() { updateMenu() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openPicker() {
        if pickerWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
                                  styleMask: [.titled, .closable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "Wallpaper Studio"
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 420, height: 420)
            pickerWindow = window
        }
        refreshPicker()
        NSApp.activate(ignoringOtherApps: true)
        pickerWindow?.center()
        pickerWindow?.makeKeyAndOrderFront(nil)
    }

    private func refreshPicker() {
        guard let window = pickerWindow else { return }
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 620))
        let title = NSTextField(labelWithString: "Choose a live wallpaper")
        title.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(title)

        let hint = NSTextField(labelWithString: "Videos are loaded locally from ~/Documents/Wallpapers")
        hint.textColor = .secondaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hint)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        for url in availableWallpapers() {
            let button = NSButton(title: url.deletingPathExtension().lastPathComponent,
                                  target: self, action: #selector(selectFromPicker(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(url.path)
            button.alignment = .left
            button.controlSize = .large
            button.bezelStyle = .rounded
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 450).isActive = true
            stack.addArrangedSubview(button)
        }

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = stack
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 22),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 22),
            hint.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            hint.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            scroll.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 18),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        window.contentView = container
    }

    @objc private func selectFromPicker(_ sender: NSButton) {
        guard let rawPath = sender.identifier?.rawValue else { return }
        let url = URL(fileURLWithPath: rawPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        currentWallpaper = url
        installWallpaper(url)
        updateMenu()
        refreshPicker()
    }

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
