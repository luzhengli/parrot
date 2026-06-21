# Global Shortcuts Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add default global shortcuts for quick text translation and screenshot translation, with menu-bar pause/resume control.

**Architecture:** Add a focused Carbon-backed `GlobalShortcutManager` that owns hotkey registration and dispatch. Keep `AppDelegate` responsible for menu construction, window presentation, and wiring shortcut callbacks to existing feature actions.

**Tech Stack:** Swift 5, AppKit, SwiftUI, Carbon HotKey APIs, Xcode macOS target.

---

## File Structure

- Create `Parrot/App/GlobalShortcutManager.swift`: Carbon hotkey registration, unregistering, pause/resume, and callback dispatch.
- Modify `Parrot/App/AppDelegate.swift`: own the manager, add the pause/resume menu item, reflect registration errors in the menu, and wire callbacks to existing placeholder actions.
- Modify `Parrot.xcodeproj/project.pbxproj`: add `GlobalShortcutManager.swift` to the `Parrot/App` group and target sources.
- Modify `feature_list.json`: update `p0.global-shortcuts` verification status and notes after build and smoke testing.
- Modify `parrot-progress.md`: record implemented shortcut behavior, verification, blockers, and next steps.

## Chunk 1: Shortcut Manager

### Task 1: Add Carbon HotKey Manager

**Files:**
- Create: `Parrot/App/GlobalShortcutManager.swift`

- [ ] **Step 1: Create the manager skeleton**

Add `GlobalShortcutManager`, `GlobalShortcutAction`, and `GlobalShortcutRegistrationError`.

```swift
import Carbon
import Foundation

enum GlobalShortcutAction: UInt32, CaseIterable {
    case quickTextTranslation = 1
    case screenshotTranslation = 2
}

final class GlobalShortcutManager {
    typealias Handler = (GlobalShortcutAction) -> Void

    private let handler: Handler
    private var eventHandler: EventHandlerRef?
    private var hotKeys: [GlobalShortcutAction: EventHotKeyRef] = [:]
    private(set) var isPaused = false
    private(set) var lastRegistrationError: String?

    init(handler: @escaping Handler) {
        self.handler = handler
    }
}
```

- [ ] **Step 2: Implement registration and event dispatch**

Register:
- `Cmd+Shift+T` for `.quickTextTranslation`.
- `Cmd+Shift+2` for `.screenshotTranslation`.

Use Carbon constants:
- `cmdKey | shiftKey` for modifiers.
- `kVK_ANSI_T` and `kVK_ANSI_2` for key codes.
- `RegisterEventHotKey` for registration.
- `InstallEventHandler` on `GetEventDispatcherTarget()` for `kEventHotKeyPressed`.

- [ ] **Step 3: Implement pause/resume**

Add:
- `start() -> Bool`
- `pause()`
- `resume() -> Bool`
- `setPaused(_:) -> Bool`
- `unregisterAll()`
- `deinit` cleanup for registered hotkeys and the installed event handler

Expected behavior:
- `pause()` unregisters all hotkeys and sets `isPaused = true`.
- `resume()` attempts registration and sets `isPaused = false` only when registration succeeds.
- `lastRegistrationError` stores a user-facing message if registration fails.
- `deinit` calls `unregisterAll()` and removes `eventHandler` with `RemoveEventHandler` so manager teardown does not leave duplicated or dangling Carbon callbacks.

- [ ] **Step 4: Build-check the manager**

Run:

```bash
xcodebuild -scheme Parrot -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Expected:
- Build fails only if the new file is not yet added to the target. Continue to Chunk 2 before treating this as a problem.

## Chunk 2: App Wiring

### Task 2: Wire Shortcuts Into AppDelegate

**Files:**
- Modify: `Parrot/App/AppDelegate.swift`

- [ ] **Step 1: Add state**

Add:
- `private var globalShortcutManager: GlobalShortcutManager?`
- `private var shortcutsMenuItem: NSMenuItem?`

- [ ] **Step 2: Start shortcuts on launch**

In `applicationDidFinishLaunching`, after menu setup:
- Create the manager with a closure that dispatches to `showQuickTextTranslation` or `showScreenshotTranslation`.
- Call `start()`.
- Update the shortcuts menu item title/status.

- [ ] **Step 3: Add pause/resume menu item**

In `makeStatusMenu`, add a menu item between screenshot translation and settings:
- Title: `Pause Shortcuts` when active.
- Title: `Resume Shortcuts` when paused.
- Title: `Shortcuts Unavailable` and disabled if registration failed.

Action:
- `toggleShortcuts`

- [ ] **Step 4: Add menu state updater**

Add a helper that sets:
- title
- enabled state
- optional tooltip or represented object if needed for failure details

If registration fails, use `NSLog` and show the menu item as unavailable.

## Chunk 3: Project Registration

### Task 3: Add Swift File To Xcode Target

**Files:**
- Modify: `Parrot.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add file reference**

Add `GlobalShortcutManager.swift` to the `PBXFileReference` section and the `Parrot/App` group.

- [ ] **Step 2: Add build file**

Add `GlobalShortcutManager.swift in Sources` to the `PBXBuildFile` section and `PBXSourcesBuildPhase`.

- [ ] **Step 3: Verify project metadata**

Run:

```bash
xcodebuild -list -project Parrot.xcodeproj
```

Expected:
- Scheme `Parrot` is still listed.

## Chunk 4: Verification And Handoff

### Task 4: Build And Smoke-Test

**Files:**
- Modify: `feature_list.json`
- Modify: `parrot-progress.md`

- [ ] **Step 1: Run Debug build**

Run:

```bash
xcodebuild -scheme Parrot -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Expected:
- Build succeeds.

- [ ] **Step 2: Launch app for smoke test**

Run:

```bash
open -a "$(pwd)/build/Debug/Parrot.app"
```

If the app location differs, use the path reported by Xcode build products.

- [ ] **Step 3: Manual acceptance checks**

Verify when the environment supports GUI interaction:
- `Cmd+Shift+T` opens the quick text translation placeholder while another app is frontmost.
- `Cmd+Shift+2` opens the screenshot translation placeholder while another app is frontmost.
- `Pause Shortcuts` disables both shortcuts.
- `Resume Shortcuts` restores both shortcuts.
- Menu actions still work even if shortcut registration fails.

- [ ] **Step 4: Update feature status honestly**

If all manual checks pass:
- Set `p0.global-shortcuts.passes` to `true`.
- Set `last_verified` to `2026-06-21`.
- Record build and smoke-test notes.

If GUI smoke testing is unavailable:
- Keep `passes` as `false`.
- Record build success and manual test blocker in `notes`.

- [ ] **Step 5: Update progress file**

Append a session note to `parrot-progress.md` with:
- Files changed.
- Build result.
- Manual verification result or blocker.
- Next recommended feature.

- [ ] **Step 6: Commit implementation**

Run:

```bash
git add Parrot/App/GlobalShortcutManager.swift Parrot/App/AppDelegate.swift Parrot.xcodeproj/project.pbxproj feature_list.json parrot-progress.md
git commit -m "feat: add global shortcuts"
```
