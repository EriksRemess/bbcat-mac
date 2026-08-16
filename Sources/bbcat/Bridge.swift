import AppKit

enum bbcatError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self { case .message(let message): message }
    }

    static func last(_ fallback: String) -> bbcatError {
        guard let pointer = bbcat_take_last_error() else { return .message(fallback) }
        defer { bbcat_string_free(pointer) }
        return .message(String(cString: pointer))
    }
}

enum bbcatWelcome {
    static func image(scale: Int) throws -> NSImage {
        var frame = BbcatFrame(data: nil, length: 0, duration_ns: 0)
        guard bbcat_render_welcome(scale, &frame) != 0, let bytes = frame.data else {
            throw bbcatError.last("Could not render the welcome artwork")
        }
        defer { bbcat_bytes_free(bytes, frame.length) }
        let data = Data(bytes: bytes, count: frame.length)
        guard let image = NSImage(data: data) else {
            throw bbcatError.message("The renderer returned an invalid welcome image")
        }
        return image
    }
}

struct bbcatDocumentInfo {
    let format: String
    let columns: Int
    let rows: Int
    let pixelWidth: Int?
    let pixelHeight: Int?
    let glyphWidth: Int
    let glyphHeight: Int
    let raster: Bool
    let supportsUTF8: Bool
    let embeddedFont: Bool
    let trueColor: Bool
    let hasSauce: Bool
    let sauceUsesICEColors: Bool
    let sauceLetterSpacing: Int?
    let title: String?
    let author: String?
    let group: String?
    let date: String?
    let fontName: String?
}

final class bbcatDocument {
    private let handle: OpaquePointer
    let sourceURL: URL
    let frameCount: Int
    let isAnimated: Bool
    let displayTitle: String
    let info: bbcatDocumentInfo

    init(url: URL) throws {
        guard let handle = url.path.withCString({ bbcat_document_open($0) }) else {
            throw bbcatError.last("Could not decode the file")
        }
        self.handle = handle
        sourceURL = url
        frameCount = Int(bbcat_document_frame_count(handle))
        isAnimated = bbcat_document_is_animated(handle) != 0
        info = try Self.copyInfo(from: handle)
        let fallback = url.lastPathComponent.isEmpty ? "ANSI art" : url.lastPathComponent
        displayTitle = fallback.withCString { fallbackPointer in
            guard let title = bbcat_document_display_title(handle, fallbackPointer) else { return fallback }
            defer { bbcat_string_free(title) }
            return String(cString: title)
        }
    }

    deinit { bbcat_document_free(handle) }

    func supports(scale: Int) -> Bool {
        scale > 0 && bbcat_document_supports_scale(handle, scale) != 0
    }

    func frame(at index: Int, scale: Int) throws -> (image: NSImage, duration: TimeInterval) {
        var frame = BbcatFrame(data: nil, length: 0, duration_ns: 0)
        guard bbcat_document_render_frame(handle, index, scale, &frame) != 0,
              let bytes = frame.data else {
            throw bbcatError.last("Could not render the artwork")
        }
        defer { bbcat_bytes_free(bytes, frame.length) }
        let data = Data(bytes: bytes, count: frame.length)
        guard let image = NSImage(data: data) else {
            throw bbcatError.message("The renderer returned an invalid image")
        }
        return (image, TimeInterval(frame.duration_ns) / 1_000_000_000)
    }

    func export(scale: Int) throws -> Data {
        var output = BbcatFrame(data: nil, length: 0, duration_ns: 0)
        let succeeded = isAnimated
            ? bbcat_document_encode_gif(handle, scale, &output)
            : bbcat_document_encode_png(handle, scale, &output)
        guard succeeded != 0, let bytes = output.data else {
            throw bbcatError.last("Could not export the artwork")
        }
        defer { bbcat_bytes_free(bytes, output.length) }
        return Data(bytes: bytes, count: output.length)
    }

    private static func copyInfo(from handle: OpaquePointer) throws -> bbcatDocumentInfo {
        var raw = BbcatDocumentInfo()
        guard bbcat_document_copy_info(handle, &raw) != 0 else {
            bbcat_document_free(handle)
            throw bbcatError.last("Could not inspect the artwork")
        }

        func string(_ field: Int32) -> String? {
            guard let pointer = bbcat_document_copy_metadata_string(handle, field) else { return nil }
            defer { bbcat_string_free(pointer) }
            return String(cString: pointer)
        }

        return bbcatDocumentInfo(
            format: string(Int32(BBCAT_METADATA_FORMAT)) ?? "Unknown",
            columns: Int(raw.columns),
            rows: Int(raw.rows),
            pixelWidth: raw.has_pixel_dimensions != 0 ? Int(raw.pixel_width) : nil,
            pixelHeight: raw.has_pixel_dimensions != 0 ? Int(raw.pixel_height) : nil,
            glyphWidth: Int(raw.glyph_width),
            glyphHeight: Int(raw.glyph_height),
            raster: raw.raster != 0,
            supportsUTF8: raw.utf8_supported != 0,
            embeddedFont: raw.embedded_font != 0,
            trueColor: raw.true_color != 0,
            hasSauce: raw.has_sauce != 0,
            sauceUsesICEColors: raw.sauce_ice_colors != 0,
            sauceLetterSpacing: raw.sauce_letter_spacing == 0 ? nil : Int(raw.sauce_letter_spacing),
            title: string(Int32(BBCAT_METADATA_TITLE)),
            author: string(Int32(BBCAT_METADATA_AUTHOR)),
            group: string(Int32(BBCAT_METADATA_GROUP)),
            date: string(Int32(BBCAT_METADATA_DATE)),
            fontName: string(Int32(BBCAT_METADATA_FONT_NAME))
        )
    }
}
