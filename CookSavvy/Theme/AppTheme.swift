import SwiftUI

/// Defines the visual style contract for the CookSavvy theme system.
///
/// Views access the active theme via `@Environment(\.appTheme)` and should use semantic
/// tokens (e.g. `theme.accent`, `theme.text1`) instead of hard-coded colors, ensuring
/// the entire app re-skins correctly when the light or dark theme is applied.
///
/// Add a new theme by creating a struct that conforms to `AppTheme` and injecting it
/// at the app root via `.environment(\.appTheme, MyTheme())`.
protocol AppTheme {
    // MARK: - V2 Color Tokens

    /// The main background color of the app canvas.
    var bg: Color { get }
    /// A slightly elevated surface color, used for cards and secondary containers.
    var surface: Color { get }
    /// A lighter variant of `surface` for subtle inner layering.
    var surfaceLight: Color { get }
    /// The card background color — typically the lightest surface shade.
    var card: Color { get }
    /// The primary accent color (orange-amber), used for CTAs and interactive highlights.
    var accent: Color { get }
    /// A low-opacity tint of `accent`, used for soft accent backgrounds on chips and badges.
    var accentSoft: Color { get }
    /// A teal/mint complementary color, used for positive states and secondary highlights.
    var mint: Color { get }
    /// A low-opacity tint of `mint`.
    var mintSoft: Color { get }
    /// A rose/pink color, used for favorite indicators and cautionary states.
    var rose: Color { get }
    /// A low-opacity tint of `rose`.
    var roseSoft: Color { get }
    /// A lavender/violet color, used for premium indicators and decorative elements.
    var lavender: Color { get }
    /// A low-opacity tint of `lavender`.
    var lavenderSoft: Color { get }
    /// A sky-blue color, used for informational badges and stats.
    var sky: Color { get }
    /// A low-opacity tint of `sky`.
    var skySoft: Color { get }
    /// A golden-yellow color, used for star ratings and achievement badges.
    var gold: Color { get }
    /// The primary text color — highest contrast against the background.
    var text1: Color { get }
    /// The secondary text color for supporting labels and metadata.
    var text2: Color { get }
    /// The tertiary text color for placeholders and de-emphasized content.
    var text3: Color { get }
    /// A subtle hairline divider color.
    var divider: Color { get }

    // MARK: - Modifier Style Tokens

    /// The top-edge stroke color for the `FrostCardModifier` gradient border.
    var frostStrokeTop: Color { get }
    /// The bottom-edge stroke color for the `FrostCardModifier` gradient border.
    var frostStrokeBottom: Color { get }
    /// The font used by `SectionLabelModifier`.
    var sectionLabelFont: Font { get }
    /// A multiplier applied to shadow opacities in `NeonGlowModifier`. Dark themes use
    /// a lower value (0.5) to prevent shadows from appearing too heavy on dark surfaces.
    var shadowStrength: Double { get }

    // MARK: - Corner Radius Tokens

    /// Small corner radius (12 pt).
    var cornerRadiusSmall: CGFloat { get }
    /// Medium corner radius (16 pt).
    var cornerRadiusMedium: CGFloat { get }
    /// Large corner radius (20 pt).
    var cornerRadiusLarge: CGFloat { get }
    /// Extra-large corner radius (24 pt).
    var cornerRadiusXL: CGFloat { get }
    /// Pill-shaped corner radius (32 pt), producing fully-rounded ends for standard button heights.
    var cornerRadiusPill: CGFloat { get }

    // MARK: - Legacy Tokens (V1 compatibility)

    /// Legacy V1 border accent color.
    var borderAccent: Color { get }
    /// Legacy V1 primary background color.
    var backgroundPrimary: Color { get }
    /// Legacy V1 secondary background color.
    var backgroundSecondary: Color { get }
    /// Legacy V1 primary button color.
    var buttonPrimary: Color { get }
    /// Legacy V1 subtle background color.
    var backgroundSubtle: Color { get }
}

/// Default implementations for corner-radius and modifier-style tokens shared by all themes.
extension AppTheme {
    var cornerRadiusSmall: CGFloat { 12 }
    var cornerRadiusMedium: CGFloat { 16 }
    var cornerRadiusLarge: CGFloat { 20 }
    var cornerRadiusXL: CGFloat { 24 }
    var cornerRadiusPill: CGFloat { 32 }
    var sectionLabelFont: Font { .system(size: 11, weight: .bold, design: .rounded) }
    var shadowStrength: Double { 1.0 }
}

/// The warm parchment-toned light theme with burnt-orange accent colors.
struct LightTheme: AppTheme {
    var frostStrokeTop: Color { Color.white.opacity(0.82) }
    var frostStrokeBottom: Color { Color(red: 0x1F/255, green: 0x1A/255, blue: 0x17/255).opacity(0.06) }

    var bg: Color { Color(red: 0xF7/255, green: 0xF2/255, blue: 0xEC/255) }
    var surface: Color { Color(red: 0xEF/255, green: 0xE7/255, blue: 0xDD/255) }
    var surfaceLight: Color { Color(red: 0xE6/255, green: 0xDB/255, blue: 0xCF/255) }
    var card: Color { Color(red: 0xFF/255, green: 0xFC/255, blue: 0xF8/255) }
    var accent: Color { Color(red: 0xE4/255, green: 0x7A/255, blue: 0x2E/255) }
    var accentSoft: Color { accent.opacity(0.15) }
    var mint: Color { Color(red: 0x2F/255, green: 0x9F/255, blue: 0x88/255) }
    var mintSoft: Color { mint.opacity(0.15) }
    var rose: Color { Color(red: 0xD9/255, green: 0x60/255, blue: 0x78/255) }
    var roseSoft: Color { rose.opacity(0.15) }
    var lavender: Color { Color(red: 0x7F/255, green: 0x68/255, blue: 0xD9/255) }
    var lavenderSoft: Color { lavender.opacity(0.15) }
    var sky: Color { Color(red: 0x4B/255, green: 0x8E/255, blue: 0xF6/255) }
    var skySoft: Color { sky.opacity(0.15) }
    var gold: Color { Color(red: 0xD7/255, green: 0xA6/255, blue: 0x42/255) }
    var text1: Color { Color(red: 0x1F/255, green: 0x1A/255, blue: 0x17/255) }
    var text2: Color { Color(red: 0x6D/255, green: 0x63/255, blue: 0x5B/255) }
    var text3: Color { Color(red: 0xA0/255, green: 0x94/255, blue: 0x8A/255) }
    var divider: Color { text1.opacity(0.10) }

    var borderAccent: Color {
        accent.opacity(0.35)
    }
    var backgroundPrimary: Color {
        Color(red: 0xF8/255, green: 0xEE/255, blue: 0xE3/255)
    }
    var backgroundSecondary: Color {
        surface
    }
    var buttonPrimary: Color {
        accent
    }
    var backgroundSubtle: Color {
        bg
    }
    var shadowStrength: Double { 1.0 }
}

/// The deep navy-charcoal dark theme with a vivid orange accent.
///
/// Shadow strengths are reduced to 0.5 to prevent neon glows from appearing heavy
/// over the dark backgrounds.
struct DarkTheme: AppTheme {
    var frostStrokeTop: Color { Color.white.opacity(0.28) }
    var frostStrokeBottom: Color { Color.white.opacity(0.10) }

    var bg: Color { Color(red: 0x0F/255, green: 0x0F/255, blue: 0x17/255) }
    var surface: Color { Color(red: 0x1C/255, green: 0x1C/255, blue: 0x26/255) }
    var surfaceLight: Color { Color(red: 0x29/255, green: 0x29/255, blue: 0x36/255) }
    var card: Color { Color(red: 0x21/255, green: 0x21/255, blue: 0x2E/255) }
    var accent: Color { Color(red: 0xFF/255, green: 0x8C/255, blue: 0x33/255) }
    var accentSoft: Color { accent.opacity(0.15) }
    var mint: Color { Color(red: 0x4D/255, green: 0xD9/255, blue: 0xB8/255) }
    var mintSoft: Color { mint.opacity(0.15) }
    var rose: Color { Color(red: 0xF2/255, green: 0x59/255, blue: 0x7F/255) }
    var roseSoft: Color { rose.opacity(0.15) }
    var lavender: Color { Color(red: 0xA6/255, green: 0x80/255, blue: 0xF2/255) }
    var lavenderSoft: Color { lavender.opacity(0.15) }
    var sky: Color { Color(red: 0x59/255, green: 0xA6/255, blue: 0xFF/255) }
    var skySoft: Color { sky.opacity(0.15) }
    var gold: Color { Color(red: 0xFF/255, green: 0xD1/255, blue: 0x4D/255) }
    var text1: Color { .white }
    var text2: Color { .white.opacity(0.65) }
    var text3: Color { .white.opacity(0.35) }
    var divider: Color { .white.opacity(0.08) }

    var borderAccent: Color { accent }
    var backgroundPrimary: Color { surface }
    var backgroundSecondary: Color { surfaceLight }
    var buttonPrimary: Color { accent }
    var backgroundSubtle: Color { card }
    var shadowStrength: Double { 0.5 }
}

/// Resolves the correct `AppTheme` implementation from a SwiftUI `ColorScheme`.
///
/// Use this at the app root to keep the `appTheme` environment value in sync with the
/// device's current color scheme setting.
struct SystemTheme {
    /// Returns `LightTheme` for `.light` and `DarkTheme` for all other color schemes.
    /// - Parameter colorScheme: The current SwiftUI `ColorScheme`.
    /// - Returns: An `AppTheme` instance matching the given scheme.
    static func resolve(for colorScheme: ColorScheme) -> AppTheme {
        switch colorScheme {
        case .dark: return DarkTheme()
        default: return LightTheme()
        }
    }
}

/// The `EnvironmentKey` backing the `appTheme` environment value. Defaults to `DarkTheme`.
private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = DarkTheme()
}

/// Adds the `appTheme` key path to SwiftUI environment values.
extension EnvironmentValues {
    /// The active app theme, injected at the root view and consumed by descendant views
    /// via `@Environment(\.appTheme)`.
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
