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
    "ansi-art dev.bbcat.ansi-art"
    "ansi-ascii dev.bbcat.ansi-ascii"
    "diz dev.bbcat.diz"
    "nfo dev.bbcat.nfo"
    "darkdraw dev.bbcat.darkdraw"
    "artworx dev.bbcat.artworx"
    "ripscrip dev.bbcat.ripscrip"
    "xbin dev.bbcat.xbin"
)

mkdir -p "$plugins_path"
rm -rf "$plugins_path/BBCatThumbnail.appex"

for thumbnail_type in "${thumbnail_types[@]}"; do
    read -r suffix uti <<< "$thumbnail_type"
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
        -c "Delete :NSExtension:NSExtensionAttributes:QLSupportedContentTypes" \
        "$extension_plist"
    /usr/libexec/PlistBuddy \
        -c "Add :NSExtension:NSExtensionAttributes:QLSupportedContentTypes array" \
        "$extension_plist"
    /usr/libexec/PlistBuddy \
        -c "Add :NSExtension:NSExtensionAttributes:QLSupportedContentTypes:0 string $uti" \
        "$extension_plist"
done
