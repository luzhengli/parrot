# Project: Parrot

Parrot is a native macOS SwiftUI app scaffold for an AI translation assistant. The product direction is a menu-bar utility with global shortcuts, screenshot OCR translation, quick text translation, and user-configured OpenAI-compatible LLM providers.

## Commands

- Open locally: `open Parrot.xcodeproj`
- List project metadata: `xcodebuild -list -project Parrot.xcodeproj`
- Build: `./init.sh`
- Debug run without Xcode: `./init.sh --run`
- Reset screenshot permission only when needed: `./init.sh --reset-screen-capture --run`
- If `xcodebuild` uses Command Line Tools instead of full Xcode, tell the user to run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

## Layout

- `Parrot.xcodeproj/` contains the single Xcode project, target, and scheme named `Parrot`.
- `Parrot/App/ParrotApp.swift` is the SwiftUI app entry point.
- `Parrot/App/ContentView.swift` is the current starter UI.
- `Parrot/Resources/Assets.xcassets/` contains app assets and icons.
- `Config/Debug.xcconfig` and `Config/Release.xcconfig` define bundle ID, version, Swift version, and macOS deployment target.
- `Docs/ai-translation-macos-prd.md` is the source of product requirements and should guide feature behavior.

## Product Constraints

- Keep the MVP focused on macOS only; do not introduce cross-platform frameworks unless the user explicitly asks.
- Prefer native macOS capabilities: SwiftUI for settings/basic windows, AppKit for menu bar/global shortcuts/floating windows/screenshot selection, Vision for local OCR, Keychain for API keys, and URLSession for LLM calls.
- Default to local OCR and send only recognized text to the configured LLM; do not upload screenshots unless the user explicitly enables an image-based feature.
- Store API keys in macOS Keychain only; never write secrets to config files, logs, fixtures, or docs.
- Preserve the lightweight workflow: trigger by shortcut, show a small result window, support copy, and allow `Esc` to close transient UI.
- For translation prompts, preserve paragraph structure, code, variable names, links, product names, and proper nouns; do not add explanations unless the user asks for explanation mode.

## Code Conventions

- Use Swift 5 and target macOS 14.0 unless the user asks to change project compatibility.
- Keep UI native and simple; avoid heavy custom styling that conflicts with macOS conventions.
- Add AppKit bridges only where SwiftUI cannot cover macOS system behavior cleanly.
- Keep feature code separated by responsibility as the app grows; avoid putting menu bar, OCR, networking, settings, and Keychain logic into `ContentView`.
- Surface user-facing errors for permissions, OCR failures, authentication failures, network failures, and timeouts.
- Do not hard-code provider-specific assumptions beyond OpenAI-compatible defaults unless adding a named provider.

## Workflow

- For non-trivial tasks, start by reading the harness handoff files: `parrot-progress.md` for current state and `feature_list.json` for prioritized acceptance criteria.
- Use `./init.sh` as the default fresh-session bootstrap and verification command. Use `./init.sh --skip-build` when only project metadata is needed, `./init.sh --open` when opening Xcode is useful, and `./init.sh --run` for TCC-sensitive local debugging because it stops old Parrot instances, builds into `./.DerivedData`, and opens that exact app bundle.
- Before larger changes, read `Docs/ai-translation-macos-prd.md` and align behavior with the MVP scope.
- When implementing product functionality, choose a high-priority feature with `passes: false` from `feature_list.json` unless the user explicitly asks for different work.
- Building successfully is only the baseline verification. Before marking any feature as `passes: true`, verify the feature against its `acceptance` criteria with an end-to-end or equivalent integration/manual acceptance check. Record the verification method and result in `feature_list.json` notes and update `parrot-progress.md`. If full end-to-end verification is not possible in the current environment, keep `passes: false` or mark the feature as blocked/failing with clear notes instead of treating a build-only check as feature completion.
- For user-facing workflow features such as menu-bar actions, global shortcuts, screenshot selection, OCR, provider settings, and translation windows, run a real user-flow smoke test whenever the environment supports it. Do not mark these features passing based on compile/build success alone.
- After completing feature work, update `feature_list.json` with the feature status, `last_verified`, and relevant notes. Also update `parrot-progress.md` with completed work, known issues, and next steps.
- After editing Swift or project settings, run the Debug build command when Xcode is available.
- Do not change `PRODUCT_BUNDLE_IDENTIFIER`, signing team, deployment target, or app version unless the task requires it.
- Do not modify generated Xcode project details casually; prefer Xcode-compatible project edits and verify with `xcodebuild`.
- Do not add dependencies for small native features before checking whether SwiftUI, AppKit, Vision, Security, or Foundation already solve the problem.

## Gotchas

- The repository is currently a scaffold; many PRD features are not implemented yet.
- `DEVELOPMENT_TEAM` is empty in both xcconfig files, so command-line builds should use `CODE_SIGNING_ALLOWED=NO`.
- Screen Recording permission is TCC-sensitive. For screenshot/global-shortcut debugging, prefer `./init.sh --run` instead of opening arbitrary `DerivedData` app bundles; multiple ad-hoc Debug copies can confuse permission identity and leave old processes holding global shortcuts.
- The app currently has one target and one scheme, both named `Parrot`.
- The default bundle identifier is `com.example.parrot`; treat it as placeholder unless the user asks to prepare distribution.

## When In Doubt

- Ask before changing product scope, privacy behavior, signing, distribution, or persistence of user data.
- Ask before deleting files or restructuring the Xcode project.
- If a requested implementation conflicts with the PRD, point out the mismatch before coding.
