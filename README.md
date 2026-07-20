# bbcat for macOS

A native AppKit viewer for ANSI and BBS artwork, ported from `bbcat-gtk`.
The UI is written in Swift and the original Rust `bbcat` decoder/rendering
library is linked through a small C-compatible bridge.

It supports ANSI (`.ans`, `.asc`, `.diz`), NFO, DarkDraw (`.ddw`), ArtWorx
(`.adf`), RIPscrip (`.rip`), and XBin (`.xb`, `.xbin`) artwork. Static and
animated documents, SAUCE metadata titles, crisp ×1/×2 rendering, responsive
aspect-fit display, oversized native-size scrolling, Finder opening, and
command-line paths are supported. The app also embeds a Quick Look Thumbnail
Extension for cropped Finder icons and a separate Quick Look Preview Extension
for full, uncropped Spacebar previews.

## Requirements

- macOS 13 or newer
- Swift toolchain / Xcode Command Line Tools
- Rust

## Build and run

```sh
make
open build/bbcat.app
```

Or open a file from Terminal:

```sh
build/bbcat.app/Contents/MacOS/bbcat artwork.ans
```

Run the Rust bridge tests with `make test`.

After copying the app to `/Applications`, launch it once so Launch Services can
discover its document types and thumbnail extension. Development builds are
ad-hoc signed by `make`; distribution builds still need Developer ID signing
and notarization.

The default build targets the current Mac architecture. For distribution,
build the Rust library and Swift executable separately for `arm64` and
`x86_64`, combine matching binaries with `lipo`, then sign/notarize the app.
