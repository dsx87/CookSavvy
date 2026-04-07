//
//  OnboardingView.swift
//  CookSavvy
//

import SwiftUI

struct OnboardingView: View {
    @StateObject var viewModel: OnboardingViewModel
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.bg.ignoresSafeArea()

            TabView(selection: $viewModel.currentPage) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                        .accessibilityIdentifier(AccessibilityID.Onboarding.page(index))
                }

                OnboardingCameraPage(viewModel: viewModel)
                    .tag(viewModel.pages.count)
                    .accessibilityIdentifier(AccessibilityID.Onboarding.cameraPage)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: viewModel.currentPage)
            .onChange(of: viewModel.currentPage) { _, _ in
                viewModel.enterCameraPageIfNeeded()
            }

            if viewModel.showsBottomControls {
                VStack(spacing: UI.Onboarding.bottomSpacing) {
                    pageIndicator

                    Button {
                        withAnimation {
                            viewModel.handlePrimaryAction()
                        }
                    } label: {
                        Text(viewModel.primaryButtonTitle)
                            .font(UI.Fonts.buttonLabel)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, UI.Onboarding.buttonVerticalPadding)
                            .background(theme.accent, in: RoundedRectangle(cornerRadius: UI.Onboarding.buttonCornerRadius, style: .continuous))
                            .neonGlow(theme.accent, radius: UI.Common.neonRadiusDefault)
                    }
                    .padding(.horizontal, UI.Onboarding.pageHorizontalPadding)
                    .accessibilityIdentifier(AccessibilityID.Onboarding.getStartedButton)
                }
                .padding(.bottom, UI.Onboarding.bottomPadding)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhaseChange(newPhase)
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.canUseTopRightFallback {
                Button(Strings.Onboarding.skip) {
                    viewModel.handleTopRightAction()
                }
                .font(UI.Fonts.captionSemibold)
                .foregroundStyle(theme.text2)
                .padding()
                .accessibilityIdentifier(AccessibilityID.Onboarding.skipButton)
            }
        }
    }

    private func pageView(_ page: OnboardingViewModel.Page) -> some View {
        VStack(spacing: UI.Onboarding.pageSpacing) {
            Spacer()

            Image(systemName: page.symbolName)
                .font(.system(size: UI.Onboarding.iconSize, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.accent, theme.mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(32)
                .background(theme.accentSoft.opacity(0.3), in: Circle())

            VStack(spacing: 12) {
                Text(page.title)
                    .font(UI.Fonts.heroTitle)
                    .foregroundStyle(theme.text1)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(UI.Fonts.body)
                    .foregroundStyle(theme.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, UI.Onboarding.pageHorizontalPadding)
            }

            Spacer()
            Spacer()
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: UI.Onboarding.indicatorSpacing) {
            ForEach(0..<viewModel.totalPages, id: \.self) { index in
                Capsule()
                    .fill(index == viewModel.currentPage ? theme.accent : theme.divider)
                    .frame(
                        width: index == viewModel.currentPage ? UI.Onboarding.indicatorActiveWidth : UI.Onboarding.indicatorInactiveWidth,
                        height: UI.Onboarding.indicatorHeight
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.pageIndicatorAccessibilityLabel)
    }
}

#Preview {
    OnboardingView(
        viewModel: OnboardingViewModel(
            analyticsService: MockAnalyticsService(),
            ingredientDetectionService: OnboardingPreviewDetectionService(),
            cameraScanTracker: OnboardingPreviewCameraScanTracker(),
            onComplete: { _ in }
        )
    )
}

private final class OnboardingPreviewDetectionService: IngredientDetectionServiceProtocol {
    func detectIngredients(in image: UIImage) async throws -> [Ingredient] {
        [Ingredient(name: "Tomato"), Ingredient(name: "Eggs")]
    }
}

private final class OnboardingPreviewCameraScanTracker: CameraScanTrackerProtocol {
    func canScan(limit: Int) -> Bool { true }
    func recordScan() {}
    func recordScanWithoutQuota() {}
    func remainingScans(limit: Int) -> Int { CameraScanTracker.freeWeeklyLimit }
    func totalScansRecorded() -> Int { 0 }
}
