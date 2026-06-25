# CookSavvy Privacy Policy

**Last updated:** 2026-06-24
**Published at:** https://dsx87.github.io/CookSavvySite/privacy.html (referenced by `LegalLinks.privacyPolicy`).

> This is a standard, app-specific privacy policy drafted to satisfy App Store Review Guideline 5.1.1
> and to back the in-app Privacy Policy link. Have it reviewed by counsel before publishing. It must be
> hosted at the URL referenced by `LegalLinks.privacyPolicy` and match the App Store Connect privacy
> "nutrition label" and the app's `PrivacyInfo.xcprivacy` manifest.

## Who we are

CookSavvy ("the app", "we", "us") is operated by Igor Pivnyk. Questions about this policy:
consul87@gmail.com.

## Summary

- We do **not** track you across apps or websites and do **not** sell your data.
- The app works anonymously by default; signing in with Apple is optional.
- Photos you scan are sent to our backend solely to detect ingredients, then discarded.
- We use privacy-preserving analytics and crash reporting to improve the app.

## Information we collect

### Account information
- **Anonymous identifier.** On first launch we create an anonymous account (via Supabase) so the app
  can reach its backend. This is a random identifier, not tied to your personal identity.
- **Sign in with Apple (optional).** If you choose to sign in, Apple provides a stable user identifier
  that links your anonymous data to a persistent account. We do not receive your Apple password. We
  only request the minimum identifier needed to maintain your account.

### Photos you scan
- When you use camera ingredient detection, the captured image is sent to our backend AI service to
  identify ingredients. Images are processed transiently for that request and are not used to build a
  profile of you or for advertising. (Camera access is governed by the system permission prompt.)

### Search queries (Smart Search)
- Smart Search lets you type a natural-language request (e.g. "quick vegetarian pasta"). On devices
  that support on-device AI (Apple Intelligence), this text is processed **entirely on your device**
  and never leaves it. On devices without on-device AI, the text is sent to our backend, which uses a
  third-party AI provider (DeepSeek) to interpret it. The query is processed transiently for that
  request, is not linked to your identity, and is not used for advertising or to build a profile.

### Usage and diagnostics
- **Analytics (TelemetryDeck).** Aggregate, privacy-preserving product-interaction events (e.g.
  "recipe viewed") to understand feature usage. No IDFA, no cross-app tracking.
- **Crash reports (Sentry).** Diagnostic data when the app crashes or logs an error, used to fix bugs.
  We log error *types*, not raw error payloads, to avoid capturing sensitive data.

### Subscriptions
- Purchases are handled by Apple via StoreKit. We receive entitlement status (e.g. active/trial), not
  your payment details.

## How we use information
- Provide and operate the app's features (ingredient detection, recipes, subscriptions).
- Maintain your account and restore purchases.
- Improve reliability and usability through aggregate analytics and crash diagnostics.

## Data sharing
We share data only with processors that help us run the app: Apple (sign-in, payments), Supabase
(backend/auth), TelemetryDeck (analytics), Sentry (crash reporting), and — only for Smart Search on
devices without on-device AI — DeepSeek (natural-language query interpretation). We do not sell
personal data and do not use it for cross-app tracking.

## Data retention and deletion
- You can delete your account at any time in **Settings → Delete Account**. This permanently deletes
  your server-side account and associated data and removes your personal data stored on the device.
- Anonymous sessions and transient photo data are retained only as long as needed to provide the
  feature requested.

## Your rights
Depending on your region, you may have rights to access, correct, or delete your data. Contact
consul87@gmail.com or use in-app account deletion.

## Children
CookSavvy is not directed to children under 13 (or the equivalent minimum age in your region).

## Changes
We may update this policy; material changes will be reflected by the "Last updated" date.

## Contact
Igor Pivnyk — consul87@gmail.com.
