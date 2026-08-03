# bbcat for macOS

A native AppKit viewer for ANSI, ASCII, DIZ, NFO, DarkDraw, ArtWorx, RIPscrip,
and XBin artwork, ported from `bbcat-gtk`. The Swift interface uses the original
Rust [`bbcat`](https://bbcat.dev/) decoder and renderer through a small
C-compatible bridge.

## Features

- ANSI (`.ans`), ASCII (`.asc`), DIZ (`.diz`), and NFO (`.nfo`)
- DarkDraw (`.ddw`), ArtWorx (`.adf`), RIPscrip (`.rip`), and XBin (`.xb`,
  `.xbin`)
- Opening from Finder, the app's file picker, or a path passed to the app
- Static artwork and timed ANSI animation playback
- PNG export for static artwork and looping GIF export for animations
- Popover inspector with format, dimensions, animation, and SAUCE information
- SAUCE titles, authors, and dates in the window title
- Crisp ×1 and ×2 rendering with responsive aspect-fit display
- Fit-width display with vertical scrolling for artwork larger than the available screen
- Format-specific, cropped Finder thumbnails with extension badges
- Full, uncropped Quick Look previews with the Space bar
- Finder and Spotlight metadata for format, dimensions, SAUCE credits, fonts,
  and animation details
- Optional bundled `bbcat` CLI, installed or removed from the app menu as
  `~/.local/bin/bbcat`

## Install

Download `bbcat-macos-arm64.zip` from the
[latest release](https://github.com/EriksRemess/bbcat-mac/releases/latest),
unzip it, and move `bbcat.app` to `/Applications`.

Releases are ready to use on Apple silicon Macs running macOS 13 or newer; no
separate Rust or `bbcat` installation is required. Launch bbcat once after
installation to register its document types and Finder extensions.

## Code

The macOS interface, document viewer, animation, and Quick Look extensions are
implemented in Swift with AppKit. The Rust bridge wraps the `bbcat` rendering
library behind a small C-compatible API shared by the app, Finder thumbnail
providers, and Quick Look preview provider.

- [`Sources/bbcat`](Sources/bbcat): application and artwork viewer
- [`Sources/bbcatThumbnail`](Sources/bbcatThumbnail): renderer shared by the
  format-specific Finder thumbnail extensions
- [`Sources/bbcatPreview`](Sources/bbcatPreview): Quick Look previews
- [`Sources/bbcatMetadata`](Sources/bbcatMetadata): Spotlight metadata importer
- [`RustBridge`](RustBridge): Rust decoder and rendering bridge

The project is available under the [MIT License](LICENSE).
