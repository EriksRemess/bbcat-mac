import AppKit
import QuickLookThumbnailing

@objc(ThumbnailProvider)
final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        do {
            guard let handle = request.fileURL.path.withCString({ bbcat_document_open($0) }) else {
                throw thumbnailError("Could not decode the artwork")
            }
            defer { bbcat_document_free(handle) }

            let requestedPixels = max(request.maximumSize.width, request.maximumSize.height) * request.scale
            let maximumPixels = max(1, min(Int(ceil(requestedPixels)), 1024))
            var frame = BbcatFrame(data: nil, length: 0, duration_ns: 0)
            guard bbcat_document_render_thumbnail(handle, maximumPixels, &frame) != 0,
                  let bytes = frame.data else {
                throw thumbnailError("Could not render the artwork")
            }
            defer { bbcat_bytes_free(bytes, frame.length) }

            let data = Data(bytes: bytes, count: frame.length)
            guard let image = NSImage(data: data) else {
                throw NSError(
                    domain: "dev.bbcat.thumbnail",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "The renderer returned an invalid image"]
                )
            }

            // Finder scales this logical context by request.scale. The PNG was
            // sampled at the corresponding pixel size to remain crisp on Retina.
            let side = min(request.maximumSize.width, request.maximumSize.height)
            let contextSize = CGSize(width: side, height: side)
            let reply = QLThumbnailReply(contextSize: contextSize, currentContextDrawing: {
                image.draw(
                    in: NSRect(origin: .zero, size: contextSize),
                    from: .zero,
                    operation: .copy,
                    fraction: 1,
                    respectFlipped: false,
                    hints: [.interpolation: NSImageInterpolation.none]
                )
                return true
            })
            reply.extensionBadge = request.fileURL.pathExtension.uppercased()
            handler(reply, nil)
        } catch {
            handler(nil, error)
        }
    }

    private func thumbnailError(_ fallback: String) -> Error {
        guard let pointer = bbcat_take_last_error() else {
            return NSError(
                domain: "dev.bbcat.thumbnail",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: fallback]
            )
        }
        defer { bbcat_string_free(pointer) }
        return NSError(
            domain: "dev.bbcat.thumbnail",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: String(cString: pointer)]
        )
    }
}
