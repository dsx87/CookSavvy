import SwiftUI

protocol AppTheme {
    var borderAccent: Color { get }
    var backgroundPrimary: Color { get }
    var backgroundSecondary: Color { get }
    var buttonPrimary: Color { get }
    var backgroundSubtle: Color { get }
    var sourceBadgeOffline: Color { get }
    var sourceBadgeOnline: Color { get }
    var sourceBadgeAI: Color { get }
}

struct DefaultTheme: AppTheme {
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

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = DefaultTheme()
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
