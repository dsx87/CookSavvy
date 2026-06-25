//
//  LegalLinks.swift
//  CookSavvy
//

import Foundation

/// Canonical URLs for the app's legal documents, surfaced on the paywall and in Settings to satisfy
/// App Store requirements (Guideline 3.1.2 — point-of-sale Terms/Privacy links).
///
/// These point at the live hosted pages (GitHub Pages, served from the `CookSavvySite` repo). The
/// source content also lives under `docs/legal/` in this repo.
enum LegalLinks {
    static let privacyPolicy = URL(string: "https://dsx87.github.io/CookSavvySite/privacy.html")
    static let termsOfUse = URL(string: "https://dsx87.github.io/CookSavvySite/terms.html")
}
