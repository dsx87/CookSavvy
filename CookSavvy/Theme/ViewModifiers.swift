import SwiftUI

/// Applies a frosted glass card appearance to any view.
///
/// The modifier fills the background with `theme.card`, clips to a rounded rectangle,
/// and overlays a thin linear-gradient stroke that transitions from a bright highlight
/// at the top-leading edge to a dark shadow at the bottom-trailing edge, simulating
/// light glancing off a glass surface.
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

/// Produces a layered neon-glow effect by stacking two drop shadows.
///
/// The inner layer is a tight, bright core glow (`innerOpacity`, `innerRadiusScale`);
/// the outer layer is a softer, larger bloom with a slight downward offset
/// (`outerOpacity`, `outerOffsetScale`). Both layers are scaled by `theme.shadowStrength`
/// so the effect adapts gracefully between light and dark themes.
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

/// Applies the standard section label style: small bold rounded font, uppercased text,
/// wide letter-spacing, and `theme.text2` foreground color.
///
/// Use on `Text` views that head a content section (e.g. "SAVED RECIPES", "RECENT COOKS").
struct SectionLabelModifier: ViewModifier {
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .font(theme.sectionLabelFont)
            .textCase(.uppercase)
            .tracking(UI.V2.SectionLabel.tracking)
            // text2 (not text3): section headings are load-bearing text and must clear
            // WCAG AA. text3 is reserved for decoration. (T-039)
            .foregroundStyle(theme.text2)
    }
}

/// Convenience APIs for applying app-wide visual style modifiers.
extension View {
    /// Applies a frosted glass card background with a gradient border stroke.
    /// - Parameter cornerRadius: The card corner radius. Defaults to `UI.V2.FrostCard.defaultCornerRadius`.
    func frostCard(cornerRadius: CGFloat = UI.V2.FrostCard.defaultCornerRadius) -> some View {
        modifier(FrostCardModifier(cornerRadius: cornerRadius))
    }

    /// Applies a two-layer neon glow shadow effect.
    /// - Parameters:
    ///   - color: The glow color.
    ///   - radius: The outer glow radius. Defaults to `UI.V2.NeonGlow.defaultRadius`.
    func neonGlow(_ color: Color, radius: CGFloat = UI.V2.NeonGlow.defaultRadius) -> some View {
        modifier(NeonGlowModifier(color: color, radius: radius))
    }

    /// Applies the standard section label typography: small, bold, uppercased, wide-tracked, `text3` color.
    func sectionLabel() -> some View {
        modifier(SectionLabelModifier())
    }
}
