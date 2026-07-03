# Parrot /Design Reference Assets

This directory is a visual reference for a future one-time UI refactor. It does not represent the current SwiftUI/AppKit implementation.

## Use Rules

- These assets lag behind the real code and are expected to drift as Parrot evolves.
- All prototypes in this directory follow root `DESIGN.md`; `DESIGN.md` is the normative source, and `/Design` is only a visual interpretation.
- Daily feature work must not reference `/Design` by default.
- Use `/Design` only when the user explicitly asks to reference the prototypes, compare against planned refactor assets, or align a refactor with these screens.
- If `/Design` conflicts with current code or `DESIGN.md`, treat `/Design` as stale unless the user explicitly asks for a refactor decision.

## Asset Pairs

| Surface | HTML prototype | Screenshot | Current app surface |
| --- | --- | --- | --- |
| `quick_text_translation` | `quick_text_translation/code.html` | `quick_text_translation/screen.png` | Quick Text Translation window |
| `screenshot_translation` | `screenshot_translation/code.html` | `screenshot_translation/screen.png` | Screenshot Translation result window |
| `settings` | `settings/code.html` | `settings/screen.png` | Unified Settings window |

## Version Status

Current assets use the existing flat page structure and are not a versioned refactor baseline. If a future refactor needs a frozen visual target, create a versioned subdirectory or manifest that records the target milestone, the `DESIGN.md` revision, lint result, and the paired HTML/PNG assets.
