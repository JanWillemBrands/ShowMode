#!/bin/bash
# Build ShowMode for iPad mini 3 (iOS 12.5.8)
# Compiles Swift sources with Xcode 14.3.1 CLI tools and packages as IPA
#
# Usage: ./build-ipad.sh
# Output: ~/Desktop/ShowMode.ipa (install via Sideloadly)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/ShowMode"
BUILD_DIR="/tmp/ShowModeSwift"
IPA_PATH="$HOME/Desktop/ShowMode.ipa"

SWIFTC="/Applications/Xcode-14.3.1.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
SDK="/Applications/Xcode-14.3.1.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk"
IBTOOL="/Applications/Xcode-14.3.1.app/Contents/Developer/usr/bin/ibtool"
PLIST="$BUILD_DIR/Info.plist"

# Check tools exist
if [ ! -f "$SWIFTC" ]; then
    echo "ERROR: Xcode 14.3.1 not found at expected path"
    exit 1
fi

echo "=== ShowMode iPad Build ==="
echo "Source: $SRC_DIR"

# Ensure build directory
mkdir -p "$BUILD_DIR"

# Compile LaunchScreen if needed
if [ ! -d "$BUILD_DIR/LaunchScreen.storyboardc" ]; then
    echo "Compiling LaunchScreen.storyboard..."
    if [ -f "$BUILD_DIR/LaunchScreen.storyboard" ]; then
        "$IBTOOL" --compile "$BUILD_DIR/LaunchScreen.storyboardc" \
            "$BUILD_DIR/LaunchScreen.storyboard" \
            --target-device ipad --minimum-deployment-target 11.0
    else
        echo "WARNING: LaunchScreen.storyboard not found in $BUILD_DIR, skipping"
    fi
fi

# Compile Swift sources
echo "Compiling Swift for arm64-apple-ios11.0..."
"$SWIFTC" \
    -target arm64-apple-ios11.0 \
    -sdk "$SDK" \
    -parse-as-library \
    -emit-executable \
    -Xlinker -framework -Xlinker WebKit \
    -o "$BUILD_DIR/ShowMode" \
    "$SRC_DIR/AppDelegate.swift" \
    "$SRC_DIR/RSSParser.swift" \
    "$SRC_DIR/MainViewController.swift"

echo "Compilation successful"

# Package IPA
echo "Packaging IPA..."
rm -rf "$BUILD_DIR/Payload"
mkdir -p "$BUILD_DIR/Payload/ShowMode.app"
cp "$BUILD_DIR/ShowMode" "$BUILD_DIR/Payload/ShowMode.app/ShowMode"

# Copy Info.plist
if [ -f "$PLIST" ]; then
    cp "$PLIST" "$BUILD_DIR/Payload/ShowMode.app/Info.plist"
else
    echo "ERROR: Info.plist not found at $PLIST"
    exit 1
fi

# Copy LaunchScreen
if [ -d "$BUILD_DIR/LaunchScreen.storyboardc" ]; then
    cp -R "$BUILD_DIR/LaunchScreen.storyboardc" "$BUILD_DIR/Payload/ShowMode.app/LaunchScreen.storyboardc"
fi

rm -f "$IPA_PATH"
cd "$BUILD_DIR"
zip -r "$IPA_PATH" Payload -q

echo "=== Build complete ==="
echo "IPA: $IPA_PATH"
echo "Install with Sideloadly"
