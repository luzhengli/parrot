---
name: Invisible Utility
colors:
  surface: '#fcf8fb'
  surface-dim: '#dcd9dc'
  surface-bright: '#fcf8fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f5'
  surface-container: '#f0edef'
  surface-container-high: '#eae7ea'
  surface-container-highest: '#e4e2e4'
  on-surface: '#1b1b1d'
  on-surface-variant: '#424656'
  inverse-surface: '#303032'
  inverse-on-surface: '#f3f0f2'
  outline: '#727687'
  outline-variant: '#c2c6d8'
  surface-tint: '#0054d6'
  primary: '#0050cb'
  on-primary: '#ffffff'
  primary-container: '#0066ff'
  on-primary-container: '#f8f7ff'
  inverse-primary: '#b3c5ff'
  secondary: '#5d5e60'
  on-secondary: '#ffffff'
  secondary-container: '#dfdfe1'
  on-secondary-container: '#616365'
  tertiary: '#585a5a'
  on-tertiary: '#ffffff'
  tertiary-container: '#717272'
  on-tertiary-container: '#f8f8f8'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dae1ff'
  primary-fixed-dim: '#b3c5ff'
  on-primary-fixed: '#001849'
  on-primary-fixed-variant: '#003fa4'
  secondary-fixed: '#e2e2e4'
  secondary-fixed-dim: '#c6c6c8'
  on-secondary-fixed: '#1a1c1d'
  on-secondary-fixed-variant: '#454749'
  tertiary-fixed: '#e2e2e2'
  tertiary-fixed-dim: '#c6c6c6'
  on-tertiary-fixed: '#1a1c1c'
  on-tertiary-fixed-variant: '#454747'
  background: '#fcf8fb'
  on-background: '#1b1b1d'
  surface-variant: '#e4e2e4'
typography:
  display:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.03em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 40px
  gutter: 20px
  margin: 32px
---

## Brand & Style

This design system is built on the philosophy of "disappearing utility." It targets professional users who value efficiency and focus, creating an environment where the interface recedes to let the content or task take center stage. The emotional response should be one of calm, clarity, and native integration.

The style is **Hyper-Minimalist Corporate**. It draws heavily from modern desktop OS patterns, favoring strict alignment, intentional negative space, and a lack of decorative flourish. By removing unnecessary borders, shadows, and vibrant saturation, the UI feels like a lightweight, transparent layer over the user's workflow—a "use and leave" tool that never overstays its welcome.

## Colors

The palette is restricted to a surgical range of neutrals to maintain a clean, native aesthetic. The YAML tokens above are the normative values; prose names explain how to use those tokens.
- **Primary Surface:** Use `surface-container-lowest` (#ffffff) for main content areas that need maximum perceived "airiness." Use `surface` / `background` (#fcf8fb) for the app-level base.
- **Secondary Surface:** Use the `surface-container-*` scale (#f6f3f5, #f0edef, #eae7ea, #e4e2e4) for toolbars, sidebars, grouped controls, and secondary utility panels without creating heavy visual breaks.
- **Accent:** Use `primary` (#0050cb) for primary actions and focus intent. `primary-container` (#0066ff) is reserved for stronger active states or web prototype calibration.
- **Typography:** Use `on-surface` (#1b1b1d) for primary text, `on-surface-variant` (#424656) for secondary text, and `outline` (#727687) for subdued metadata.
- **Dividers:** Use `surface-container-highest` (#e4e2e4) or `outline-variant` (#c2c6d8) for hairline separators, only when negative space alone cannot define a boundary.

## Platform & Native Implementation

Parrot is a native macOS SwiftUI/AppKit app. Use macOS semantic colors, material behavior, system font metrics, and native controls first. The hex colors and Inter typography tokens are review, lint, and web-prototype fallbacks; they should not be hard-coded into SwiftUI/AppKit unless a local exception is explicitly justified.

## Typography

The typography tokens use **Inter** as the closest web-available equivalent to SF Pro. Native SwiftUI/AppKit surfaces should use the system font and native control text styles while preserving the same hierarchy, weight, and density.

The hierarchy is driven by weight and negative space rather than dramatic size shifts. Generous leading (line height) and paragraph spacing are mandatory to ensure the "breathable" feel of the interface. Tracking is slightly tightened on larger headlines for a "locked-in" professional look, while smaller labels receive slight letter-spacing to ensure legibility on high-density displays. Text should always have a minimum of 16px horizontal padding from its container edges.

## Layout & Spacing

This design system uses a **Fixed Grid** model for core content with fluid containers for utility bars. The spacing rhythm is based on a strict 4px/8px incremental scale.

- **Desktop:** 12-column grid with 20px gutters. Content is centered with a max-width of 1200px to prevent excessive line lengths.
- **Tablet:** 8-column grid with 16px gutters and 24px margins.
- **Mobile:** 4-column grid with 16px gutters and 16px margins.

Layouts should favor "grouping by proximity" rather than containment. Use large `xl` (40px) gaps between major functional sections to allow the UI to "breathe" without the need for boxes or lines.

## Elevation & Depth

In pursuit of a "flat" native feel, elevation is conveyed through **Tonal Layers** and **Subtle Contrast** rather than shadows.

- **Level 0 (Base):** `surface-container-lowest` (#ffffff) for the primary workspace.
- **Level 1 (Navigation/Utility):** `surface-container-low` (#f6f3f5) or `surface-container` (#f0edef) for sidebars or top bars.
- **Level 2 (Popovers/Modals):** `surface-container-lowest` (#ffffff) with a very thin `surface-container-highest` (#e4e2e4) border. Shadows are avoided unless necessary for legibility against complex content, in which case a very diffused 10% opacity neutral shadow is used.

Interactivity is communicated via subtle shifts within the `surface-container-*` scale rather than lift or glow effects.

## Shapes

The shape language is **Soft** and precise. A universal corner radius of 0.25rem (4px) is applied to standard components like input fields and buttons to provide a hint of approachability while maintaining a structured, professional appearance. Larger components like cards or modals may scale to 0.5rem (8px), but never exceed this to avoid a "playful" or overly consumer-focused aesthetic.

## Components

- **Buttons:** Primary buttons use `primary` with `on-primary` text. Secondary buttons are "Ghost" style: transparent backgrounds with `on-surface` text, becoming subtly tonal on hover.
- **Inputs:** Clean, borderless-first approach where possible, or a simple 1px hairline border using `surface-container-highest` or `outline-variant`. Focus states use `primary` / `surface-tint` with an offset to maintain clarity.
- **Chips:** Minimalist tags use a `surface-container-*` background with `on-surface` text. No icons unless functional.
- **Lists:** Use 1px hairline dividers from `surface-container-highest` or `outline-variant` that do not span the full width of the container (inset by 16px) to maintain a modern, airy feel.
- **Cards:** Cards should not have shadows. Use a simple 1px tokenized hairline border or, preferably, just a `surface-container-*` background change to define the container.
- **Selection Controls:** Checkboxes and Radio buttons should be small (14px) and use the primary blue for the checked state, following the native OS appearance.
- **Tooltips:** Plain charcoal background with white text, 4px rounded corners, appearing only after a significant delay to minimize visual noise.
