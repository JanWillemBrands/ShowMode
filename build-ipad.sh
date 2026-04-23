#!/bin/bash
# Build ShowMode for iPad mini 3 (iOS 12.5.8)
# Compiles Swift sources with Xcode 14.3.1 CLI tools and packages as IPA
#
# Usage: ./build-ipad.sh
# Output: ~/Desktop/ShowMode.ipa
# Log: /tmp/ShowMode-build.log

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/ShowMode"
BUILD_DIR="/tmp/ShowModeSwift"
IPA_PATH="$HOME/Desktop/ShowMode.ipa"
LOG_PATH="/tmp/ShowMode-build.log"

BUNDLE_ID="${SHOWMODE_BUNDLE_ID:-Magenta.ShowModeLegacy}"
PRODUCT_NAME="ShowMode"
EXECUTABLE_NAME="ShowMode"
MARKETING_VERSION="${SHOWMODE_MARKETING_VERSION:-1.0}"
CURRENT_PROJECT_VERSION="${SHOWMODE_CURRENT_PROJECT_VERSION:-1}"

SWIFTC="/Applications/Xcode-14.3.1.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
SDK="/Applications/Xcode-14.3.1.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk"
IBTOOL="/Applications/Xcode-14.3.1.app/Contents/Developer/usr/bin/ibtool"
PLIST="$BUILD_DIR/Info.plist"

# Check tools exist
if [ ! -f "$SWIFTC" ]; then
    echo "ERROR: Xcode 14.3.1 not found at expected path"
    exit 1
fi

mkdir -p "$BUILD_DIR"
exec > >(tee "$LOG_PATH") 2>&1

echo "=== ShowMode iPad Build ==="
echo "Source: $SRC_DIR"
echo "Log: $LOG_PATH"

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

# Generate a concrete Info.plist for legacy packaging.
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${PRODUCT_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${CURRENT_PROJECT_VERSION}</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIStatusBarHidden</key>
    <true/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
    <key>UIDeviceFamily</key>
    <array>
        <integer>2</integer>
    </array>
</dict>
</plist>
EOF

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
echo "Bundle ID: $BUNDLE_ID"
echo "Install with Sideloadly"
echo "Log: $LOG_PATH"
