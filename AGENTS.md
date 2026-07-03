# Project: Parrot

Parrot is a native macOS SwiftUI/AppKit menu-bar translation assistant prototype. It supports global shortcuts, screenshot OCR translation, quick text translation, local translation history, custom shortcuts, and user-configured OpenAI-compatible LLM providers.

## Commands

- Open locally: `open Parrot.xcodeproj`
- List project metadata: `xcodebuild -list -project Parrot.xcodeproj`
- Build: `./init.sh`
- Debug run without Xcode: `./init.sh --run`
- Reset screenshot permission only when needed: `./init.sh --reset-screen-capture --run`
- Build unsigned release packages: `Scripts/package-release.sh`
- Validate unsigned release packaging before tagging: `Scripts/package-release.sh --allow-untagged`
- If `xcodebuild` uses Command Line Tools instead of full Xcode, tell the user to run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

## Layout

- `Parrot.xcodeproj/` contains the single Xcode project, target, and scheme named `Parrot`.
- `Parrot/App/` contains the app entry point, menu-bar shell, global shortcuts, screenshot/OCR flow, translation UI, provider settings, shortcut settings, and translation history.
- `Parrot/Resources/` contains app assets and icons.
- `Config/` contains Debug and Release build settings, including bundle ID, version, Swift version, and macOS deployment target.
- `Docs/` contains PRDs and planning documents. Treat PRDs as conditional references only: read them when the user explicitly asks for PRD alignment/review, or when the task is specifically to update/audit PRD-backed planning.
- `Docs/release-process.md` contains the SemVer, Git tag, and GitHub Release packaging workflow.
- `Scripts/` contains focused source-linked regression checks for implemented features.
- `parrot-progress.md` and `feature_list.json` are the handoff and acceptance-tracking files for agent work.

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

## Design Harness

- `DESIGN.md` at the repository root is the single mandatory design source for Parrot UI/UX work. It defines visual language, color, typography, density, native component choices, layout, states, and motion guidance through YAML tokens plus Markdown rationale.
- `DESIGN.md` must stay committed and version-controlled as the team design contract. Do not add it to `.gitignore`, rename it, move it under `Docs/`, or treat it as a per-session prompt note.
- Mandatory trigger: before any UI/UX work, read and align with `DESIGN.md`. This includes new UI features, UI refactors, changes to windows, Settings sections, menu surfaces, status/error/loading/empty states, user-facing flow layout, and user-facing UI copy. Non-UI implementation work does not need to load `DESIGN.md`.
- Native implementation rule: SwiftUI/AppKit work should prefer macOS semantic colors, system fonts, native controls, and HIG-aligned behavior. Hex colors and web typography in `DESIGN.md` are review/lint/prototype fallback values unless a local exception is explicitly justified.
- Stability rule: day-to-day feature work consumes `DESIGN.md`; do not opportunistically rewrite it. Update `DESIGN.md` only for deliberate design direction, token, component, state, or motion changes, then run `npx @google/design.md lint DESIGN.md` when available and record the result.
- Do not invent new visual decisions without a reason: no new custom colors, typography, spacing, radius, shadows, or motion unless the change is justified by the user request, `DESIGN.md`, or a recorded local exception.
- PRDs are conditional references only. They can drift behind the implemented app, including product behavior, so do not use them as a default source for daily feature work. Read PRDs only when the user explicitly asks for PRD reference/alignment/review, or when the task is specifically PRD/planning work.
- When PRDs are explicitly in scope, use them as requested context, then verify against current code and current user intent. Do not let stale PRD text override implemented behavior without calling out the mismatch.
- `/Design` is conditional-only. The HTML prototypes under `/Design` are future one-time-refactor reference assets, not current implementation evidence. Do not open or use them for daily feature work unless the user explicitly asks to reference `/Design`, compare against a prototype, or align with a planned refactor. When `/Design` is explicitly in scope, use the relevant `code.html` file as the prototype source for higher fidelity.
- `/Design` follows `DESIGN.md`, never the reverse. If a prototype disagrees with `DESIGN.md` or current app behavior, treat the prototype as stale unless the user explicitly asks for a refactor decision.
- Conflict priority, highest to lowest: explicit user instruction > privacy/security/macOS permission/Keychain constraints > macOS HIG > `DESIGN.md` > current code's established shape. PRDs and `/Design` do not participate in day-to-day arbitration; use them only when explicitly requested.
- Design trigger keywords for mandatory `DESIGN.md` review include: `UI`, `界面`, `视觉`, `样式`, `布局`, `设计`, `重构 UI`, `Settings`, `窗口`, `错误态`, `空状态`, `loading`, `配色`, `字体`, `间距`, `圆角`, and `控件`.
- Conditional `/Design` trigger keywords require explicit user intent, such as: `参考 /Design`, `对照原型`, `按设计稿`, `reference the prototype`, `match the mockup`, or `重构对照`.

## Workflow

- For non-trivial tasks, start by reading the harness handoff files: `parrot-progress.md` for current state and `feature_list.json` for prioritized acceptance criteria.
- Use `./init.sh` as the default fresh-session bootstrap and verification command. Use `./init.sh --skip-build` when only project metadata is needed, `./init.sh --open` when opening Xcode is useful, and `./init.sh --run` for TCC-sensitive local debugging because it stops old Parrot instances, builds into `./.DerivedData`, and opens that exact app bundle.
- For larger changes, use current code, `feature_list.json`, `parrot-progress.md`, and the user's request as the default product context. Read PRDs only when the user explicitly asks for PRD reference/alignment/review, or when updating/auditing PRD-backed planning.
- For UI work, follow current app behavior, native macOS conventions, and root `DESIGN.md`. Do not treat PRDs as a default product or visual reference. See Design Harness for mandatory vs conditional design references.
- When implementing product functionality, choose a high-priority feature with `passes: false` from `feature_list.json` unless the user explicitly asks for different work.
- Building successfully is only the baseline verification. Before marking any feature as `passes: true`, verify the feature against its `acceptance` criteria with an end-to-end or equivalent integration/manual acceptance check. Record the verification method and result in `feature_list.json` notes and update `parrot-progress.md`. If full end-to-end verification is not possible in the current environment, keep `passes: false` or mark the feature as blocked/failing with clear notes instead of treating a build-only check as feature completion.
- For user-facing workflow features such as menu-bar actions, global shortcuts, screenshot selection, OCR, provider settings, and translation windows, run a real user-flow smoke test whenever the environment supports it. Do not mark these features passing based on compile/build success alone.
- After completing feature work, update `feature_list.json` with the feature status, `last_verified`, and relevant notes. Also update `parrot-progress.md` with completed work, known issues, and next steps.
- After editing Swift or project settings, run the Debug build command when Xcode is available.
- For release work, read `Docs/release-process.md` first. Formal releases must use SemVer, a clean worktree, and a Git tag matching `v<MARKETING_VERSION>` before running `Scripts/package-release.sh`.
- Use `Scripts/package-release.sh --allow-untagged` only for local package validation; do not treat dev packages as formal GitHub releases.
- Do not change `PRODUCT_BUNDLE_IDENTIFIER`, signing team, deployment target, or app version unless the task requires it.
- Do not modify generated Xcode project details casually; prefer Xcode-compatible project edits and verify with `xcodebuild`.
- Do not add dependencies for small native features before checking whether SwiftUI, AppKit, Vision, Security, or Foundation already solve the problem.

## Gotchas

- The P0 MVP path is largely implemented. Historical P1/P2 planning exists in `Docs/ai-translation-macos-v1-prd.md`; read it only when the user requests PRD-backed planning, review, or alignment.
- `DEVELOPMENT_TEAM` is empty in both xcconfig files, so command-line builds should use `CODE_SIGNING_ALLOWED=NO`.
- Release packages are currently unsigned and unnotarized. GitHub-style assets are generated under `Dist/`, which is ignored by git.
- Screen Recording permission is TCC-sensitive. For screenshot/global-shortcut debugging, prefer `./init.sh --run` instead of opening arbitrary `DerivedData` app bundles; multiple ad-hoc Debug copies can confuse permission identity and leave old processes holding global shortcuts.
- The app currently has one target and one scheme, both named `Parrot`.
- The default bundle identifier is `com.example.parrot`; treat it as placeholder unless the user asks to prepare distribution.

## When In Doubt

- Ask before changing product scope, privacy behavior, signing, distribution, or persistence of user data.
- Ask before deleting files or restructuring the Xcode project.
- If the user explicitly requests PRD alignment and the PRD conflicts with current code, current user intent, privacy/security, or macOS constraints, point out the mismatch before coding.
