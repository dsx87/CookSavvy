import SwiftUI

/// A row of 1–5 star icons representing a numeric rating.
/// Supports half-star display and rounds to the nearest 0.5 for accessibility labelling.
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

    /// Rating value rounded to the nearest 0.5, clamped to [0, 5], formatted for VoiceOver.
    private var ratingString: String {
        let floored = min(max(floor(rating * 2) / 2, 0), 5)
        return floored == floored.rounded() ? "\(Int(floored))" : String(format: "%.1f", floored)
    }
}

/// A left-aligned flow layout that lays subviews out left-to-right and wraps onto a new row
/// whenever the next subview would exceed the proposed width. Each subview keeps its intrinsic
/// size — nothing is compressed — so it is well suited to rows of capsule pills/badges that may
/// overflow a width-constrained column (e.g. `RecipeBadges` inside a `RecipeRow`).
struct WrappingFlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0      // width consumed by the current row (incl. trailing spacing)
        var rowHeight: CGFloat = 0     // tallest subview in the current row
        var totalWidth: CGFloat = 0    // widest row seen so far
        var totalHeight: CGFloat = 0   // accumulated height of completed rows

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            // Wrap to a new row when this subview no longer fits (but never on an empty row).
            if rowWidth > 0, rowWidth + size.width > maxWidth {
                totalWidth = max(totalWidth, rowWidth - horizontalSpacing)
                totalHeight += rowHeight + verticalSpacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
        totalWidth = max(totalWidth, rowWidth - horizontalSpacing)
        totalHeight += rowHeight
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            // Move to the next row when this subview would overflow the available width.
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// A vertically stacked icon + value + label pill used in the recipe details stats row.
/// Expands to fill its parent width so multiple pills share available space equally.
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
