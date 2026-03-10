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

    var shortLabel: String {
        switch self {
        case .local: Strings.SourceBadge.localShortLabel
        case .network: Strings.SourceBadge.networkShortLabel
        case .ai: Strings.SourceBadge.aiShortLabel
        case .user: Strings.SourceBadge.userShortLabel
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
        case .local: theme.mint
        case .network: theme.sky
        case .ai: theme.lavender
        case .user: theme.gold
        }
    }
}

struct RecipeSourceBadge: View {
    @Environment(\.appTheme) private var theme
    let source: RecipeDisplaySource
    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented = true
        } label: {
            HStack(spacing: UI.SourceBadge.labelSpacing) {
                Image(systemName: source.iconName)
                    .symbolVariant(.fill)
                Text(source.shortLabel)
            }
            .font(.system(size: UI.SourceBadge.iconSize, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, UI.SourceBadge.pillPaddingH)
            .padding(.vertical, UI.SourceBadge.pillPaddingV)
            .background(source.backgroundColor(theme: theme), in: Capsule(style: .continuous))
            .shadow(
                color: source.backgroundColor(theme: theme).opacity(UI.SourceBadge.shadowOpacity),
                radius: UI.SourceBadge.shadowRadius,
                y: UI.SourceBadge.shadowY
            )
        }
        .buttonStyle(SourceBadgePressStyle())
        .padding(UI.SourceBadge.edgePadding)
        .popover(isPresented: $isPopoverPresented) {
            SourceBadgePopoverContent(source: source)
        }
        .accessibilityLabel(source.title)
        .accessibilityHint(Strings.SourceBadge.accessibilityHint)
    }
}

private struct SourceBadgePopoverContent: View {
    @Environment(\.appTheme) private var theme
    let source: RecipeDisplaySource

    var body: some View {
        VStack(alignment: .leading, spacing: UI.SourceBadge.popoverSpacing) {
            HStack(spacing: UI.SourceBadge.labelSpacing) {
                Image(systemName: source.iconName)
                    .symbolVariant(.fill)
                    .font(.system(size: UI.SourceBadge.popoverIconSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(UI.SourceBadge.popoverIconPadding)
                    .background(source.backgroundColor(theme: theme), in: Circle())
                Text(source.title)
                    .font(UI.Fonts.smallCaptionBold)
                    .foregroundStyle(theme.text1)
            }
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
}

private struct SourceBadgePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.65), value: configuration.isPressed)
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
