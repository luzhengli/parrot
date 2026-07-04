# Parrot

Parrot is a native macOS menu-bar translation assistant for quick text
translation, screenshot OCR translation, local translation history, and
user-configured OpenAI-compatible providers.

This repository currently ships an **unsigned release candidate**. Release
packages are ad-hoc signed for local bundle integrity, but they are not
Developer ID signed or notarized.

## Features

- Quick Text Translation floating window.
- Screenshot region selection with local Vision OCR before translation.
- OpenAI-compatible provider settings with DeepSeek, GLM, OpenAI, and custom
  endpoint presets.
- API keys stored only in macOS Keychain.
- Local text-only translation history that can be disabled or cleared.
- Source and target language controls for Quick Text and Screenshot
  Translation.
- Translation style, custom prompt template, and local terminology glossary.
- OCR source text editing before retranslation.
- Long-text segmentation with explicit confirmation for very large input.
- Request cancellation, retry, timeout, and structured recovery actions.
- Settings sidebar with Setup, Model, Shortcuts, Translation, Privacy, and
  About sections.

## Requirements

- macOS 14.0 or later.
- A configured OpenAI-compatible provider API key.
- Screen Recording permission only for Screenshot Translation.

Developer builds require a full Xcode installation. If `xcodebuild` is using
Command Line Tools instead of full Xcode, select Xcode with:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Default Shortcuts

- Quick Text Translation: `Cmd+Shift+T`
- Screenshot Translation: `Cmd+Shift+2`
- Open Settings: `Cmd+Option+,`

Shortcuts can be changed in `Settings > Shortcuts`.

## Install Unsigned RC

Release artifacts are generated as `.dmg`, `.zip`, `SHA256SUMS.txt`, and
`RELEASE_NOTES.md`.

1. Download the `.dmg` or `.zip` release asset.
2. Move `Parrot.app` to `/Applications`.
3. Verify checksums from the release directory:

   ```sh
   shasum -a 256 -c SHA256SUMS.txt
   ```

4. Open Parrot. Because this is an unsigned RC, macOS may show an
   "unidentified developer" warning. Use right-click > Open for a trusted local
   test build.
5. If quarantine blocks a trusted local test build, remove the quarantine flag:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Parrot.app
   ```

## First Run

1. Open `Settings > Setup` or `Settings > Model`.
2. Choose a provider preset or enter a custom HTTPS Base URL and model name.
3. Enter the API key and save it to Keychain.
4. Use `Test Connection`.
5. Use `Cmd+Shift+T` for Quick Text.
6. Use Screenshot Translation only after granting Screen Recording permission.

Quick Text does not need Screen Recording permission.

## Provider Configuration

Parrot sends translation requests to the provider you configure. Base URLs must
normalize to an HTTPS OpenAI-compatible chat completions endpoint. Root URLs,
`/v1` URLs, and full `/chat/completions` URLs are supported.

The app stores non-secret provider settings in UserDefaults. API keys are
stored only in Keychain.

## Privacy

- API keys are stored only in macOS Keychain.
- Screenshot images are used locally for OCR and are not uploaded by default.
- Only recognized or typed text is sent to the configured provider during
  translation.
- Translation history is local, text-only, and does not include screenshots,
  screen geometry, API keys, or provider responses.
- History can be disabled or cleared in `Settings > Privacy`.
- Diagnostics summaries exclude API keys, endpoint hosts, model names, source
  text, provider responses, history content, screenshots, window titles, and
  source app names.

## FAQ

### macOS says Parrot is from an unidentified developer

This RC is unsigned and not notarized. For a trusted local test build, use
right-click > Open. A future signed release should replace this flow once a
Developer ID certificate and notarization setup are available.

### Screenshot Translation does not start

Open `System Settings > Privacy & Security > Screen Recording`, enable Parrot,
then retry Screenshot Translation. Quick Text works without this permission.

### There are duplicate Parrot entries in Screen Recording

Old unsigned builds can leave stale macOS permission entries because Screen
Recording permission is tied to the app code requirement. Prefer the current
packaged app in `/Applications`, enable that entry, and remove or ignore stale
entries from older debug or release copies.

### Parrot asks me to save the API key again

Unsigned debug or RC builds can change the Keychain access context. Re-enter the
API key in `Settings > Model`; Parrot will save it back to Keychain and will not
store it in config files or logs.

### Where is local data stored?

Translation history is stored under:

```text
~/Library/Application Support/Parrot/translation-history.json
```

Provider settings and preferences are stored in UserDefaults. API keys are in
Keychain.

### How do I uninstall Parrot?

Quit Parrot, remove `/Applications/Parrot.app`, then optionally remove local
history from `~/Library/Application Support/Parrot/` and delete saved API keys
from Keychain.

## Known Limitations

- Current public RC packages are unsigned and not notarized.
- Screenshot Translation depends on macOS Screen Recording permission.
- Translation quality, availability, and latency depend on the configured
  provider.
- The app is macOS-only.
- Automatic update download and installation is not implemented yet.

## Developer Verification

```sh
./init.sh
Scripts/run-core-e2e.sh
Scripts/package-release.sh --allow-untagged
```

Release builds read `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, bundle ID,
Swift version, and deployment target from `Config/Release.xcconfig`. The current
Release configuration is `0.1.4` build `6`.

## Project Layout

- `Parrot.xcodeproj/`: Xcode project with the `Parrot` target and scheme.
- `Parrot/App/`: SwiftUI and AppKit application code.
- `Parrot/Resources/`: app asset catalog and resources.
- `Config/`: Debug and Release build settings.
- `Docs/`: product and release planning documents.
- `Scripts/`: source-linked regression checks and packaging scripts.

Agent-specific workflow, constraints, and handoff state live in `AGENTS.md`,
`parrot-progress.md`, and `feature_list.json`.
