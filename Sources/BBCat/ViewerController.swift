import AppKit
import UniformTypeIdentifiers

final class ViewerController: NSWindowController, NSWindowDelegate {
    private let artworkView = ArtworkView(frame: .zero)
    private let scrollView = NSScrollView(frame: .zero)
    private var artworkDocument: BBCatDocument?
    private var scale = 1
    private var frameIndex = 0
    private var playbackGeneration = 0
    private var nativeSizeMode = false

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = "bbcat"
        window.minSize = NSSize(width: 320, height: 240)
        window.center()
        window.delegate = self
        configureContent()
        configureToolbar()
        showWelcomeArtwork()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configureContent() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .black
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        artworkView.autoresizingMask = [.width, .height]
        scrollView.documentView = artworkView
        window?.contentView = scrollView
    }

    private func configureToolbar() {
        let toolbar = NSToolbar(identifier: "BBCatToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.delegate = self
        window?.toolbar = toolbar
        window?.toolbarStyle = .unified
    }

    private func showWelcomeArtwork() {
        artworkView.image = try? BBCatWelcome.image(scale: 1)
        artworkView.maximumFitScale = 2
        artworkView.setAccessibilityLabel("Open an artwork to view it")
    }

    func open(_ url: URL) {
        playbackGeneration &+= 1
        do {
            let loaded = try BBCatDocument(url: url)
            artworkDocument = loaded
            artworkView.maximumFitScale = nil
            frameIndex = 0
            window?.title = loaded.displayTitle
            try displayFrame(generation: playbackGeneration, resizeWindow: true)
            window?.representedURL = url
        } catch {
            present(error)
        }
    }

    @objc private func chooseFile() {
        let panel = NSOpenPanel()
        panel.title = "Open ANSI art"
        panel.prompt = "Open"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = ["ans", "asc", "diz", "nfo", "ddw", "adf", "rip", "xb", "xbin"]
            .compactMap { UTType(filenameExtension: $0) }
        panel.beginSheetModal(for: window!) { [weak self] response in
            if response == .OK, let url = panel.url { self?.open(url) }
        }
    }

    @objc private func changeScale(_ sender: NSSegmentedControl) {
        let newScale = sender.selectedSegment + 1
        guard newScale != scale else { return }
        scale = newScale
        playbackGeneration &+= 1
        frameIndex = 0
        do { try displayFrame(generation: playbackGeneration, resizeWindow: true) }
        catch { present(error) }
    }

    private func displayFrame(generation: Int, resizeWindow: Bool) throws {
        guard generation == playbackGeneration, let artworkDocument else { return }
        let rendered = try artworkDocument.frame(at: frameIndex, scale: scale)
        artworkView.image = rendered.image
        configureLayout(for: rendered.image.size, resizeWindow: resizeWindow)

        guard artworkDocument.frameCount > 1 else { return }
        let delay = max(rendered.duration, 0.001)
        frameIndex = (frameIndex + 1) % artworkDocument.frameCount
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, generation == self.playbackGeneration else { return }
            do { try self.displayFrame(generation: generation, resizeWindow: false) }
            catch { self.present(error) }
        }
    }

    private func configureLayout(for imageSize: NSSize, resizeWindow: Bool) {
        let visible = window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let maxWidth = floor(visible.width * 0.9)
        let maxHeight = floor(visible.height * 0.9)
        nativeSizeMode = imageSize.width > maxWidth || imageSize.height > maxHeight
        artworkView.fitsImage = !nativeSizeMode
        scrollView.hasHorizontalScroller = nativeSizeMode && imageSize.width > scrollView.contentSize.width
        scrollView.hasVerticalScroller = nativeSizeMode && imageSize.height > scrollView.contentSize.height

        if nativeSizeMode {
            artworkView.autoresizingMask = []
            artworkView.frame = NSRect(origin: .zero, size: NSSize(
                width: max(imageSize.width, scrollView.contentSize.width),
                height: max(imageSize.height, scrollView.contentSize.height)
            ))
        } else {
            artworkView.autoresizingMask = [.width, .height]
            artworkView.frame = NSRect(origin: .zero, size: scrollView.contentSize)
        }

        if resizeWindow {
            let contentSize = NSSize(
                width: min(max(imageSize.width, 320), maxWidth),
                height: min(max(imageSize.height, 200), maxHeight)
            )
            window?.setContentSize(contentSize)
            window?.center()
        }
    }

    func windowDidResize(_ notification: Notification) {
        guard let size = artworkView.image?.size else { return }
        configureLayout(for: size, resizeWindow: false)
    }

    private func present(_ error: Error) {
        playbackGeneration &+= 1
        let alert = NSAlert(error: error)
        alert.messageText = "Could not open ANSI art"
        if let window { alert.beginSheetModal(for: window) }
    }
}

extension ViewerController: NSToolbarDelegate {
    private static let openIdentifier = NSToolbarItem.Identifier("Open")
    private static let scaleIdentifier = NSToolbarItem.Identifier("Scale")

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.openIdentifier, .flexibleSpace, Self.scaleIdentifier]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.openIdentifier, .flexibleSpace, Self.scaleIdentifier]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        if identifier == Self.openIdentifier {
            item.label = "Open"
            item.toolTip = "Open ANSI art"
            item.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Open")
            item.target = self
            item.action = #selector(chooseFile)
        } else if identifier == Self.scaleIdentifier {
            let control = NSSegmentedControl(labels: ["×1", "×2"], trackingMode: .selectOne,
                                             target: self, action: #selector(changeScale(_:)))
            control.selectedSegment = scale - 1
            control.setAccessibilityLabel("Rendering scale")
            item.label = "Scale"
            item.view = control
        } else { return nil }
        return item
    }
}
