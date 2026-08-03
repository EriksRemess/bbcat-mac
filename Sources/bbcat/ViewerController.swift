import AppKit
import UniformTypeIdentifiers

final class ViewerController: NSWindowController, NSWindowDelegate {
    private let artworkView = ArtworkView(frame: .zero)
    private let scrollView = NSScrollView(frame: .zero)
    private var artworkDocument: bbcatDocument?
    private var scale = 1
    private var supportsTwoX = false
    private var frameIndex = 0
    private var playbackGeneration = 0

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = "bbcat"
        window.minSize = NSSize(width: 400, height: 240)
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
        let toolbar = NSToolbar(identifier: "bbcatToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.delegate = self
        window?.toolbar = toolbar
        window?.toolbarStyle = .unified
    }

    private func showWelcomeArtwork() {
        artworkView.image = try? bbcatWelcome.image(scale: 1)
        artworkView.maximumFitScale = 2
        artworkView.setAccessibilityLabel("Open an artwork to view it")
    }

    func open(_ url: URL) {
        playbackGeneration &+= 1
        do {
            let loaded = try bbcatDocument(url: url)
            artworkDocument = loaded
            updateScaleControl(for: loaded)
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
        let previousScale = scale
        scale = newScale
        playbackGeneration &+= 1
        frameIndex = 0
        do {
            try displayFrame(generation: playbackGeneration, resizeWindow: true)
        } catch {
            scale = previousScale
            sender.selectedSegment = previousScale - 1
            present(error)
        }
    }

    private func updateScaleControl(for document: bbcatDocument?) {
        supportsTwoX = document?.supports(scale: 2) == true
        if !supportsTwoX {
            scale = 1
        }
        guard let toolbar = window?.toolbar else { return }
        for item in toolbar.items where item.itemIdentifier == Self.scaleIdentifier {
            item.isEnabled = supportsTwoX
            if let control = item.view as? NSSegmentedControl {
                configureScaleControl(control)
            }
        }
    }

    private func configureScaleControl(_ control: NSSegmentedControl) {
        control.selectedSegment = scale - 1
        control.isEnabled = supportsTwoX
        control.toolTip = switch (artworkDocument, supportsTwoX) {
        case (nil, _): "Open an artwork to change its rendering scale"
        case (_, true): "Rendering scale"
        case (_, false): "2x rendering exceeds the canvas pixel safety limit"
        }
    }

    private func displayFrame(generation: Int, resizeWindow: Bool) throws {
        guard generation == playbackGeneration, let artworkDocument else { return }
        let rendered = try artworkDocument.frame(at: frameIndex, scale: scale)
        artworkView.image = rendered.image
        configureLayout(for: rendered.image.size, resizeWindow: resizeWindow)

        guard artworkDocument.isAnimated else { return }
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
        let fitWidth = imageSize.width > maxWidth || imageSize.height > maxHeight

        if resizeWindow {
            let contentSize = NSSize(
                width: min(max(imageSize.width, 400), maxWidth),
                height: min(max(imageSize.height, 200), maxHeight)
            )
            window?.setContentSize(contentSize)
            window?.center()
        }

        if fitWidth {
            configureFitWidthLayout(for: imageSize)
            if resizeWindow {
                scrollView.contentView.scroll(to: .zero)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        } else {
            scrollView.hasHorizontalScroller = false
            scrollView.hasVerticalScroller = false
            artworkView.fitsImage = true
            artworkView.autoresizingMask = [.width, .height]
            artworkView.frame = NSRect(origin: .zero, size: scrollView.contentSize)
        }
    }

    private func configureFitWidthLayout(for imageSize: NSSize) {
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        artworkView.fitsImage = true
        artworkView.autoresizingMask = []

        let fullViewport = scrollView.contentSize
        let fullWidthHeight = fullViewport.width * imageSize.height / max(imageSize.width, 1)
        scrollView.hasVerticalScroller = fullWidthHeight > fullViewport.height

        // A non-overlay scroller narrows the viewport, so calculate once more using
        // the final content width. The document always matches that width and can
        // therefore only scroll vertically, just like the iOS viewer.
        let viewport = scrollView.contentSize
        let fittedHeight = viewport.width * imageSize.height / max(imageSize.width, 1)
        artworkView.frame = NSRect(
            origin: .zero,
            size: NSSize(width: viewport.width, height: max(ceil(fittedHeight), viewport.height))
        )
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
            item.visibilityPriority = .high
        } else if identifier == Self.scaleIdentifier {
            let control = NSSegmentedControl(labels: ["×1", "×2"], trackingMode: .selectOne,
                                             target: self, action: #selector(changeScale(_:)))
            control.setAccessibilityLabel("Rendering scale")
            configureScaleControl(control)
            item.label = "Scale"
            item.view = control
            item.isEnabled = supportsTwoX
            item.visibilityPriority = .high
        } else { return nil }
        return item
    }
}
