import AppKit

guard CommandLine.arguments.count == 3 else {
    fatalError("usage: render-icon.swift INPUT.svg OUTPUT.icns")
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = NSImage(contentsOf: inputURL) else {
    fatalError("could not load \(inputURL.path)")
}

func bigEndian(_ value: Int) -> [UInt8] {
    let value = UInt32(value)
    return [
        UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff),
        UInt8((value >> 8) & 0xff), UInt8(value & 0xff),
    ]
}

func pngRepresentation(pixels: Int) -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { fatalError("could not allocate \(pixels)-pixel bitmap") }

    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    source.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("could not encode \(pixels)-pixel PNG")
    }
    return png
}

// ICNS stores one PNG chunk for each physical pixel size. These chunk names
// are the same representations iconutil normally builds from an iconset.
let variants: [(String, Int)] = [
    ("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128),
    ("ic08", 256), ("ic09", 512), ("ic10", 1024),
]
var chunks = Data()
for (kind, pixels) in variants {
    let png = pngRepresentation(pixels: pixels)
    chunks.append(contentsOf: kind.utf8)
    chunks.append(contentsOf: bigEndian(png.count + 8))
    chunks.append(png)
}

var icon = Data("icns".utf8)
icon.append(contentsOf: bigEndian(chunks.count + 8))
icon.append(chunks)
try icon.write(to: outputURL, options: .atomic)
