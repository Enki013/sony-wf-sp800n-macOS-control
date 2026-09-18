#!/bin/bash
set -e

APP_NAME="SonyControl"
BUNDLE_DIR="$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "Info.plist copying..."
cp Info.plist "$CONTENTS_DIR/Info.plist"
cp icons/wf_sp800n_color_00_01_sca.png "$RESOURCES_DIR/wf_sp800n_color_00_01_sca.png"
cp icons/wf_sp800n_color_00_01_right.png "$RESOURCES_DIR/wf_sp800n_color_00_01_right.png"
cp icons/wf_sp800n_color_00_01_left.png "$RESOURCES_DIR/wf_sp800n_color_00_01_left.png"
cp icons/wf_sp800n_color_00_01_cradle.png "$RESOURCES_DIR/wf_sp800n_color_00_01_cradle.png"
mkdir -p "$RESOURCES_DIR/tr.lproj" "$RESOURCES_DIR/en.lproj"
cp Resources/tr.lproj/InfoPlist.strings "$RESOURCES_DIR/tr.lproj/InfoPlist.strings"
cp Resources/en.lproj/InfoPlist.strings "$RESOURCES_DIR/en.lproj/InfoPlist.strings"

echo "Compiling Swift files..."
swiftc -O \
    -framework AppKit \
    -framework IOBluetooth \
    -framework Foundation \
    src/Localization.swift \
    src/ImageLoader.swift \
    src/SonyProtocol.swift \
    src/BluetoothManager.swift \
    src/PopoverController.swift \
    src/AppDelegate.swift \
    src/main.swift \
    -o "$MACOS_DIR/$APP_NAME"

echo " Signing the application (Ad-hoc codesign)..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo " $BUNDLE_DIR successfully built and ready!"
