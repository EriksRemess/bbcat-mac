# bbcat for macOS

A native AppKit viewer for ANSI and BBS artwork, ported from `bbcat-gtk`.
The UI is written in Swift and the original Rust `bbcat` decoder/rendering
library is linked through a small C-compatible bridge.

## Features

- ANSI (`.ans`, `.asc`, `.diz`) and NFO artwork
- DarkDraw (`.ddw`), ArtWorx (`.adf`), and RIPscrip (`.rip`)
- XBin (`.xb`, `.xbin`)
- Static and animated documents
- SAUCE metadata titles
- Crisp ×1 and ×2 rendering
- Responsive aspect-fit display and native-size scrolling
- Cropped Finder thumbnails
- Full, uncropped Quick Look previews with the Space bar

## Install

Download `bbcat-macos-arm64.zip` from the
[latest release](https://github.com/EriksRemess/bbcat-mac/releases/latest),
unzip it, and move `bbcat.app` to `/Applications`.

Releases support Apple silicon Macs running macOS 13 or newer. Launch bbcat
once after installation to register its document types and Finder extensions.

## Code

The macOS interface, document viewer, animation, and Quick Look extensions are
implemented in Swift with AppKit. The Rust bridge wraps the `bbcat` rendering
library behind a small C-compatible API shared by the app and both extensions.

- [`Sources/BBCat`](Sources/BBCat): application and artwork viewer
- [`Sources/BBCatThumbnail`](Sources/BBCatThumbnail): Finder thumbnails
- [`Sources/BBCatPreview`](Sources/BBCatPreview): Quick Look previews
- [`RustBridge`](RustBridge): Rust decoder and rendering bridge

The project is available under the [MIT License](LICENSE).
