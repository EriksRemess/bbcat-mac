APP := build/bbcat.app
EXTENSION := $(APP)/Contents/PlugIns/BBCatThumbnail.appex
PREVIEW := $(APP)/Contents/PlugIns/BBCatPreview.appex
RUST_LIB := RustBridge/target/release/libbbcat_bridge.a
# Keep this pinned to the bbcat version in RustBridge/Cargo.lock.
BBCAT_CLI_VERSION := 0.5.8
CLI_INSTALL_ROOT := build/bbcat-cli
CLI_TARGET_DIR := build/bbcat-cli-target
CLI_BINARY := $(CLI_INSTALL_ROOT)/bin/bbcat
BUNDLED_CLI := $(APP)/Contents/Helpers/bbcat
SWIFT_TEST_BINARY := build/tests/command-line-tool-installer-tests
SWIFT_SOURCES := $(wildcard Sources/BBCat/*.swift)
THUMBNAIL_SOURCES := $(wildcard Sources/BBCatThumbnail/*.swift)
PREVIEW_SOURCES := $(wildcard Sources/BBCatPreview/*.swift) Sources/BBCat/ArtworkView.swift Sources/BBCat/Bridge.swift
APP_ICON := Resources/bbcat.icns
BBCAT_LICENSE := Resources/BBCAT_LICENSE
THIRD_PARTY_LICENSES := Resources/THIRD_PARTY_LICENSES
ARCH := $(shell uname -m)
DEPLOYMENT_TARGET := 13.0

.PHONY: all bundle run test clean

all: bundle

bundle: $(APP)/Contents/MacOS/bbcat $(BUNDLED_CLI) $(APP)/Contents/Resources/bbcat.icns $(APP)/Contents/Resources/BBCAT_LICENSE $(APP)/Contents/Resources/THIRD_PARTY_LICENSES $(EXTENSION)/Contents/MacOS/BBCatThumbnail $(PREVIEW)/Contents/MacOS/BBCatPreview
	codesign --force --sign - $(BUNDLED_CLI)
	codesign --force --sign - --entitlements Resources/Thumbnail.entitlements $(EXTENSION)
	codesign --force --sign - --entitlements Resources/Thumbnail.entitlements $(PREVIEW)
	codesign --force --sign - $(APP)

$(RUST_LIB): Makefile RustBridge/Cargo.toml RustBridge/src/lib.rs RustBridge/include/bbcat_bridge.h
	MACOSX_DEPLOYMENT_TARGET=$(DEPLOYMENT_TARGET) cargo build --release --manifest-path RustBridge/Cargo.toml

$(CLI_BINARY): $(RUST_LIB) Makefile RustBridge/Cargo.lock
	MACOSX_DEPLOYMENT_TARGET=$(DEPLOYMENT_TARGET) CARGO_TARGET_DIR=$(CURDIR)/$(CLI_TARGET_DIR) \
		cargo install --locked --offline --force --version $(BBCAT_CLI_VERSION) --root $(CURDIR)/$(CLI_INSTALL_ROOT) bbcat

$(BUNDLED_CLI): $(CLI_BINARY)
	mkdir -p $(APP)/Contents/Helpers
	cp $(CLI_BINARY) $@

$(APP)/Contents/MacOS/bbcat: Makefile $(RUST_LIB) $(SWIFT_SOURCES) Resources/Info.plist
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	CLANG_MODULE_CACHE_PATH=$(CURDIR)/build/ModuleCache \
	swiftc -module-cache-path $(CURDIR)/build/ModuleCache -target $(ARCH)-apple-macosx$(DEPLOYMENT_TARGET) \
		-swift-version 5 -O -whole-module-optimization \
		-import-objc-header RustBridge/include/bbcat_bridge.h \
		$(SWIFT_SOURCES) $(RUST_LIB) -framework AppKit -framework CoreServices -framework UniformTypeIdentifiers \
		-o $(APP)/Contents/MacOS/bbcat

$(APP_ICON): Resources/bbcat.svg Scripts/render-icon.swift
	CLANG_MODULE_CACHE_PATH=$(CURDIR)/build/ModuleCache \
		swift -module-cache-path $(CURDIR)/build/ModuleCache Scripts/render-icon.swift Resources/bbcat.svg $(APP_ICON)

$(APP)/Contents/Resources/bbcat.icns: $(APP_ICON)
	mkdir -p $(APP)/Contents/Resources
	cp $(APP_ICON) $@

$(APP)/Contents/Resources/THIRD_PARTY_LICENSES: $(THIRD_PARTY_LICENSES)
	mkdir -p $(APP)/Contents/Resources
	cp $(THIRD_PARTY_LICENSES) $@

$(APP)/Contents/Resources/BBCAT_LICENSE: $(BBCAT_LICENSE)
	mkdir -p $(APP)/Contents/Resources
	cp $(BBCAT_LICENSE) $@

$(EXTENSION)/Contents/MacOS/BBCatThumbnail: Makefile $(RUST_LIB) $(THUMBNAIL_SOURCES) Resources/ThumbnailInfo.plist
	mkdir -p $(EXTENSION)/Contents/MacOS
	cp Resources/ThumbnailInfo.plist $(EXTENSION)/Contents/Info.plist
	CLANG_MODULE_CACHE_PATH=$(CURDIR)/build/ModuleCache \
	swiftc -module-cache-path $(CURDIR)/build/ModuleCache -target $(ARCH)-apple-macosx$(DEPLOYMENT_TARGET) \
		-swift-version 5 -O -whole-module-optimization -parse-as-library -application-extension \
		-module-name BBCatThumbnail -import-objc-header RustBridge/include/bbcat_bridge.h \
		$(THUMBNAIL_SOURCES) $(RUST_LIB) -framework AppKit -framework QuickLookThumbnailing \
		-Xlinker -e -Xlinker _NSExtensionMain -o $(EXTENSION)/Contents/MacOS/BBCatThumbnail

$(PREVIEW)/Contents/MacOS/BBCatPreview: Makefile $(RUST_LIB) $(PREVIEW_SOURCES) Resources/PreviewInfo.plist
	mkdir -p $(PREVIEW)/Contents/MacOS
	cp Resources/PreviewInfo.plist $(PREVIEW)/Contents/Info.plist
	CLANG_MODULE_CACHE_PATH=$(CURDIR)/build/ModuleCache \
	swiftc -module-cache-path $(CURDIR)/build/ModuleCache -target $(ARCH)-apple-macosx$(DEPLOYMENT_TARGET) \
		-swift-version 5 -O -whole-module-optimization -parse-as-library -application-extension \
		-module-name BBCatPreview -import-objc-header RustBridge/include/bbcat_bridge.h \
		$(PREVIEW_SOURCES) $(RUST_LIB) -framework AppKit -framework QuickLookUI \
		-Xlinker -e -Xlinker _NSExtensionMain -o $(PREVIEW)/Contents/MacOS/BBCatPreview

run: all
	open $(APP)

$(SWIFT_TEST_BINARY): Sources/BBCat/CommandLineToolInstaller.swift Tests/CommandLineToolInstaller/main.swift
	mkdir -p build/tests
	CLANG_MODULE_CACHE_PATH=$(CURDIR)/build/ModuleCache \
		swiftc -module-cache-path $(CURDIR)/build/ModuleCache \
		-target $(ARCH)-apple-macosx$(DEPLOYMENT_TARGET) -swift-version 5 -O $^ -o $@

test: $(SWIFT_TEST_BINARY)
	cargo test --manifest-path RustBridge/Cargo.toml
	$(SWIFT_TEST_BINARY)

clean:
	cargo clean --manifest-path RustBridge/Cargo.toml
	rm -rf build
