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
    var sourceBadgeOffline: Color { get }
    var sourceBadgeOnline: Color { get }
    var sourceBadgeAI: Color { get }
}

extension AppTheme {
    var cornerRadiusSmall: CGFloat { 12 }
    var cornerRadiusMedium: CGFloat { 16 }
    var cornerRadiusLarge: CGFloat { 20 }
    var cornerRadiusXL: CGFloat { 24 }
    var cornerRadiusPill: CGFloat { 32 }
    var sectionLabelFont: Font { .system(size: 11, weight: .bold, design: .rounded) }
}

struct LightTheme: AppTheme {
    var frostStrokeTop: Color { Color.black.opacity(0.06) }
    var frostStrokeBottom: Color { Color.black.opacity(0.02) }

    var bg: Color { Color(red: 0.98, green: 0.98, blue: 0.99) }
    var surface: Color { Color(red: 0.94, green: 0.94, blue: 0.96) }
    var surfaceLight: Color { Color(red: 0.90, green: 0.90, blue: 0.93) }
    var card: Color { .white }
    var accent: Color { Color(red: 1.0, green: 0.549, blue: 0.2) }
    var accentSoft: Color { accent.opacity(0.15) }
    var mint: Color { Color(red: 0.302, green: 0.851, blue: 0.722) }
    var mintSoft: Color { mint.opacity(0.15) }
    var rose: Color { Color(red: 0.949, green: 0.349, blue: 0.498) }
    var roseSoft: Color { rose.opacity(0.15) }
    var lavender: Color { Color(red: 0.651, green: 0.502, blue: 0.949) }
    var lavenderSoft: Color { lavender.opacity(0.15) }
    var sky: Color { Color(red: 0.349, green: 0.651, blue: 1.0) }
    var skySoft: Color { sky.opacity(0.15) }
    var gold: Color { Color(red: 1.0, green: 0.82, blue: 0.302) }
    var text1: Color { Color(red: 0.1, green: 0.1, blue: 0.12) }
    var text2: Color { Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.65) }
    var text3: Color { Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.35) }
    var divider: Color { Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.08) }

    var borderAccent: Color {
        Color(red: 254.0/255.0, green: 215.0/255.0, blue: 170.0/255.0)
    }
    var backgroundPrimary: Color {
        Color(red: 255.0/255.0, green: 237.0/255.0, blue: 213.0/255.0)
    }
    var backgroundSecondary: Color {
        Color(red: 255.0/255.0, green: 244.0/255.0, blue: 239.0/255.0)
    }
    var buttonPrimary: Color {
        Color(red: 246.0/255.0, green: 115.0/255.0, blue: 21.0/255.0)
    }
    var backgroundSubtle: Color {
        Color(red: 249.0/255.0, green: 250.0/255.0, blue: 251.0/255.0)
    }
    var sourceBadgeOffline: Color { .gray }
    var sourceBadgeOnline: Color { .blue }
    var sourceBadgeAI: Color { .purple }
}

struct DarkTheme: AppTheme {
    var frostStrokeTop: Color { Color.white.opacity(0.12) }
    var frostStrokeBottom: Color { Color.white.opacity(0.03) }

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
    var sourceBadgeOffline: Color { .gray }
    var sourceBadgeOnline: Color { sky }
    var sourceBadgeAI: Color { lavender }
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
