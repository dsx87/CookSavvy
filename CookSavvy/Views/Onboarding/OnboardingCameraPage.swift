//
//  OnboardingCameraPage.swift
//  CookSavvy
//

import SwiftUI

struct OnboardingCameraPage: View {
    @ObservedObject var viewModel: OnboardingViewModel
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

    private func ingredientChips(_ ingredients: [Ingredient]) -> some View {
        let visibleIngredients = Array(ingredients.prefix(UI.Onboarding.chipMaxCount))

        return FlowLayout(
            items: visibleIngredients,
            horizontalSpacing: UI.Onboarding.chipSpacing,
            verticalSpacing: UI.Onboarding.chipSpacing
        ) { ingredient in
            Text(ingredient.name)
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

private struct OnboardingPrimaryButtonModifier: ViewModifier {
    let theme: AppTheme

    func body(content: Content) -> some View {
        content
            .font(UI.Fonts.buttonLabel)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, UI.Onboarding.buttonVerticalPadding)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: UI.Onboarding.buttonCornerRadius, style: .continuous))
            .frame(maxWidth: UI.Onboarding.buttonMaxWidth)
    }
}

private struct OnboardingSecondaryButtonModifier: ViewModifier {
    let theme: AppTheme

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

private struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let content: (Data.Element) -> Content

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
