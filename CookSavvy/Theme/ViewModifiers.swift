import SwiftUI

struct FrostCardModifier: ViewModifier {
    @Environment(\.appTheme) private var theme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [theme.frostStrokeTop, theme.frostStrokeBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: UI.V2.FrostCard.strokeWidth
                    )
            )
    }
}

struct NeonGlowModifier: ViewModifier {
    @Environment(\.appTheme) private var theme
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(
                color: color.opacity(UI.V2.NeonGlow.innerOpacity * theme.shadowStrength),
                radius: radius * UI.V2.NeonGlow.innerRadiusScale,
                x: 0, y: 0
            )
            .shadow(
                color: color.opacity(UI.V2.NeonGlow.outerOpacity * theme.shadowStrength),
                radius: radius,
                x: 0, y: radius * UI.V2.NeonGlow.outerOffsetScale
            )
    }
}

struct SectionLabelModifier: ViewModifier {
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .font(theme.sectionLabelFont)
            .textCase(.uppercase)
            .tracking(UI.V2.SectionLabel.tracking)
            .foregroundStyle(theme.text3)
    }
}

extension View {
    func frostCard(cornerRadius: CGFloat = UI.V2.FrostCard.defaultCornerRadius) -> some View {
        modifier(FrostCardModifier(cornerRadius: cornerRadius))
    }

    func neonGlow(_ color: Color, radius: CGFloat = UI.V2.NeonGlow.defaultRadius) -> some View {
        modifier(NeonGlowModifier(color: color, radius: radius))
    }

    func sectionLabel() -> some View {
        modifier(SectionLabelModifier())
    }
}
