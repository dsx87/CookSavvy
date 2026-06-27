//
//  ThemeContrastTests.swift
//  CookSavvyTests
//
//  Automated WCAG AA (1.4.3) contrast guard for the theme color tokens (T-039).
//  Asserts that every load-bearing (text, surface) pairing renders at >= 4.5:1.
//  `text3` is intentionally excluded: it is a *decorative* token (placeholders,
//  de-emphasized chrome) and must not be used for meaningful text — see AppTheme.swift.
//

import XCTest
import SwiftUI
@testable import CookSavvy

final class ThemeContrastTests: XCTestCase {

    /// WCAG AA minimum contrast ratio for normal-size text.
    private let minimumRatio = 4.5

    // MARK: - WCAG color math

    /// sRGB components (0...1) plus alpha, resolved from a SwiftUI `Color` via `UIColor`.
    /// The theme tokens are programmatic `Color(red:green:blue:)` / `.white.opacity()`
    /// values, so the resolved components are exact (no asset-catalog indirection).
    @MainActor
    private func components(_ color: Color) -> (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }

    /// Alpha-composites a (possibly translucent) foreground over an opaque background.
    /// WCAG contrast is defined on what the eye actually sees, so a translucent token
    /// such as Dark `text2` (white @ 0.65) must be flattened onto its surface first.
    @MainActor
    private func composite(_ fg: Color, over bg: Color) -> (r: Double, g: Double, b: Double) {
        let f = components(fg)
        let b = components(bg)
        return (
            f.r * f.a + b.r * (1 - f.a),
            f.g * f.a + b.g * (1 - f.a),
            f.b * f.a + b.b * (1 - f.a)
        )
    }

    /// WCAG relative luminance of a (opaque) sRGB color.
    @MainActor
    private func relativeLuminance(_ c: (r: Double, g: Double, b: Double)) -> Double {
        func linearize(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(c.r) + 0.7152 * linearize(c.g) + 0.0722 * linearize(c.b)
    }

    /// WCAG contrast ratio (>= 1.0) between a foreground token and an opaque surface,
    /// compositing the foreground over the surface to account for any alpha.
    @MainActor
    private func contrastRatio(_ fg: Color, on surface: Color) -> Double {
        let s = components(surface)
        let fgLum = relativeLuminance(composite(fg, over: surface))
        let bgLum = relativeLuminance((s.r, s.g, s.b))
        let lighter = max(fgLum, bgLum)
        let darker = min(fgLum, bgLum)
        return (lighter + 0.05) / (darker + 0.05)
    }

    // MARK: - Assertions

    /// Surfaces a body-text token can legitimately sit on.
    @MainActor
    private func surfaces(_ theme: AppTheme) -> [(name: String, color: Color)] {
        [
            ("bg", theme.bg),
            ("surface", theme.surface),
            ("surfaceLight", theme.surfaceLight),
            ("card", theme.card)
        ]
    }

    /// Verifies every load-bearing text token clears AA on every surface, plus the
    /// CTA pairing of `onAccent` on `accent`.
    @MainActor
    private func assertContrast(for theme: AppTheme, named themeName: String) {
        let textTokens: [(name: String, color: Color)] = [
            ("text1", theme.text1),
            ("text2", theme.text2)
        ]

        for token in textTokens {
            for surface in surfaces(theme) {
                let ratio = contrastRatio(token.color, on: surface.color)
                XCTAssertGreaterThanOrEqual(
                    ratio, minimumRatio,
                    "\(themeName): \(token.name) on \(surface.name) is \(String(format: "%.2f", ratio)):1 (needs \(minimumRatio):1)"
                )
            }
        }

        // Primary CTA foreground (`onAccent`) sits on the accent fill ("Find Dinner",
        // subscribe) and on accent-paired gradients used by other CTAs ([accent, rose]
        // for Start Cooking / step badges / save; [accent, sky] for subscribe). It must
        // clear AA against every stop those gradients can render.
        let ctaFills: [(name: String, color: Color)] = [
            ("accent", theme.accent),
            ("rose", theme.rose),
            ("sky", theme.sky)
        ]
        for fill in ctaFills {
            let ratio = contrastRatio(theme.onAccent, on: fill.color)
            XCTAssertGreaterThanOrEqual(
                ratio, minimumRatio,
                "\(themeName): onAccent on \(fill.name) is \(String(format: "%.2f", ratio)):1 (needs \(minimumRatio):1)"
            )
        }
    }

    // MARK: - Tests

    @MainActor
    func testLightThemeMeetsAAContrast() async {
        assertContrast(for: LightTheme(), named: "LightTheme")
    }

    @MainActor
    func testDarkThemeMeetsAAContrast() async {
        assertContrast(for: DarkTheme(), named: "DarkTheme")
    }
}
