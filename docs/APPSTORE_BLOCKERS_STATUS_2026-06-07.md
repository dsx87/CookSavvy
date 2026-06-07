# App Store Blockers — Remediation Status

**Date:** 2026-06-07
**Scope:** Consolidated tracker for the release-gating blockers from the three 2026-06-06 audits
(`AUDIT_2026-06-06.md` = engineering, `PRODUCT_AUDIT_2026-06-06.md` = product, `UX_UI_AUDIT_2026-06-06.md` = UX/UI).
**Source of truth:** this file. The individual audits carry inline status markers pointing here.

> **Legend:** ✅ Done (in this iOS repo) · ◐ Code-complete, external step left · ⛔ Not started / out-of-repo.

---

## Summary

| # | Blocker | Audit ref | Status |
|---|---------|-----------|--------|
| 1 | App-launch crash — `ImageService` force-unwrap | AUDIT SB-1 / PROD SB-5 | ✅ Done |
| 2 | Auth errors logged verbatim → Sentry | AUDIT SB-2 | ✅ Done |
| 3 | Missing App Privacy Manifest | PROD SB-1 | ✅ Done |
| 4 | Restore Purchases on paywall | UX SB-6 | ✅ Done |
| 5 | Subscription disclosure copy | UX SB-8 | ✅ Done |
| 6 | Build number static at 1 | AUDIT (low) | ✅ Done |
| 7 | Terms + Privacy links | PROD SB-2 / UX SB-7 | ◐ Code done / hosting pending |
| 8 | In-app Account Deletion | PROD SB-3 / UX SB-9 | ◐ Client done / backend pending |
| 9 | App icon image | PROD SB-4 | ⛔ Owner-provided asset |
| 10 | Server-side scan quota | AUDIT SB-3 / PROD SB-6 | ⛔ Backend / business decision |

**Verification:** `xcodebuild … build` succeeds; `UnitTests` plan passes (314 tests, incl. 4 new); `PrivacyInfo.xcprivacy` confirmed bundled at the app root and valid plist.

---

## Done (this iOS repo)

### 1. ImageService launch crash (AUDIT SB-1 / PROD SB-5)
`ImageService.init` is now `throws`; the documents-dir lookup uses `guard let … else { throw ImageServiceError.documentsDirectoryUnavailable }`. `AppContainer` calls `try ImageService()`, so a missing directory surfaces through the existing blocking `StartupErrorView` instead of an uncatchable crash. 23 test call sites updated.
- Files: `Services/Image/ImageService.swift`, `App/AppContainer.swift`, `CookSavvyTests/ImageServiceTests.swift`.

### 2. Auth error logging (AUDIT SB-2)
All raw-error log sites now log `type(of: error)` rather than the raw Supabase error, so no JWT/nonce/identity-token payload reaches the `LoggingService` crash sink (Sentry in RELEASE). Also closes an org-policy violation.
- Files: `Services/Auth/SupabaseAuthService.swift` (113, 128, 158, 170), `Services/Auth/SignInWithAppleAction.swift` (125).

### 3. App Privacy Manifest (PROD SB-1)
New `Support/PrivacyInfo.xcprivacy`: `NSPrivacyTracking=false`, no tracking domains, required-reason `UserDefaults (CA92.1)`, collected-data types for photos/crash/analytics (all not-linked, not-tracking). Auto-bundled via the Xcode 16 synchronized group.
- File: `Support/PrivacyInfo.xcprivacy`. ⚠️ Reconcile with the App Store Connect privacy nutrition label.

### 4. Restore Purchases on paywall (UX SB-6)
`UpgradeViewModel.restorePurchases()` + a "Restore Purchases" button and restore-error alert on `UpgradeView`.
- Files: `Views/Upgrade/UpgradeViewModel.swift`, `Views/Upgrade/UpgradeView.swift`. Tests added.

### 5. Subscription disclosure copy (UX SB-8)
`Strings.Upgrade.autoRenew` now states: trial applies to **monthly only**, billing period, auto-renewal at displayed price, and cancellation terms — at the point of sale.

### 6. Build number bump
`CURRENT_PROJECT_VERSION` 1 → 2 across all configs (`MARKETING_VERSION` stays 1.0). Increment per upload going forward.

---

## Code-complete — external step remaining

### 7. Terms of Use + Privacy Policy links (PROD SB-2 / UX SB-7) — ◐ HOSTING PENDING
Links wired on the paywall (point of sale) and in a Settings "Legal" section via `Utilities/LegalLinks.swift`. Standard documents authored at `docs/legal/PRIVACY_POLICY.md` and `docs/legal/TERMS_OF_USE.md`.
- **Left:** host the two pages and replace the placeholder URLs in `LegalLinks.swift` (`https://cooksavvy.app/privacy`, `/terms`). Apple's standard EULA is an acceptable Terms target.

### 8. In-app Account Deletion (PROD SB-3 / UX SB-9) — ◐ BACKEND PENDING
`AuthServiceProtocol.deleteAccount()` (+ Supabase/Mock/NoOp impls); Settings flow with two-step confirmation, `accountDeleted` analytics event, local-data clear, and anonymous re-session. Server-side deletion source delivered at `docs/backend/DELETE_ACCOUNT_EDGE_FUNCTION.md`.
- **Left:** deploy the `delete-account` Supabase edge function (uses the service-role key, server-side only). Until deployed, the in-app action fails gracefully with `Strings.Settings.deleteAccountFailed`.

---

## Not started (out of this iOS repo / decisions)

### 9. App icon image (PROD SB-4) — ⛔ OWNER ASSET
`AppIcon.appiconset/Contents.json` is correctly configured for a 1024² universal icon with dark/tinted variants, but no PNG is present. Guaranteed rejection until a marketing icon is added. Owner-provided per scope decision.

### 10. Server-side camera-scan quota (AUDIT SB-3 / PROD SB-6) — ⛔ BACKEND + DECISION
The 5-scans/week free limit is client-only (`CameraScanTracker`, UserDefaults) with no enforcement in the `detect-ingredients` edge function. Needs a per-user/week rate table server-side. Pending a business decision (gate release vs. ship-and-fix).

---

## Pre-submission checklist (remaining)
- [ ] Add the 1024² app icon PNG (#9).
- [ ] Host Privacy Policy + Terms; update `LegalLinks.swift` URLs (#7).
- [ ] Deploy the `delete-account` edge function (#8).
- [ ] Decide on / implement server-side scan quota (#10).
- [ ] Camera-screen photo-upload disclosure line + cover in Privacy Policy (PROD finding E).
- [ ] Fill placeholder fields in `docs/legal/*` (company name, contact, jurisdiction).
- [ ] Confirm App Store Connect privacy nutrition label matches `PrivacyInfo.xcprivacy`.
