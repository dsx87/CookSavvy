# CookSavvy — Senior Product Manager Audit

**Date:** 2026-06-06
**Author lens:** Senior Product Manager (launch-readiness, monetization, growth, compliance)
**Scope:** Whole app, product perspective — activation, monetization funnel, App Store readiness, privacy/legal, core-loop UX, retention, accessibility/localization.
**Method:** 8 parallel domain subagents (onboarding, monetization, store-readiness, privacy/legal, core-loop UX, retention, a11y/localization, product-doc review). Every **ship blocker** below was hand-verified against source — see *Verification* notes. Severities for high/medium are agent-reported leads.

> **Companion document:** `docs/AUDIT_2026-06-06.md` is today's **engineering** audit (crashes, data integrity, test gaps). This is the **product** audit. Where they overlap I cross-reference rather than repeat; a few items are blockers in *both* lenses.

---

## TL;DR — Verdict

**Not ready to submit.** The product itself is feature-complete and well-built — 28+ shipped features, a sharp value prop ("snap your fridge → confident dinner in 30 seconds"), a clean 2-tier model. But it will be **rejected by App Store Review on day one** for four mandatory-compliance gaps, and it ships with **zero re-engagement surface** (no notifications, no rating prompt), which caps retention from launch.

- **6 ship blockers** — 4 are guaranteed App Store rejections, 1 is a startup-crash risk (shared with eng audit), 1 is a revenue-integrity hole.
- **The product is ~2–3 weeks of focused work from submittable** — the blockers are compliance/infra, not redesigns.
- **Biggest *product* (non-blocking) risk:** the core recommendation/match quality relies on naive substring matching, and there is no pantry memory — the two things most likely to make the core loop feel "dumb" and drive early churn.

---

## Ship Blockers

These gate release. The first four are not opinions — they are documented Apple requirements with near-100% rejection rates.

### SB-1 — No App Privacy Manifest (`PrivacyInfo.xcprivacy`) `[store-rejection]`
**Verification:** `find . -name "*.xcprivacy"` → **none.**
Required by Apple since iOS 17.1 for any app, and *specifically* required because CookSavvy uses APIs/SDKs in Apple's "required reason" list and bundles third-party SDKs (Supabase, TelemetryDeck, Sentry). Missing manifest = automated rejection.
**Before release:** Add `PrivacyInfo.xcprivacy` declaring: data types collected (camera images, identifiers, usage data, crash data), required-reason API usage (UserDefaults/file timestamps), and the three third-party SDK declarations. Confirm each SDK's own bundled manifest is present via SPM.

### SB-2 — No Terms of Use + Privacy Policy links on the paywall `[store-rejection — Guideline 3.1.2]`
**Verification:** `grep -rin "privacy\|terms\|eula" CookSavvy/Views/Upgrade/` → **none**; not present in `Strings.swift` either. Paywall shows only the auto-renew sentence.
Apple **requires** auto-renewable-subscription apps to display functional links to Terms (EULA) and Privacy Policy on/adjacent to the paywall. This is one of the most common rejection reasons for subscription apps.
**Before release:** Author + host a Privacy Policy and Terms (the standard Apple EULA is acceptable). Add tappable links on `UpgradeView` and in Settings. **This blocker also blocks SB-4 below and several privacy findings — it is the long pole.**

### SB-3 — No in-app Account Deletion `[store-rejection — Guideline 5.1.1(v)]`
**Verification:** `grep -rin "deleteAccount" CookSavvy/Views/Settings CookSavvy/Services/Auth` → **none.** Settings offers Sign Out only; the app creates Supabase accounts (anonymous + Sign in with Apple).
Any app that lets users create an account must offer in-app account+data deletion. Sign-out ≠ deletion.
**Before release:** Add a "Delete Account" flow in Settings that deletes the Supabase user and associated server data (and local DB), with confirmation. Requires a backend deletion endpoint.

### SB-4 — App ships with no app icon image `[store-rejection / build artifact]`
**Verification:** `AppIcon.appiconset/` contains only `Contents.json` — **no PNG/asset files.**
A missing app icon fails submission (and ships a blank home-screen icon). Easy to miss because the project still builds.
**Before release:** Add the 1024×1024 marketing icon (and light/dark/tinted variants the catalog declares).

### SB-5 — App-launch crash risk: force-unwrap of documents directory `[crash]` *(shared with eng audit SB-1)*
**Verification:** `ImageService.swift:123` — `fileManager.urls(...).first!` in a **non-throwing** `init` run during `AppContainer` startup. A nil bypasses the app's blocking-startup-error handling and crashes on launch.
**Before release:** `guard let … else { throw }` so the existing throwing container surfaces it as the startup error screen. Trivial fix; high consequence.

### SB-6 — Free-tier camera-scan quota is client-only (bypassable) `[revenue integrity]` *(shared with eng audit SB-3)*
**Verification:** quota lives in `UserDefaults` (`CameraScanTracker`); no server-side enforcement in the `detect-ingredients` edge function. Documented as known debt in `docs/BACKEND_PLAN.md`.
For a paid app, the core free→premium gate (5 AI scans/week) can be reset by deleting app data. This is the monetization wall and it leaks.
**Decision needed:** ship-and-fix-fast vs. gate release. As PM I'd **gate** — a paywall you can trivially bypass undercuts the entire subscription. Enforce server-side (per-user/week rate table).

> **Severity calls I overrode from the subagents:** the hardcoded `"minutes"` string (CookModeView:147) was flagged "BLOCKER" — it is `.accessibilityHidden(true)` cosmetic text; **downgraded to Low.** "English-only localization" was flagged "BLOCKER" — English-only is a perfectly valid v1 launch; **downgraded to a post-launch growth lever.** The Manage-Subscription URL is the correct generic Apple endpoint; the `// TODO: check the link` is cosmetic, **not a blocker.**

---

## Priority Findings (non-blocking, ranked by impact)

### A. Retention is structurally capped at launch — **HIGH**
The app has a *good* engagement foundation (10 achievements, streak calc, recommendations, share cards, Journey stats) but **no way to bring users back.**
- **No push/local notifications anywhere** (`grep UNUserNotificationCenter` → none). No streak-break nudge, no "dinner o'clock" reminder, no achievement celebration. For a habit app this is the single biggest retention miss.
- **No App Store rating prompt** (`requestReview` → none) — leaving organic ASO/ratings entirely on the table at the exact moments of delight (first cook, achievement unlock).
- **Streak is computed but never shown** as a card (`UserDataService` calculates `dayStreak`; Journey only surfaces it inside one achievement). Highest-ROI motivator, hidden.
- No widgets / App Intents / Siri — no home-screen re-entry point.
**Recommendation:** Notifications + a visible streak pill + a well-timed rating prompt are the three highest-leverage pre/at-launch additions. Notifications need the permission priming added in onboarding (see C).

### B. Monetization funnel leaves conversions on the table — **HIGH**
The plumbing (StoreKit 2, trial, annual "best value") is solid, but the *selling* is thin:
- **No upsell at the onboarding camera "win."** The single highest-intent moment (user just watched the camera detect their ingredients) hands straight off to Discover with no "unlimited scans with CookSavvy+" beat.
- **Silent downgrade for free users.** When premium sources (online/AI recipes) are filtered out, the user just sees fewer results with no "unlock more recipes" callout — the desire-creating moment is invisible.
- **Quota framing is weak.** The "5 scans" badge never says "Premium: unlimited"; the paywall only appears at 0/5. Free users with scans left have no reason to know premium exists.
- **Premium features aren't teased before they're hit.** Shopping list only reveals itself on tap; no locked-state teaser. No restore-success confirmation.
**Recommendation:** Add an onboarding-success upsell, a "limited results / unlock online recipes" callout, and reframe the scan badge. These are copy/placement changes, low effort, direct conversion impact.

### C. First-run activation has gaps — **HIGH/MEDIUM**
- **No permission priming.** Notifications never requested (ties to A); camera permission jumps straight to the system dialog with no "why" pre-prompt (lower grant rates).
- **No premium value framing in onboarding** — users exit with no idea what CookSavvy+ is.
- **Cold-start empty state doesn't guide.** A user who skips the camera lands on an ingredient grid with no suggested starter ingredients and can leave without ever seeing a recipe (no "aha" moment guaranteed).
- **Sign-in / backup value buried** below the fold in Journey — new users don't learn their data is device-only until deep scroll.
**Recommendation:** Add a soft notification prime + camera "why" pre-prompt, 3–5 suggested starter ingredients on the empty state, and a one-line premium teaser at onboarding end.

### D. Core-loop quality risks feeling "dumb" — **HIGH (product trust)**
This is the deepest *product* risk even though none of it blocks submission:
- **Match logic is bidirectional substring matching** (`OfflineRecipeSource`, `RecipeMatchExplainer`): "pepper" matches "bell pepper", "egg" matches "eggplant". Inflated match %, eroded trust in the headline "find recipes with what you have."
- **No pantry memory** — users re-enter staples (salt, oil, garlic) every session; the loop feels disposable. (Flagged as the top retention lever in the existing product strategy, still unbuilt.)
- **Smart Search (NL parsing) is hard-gated to iOS 26+**; the Supabase fallback exists in code but is unwired, so most users get grid-search only.
- **No-match and AI-failure states are generic** — no inline "remove an ingredient / retry" affordance; AI-source timeouts surface as a vague "some sources couldn't be reached."
- **No source provenance** shown on cards (AI vs curated vs local) — a trust lever for AI-generated results.
**Recommendation:** Treat match-quality + pantry memory as the #1 post-launch product investment; add inline refine actions on the no-match state now (cheap, high-frequency).

### E. Privacy/consent posture is thin (beyond the store blockers) — **MEDIUM**
- **Analytics + crash reporting start with no consent** (TelemetryDeck/Sentry bootstrapped at launch; no opt-out in Settings). For EU/UK users GDPR expects consent for non-essential analytics. No ATT prompt.
- **User photos are uploaded to the backend for AI detection with no in-app disclosure** — needs a one-line "photos are processed by our AI service" notice on the camera screen + coverage in the Privacy Policy (SB-2).
- **Auth errors are logged verbatim and can reach Sentry** (eng audit SB-2) — can carry tokens; also an org-policy issue.
**Recommendation:** Add an analytics opt-out in Settings, a camera-privacy line, and scrub raw-error logging before enabling Sentry in production.

### F. Accessibility good, localization English-only — **MEDIUM/LOW**
- Accessibility is genuinely strong (broad VoiceOver labels, full dark mode, AAA contrast, correct traits). Two real gaps: **Dynamic Type is only ~30% adopted** (many fixed `.system(size:)` fonts don't scale) and **recipe images lack accessibility labels.**
- **Localization:** infrastructure is excellent (343 strings centralized in the catalog) but **English only.** Fine for v1; it's a market-expansion lever, not a blocker. One stray hardcoded word (`"minutes"`, cosmetic).

### G. Platform reach — **LOW/INFO**
Deployment targets are mixed across targets (17.6 / 18.0 / 18.6). A high floor (iOS 18+) materially shrinks the addressable base; confirm it's intentional and reconcile the test target to match the app target.

---

## Pre-Release Checklist (gate to submission)

> **Remediation status (2026-06-07):** code-side blockers closed; see `docs/APPSTORE_BLOCKERS_STATUS_2026-06-07.md` for the consolidated tracker. Summary inline below.

**Must-do (blockers):**
1. ☑ Add `PrivacyInfo.xcprivacy` + verify SDK manifests (SB-1) — **DONE** (`Support/PrivacyInfo.xcprivacy`, verified bundled at app root + valid plist).
2. ◐ Host + link Privacy Policy and Terms on paywall & Settings (SB-2) — **CODE DONE / HOSTING PENDING.** Links wired on paywall + Settings via `Utilities/LegalLinks.swift` (placeholder URLs); standard docs authored at `docs/legal/`. Left: host the pages and swap in real URLs.
3. ◐ Implement in-app Account Deletion (client + backend) (SB-3) — **CLIENT DONE / BACKEND PENDING.** Settings delete flow + `AuthServiceProtocol.deleteAccount()` calling `delete-account`; edge-function source at `docs/backend/DELETE_ACCOUNT_EDGE_FUNCTION.md`. Left: deploy the edge function.
4. ☐ Add app icon assets (SB-4) — **LEFT** (owner-provided PNG; slot/`Contents.json` already correct).
5. ☑ Fix `ImageService` force-unwrap → throw (SB-5) — **DONE** (throwing init + guard; surfaces via startup error screen).
6. ☐ **Decision:** server-enforce scan quota, or sign-off to accept the leak short-term (SB-6) — **OPEN** (backend; business decision).

**Strongly recommended before launch (cheap, high-impact):**
7. ☐ Local notifications + onboarding permission prime (retention)
8. ☐ Visible streak pill on Journey (retention)
9. ☐ Rating prompt after first cook / first achievement (ASO)
10. ☐ Onboarding-success upsell + "unlock online recipes" callout + scan-badge reframe (conversion)
11. ☐ Suggested starter ingredients on empty state (activation)
12. ☐ Analytics opt-out in Settings + camera-privacy disclosure line (privacy)
13. ☐ Camera "why" pre-prompt (permission grant rate)
14. ☐ Confirm App Store Connect metadata: subscription disclosures, screenshots, age rating, privacy "nutrition label" matches the manifest

**App Store Connect / ops:**
15. ☐ Sandbox-test purchase, restore, trial, and (importantly) Ask-to-Buy / pending-purchase paths
16. ☐ Verify the Manage-Subscription link end-to-end; remove the TODO
17. ☐ Reconcile deployment targets; confirm minimum-iOS decision

---

## Post-Release Roadmap (first 1–3 sprints)

**Sprint 1 — trust & integrity**
- Replace substring matching with token/synonym-aware matching (core trust) — *Finding D*
- Server-side scan quota if deferred from launch (SB-6)
- Inline refine actions on no-match; clearer AI-failure messaging — *Finding D*
- Scrub raw auth-error logging (eng SB-2)

**Sprint 2 — retention depth**
- **Pantry memory** (top strategy lever) — *Finding D*
- Weekly personalized digest notification; streak-break nudge — *Finding A*
- Soft-gate "try N free then upgrade" on shopping list — *Finding B*

**Sprint 3 — reach & growth**
- Home-screen widget (suggested recipe + streak) — *Finding A*
- Dynamic Type pass + recipe-image a11y labels — *Finding F*
- Dataset quality audit (de-dupe / remove low-quality entries) — *flagged in product strategy*
- Localization to 2–3 priority languages (infra is ready) — *Finding F*

**Continuously**
- Instrument the funnel: onboarding exit-path, first-search rate, scan→result, free→trial→paid, D1/D7/D30, streak-build rate. (Several events exist; add exit-path and activation-stage properties.)

---

## Appendix — What's genuinely strong (don't regress)

- Clear, defensible value prop and target user (weeknight deciders; anti-waste framing carried through copy).
- Correct 2-tier model with a smart activation hook (5 free scans/week).
- Feature-complete: camera detection, offline/online/AI sources, cook mode, shopping list, achievements, recommendations, sharing, create-recipe, theming.
- Solid accessibility and a clean MVVM+Coordinator architecture (per eng audit).
- Strategy is well-documented (`prod/2026-03-30/`) and the build tracks it — no hidden surprises.

---

### Methodology note
Findings synthesized from 8 read-only subagent audits. The 6 ship blockers were individually re-verified against source (`find`/`grep`/file reads) on 2026-06-06; commands and results are quoted inline under each. High/medium findings are credible leads triangulated across agents but were not all independently re-verified — treat them as prioritized work, not proven defects. Subagent severity inflation (3 items) was corrected and noted.
