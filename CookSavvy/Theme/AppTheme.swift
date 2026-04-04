import SwiftUI

protocol AppTheme {
    // MARK: - V2 Color Tokens
    var bg: Color { get }
    var surface: Color { get }
    var surfaceLight: Color { get }
    var card: Color { get }
    var accent: Color { get }
    var accentSoft: Color { get }
    var mint: Color { get }
    var mintSoft: Color { get }
    var rose: Color { get }
    var roseSoft: Color { get }
    var lavender: Color { get }
    var lavenderSoft: Color { get }
    var sky: Color { get }
    var skySoft: Color { get }
    var gold: Color { get }
    var text1: Color { get }
    var text2: Color { get }
    var text3: Color { get }
    var divider: Color { get }

    // MARK: - Modifier Style Tokens
    var frostStrokeTop: Color { get }
    var frostStrokeBottom: Color { get }
    var sectionLabelFont: Font { get }
    var shadowStrength: Double { get }

    // MARK: - Corner Radius Tokens
    var cornerRadiusSmall: CGFloat { get }
    var cornerRadiusMedium: CGFloat { get }
    var cornerRadiusLarge: CGFloat { get }
    var cornerRadiusXL: CGFloat { get }
    var cornerRadiusPill: CGFloat { get }

    // MARK: - Legacy Tokens (V1 compatibility)
    var borderAccent: Color { get }
    var backgroundPrimary: Color { get }
    var backgroundSecondary: Color { get }
    var buttonPrimary: Color { get }
    var backgroundSubtle: Color { get }
}

extension AppTheme {
    var cornerRadiusSmall: CGFloat { 12 }
    var cornerRadiusMedium: CGFloat { 16 }
    var cornerRadiusLarge: CGFloat { 20 }
    var cornerRadiusXL: CGFloat { 24 }
    var cornerRadiusPill: CGFloat { 32 }
    var sectionLabelFont: Font { .system(size: 11, weight: .bold, design: .rounded) }
    var shadowStrength: Double { 1.0 }
}

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

struct SystemTheme {
    static func resolve(for colorScheme: ColorScheme) -> AppTheme {
        switch colorScheme {
        case .dark: return DarkTheme()
        default: return LightTheme()
        }
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = DarkTheme()
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
