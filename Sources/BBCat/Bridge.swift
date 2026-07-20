import AppKit

enum BBCatError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self { case .message(let message): message }
    }

    static func last(_ fallback: String) -> BBCatError {
        guard let pointer = bbcat_take_last_error() else { return .message(fallback) }
        defer { bbcat_string_free(pointer) }
        return .message(String(cString: pointer))
    }
}
final class BBCatDocument {
    private let handle: OpaquePointer
    let frameCount: Int
    let displayTitle: String

    init(url: URL) throws {
        guard let handle = url.path.withCString({ bbcat_document_open($0) }) else {
            throw BBCatError.last("Could not decode the file")
        }
        self.handle = handle
        frameCount = Int(bbcat_document_frame_count(handle))
        let fallback = url.lastPathComponent.isEmpty ? "ANSI art" : url.lastPathComponent
        displayTitle = fallback.withCString { fallbackPointer in
            guard let title = bbcat_document_display_title(handle, fallbackPointer) else { return fallback }
            defer { bbcat_string_free(title) }
            return String(cString: title)
        }
    }

    deinit { bbcat_document_free(handle) }

    func frame(at index: Int, scale: Int) throws -> (image: NSImage, duration: TimeInterval) {
        var frame = BbcatFrame(data: nil, length: 0, duration_ns: 0)
        guard bbcat_document_render_frame(handle, index, scale, &frame) != 0,
              let bytes = frame.data else {
            throw BBCatError.last("Could not render the artwork")
        }
        defer { bbcat_bytes_free(bytes, frame.length) }
        let data = Data(bytes: bytes, count: frame.length)
        guard let image = NSImage(data: data) else {
            throw BBCatError.message("The renderer returned an invalid image")
        }
        return (image, TimeInterval(frame.duration_ns) / 1_000_000_000)
    }
}
