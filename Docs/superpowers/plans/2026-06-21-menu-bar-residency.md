# Menu Bar Residency Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native macOS menu-bar entry for Parrot with actions for quick text translation, screenshot translation, settings, and quit.

**Architecture:** Use an AppKit `NSStatusItem` managed by an `NSApplicationDelegate` so the app can expose a stable menu-bar entry while keeping SwiftUI for lightweight placeholder windows. Menu actions open reusable `NSWindowController` instances that host SwiftUI views for settings and not-yet-implemented feature placeholders.

**Tech Stack:** Swift 5, SwiftUI, AppKit, Xcode project source phase updates, `xcodebuild`.

---

## Chunk 1: Menu-Bar Shell

### Task 1: Add Status Item Controller

**Files:**
- Create: `Parrot/App/AppDelegate.swift`
- Modify: `Parrot/App/ParrotApp.swift`
- Modify: `Parrot.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create `AppDelegate.swift`**
  - Define `AppDelegate: NSObject, NSApplicationDelegate`.
  - Create an `NSStatusItem` in `applicationDidFinishLaunching`.
  - Use a text bubble SF Symbol when available, with fallback title `Parrot`.
  - Build an `NSMenu` with `Quick Text Translation`, `Screenshot Translation`, separator, `Settings`, separator, and `Quit Parrot`.
  - Wire actions to window presentation helpers and `NSApp.terminate`.

- [ ] **Step 2: Add SwiftUI Placeholder Views**
  - Add focused SwiftUI views inside `AppDelegate.swift` for `SettingsPlaceholderView` and `FeaturePlaceholderView`.
  - Keep placeholders honest: label text translation and screenshot translation as not implemented yet.
  - Include short explanatory text so menu actions produce visible feedback without claiming the full feature is complete.

- [ ] **Step 3: Connect App Delegate**
  - Add `@NSApplicationDelegateAdaptor(AppDelegate.self)` to `ParrotApp`.
  - Keep the existing `WindowGroup` and `ContentView` unchanged except for delegate integration.

- [ ] **Step 4: Register Source File**
  - Add `AppDelegate.swift` as a file reference under the `Parrot/App` group.
  - Add `AppDelegate.swift in Sources` to the `Parrot` target source build phase.

- [ ] **Step 5: Verify Build**
  - Run: `xcodebuild -scheme Parrot -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
  - Expected: build succeeds without code signing.

### Task 2: Update Handoff State

**Files:**
- Modify: `feature_list.json`
- Modify: `parrot-progress.md`

- [ ] **Step 1: Mark Feature Passing**
  - Set `p0.menu-bar-residency.passes` to `true`.
  - Set `last_verified` to `2026-06-21`.
  - Note that settings, quick text translation, and screenshot translation menu entries open placeholder windows pending their dedicated features.

- [ ] **Step 2: Update Progress**
  - Add a session entry describing the native menu-bar entry.
  - Move menu-bar residency out of the current missing basics while preserving the still-unimplemented downstream actions.

- [ ] **Step 3: Run Harness**
  - Run: `./init.sh`
  - Expected: project metadata lists `Parrot`, Debug build succeeds.
