---
paths:
  - "CookSavvy/Theme/**"
---

# Theme & Localization

- **Layout constants** — `UI` struct with nested domain structs (`UI.RecipeCell.imageSize`, `UI.V2.heroImageHeight`)
- **Theme system** — `AppTheme` protocol + `LightTheme` / `DarkTheme` + `SystemTheme` helper, injected via `@Environment(\.appTheme)`
  - Color tokens: `bg`, `surface`, `surfaceLight`, `card`, `accent`, `onAccent`, `accentSoft`, `mint`, `mintSoft`, `rose`, `roseSoft`, `lavender`, `lavenderSoft`, `sky`, `skySoft`, `gold`, `text1`, `text2`, `text3`, `divider`
    - `onAccent` = near-black foreground for content on `accent`/accent-gradient CTA fills (WCAG AA; white fails). `text3` is **decorative only** (placeholders, disabled-control states, decorative icons) — never for load-bearing text. A `ThemeContrastTests` unit test enforces every (text, surface) pair ≥ 4.5:1.
  - Corner radius tokens: `cornerRadiusSmall` (12), `cornerRadiusMedium` (16), `cornerRadiusLarge` (20), `cornerRadiusXL` (24), `cornerRadiusPill` (32)
- **View Modifiers** (`Theme/ViewModifiers.swift`): `.frostCard()`, `.neonGlow(_:radius:)`, `.sectionLabel()`
- **Strings** — `Strings` enum with nested screen enums, using `String(localized:defaultValue:)` for localization; accessed as `Strings.Settings.navigationTitle`
  - Screen enums include `Discover`, `Journey`, `CookMode`, `CreateRecipe`, `RecipeList`, `MoodFilter`
- **Icons** — `Icons` enum with nested screen enums for SF Symbol names; accessed as `Icons.Settings.trash`
  - Screen enums include `Discover`, `Journey`, `CookMode`, `CreateRecipe`, `Mood`
- **String Catalog** — `Localizable.xcstrings` (Xcode 15+), auto-populated from `String(localized:)` calls
- Adding a new theme: create a struct conforming to `AppTheme` and inject at app root
- Adding a new language: add translations in the String Catalog via Xcode

## File Map

```
Theme/
├── UIConstants.swift              — Layout constants (nested `UI` struct + `UI.V2`)
├── AppTheme.swift                 — Theme protocol + LightTheme + DarkTheme + SystemTheme
├── ViewModifiers.swift            — FrostCard, NeonGlow, SectionLabel modifiers
├── Strings.swift                  — Localized strings (`String(localized:)`) by screen
└── Icons.swift                    — SF Symbol names by screen
```
