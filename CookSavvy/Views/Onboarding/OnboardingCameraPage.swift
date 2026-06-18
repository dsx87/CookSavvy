//
//  OnboardingCameraPage.swift
//  CookSavvy
//

import SwiftUI

/// The embedded camera scan page shown as the last step of onboarding.
///
/// Renders a state-driven layout based on `OnboardingViewModel.CameraPageState`:
/// - `.capturing` — live `CameraCaptureView` with an overlay and "Type Instead" fallback
/// - `.processing` — frozen image with a spinner and progress text
/// - `.detected` — ingredient chips confirming what was found
/// - `.noIngredientsFound` — retry card
/// - `.permissionDenied` — Settings deep-link card
/// - `.error` — error message card
struct OnboardingCameraPage: View {
    var viewModel: OnboardingViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewModel.cameraState {
            case .idle, .requestingPermission:
                ProgressView()
                    .scaleEffect(UI.Common.progressScale)
                    .tint(.white)

            case .permissionGranted, .capturing:
                capturingView

            case .processing(let image):
                processingView(image: image)

            case .detected(let ingredients):
                detectedView(ingredients: ingredients)

            case .permissionDenied:
                permissionDeniedView

            case .noIngredientsFound:
                noIngredientsFoundView

            case .error(let message):
                errorView(message: message)
            }
        }
        .accessibilityIdentifier(AccessibilityID.Onboarding.cameraPage)
    }

    /// Full-screen `CameraCaptureView` with an overlay bar and contextual instructions.
    private var capturingView: some View {
        ZStack(alignment: .top) {
            if viewModel.isCameraPage {
                CameraCaptureView(
                    onPhotoCaptured: viewModel.photoCaptured,
                    showsCloseButton: false
                )
                .ignoresSafeArea()
            }

            cameraOverlay
        }
    }

    /// Top instruction bar overlaid on the live camera preview.
    private var cameraOverlay: some View {
        VStack(spacing: UI.Onboarding.cameraOverlaySpacing) {
            Text(Strings.Onboarding.scanPageTitle)
                .font(UI.Fonts.largeTitle)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(Strings.Onboarding.scanPageSubtitle)
                .font(UI.Fonts.body)
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)

            // Privacy disclosure: photos are uploaded off-device for AI detection (T-034).
            Text(Strings.Camera.aiProcessingDisclosure)
                .font(UI.Fonts.smallCaption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, UI.Onboarding.cameraOverlayPadding)
        .padding(.top, UI.Onboarding.overlayTopPadding)
        .padding(.horizontal, UI.Onboarding.overlayHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// Full-screen overlay showing the frozen captured image and a spinner while AI detection runs.
    private func processingView(image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            Color.black.opacity(UI.Onboarding.processingOverlayOpacity)
                .ignoresSafeArea()

            VStack(spacing: UI.Common.stackSpacing) {
                ProgressView()
                    .scaleEffect(UI.Common.progressScale)
                    .tint(.white)

                Text(Strings.Onboarding.scanning)
                    .font(UI.Fonts.bodySemibold)
                    .foregroundStyle(.white)

                typeInsteadButton
                    .modifier(OnboardingSecondaryButtonModifier(theme: theme))
            }
            .padding(UI.Onboarding.cardPadding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: theme.cornerRadiusLarge))
        }
    }

    /// Success state card showing the detected ingredient chips before the flow auto-advances.
    private func detectedView(ingredients: [Ingredient]) -> some View {
        VStack(spacing: UI.Onboarding.cardSpacing) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: UI.Onboarding.stateIconSize, weight: .semibold))
                .foregroundStyle(theme.mint)

            VStack(spacing: UI.Common.mediumSpacing) {
                Text(Strings.Onboarding.detectedTitle)
                    .font(UI.Fonts.title)
                    .foregroundStyle(.white)

                ingredientChips(ingredients)
            }
        }
        .padding(UI.Onboarding.cardPadding)
    }

    private var permissionDeniedView: some View {
        stateCard(
            icon: Icons.Camera.camera,
            title: Strings.Onboarding.cameraDeniedTitle,
            subtitle: Strings.Onboarding.cameraDeniedSubtitle
        ) {
            Button(Strings.Onboarding.openSettings) {
                viewModel.openSettings()
            }
            .modifier(OnboardingPrimaryButtonModifier(theme: theme))

            typeInsteadButton
                .modifier(OnboardingSecondaryButtonModifier(theme: theme))
        }
    }

    private var noIngredientsFoundView: some View {
        stateCard(
            icon: Icons.Camera.warning,
            title: Strings.Onboarding.noIngredientsTitle,
            subtitle: Strings.Onboarding.noIngredientsSubtitle
        ) {
            Button(Strings.Camera.tryAgain) {
                viewModel.retryCapture()
            }
            .modifier(OnboardingPrimaryButtonModifier(theme: theme))

            typeInsteadButton
                .modifier(OnboardingSecondaryButtonModifier(theme: theme))
        }
    }

    /// Builds the fallback error card when ingredient detection fails.
    private func errorView(message: String) -> some View {
        stateCard(
            icon: Icons.Camera.errorCircle,
            title: Strings.Onboarding.errorTitle,
            subtitle: message
        ) {
            Button(Strings.Camera.tryAgain) {
                viewModel.retryCapture()
            }
            .modifier(OnboardingPrimaryButtonModifier(theme: theme))

            typeInsteadButton
                .modifier(OnboardingSecondaryButtonModifier(theme: theme))
        }
    }

    /// Shared card layout used for onboarding camera states with custom action content.
    private func stateCard<Actions: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(spacing: UI.Onboarding.cardSpacing) {
            Image(systemName: icon)
                .font(.system(size: UI.Onboarding.stateIconSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))

            VStack(spacing: UI.Common.mediumSpacing) {
                Text(title)
                    .font(UI.Fonts.title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(UI.Fonts.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: UI.Common.largeSpacing) {
                actions()
            }
        }
        .frame(maxWidth: UI.Onboarding.cardMaxWidth)
        .padding(UI.Onboarding.cardPadding)
    }

    /// Renders up to a capped number of detected ingredient chips in a wrapped grid.
    private func ingredientChips(_ ingredients: [Ingredient]) -> some View {
        let visibleIngredients = Array(ingredients.prefix(UI.Onboarding.chipMaxCount))

        return FlowLayout(
            items: visibleIngredients,
            horizontalSpacing: UI.Onboarding.chipSpacing,
            verticalSpacing: UI.Onboarding.chipSpacing
        ) { ingredient in
            Text(ingredient.name.capitalized)
                .font(UI.Fonts.captionSemibold)
                .foregroundStyle(.white)
                .padding(.horizontal, UI.Common.chipHorizontalPadding)
                .padding(.vertical, UI.Common.chipVerticalPadding)
                .background(theme.mint.opacity(0.25), in: Capsule())
        }
    }

    private var typeInsteadButton: some View {
        Button(Strings.Onboarding.typeInstead) {
            viewModel.typeInstead()
        }
        .accessibilityIdentifier(AccessibilityID.Onboarding.typeInsteadButton)
    }
}

/// Primary CTA button styling used in onboarding camera-state cards.
private struct OnboardingPrimaryButtonModifier: ViewModifier {
    let theme: AppTheme

    /// Applies the primary onboarding button visual treatment.
    func body(content: Content) -> some View {
        content
            .font(UI.Fonts.buttonLabel)
            .foregroundStyle(theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, UI.Onboarding.buttonVerticalPadding)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: UI.Onboarding.buttonCornerRadius, style: .continuous))
            .frame(maxWidth: UI.Onboarding.buttonMaxWidth)
    }
}

/// Secondary CTA button styling used in onboarding camera-state cards.
private struct OnboardingSecondaryButtonModifier: ViewModifier {
    let theme: AppTheme

    /// Applies the secondary onboarding button visual treatment.
    func body(content: Content) -> some View {
        content
            .font(UI.Fonts.bodySemibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, UI.Onboarding.buttonVerticalPadding)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: UI.Onboarding.buttonCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: UI.Onboarding.buttonCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: UI.Common.borderWidth)
            )
            .frame(maxWidth: UI.Onboarding.buttonMaxWidth)
    }
}

/// Simple flow layout that groups items into rows of three for chip presentation.
private struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let content: (Data.Element) -> Content

    /// Creates a row-based flow layout with caller-provided spacing and item content.
    init(
        items: Data,
        horizontalSpacing: CGFloat,
        verticalSpacing: CGFloat,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.items = items
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .center, spacing: verticalSpacing) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: horizontalSpacing) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                }
            }
        }
    }

    private var rows: [[Data.Element]] {
        var rows: [[Data.Element]] = []
        var currentRow: [Data.Element] = []

        for item in items {
            currentRow.append(item)
            if currentRow.count == 3 {
                rows.append(currentRow)
                currentRow = []
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }
}
