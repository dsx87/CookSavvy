import SwiftUI

struct StarRating: View {
    @Environment(\.appTheme) private var theme
    let rating: Double

    var body: some View {
        HStack(spacing: UI.Components.starSpacing) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: Double(i) <= rating ? "star.fill" : (Double(i) - 0.5 <= rating ? "star.leadinghalf.filled" : "star"))
                    .font(UI.Fonts.micro)
                    .foregroundStyle(theme.gold)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: Strings.Accessibility.rating, ratingString))
    }

    private var ratingString: String {
        let floored = min(max(floor(rating * 2) / 2, 0), 5)
        return floored == floored.rounded() ? "\(Int(floored))" : String(format: "%.1f", floored)
    }
}

struct StatPill: View {
    @Environment(\.appTheme) private var theme
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: UI.Components.statPillSpacing) {
            Image(systemName: icon)
                .font(UI.Fonts.iconSemibold)
                .foregroundStyle(color)
            Text(value)
                .font(UI.Fonts.statPillValue)
                .foregroundStyle(theme.text1)
            Text(label)
                .font(UI.Fonts.statPillLabel)
                .foregroundStyle(theme.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UI.Components.statPillPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label.replacingOccurrences(of: "\n", with: " ")): \(value)")
    }
}
