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

final class WallpaperTileView: NSView {
    let imageView = NSImageView()
    let titleField = NSTextField(labelWithString: "")
    var onHover: ((Bool) -> Void)?
    var isHighlighted = false { didSet { updateAppearance() } }
    var isSelected = false { didSet { updateAppearance() } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 9
        imageView.layer?.masksToBounds = true
        titleField.alignment = .center
        titleField.lineBreakMode = .byTruncatingMiddle
        titleField.maximumNumberOfLines = 1
        titleField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        addSubview(titleField)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            imageView.heightAnchor.constraint(equalToConstant: 88),
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            titleField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self))
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { isHighlighted = true; onHover?(true) }
    override func mouseExited(with event: NSEvent) { isHighlighted = false; onHover?(false) }

    private func updateAppearance() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(isHighlighted || isSelected ? 0.95 : 0.72).cgColor
        layer?.borderColor = (isSelected ? NSColor.systemPink : (isHighlighted ? NSColor.systemCyan : NSColor.separatorColor)).cgColor
        layer?.borderWidth = isSelected || isHighlighted ? 2 : 1
        layer?.shadowColor = NSColor.systemCyan.cgColor
        layer?.shadowRadius = isHighlighted ? 8 : 0
        layer?.shadowOpacity = isHighlighted ? 0.7 : 0
    }
}

final class WallpaperGridItem: NSCollectionViewItem {
    private var tile: WallpaperTileView { view as! WallpaperTileView }
    override func loadView() { view = WallpaperTileView(frame: NSRect(x: 0, y: 0, width: 150, height: 125)) }
    override var isSelected: Bool { didSet { tile.isSelected = isSelected } }

    func configure(with url: URL) {
        tile.titleField.stringValue = url.deletingPathExtension().lastPathComponent
        tile.imageView.image = NSImage(systemSymbolName: "film", accessibilityDescription: "Video")
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 280, height: 180)
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { [weak self] _, image, _, _, _ in
            guard let image else { return }
            DispatchQueue.main.async { self?.tile.imageView.image = NSImage(cgImage: image, size: .zero) }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSCollectionViewDataSource, NSCollectionViewDelegate {
    private let wallpaperDirectoryKey = "wallpaperDirectory"
    private var wallpaperDirectory: URL {
        if let savedPath = UserDefaults.standard.string(forKey: wallpaperDirectoryKey) {
            return URL(fileURLWithPath: savedPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Wallpapers", isDirectory: true)
    }
    private var windows: [WallpaperWindow] = []
    private var players: [AVQueuePlayer] = []
    private var loopers: [AVPlayerLooper] = []
    private var statusItem: NSStatusItem!
    private var currentWallpaper: URL!
    private var pickerWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: wallpaperDirectory, withIntermediateDirectories: true)
        let wallpapers = availableWallpapers()
        currentWallpaper = wallpapers.first
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateMenu()
        if let url = currentWallpaper { installWallpaper(url) }
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
        statusItem.menu = nil
        if let iconURL = Bundle.main.url(forResource: "BatmanLiveWallpaper", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = false
            statusItem.button?.image = icon
            statusItem.button?.title = ""
        } else {
            statusItem.button?.image = nil
            statusItem.button?.title = "🎞️"
        }
        statusItem.button?.toolTip = "Open Wallpaper Studio thumbnail grid"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(openPicker)
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

    @objc private func chooseWallpaperFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Wallpaper Folder"
        panel.message = "Select the folder containing your MP4 wallpapers."
        panel.prompt = "Use This Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = wallpaperDirectory
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.path, forKey: wallpaperDirectoryKey)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        currentWallpaper = availableWallpapers().first
        updateMenu()
        refreshPicker()
        if let url = currentWallpaper { installWallpaper(url) }
    }

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

        let displayPath = wallpaperDirectory.path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
        let hint = NSTextField(labelWithString: "Videos are loaded locally from \(displayPath)")
        hint.textColor = .secondaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hint)

        let folderButton = NSButton(title: "Choose Wallpaper Folder…", target: self, action: #selector(chooseWallpaperFolder))
        folderButton.bezelStyle = .rounded
        folderButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(folderButton)
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 150, height: 125)
        layout.sectionInset = NSEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 12
        let collection = NSCollectionView()
        collection.collectionViewLayout = layout
        collection.isSelectable = true
        collection.allowsEmptySelection = true
        collection.allowsMultipleSelection = false
        collection.dataSource = self
        collection.delegate = self
        collection.register(WallpaperGridItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("WallpaperGridItem"))
        collection.backgroundColors = [.clear]
        collection.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = collection
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 22),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 22),
            hint.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            hint.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            folderButton.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 10),
            folderButton.leadingAnchor.constraint(equalTo: hint.leadingAnchor),
            scroll.topAnchor.constraint(equalTo: folderButton.bottomAnchor, constant: 14),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        window.contentView = container
        window.makeFirstResponder(collection)
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        availableWallpapers().count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("WallpaperGridItem"), for: indexPath) as! WallpaperGridItem
        item.configure(with: availableWallpapers()[indexPath.item])
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        let wallpapers = availableWallpapers()
        guard indexPath.item < wallpapers.count else { return }
        currentWallpaper = wallpapers[indexPath.item]
        installWallpaper(currentWallpaper)
        updateMenu()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        collectionView.reloadData()
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
