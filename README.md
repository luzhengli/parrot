# Parrot

Parrot is a native macOS SwiftUI application scaffold.

## Project Structure

- `Parrot.xcodeproj`: Xcode project.
- `Parrot/App`: SwiftUI app entry and starter view.
- `Parrot/Resources`: asset catalog and app resources.
- `Config`: Debug and Release build configuration files.
- `ai-translation-macos-prd.md`: existing product requirement draft.

## Local Setup

1. Install and select full Xcode.
2. Open `Parrot.xcodeproj`.
3. Update `PRODUCT_BUNDLE_IDENTIFIER` in `Config/Debug.xcconfig` and `Config/Release.xcconfig` if you need a custom identifier.
4. Choose the `Parrot` scheme and run on `My Mac`.
5. For command-line verification, run:

```sh
xcodebuild -scheme Parrot -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

If `xcodebuild` reports that the active developer directory is Command Line Tools, select Xcode with:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Current Defaults

- Deployment target: macOS 14.0
- UI framework: SwiftUI
- Bundle identifier: `com.example.parrot`
- Version: `0.1.0`
