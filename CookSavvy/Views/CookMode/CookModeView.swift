import SwiftUI

struct CookModeView: View {
    @Environment(\.appTheme) private var theme
    @StateObject var viewModel: CookModeViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.accent.opacity(UI.CookMode.bgOpacity), theme.bg],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                stepProgressDots
                Spacer()
                stepContent
                Spacer()
                navigationButtons
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { viewModel.dismiss() } label: {
                Image(systemName: Icons.CookMode.close)
                    .font(UI.Fonts.buttonIcon)
                    .foregroundStyle(theme.text2)
                    .frame(width: UI.CookMode.closeButtonSize, height: UI.CookMode.closeButtonSize)
                    .background(theme.surface, in: Circle())
            }

            Spacer()

            VStack(spacing: UI.CookMode.titleInfoSpacing) {
                Text(viewModel.recipe.title)
                    .font(UI.Fonts.sectionTitle)
                    .foregroundStyle(theme.text1)
                Text(String(format: Strings.CookMode.stepOf, viewModel.currentStep + 1, viewModel.stepCount))
                    .font(UI.Fonts.smallCaption)
                    .foregroundStyle(theme.text2)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(theme.surface, lineWidth: UI.CookMode.progressLineWidth)
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: UI.CookMode.progressLineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(viewModel.completedSteps.count)")
                    .font(UI.Fonts.smallCaptionBold)
                    .foregroundStyle(theme.accent)
            }
            .frame(width: UI.CookMode.progressSize, height: UI.CookMode.progressSize)
            .animation(UI.Anim.easeDefault, value: viewModel.progress)
        }
        .padding(.horizontal, UI.CookMode.horizontalPadding)
        .padding(.top, UI.CookMode.topBarTopPadding)
    }

    // MARK: - Step Progress Dots

    private var stepProgressDots: some View {
        HStack(spacing: UI.CookMode.dotsSpacing) {
            ForEach(0..<viewModel.stepCount, id: \.self) { i in
                Capsule()
                    .fill(i == viewModel.currentStep ? theme.accent :
                            (viewModel.completedSteps.contains(i) ? theme.mint : theme.surfaceLight))
                    .frame(height: UI.Common.dotHeight)
                    .frame(maxWidth: i == viewModel.currentStep ? .infinity : UI.Common.dotInactiveWidth)
                    .animation(UI.Anim.springDefault, value: viewModel.currentStep)
            }
        }
        .padding(.horizontal, UI.CookMode.horizontalPadding)
        .padding(.top, UI.CookMode.dotsTopPadding)
    }

    // MARK: - Step Content

    private var stepContent: some View {
        VStack(spacing: UI.CookMode.contentSpacing) {
            Text(viewModel.currentStepText)
                .font(UI.Fonts.largeTitle)
                .foregroundStyle(theme.text1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, UI.CookMode.horizontalPadding)
                .id(viewModel.currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            if let timerMin = viewModel.currentStepTimer {
                timerView(minutes: timerMin)
            }
        }
    }

    private func timerView(minutes: Int) -> some View {
        VStack(spacing: UI.CookMode.timerSpacing) {
            ZStack {
                Circle()
                    .stroke(theme.surface, lineWidth: UI.CookMode.timerLineWidth)
                    .frame(width: UI.V2.cookModeTimerSize, height: UI.V2.cookModeTimerSize)

                Circle()
                    .trim(from: 0, to: viewModel.timerProgress)
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: UI.CookMode.timerLineWidth, lineCap: .round))
                    .frame(width: UI.V2.cookModeTimerSize, height: UI.V2.cookModeTimerSize)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: UI.CookMode.titleInfoSpacing) {
                    Text(viewModel.timerDisplayText())
                        .font(UI.Fonts.timerDisplay)
                        .foregroundStyle(theme.text1)
                    Text("minutes")
                        .font(UI.Fonts.tinyCaption)
                        .foregroundStyle(theme.text3)
                }
            }

            Button {
                viewModel.toggleTimer()
            } label: {
                HStack(spacing: UI.CookMode.timerButtonSpacing) {
                    Image(systemName: viewModel.timerRunning ? Icons.CookMode.pause : Icons.CookMode.play)
                    Text(viewModel.timerRunning ? Strings.CookMode.pause : Strings.CookMode.startTimer)
                        .font(UI.Fonts.bodySemibold)
                }
                .foregroundStyle(theme.accent)
                .padding(.horizontal, UI.CookMode.timerButtonHorizontalPadding)
                .padding(.vertical, UI.CookMode.timerButtonVerticalPadding)
                .background(theme.accentSoft, in: Capsule())
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: UI.CookMode.navigationSpacing) {
            Button {
                withAnimation(UI.Anim.springNav) {
                    viewModel.goPrevious()
                }
            } label: {
                Image(systemName: Icons.CookMode.previous)
                    .font(UI.Fonts.iconBold)
                    .foregroundStyle(!viewModel.isFirstStep ? theme.text1 : theme.text3)
                    .frame(width: UI.CookMode.navigationButtonSize, height: UI.CookMode.navigationButtonSize)
                    .background(theme.surface, in: Circle())
            }
            .disabled(viewModel.isFirstStep)

            Button {
                withAnimation(UI.Anim.springDefault) {
                    if viewModel.isLastStep {
                        viewModel.finish()
                    } else {
                        viewModel.markDone()
                    }
                }
            } label: {
                HStack(spacing: UI.CookMode.doneButtonSpacing) {
                    Image(systemName: viewModel.completedSteps.contains(viewModel.currentStep)
                          ? "checkmark.circle.fill" : Icons.CookMode.checkmark)
                        .font(UI.Fonts.iconBold)
                    Text(viewModel.isLastStep ? Strings.CookMode.finish : Strings.CookMode.done)
                        .font(UI.Fonts.buttonLabel)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: UI.CookMode.navigationButtonSize)
                .background(
                    LinearGradient(colors: [theme.accent, theme.rose], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
                .neonGlow(theme.accent, radius: UI.Common.neonRadiusSmall)
            }

            Button {
                withAnimation(UI.Anim.springNav) {
                    viewModel.goNext()
                }
            } label: {
                Image(systemName: Icons.CookMode.next)
                    .font(UI.Fonts.iconBold)
                    .foregroundStyle(!viewModel.isLastStep ? theme.text1 : theme.text3)
                    .frame(width: UI.CookMode.navigationButtonSize, height: UI.CookMode.navigationButtonSize)
                    .background(theme.surface, in: Circle())
            }
            .disabled(viewModel.isLastStep)
        }
        .padding(.horizontal, UI.CookMode.horizontalPadding)
        .padding(.bottom, UI.CookMode.bottomPadding)
    }
}
