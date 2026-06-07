# CookSavvy — UI/UX Design Audit

**Date:** 2026-06-06
**Reviewer:** Senior UI/UX Designer (design-systems + iOS HIG + accessibility)
**Scope:** All SwiftUI screens, the theme/design system, accessibility infrastructure, and Liquid Glass (iOS 26) adoption readiness.
**Method:** Six parallel deep-dive audits (one per feature cluster + one cross-cutting design-system/a11y pass), each evaluating against Nielsen heuristics, Apple Human Interface Guidelines, App Store Review Guidelines, WCAG 2.1 AA, and Liquid Glass readiness. All top ship-blocker claims were verified directly against source.

> **App Store note:** Several ship blockers below (Restore Purchases, Terms/Privacy links, account deletion) are **likely App Store rejection triggers**, not just UX polish. Treat them as release-gating.

---

## 1. Executive Summary

CookSavvy has a genuinely strong, cohesive visual identity — a warm "frost glass + neon glow" design system with a well-factored token layer (`AppTheme`, `UI.*`, `Strings`, `Icons`). The information architecture is sensible and the navigation shell correctly uses a **native `TabView`** (which positions it well for iOS 26 Liquid Glass).

However, the audit surfaced **three systemic problems that touch nearly every screen**, plus a cluster of compliance gaps:

1. **Dynamic Type is effectively absent.** ~98% of text uses fixed `.system(size:)` tokens. Only `bodyScaled`/`stepContent` scale. Core reading surfaces (recipe titles, ingredients, the CookMode step text and timer) do not respond to the user's text-size setting. This is a WCAG 1.4.4 failure across the app.
2. **Color contrast fails WCAG AA on load-bearing text.** Section headings and metadata render in `text3` (~2:1), and the primary white-on-accent CTA fails AA in both themes (Light ~3.1:1, Dark ~2.0:1).
3. **App Store compliance gaps in the monetization + account surfaces.** No Restore Purchases, no Terms/Privacy links, no account deletion, raw user-ID shown as identity.

On top of these, the **CookMode (active cooking) screen has a broken core use case**: it never keeps the screen awake and its step text is non-scrollable and undersized — the two things a hands-free kitchen screen must get right.

**Verdict:** Not shippable as-is. The ship blockers are concentrated and fixable; most share root causes (the font token layer, the contrast tokens, a few missing controls). Liquid Glass adoption is viable and attractive, but should come *after* the contrast and Dynamic Type fixes — glass amplifies contrast problems.

### Counts

| Severity | Count |
|---|---|
| 🔴 SHIP BLOCKER | 16 |
| 🟠 HIGH | 22 |
| 🟡 MEDIUM | 21 |
| ⚪ LOW | 14 |

---

## 2. 🔴 Ship Blockers (release-gating)

These must be resolved before submission. Grouped by theme; each is verified.

### A. Accessibility — systemic (whole app)

| # | Blocker | Location | Why it blocks |
|---|---|---|---|
| SB-1 | **No Dynamic Type on primary reading surfaces.** ~50 font tokens, only 2 scale; used fixed ~179× vs scalable 4×. | `Theme/UIConstants.swift:16-63` | WCAG 1.4.4 failure on the app's core content. Users at large accessibility sizes get no enlargement of recipe titles, ingredients, captions, buttons. |
| SB-2 | **Section headings use `text3` (~2:1 contrast).** Load-bearing labels, not decoration. | `Theme/ViewModifiers.swift:69`; tokens `AppTheme.swift:125,171` | Light `#A0948A` on `bg` ≈ 2.0:1; Dark `white@0.35` ≈ 2.6:1. Fails AA (needs 4.5:1) at 30 call sites. |
| SB-3 | **`text3` used for real metadata; Light `text2` fails on darker surfaces.** | `AppTheme.swift:124-125,170-171`; e.g. `CommonComponents.swift:47` | `text3` ≈ 2.1–2.6:1 (fail). Light `text2 #6D635B` on `surfaceLight` ≈ 4.1:1 (fail for normal text). |
| SB-4 | **Primary white-on-accent CTA fails AA.** | `AppTheme.swift:112,158`; `UpgradeView.swift:223`, `DiscoverView.swift:88` | Light accent ≈ 3.1:1, Dark accent ≈ 2.0:1 with 17pt bold label. The "Find Dinner"/subscribe CTAs — core conversion surfaces — are hard to read. |

### B. Build integrity

| # | Blocker | Location | Why it blocks |
|---|---|---|---|
| SB-5 | **Mixed deployment targets (17.6 / 18.0 / 18.6).** Effective minimum OS is non-deterministic across the build matrix. | `CookSavvy.xcodeproj/project.pbxproj` (18.0 ×4, 18.6 ×2, 17.6 ×2) | Contradicts the stated 17.6 floor. Risks shipping APIs that crash on 17.6, or silently excluding users. Per-config drift means Debug QA ≠ Release minimum. Also a prerequisite for the Liquid Glass roadmap. |

### C. App Store compliance — subscriptions & account (Guidelines 3.1.2, 5.1.1)

> **Remediation status (2026-06-07):** SB-6 and SB-8 fixed in code; SB-7 and SB-9 are code-complete with hosting/backend deployment outstanding; SB-10 unchanged. Consolidated tracker: `docs/APPSTORE_BLOCKERS_STATUS_2026-06-07.md`.

| # | Blocker | Location | Why it blocks |
|---|---|---|---|
| SB-6 | ✅ **FIXED** — Restore Purchases now on the paywall (`UpgradeViewModel.restorePurchases()` + button & error alert). | `UpgradeView.swift` / `UpgradeViewModel.swift` | Guideline 3.1.1/3.1.2 requires it. Reinstall/device-switch users can't recover their subscription. Near-certain rejection. |
| SB-7 | ◐ **CODE DONE / HOSTING PENDING** — Terms + Privacy links added to paywall + Settings via `Utilities/LegalLinks.swift` (placeholder URLs); standard docs at `docs/legal/`. Left: host pages + real URLs. | `UpgradeView.swift`; `SettingsView.swift` | Guideline 3.1.2 / 5.1.1 require functional links at point of sale and in-app. |
| SB-8 | ✅ **FIXED** — `upgrade.autoRenew` disclosure tightened: trial is monthly-only, billing period, auto-renew, and cancellation all stated at point of sale. | `UpgradeView.swift`; `Strings.swift` | Guideline 3.1.2 requires price, billing period, and full trial terms clearly at point of sale. Misleading trial scope is a rejection risk. |
| SB-9 | ◐ **CLIENT DONE / BACKEND PENDING** — Settings Delete Account flow + `AuthServiceProtocol.deleteAccount()`; edge-function source at `docs/backend/DELETE_ACCOUNT_EDGE_FUNCTION.md`. Left: deploy `delete-account`. | `SettingsView.swift` / `SettingsViewModel.swift` | Guideline 5.1.1(v) requires in-app account deletion for any app with account creation. Automatic rejection trigger. |
| SB-10 | ☐ **OPEN** — Raw `userId` shown as account identity. | `SettingsView.swift:134-139`; VM `:74-80` | Opaque Apple identifier is meaningless to users; poor information design on the account surface. |

### D. CookMode — broken core use case

| # | Blocker | Location | Why it blocks |
|---|---|---|---|
| SB-11 | **Screen never kept awake during cooking.** `isIdleTimerDisabled` is never set. *(verified: 0 occurrences in codebase)* | `CookModeView.swift` (no modifier) | A hands-free cooking screen dims and locks mid-recipe — exactly when the user can't touch the phone. Broken primary use case. |
| SB-12 | **Step text undersized (`.title2`) and non-scrollable.** Sits between two `Spacer()`s, no `ScrollView` (despite a comment claiming "scrollable card"). | `CookModeView.swift:24-27,108-120` | Long steps or large Dynamic Type clip/overflow with no scroll. Clipped cooking instructions = hard usability failure at arm's length. |
| SB-13 | **Hardcoded English `Text("minutes")`** that also mislabels an `M:SS` value. | `CookModeView.swift:147` | Bypasses String Catalog (won't localize) and is factually wrong (labels minutes:seconds as "minutes"). |

### E. Creation flows — data loss & dead ends

| # | Blocker | Location | Why it blocks |
|---|---|---|---|
| SB-14 | **No keyboard dismissal in the Create Recipe wizard.** No `@FocusState`, no keyboard toolbar, no `scrollDismissesKeyboard`; multiline step field's Return inserts a newline. Bottom CTA sits under the keyboard. | `CreateRecipeView.swift:8-35`; `CreateRecipeComponents.swift:51` | User can be unable to reach the primary CTA — a dead-end on the core creation flow. |
| SB-15 | **Save can duplicate / fails silently.** Save button ignores `isSaving` (double-tap → duplicate recipes), and `saveError` is never surfaced (no `.alert`). | `CreateRecipeView.swift:393-419`; VM `:84,207-223` | Data-integrity bug + silent data-loss risk on the most data-sensitive flow. (ShoppingList already has the correct alert pattern to copy.) |
| SB-16 | **Camera dead-ends.** (a) Permission re-grant from Settings never re-checked (`onAppear` only) → stuck on denied screen. (b) `setupCamera()` failure returns silently → permanent black screen with a no-op shutter. | `CameraView.swift:46-49,268-297`; `CameraViewModel.swift:72-86` | Strands the user on the app's primary value path with no recovery. |

> **Also borderline (HIGH→BLOCKER if reachable):** `RecipeDetailsAdditionalInfo` force-indexes a 4-element array after an early-return guard — index-out-of-range crash risk if the component is still on any code path. Confirm it's dead code and delete, or guard it. (`RecipeDetailsAdditionalInfo.swift:27-40`)

---

## 3. Cross-Cutting Themes (root causes)

Most findings collapse into five systemic patterns. Fixing these once resolves dozens of individual items.

1. **The font token layer doesn't scale (SB-1, SB-12).** Fix centrally in `UI.Fonts` by mapping tokens to semantic `Font.TextStyle`s (or `@ScaledMetric`), so all ~179 call sites inherit Dynamic Type unchanged. Then add `minimumScaleFactor`/wrapping to constrained labels (currently **0** uses of `minimumScaleFactor` app-wide) and sweep the 27 inline `.system(size:)` literals in Views into the token system.

2. **Contrast tokens are too light (SB-2/3/4).** `text3` is used as content, not decoration; Light `text2` fails on elevated surfaces; white-on-accent fails. Introduce an `onAccent` token, darken `text2`, reserve `text3` for true decoration, and add an **automated contrast unit test** asserting every (text, surface) pair ≥ 4.5:1.

3. **`.onTapGesture` used instead of `Button` (~10+ sites).** Mood/category/filter pills, recipe cards, emoji/difficulty/cook-time chips manually bolt on `.isButton` but lose press feedback, reliable VoiceOver/Switch Control/Full Keyboard activation, *and* future automatic glass button styling. Wrap in `Button { } label: { }.buttonStyle(.plain)`.
   - Discover: `DiscoverView.swift:396,716,762,775`; Journey: `JourneyView.swift:582,601`; Create: `CreateRecipeComponents.swift:24,98,126`.

4. **Color-only state cues.** Ingredient availability (mint/rose dots), "today" streak marker, selected chips, locked achievements rely on hue alone — fails HIG "don't rely on color alone" for color-blind/low-vision users. Pair with icon/shape/text.
   - `RecipeDetailsView.swift:200-236`; `JourneyComponents.swift:42-45`; `DiscoverView.swift` filter pills.

5. **Inconsistent state handling.** Loading/empty/error states are handled well in some places (ShoppingList error alert) and missing in others (Discover landing has no skeletons; Create has no error alert; Journey shows zeros indistinguishable from failure; `AsyncImageDisk` spins forever on failure). Standardize a loading/empty/error pattern and apply uniformly.

---

## 4. Findings by Screen

Severity legend: 🔴 blocker · 🟠 high · 🟡 medium · ⚪ low. Items already listed in §2 are referenced by ID.

### 4.1 Discover / Browse (home)
- 🔴 SB-1 instances: ingredient bubble label fixed 11pt + truncates (`DiscoverComponents.swift:66`); camera scan badge fixed size (`DiscoverView.swift:145`).
- 🔴 Hero best-match card has **no accessibility label/grouping** — the most prominent result is unnamed/unusable under VoiceOver. (`DiscoverView.swift:794-811`)
- 🔴 Match-info button: no label, sub-44pt, nested inside a tappable card. (`DiscoverView.swift:887-897`)
- 🔴 Pantry toggle: likely sub-44pt and adjacent-target ambiguity with the ingredient bubble. (`DiscoverComponents.swift:106-130`)
- 🟠 No loading/skeleton state on the landing screen — carousels pop in piecemeal; layout shift, "broken/empty" first impression. (`DiscoverView.swift:43-77`)
- 🟠 Empty state renders *between* always-present collections + grid, contradicting itself. (`DiscoverView.swift:61-65`)
- 🟠 Error banners passive, non-dismissible, reused as a stale toast for pantry errors; buried mid-scroll. (`DiscoverView.swift:232-247`)
- 🟠 Results screen stacks up to **8 filter sections above results**; loading indicator is below the fold — buries primary content. (`DiscoverView.swift:513-537`)
- 🟠 "Edit" affordance destructively clears all selections (label/action mismatch, no confirm); coexists with a "+" that preserves them. (`DiscoverView.swift:618-664`)
- 🟠 White hero text over arbitrary recipe photos — contrast not guaranteed. (`DiscoverView.swift:815-837`)
- 🟡 Carousels have no peek/scroll affordance; `noResultsState` offers no "Clear filters" recovery; `.popover` match-info unreliable on iPhone; greeting can go stale.
- ⚪ Hardcoded SF Symbols + raw `"cal"` string bypass `Icons.*`/`Strings.*` (`RecipeCardComponents.swift:179-254`); suggestion popup has no outside-tap-to-dismiss; magic `searchBarHeight = 47`; `RecipeListView` no empty state.
- 🟡 **RecipeRow palette overload** — up to 3 rows of multicolor capsules under one title; hierarchy collapses. (`RecipeCardComponents.swift:164-228`)

### 4.2 Recipe Details + CookMode
- 🔴 SB-11 (keep-awake), SB-12 (step text), SB-13 ("minutes").
- 🟠 **Timer completes silently** — no haptic/sound/visual; and `Timer.publish` pauses in background with no local-notification fallback. (`CookModeViewModel.swift:185-189`)
- 🟠 Primary Done/Finish button has no accessibility label and doesn't announce completed state; visually under-emphasized vs nav circles. (`CookModeView.swift:257-282`)
- 🟠 Progress ring only advances on the "Done" button, not arrow navigation → ring stays empty while stepping; completed state hidden from VoiceOver. (`CookModeViewModel.swift:109-129`)
- 🟠 SB-1 instances: recipe title (28pt), timer display (32pt), step counter, button labels all fixed. (`RecipeDetailsView.swift:105`, `CookModeView.swift:145`)
- 🟠 No loading/empty/zero-step guards — "Start Cooking" can launch a 0-step CookMode that strands the user. (`RecipeDetailsView.swift:16-50`; `CookModeViewModel.swift:64-66`)
- 🟠 Share button: empty no-op action while preparing, no spinner. (`RecipeDetailsView.swift:52-73`)
- 🟡 Stale comments describe a non-existent floating back button (contrast over hero unverified); sticky CTA overlap relies on fixed spacer (use `safeAreaInset`); feedback overlay not `.isModal`, no focus move; feedback stars sub-44pt; ingredient availability color-only; paused timer shows full duration / empty ring; no confirmation on closing mid-cook.
- ⚪ Dead components `RecipeDetailsList`/`RecipeDetailsAdditionalInfo` (delete or fix crash + fonts); progress dots fixed height; step+timer can't coexist on small screens without scroll.

### 4.3 Onboarding + Paywall (conversion funnels)
- 🔴 SB-6 (Restore), SB-7 (Terms/Privacy), SB-8 (disclosure).
- 🟠 SB-1 instances across both funnels (`UpgradeView.swift:82-209`, `OnboardingView.swift:96`, `OnboardingCameraPage.swift:72-231`).
- 🟠 **Camera permission requested with no priming screen** — system dialog fires the instant the camera page appears, before any value explanation; denial permanently degrades the core feature. (`OnboardingViewModel.swift:202-224`)
- 🟠 Detected-ingredients state auto-advances on a forced timer with no Continue/escape control. (`OnboardingCameraPage.swift:123-138`)
- 🟡 "Done" is odd labeling for paywall dismiss; annual plan lacks a per-month equivalent for comparison; raw `error.localizedDescription` shown during first-run scan; Skip is low-contrast and disappears during processing; two competing full-width CTAs dilute the promoted plan.
- ⚪ `FlowLayout` hardcodes 3-per-row and silently caps chips; funnels not yet glass; `.white` CTA foreground unverified vs accent contrast.
- ✅ Good: purchase flow ignores `userCancelled`; double-completion guarded; permission re-checked on foreground; page indicator has VoiceOver label; paywall is genuinely dismissible (no dark pattern).

### 4.4 Create Recipe + Camera + Shopping List
- 🔴 SB-14 (keyboard), SB-15 (save duplicate/silent fail), SB-16 (camera dead-ends).
- 🟠 SB-1 instances; CameraView **bypasses the design system wholesale** (raw `Color.white`/`.black`, literal radii/paddings, raw Auto Layout constants). (`CameraView.swift` throughout)
- 🟠 **Scan-limit messaging absent** — free tier's 5/week limit never shown; VM has no `CameraScanTracker` awareness; no limit-reached → paywall route. (`CameraView`/`CameraViewModel`)
- 🟠 No discard confirmation — X/swipe-dismiss destroys an in-progress recipe. (`CreateRecipeView.swift:41-46`)
- 🟠 No field-level validation messaging (disabled-button-only anti-pattern). (`CreateRecipeViewModel.swift:110-123`)
- 🟠 Multiple sub-44pt targets (step delete, ingredient minus, camera close 40×40). (`CreateRecipeComponents.swift:64-72`; `CameraView.swift:242-251`)
- 🟠 Ingredient rows iterated by `id: \.self` index → focus/identity bugs on delete (steps correctly use stable id). (`CreateRecipeView.swift:169`)
- 🟡 `NavigationView` deprecated (→ `NavigationStack`); ShoppingList loading state never shown; camera error auto-dismisses in fixed 2s with no retry/VoiceOver; decorative emoji lacks a11y label; servings/difficulty lack stepper/`.isSelected` semantics; low-contrast white-on-black secondary controls.
- ⚪ `.onTapGesture` chips; unused `cuisine` field; review step not tap-to-edit; no scroll-to-new-row/reorder.
- ✅ Good: ShoppingList is the model citizen — clean error alert, VoiceOver checkbox labels, swipe actions.

### 4.5 Journey + Settings + Navigation shell
- 🔴 SB-7 (Privacy/Terms/Support), SB-9 (account deletion), SB-10 (raw userId).
- 🔴 `AsyncImageDisk` has **no failure state** — failed loads show the loading spinner forever (status lie); no empty-name guard. (`AsyncImageDisk.swift:88-111`)
- 🔴 Tab images lack explicit VoiceOver labels (rely on `accessibilityIdentifier`, a test hook). (`TabContainerView.swift:29-43`) — *structurally close; needs explicit labels + verification.*
- 🟠 "Manage Subscription" opens a hardcoded App Store URL with an unresolved TODO instead of `AppStore.showManageSubscriptions(in:)`. *(verified)* (`SettingsViewModel.swift:14,255-261`)
- 🟠 No Acknowledgements/licenses screen (TelemetryDeck, Sentry, GRDB attributions). (`SettingsView.swift`)
- 🟠 `reloadDataOnAppear` re-runs 5 concurrent queries + achievement eval on **every** tab switch → flash + battery. (`JourneyView.swift:39-44`; VM `:186-212`)
- 🟠 SB-1 instances (icons/emoji fixed size). (`JourneyView.swift:112-449`)
- 🟠 Bulk clear of favorites is irreversible with generic confirmation, no undo/count. (`SettingsView.swift:302-319`)
- 🟠 Carousel cards use `.onTapGesture` not `Button` (createRecipeButton is correct — inconsistent). (`JourneyView.swift:582-608`)
- 🟠 Manual currency formatting (`"$\(amount)"`) ignores locale → "EUR 5". (`JourneyViewModel.swift:415-424`)
- 🟡 Journey shows zeros indistinguishable from load failure; some sub-loads swallow errors; theme-write fire-and-forget; "today" streak color-only; locked achievement contrast/emoji a11y; version row not copyable.
- ⚪ Weekday labels hardcoded/ambiguous (`["M","T","W","T","F","S","S"]`); `RelativeDateTimeFormatter` allocated per row; carousels lack paging affordance.
- ✅ **Good & important: the shell is a native `TabView`** — keep it; it gets iOS 26 Liquid Glass for free. Add a `selection` binding for deep-linking (currently impossible). Restore Purchases *is* correctly wired in Settings (but missing from the paywall — see SB-6).

### 4.6 Design system & accessibility (cross-cutting)
See §3. Additional: `.frostCard()`/`.neonGlow()` don't degrade under Reduce Transparency / Increase Contrast (🟠 `ViewModifiers.swift:9-55`); reduce-motion handled ad-hoc per-view (missing in Onboarding/Create) (🟡); no systematic VoiceOver convention beyond `AccessibilityID` (🟠); default app theme hardcoded to `DarkTheme` regardless of system scheme (🟡 `AppTheme.swift:199-201`); V1/legacy token duplication with divergent cross-theme semantics (🟡 `AppTheme.swift:78-89`).

---

## 5. Liquid Glass (iOS 26) Adoption

### 5.1 How today's "frost glass" relates to Liquid Glass
CookSavvy already ships a hand-rolled glass *aesthetic* that is a **competitor** to Apple's Liquid Glass, not a complement:
- **`.frostCard()` is fake glass** — it fills with an **opaque** `theme.card` plus a decorative gradient stroke. No backdrop sampling, blur, refraction, or specular response. (`ViewModifiers.swift:9`)
- **`.neonGlow()` is a brand signature** (two colored drop shadows), unrelated to Liquid Glass's lensing/highlights. (`ViewModifiers.swift:37`)
- The only *genuine* translucency is two `.ultraThinMaterial` overlays (Camera/Onboarding).

iOS 26 Liquid Glass (`.glassEffect(_:in:)`, `GlassEffectContainer`, `Glass` configs `.regular`/`.clear`/`.tint()`/`.interactive()`, `.glass`/`.glassProminent` button styles, automatic glass on native `TabView`/`NavigationStack`/toolbars/sheets, `glassEffectID` morphing) is a *dynamic, system-rendered* material. Implications:
- The frost card is the **redundant fake** on *floating* chrome — but content cards on the canvas (recipe rows, most of Journey) should **stay solid**. Adoption is **selective**: glass is for floating chrome (toolbars, FABs, tab bar, sheets, CTAs over imagery), not list-row content.
- The **neon glow is the brand** and Liquid Glass's neutral language threatens it. Defend it with `Glass.tint(theme.accent)` and by keeping neon on hero moments (primary CTA, achievement unlocks) while structural chrome goes neutral-glass.

### 5.2 Highest-ROI surfaces (ranked)
1. **Tab bar** — already native `TabView`; gets glass essentially for free on the iOS 26 SDK. (`TabContainerView.swift`)
2. **Sheets** (Shopping List, Camera, Upgrade) — native sheets adopt glass automatically.
3. **Floating controls** — CookMode prev/done/next cluster, Recipe Details floating back/bookmark: canonical `.glassEffect(.regular.interactive(), in: .circle)` use case.
4. **Primary CTAs** — "Find Dinner" / subscribe → `.buttonStyle(.glassProminent).tint(theme.accent)` (**after** fixing SB-4 contrast).
5. **Recipe card image overlays** — match badge, bookmark, meta pill over photography: glass beats today's opacity overlays.
6. **Search field** over the ingredient grid.

### 5.3 Migration mechanics
- **`.frostCard()` → `frostCard(style: .floating | .surface)`** adapter: `.floating` branches to `if #available(iOS 26,*) { .glassEffect(.regular.tint(theme.card), in: .rect(cornerRadius:)) } else { /* current frost */ }`; `.surface` keeps the solid fill. This same seam fixes Reduce Transparency (SB-adjacent 🟠).
- **`.neonGlow()` → selective:** glass for structural chrome, neon retained for brand moments. Do **not** blanket-replace.
- **`GlassEffectContainer`** wraps nearby glass clusters (CookMode controls; Details back+bookmark; Discover search+camera) so they blend instead of rendering separate blobs.
- **Native `TabView`:** ensure no custom `UITabBarAppearance` fights the system glass; verify `.tint(theme.accent)` still reads.
- **`glassEffectID`** for morphing the camera-scan and Discover ingredient→results transitions (coordinate with existing `reduceMotion`).

### 5.4 Risks
- **Contrast over glass** — with already-marginal `text2`/`text3`, text over glass can become unreadable. Must fix §2A first and honor `colorSchemeContrast`.
- **Performance** — backdrop sampling is GPU-costly; keep glass off scrolling list rows; older 17.6-era devices won't even get the effect.
- **All-or-nothing** — compiling against the iOS 26 SDK makes native `TabView`/sheets/toolbars glass *globally*; mixing with leftover custom frost looks inconsistent. Migrate surrounding chrome in the same release as the SDK bump.
- **Brand dilution** — Liquid Glass is intentionally neutral; defend warmth via `Glass.tint` + retained neon on hero CTAs.

### 5.5 Phased roadmap
- **Phase 0 — Prerequisites:** Resolve SB-5 (single deployment floor via `.xcconfig`). Fix contrast SB-2/3/4 and Dynamic Type SB-1. Add the contrast unit test. Build the environment seam so `.frostCard`/`.neonGlow` read `reduceTransparency`/`colorSchemeContrast`. *(Glass amplifies contrast bugs — do not ship glass over failing tokens.)*
- **Phase 1 — Quick wins (`#available`-gated):** native `TabView`/sheet glass (compile-time freebies); primary CTAs → `.glassProminent` with corrected foreground; replace the two `.ultraThinMaterial` overlays with `.glassEffect` (solid fallback).
- **Phase 2 — Structural:** ship the `frostCard(style:)` adapter; migrate floating chrome (Details back/bookmark, CookMode cluster, Discover search/camera) inside `GlassEffectContainer`; move recipe-card image overlays onto glass; finalize the neon-vs-glass policy.
- **Phase 3 — Polish:** `glassEffectID` morphing; per-surface `Glass.tint`/`.interactive()` tuning to defend the brand; full a11y re-pass over glass (legibility on photography, fallbacks, VoiceOver labels) + performance profiling on the lowest supported device. Consider raising the floor to 26 in a later release and retiring fallbacks.

---

## 6. Recommended Sequencing

1. **Compliance sprint (unblock submission):** SB-6, SB-7, SB-8, SB-9, SB-10 + Manage-Subscription API fix. Small, well-scoped, mostly additive.
2. **Accessibility sprint (largest user impact):** SB-1 (font tokens), SB-2/3/4 (contrast tokens + `onAccent` + contrast unit test), then `minimumScaleFactor`/wrapping pass.
3. **CookMode fix:** SB-11, SB-12, SB-13 + silent-timer/haptic. Cheap, high-impact for the core verb of the app.
4. **Creation flows hardening:** SB-14, SB-15, SB-16 (reuse ShoppingList's error pattern).
5. **Build hygiene:** SB-5 (single deployment target) — also Phase 0 for glass.
6. **Cross-cutting polish:** `.onTapGesture`→`Button`, color-only cues, state-handling standardization.
7. **Liquid Glass:** Phases 1–3 per §5.5, only after steps 2 and 5.

---

## 7. What's Working Well
- Cohesive, distinctive visual identity with a real token system (`AppTheme`, `UI.*`, `Strings`, `Icons`).
- **Native `TabView` shell** — correct for accessibility and free Liquid Glass.
- ShoppingList is a model for error/empty/VoiceOver handling — use it as the in-repo reference pattern.
- Paywall purchase flow handles `userCancelled` correctly and is genuinely dismissible (no dark pattern).
- Onboarding guards double-completion and re-checks permission on foreground.
- Restore Purchases is correctly wired in Settings (just missing from the paywall).

---

*Audit produced by six parallel specialist reviews; all ship-blocker claims (keep-awake, Restore Purchases, Terms/Privacy, account deletion, deployment targets, Manage-Subscription URL) verified directly against source. Contrast ratios are computed from the hex/opacity values in `AppTheme.swift` and should be confirmed with Xcode's Accessibility Inspector before finalizing token changes.*
