import AppKit

final class ArtworkView: NSView {
    var image: NSImage? { didSet { needsDisplay = true } }
    var fitsImage = true { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()
        guard let image, image.size.width > 0, image.size.height > 0 else { return }

        let destination: NSRect
        if fitsImage {
            let ratio = min(bounds.width / image.size.width, bounds.height / image.size.height)
            let size = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
            destination = NSRect(
                x: (bounds.width - size.width) / 2,
                y: (bounds.height - size.height) / 2,
                width: size.width,
                height: size.height
            )
        } else {
            destination = NSRect(
                x: max((bounds.width - image.size.width) / 2, 0),
                y: max((bounds.height - image.size.height) / 2, 0),
                width: image.size.width,
                height: image.size.height
            )
        }
        image.draw(in: destination, from: .zero, operation: .copy, fraction: 1,
                   respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
    }
}
