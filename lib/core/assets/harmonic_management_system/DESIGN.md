---
name: Harmonic Management System
colors:
  surface: '#0b1326'
  surface-dim: '#0b1326'
  surface-bright: '#31394d'
  surface-container-lowest: '#060e20'
  surface-container-low: '#131b2e'
  surface-container: '#171f33'
  surface-container-high: '#222a3d'
  surface-container-highest: '#2d3449'
  on-surface: '#dae2fd'
  on-surface-variant: '#c2c6d6'
  inverse-surface: '#dae2fd'
  inverse-on-surface: '#283044'
  outline: '#8c909f'
  outline-variant: '#424754'
  surface-tint: '#adc6ff'
  primary: '#adc6ff'
  on-primary: '#002e6a'
  primary-container: '#4d8eff'
  on-primary-container: '#00285d'
  inverse-primary: '#005ac2'
  secondary: '#4edea3'
  on-secondary: '#003824'
  secondary-container: '#00a572'
  on-secondary-container: '#00311f'
  tertiary: '#ffb95f'
  on-tertiary: '#472a00'
  tertiary-container: '#ca8100'
  on-tertiary-container: '#3e2400'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#d8e2ff'
  primary-fixed-dim: '#adc6ff'
  on-primary-fixed: '#001a42'
  on-primary-fixed-variant: '#004395'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#ffddb8'
  tertiary-fixed-dim: '#ffb95f'
  on-tertiary-fixed: '#2a1700'
  on-tertiary-fixed-variant: '#653e00'
  background: '#0b1326'
  on-background: '#dae2fd'
  surface-variant: '#2d3449'
typography:
  display-lg:
    fontFamily: Hanken Grotesk
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  chord-display:
    fontFamily: JetBrains Mono
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: 0.05em
  lyric-text:
    fontFamily: Hanken Grotesk
    fontSize: 20px
    fontWeight: '400'
    lineHeight: 32px
  label-sm:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  container-padding: 24px
  sidebar-width: 280px
  gutter: 16px
  stack-gap: 12px
  section-margin: 40px
---

## Brand & Style

The design system is engineered for professional musicians and worship leaders who require precision, clarity, and aesthetic calm during high-pressure management and performance tasks. It adopts a **Modern Corporate** aesthetic—prioritizing utility and focus over decoration—while incorporating elements of **Minimalism** to ensure that complex chord sheets and lyrics remain the hero of the interface.

The emotional response is one of "focused reliability." By using a dark-mode-first approach with deep oceanic tones, the UI recedes into the background, allowing the white or light-gray musical notation to pop with high legibility. This creates an environment that feels like a premium desktop productivity tool—precise, stable, and sophisticated.

## Colors

The palette is anchored in **Slate and Navy** tones to provide a low-strain environment for extended editing sessions. 

- **Primary (Electric Blue):** Reserved for primary actions, focus states, and the "current song" indicator.
- **Secondary (Emerald):** Used for "Live" or "Active" performance indicators and successful sync states.
- **Tertiary (Amber):** Specific to chord notation highlights or "Needs Review" status markers.
- **Neutrals:** A range of cool grays that distinguish between the sidebar, the editor, and the preview pane without using heavy borders.

## Typography

This design system uses a dual-font strategy. **Hanken Grotesk** provides a sharp, contemporary feel for the UI and lyric text, offering excellent readability at various weights. **JetBrains Mono** is utilized for chord notations and technical metadata (BPM, Key, Time Signature). 

The monospace font ensures that chords stay perfectly aligned above lyrics, preventing the "drifting" common in variable-width fonts. For performance views, font sizes for lyrics and chords are significantly increased to ensure visibility from a distance (e.g., on a floor monitor).

## Layout & Spacing

The layout follows a **Fixed-Fluid-Fixed** structure typical of high-end productivity suites:
1.  **Navigation Rail (Fixed):** Minimized left bar for global app sections.
2.  **Library Sidebar (Fixed):** A 280px searchable list of songs and sets.
3.  **Editor/Preview (Fluid):** The central workspace that expands to fill the remaining area.

We employ an 8px grid system for general spacing, but use a 4px "half-step" for tight UI controls. Generous vertical whitespace between verses and choruses is mandatory to prevent visual crowding during performance.

## Elevation & Depth

Hierarchy is established through **Tonal Layering** rather than traditional drop shadows.
- **Level 0 (Background):** `#020617` — The lowest layer, used for the main application backdrop.
- **Level 1 (Surface):** `#0F172A` — Sidebar and secondary panels.
- **Level 2 (Active Surface):** `#1E293B` — The active song editor or modal windows.
- **Level 3 (Overlay):** High-contrast tooltips and context menus use a slight background blur (backdrop-filter: blur(12px)) to separate themselves from the dense text underneath.

Subtle 1px borders in `#334155` are used sparingly to define boundaries between panels.

## Shapes

The design system utilizes **Soft** roundedness (4px/0.25rem). This maintains a professional, "tooled" look that feels engineered rather than casual. 

- **Buttons & Inputs:** 4px radius.
- **Cards & Modals:** 8px (rounded-lg).
- **Active State Indicators:** Vertical pills (fully rounded) on the left edge of list items to denote selection.

## Components

### Buttons
- **Primary:** Solid Electric Blue with white text. High-contrast for critical actions like "Go Live" or "Save."
- **Ghost:** Transparent background with a Slate-400 border. Used for secondary management tasks.

### Chord Tags
Inline chord notation within the editor should be wrapped in a subtle background tint (Primary 10%) with the text in Primary Blue to distinguish logic from content.

### Song List Items
Each item includes a title (Bold Slate-100), subtitle (Slate-400), and a small monospace "Key" badge in the trailing edge. The hover state uses a subtle Level 2 surface highlight.

### Input Fields
Dark backgrounds (`#020617`) with a 1px border. On focus, the border transitions to Primary Blue with a 2px outer glow (0% opacity to 20% opacity) for a "soft focus" effect.

### Metadata Chips
Small, mono-spaced chips used for BPM, Key, and Duration. These use a "neutral-filled" style (Slate-800 background, Slate-300 text).