import SwiftUI

enum RecipeDisplaySource: Equatable {
    case local
    case network
    case ai
    case user

    init?(recipe: Recipe) {
        if recipe.isUserCreated {
            self = .user
            return
        }

        switch recipe.source {
        case .offline?:
            self = .local
        case .online?:
            self = .network
        case .ai?:
            self = .ai
        case nil:
            return nil
        }
    }

    var iconName: String {
        switch self {
        case .local: Icons.RecipeSource.offline
        case .network: Icons.RecipeSource.online
        case .ai: Icons.RecipeSource.ai
        case .user: Icons.RecipeSource.user
        }
    }

    var title: String {
        switch self {
        case .local: Strings.SourceBadge.localTitle
        case .network: Strings.SourceBadge.networkTitle
        case .ai: Strings.SourceBadge.aiTitle
        case .user: Strings.SourceBadge.userTitle
        }
    }

    var description: String {
        switch self {
        case .local: Strings.SourceBadge.localDescription
        case .network: Strings.SourceBadge.networkDescription
        case .ai: Strings.SourceBadge.aiDescription
        case .user: Strings.SourceBadge.userDescription
        }
    }

    func backgroundColor(theme: AppTheme) -> Color {
        switch self {
        case .local: theme.text1
        case .network: theme.sky
        case .ai: theme.lavender
        case .user: theme.gold
        }
    }

    func foregroundColor(theme: AppTheme) -> Color {
        switch self {
        case .local, .user:
            theme.bg
        case .network, .ai:
            .white
        }
    }
}

struct RecipeSourceBadge: View {
    @Environment(\.appTheme) private var theme
    let source: RecipeDisplaySource
    var cornerRadius: CGFloat = UI.Common.cardCornerRadius
    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented = true
        } label: {
            Image(systemName: source.iconName)
                .font(.system(size: UI.SourceBadge.iconSize, weight: .semibold))
                .foregroundStyle(source.foregroundColor(theme: theme))
                .frame(width: UI.SourceBadge.width, height: UI.SourceBadge.height)
                .background(source.backgroundColor(theme: theme))
                .clipShape(
                    .rect(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: cornerRadius,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: cornerRadius
                    )
                )
                .overlay {
                    UnevenRoundedRectangle(
                        cornerRadii: .init(
                            topLeading: 0,
                            bottomLeading: cornerRadius,
                            bottomTrailing: 0,
                            topTrailing: cornerRadius
                        ),
                        style: .continuous
                    )
                    .stroke(.white.opacity(UI.SourceBadge.borderOpacity), lineWidth: UI.Common.borderWidth)
                }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented) {
            VStack(alignment: .leading, spacing: UI.SourceBadge.popoverSpacing) {
                Text(source.title)
                    .font(UI.Fonts.smallCaptionBold)
                    .foregroundStyle(theme.text1)
                Text(source.description)
                    .font(UI.Fonts.smallCaption)
                    .foregroundStyle(theme.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: UI.SourceBadge.popoverWidth, alignment: .leading)
            .padding(UI.SourceBadge.popoverPadding)
            .background(theme.surface)
            .presentationCompactAdaptation(.popover)
            .presentationBackground(theme.surface)
        }
        .accessibilityLabel(source.title)
        .accessibilityHint(Strings.SourceBadge.accessibilityHint)
    }
}

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
    }
}
