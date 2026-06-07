//
//  LegalLinks.swift
//  CookSavvy
//

import Foundation

/// Canonical URLs for the app's legal documents, surfaced on the paywall and in Settings to satisfy
/// App Store requirements (Guideline 3.1.2 — point-of-sale Terms/Privacy links).
///
/// These are placeholders pending the hosted pages. Replace them with the live URLs before
/// submission; the standard EULA + Privacy Policy content lives under `docs/legal/`.
enum LegalLinks {
    static let privacyPolicy = URL(string: "https://cooksavvy.app/privacy")
    static let termsOfUse = URL(string: "https://cooksavvy.app/terms")
}
