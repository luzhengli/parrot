# Global Shortcuts Design

## Goal

Implement `p0.global-shortcuts` for Parrot so users can trigger quick text translation and screenshot translation while another app is frontmost.

## Scope

- Register two default global shortcuts:
  - `Cmd+Shift+T` for quick text translation.
  - `Cmd+Shift+2` for screenshot translation.
- Add a menu-bar action to pause or resume shortcuts.
- Reuse the existing quick text and screenshot placeholder windows as the triggered actions.
- Keep shortcut handling separate from menu and window presentation code.

## Approach

Use Carbon `RegisterEventHotKey` for MVP global shortcuts. This provides app-wide hotkeys without adding dependencies or using a broad keyboard event monitor. The implementation will introduce a `GlobalShortcutManager` that owns registration, unregistration, and event dispatch.

`AppDelegate` will create the manager on launch and provide closures for each shortcut action. It will also update the menu item title when shortcuts are paused or resumed.

## Components

- `GlobalShortcutManager`: registers Carbon hotkeys, installs the event handler, dispatches shortcut identifiers, and unregisters on deinit.
- `AppDelegate`: wires shortcut actions to existing window presentation methods and exposes pause/resume in the status menu.
- `feature_list.json` and `parrot-progress.md`: record verification status and implementation notes after validation.

## Error Handling

If a shortcut cannot be registered, the app will keep running, log a concise diagnostic through `NSLog`, and expose the failure in the menu-bar dropdown. The shortcuts menu item will show a disabled/error state such as `Shortcuts Unavailable`, and the affected feature actions remain available from the menu bar.

Carbon hotkeys do not require Accessibility permission for the planned shortcut registration, so the current implementation should treat the permission-related acceptance item as not applicable for this API path. The user-facing failure path for this feature is shortcut registration failure, usually caused by conflicting hotkeys or unsupported key combinations. If future shortcut handling changes to event monitoring or selected-text integration, Accessibility permission guidance should be added as a separate feature.

## Verification

- Build the Debug scheme with `CODE_SIGNING_ALLOWED=NO`.
- Launch the app and smoke-test `Cmd+Shift+T` and `Cmd+Shift+2` from outside the app when the environment supports GUI testing.
- Verify pause/resume prevents and restores shortcut actions.
- Update feature notes honestly: mark passing only if the actual user flow is verified, otherwise record the blocker.
