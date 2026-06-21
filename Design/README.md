# Parrot Design References

This directory contains high-fidelity product prototype images for the Parrot macOS translation assistant.

## Screens

| File | Prototype | Implementation reference |
| --- | --- | --- |
| `quick-text-translation-panel.png` | View 1: Quick Text Translation Panel | Keyboard-first floating quick translation panel, light and dark appearance, shortcut hints, source/target language controls, copy/swap/close actions. |
| `screenshot-translation-result-card.png` | View 2: Screenshot Translation Result Card | Screenshot region selection result card with OCR source text, translated output, retry, close, copy translation, copy source, and compact dark appearance. |
| `settings-window.png` | View 3: Settings Window | Native macOS preferences window with General, Shortcuts, Model, Translation, Privacy, and About tabs, including light and dark appearances. |
| `menu-bar-dropdown.png` | View 4: Menu Bar Dropdown | Standard `NSMenu` opened from the menu-bar icon with quick translate, screenshot translate, history, shortcut toggle, settings, and quit actions. |

## Product Notes

- Treat these prototypes as visual guidance for the MVP surfaces described in `Docs/ai-translation-macos-prd.md`.
- Prefer native macOS controls and behavior over pixel-perfect custom rendering when platform conventions conflict.
- Keep privacy behavior aligned with the PRD: OCR runs locally by default and screenshots are not uploaded unless a future explicit image-based feature enables it.
