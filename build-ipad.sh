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
    <key>MinimumOSVersion</key>
    <string>11.0</string>
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
    <key>DTPlatformName</key>
    <string>iphoneos</string>
    <key>DTPlatformVersion</key>
    <string>16.4</string>
    <key>DTSDKName</key>
    <string>iphoneos16.4</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>iPhoneOS</string>
    </array>
    <key>BuildMachineOSBuild</key>
    <string>22A400</string>
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
APP_DIR="$BUILD_DIR/Payload/ShowMode.app"
rm -rf "$BUILD_DIR/Payload"
mkdir -p "$APP_DIR"
cp "$BUILD_DIR/ShowMode" "$APP_DIR/ShowMode"

# Copy Info.plist
if [ -f "$PLIST" ]; then
    cp "$PLIST" "$APP_DIR/Info.plist"
else
    echo "ERROR: Info.plist not found at $PLIST"
    exit 1
fi

# Create PkgInfo (standard for iOS apps)
printf 'APPL????' > "$APP_DIR/PkgInfo"

# Copy LaunchScreen
if [ -d "$BUILD_DIR/LaunchScreen.storyboardc" ]; then
    cp -R "$BUILD_DIR/LaunchScreen.storyboardc" "$APP_DIR/LaunchScreen.storyboardc"
fi

# Ad-hoc code sign so the IPA has valid structure for Sideloadly
CODESIGN="/usr/bin/codesign"
if [ -x "$CODESIGN" ]; then
    echo "Ad-hoc signing .app bundle..."
    "$CODESIGN" --force --sign - --timestamp=none "$APP_DIR"
fi

rm -f "$IPA_PATH"
cd "$BUILD_DIR"
zip -r "$IPA_PATH" Payload -q

# Validate IPA structure (catch problems before attempting Sideloadly)
echo "Validating IPA..."
VALID=true

# Check zip is well-formed
if ! unzip -t "$IPA_PATH" > /dev/null 2>&1; then
    echo "ERROR: IPA is not a valid zip archive"
    VALID=false
fi

# Check required files exist inside the IPA
for REQUIRED in "Payload/ShowMode.app/ShowMode" "Payload/ShowMode.app/Info.plist" "Payload/ShowMode.app/PkgInfo" "Payload/ShowMode.app/_CodeSignature/CodeResources"; do
    if ! unzip -l "$IPA_PATH" "$REQUIRED" > /dev/null 2>&1; then
        echo "ERROR: Missing $REQUIRED in IPA"
        VALID=false
    fi
done

# Verify code signature on the .app inside the build dir
if ! codesign -v "$APP_DIR" 2>/dev/null; then
    echo "ERROR: Code signature verification failed"
    VALID=false
fi

# Check key Info.plist fields
for KEY in MinimumOSVersion CFBundleIdentifier CFBundleExecutable CFBundleSupportedPlatforms DTPlatformName; do
    if ! /usr/libexec/PlistBuddy -c "Print :$KEY" "$APP_DIR/Info.plist" > /dev/null 2>&1; then
        echo "ERROR: Info.plist missing required key: $KEY"
        VALID=false
    fi
done

if [ "$VALID" = false ]; then
    echo "=== BUILD FAILED: IPA validation errors (see above) ==="
    exit 1
fi

echo "=== Build complete ==="
echo "IPA: $IPA_PATH ($(du -h "$IPA_PATH" | cut -f1) bytes)"
echo "Bundle ID: $BUNDLE_ID"
echo "Install with Sideloadly"
echo "Log: $LOG_PATH"
