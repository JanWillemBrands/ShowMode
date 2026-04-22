# ShowMode Build Guide

## Architecture

ShowMode is developed in **Swift/UIKit** using two compilation paths:

| Stage | Tool | Target | Purpose |
|-------|------|--------|---------|
| Development | Xcode 26.4 | iPad Mini (A17 Pro) iOS 18.1 simulator | Edit, test, preview |
| iPad build | Xcode 14.3.1 CLI (`swiftc`) | arm64-apple-ios11.0 | Compile for iPad mini 3 |
| Install | Sideloadly | iPad mini 3 (iOS 12.5.8) | Code signing + install |

**Why two Xcodes?** Xcode 26.4's Swift runtime is incompatible with iOS 12. Xcode 14.3.1's `swiftc` (Swift 5.8) produces compatible binaries. Xcode 14.3.1 GUI doesn't run on macOS Tahoe, but its CLI tools work fine.

**Why Sideloadly?** Manual code signing (`codesign` + `ideviceinstaller`) fails on iOS 12.5.8. Sideloadly handles signing in a way iOS 12 accepts.

## Quick Build

After editing in Xcode 26.4, just **Build** (Cmd+B). The scheme's post-build action automatically runs `build-ipad.sh`, which:

1. Compiles all Swift sources with Xcode 14.3.1's `swiftc` for `arm64-apple-ios11.0`
2. Links UIKit, Foundation, and WebKit frameworks
3. Packages the binary + Info.plist + LaunchScreen into `~/Desktop/ShowMode.ipa`

Build log: `/tmp/ShowMode-build.log`

## Manual Build

```bash
./build-ipad.sh
```

## Deploy to iPad

1. Open **Sideloadly**
2. Select `~/Desktop/ShowMode.ipa`
3. Select iPad mini 3 from device dropdown
4. Enter Apple ID, click Start

## Key Files

```
ShowMode/
  ShowMode/
    AppDelegate.swift       # Window setup, portrait lock
    MainViewController.swift # All UI: clock, weather, news, entertainment
    RSSParser.swift          # XML parser for RSS feeds (BBC, Repubblica)
  build-ipad.sh             # iPad compilation + IPA packaging
  ShowMode.xcodeproj/       # Xcode 26.4 (development)
  ShowModeLegacy.xcodeproj/ # Legacy project (no longer needed)
```

## Build Dependencies

- `/tmp/ShowModeSwift/Info.plist` — iPad app metadata (UIDeviceFamily=2, bundle ID, ATS)
- `/tmp/ShowModeSwift/LaunchScreen.storyboardc` — Compiled storyboard for full-screen display
- Xcode 14.3.1 at `/Applications/Xcode-14.3.1.app/`
- Sideloadly for installation

## Constraints

- **No async/await** — Swift 5.8 on iOS 12 doesn't support concurrency
- **No SwiftUI** — iOS 12 predates SwiftUI
- **No SceneDelegate** — UIWindow-based lifecycle only
- **WebKit linked explicitly** — WKWebView used for article overlay
- Bundle ID: `Magenta.ShowModeLegacy`
- Signing identity managed by Sideloadly
