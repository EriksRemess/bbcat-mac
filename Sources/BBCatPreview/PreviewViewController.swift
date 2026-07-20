import AppKit
import QuickLookUI

@objc(PreviewViewController)
final class PreviewViewController: NSViewController, QLPreviewingController {
    private let artworkView = ArtworkView(frame: .zero)

    override func loadView() {
        artworkView.autoresizingMask = [.width, .height]
        artworkView.fitsImage = true
        view = artworkView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let document = try BBCatDocument(url: url)
            let rendered = try document.frame(at: 0, scale: 1)
            artworkView.image = rendered.image
            title = document.displayTitle

            let size = rendered.image.size
            let maximum = NSSize(width: 1000, height: 800)
            let ratio = min(maximum.width / max(size.width, 1), maximum.height / max(size.height, 1), 1)
            preferredContentSize = NSSize(
                width: max(size.width * ratio, 320),
                height: max(size.height * ratio, 240)
            )
            handler(nil)
        } catch {
            handler(error)
        }
    }
}
