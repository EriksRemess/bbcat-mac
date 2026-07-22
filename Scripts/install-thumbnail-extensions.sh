#!/bin/bash

set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "usage: $0 APP_PATH THUMBNAIL_BINARY INFO_PLIST" >&2
    exit 2
fi

app_path="$1"
thumbnail_binary="$2"
info_plist="$3"
plugins_path="$app_path/Contents/PlugIns"

thumbnail_types=(
    "ansi-art dev.bbcat.ansi-art bbcat — ANSI (.ans) thumbnails"
    "ansi-ascii dev.bbcat.ansi-ascii bbcat — ASCII (.asc) thumbnails"
    "diz dev.bbcat.diz bbcat — DIZ (.diz) thumbnails"
    "nfo dev.bbcat.nfo bbcat — NFO (.nfo) thumbnails"
    "darkdraw dev.bbcat.darkdraw bbcat — DarkDraw (.ddw) thumbnails"
    "artworx dev.bbcat.artworx bbcat — ArtWorx (.adf) thumbnails"
    "ripscrip dev.bbcat.ripscrip bbcat — RIPscrip (.rip) thumbnails"
    "xbin dev.bbcat.xbin bbcat — XBin (.xb, .xbin) thumbnails"
)

mkdir -p "$plugins_path"
rm -rf "$plugins_path/BBCatThumbnail.appex"

for thumbnail_type in "${thumbnail_types[@]}"; do
    read -r suffix uti display_name <<< "$thumbnail_type"
    extension_path="$plugins_path/BBCatThumbnail-$suffix.appex"
    executable_path="$extension_path/Contents/MacOS/BBCatThumbnail"
    extension_plist="$extension_path/Contents/Info.plist"

    rm -rf "$extension_path"
    mkdir -p "$(dirname "$executable_path")"
    cp "$thumbnail_binary" "$executable_path"
    cp "$info_plist" "$extension_plist"

    /usr/libexec/PlistBuddy \
        -c "Set :CFBundleIdentifier dev.bbcat.mac.thumbnail.$suffix" \
        "$extension_plist"
    /usr/libexec/PlistBuddy \
        -c "Set :CFBundleDisplayName $display_name" \
        "$extension_plist"
    /usr/libexec/PlistBuddy \
        -c "Delete :NSExtension:NSExtensionAttributes:QLSupportedContentTypes" \
        "$extension_plist"
    /usr/libexec/PlistBuddy \
        -c "Add :NSExtension:NSExtensionAttributes:QLSupportedContentTypes array" \
        "$extension_plist"
    /usr/libexec/PlistBuddy \
        -c "Add :NSExtension:NSExtensionAttributes:QLSupportedContentTypes:0 string $uti" \
        "$extension_plist"
done
