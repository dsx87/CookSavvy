//
//  OnboardingView.swift
//  CookSavvy
//

import SwiftUI

struct OnboardingView: View {
    @StateObject var viewModel: OnboardingViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.bg.ignoresSafeArea()

            TabView(selection: $viewModel.currentPage) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                        .accessibilityIdentifier(AccessibilityID.Onboarding.page(index))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: viewModel.currentPage)

            VStack(spacing: 24) {
                pageIndicator

                if viewModel.isLastPage {
                    Button {
                        viewModel.nextPage()
                    } label: {
                        Text(Strings.Onboarding.getStarted)
                            .font(UI.Fonts.buttonLabel)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(theme.accent, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .neonGlow(theme.accent, radius: UI.Common.neonRadiusDefault)
                    }
                    .padding(.horizontal, 32)
                    .accessibilityIdentifier(AccessibilityID.Onboarding.getStartedButton)
                } else {
                    Button {
                        withAnimation {
                            viewModel.nextPage()
                        }
                    } label: {
                        Text(Strings.Onboarding.getStarted)
                            .font(UI.Fonts.buttonLabel)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(theme.accent, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .neonGlow(theme.accent, radius: UI.Common.neonRadiusDefault)
                    }
                    .padding(.horizontal, 32)
                    .accessibilityIdentifier(AccessibilityID.Onboarding.getStartedButton)
                }
            }
            .padding(.bottom, 48)
        }
        .overlay(alignment: .topTrailing) {
            Button(Strings.Onboarding.skip) {
                viewModel.skip()
            }
            .font(UI.Fonts.captionSemibold)
            .foregroundStyle(theme.text2)
            .padding()
            .accessibilityIdentifier(AccessibilityID.Onboarding.skipButton)
        }
    }

    private func pageView(_ page: OnboardingViewModel.Page) -> some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.symbolName)
                .font(.system(size: 80, weight: .light))
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
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<viewModel.pages.count, id: \.self) { index in
                Capsule()
                    .fill(index == viewModel.currentPage ? theme.accent : theme.divider)
                    .frame(width: index == viewModel.currentPage ? 20 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.currentPage)
            }
        }
    }
}

#Preview {
    OnboardingView(viewModel: OnboardingViewModel(analyticsService: MockAnalyticsService(), onComplete: {}))
}
