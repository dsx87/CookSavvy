import SwiftUI

enum ThemePreference: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    static let storageKey = "theme_preference"
    static let defaultValue: ThemePreference = .system

    var id: Self { self }

    static func from(rawValue: String?) -> ThemePreference {
        guard let rawValue else { return defaultValue }
        return ThemePreference(rawValue: rawValue) ?? defaultValue
    }

    var displayName: String {
        switch self {
        case .light:
            Strings.Settings.appearanceLight
        case .dark:
            Strings.Settings.appearanceDark
        case .system:
            Strings.Settings.appearanceSystem
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light:
            .light
        case .dark:
            .dark
        case .system:
            nil
        }
    }

    func resolvedTheme(for colorScheme: ColorScheme) -> AppTheme {
        switch self {
        case .light:
            LightTheme()
        case .dark:
            DarkTheme()
        case .system:
            SystemTheme.resolve(for: colorScheme)
        }
    }
}
