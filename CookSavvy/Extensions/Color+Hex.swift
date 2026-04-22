import SwiftUI

/// Color construction conveniences used by theme and design tokens.
extension Color {
    /// Creates a `Color` from a CSS-style hex string, with or without a leading `#`.
    ///
    /// Expects a 6-digit RGB hex value (e.g. `"#FF9500"` or `"FF9500"`).
    /// - Parameter hex: The hex colour string to parse.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
