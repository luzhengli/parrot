# Parrot

Parrot is a native macOS translation assistant prototype. The app is planned as a lightweight menu-bar utility for quick text translation, screenshot OCR translation, and user-configured OpenAI-compatible LLM providers.

> Status: early SwiftUI scaffold. Core translation features are still under development.

## Highlights

- Native macOS app built with SwiftUI and AppKit where system integration is needed.
- Menu-bar-first product direction with global shortcuts and transient floating windows.
- Screenshot translation flow designed around local OCR before sending recognized text to an LLM.
- User-owned provider setup for OpenAI-compatible APIs.
- High-fidelity product references in [`Design/`](Design/).

## Screens

The current design references cover the main MVP surfaces:

- Quick text translation panel
- Screenshot translation result card
- Settings window
- Menu-bar dropdown

See [`Design/README.md`](Design/README.md) for the image index.

## Requirements

- macOS 14.0 or later
- Full Xcode installation
- Swift 5

If `xcodebuild` is using Command Line Tools instead of full Xcode, select Xcode with:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Getting Started

Open the project in Xcode:

```sh
open Parrot.xcodeproj
```

Then choose the `Parrot` scheme and run on `My Mac`.

For command-line verification:

```sh
./init.sh
```

Or run the build directly:

```sh
xcodebuild -scheme Parrot -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

## Project Layout

- `Parrot.xcodeproj/`: Xcode project with the `Parrot` target and scheme.
- `Parrot/App/`: SwiftUI app entry point and starter UI.
- `Parrot/Resources/`: app asset catalog and resources.
- `Config/`: Debug and Release build settings.
- `Docs/`: product requirements and planning documents.
- `Design/`: high-fidelity product prototype images.

## Product Scope

The MVP focuses on:

- Quick text translation from a small floating panel.
- Screenshot region selection, local OCR, and translation result display.
- OpenAI-compatible provider configuration.
- Keychain-only API key storage.
- Clear user-facing errors for permissions, OCR, authentication, network, and timeouts.

The MVP does not aim to be a full document translation workspace, browser extension, team glossary system, or professional CAT tool.

## Agent Harness

This README is written for GitHub visitors and developers. Agent-specific workflow, constraints, and handoff rules live in [`AGENTS.md`](AGENTS.md).

For agent handoff state, use:

- [`parrot-progress.md`](parrot-progress.md)
- [`feature_list.json`](feature_list.json)

## Current Defaults

- Deployment target: macOS 14.0
- UI framework: SwiftUI
- Bundle identifier: `com.example.parrot`
- Version: `0.1.0`
